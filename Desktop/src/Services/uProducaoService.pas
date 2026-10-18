unit uProducaoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 3 - Produção
  ------------------------------------------------------------
  Regras de negócio do MAPA DE PRODUÇÃO (Fase 2).

    - CriarMapa: gera o mapa a partir de um PEDIDO_VENDA, com itens
      e quantidades (inclusive parciais), impedindo que a soma do
      que já foi mapeado ultrapasse a quantidade pedida;
    - ItensPendentesDoPedido: itens do pedido com saldo a produzir
      (usado pelo "incluir tudo" da tela e pela validação);
    - CancelarMapa: cancela o mapa com motivo, cancela os itens e os
      talões ainda não concluídos e reavalia o pedido;
    - ReavaliarPedido: único ponto que decide o status do pedido
      (Pendente / Em produção / Produzido) a partir dos mapas e
      talões — máquina de estados em uPedidoStatus;
    - ProgressoMapa: quanto já foi produzido (talões concluídos),
      quanto está em produção e o total do mapa.

  Toda operação é transacional (IniciarTransacao / Confirmar /
  Cancelar) e registra auditoria em LOG_SISTEMA com usuário,
  data/hora e valores antes/depois.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, DB, uConexao, uPedidoStatus;

type
  EProducao = class(Exception);

  { Item a mapear: ItemPedidoId + quantidade (ProdutoId é conferido
    no banco a partir do próprio item do pedido). }
  TItemMapa = record
    ItemPedidoId: Int64;
    ProdutoId: Int64;
    Quantidade: Double;
  end;
  TItensMapa = array of TItemMapa;

const
  { Tolerância para comparação de quantidades (NUMERIC(15,4)) }
  TOLERANCIA_QTD = 0.0001;

type
  TProducaoService = class
  private
    FConexao: TConexao;
    function  NovaConsulta: TSQLQuery;
    function  ProximoNumeroMapa(AEmpresaId: Int64): Integer;
    function  QuantidadePedidaItem(AItemPedidoId: Int64; out APedidoId,
      AProdutoId: Int64): Double;
    function  QuantidadeMapeadaItem(AItemPedidoId: Int64;
      AExcetoMapaId: Int64 = 0): Double;
    procedure AplicarStatusPedido(APedidoId: Int64; const ANovoStatus: string);
  public
    constructor Create;

    { --- consultas de apoio (também usadas pela tela) --------------- }
    function  StatusMapa(AMapaId: Int64): string;
    function  MapaAtivoDoPedido(APedidoId: Int64): Int64;
    function  QuantidadeMapeadaDoItem(AItemPedidoId: Int64): Double;
    function  QuantidadePendenteDoItem(AItemPedidoId: Int64): Double;
    function  ItensPendentesDoPedido(APedidoId: Int64): TItensMapa;
    function  QuantidadeItensDoMapa(AMapaId: Int64): Integer;
    function  ProgressoMapa(AMapaId: Int64; out AProduzido, AEmProducao,
      ATotal: Double): Boolean;

    { --- operações ---------------------------------------------------- }
    function  CriarMapa(APedidoId: Int64; const AItens: TItensMapa;
      const AObservacao: string; ADataPrevista: TDate): Int64;
    procedure CancelarMapa(AMapaId: Int64; const AMotivo: string);
    procedure ReavaliarPedido(APedidoId: Int64);
  end;

implementation

uses
  uSessao, uAuditoria;

constructor TProducaoService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TProducaoService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConexao.Connection;
  Result.Transaction := FConexao.Transaction;
end;

