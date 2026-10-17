unit uCategoria;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model Categoria
  Descrição: Entidade de categorias de produtos
  Padrão: Entity
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TCategoria - Categoria de produtos }
  TCategoria = class(TModelBase)
  private
    FNome: string;
    FDescricao: string;
    FAtivo: Char;
  public
    constructor Create; override;

    property Nome: string read FNome write FNome;
    property Descricao: string read FDescricao write FDescricao;
    property Ativo: Char read FAtivo write FAtivo;
  end;

implementation

{ TCategoria }

constructor TCategoria.Create;
begin
  inherited Create;
  FNome := '';
  FDescricao := '';
  FAtivo := 'A';
end;

end.
