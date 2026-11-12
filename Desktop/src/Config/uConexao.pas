unit uConexao;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, IBConnection;

type
  { Construtor privado é intencional (singleton via GetInstance). }
  {$push}{$warn 3018 off}
  TConexao = class
  private
    class var FInstance: TConexao;
    constructor CreatePrivate;
  public
    Connection: TIBConnection;
    Transaction: TSQLTransaction;
    Host: string;
    Database: string;
    User: string;
    Password: string;
    Port: Integer;

    class function GetInstance: TConexao;
    class procedure ReleaseInstance;

    procedure Conectar;
    procedure Desconectar;
    function Conectado: Boolean;

    procedure IniciarTransacao;
    procedure Confirmar;
    procedure Cancelar;
    function EmTransacao: Boolean;

    destructor Destroy; override;
  end;
  {$pop}

implementation

{ Configuracao do banco por variaveis de ambiente:
    ERP_DB_HOST, ERP_DB_PATH, ERP_DB_USER, ERP_DB_PASSWORD, ERP_DB_PORT.
  Sem ERP_DB_PATH, usa <pasta do exe>\..\..\Banco\dados.fdb, o mesmo
  banco do projeto sem depender do caminho absoluto da maquina. }
function ValorAmbiente(const ANome, APadrao: string): string;
var
  LValor: string;
begin
  LValor := Trim(GetEnvironmentVariable(ANome));
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

constructor TConexao.CreatePrivate;
begin
  inherited Create;
  Connection := TIBConnection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  // READ COMMITTED + rec_version: o Desktop enxerga os dados gravados por outra
  // conexao (ex.: API/Android). Sem isto o Firebird usa SNAPSHOT e a tela fica
  // com dados obsoletos enquanto a transacao permanecer aberta.
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
  if FInstance = nil then
    FInstance := TConexao.CreatePrivate;
  Result := FInstance;
end;

class procedure TConexao.ReleaseInstance;
begin
  if FInstance <> nil then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
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
    Connection.CharSet := 'UTF8';
    Connection.LoginPrompt := False;
    Connection.Params.Add('isc_dpb_lc_ctype=UTF8');
    Connection.Connected := True;
  end;
end;

procedure TConexao.Desconectar;
begin
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

initialization

finalization
  TConexao.ReleaseInstance;

end.