function TProducaoService.ProximoNumeroMapa(AEmpresaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 1;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COALESCE(MAX(NUMERO), 0) + 1 AS PROX FROM MAPA_PRODUCAO ' +
      'WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('PROX').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.StatusMapa(AMapaId: Int64): string;
var
  LQuery: TSQLQuery;
begin
  Result := '';
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT STATUS FROM MAPA_PRODUCAO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('STATUS').AsString);
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.MapaAtivoDoPedido(APedidoId: Int64): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM MAPA_PRODUCAO ' +
      'WHERE PEDIDO_VENDA_ID = :PED AND STATUS IN (''ABERTO'', ''EM_PRODUCAO'') ' +
      'ORDER BY ID DESC';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.QuantidadePedidaItem(AItemPedidoId: Int64;
  out APedidoId, AProdutoId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  APedidoId := 0;
  AProdutoId := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE ' +
      'FROM ITEM_PEDIDO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AItemPedidoId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise EProducao.Create('Item do pedido não encontrado (ID ' +
        IntToStr(AItemPedidoId) + ').');
    APedidoId := LQuery.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;
    AProdutoId := LQuery.FieldByName('PRODUTO_ID').AsLargeInt;
    Result := LQuery.FieldByName('QUANTIDADE').AsFloat;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.QuantidadeMapeadaItem(AItemPedidoId: Int64;
  AExcetoMapaId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(MI.QUANTIDADE), 0) AS NUMERIC(18,4)) AS QTD ' +
      'FROM MAPA_PRODUCAO_ITEM MI ' +
      '  JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
      'WHERE MI.ITEM_PEDIDO_ID = :ITEM ' +
      '  AND M.STATUS <> ''CANCELADO'' AND M.ID <> :EXCETO';
    LQuery.ParamByName('ITEM').AsLargeInt := AItemPedidoId;
    LQuery.ParamByName('EXCETO').AsLargeInt := AExcetoMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('QTD').AsFloat;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.QuantidadeMapeadaDoItem(AItemPedidoId: Int64): Double;
begin
  Result := QuantidadeMapeadaItem(AItemPedidoId, 0);
end;

function TProducaoService.QuantidadePendenteDoItem(AItemPedidoId: Int64): Double;
var
  LPedidoId, LProdutoId: Int64;
  LPedida: Double;
begin
  LPedida := QuantidadePedidaItem(AItemPedidoId, LPedidoId, LProdutoId);
  Result := LPedida - QuantidadeMapeadaItem(AItemPedidoId, 0);
  if Result < 0 then
    Result := 0;
end;

function TProducaoService.ItensPendentesDoPedido(APedidoId: Int64): TItensMapa;
var
  LQuery: TSQLQuery;
  LItens: TItensMapa;
begin
  LItens := nil;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT I.ID, I.PRODUTO_ID, ' +
      '       CAST(I.QUANTIDADE - COALESCE((SELECT SUM(MI.QUANTIDADE) ' +
      '           FROM MAPA_PRODUCAO_ITEM MI ' +
      '             JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
      '           WHERE MI.ITEM_PEDIDO_ID = I.ID AND M.STATUS <> ''CANCELADO''), 0) ' +
      '         AS NUMERIC(18,4)) AS PENDENTE ' +
      'FROM ITEM_PEDIDO I ' +
      'WHERE I.PEDIDO_VENDA_ID = :PED ' +
      'ORDER BY I.ID';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      if LQuery.FieldByName('PENDENTE').AsFloat > TOLERANCIA_QTD then
      begin
        SetLength(LItens, Length(LItens) + 1);
        LItens[High(LItens)].ItemPedidoId := LQuery.FieldByName('ID').AsLargeInt;
        LItens[High(LItens)].ProdutoId := LQuery.FieldByName('PRODUTO_ID').AsLargeInt;
        LItens[High(LItens)].Quantidade := LQuery.FieldByName('PENDENTE').AsFloat;
      end;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
  Result := LItens;
end;

