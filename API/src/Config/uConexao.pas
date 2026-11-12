unit uConexao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - API - Pool de conexoes com o Firebird
  ------------------------------------------------------------
  O Horse (provider FPC.HTTPApplication) atende cada requisicao
  em uma thread propria: o provider faz
  THTTPApplication.Threaded := True e o fphttpserver usa
  TFPHTTPConnectionThread (com keep-alive, a mesma thread atende
  varias requisicoes). Uma unica TIBConnection compartilhada por
  todo o servidor, portanto, nao e segura: duas requisicoes
  simultaneas disputariam a MESMA conexao e a MESMA transacao.

  Solucao: pool com afinidade por thread.

  - Cada thread de requisicao recebe a SUA TConexao (conexao +
    transacao); nunca ha duas threads no mesmo objeto.
  - TConexao.GetInstance continua devolvendo "a conexao da thread
    atual", entao nenhuma rota precisou mudar.
  - Toda conexao retirada ja sai CONECTADA (reconecta sozinha se o
    Firebird reiniciar).
  - Quando uma thread morre (fim da conexao keep-alive), a vaga e
    liberada e a conexao do Firebird e fechada: nada envelhece.
  - Se todas as conexoes estiverem em uso por threads vivas, Obter
    espera ate ~5 s e so entao falha com mensagem clara - nunca
    compartilha conexao em silencio.

  Tamanho do pool: variavel de ambiente ERP_API_POOL (padrao 8,
  limitada a 2..64).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, IBConnection;

type
  TConexaoPool = class;

  TConexao = class
  private
    class var FPool: TConexaoPool;
  public
    Connection: TIBConnection;
    Transaction: TSQLTransaction;
    Host: string;
    Database: string;
    User: string;
    Password: string;
    Port: Integer;

    constructor Create;

    { Conexao da thread atual (retirada do pool). }
    class function GetInstance: TConexao;
    { Destroi o pool inteiro (finalizacao do processo). }
    class procedure ReleaseInstance;
    { Devolve a conexao da thread atual ao pool, fechando-a. Opcional: sem
      isto a conexao fica reservada ate a thread morrer (o que tambem
      funciona - a vaga e reciclada). }
    class procedure DevolverAtual;
    { Diagnostico: "pool=N conexoes, M em uso". }
    class function PoolDescricao: string;

    procedure Conectar;
    procedure Desconectar;
    function  Conectado: Boolean;

    procedure IniciarTransacao;
    procedure Confirmar;
    procedure Cancelar;
    function  EmTransacao: Boolean;

    destructor Destroy; override;
  end;

  { Pool interno: uma TConexao por thread de requisicao, com limite de
    conexoes simultaneas. Nao usar direto - o caminho e TConexao.GetInstance. }
  TConexaoPool = class
  private
    type
      TItemPool = record
        Conexao: TConexao;    { nil = vaga ainda nao usada }
        ThreadId: TThreadId;  { dono da conexao; 0 = vaga }
      end;
  private
    FLock: TRTLCriticalSection;
    FItens: array of TItemPool;
    function  IndexDaThread(AThreadId: TThreadId): Integer;
    function  IndexVaga: Integer;
    function  LiberarThreadsMortas: Integer;
  public
    constructor Create(AMaximo: Integer);
    destructor Destroy; override;
    function  Obter: TConexao;
    procedure Devolver(AThreadId: TThreadId);
    function  Descricao: string;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;   { OpenThread / GetExitCodeThread / STILL_ACTIVE }
{$ENDIF}

const
  { Conexoes simultaneas com o Firebird, salvo ajuste por ERP_API_POOL. }
  POOL_PADRAO = 8;
  { Espera por uma vaga antes de falhar: 250 passos de 20 ms = ~5 s. }
  POOL_ESPERA_PASSOS = 250;
  POOL_ESPERA_MS = 20;

{ ------------------------------------------------------------
  Configuracao do banco (variaveis de ambiente)
  ------------------------------------------------------------
  ERP_DB_HOST, ERP_DB_PATH, ERP_DB_USER, ERP_DB_PASSWORD, ERP_DB_PORT.
  Sem ERP_DB_PATH, usa <pasta do exe>\..\..\Banco\dados.fdb, que e o
  mesmo banco do desktop sem depender do caminho absoluto da maquina
  de desenvolvimento. }

function ValorAmbiente(const ANome, APadrao: string): string;
var
  LValor: string;
begin
  LValor := Trim(SysUtils.GetEnvironmentVariable(ANome));
  if LValor = '' then
    Result := APadrao
  else
    Result := LValor;
end;

function CaminhoPadraoBanco: string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    '..' + PathDelim + '..' + PathDelim + 'Banco' + PathDelim + 'dados.fdb');
end;

