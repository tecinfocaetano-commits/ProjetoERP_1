unit uUsuario;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model Usuario
  Descrição: Entidade de usuários do sistema
  Padrão: Entity
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TUsuario - Usuário do sistema }
  TUsuario = class(TModelBase)
  private
    FNome: string;
    FLogin: string;
    FSenha: string;
    FEmail: string;
    FTelefone: string;
    FGrupoId: Int64;
    FAtivo: Char;
    FAdministrador: Boolean;
    FUltimoAcesso: TDateTime;
  public
    constructor Create; override;

    property Nome: string read FNome write FNome;
    property Login: string read FLogin write FLogin;
    property Senha: string read FSenha write FSenha;
    property Email: string read FEmail write FEmail;
    property Telefone: string read FTelefone write FTelefone;
    property GrupoId: Int64 read FGrupoId write FGrupoId;
    property Ativo: Char read FAtivo write FAtivo;
    property Administrador: Boolean read FAdministrador write FAdministrador;
    property UltimoAcesso: TDateTime read FUltimoAcesso write FUltimoAcesso;
  end;

implementation

{ TUsuario }

constructor TUsuario.Create;
begin
  inherited Create;
  FNome := '';
  FLogin := '';
  FSenha := '';
  FEmail := '';
  FTelefone := '';
  FGrupoId := 0;
  FAtivo := 'A';
  FAdministrador := False;
  FUltimoAcesso := 0;
end;

end.
