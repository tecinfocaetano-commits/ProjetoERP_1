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
    procedure GarantirAberto(AId: Int64; out ANumero: string;
      out ASubtotal, ADesconto, ATotal: Double);
    function ClienteValido(AClienteId: Int64): Boolean;
    procedure ValidarItens(const AItens: TItensPedidoEntrada);
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

    { F1: edita um orçamento AINDA ABERTO. Cliente/itens/totais são
      revalidados como no pedido; NUMERO e DATA_EMISSAO são preservados. }
    function AtualizarOrcamento(AOrcamentoId, AClienteId: Int64;
      const AItens: TItensPedidoEntrada; ADesconto: Double;
      const AObservacoes: string = ''): Boolean;

    { F1: exclui somente um orçamento aberto, junto com seus itens. }
    function ExcluirOrcamento(AOrcamentoId: Int64): Boolean;

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
  CFOP_PADRAO = '5102';
  TAMANHO_MAX_CFOP = 5;
  TAMANHO_MAX_OBSERVACOES = 255;

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

{ F1: mesmo tratamento de "não encontrado" para registro de outra empresa,
  para não vazar a existência do orçamento. }
procedure TOrcamentoService.GarantirAberto(AId: Int64; out ANumero: string;
  out ASubtotal, ADesconto, ATotal: Double);
var
  LQuery: TSQLQuery;
begin
  ANumero := '';
  ASubtotal := 0;
  ADesconto := 0;
  ATotal := 0;
  if AId <= 0 then
    raise Exception.Create('Selecione um orçamento.');

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT EMPRESA_ID, STATUS, NUMERO, SUBTOTAL, DESCONTO, TOTAL ' +
      'FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if LQuery.IsEmpty or
       (LQuery.FieldByName('EMPRESA_ID').AsLargeInt <> TSessao.GetInstance.EmpresaId) then
      raise Exception.Create('Orçamento não encontrado.');
    if Trim(LQuery.FieldByName('STATUS').AsString) <> STATUS_ORCAMENTO then
      raise Exception.Create('Somente orçamentos em aberto podem ser alterados.');

    ANumero := LQuery.FieldByName('NUMERO').AsString;
    ASubtotal := LQuery.FieldByName('SUBTOTAL').AsFloat;
    ADesconto := LQuery.FieldByName('DESCONTO').AsFloat;
    ATotal := LQuery.FieldByName('TOTAL').AsFloat;
  finally
    LQuery.Free;
  end;
end;

function TOrcamentoService.ClienteValido(AClienteId: Int64): Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  if AClienteId <= 0 then
    Exit;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PESSOA ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP AND TIPO = ''C'' AND ATIVO = ''A''';
    LQuery.ParamByName('ID').AsLargeInt := AClienteId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

{ F1: as mesmas regras de item usadas na gravação do pedido — a API manda
  o CFOP/valor unitário, mas nada disso é aceito sem validação. }
procedure TOrcamentoService.ValidarItens(const AItens: TItensPedidoEntrada);
var
  LQuery: TSQLQuery;
  I: Integer;
begin
  if Length(AItens) = 0 then
    raise Exception.Create('Adicione pelo menos um item ao orçamento.');

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    for I := 0 to High(AItens) do
    begin
      if AItens[I].ProdutoId <= 0 then
        raise Exception.Create('Selecione um produto para o item.');

      LQuery.SQL.Text :=
        'SELECT FIRST 1 ID FROM PRODUTO ' +
        'WHERE ID = :ID AND EMPRESA_ID = :EMP AND ATIVO = ''A''';
      LQuery.ParamByName('ID').AsLargeInt := AItens[I].ProdutoId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      if LQuery.IsEmpty then
        raise Exception.Create('Produto do item não encontrado ou inativo.');
      LQuery.Close;

      if AItens[I].Quantidade <= 0 then
        raise Exception.Create('A quantidade do item deve ser maior que zero.');
      if AItens[I].ValorUnitario < 0 then
        raise Exception.Create('O valor unitário do item não pode ser negativo.');
      if AItens[I].Desconto < 0 then
        raise Exception.Create('O desconto do item não pode ser negativo.');
      if Length(Trim(AItens[I].Cfop)) > TAMANHO_MAX_CFOP then
        raise Exception.CreateFmt('O CFOP do item deve ter no máximo %d caracteres.',
          [TAMANHO_MAX_CFOP]);
      if (AItens[I].Quantidade * AItens[I].ValorUnitario) - AItens[I].Desconto < 0 then
        raise Exception.Create('Desconto maior que o valor do item.');
    end;
  finally
    LQuery.Free;
  end;
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

function TOrcamentoService.AtualizarOrcamento(AOrcamentoId,
  AClienteId: Int64; const AItens: TItensPedidoEntrada;
  ADesconto: Double; const AObservacoes: string): Boolean;
var
  LQuery: TSQLQuery;
  LNumero, LObservacoes: string;
  LSubtotalAntes, LDescontoAntes, LTotalAntes: Double;
  LSubtotal, LTotal, LValorItem: Double;
  I: Integer;
