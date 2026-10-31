unit uProdutoFinanceiro;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model: Produto Financeiro
  Descrição: Serviço/outros usado na nota e no financeiro
             (vincula a um Produto Fiscal)
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TProdutoFinanceiro }
  TProdutoFinanceiro = class(TModelBase)
  private
    FProdutoFiscalId: Int64;
    FCodigo: string;
    FDescricao: string;
    FTipo: Char;          // S = serviço, O = outros
    FValor: Currency;
    FAtivo: Char;
    FObservacoes: string;
  public
    constructor Create; override;

    property ProdutoFiscalId: Int64 read FProdutoFiscalId write FProdutoFiscalId;
    property Codigo: string read FCodigo write FCodigo;
    property Descricao: string read FDescricao write FDescricao;
    property Tipo: Char read FTipo write FTipo;
    property Valor: Currency read FValor write FValor;
    property Ativo: Char read FAtivo write FAtivo;
    property Observacoes: string read FObservacoes write FObservacoes;
  end;

implementation

{ TProdutoFinanceiro }

constructor TProdutoFinanceiro.Create;
begin
  inherited Create;
  FProdutoFiscalId := 0;
  FTipo := 'S';
  FValor := 0;
  FAtivo := 'A';
end;

end.
