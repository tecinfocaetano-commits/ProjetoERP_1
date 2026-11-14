unit uUsuarioService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service: Usuario
  Descrição: Regras de negócio para o cadastro de Usuários.
             A senha chega em TEXTO PURO nos métodos e é gravada
             como SHA-256 (uSenhaHash); no update, string vazia
             mantém a senha atual. Login é único por empresa e
             GRUPO_ID é obrigatório (domínio DM_ID = NOT NULL —
             a tela já tinha o combo, mas o INSERT/UPDATE antigo
             não gravava a coluna e falhava).
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uServiceBase, uRepositoryBase, uUsuario,
  uSessao;

type
  { Login existe em mais de uma empresa e o chamador nao informou qual. }
  ELoginAmbiguo = class(Exception);

  { TUsuarioService }
  TUsuarioService = class(TServiceBase)
  private
    FRepo: TRepositoryBase;
    function LoginExiste(const ALogin: string; AExcluirId: Int64 = 0): Boolean;
    procedure Validar(AObj: TUsuario; const ASenhaTexto: string;
      AInserindo: Boolean);
    procedure GarantirDaEmpresa(AId: Int64);
  public
    constructor Create;
    destructor Destroy; override;

    function BuscarPorId(AId: Int64): TUsuario;
    { Com AEmpresaId > 0, restringe a empresa. Sem ele, se o mesmo login
      existir em mais de uma empresa, levanta ELoginAmbiguo em vez de
      escolher a primeira silenciosamente. }
    function BuscarPorLogin(const ALogin: string;
      AEmpresaId: Int64 = 0): TUsuario;
    function BuscarTodos: TSQLQuery;
    function Inserir(AObj: TUsuario; const ASenhaTexto: string): Int64;
    function Atualizar(AObj: TUsuario; const ASenhaTexto: string): Boolean;
    function Excluir(AId: Int64): Boolean;
    function Pesquisar(const ATermo: string): TSQLQuery;
    { Login: devolve o usuário ativo pelo login (com hash da senha
      em Senha) para o SenhaConfere da tela; depois o formulário
      chama RegistrarAcesso. }
    procedure RegistrarAcesso(AId: Int64; const ASenhaDigitada,
      ASenhaGuardada: string);
  end;

implementation

uses
  uSenhaHash;

{ TUsuarioService }

constructor TUsuarioService.Create;
begin
  FRepo := TRepositoryBase.Create('USUARIO');
  inherited Create(FRepo);
end;

destructor TUsuarioService.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

procedure TUsuarioService.Validar(AObj: TUsuario;
  const ASenhaTexto: string; AInserindo: Boolean);
begin
  ValidarCampoObrigatorio(AObj.Nome, 'Nome');
  ValidarCampoObrigatorio(AObj.Login, 'Login');
  if AInserindo and (Length(ASenhaTexto) < 6) then
    raise Exception.Create('A senha deve ter pelo menos 6 caracteres.');
  if (not AInserindo) and (ASenhaTexto <> '') and
     (Length(ASenhaTexto) < 6) then
    raise Exception.Create('A senha deve ter pelo menos 6 caracteres.');
  { DM_ID é NOT NULL: sem grupo o INSERT/UPDATE falha no banco }
  if AObj.GrupoId <= 0 then
    raise Exception.Create('Selecione o Grupo do usuário.');
  if LoginExiste(AObj.Login, AObj.Id) then
    raise Exception.Create('Já existe um usuário com este login.');
end;

function TUsuarioService.LoginExiste(const ALogin: string;
  AExcluirId: Int64): Boolean;
var
  LCond: string;
  LNome: array of string;
  LVal: array of string;
begin
  if Trim(ALogin) = '' then
  begin
    Result := False;
    Exit;
  end;

  if AExcluirId > 0 then
  begin
    LCond := 'EMPRESA_ID = :EMP AND UPPER(LOGIN) = UPPER(:LOG) AND ID <> :EXC';
    LNome := ['EMP', 'LOG', 'EXC'];
    LVal := [IntToStr(TSessao.GetInstance.EmpresaId), ALogin,
      IntToStr(AExcluirId)];
  end
  else
  begin
    LCond := 'EMPRESA_ID = :EMP AND UPPER(LOGIN) = UPPER(:LOG)';
    LNome := ['EMP', 'LOG'];
    LVal := [IntToStr(TSessao.GetInstance.EmpresaId), ALogin];
  end;
  Result := FRepo.ContarParam(LCond, LNome, LVal) > 0;
end;

function TUsuarioService.BuscarPorId(AId: Int64): TUsuario;
var
  LQuery: TSQLQuery;
