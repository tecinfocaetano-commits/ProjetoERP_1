unit uSessao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Gerenciador de Sessão
  Descrição: Controle de sessão do usuário logado
  Padrão: Singleton
  ============================================================ }

interface

uses
  Classes, SysUtils;

type
  { TSessao - Dados do usuário logado }
  TSessao = class
  private
    class var FInstance: TSessao;
  public
    UsuarioId: Int64;
    EmpresaId: Int64;
    UsuarioNome: string;
    UsuarioLogin: string;
    Administrador: Boolean;
    GrupoId: Int64;
    Logado: Boolean;
    DataLogin: TDateTime;

    constructor Create;

    class function GetInstance: TSessao;
    class procedure ReleaseInstance;
    { Contexto por thread: a API atende cada requisicao numa thread propria e
      nao pode compartilhar o singleton do desktop. Os Services continuam
      chamando GetInstance; quando ha contexto de thread, e ele que vale. }
    class procedure DefinirContexto(AUsuarioId, AEmpresaId, AGrupoId: Int64;
      const ANome, ALogin: string; AAdmin: Boolean);
    class procedure LimparContexto;

    procedure Logar(AUsuarioId, AEmpresaId, AGrupoId: Int64;
      const ANome, ALogin: string; AAdmin: Boolean);
    procedure Deslogar;
  end;

implementation

{ Contexto isolado por thread (usado pela API). A variavel threadvar e
  independente para cada thread de requisicao; o singleton FInstance continua
  sendo o contexto do desktop (thread principal). }
threadvar
  FContextoThread: TSessao;

{ TSessao }

constructor TSessao.Create;
begin
  inherited Create;
  Logado := False;
  UsuarioId := 0;
  EmpresaId := 0;
  GrupoId := 0;
end;

class function TSessao.GetInstance: TSessao;
begin
  { D3: se a thread atual tem contexto propio (API), ele tem prioridade;
    o desktop segue usando o singleton. }
  if FContextoThread <> nil then
    Exit(FContextoThread);
  if FInstance = nil then
    FInstance := TSessao.Create;
  Result := FInstance;
end;

class procedure TSessao.DefinirContexto(AUsuarioId, AEmpresaId,
  AGrupoId: Int64; const ANome, ALogin: string; AAdmin: Boolean);
begin
  LimparContexto;
  FContextoThread := TSessao.Create;
  FContextoThread.Logar(AUsuarioId, AEmpresaId, AGrupoId, ANome, ALogin, AAdmin);
end;

class procedure TSessao.LimparContexto;
begin
  if FContextoThread <> nil then
  begin
    FContextoThread.Free;
    FContextoThread := nil;
  end;
end;

class procedure TSessao.ReleaseInstance;
begin
  if FInstance <> nil then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
end;

procedure TSessao.Logar(AUsuarioId, AEmpresaId, AGrupoId: Int64;
  const ANome, ALogin: string; AAdmin: Boolean);
begin
  UsuarioId := AUsuarioId;
  EmpresaId := AEmpresaId;
  GrupoId := AGrupoId;
  UsuarioNome := ANome;
  UsuarioLogin := ALogin;
  Administrador := AAdmin;
  Logado := True;
  DataLogin := Now;
end;

procedure TSessao.Deslogar;
begin
  Logado := False;
  UsuarioId := 0;
  EmpresaId := 0;
  GrupoId := 0;
  UsuarioNome := '';
  UsuarioLogin := '';
  Administrador := False;
end;

initialization

finalization
  TSessao.LimparContexto;
  TSessao.ReleaseInstance;

end.
