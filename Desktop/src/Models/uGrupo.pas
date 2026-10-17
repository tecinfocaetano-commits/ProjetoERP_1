unit uGrupo;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model Grupo
  Descrição: Entidade de grupos de usuários/permissões
  Padrão: Entity
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TGrupo - Grupo de usuários }
  TGrupo = class(TModelBase)
  private
    FNome: string;
    FDescricao: string;
    FAtivo: string;
  public
    constructor Create; override;

    property Nome: string read FNome write FNome;
    property Descricao: string read FDescricao write FDescricao;
    property Ativo: string read FAtivo write FAtivo;
  end;

implementation

{ TGrupo }

constructor TGrupo.Create;
begin
  inherited Create;
  FNome := '';
  FDescricao := '';
  FAtivo := 'A';
end;

end.