{ ------------------------------------------------------------
  Tamanho do pool (ERP_API_POOL, com limites de seguranca)
  ------------------------------------------------------------ }

function TamanhoPool: Integer;
var
  LValor: string;
begin
  Result := POOL_PADRAO;
  LValor := Trim(SysUtils.GetEnvironmentVariable('ERP_API_POOL'));
  if LValor <> '' then
    Result := StrToIntDef(LValor, POOL_PADRAO);
  if Result < 2 then
    Result := 2;
  if Result > 64 then
    Result := 64;
end;

{ ------------------------------------------------------------
  Thread viva? (Windows: codigo de saida STILL_ACTIVE)
  Sem isto a vaga de uma thread morta nunca voltaria ao pool e o
  servidor esgotaria as conexoes com o passar do tempo.
  ------------------------------------------------------------ }

function ThreadViva(AThreadId: TThreadId): Boolean;
{$IFDEF MSWINDOWS}
var
  LHandle: THandle;
  LCodigo: DWORD;
begin
  Result := True;
  if AThreadId = 0 then
    Exit(False);

  LHandle := OpenThread(THREAD_QUERY_INFORMATION, False, DWORD(AThreadId));
  if LHandle = 0 then
    Exit(False);   { a thread nao existe mais }
  try
    { GetExitCodeThread devolve LongBool em FPC: usar direto na expressao }
    Result := GetExitCodeThread(LHandle, LCodigo)
      and (LCodigo = STILL_ACTIVE);
  finally
    CloseHandle(LHandle);
  end;
end;
{$ELSE}
begin
  { fora do Windows nao ha como checar de forma barata: assume viva.
    O pool continua limitado - so nao recicla a vaga da thread morta. }
  Result := AThreadId <> 0;
end;
{$ENDIF}

{ ============================================================
  TConexao
  ============================================================ }

constructor TConexao.Create;
begin
  inherited Create;
  Connection := TIBConnection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  // READ COMMITTED + rec_version: cada consulta enxerga o que ja foi confirmado
  // por outras conexoes (Desktop, outro usuario). Sem isto o Firebird usa
  // SNAPSHOT e a API passa a devolver dados obsoletos enquanto a transacao
  // permanecer aberta.
  Transaction.Params.Add('read_committed');
  Transaction.Params.Add('rec_version');
  Transaction.Params.Add('nowait');
  Connection.Transaction := Transaction;
  Transaction.DataBase := Connection;
  Host := ValorAmbiente('ERP_DB_HOST', '');
  Database := ValorAmbiente('ERP_DB_PATH', CaminhoPadraoBanco);
  User := ValorAmbiente('ERP_DB_USER', 'SYSDBA');
  Password := ValorAmbiente('ERP_DB_PASSWORD', 'masterkey');
  Port := StrToIntDef(ValorAmbiente('ERP_DB_PORT', '3050'), 3050);
end;

class function TConexao.GetInstance: TConexao;
begin
  { "a conexao da thread atual": cada requisicao tem a sua, entao as
    rotas continuam iguais e deixam de compartilhar conexao }
  Result := FPool.Obter;
end;

class procedure TConexao.ReleaseInstance;
begin
  FreeAndNil(FPool);
end;

class procedure TConexao.DevolverAtual;
begin
  FPool.Devolver(GetCurrentThreadId);
end;

class function TConexao.PoolDescricao: string;
begin
  if FPool = nil then
    Result := 'pool nao iniciado'
  else
    Result := FPool.Descricao;
end;

procedure TConexao.Conectar;
begin
  if not Connection.Connected then
  begin
    Connection.HostName := Host;
    Connection.DatabaseName := Database;
    Connection.UserName := User;
    Connection.Password := Password;
    Connection.Port := Port;
    Connection.LoginPrompt := False;
    // IMPORTANTE (API): NAO definir CharSet='UTF8'.
    // Com CharSet=UTF8 o FPC converte o texto para o codepage do sistema (CP1252),
    // o que corrompe o JSON (que precisa de UTF-8). Sem CharSet, o Firebird
    // entrega os bytes UTF-8 crus, que e exatamente o que a API deve repassar.
    Connection.Connected := True;
  end;
end;

procedure TConexao.Desconectar;
begin
  if Transaction.Active then
    Transaction.Rollback;   { nao deixa transacao pendurada ao devolver a vaga }
  if Connection.Connected then
    Connection.Connected := False;
end;

function TConexao.Conectado: Boolean;
begin
  Result := Connection.Connected;
end;

procedure TConexao.IniciarTransacao;
begin
  if not Transaction.Active then
    Transaction.StartTransaction;
end;

procedure TConexao.Confirmar;
begin
  if Transaction.Active then
    Transaction.Commit;
