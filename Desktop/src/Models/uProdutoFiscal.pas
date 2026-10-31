unit uProdutoFiscal;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model: Produto Fiscal
  Descrição: Classificação fiscal (NCM/CEST/CFOP/CST/alíquotas)
             reaproveitada por Material, Produto e Prod.Financeiro
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TProdutoFiscal }
  TProdutoFiscal = class(TModelBase)
  private
    FCodigo: string;
    FDescricao: string;
    FNcm: string;
    FCest: string;
    FCfop: string;
    FCfopVenda: string;
    FCfopCompra: string;
    FCstIcms: string;
    FCstPis: string;
    FCstCofins: string;
    FAliqIcms: Double;
    FAliqPis: Double;
    FAliqCofins: Double;
    FPesoLiquido: Double;
    FPesoBruto: Double;
    FAtivo: Char;
    FObservacoes: string;
  public
    constructor Create; override;

    property Codigo: string read FCodigo write FCodigo;
    property Descricao: string read FDescricao write FDescricao;
    property Ncm: string read FNcm write FNcm;
    property Cest: string read FCest write FCest;
    property Cfop: string read FCfop write FCfop;
    property CfopVenda: string read FCfopVenda write FCfopVenda;
    property CfopCompra: string read FCfopCompra write FCfopCompra;
    property CstIcms: string read FCstIcms write FCstIcms;
    property CstPis: string read FCstPis write FCstPis;
    property CstCofins: string read FCstCofins write FCstCofins;
    property AliqIcms: Double read FAliqIcms write FAliqIcms;
    property AliqPis: Double read FAliqPis write FAliqPis;
    property AliqCofins: Double read FAliqCofins write FAliqCofins;
    property PesoLiquido: Double read FPesoLiquido write FPesoLiquido;
    property PesoBruto: Double read FPesoBruto write FPesoBruto;
    property Ativo: Char read FAtivo write FAtivo;
    property Observacoes: string read FObservacoes write FObservacoes;
  end;

implementation

{ TProdutoFiscal }

constructor TProdutoFiscal.Create;
begin
  inherited Create;
  FAtivo := 'A';
  FAliqIcms := 0;
  FAliqPis := 0;
  FAliqCofins := 0;
  FPesoLiquido := 0;
  FPesoBruto := 0;
end;

end.
