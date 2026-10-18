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

  { Resultado de uma bipagem de talão (Fase 4). Uma bipagem OK
    representa uma transição de status:
      GERADO/IMPRESSO -> EM_PRODUCAO (Etapa = 'INICIO')
      EM_PRODUCAO     -> CONCLUIDO   (Etapa = 'CONCLUSAO')
    Bipagens rejeitadas são registradas com DUPLICADO/INVALIDO. }
  TBipagemTalao = record
    TalaoId: Int64;
    NumeroTalao: Integer;
    CodigoBarras: string;
    Produto: string;
    Quantidade: Double;
    MapaId: Int64;
    MapaNumero: Integer;
    StatusAnterior: string;  { status do talão antes da bipagem }
    StatusNovo: string;      { status após a bipagem (igual ao anterior em erro) }
    Etapa: string;           { INICIO | CONCLUSAO | BIPAGEM }
    Resultado: string;       { OK | DUPLICADO | INVALIDO }
    Mensagem: string;        { mensagem amigável para o operador }
    MapaConcluido: Boolean;  { esta bipagem concluiu o mapa de produção }
  end;

const
  { Tolerância para comparação de quantidades (NUMERIC(15,4)) }
  TOLERANCIA_QTD = 0.0001;

type
  TProducaoService = class
  private
    FConexao: TConexao;
    function  NovaConsulta: TSQLQuery;
    function  ProximoNumeroMapa(AEmpresaId: Int64): Integer;
    function  ProximoNumeroTalao(AEmpresaId: Int64): Integer;
    function  NumeroDoMapa(AMapaId: Int64): Integer;
    function  LerConfiguracao(const AChave, APadrao: string): string;
    function  QuantidadePedidaItem(AItemPedidoId: Int64; out APedidoId,
      AProdutoId: Int64): Double;
    function  QuantidadeMapeadaItem(AItemPedidoId: Int64;
      AExcetoMapaId: Int64 = 0): Double;
    procedure AplicarStatusPedido(APedidoId: Int64; const ANovoStatus: string);
    procedure RegistrarBipagem(ATalaoId: Int64; const AEtapa, AOrigem,
      AResultado, AObservacao: string);
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

    { --- talões (Fase 3) ----------------------------------------------
      Modos (PRODUCAO_TALAO_MODO ou parâmetro):
        ITEM     - 1 talão com todas as unidades pendentes do item;
        UNIDADE  - 1 talão por unidade;
        LOTE     - talões de PRODUCAO_TALAO_LOTE unidades (último com o resto).
      CODIGO_BARRAS = 'T' + nº do talão com 6 dígitos (Code128B no LazReport;
      o dígito verificador é o próprio checksum do Code128). }
    function  ModoTalao: string;      { ITEM | UNIDADE | LOTE (CONFIGURACAO) }
    function  TaloesAtivosDoItem(AMapaItemId: Int64): Integer;
    function  QuantidadeTaloesDoItem(AMapaItemId: Int64): Double;
    function  GerarTaloes(AMapaItemId: Int64; const AModo: string;
      out AGerados: Integer): Integer;
    function  ImprimirTaloesDoMapa(AMapaId: Int64): Integer;
    procedure CancelarTalao(ATalaoId: Int64; const AMotivo: string);

    { --- bipagem (Fase 4) -----------------------------------------------
      Registra a leitura do código de barras de um talão e move o status:
        GERADO/IMPRESSO -> EM_PRODUCAO (etapa INICIO)
        EM_PRODUCAO     -> CONCLUIDO   (etapa CONCLUSAO)
      Ao concluir o último talão: item -> CONCLUIDO e, se todo o mapa
      terminou, mapa -> CONCLUIDO e pedido reavaliado (Produzido).
      Bipagens inválidas/duplicadas também são gravadas em TALAO_BIPAGEM
      para rastreabilidade. AOrigem: LEITOR | MANUAL | SISTEMA. }
    function  BiparTalao(const ACodigoBarras: string;
      const AOrigem: string = 'LEITOR'): TBipagemTalao;

    { --- relatório de talões (Fase 4) ---------------------------------
      Caminho do .lrf usado na visualização e impressão. O usuário final
      pode trocar o arquivo em "Relatório ▼ → Configurar" (fica gravado
      na CONFIGURACAO da empresa, chave PRODUCAO_TALAO_RELATORIO);
      caminho vazio restaura o padrão relatorios\talao.lrf ao lado do
      exe. }
    function  CaminhoRelatorioTalao: string;
    procedure DefinirCaminhoRelatorioTalao(const ACaminho: string);
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

{ =====================================================================
  TALÕES (Fase 3)
  ===================================================================== }

function TProducaoService.LerConfiguracao(const AChave, APadrao: string): string;
var
  LQuery: TSQLQuery;