end;

procedure TConexao.Cancelar;
begin
  if Transaction.Active then
    Transaction.Rollback;
end;

function TConexao.EmTransacao: Boolean;
begin
  Result := Transaction.Active;
end;

destructor TConexao.Destroy;
begin
  Desconectar;
  Transaction.Free;
  Connection.Free;
  inherited Destroy;
end;

{ ============================================================
  TConexaoPool
  ============================================================ }

constructor TConexaoPool.Create(AMaximo: Integer);
begin
  inherited Create;
  InitCriticalSection(FLock);
  SetLength(FItens, AMaximo);   { vagas vazias: Conexao = nil, ThreadId = 0 }
end;

destructor TConexaoPool.Destroy;
var
  I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    for I := 0 to High(FItens) do
      FItens[I].Conexao.Free;   { Destroy ja desconecta }
    SetLength(FItens, 0);
  finally
    LeaveCriticalSection(FLock);
  end;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TConexaoPool.IndexDaThread(AThreadId: TThreadId): Integer;
var
  I: Integer;
begin
  Result := -1;
  if AThreadId = 0 then
    Exit;
  for I := 0 to High(FItens) do
    if FItens[I].ThreadId = AThreadId then
      Exit(I);
end;

function TConexaoPool.IndexVaga: Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FItens) do
    if FItens[I].ThreadId = 0 then
      Exit(I);
end;

{ Libera as vagas de threads que ja morreram (fim da conexao keep-alive),
  fechando a conexao correspondente. Devolve quantas vagas liberou. }
function TConexaoPool.LiberarThreadsMortas: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FItens) do
    if (FItens[I].ThreadId <> 0) and (not ThreadViva(FItens[I].ThreadId)) then
    begin
      FItens[I].Conexao.Free;   { Destroy faz Rollback + Desconectar }
      FItens[I].Conexao := nil;
      FItens[I].ThreadId := 0;
      Inc(Result);
    end;
end;

function TConexaoPool.Obter: TConexao;
var
  LThread: TThreadId;
  LIdx, LEspera: Integer;
begin
  LThread := GetCurrentThreadId;
  Result := nil;

  for LEspera := 0 to POOL_ESPERA_PASSOS do
  begin
    EnterCriticalSection(FLock);
    try
      LIdx := IndexDaThread(LThread);
      if LIdx < 0 then
      begin
        LiberarThreadsMortas;   { recicla vagas de threads encerradas }
        LIdx := IndexVaga;
      end;

      if LIdx >= 0 then
      begin
        if FItens[LIdx].Conexao = nil then
          FItens[LIdx].Conexao := TConexao.Create;
        FItens[LIdx].ThreadId := LThread;   { posse exclusiva desta thread }
        Result := FItens[LIdx].Conexao;
      end;
    finally
      LeaveCriticalSection(FLock);
    end;

    if Result <> nil then
    begin
      try
        Result.Conectar;   { idempotente: so conecta se preciso }
      except
        { falhou ao conectar (banco fora do ar): devolve a vaga para nao
          deixar uma conexao presa na thread }
        Devolver(LThread);
        raise;
      end;
      Exit;
    end;

    { todas as conexoes estao em uso por threads vivas: espera uma vaga }
    Sleep(POOL_ESPERA_MS);
  end;

  raise Exception.Create(Format(
    'Pool de conexoes esgotado: as %d conexoes estao em uso por outras ' +
    'threads de requisicao. Aumente a variavel de ambiente ERP_API_POOL ' +
    'ou reduza a concorrencia.', [Length(FItens)]));
end;

procedure TConexaoPool.Devolver(AThreadId: TThreadId);
var
  LIdx: Integer;
begin
  EnterCriticalSection(FLock);
  try
    LIdx := IndexDaThread(AThreadId);
    if LIdx >= 0 then
    begin
      FItens[LIdx].Conexao.Free;   { Destroy faz Rollback + Desconectar }
      FItens[LIdx].Conexao := nil;
      FItens[LIdx].ThreadId := 0;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TConexaoPool.Descricao: string;
var
  I, LEmUso: Integer;
begin
  LEmUso := 0;
  EnterCriticalSection(FLock);
  try
    for I := 0 to High(FItens) do
      if FItens[I].ThreadId <> 0 then
        Inc(LEmUso);
    Result := Format('pool=%d conexoes, %d em uso', [Length(FItens), LEmUso]);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

initialization
  { criado na inicializacao da unit (antes de qualquer thread de requisicao)
    para nao precisar de lock no proprio nascimento do pool }
  TConexao.FPool := TConexaoPool.Create(TamanhoPool);

finalization
  TConexao.ReleaseInstance;

end.