begin
  Result := nil;
  LQuery := FRepo.BuscarPorId(AId);
  try
    if not LQuery.IsEmpty then
    begin
      Result := TUsuario.Create;
      Result.Id := LQuery.FieldByName('ID').AsLargeInt;
      Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
      if (LQuery.FindField('GRUPO_ID') <> nil) and
         (not LQuery.FieldByName('GRUPO_ID').IsNull) then
        Result.GrupoId := LQuery.FieldByName('GRUPO_ID').AsLargeInt;
      Result.Nome := LQuery.FieldByName('NOME').AsString;
      Result.Login := LQuery.FieldByName('LOGIN').AsString;
      Result.Senha := LQuery.FieldByName('SENHA').AsString;
      Result.Email := LQuery.FieldByName('EMAIL').AsString;
      if LQuery.FindField('TELEFONE') <> nil then
        Result.Telefone := LQuery.FieldByName('TELEFONE').AsString;
      Result.Administrador :=
        LQuery.FieldByName('ADMINISTRADOR').AsString = 'S';
      Result.Ativo := LQuery.FieldByName('ATIVO').AsString[1];
    end;
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TUsuarioService.BuscarPorLogin(const ALogin: string;
  AEmpresaId: Int64): TUsuario;
var
  LQuery: TSQLQuery;
  LCond: string;
  LNomes, LValores: array of string;
  LEmpresaAtual: Int64;
  LEmpresas: string;
begin
  Result := nil;

  if AEmpresaId > 0 then
  begin
    LCond := 'LOGIN = :LOG AND ATIVO = ''A'' AND EMPRESA_ID = :EMP';
    SetLength(LNomes, 2);
    SetLength(LValores, 2);
    LNomes[0] := 'LOG';
    LNomes[1] := 'EMP';
    LValores[0] := ALogin;
    LValores[1] := IntToStr(AEmpresaId);
  end
  else
  begin
    LCond := 'LOGIN = :LOG AND ATIVO = ''A''';
    SetLength(LNomes, 1);
    SetLength(LValores, 1);
    LNomes[0] := 'LOG';
    LValores[0] := ALogin;
  end;

  LQuery := FRepo.BuscarTodosParam(LCond, LNomes, LValores, 'EMPRESA_ID, ID');
  try
    if LQuery.IsEmpty then
      Exit;

    { Sem empresa informada, o login so pode identificar uma empresa.
      Percorre as linhas: mais de uma empresa = ambiguidade explicita. }
    LQuery.First;
    LEmpresaAtual := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
    LEmpresas := '';
    while not LQuery.EOF do
    begin
      if LQuery.FieldByName('EMPRESA_ID').AsLargeInt <> LEmpresaAtual then
      begin
        if LEmpresas = '' then
          LEmpresas := IntToStr(LEmpresaAtual);
        LEmpresas := LEmpresas + ', ' +
          IntToStr(LQuery.FieldByName('EMPRESA_ID').AsLargeInt);
      end;
      LQuery.Next;
    end;
    if LEmpresas <> '' then
      raise ELoginAmbiguo.Create(
        'Este login existe em mais de uma empresa (' + LEmpresas +
        '). Informe o codigo da empresa.');

    LQuery.First;
    Result := TUsuario.Create;
    Result.Id := LQuery.FieldByName('ID').AsLargeInt;
    Result.EmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
    if (LQuery.FindField('GRUPO_ID') <> nil) and
       (not LQuery.FieldByName('GRUPO_ID').IsNull) then
      Result.GrupoId := LQuery.FieldByName('GRUPO_ID').AsLargeInt;
    Result.Nome := LQuery.FieldByName('NOME').AsString;
    Result.Login := LQuery.FieldByName('LOGIN').AsString;
    Result.Senha := LQuery.FieldByName('SENHA').AsString;
    Result.Email := LQuery.FieldByName('EMAIL').AsString;
    Result.Administrador :=
      LQuery.FieldByName('ADMINISTRADOR').AsString = 'S';
    Result.Ativo := 'A';
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TUsuarioService.BuscarTodos: TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP',
    ['EMP'],
    [IntToStr(TSessao.GetInstance.EmpresaId)],
    'NOME');
end;

function TUsuarioService.Inserir(AObj: TUsuario;
  const ASenhaTexto: string): Int64;
const
  CAMPOS = 'EMPRESA_ID, GRUPO_ID, NOME, LOGIN, SENHA, EMAIL, ' +
           'TELEFONE, ADMINISTRADOR, ATIVO';
  VALORES_PARAM = ':EMP, :GRUPO, :NOME, :LOGIN, :SENHA, :EMAIL, ' +
                  ':TEL, :ADMIN, :ATIVO';
var
  LAdmin: string;
begin
  Validar(AObj, ASenhaTexto, True);
  if AObj.Administrador then LAdmin := 'S' else LAdmin := 'N';

  Result := FRepo.InserirParam(
    CAMPOS, VALORES_PARAM,
    ['EMP', 'GRUPO', 'NOME', 'LOGIN', 'SENHA', 'EMAIL',
     'TEL', 'ADMIN', 'ATIVO'],
    [IntToStr(AObj.EmpresaId), IntToStr(AObj.GrupoId), AObj.Nome,
     AObj.Login, HashSenha(ASenhaTexto), AObj.Email, AObj.Telefone,
     LAdmin, AObj.Ativo]);

  LogOperacao('USUARIO', 'I', Result);