begin
  Result := APadrao;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 VALOR FROM CONFIGURACAO ' +
      'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL) ' +
      'ORDER BY EMPRESA_ID DESC';
    LQuery.ParamByName('CHAVE').AsString := AChave;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if (not LQuery.IsEmpty) and (Trim(LQuery.FieldByName('VALOR').AsString) <> '') then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.ModoTalao: string;
begin
  Result := UpperCase(LerConfiguracao('PRODUCAO_TALAO_MODO', 'UNIDADE'));
  if (Result <> 'ITEM') and (Result <> 'UNIDADE') and (Result <> 'LOTE') then
    Result := 'UNIDADE';
end;

function TProducaoService.NumeroDoMapa(AMapaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT NUMERO FROM MAPA_PRODUCAO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('NUMERO').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.ProximoNumeroTalao(AEmpresaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 1;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COALESCE(MAX(NUMERO), 0) + 1 AS PROX FROM TALAO ' +
      'WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('PROX').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.TaloesAtivosDoItem(AMapaItemId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS QTDT FROM TALAO ' +
      'WHERE MAPA_PRODUCAO_ITEM_ID = :ITEM AND STATUS <> ''CANCELADO''';
    LQuery.ParamByName('ITEM').AsLargeInt := AMapaItemId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('QTDT').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.QuantidadeTaloesDoItem(AMapaItemId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(QUANTIDADE), 0) AS NUMERIC(18,4)) AS QTD ' +
      'FROM TALAO ' +
      'WHERE MAPA_PRODUCAO_ITEM_ID = :ITEM AND STATUS <> ''CANCELADO''';
    LQuery.ParamByName('ITEM').AsLargeInt := AMapaItemId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('QTD').AsFloat;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.GerarTaloes(AMapaItemId: Int64; const AModo: string;
  out AGerados: Integer): Integer;
var
  LItem, LTaloes, LIns, LUpd: TSQLQuery;
  LMapaId, LEmpresaId, LTalaoId: Int64;
  LQtdItem, LQtdTaloes, LPendente, LLote, LQtdTalao: Double;
  LStatusItem, LStatusMapa, LModo, LCodigo: string;
  LNumero, LSeqBase, LTotal, LIndice: Integer;
begin
  AGerados := 0;
  Result := 0;

  LModo := UpperCase(Trim(AModo));
  if LModo = '' then
    LModo := UpperCase(LerConfiguracao('PRODUCAO_TALAO_MODO', 'UNIDADE'));
  if (LModo <> 'ITEM') and (LModo <> 'UNIDADE') and (LModo <> 'LOTE') then
    raise EProducao.Create('Modo de talão inválido: use ITEM, UNIDADE ou LOTE.');

  LLote := 10;
  if LModo = 'LOTE' then
  begin
    LLote := StrToIntDef(LerConfiguracao('PRODUCAO_TALAO_LOTE', '10'), 10);
    if LLote < 1 then
      raise EProducao.Create(
        'Configure PRODUCAO_TALAO_LOTE com um número maior que zero.');
  end;

  FConexao.IniciarTransacao;
  LItem := NovaConsulta;
  LTaloes := NovaConsulta;
  LIns := NovaConsulta;
  LUpd := NovaConsulta;
  try
    try
      // --- item + mapa ------------------------------------------------
      LItem.SQL.Text :=
        'SELECT MI.QUANTIDADE, MI.STATUS, MI.MAPA_PRODUCAO_ID, ' +
        '  M.STATUS AS MAPA_STATUS, M.EMPRESA_ID ' +
        'FROM MAPA_PRODUCAO_ITEM MI ' +
        '  JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
        'WHERE MI.ID = :ID';
      LItem.ParamByName('ID').AsLargeInt := AMapaItemId;
      LItem.Open;
      if LItem.IsEmpty then
        raise EProducao.Create('Item do mapa de produção não encontrado.');

      LQtdItem := LItem.FieldByName('QUANTIDADE').AsFloat;
      LStatusItem := Trim(LItem.FieldByName('STATUS').AsString);
      LMapaId := LItem.FieldByName('MAPA_PRODUCAO_ID').AsLargeInt;
      LStatusMapa := Trim(LItem.FieldByName('MAPA_STATUS').AsString);
      LEmpresaId := LItem.FieldByName('EMPRESA_ID').AsLargeInt;
      LItem.Close;

      if (LStatusMapa <> 'ABERTO') and (LStatusMapa <> 'EM_PRODUCAO') then
        raise EProducao.CreateFmt(
          'O mapa nº %d está como "%s": talões só podem ser gerados em mapa aberto ou em produção.',
          [NumeroDoMapa(LMapaId), LStatusMapa]);

      if (LStatusItem <> 'PENDENTE') and (LStatusItem <> 'EM_PRODUCAO') then
        raise EProducao.CreateFmt(
          'O item do mapa nº %d está como "%s" e não aceita novos talões.',
          [NumeroDoMapa(LMapaId), LStatusItem]);

      // --- quanto já foi taloeado --------------------------------------
      LTaloes.SQL.Text :=
        'SELECT COUNT(*) AS QTDT, ' +
        '  CAST(COALESCE(SUM(QUANTIDADE), 0) AS NUMERIC(18,4)) AS QTDQ ' +
        'FROM TALAO ' +
        'WHERE MAPA_PRODUCAO_ITEM_ID = :ITEM AND STATUS <> ''CANCELADO''';
      LTaloes.ParamByName('ITEM').AsLargeInt := AMapaItemId;
      LTaloes.Open;
      LSeqBase := LTaloes.FieldByName('QTDT').AsInteger;
      LQtdTaloes := LTaloes.FieldByName('QTDQ').AsFloat;
      LTaloes.Close;

      LPendente := LQtdItem - LQtdTaloes;
      if LPendente <= TOLERANCIA_QTD then
        raise EProducao.CreateFmt(
          'Todas as unidades deste item já possuem talão (%s de %s).',
          [FormatFloat('#,##0.####', LQtdTaloes),
           FormatFloat('#,##0.####', LQtdItem)]);

      // --- quantos talões faltam ---------------------------------------
      if LModo = 'UNIDADE' then
      begin
        if Abs(LPendente - Trunc(LPendente + 0.5)) > TOLERANCIA_QTD then
          raise EProducao.Create(
            'No modo por unidade a quantidade precisa ser inteira. ' +
            'Ajuste o item ou use o modo LOTE.');
        LTotal := Trunc(LPendente + 0.5);
      end
      else if LModo = 'LOTE' then
        LTotal := Trunc((LPendente - TOLERANCIA_QTD) / LLote) + 1  { teto }
      else
        LTotal := 1;   { ITEM: tudo em um talão }
      if LTotal < 1 then
        LTotal := 1;

      // --- gera os talões ----------------------------------------------
      for LIndice := 1 to LTotal do
      begin
        if LModo = 'UNIDADE' then
          LQtdTalao := 1
        else if LModo = 'LOTE' then
        begin
          if LIndice < LTotal then
            LQtdTalao := LLote
          else
            LQtdTalao := LPendente - (LTotal - 1) * LLote;   { resto }
        end
        else
          LQtdTalao := LPendente;   { ITEM }

        if LQtdTalao <= TOLERANCIA_QTD then
          Break;

        LNumero := ProximoNumeroTalao(LEmpresaId);
        LCodigo := Format('T%.6d', [LNumero]);

        LIns.SQL.Text :=
          'INSERT INTO TALAO (EMPRESA_ID, NUMERO, MAPA_PRODUCAO_ITEM_ID, ' +
          '  SEQUENCIA, QUANTIDADE, CODIGO_BARRAS, STATUS, DATA_GERACAO, ' +
          '  QTD_IMPRESSOES, USUARIO_ID) ' +
          'VALUES (:EMP, :NUM, :ITEM, :SEQ, :QTD, :COD, ''GERADO'', ' +
          '  CURRENT_TIMESTAMP, 0, :USR) RETURNING ID';
        LIns.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LIns.ParamByName('NUM').AsInteger := LNumero;
        LIns.ParamByName('ITEM').AsLargeInt := AMapaItemId;
        LIns.ParamByName('SEQ').AsInteger := LSeqBase + LIndice;
        LIns.ParamByName('QTD').AsFloat := LQtdTalao;
        LIns.ParamByName('COD').AsString := LCodigo;
        LIns.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
        LIns.Open;
        LTalaoId := LIns.FieldByName('ID').AsLargeInt;
        LIns.Close;

        RegistrarAuditoria('TALAO', 'GERAR', LTalaoId, '',
          'NUMERO=' + IntToStr(LNumero) +
          '; MAPA=' + IntToStr(NumeroDoMapa(LMapaId)) +
          '; ITEM=' + IntToStr(AMapaItemId) +
          '; QTD=' + FormatFloat('#,##0.####', LQtdTalao) +
          '; MODO=' + LModo);

        Inc(AGerados);
        Result := LNumero;
      end;

      // --- o item passa a em produção ----------------------------------
      if LStatusItem = 'PENDENTE' then
      begin
        LUpd.SQL.Text :=
          'UPDATE MAPA_PRODUCAO_ITEM SET STATUS = ''EM_PRODUCAO'' ' +
          'WHERE ID = :ID';
        LUpd.ParamByName('ID').AsLargeInt := AMapaItemId;
        LUpd.ExecSQL;
        RegistrarAuditoria('MAPA_PRODUCAO_ITEM', 'STATUS', AMapaItemId,
          'PENDENTE', 'EM_PRODUCAO');
      end;

      // --- mapa aberto também passa a em produção (1º talão gerado) ----
      if LStatusMapa = 'ABERTO' then
      begin
        LUpd.SQL.Text :=
          'UPDATE MAPA_PRODUCAO SET STATUS = ''EM_PRODUCAO'' WHERE ID = :ID';
        LUpd.ParamByName('ID').AsLargeInt := LMapaId;
        LUpd.ExecSQL;
        RegistrarAuditoria('MAPA_PRODUCAO', 'STATUS', LMapaId,
          'ABERTO', 'EM_PRODUCAO');
      end;

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LItem.Free;
    LTaloes.Free;
    LIns.Free;
    LUpd.Free;
  end;
end;

function TProducaoService.ImprimirTaloesDoMapa(AMapaId: Int64): Integer;
var
  LLista, LUpd: TSQLQuery;
  LStatusMapa, LStatus: string;
  LTalaoId: Int64;
  LNumero, LImpressoes: Integer;
begin
  Result := 0;

  LStatusMapa := StatusMapa(AMapaId);
  if (LStatusMapa <> 'ABERTO') and (LStatusMapa <> 'EM_PRODUCAO') then
    raise EProducao.CreateFmt(
      'O mapa nº %d está como "%s": não é possível imprimir talões.',
      [NumeroDoMapa(AMapaId), LStatusMapa]);

  FConexao.IniciarTransacao;
  LLista := NovaConsulta;
  LUpd := NovaConsulta;
  try
    try
      LLista.SQL.Text :=
        'SELECT T.ID, T.NUMERO, T.STATUS, ' +
        '  COALESCE(T.QTD_IMPRESSOES, 0) AS IMP ' +
        'FROM TALAO T ' +
        '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
        'WHERE MI.MAPA_PRODUCAO_ID = :MAPA AND T.STATUS <> ''CANCELADO'' ' +
        'ORDER BY T.NUMERO';
      LLista.ParamByName('MAPA').AsLargeInt := AMapaId;
      LLista.Open;
      if LLista.IsEmpty then
        raise EProducao.CreateFmt(
          'O mapa nº %d não tem talões para imprimir. Gere os talões primeiro.',
          [NumeroDoMapa(AMapaId)]);

      while not LLista.EOF do
      begin
        LTalaoId := LLista.FieldByName('ID').AsLargeInt;
        LNumero := LLista.FieldByName('NUMERO').AsInteger;
        LStatus := Trim(LLista.FieldByName('STATUS').AsString);
        LImpressoes := LLista.FieldByName('IMP').AsInteger;

        LUpd.SQL.Text :=
          'UPDATE TALAO SET ' +
          '  STATUS = CASE WHEN STATUS = ''GERADO'' THEN ''IMPRESSO'' ELSE STATUS END, ' +
          '  QTD_IMPRESSOES = COALESCE(QTD_IMPRESSOES, 0) + 1, ' +
          '  DATA_IMPRESSAO = CURRENT_TIMESTAMP ' +
          'WHERE ID = :ID';
        LUpd.ParamByName('ID').AsLargeInt := LTalaoId;
        LUpd.ExecSQL;

        if LStatus = 'GERADO' then
          RegistrarAuditoria('TALAO', 'IMPRESSAO', LTalaoId, 'GERADO', 'IMPRESSO')
        else
        begin
          { reimpresão: evento rastreado em TALAO_BIPAGEM (origem SISTEMA) }
          LUpd.SQL.Text :=
            'INSERT INTO TALAO_BIPAGEM (TALAO_ID, USUARIO_ID, DATA_HORA, ' +
            '  ETAPA, ORIGEM, RESULTADO) VALUES ' +
            '  (:TAL, :USR, CURRENT_TIMESTAMP, ''REIMPRESSAO'', ''SISTEMA'', ''OK'')';
          LUpd.ParamByName('TAL').AsLargeInt := LTalaoId;
          LUpd.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
          LUpd.ExecSQL;
          RegistrarAuditoria('TALAO', 'REIMPRESSAO', LTalaoId, LStatus,
            'NUMERO=' + IntToStr(LNumero) +
            '; IMPRESSOES=' + IntToStr(LImpressoes + 1));
        end;

        Inc(Result);
        LLista.Next;
      end;
      LLista.Close;

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LLista.Free;
    LUpd.Free;
  end;
end;

procedure TProducaoService.CancelarTalao(ATalaoId: Int64; const AMotivo: string);
var
  LTalao, LUpd: TSQLQuery;
  LStatus, LStatusItem: string;
  LNumero: Integer;
  LItemId: Int64;
begin
  if Trim(AMotivo) = '' then
    raise EProducao.Create('Informe o motivo do cancelamento do talão.');

  FConexao.IniciarTransacao;
  LTalao := NovaConsulta;
  LUpd := NovaConsulta;
  try
    try
      LTalao.SQL.Text :=
        'SELECT T.NUMERO, T.STATUS, T.MAPA_PRODUCAO_ITEM_ID, ' +
        '  MI.STATUS AS ITEM_STATUS ' +
        'FROM TALAO T ' +
        '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
        'WHERE T.ID = :ID';
      LTalao.ParamByName('ID').AsLargeInt := ATalaoId;
      LTalao.Open;
      if LTalao.IsEmpty then
        raise EProducao.Create('Talão não encontrado.');
      LNumero := LTalao.FieldByName('NUMERO').AsInteger;
      LStatus := Trim(LTalao.FieldByName('STATUS').AsString);
      LItemId := LTalao.FieldByName('MAPA_PRODUCAO_ITEM_ID').AsLargeInt;
      LStatusItem := Trim(LTalao.FieldByName('ITEM_STATUS').AsString);
      LTalao.Close;

      if LStatus = 'CANCELADO' then
        raise EProducao.CreateFmt('O talão nº %d já está cancelado.', [LNumero]);
      if LStatus = 'CONCLUIDO' then
        raise EProducao.CreateFmt(
          'O talão nº %d já foi concluído e não pode ser cancelado.', [LNumero]);
      if LStatus = 'EM_PRODUCAO' then
        raise EProducao.CreateFmt(
          'O talão nº %d já está em produção (bipado). ' +
          'Finalize-o ou cancele o mapa de produção.', [LNumero]);

      LUpd.SQL.Text :=
        'UPDATE TALAO SET STATUS = ''CANCELADO'', ' +
        '  DATA_CANCELAMENTO = CURRENT_TIMESTAMP, OBSERVACAO = :OBS ' +
        'WHERE ID = :ID';
      LUpd.ParamByName('ID').AsLargeInt := ATalaoId;
      LUpd.ParamByName('OBS').AsString := Copy(Trim(AMotivo), 1, 255);
      LUpd.ExecSQL;

      RegistrarAuditoria('TALAO', 'CANCELAR', ATalaoId, LStatus,
        'CANCELADO; MOTIVO=' + Trim(AMotivo));

      { sem talão ativo, o item volta a pendente }
      if LStatusItem = 'EM_PRODUCAO' then
      begin
        LUpd.SQL.Text :=
          'SELECT COUNT(*) AS QTDT FROM TALAO ' +
          'WHERE MAPA_PRODUCAO_ITEM_ID = :ITEM AND STATUS <> ''CANCELADO''';
        LUpd.ParamByName('ITEM').AsLargeInt := LItemId;
        LUpd.Open;
        if LUpd.FieldByName('QTDT').AsInteger = 0 then
        begin
          LUpd.Close;
          LUpd.SQL.Text :=
            'UPDATE MAPA_PRODUCAO_ITEM SET STATUS = ''PENDENTE'' ' +
            'WHERE ID = :ID';
          LUpd.ParamByName('ID').AsLargeInt := LItemId;
          LUpd.ExecSQL;
          RegistrarAuditoria('MAPA_PRODUCAO_ITEM', 'STATUS', LItemId,
            'EM_PRODUCAO', 'PENDENTE');
        end
        else
          LUpd.Close;
      end;

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LTalao.Free;
    LUpd.Free;
  end;
end;

{ ------------------------------------------------------------ 
  Fase 4 - BIPAGEM DE TALÕES
  ------------------------------------------------------------ }

procedure TProducaoService.RegistrarBipagem(ATalaoId: Int64; const AEtapa,
  AOrigem, AResultado, AObservacao: string);
var
  LIns: TSQLQuery;
begin
  LIns := NovaConsulta;
  try
    LIns.SQL.Text :=
      'INSERT INTO TALAO_BIPAGEM ' +
      '  (TALAO_ID, USUARIO_ID, DATA_HORA, ETAPA, ORIGEM, RESULTADO, OBSERVACAO) ' +
      'VALUES ' +
      '  (:TAL, :USR, CURRENT_TIMESTAMP, :ETAPA, :ORI, :RES, :OBS)';
    LIns.ParamByName('TAL').AsLargeInt := ATalaoId;
    LIns.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LIns.ParamByName('ETAPA').AsString := AEtapa;
    LIns.ParamByName('ORI').AsString := AOrigem;
    LIns.ParamByName('RES').AsString := AResultado;
    if AObservacao = '' then
      LIns.ParamByName('OBS').Clear
    else
      LIns.ParamByName('OBS').AsString := AObservacao;
    LIns.ExecSQL;
  finally
    LIns.Free;
  end;
end;

function TProducaoService.BiparTalao(const ACodigoBarras: string;
  const AOrigem: string): TBipagemTalao;
var
  LTalao, LUpd: TSQLQuery;
  LCodigo: string;
  LTalaoId, LItemId, LMapaId, LPedidoId: Int64;
  LNumero, LMapaNumero: Integer;
  LStatus, LStatusMapa: string;
  LConcluiuMapa: Boolean;
begin
  { resultado padrão: inválido — preenchido conforme a análise }
  Result.TalaoId := 0;
  Result.NumeroTalao := 0;
  Result.CodigoBarras := Trim(UpperCase(ACodigoBarras));
  Result.Produto := '';
  Result.Quantidade := 0;
  Result.MapaId := 0;
  Result.MapaNumero := 0;
  Result.StatusAnterior := '';
  Result.StatusNovo := '';
  Result.Etapa := 'BIPAGEM';
  Result.Resultado := 'INVALIDO';
  Result.Mensagem := '';
  Result.MapaConcluido := False;

  LCodigo := Result.CodigoBarras;
  if LCodigo = '' then
  begin
    Result.Mensagem := 'Informe o código de barras do talão.';
    Exit;
  end;

  { digitação manual só com o número (ex.: "3") vira o formato T000003 }
  if (Length(LCodigo) <= 9) and (LCodigo[1] >= '0') and (LCodigo[1] <= '9') then
    LCodigo := Format('T%.6d', [StrToIntDef(LCodigo, 0)]);
  Result.CodigoBarras := LCodigo;

  FConexao.IniciarTransacao;
  LTalao := NovaConsulta;
  LUpd := NovaConsulta;
  try
    try
      LTalao.SQL.Text :=
        'SELECT T.ID, T.NUMERO, T.STATUS, T.QUANTIDADE, ' +
        '  T.MAPA_PRODUCAO_ITEM_ID, ' +
        '  M.ID AS MAPA_ID, M.NUMERO AS MAPA_NUMERO, M.STATUS AS MAPA_STATUS, ' +
        '  M.PEDIDO_VENDA_ID, PR.DESCRICAO AS PRODUTO ' +
        'FROM TALAO T ' +
        '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
        '  JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
        '  LEFT JOIN PRODUTO PR ON PR.ID = MI.PRODUTO_ID ' +
        'WHERE T.CODIGO_BARRAS = :COD';
      LTalao.ParamByName('COD').AsString := LCodigo;
      LTalao.Open;

      if LTalao.IsEmpty then
      begin
        { tentativa de leitura inválida fica registrada para rastreio;
          TALAO_ID = 0 marca "código inexistente" (sem FK na tabela) }
        RegistrarBipagem(0, 'BIPAGEM', AOrigem, 'INVALIDO',
          'Código não encontrado: ' + LCodigo);
        RegistrarAuditoria('TALAO_BIPAGEM', 'BIPAGEM', 0, '',
          'CODIGO=' + LCodigo + '; RESULTADO=INVALIDO; ORIGEM=' + AOrigem);
        FConexao.Confirmar;
        Result.Mensagem := Format(
          'Código de barras "%s" não corresponde a nenhum talão.', [LCodigo]);
        Exit;
      end;

      LTalaoId := LTalao.FieldByName('ID').AsLargeInt;
      LNumero := LTalao.FieldByName('NUMERO').AsInteger;
      LStatus := Trim(LTalao.FieldByName('STATUS').AsString);
      LItemId := LTalao.FieldByName('MAPA_PRODUCAO_ITEM_ID').AsLargeInt;
      LMapaId := LTalao.FieldByName('MAPA_ID').AsLargeInt;
      LMapaNumero := LTalao.FieldByName('MAPA_NUMERO').AsInteger;
      LStatusMapa := Trim(LTalao.FieldByName('MAPA_STATUS').AsString);
      LPedidoId := LTalao.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;

      Result.TalaoId := LTalaoId;
      Result.NumeroTalao := LNumero;
      Result.Quantidade := LTalao.FieldByName('QUANTIDADE').AsFloat;
      Result.Produto := Trim(LTalao.FieldByName('PRODUTO').AsString);
      Result.MapaId := LMapaId;
      Result.MapaNumero := LMapaNumero;
      Result.StatusAnterior := LStatus;
      Result.StatusNovo := LStatus;
      LTalao.Close;

      { --- bipagens rejeitadas (mas auditadas) ----------------------- }
      if (LStatusMapa = 'CANCELADO') or (LStatus = 'CANCELADO') then
      begin
        RegistrarBipagem(LTalaoId, 'BIPAGEM', AOrigem, 'INVALIDO',
          'Talão ou mapa cancelado');
        RegistrarAuditoria('TALAO_BIPAGEM', 'BIPAGEM', LTalaoId, LStatus,
          'RESULTADO=INVALIDO; MOTIVO=CANCELADO');
        FConexao.Confirmar;
        Result.Mensagem := Format(
          'Talão %d não pode ser bipado: está cancelado.', [LNumero]);
        Exit;
      end;

      if LStatusMapa = 'CONCLUIDO' then
      begin
        RegistrarBipagem(LTalaoId, 'BIPAGEM', AOrigem, 'DUPLICADO',
          'Mapa já concluído');
        FConexao.Confirmar;
        Result.Mensagem := Format(
          'Talão %d não pode ser bipado: o mapa nº %d já foi concluído.',
          [LNumero, LMapaNumero]);
        Result.Resultado := 'DUPLICADO';
        Exit;
      end;

      if LStatus = 'CONCLUIDO' then
      begin
        RegistrarBipagem(LTalaoId, 'BIPAGEM', AOrigem, 'DUPLICADO',
          'Talão já concluído');
        RegistrarAuditoria('TALAO_BIPAGEM', 'BIPAGEM', LTalaoId, LStatus,
          'RESULTADO=DUPLICADO; MOTIVO=JA_CONCLUIDO');
        FConexao.Confirmar;
        Result.Resultado := 'DUPLICADO';
        Result.Mensagem := Format(
          'Talão %d já foi concluído anteriormente.', [LNumero]);
        Exit;
      end;

      { --- bipagens válidas: transição de status --------------------- }
      if (LStatus = 'GERADO') or (LStatus = 'IMPRESSO') then
      begin
        { INICIO: talão entra em produção }
        LUpd.SQL.Text :=
          'UPDATE TALAO SET STATUS = ''EM_PRODUCAO'', ' +
          '  DATA_INICIO = CURRENT_TIMESTAMP ' +
          'WHERE ID = :ID';
        LUpd.ParamByName('ID').AsLargeInt := LTalaoId;
        LUpd.ExecSQL;
        RegistrarAuditoria('TALAO', 'BIPAGEM', LTalaoId, LStatus, 'EM_PRODUCAO');

        { item: pendente -> em produção }
        LUpd.Close;
        LUpd.SQL.Text :=
          'UPDATE MAPA_PRODUCAO_ITEM SET STATUS = ''EM_PRODUCAO'' ' +
          'WHERE ID = :ID AND STATUS = ''PENDENTE''';
        LUpd.ParamByName('ID').AsLargeInt := LItemId;
        LUpd.ExecSQL;

        { mapa: aberto -> em produção (fica registrado o início) }
        LUpd.Close;
        LUpd.SQL.Text :=
          'UPDATE MAPA_PRODUCAO SET STATUS = ''EM_PRODUCAO'', ' +
          '  DATA_INICIO = COALESCE(DATA_INICIO, CURRENT_TIMESTAMP) ' +
          'WHERE ID = :ID AND STATUS = ''ABERTO''';
        LUpd.ParamByName('ID').AsLargeInt := LMapaId;
        LUpd.ExecSQL;

        Result.Etapa := 'INICIO';
        Result.StatusNovo := 'EM_PRODUCAO';
        Result.Mensagem := Format('Talão %d iniciado. Bom trabalho!', [LNumero]);
      end
      else
      begin
        { EM_PRODUCAO -> CONCLUSAO }
        LUpd.SQL.Text :=
          'UPDATE TALAO SET STATUS = ''CONCLUIDO'', ' +
          '  DATA_CONCLUSAO = CURRENT_TIMESTAMP ' +
          'WHERE ID = :ID';
        LUpd.ParamByName('ID').AsLargeInt := LTalaoId;
        LUpd.ExecSQL;
        RegistrarAuditoria('TALAO', 'BIPAGEM', LTalaoId, 'EM_PRODUCAO',
          'CONCLUIDO');

        { o item termina quando todos os seus talões forem concluídos }
        LUpd.Close;
        LUpd.SQL.Text :=
          'SELECT COUNT(*) AS FALTAM FROM TALAO ' +
          'WHERE MAPA_PRODUCAO_ITEM_ID = :ITEM ' +
          '  AND STATUS NOT IN (''CONCLUIDO'', ''CANCELADO'')';
        LUpd.ParamByName('ITEM').AsLargeInt := LItemId;
        LUpd.Open;
        if LUpd.FieldByName('FALTAM').AsInteger = 0 then
        begin
          LUpd.Close;
          LUpd.SQL.Text :=
            'UPDATE MAPA_PRODUCAO_ITEM SET STATUS = ''CONCLUIDO'' ' +
            'WHERE ID = :ID';
          LUpd.ParamByName('ID').AsLargeInt := LItemId;
          LUpd.ExecSQL;
          RegistrarAuditoria('MAPA_PRODUCAO_ITEM', 'BIPAGEM', LItemId,
            'EM_PRODUCAO', 'CONCLUIDO');
        end
        else
          LUpd.Close;

        { o mapa termina quando todos os itens estiverem finalizados }
        LUpd.SQL.Text :=
          'SELECT COUNT(*) AS FALTAM FROM MAPA_PRODUCAO_ITEM ' +
          'WHERE MAPA_PRODUCAO_ID = :MAPA ' +
          '  AND STATUS NOT IN (''CONCLUIDO'', ''CANCELADO'')';
        LUpd.ParamByName('MAPA').AsLargeInt := LMapaId;
        LUpd.Open;
        LConcluiuMapa := LUpd.FieldByName('FALTAM').AsInteger = 0;
        LUpd.Close;

        if LConcluiuMapa then
        begin
          LUpd.SQL.Text :=
            'UPDATE MAPA_PRODUCAO SET STATUS = ''CONCLUIDO'', ' +
            '  DATA_FIM = CURRENT_TIMESTAMP ' +
            'WHERE ID = :ID';
          LUpd.ParamByName('ID').AsLargeInt := LMapaId;
          LUpd.ExecSQL;
          RegistrarAuditoria('MAPA_PRODUCAO', 'CONCLUSAO', LMapaId,
            'EM_PRODUCAO', 'CONCLUIDO');
          Result.MapaConcluido := True;
        end;

        { o pedido é sempre reavaliado após uma conclusão de talão:
          ele só vira "Produzido" quando toda a quantidade mapeada
          foi produzida (ReavaliarPedido decide) }
        ReavaliarPedido(LPedidoId);

        Result.Etapa := 'CONCLUSAO';
        Result.StatusNovo := 'CONCLUIDO';
        Result.Mensagem := Format('Talão %d concluído com sucesso.', [LNumero]);
        if LConcluiuMapa then
          Result.Mensagem := Result.Mensagem + sLineBreak +
            Format('Mapa nº %d concluído — produção finalizada!', [LMapaNumero]);
      end;

      { registro da bipagem aceita }
      RegistrarBipagem(LTalaoId, Result.Etapa, AOrigem, 'OK', '');
      Result.Resultado := 'OK';

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LTalao.Free;
    LUpd.Free;
  end;
end;

{ ------------------------------------------------------------
  Relatório de talões - caminho configurável (Fase 4)
  ------------------------------------------------------------ }

function TProducaoService.CaminhoRelatorioTalao: string;
var
  LConfigurado: string;
begin
  LConfigurado := LerConfiguracao('PRODUCAO_TALAO_RELATORIO', '');
  if LConfigurado = '' then
  begin
    { padrão: o exe roda de Desktop\bin\ e relatorios\talao.lrf
      fica copiado ao lado dele pelo build_desktop.bat }
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
      'relatorios' + PathDelim + 'talao.lrf';
    Exit;
  end;

  Result := LConfigurado;
  { caminho relativo (ex.: "meus_relatorios\talao.lrf") é resolvido
    a partir da pasta do exe }
  if ExtractFilePath(Result) = '' then
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + Result;
end;

procedure TProducaoService.DefinirCaminhoRelatorioTalao(const ACaminho: string);
var
  LUpd: TSQLQuery;
  LNovo, LAnterior: string;
  LExiste: Boolean;
begin
  LNovo := Trim(ACaminho);
  LAnterior := CaminhoRelatorioTalao;

  FConexao.IniciarTransacao;
  LUpd := NovaConsulta;
  try
    try
      if LNovo = '' then
      begin
        { restaura o padrão: apaga a configuração da empresa }
        LUpd.SQL.Text :=
          'DELETE FROM CONFIGURACAO ' +
          'WHERE CHAVE = :CHAVE AND EMPRESA_ID = :EMP';
        LUpd.ParamByName('CHAVE').AsString := 'PRODUCAO_TALAO_RELATORIO';
        LUpd.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LUpd.ExecSQL;
        RegistrarAuditoria('CONFIGURACAO', 'ALTERACAO', 0,
          'PRODUCAO_TALAO_RELATORIO=' + LAnterior, 'PADRAO');
      end
      else
      begin
        { grava a configuração da empresa: primeiro verifica se já
          existe a chave; UPDATE ou INSERT (a tabela tem trigger
          de ID automático; EMPRESA_ID é NOT NULL - domínio DM_ID) }
        LUpd.SQL.Text :=
          'SELECT COUNT(*) AS QTD FROM CONFIGURACAO ' +
          'WHERE CHAVE = :CHAVE AND EMPRESA_ID = :EMP';
        LUpd.ParamByName('CHAVE').AsString := 'PRODUCAO_TALAO_RELATORIO';
        LUpd.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LUpd.Open;
        LExiste := LUpd.FieldByName('QTD').AsInteger > 0;
        LUpd.Close;

        if LExiste then
        begin
          LUpd.SQL.Text :=
            'UPDATE CONFIGURACAO SET VALOR = :VALOR ' +
            'WHERE CHAVE = :CHAVE AND EMPRESA_ID = :EMP';
          LUpd.ParamByName('VALOR').AsString := LNovo;
          LUpd.ParamByName('CHAVE').AsString := 'PRODUCAO_TALAO_RELATORIO';
          LUpd.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
          LUpd.ExecSQL;
        end
        else
        begin
          LUpd.SQL.Text :=
            'INSERT INTO CONFIGURACAO (EMPRESA_ID, CHAVE, VALOR, DESCRICAO) ' +
            'VALUES (:EMP, :CHAVE, :VALOR, :DESCR)';
          LUpd.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
          LUpd.ParamByName('CHAVE').AsString := 'PRODUCAO_TALAO_RELATORIO';
          LUpd.ParamByName('VALOR').AsString := LNovo;
          LUpd.ParamByName('DESCR').AsString :=
            'Caminho do relatório .lrf dos talões de produção';
          LUpd.ExecSQL;
        end;
        RegistrarAuditoria('CONFIGURACAO', 'ALTERACAO', 0,
          'PRODUCAO_TALAO_RELATORIO=' + LAnterior,
          'PRODUCAO_TALAO_RELATORIO=' + LNovo);
      end;

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LUpd.Free;
  end;
end;

end.
