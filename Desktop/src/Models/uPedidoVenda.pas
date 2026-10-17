unit uPedidoVenda;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Model PedidoVenda
  Descrição: Entidade de pedidos de venda
  Padrão: Entity
  ============================================================ }

interface

uses
  Classes, SysUtils, uModelBase;

type
  { TPedidoVenda - Pedido de venda }
  TPedidoVenda = class(TModelBase)
  private
    FClienteId: Int64;
    FNumero: string;
    FDataEmissao: TDateTime;
    FDataEntrega: TDateTime;
    FStatus: string;
    FSubtotal: Double;
    FDesconto: Double;
    FTotal: Double;
    FObservacoes: string;
  public
    constructor Create; override;

    property ClienteId: Int64 read FClienteId write FClienteId;
    property Numero: string read FNumero write FNumero;
    property DataEmissao: TDateTime read FDataEmissao write FDataEmissao;
    property DataEntrega: TDateTime read FDataEntrega write FDataEntrega;
    property Status: string read FStatus write FStatus;
    property Subtotal: Double read FSubtotal write FSubtotal;
    property Desconto: Double read FDesconto write FDesconto;
    property Total: Double read FTotal write FTotal;
    property Observacoes: string read FObservacoes write FObservacoes;
  end;

implementation

{ TPedidoVenda }

constructor TPedidoVenda.Create;
begin
  inherited Create;
  FClienteId := 0;
  FNumero := '';
  FDataEmissao := Now;
  FDataEntrega := Now;
  FStatus := 'A';
  FSubtotal := 0;
  FDesconto := 0;
  FTotal := 0;
  FObservacoes := '';
end;

end.
