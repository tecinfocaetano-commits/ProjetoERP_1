unit uOrcamentoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Service de orçamento
  ------------------------------------------------------------
  Orçamento é um PEDIDO_VENDA com STATUS = 'O'. As regras de
  gravação (numeração por empresa, totais, validações, itens e
  auditoria INSERT) são as mesmas do pedido de venda, por isso
  este Service delega a gravação para TPedidoVendaService.

  Regras próprias do orçamento:
    - salvar sempre com STATUS 'O', independente do padrão 'P'
      do pedido de venda;
    - converter em pedido somente quando o registro é da empresa
      da sessão e ainda está com STATUS 'O' (aberto);
    - a conversão é um UPDATE com STATUS='O' no WHERE (protege
      contra conversão dupla) + auditoria 'CONVERSAO' na mesma
      transação;
    - um orçamento já convertido ('P') ou com outro status não
      pode ser convertido de novo.

  A tela antiga gravava sem NUMERO, sem PRECO_UNITARIO, sem
  auditoria e convertia qualquer registro para 'P' sem validar
  status nem empresa.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao, uPedidoVendaService;

type
  { TOrcamentoService }
  TOrcamentoService = class
  private
    FConexao: TConexao;
    FPedidoVenda: TPedidoVendaService;
  public
    constructor Create;
    destructor Destroy; override;

    { Maior número numérico da empresa + 1; ignora textos. }
    function ProximoNumero: Integer;

    { Grava o orçamento (cabeçalho + itens) com STATUS 'O' e
      devolve o ID. ANumero vazio ou '0' usa ProximoNumero. }
    function SalvarOrcamento(AClienteId: Int64; const ANumero: string;
      const AItens: TItensPedidoEntrada; ADesconto: Double;
      const AObservacoes: string = ''; ADataEntrega: TDateTime = 0): Int64;

    { Converte o orçamento aberto em pedido (STATUS 'O' -> 'P').
      Devolve True quando a conversão aconteceu. }
    function ConverterEmPedido(AOrcamentoId: Int64): Boolean;

    { Quantidade de itens do orçamento. }
    function QuantidadeItens(AOrcamentoId: Int64): Integer;
  end;

implementation

uses
  uSessao, uAuditoria;

const
  STATUS_ORCAMENTO = 'O';
  STATUS_PEDIDO = 'P';

constructor TOrcamentoService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
  FPedidoVenda := TPedidoVendaService.Create;
end;

destructor TOrcamentoService.Destroy;
begin
  FPedidoVenda.Free;
  inherited Destroy;
end;

function TOrcamentoService.ProximoNumero: Integer;
begin
  Result := FPedidoVenda.ProximoNumero;
end;

function TOrcamentoService.SalvarOrcamento(AClienteId: Int64;
  const ANumero: string; const AItens: TItensPedidoEntrada;
  ADesconto: Double; const AObservacoes: string;
  ADataEntrega: TDateTime): Int64;
begin
  { gravação, validações, itens e auditoria INSERT ficam no Service
    do pedido de venda; aqui só fixamos o status de orçamento }
  Result := FPedidoVenda.SalvarPedido(AClienteId, ANumero, AItens,
    ADesconto, 0, 0, AObservacoes, STATUS_ORCAMENTO, ADataEntrega);
end;

function TOrcamentoService.QuantidadeItens(AOrcamentoId: Int64): Integer;
begin
  Result := FPedidoVenda.QuantidadeItens(AOrcamentoId);
end;

function TOrcamentoService.ConverterEmPedido(AOrcamentoId: Int64): Boolean;
var
  LQuery: TSQLQuery;
  LStatus: string;
  LEmpresaId: Int64;
begin
  Result := False;
  if AOrcamentoId <= 0 then
    raise Exception.Create('Selecione um orçamento para converter.');

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;

    LQuery.SQL.Text :=
      'SELECT EMPRESA_ID, STATUS FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AOrcamentoId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Orçamento não encontrado.');
    LEmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
    LStatus := Trim(LQuery.FieldByName('STATUS').AsString);
    LQuery.Close;

    { mesmo tratamento de "não encontrado" para outra empresa: não
      vaza a existência de orçamento de outra empresa }
    if LEmpresaId <> TSessao.GetInstance.EmpresaId then
      raise Exception.Create('Orçamento não encontrado.');
    if LStatus = STATUS_PEDIDO then
      raise Exception.Create('Este orçamento já foi convertido em pedido.');
    if LStatus <> STATUS_ORCAMENTO then
      raise Exception.Create(
        'Somente orçamento em aberto pode ser convertido em pedido.');

    FConexao.IniciarTransacao;
    try
      LQuery.SQL.Text :=
        'UPDATE PEDIDO_VENDA SET STATUS = :NOVO ' +
        'WHERE ID = :ID AND STATUS = :ATUAL';
      LQuery.ParamByName('NOVO').AsString := STATUS_PEDIDO;
      LQuery.ParamByName('ID').AsLargeInt := AOrcamentoId;
      LQuery.ParamByName('ATUAL').AsString := STATUS_ORCAMENTO;
      LQuery.ExecSQL;
      if LQuery.RowsAffected <> 1 then
        raise Exception.Create(
          'Não foi possível converter o orçamento: o status mudou.');

      RegistrarAuditoriaSegura('PEDIDO_VENDA', 'CONVERSAO', AOrcamentoId,
        'STATUS=' + STATUS_ORCAMENTO, 'STATUS=' + STATUS_PEDIDO);

      FConexao.Confirmar;
      Result := True;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

end.
