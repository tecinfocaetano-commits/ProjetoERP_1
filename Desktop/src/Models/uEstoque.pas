unit uEstoque;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model Estoque
  Descrição: Entidade de controle de estoque
  Padrão: Entity
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TEstoque - Controle de estoque }
  TEstoque = class(TModelBase)
  private
    FProdutoId: Int64;
    FQuantidade: Double;
    FQuantidadeMinima: Double;
    FQuantidadeMaxima: Double;
    FLocalizacao: string;
  public
    constructor Create; override;

    property ProdutoId: Int64 read FProdutoId write FProdutoId;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property QuantidadeMinima: Double read FQuantidadeMinima write FQuantidadeMinima;
    property QuantidadeMaxima: Double read FQuantidadeMaxima write FQuantidadeMaxima;
    property Localizacao: string read FLocalizacao write FLocalizacao;
  end;

implementation

{ TEstoque }

constructor TEstoque.Create;
begin
  inherited Create;
  FProdutoId := 0;
  FQuantidade := 0;
  FQuantidadeMinima := 0;
  FQuantidadeMaxima := 0;
  FLocalizacao := '';
end;

end.
