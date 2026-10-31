unit uMaterial;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model: Material
  Descrição: Insumo comprado/consumido na produção
             (vincula a um Produto Fiscal)
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TMaterial }
  TMaterial = class(TModelBase)
  private
    FProdutoFiscalId: Int64;
    FUnidadeId: Int64;
    FCodigo: string;
    FCodigoBarras: string;
    FDescricao: string;
    FPrecoCusto: Currency;
    FControlaEstoque: Boolean;
    FEstoqueMinimo: Double;
    FAtivo: Char;
    FObservacoes: string;
  public
    constructor Create; override;

    property ProdutoFiscalId: Int64 read FProdutoFiscalId write FProdutoFiscalId;
    property UnidadeId: Int64 read FUnidadeId write FUnidadeId;
    property Codigo: string read FCodigo write FCodigo;
    property CodigoBarras: string read FCodigoBarras write FCodigoBarras;
    property Descricao: string read FDescricao write FDescricao;
    property PrecoCusto: Currency read FPrecoCusto write FPrecoCusto;
    property ControlaEstoque: Boolean read FControlaEstoque write FControlaEstoque;
    property EstoqueMinimo: Double read FEstoqueMinimo write FEstoqueMinimo;
    property Ativo: Char read FAtivo write FAtivo;
    property Observacoes: string read FObservacoes write FObservacoes;
  end;

implementation

{ TMaterial }

constructor TMaterial.Create;
begin
  inherited Create;
  FProdutoFiscalId := 0;
  FUnidadeId := 0;
  FAtivo := 'A';
  FControlaEstoque := True;
  FPrecoCusto := 0;
  FEstoqueMinimo := 0;
end;

end.