function TProducaoService.QuantidadeItensDoMapa(AMapaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS TOTAL FROM MAPA_PRODUCAO_ITEM ' +
      'WHERE MAPA_PRODUCAO_ID = :ID AND STATUS <> ''CANCELADO''';
    LQuery.ParamByName('ID').AsLargeInt := AMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('TOTAL').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.ProgressoMapa(AMapaId: Int64; out AProduzido,
  AEmProducao, ATotal: Double): Boolean;
var
  LQuery: TSQLQuery;
begin
  AProduzido := 0;
  AEmProducao := 0;
  ATotal := 0;
  Result := False;

  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT ' +
      '  CAST(COALESCE((SELECT SUM(MI.QUANTIDADE) FROM MAPA_PRODUCAO_ITEM MI ' +
      '      WHERE MI.MAPA_PRODUCAO_ID = :ID AND MI.STATUS <> ''CANCELADO''), 0) AS NUMERIC(18,4)) AS TOTAL, ' +
      '  CAST(COALESCE((SELECT SUM(T.QUANTIDADE) FROM TALAO T ' +
      '      JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
      '      WHERE MI.MAPA_PRODUCAO_ID = :ID AND T.STATUS = ''CONCLUIDO''), 0) AS NUMERIC(18,4)) AS PRODUZIDO, ' +
      '  CAST(COALESCE((SELECT SUM(T.QUANTIDADE) FROM TALAO T ' +
      '      JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
      '      WHERE MI.MAPA_PRODUCAO_ID = :ID AND T.STATUS IN (''GERADO'', ''IMPRESSO'', ''EM_PRODUCAO'')), 0) AS NUMERIC(18,4)) AS EM_PRODUCAO ' +
      'FROM RDB$DATABASE';
    LQuery.ParamByName('ID').AsLargeInt := AMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      ATotal := LQuery.FieldByName('TOTAL').AsFloat;
      AProduzido := LQuery.FieldByName('PRODUZIDO').AsFloat;
      AEmProducao := LQuery.FieldByName('EM_PRODUCAO').AsFloat;
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TProducaoService.AplicarStatusPedido(APedidoId: Int64;
  const ANovoStatus: string);
var
  LQuery: TSQLQuery;
  LAtual: string;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT STATUS FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise EProducao.Create('Pedido de venda não encontrado (ID ' +
        IntToStr(APedidoId) + ').');
    LAtual := Trim(LQuery.FieldByName('STATUS').AsString);
    LQuery.Close;

    if LAtual = ANovoStatus then
      Exit;

    ValidarTransicao(LAtual, ANovoStatus);

    LQuery.SQL.Text :=
      'UPDATE PEDIDO_VENDA SET STATUS = :STATUS WHERE ID = :ID';
    LQuery.ParamByName('STATUS').AsString := ANovoStatus;
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ExecSQL;

    RegistrarAuditoria('PEDIDO_VENDA', 'STATUS', APedidoId,
      'STATUS=' + LAtual,
      'STATUS=' + ANovoStatus + ' (' + DescricaoDoStatus(ANovoStatus) + ')');
  finally
    LQuery.Free;
  end;
end;

procedure TProducaoService.ReavaliarPedido(APedidoId: Int64);
var
  LQuery: TSQLQuery;
  LAtual: string;
  LAtivos: Integer;
  LProduzido, LTotal, LDummy: Double;
  LNovo: string;
begin
  LAtivos := 0;
  LProduzido := 0;
  LTotal := 0;

  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT STATUS, ' +
      '  (SELECT COUNT(*) FROM MAPA_PRODUCAO M ' +
      '     WHERE M.PEDIDO_VENDA_ID = :PED AND M.STATUS IN (''ABERTO'', ''EM_PRODUCAO'')) AS ATIVOS, ' +
      '  CAST(COALESCE((SELECT SUM(MI.QUANTIDADE) FROM MAPA_PRODUCAO_ITEM MI ' +
      '      JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
      '      WHERE M.PEDIDO_VENDA_ID = :PED AND M.STATUS <> ''CANCELADO''), 0) AS NUMERIC(18,4)) AS TOTAL, ' +
      '  CAST(COALESCE((SELECT SUM(T.QUANTIDADE) FROM TALAO T ' +
      '      JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
      '      JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
      '      WHERE M.PEDIDO_VENDA_ID = :PED AND T.STATUS = ''CONCLUIDO''), 0) AS NUMERIC(18,4)) AS PRODUZIDO ' +
      'FROM PEDIDO_VENDA WHERE ID = :PED';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;
    LAtual := Trim(LQuery.FieldByName('STATUS').AsString);
    LAtivos := LQuery.FieldByName('ATIVOS').AsInteger;
    LTotal := LQuery.FieldByName('TOTAL').AsFloat;
    LProduzido := LQuery.FieldByName('PRODUZIDO').AsFloat;
    LQuery.Close;
  finally
    LQuery.Free;
  end;

  // Pedido faturado ou cancelado não é alterado pela produção
  if (LAtual = PEDIDO_STATUS_FATURADO) or (LAtual = PEDIDO_STATUS_CANCELADO) then
    Exit;

  if LAtivos > 0 then
    LNovo := PEDIDO_STATUS_EM_PRODUCAO
  else if (LTotal > TOLERANCIA_QTD) and (LProduzido >= LTotal - TOLERANCIA_QTD) then
    LNovo := PEDIDO_STATUS_PRODUZIDO
  else if LProduzido > TOLERANCIA_QTD then
    LNovo := PEDIDO_STATUS_EM_PRODUCAO
  else
    LNovo := PEDIDO_STATUS_PENDENTE;

  AplicarStatusPedido(APedidoId, LNovo);
end;

// Gera o mapa de produção a partir de um pedido de venda.
function TProducaoService.CriarMapa(APedidoId: Int64;
  const AItens: TItensMapa; const AObservacao: string;
  ADataPrevista: TDate): Int64;
var
  LPed, LItem, LIns: TSQLQuery;
  LStatusPedido: string;
  LEmpresaId, LItemPedidoDoBanco, LProdutoId: Int64;
  LNumero: Integer;
  LIndice: Integer;
  LQuantidade, LPendente: Double;
  LResumo: string;
begin
  if Length(AItens) = 0 then
    raise EProducao.Create('Selecione ao menos um item do pedido para gerar o mapa.');

  FConexao.IniciarTransacao;
  LPed := NovaConsulta;
  LItem := NovaConsulta;
  LIns := NovaConsulta;
  try
    // --- Pedido ----------------------------------------------------------
    LPed.SQL.Text :=
      'SELECT STATUS, EMPRESA_ID, NUMERO FROM PEDIDO_VENDA WHERE ID = :ID';
    LPed.ParamByName('ID').AsLargeInt := APedidoId;
    LPed.Open;
    if LPed.IsEmpty then
      raise EProducao.Create('Pedido de venda não encontrado.');

    LStatusPedido := Trim(LPed.FieldByName('STATUS').AsString);
    if not PodeGerarMapa(LStatusPedido) then
      raise EProducao.CreateFmt(
        'O pedido %s está como "%s" e não pode gerar mapa de produção.',
        [Trim(LPed.FieldByName('NUMERO').AsString), DescricaoDoStatus(LStatusPedido)]);

    LEmpresaId := LPed.FieldByName('EMPRESA_ID').AsLargeInt;
    if LEmpresaId = 0 then
      LEmpresaId := TSessao.GetInstance.EmpresaId;
    LPed.Close;

    LNumero := ProximoNumeroMapa(LEmpresaId);

    // --- Cabeçalho do mapa ----------------------------------------------
    LIns.SQL.Text :=
      'INSERT INTO MAPA_PRODUCAO (EMPRESA_ID, NUMERO, PEDIDO_VENDA_ID, STATUS, ' +
      '  DATA_PREVISTA, OBSERVACAO, USUARIO_ID) ' +
      'VALUES (:EMP, :NUM, :PED, ''ABERTO'', :PREV, :OBS, :USR) RETURNING ID';
    LIns.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LIns.ParamByName('NUM').AsInteger := LNumero;
    LIns.ParamByName('PED').AsLargeInt := APedidoId;
    if ADataPrevista > 0 then
      LIns.ParamByName('PREV').AsDate := ADataPrevista
    else
      LIns.ParamByName('PREV').Clear;
    if Trim(AObservacao) = '' then
      LIns.ParamByName('OBS').Clear
    else
      LIns.ParamByName('OBS').AsString := Trim(AObservacao);
    LIns.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LIns.Open;
    Result := LIns.FieldByName('ID').AsLargeInt;
    LIns.Close;

    // --- Itens -----------------------------------------------------------
    LResumo := '';
    for LIndice := 0 to High(AItens) do
    begin
      if AItens[LIndice].ItemPedidoId <= 0 then
        raise EProducao.Create('Item do pedido inválido na seleção do mapa.');

      QuantidadePedidaItem(AItens[LIndice].ItemPedidoId, LItemPedidoDoBanco, LProdutoId);
      if LItemPedidoDoBanco <> APedidoId then
        raise EProducao.Create('O item informado não pertence ao pedido selecionado.');

      LQuantidade := AItens[LIndice].Quantidade;
      if LQuantidade <= 0 then
        raise EProducao.Create('Informe uma quantidade maior que zero para os itens do mapa.');

      LPendente := QuantidadePendenteDoItem(AItens[LIndice].ItemPedidoId);
      if LQuantidade > LPendente + TOLERANCIA_QTD then
        raise EProducao.CreateFmt(
          'A quantidade a produzir (%s) ultrapassa o saldo pendente do item (%s). ' +
          'Já foram mapeados %s de %s.',
          [FormatFloat('#,##0.####', LQuantidade), FormatFloat('#,##0.####', LPendente),
           FormatFloat('#,##0.####', QuantidadeMapeadaItem(AItens[LIndice].ItemPedidoId, 0)),
           FormatFloat('#,##0.####', QuantidadePedidaItem(AItens[LIndice].ItemPedidoId, LItemPedidoDoBanco, LProdutoId))]);

      LItem.SQL.Text :=
        'INSERT INTO MAPA_PRODUCAO_ITEM (MAPA_PRODUCAO_ID, ITEM_PEDIDO_ID, ' +
        '  PRODUTO_ID, QUANTIDADE, STATUS) ' +
        'VALUES (:MAPA, :ITEM, :PROD, :QTD, ''PENDENTE'')';
      LItem.ParamByName('MAPA').AsLargeInt := Result;
      LItem.ParamByName('ITEM').AsLargeInt := AItens[LIndice].ItemPedidoId;
      if AItens[LIndice].ProdutoId > 0 then
        LItem.ParamByName('PROD').AsLargeInt := AItens[LIndice].ProdutoId
      else
        LItem.ParamByName('PROD').AsLargeInt := LProdutoId;
      LItem.ParamByName('QTD').AsFloat := LQuantidade;
      LItem.ExecSQL;

      if LResumo <> '' then
        LResumo := LResumo + '; ';
      LResumo := LResumo + 'ITEM ' + IntToStr(AItens[LIndice].ItemPedidoId) +
        '=' + FormatFloat('#,##0.####', LQuantidade);
    end;

    // --- Auditoria + status do pedido ------------------------------------
    RegistrarAuditoria('MAPA_PRODUCAO', 'CRIAR', Result, '',
      'NUMERO=' + IntToStr(LNumero) + '; PEDIDO=' + IntToStr(APedidoId) +
      '; ' + LResumo);
    RegistrarAuditoriaSegura('MAPA_PRODUCAO_ITEM', 'CRIAR', Result, '',
      'ITENS=' + IntToStr(Length(AItens)));

    ReavaliarPedido(APedidoId);

    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LPed.Free;
    LItem.Free;
    LIns.Free;
    raise;
  end;

  LPed.Free;
  LItem.Free;
  LIns.Free;
end;

procedure TProducaoService.CancelarMapa(AMapaId: Int64;
  const AMotivo: string);
var
  LMapa, LQtd, LUpd: TSQLQuery;
  LPedidoId: Int64;
  LStatus: string;
  LConcluidos: Integer;
begin
  if Trim(AMotivo) = '' then
    raise EProducao.Create('Informe o motivo do cancelamento do mapa.');

  FConexao.IniciarTransacao;
  LMapa := NovaConsulta;
  LQtd := NovaConsulta;
  LUpd := NovaConsulta;
  try
    LMapa.SQL.Text :=
      'SELECT STATUS, PEDIDO_VENDA_ID FROM MAPA_PRODUCAO WHERE ID = :ID';
    LMapa.ParamByName('ID').AsLargeInt := AMapaId;
    LMapa.Open;
    if LMapa.IsEmpty then
      raise EProducao.Create('Mapa de produção não encontrado.');

    LStatus := Trim(LMapa.FieldByName('STATUS').AsString);
    LPedidoId := LMapa.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;
    LMapa.Close;

    if LStatus = 'CANCELADO' then
      raise EProducao.Create('Este mapa de produção já está cancelado.');

    // Não permitir cancelar mapa com produção já concluída
    LQtd.SQL.Text :=
      'SELECT COUNT(*) AS CONCLUIDOS FROM TALAO T ' +
      '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
      'WHERE MI.MAPA_PRODUCAO_ID = :ID AND T.STATUS = ''CONCLUIDO''';
    LQtd.ParamByName('ID').AsLargeInt := AMapaId;
    LQtd.Open;
    LConcluidos := LQtd.FieldByName('CONCLUIDOS').AsInteger;
    LQtd.Close;
    if LConcluidos > 0 then
      raise EProducao.CreateFmt(
        'Este mapa possui %d talão(ões) concluído(s) e não pode ser cancelado.',
        [LConcluidos]);

    // Cancela talões ainda não concluídos (Fase 3) e o mapa
    LUpd.SQL.Text :=
      'UPDATE TALAO SET STATUS = ''CANCELADO'', DATA_CANCELAMENTO = CURRENT_TIMESTAMP ' +
      'WHERE MAPA_PRODUCAO_ITEM_ID IN ' +
      '  (SELECT ID FROM MAPA_PRODUCAO_ITEM WHERE MAPA_PRODUCAO_ID = :ID) ' +
      '  AND STATUS <> ''CONCLUIDO''';
    LUpd.ParamByName('ID').AsLargeInt := AMapaId;
    LUpd.ExecSQL;

    LUpd.SQL.Text :=
      'UPDATE MAPA_PRODUCAO_ITEM SET STATUS = ''CANCELADO'' ' +
      'WHERE MAPA_PRODUCAO_ID = :ID';
    LUpd.ParamByName('ID').AsLargeInt := AMapaId;
    LUpd.ExecSQL;

    LUpd.SQL.Text :=
      'UPDATE MAPA_PRODUCAO SET STATUS = ''CANCELADO'', MOTIVO_CANCELAMENTO = :MOTIVO, ' +
      '  DATA_CANCELAMENTO = CURRENT_TIMESTAMP WHERE ID = :ID';
    LUpd.ParamByName('MOTIVO').AsString := Trim(AMotivo);
    LUpd.ParamByName('ID').AsLargeInt := AMapaId;
    LUpd.ExecSQL;

    RegistrarAuditoria('MAPA_PRODUCAO', 'CANCELAR', AMapaId,
      'STATUS=' + LStatus,
      'STATUS=CANCELADO; MOTIVO=' + Trim(AMotivo));

    ReavaliarPedido(LPedidoId);

    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LMapa.Free;
    LQtd.Free;
    LUpd.Free;
    raise;
  end;

  LMapa.Free;
  LQtd.Free;
  LUpd.Free;
end;

end.
