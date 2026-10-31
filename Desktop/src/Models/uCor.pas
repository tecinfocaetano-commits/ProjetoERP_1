unit uCor;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model: Cor
  Descrição: Cor do produto de produção (obrigatória).
             Cada cor tem sua Ficha Técnica (TIPO_BASE = 'COR')
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TCor }
  TCor = class(TModelBase)
  private
    FProdutoId: Int64;    { produto de produção (tabela PRODUTO) }
    FNome: string;
    FHex: string;
    FAtivo: Char;
  public
    constructor Create; override;

    property ProdutoId: Int64 read FProdutoId write FProdutoId;
    property Nome: string read FNome write FNome;
    property Hex: string read FHex write FHex;
    property Ativo: Char read FAtivo write FAtivo;
  end;

implementation

{ TCor }

constructor TCor.Create;
begin
  inherited Create;
  FProdutoId := 0;
  FAtivo := 'A';
end;

end.