begin
  Result := False;
  GarantirAberto(AOrcamentoId, LNumero, LSubtotalAntes, LDescontoAntes, LTotalAntes);

  if not ClienteValido(AClienteId) then
    raise Exception.Create('Selecione um cliente ativo.');
  ValidarItens(AItens);
  if ADesconto < 0 then
    raise Exception.Create('O desconto do orçamento não pode ser negativo.');
  LObservacoes := Trim(AObservacoes);
  if Length(LObservacoes) > TAMANHO_MAX_OBSERVACOES then
    raise Exception.CreateFmt('As observações devem ter no máximo %d caracteres.',
      [TAMANHO_MAX_OBSERVACOES]);

  LSubtotal := FPedidoVenda.SubtotalDosItens(AItens);
  LTotal := FPedidoVenda.TotalDoPedido(AItens, ADesconto);
  if ADesconto > LSubtotal then
    raise Exception.Create('Desconto do orçamento maior que o subtotal dos itens.');

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      { STATUS na cláusula WHERE protege contra edição de um rascunho que
        foi convertido por outra requisição entre a leitura e o UPDATE. }
      LQuery.SQL.Text :=
        'UPDATE PEDIDO_VENDA SET CLIENTE_ID = :CLI, SUBTOTAL = :SUB, ' +
        'DESCONTO = :DESC, TOTAL = :TOT, OBSERVACOES = :OBS ' +
        'WHERE ID = :ID AND STATUS = ''O'' AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
      LQuery.ParamByName('SUB').AsFloat := LSubtotal;
      LQuery.ParamByName('DESC').AsFloat := ADesconto;
      LQuery.ParamByName('TOT').AsFloat := LTotal;
      LQuery.ParamByName('OBS').AsString := LObservacoes;
      LQuery.ParamByName('ID').AsLargeInt := AOrcamentoId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;
      if LQuery.RowsAffected <> 1 then
        raise Exception.Create('Somente orçamentos em aberto podem ser alterados.');

      { os itens são substituídos por inteiro: mesmo cálculo da gravação
        de um orçamento novo, com PRECO_UNITARIO e VALOR_UNITARIO. }
      LQuery.SQL.Text := 'DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = :PED';
      LQuery.ParamByName('PED').AsLargeInt := AOrcamentoId;
      LQuery.ExecSQL;

      for I := 0 to High(AItens) do
      begin
        LQuery.SQL.Text :=
          'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, ' +
          'PRECO_UNITARIO, VALOR_UNITARIO, DESCONTO, VALOR_TOTAL, CFOP) ' +
          'VALUES (:PED, :PROD, :QTD, :PRECO, :VLR, :DESC, :TOT, :CFOP)';
        LQuery.ParamByName('PED').AsLargeInt := AOrcamentoId;
        LQuery.ParamByName('PROD').AsLargeInt := AItens[I].ProdutoId;
        LQuery.ParamByName('QTD').AsFloat := AItens[I].Quantidade;
        LQuery.ParamByName('PRECO').AsFloat := AItens[I].ValorUnitario;
        LQuery.ParamByName('VLR').AsFloat := AItens[I].ValorUnitario;
        LQuery.ParamByName('DESC').AsFloat := AItens[I].Desconto;
        LValorItem := (AItens[I].Quantidade * AItens[I].ValorUnitario) -
          AItens[I].Desconto;
        LQuery.ParamByName('TOT').AsFloat := LValorItem;
        if Trim(AItens[I].Cfop) <> '' then
          LQuery.ParamByName('CFOP').AsString := Trim(AItens[I].Cfop)
        else
          LQuery.ParamByName('CFOP').AsString := CFOP_PADRAO;
        LQuery.ExecSQL;
      end;

      RegistrarAuditoriaSegura('PEDIDO_VENDA', 'U', AOrcamentoId,
        ResumoAuditoria(['NUMERO=' + LNumero, 'STATUS=O',
          'TOTAL=' + FormatFloat('0.00', LTotalAntes)]),
        ResumoAuditoria(['NUMERO=' + LNumero, 'STATUS=O',
          'CLIENTE_ID=' + IntToStr(AClienteId),
          'ITENS=' + IntToStr(Length(AItens)),
          'TOTAL=' + FormatFloat('0.00', LTotal)]));

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

function TOrcamentoService.ExcluirOrcamento(AOrcamentoId: Int64): Boolean;
var
  LQuery: TSQLQuery;
  LNumero: string;
  LSubtotal, LDesconto, LTotal: Double;
begin
  Result := False;
  GarantirAberto(AOrcamentoId, LNumero, LSubtotal, LDesconto, LTotal);

  FConexao.IniciarTransacao;
  LQuery := TSQLQuery.Create(nil);
  try
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;

      LQuery.SQL.Text := 'DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = :PED';
      LQuery.ParamByName('PED').AsLargeInt := AOrcamentoId;
      LQuery.ExecSQL;

      LQuery.SQL.Text :=
        'DELETE FROM PEDIDO_VENDA WHERE ID = :ID AND STATUS = ''O'' ' +
        'AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('ID').AsLargeInt := AOrcamentoId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;
      if LQuery.RowsAffected <> 1 then
        raise Exception.Create('Somente orçamentos em aberto podem ser alterados.');

      RegistrarAuditoriaSegura('PEDIDO_VENDA', 'D', AOrcamentoId,
        ResumoAuditoria(['NUMERO=' + LNumero, 'STATUS=O',
          'TOTAL=' + FormatFloat('0.00', LTotal)]), '');

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