end;

procedure TUsuarioService.GarantirDaEmpresa(AId: Int64);
var
  LQuery: TSQLQuery;
begin
  { escrita/leitura por ID só vale para registro da empresa da sessão }
  LQuery := FRepo.BuscarPorId(AId);
  try
    if LQuery.IsEmpty or
       (LQuery.FieldByName('EMPRESA_ID').AsLargeInt <>
        TSessao.GetInstance.EmpresaId) then
      raise Exception.Create('Usuário não encontrado para a empresa atual.');
  finally
    if LQuery.Active then
      LQuery.Close;
  end;
end;

function TUsuarioService.Atualizar(AObj: TUsuario;
  const ASenhaTexto: string): Boolean;
const
  CAMPOS_PARAM = 'GRUPO_ID = :GRUPO, NOME = :NOME, LOGIN = :LOGIN, ' +
                 'EMAIL = :EMAIL, TELEFONE = :TEL, ' +
                 'ADMINISTRADOR = :ADMIN, ATIVO = :ATIVO';
const
  CAMPOS_SENHA = ', SENHA = :SENHA';
var
  LCampos: string;
  LValoresParam: string;
  LNome: array of string;
  LVal: array of string;
  LAdmin: string;
begin
  ValidarId(AObj.Id, 'Usuário');
  GarantirDaEmpresa(AObj.Id);
  Validar(AObj, ASenhaTexto, False);
  if AObj.Administrador then LAdmin := 'S' else LAdmin := 'N';

  LCampos := CAMPOS_PARAM;
  LValoresParam := ':GRUPO, :NOME, :LOGIN, :EMAIL, :TEL, :ADMIN, :ATIVO';
  LNome := ['GRUPO', 'NOME', 'LOGIN', 'EMAIL', 'TEL', 'ADMIN', 'ATIVO'];
  LVal := [IntToStr(AObj.GrupoId), AObj.Nome, AObj.Login, AObj.Email,
    AObj.Telefone, LAdmin, AObj.Ativo];

  { senha vazia = manter a atual (o form limpa o campo ao editar) }
  if ASenhaTexto <> '' then
  begin
    LCampos := LCampos + CAMPOS_SENHA;
    LValoresParam := LValoresParam + ', :SENHA';
    SetLength(LNome, Length(LNome) + 1);
    LNome[High(LNome)] := 'SENHA';
    SetLength(LVal, Length(LVal) + 1);
    LVal[High(LVal)] := HashSenha(ASenhaTexto);
  end;

  Result := FRepo.AtualizarParam(
    AObj.Id, LCampos,
    LNome, LVal);

  LogOperacao('USUARIO', 'U', AObj.Id);
end;

function TUsuarioService.Excluir(AId: Int64): Boolean;
begin
  ValidarId(AId, 'Usuário');
  GarantirDaEmpresa(AId);
  { ninguém exclui o próprio usuário logado (regra também checada
    na tela; aqui é a garantia no Service) }
  if AId = TSessao.GetInstance.UsuarioId then
    raise Exception.Create('Não é possível excluir o próprio usuário logado.');
  Result := FRepo.Excluir(AId);
  LogOperacao('USUARIO', 'D', AId);
end;

function TUsuarioService.Pesquisar(const ATermo: string): TSQLQuery;
begin
  Result := FRepo.BuscarTodosParam(
    'EMPRESA_ID = :EMP AND ' +
    '(UPPER(CAST(NOME AS VARCHAR(200))) CONTAINING UPPER(:T) OR ' +
    'UPPER(CAST(LOGIN AS VARCHAR(200))) CONTAINING UPPER(:T))',
    ['EMP', 'T'],
    [IntToStr(TSessao.GetInstance.EmpresaId), ATermo],
    'NOME');
end;

procedure TUsuarioService.RegistrarAcesso(AId: Int64;
  const ASenhaDigitada, ASenhaGuardada: string);
var
  LQuery: TSQLQuery;
  LMigrar: Boolean;
begin
  LMigrar := PrecisaMigrarSenha(ASenhaGuardada);
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := Conexao.Connection;
    LQuery.Transaction := Conexao.Transaction;
    if LMigrar then
      LQuery.SQL.Text :=
        'UPDATE USUARIO SET SENHA = :SENHA, ' +
        'ULTIMO_ACESSO = CURRENT_TIMESTAMP WHERE ID = :ID'
    else
      LQuery.SQL.Text :=
        'UPDATE USUARIO SET ULTIMO_ACESSO = CURRENT_TIMESTAMP ' +
        'WHERE ID = :ID';
    if LMigrar then
      LQuery.ParamByName('SENHA').AsString := HashSenha(ASenhaDigitada);
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.ExecSQL;
    Conexao.Confirmar;
  finally
    LQuery.Free;
  end;

  { migração de senha legada → hash é mudança de dado: audita }
  if LMigrar then
    LogOperacao('USUARIO', 'U', AId);
end;

end.
