unit uProduto;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model: Produto
  Descrição: Entidade de Produto
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TProduto }
  TProduto = class(TModelBase)
  private
    FCategoriaId: Int64;
    FFornecedorId: Int64;
    FUnidadeId: Int64;
    FCodigo: string;
    FCodigoBarras: string;
    FDescricao: string;
    FDescricaoPDV: string;
    FNcm: string;
    FCest: string;
    FCfopVenda: string;
    FCfopCompra: string;
    FCstIcms: string;
    FCstPis: string;
    FCstCofins: string;
    FAliqIcms: Double;
    FAliqPis: Double;
    FAliqCofins: Double;
    FPrecoCusto: Currency;
    FPrecoVenda: Currency;
    FMargemLucro: Double;
    FEstoqueMinimo: Double;
    FEstoqueMaximo: Double;
    FPesoLiquido: Double;
    FPesoBruto: Double;
    FControlaEstoque: Boolean;
    FAtivo: Char;
    FImagem: string;
    FObservacoes: string;
  public
    constructor Create; override;

    property CategoriaId: Int64 read FCategoriaId write FCategoriaId;
    property FornecedorId: Int64 read FFornecedorId write FFornecedorId;
    property UnidadeId: Int64 read FUnidadeId write FUnidadeId;
    property Codigo: string read FCodigo write FCodigo;
    property CodigoBarras: string read FCodigoBarras write FCodigoBarras;
    property Descricao: string read FDescricao write FDescricao;
    property DescricaoPDV: string read FDescricaoPDV write FDescricaoPDV;
    property Ncm: string read FNcm write FNcm;
    property Cest: string read FCest write FCest;
    property CfopVenda: string read FCfopVenda write FCfopVenda;
    property CfopCompra: string read FCfopCompra write FCfopCompra;
    property CstIcms: string read FCstIcms write FCstIcms;
    property CstPis: string read FCstPis write FCstPis;
    property CstCofins: string read FCstCofins write FCstCofins;
    property AliqIcms: Double read FAliqIcms write FAliqIcms;
    property AliqPis: Double read FAliqPis write FAliqPis;
    property AliqCofins: Double read FAliqCofins write FAliqCofins;
    property PrecoCusto: Currency read FPrecoCusto write FPrecoCusto;
    property PrecoVenda: Currency read FPrecoVenda write FPrecoVenda;
    property MargemLucro: Double read FMargemLucro write FMargemLucro;
    property EstoqueMinimo: Double read FEstoqueMinimo write FEstoqueMinimo;
    property EstoqueMaximo: Double read FEstoqueMaximo write FEstoqueMaximo;
    property PesoLiquido: Double read FPesoLiquido write FPesoLiquido;
    property PesoBruto: Double read FPesoBruto write FPesoBruto;
    property ControlaEstoque: Boolean read FControlaEstoque write FControlaEstoque;
    property Ativo: Char read FAtivo write FAtivo;
    property Imagem: string read FImagem write FImagem;
    property Observacoes: string read FObservacoes write FObservacoes;
  end;

implementation

{ TProduto }

constructor TProduto.Create;
begin
  inherited Create;
  FCategoriaId := 0;
  FFornecedorId := 0;
  FUnidadeId := 0;
  FAtivo := 'A';
  FControlaEstoque := True;
  FPrecoCusto := 0;
  FPrecoVenda := 0;
  FMargemLucro := 0;
end;

end.
