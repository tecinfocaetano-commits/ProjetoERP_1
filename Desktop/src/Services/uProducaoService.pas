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

  { Item da ficha técnica (BOM) - Fase 5.
    QUANTIDADE = consumo do material para produzir QUANTIDADE_BASE;
    PERDA_PERCENTUAL = perda esperada do material (%). }
  TItemFichaTecnica = record
    MaterialId: Int64;
    Quantidade: Double;
    PerdaPercentual: Double;
  end;
  TItensFichaTecnica = array of TItemFichaTecnica;

  { Quantidade real informada pelo operador na confirmação do consumo
    (Fase 5). ItemId aponta o CONSUMO_MATERIAL_ITEM gravado. }
  TItemConsumoConfirmar = record
    ItemId: Int64;
    QtdReal: Double;
  end;
  TItensConsumoConfirmar = array of TItemConsumoConfirmar;

const
  { Tolerância para comparação de quantidades (NUMERIC(15,4)) }
  TOLERANCIA_QTD = 0.0001;

  { --- Modelos I e II dos relatórios (Talão e Mapa) ---------------------
    Modelo I é o .lrf original; Modelo II é uma cópia (arquivo separado)
    para o usuário ajustar no designer do LazReport sem mexer no Modelo I.
    Os dois modelos usam os MESMOS datasets - só muda o arquivo carregado.
    _RELATORIO(_M2) guardam o caminho do .lrf; _MODELO guarda '1' ou '2'
    (qual modelo vale para visualizar/imprimir/exportar). }
  CFG_TALAO_RELATORIO    = 'PRODUCAO_TALAO_RELATORIO';
  CFG_TALAO_RELATORIO_M2 = 'PRODUCAO_TALAO_RELATORIO_M2';
  CFG_TALAO_MODELO       = 'PRODUCAO_TALAO_MODELO';
  CFG_MAPA_MODELO        = 'PRODUCAO_MAPA_MODELO';

type
  TProducaoService = class
  private
    FConexao: TConexao;
    function  NovaConsulta: TSQLQuery;
    function  ProximoNumeroMapa(AEmpresaId: Int64): Integer;
    function  ProximoNumeroTalao(AEmpresaId: Int64): Integer;
    function  NumeroDoMapa(AMapaId: Int64): Integer;
    function  LerConfiguracao(const AChave, APadrao: string): string;
    procedure GravarChaveConfig(const AChave, AValor, ADescricao: string);
    function  ResolverCaminhoRelatorio(const AConfigurado,
      AArquivoPadrao: string): string;
    function  QuantidadePedidaItem(AItemPedidoId: Int64; out APedidoId,
      AProdutoId: Int64): Double;
    function  QuantidadeMapeadaItem(AItemPedidoId: Int64;
      AExcetoMapaId: Int64 = 0): Double;
    procedure AplicarStatusPedido(APedidoId: Int64; const ANovoStatus: string);
    procedure RegistrarBipagem(ATalaoId: Int64; const AEtapa, AOrigem,
      AResultado, AObservacao: string);
    { Fase 5: custo do material (CUSTO_MEDIO do estoque, senão
      PRECO_CUSTO do produto). }
    function  CustoMaterial(AProdutoId: Int64): Double;
    { Recalcula CONSUMO_MATERIAL_ITEM.STATUS_PRODUCAO do mapa conforme
      talões concluídos × total (exclui cancelados): ABERTO /
      PARCIALMENTE_CONCLUIDO / CONCLUIDO. }
    procedure AtualizarStatusProducaoConsumo(AMapaId: Int64);
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

    { --- modelos I/II (mesmos datasets) ----------------------------------
      Ambos os modelos apontam para o MESMO dataset do relatório; só o
      arquivo .lrf carregado muda. Caminho do Modelo II vem da CONFIGURACAO
      (PRODUCAO_TALAO_RELATORIO_M2) com padrão relatorios\talao_modelo2.lrf;
      o do mapa é fixo (mapa_producao.lrf / mapa_producao_modelo2.lrf). }
    function  CaminhoRelatorioTalaoModelo(const AModelo: Integer): string;
    procedure DefinirCaminhoRelatorioTalaoModelo(const AModelo: Integer;
      const ACaminho: string);
    function  CaminhoRelatorioMapaModelo(const AModelo: Integer): string;
    { Modelo ativo = '1' (padrão) ou '2'. DefinirModeloAtivo devolve True
      quando realmente gravou (o COMMIT da CONFIGURACAO invalida os cursores
      SQLDB já abertos, então a tela só recarrega nesse caso). }
    function  ModeloAtivo(const AChave: string): Integer;
    function  DefinirModeloAtivo(const AChave: string;
      const AModelo: Integer): Boolean;

    { --- ficha técnica (Fase 5) -----------------------------------------
      Uma ficha por produto (índice único EMPRESA+PRODUTO). QUANTIDADE_BASE
      é o rendimento: os itens dizem quanto de cada material é consumido
      para produzir QUANTIDADE_BASE, com a perda percentual esperada.
      FichaTecnicaDoProduto devolve a ficha ATIVA do produto (vazio se
      não houver); GravarFichaTecnica faz o upsert do cabeçalho e troca
      todos os itens de uma vez, na mesma transação. }
    function  FichaTecnicaDoProduto(AProdutoId: Int64; out ADescricao: string;
      out ABase: Double): TItensFichaTecnica;
    function  GravarFichaTecnica(AProdutoId: Int64; const ADescricao: string;
      ABase: Double; const AItens: TItensFichaTecnica): Int64;

    { --- consumo de materiais (Fase 5) -----------------------------------
      GerarConsumoMaterial: cria o consumo PENDENTE do mapa a partir das
      fichas técnicas dos produtos. Por padrão usa a base PRODUZIDA
      (só talões CONCLUÍDOS); com APorPlanejado=True usa a base PLANEJADA
      (a quantidade prevista do item do mapa), que é o consumo automático
      gerado ainda no início da produção. Em ambos a QTD_PREVISTA inclui
      a perda. Um consumo PENDENTE existente é substituído (ainda não
      movimentou estoque); consumo CONFIRMADO exige estorno prévio.
      ConfirmarConsumo: dá baixa no estoque (MOVIMENTO_ESTOQUE 'S', custo
      do ESTOQUE.CUSTO_MEDIO) e marca CONFIRMADO; respeita
      PRODUCAO_PERMITE_ESTOQUE_NEGATIVO ('N' = exige saldo).
      EstornarConsumo: devolve ao estoque ('E') e marca ESTORNADO
      (somente um consumo CONFIRMADO pode ser estornado). }
    function  GerarConsumoMaterial(AMapaId: Int64;
      const AJustificativa: string;
      APorPlanejado: Boolean = False): Int64;
    procedure ConfirmarConsumo(AConsumoId: Int64;
      const AItens: TItensConsumoConfirmar);
    procedure EstornarConsumo(AConsumoId: Int64; const AMotivo: string);
    { ID do consumo PENDENTE/CONFIRMADO do mapa (0 quando não há). }
    function  ConsumoAtivoDoMapa(AMapaId: Int64): Int64;
  end;

implementation

uses
  Math, uSessao, uAuditoria;

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

procedure TProducaoService.AtualizarStatusProducaoConsumo(AMapaId: Int64);
var
  LQry, LUpd: TSQLQuery;
  LTotal, LConcluidos: Integer;
  LNovoStatus: string;
begin
  if AMapaId <= 0 then
    Exit;

  LQry := NovaConsulta;
  LUpd := NovaConsulta;
  try
    { total de talões do mapa (exclui cancelados) e quantos concluídos }
    LQry.SQL.Text :=
      'SELECT COUNT(*) AS TOTAL, ' +
      '  SUM(CASE WHEN T.STATUS = ''CONCLUIDO'' THEN 1 ELSE 0 END) AS CONCLUIDOS ' +
      'FROM TALAO T ' +
      '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
      'WHERE MI.MAPA_PRODUCAO_ID = :MAPA AND T.STATUS <> ''CANCELADO''';
    LQry.ParamByName('MAPA').AsLargeInt := AMapaId;
    LQry.Open;
    LTotal := LQry.FieldByName('TOTAL').AsInteger;
    LConcluidos := LQry.FieldByName('CONCLUIDOS').AsInteger;
    LQry.Close;

    if (LTotal > 0) and (LConcluidos >= LTotal) then
      LNovoStatus := 'CONCLUIDO'
    else if LConcluidos > 0 then
      LNovoStatus := 'PARCIALMENTE_CONCLUIDO'
    else
      LNovoStatus := 'ABERTO';

    { consumo é por mapa (agregado por material): aplica o andamento a
      todos os itens de consumo do mapa; só grava o que mudou }
    LUpd.SQL.Text :=
      'UPDATE CONSUMO_MATERIAL_ITEM SET STATUS_PRODUCAO = :NOVO ' +
      'WHERE CONSUMO_MATERIAL_ID IN ' +
      '  (SELECT ID FROM CONSUMO_MATERIAL WHERE MAPA_PRODUCAO_ID = :MAPA) ' +
      '  AND COALESCE(STATUS_PRODUCAO, '''') <> :NOVO';
    LUpd.ParamByName('NOVO').AsString := LNovoStatus;
    LUpd.ParamByName('MAPA').AsLargeInt := AMapaId;
    LUpd.ExecSQL;

    RegistrarAuditoria('CONSUMO_MATERIAL_ITEM', 'STATUS_PRODUCAO', AMapaId,
      '', LNovoStatus + '; CONCLUIDOS=' + IntToStr(LConcluidos) +
      '; TOTAL=' + IntToStr(LTotal));
  finally
    LQry.Free;
    LUpd.Free;
  end;
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
  LItemId, LMapaId: Int64;
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
        '  MI.STATUS AS ITEM_STATUS, MI.MAPA_PRODUCAO_ID ' +
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
      LMapaId := LTalao.FieldByName('MAPA_PRODUCAO_ID').AsLargeInt;
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

      { cancelamento muda o total de talões: recalcula o andamento }
      AtualizarStatusProducaoConsumo(LMapaId);

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

        { andamento do consumo do mapa acompanha o início do talão }
        AtualizarStatusProducaoConsumo(LMapaId);

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

        { andamento do consumo do mapa acompanha a conclusão do talão }
        AtualizarStatusProducaoConsumo(LMapaId);

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

function TProducaoService.ResolverCaminhoRelatorio(const AConfigurado,
  AArquivoPadrao: string): string;
begin
  Result := Trim(AConfigurado);
  if Result = '' then
  begin
    { padrão: o exe roda de Desktop\bin\ e relatorios\<arquivo>
      fica copiado ao lado dele pelo build_desktop.bat }
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
      'relatorios' + PathDelim + AArquivoPadrao;
    Exit;
  end;

  { caminho relativo (ex.: "meus_relatorios\talao.lrf") é resolvido
    a partir da pasta do exe }
  if ExtractFilePath(Result) = '' then
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + Result;
end;

function TProducaoService.CaminhoRelatorioTalaoModelo(const AModelo: Integer): string;
begin
  if AModelo = 2 then
    Result := ResolverCaminhoRelatorio(
      LerConfiguracao(CFG_TALAO_RELATORIO_M2, ''), 'talao_modelo2.lrf')
  else
    Result := ResolverCaminhoRelatorio(
      LerConfiguracao(CFG_TALAO_RELATORIO, ''), 'talao.lrf');
end;

function TProducaoService.CaminhoRelatorioTalao: string;
begin
  { o caminho vem da CONFIGURACAO (PRODUCAO_TALAO_RELATORIO); o
    usuário final pode trocá-lo em "Relatório ▼ → Configurar" }
  Result := CaminhoRelatorioTalaoModelo(ModeloAtivo(CFG_TALAO_MODELO));
end;

function TProducaoService.CaminhoRelatorioMapaModelo(const AModelo: Integer): string;
begin
  { o mapa nunca teve caminho configurável; cada modelo é um arquivo fixo
    ao lado do exe (o build copia os dois de Desktop\relatorios) }
  if AModelo = 2 then
    Result := ResolverCaminhoRelatorio('', 'mapa_producao_modelo2.lrf')
  else
    Result := ResolverCaminhoRelatorio('', 'mapa_producao.lrf');
end;

{ Modelo ativo do relatório: valor ausente ou inválido = Modelo I. }
function TProducaoService.ModeloAtivo(const AChave: string): Integer;
var
  LValor: string;
begin
  LValor := Trim(LerConfiguracao(AChave, ''));
  if LValor = '2' then
    Result := 2
  else
    Result := 1;
end;

function TProducaoService.DefinirModeloAtivo(const AChave: string;
  const AModelo: Integer): Boolean;
var
  LValor, LAtual: string;
begin
  if AModelo = 2 then
    LValor := '2'
  else
    LValor := '1';

  LAtual := Trim(LerConfiguracao(AChave, ''));
  if LAtual = '' then
    LAtual := '1';   { sem chave gravada o padrão é o Modelo I }

  Result := False;
  if LAtual = LValor then
    Exit;             { nada a gravar: evita COMMIT que invalidaria cursores }

  GravarChaveConfig(AChave, LValor,
    'Modelo ativo (1 ou 2) do relatório de produção');
  Result := True;
end;

procedure TProducaoService.DefinirCaminhoRelatorioTalao(const ACaminho: string);
begin
  { mantém a assinatura da Fase 4: o caminho configurável é o do Modelo I }
  DefinirCaminhoRelatorioTalaoModelo(1, ACaminho);
end;

procedure TProducaoService.DefinirCaminhoRelatorioTalaoModelo(
  const AModelo: Integer; const ACaminho: string);
begin
  if AModelo = 2 then
    GravarChaveConfig(CFG_TALAO_RELATORIO_M2, ACaminho,
      'Caminho do relatório .lrf dos talões de produção (Modelo II)')
  else
    GravarChaveConfig(CFG_TALAO_RELATORIO, ACaminho,
      'Caminho do relatório .lrf dos talões de produção');
end;

{ Grava uma chave na CONFIGURACAO da empresa (ou a remove, quando o valor
  é vazio = restaurar o padrão), com auditoria no mesmo caminho único
  (uAuditoria.RegistrarAuditoria). Uma única transação: grava/audita/COMMIT. }
procedure TProducaoService.GravarChaveConfig(const AChave, AValor,
  ADescricao: string);
var
  LUpd: TSQLQuery;
  LNovo, LAnterior: string;
  LExiste: Boolean;
begin
  LNovo := Trim(AValor);
  LAnterior := Trim(LerConfiguracao(AChave, ''));

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
        LUpd.ParamByName('CHAVE').AsString := AChave;
        LUpd.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LUpd.ExecSQL;
        RegistrarAuditoria('CONFIGURACAO', 'ALTERACAO', 0,
          AChave + '=' + LAnterior, AChave + '=PADRAO');
      end
      else
      begin
        { grava a configuração da empresa: primeiro verifica se já
          existe a chave; UPDATE ou INSERT (a tabela tem trigger
          de ID automático; EMPRESA_ID é NOT NULL - domínio DM_ID) }
        LUpd.SQL.Text :=
          'SELECT COUNT(*) AS QTD FROM CONFIGURACAO ' +
          'WHERE CHAVE = :CHAVE AND EMPRESA_ID = :EMP';
        LUpd.ParamByName('CHAVE').AsString := AChave;
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
          LUpd.ParamByName('CHAVE').AsString := AChave;
          LUpd.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
          LUpd.ExecSQL;
        end
        else
        begin
          LUpd.SQL.Text :=
            'INSERT INTO CONFIGURACAO (EMPRESA_ID, CHAVE, VALOR, DESCRICAO) ' +
            'VALUES (:EMP, :CHAVE, :VALOR, :DESCR)';
          LUpd.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
          LUpd.ParamByName('CHAVE').AsString := AChave;
          LUpd.ParamByName('VALOR').AsString := LNovo;
          LUpd.ParamByName('DESCR').AsString := ADescricao;
          LUpd.ExecSQL;
        end;
        RegistrarAuditoria('CONFIGURACAO', 'ALTERACAO', 0,
          AChave + '=' + LAnterior, AChave + '=' + LNovo);
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

{ ------------------------------------------------------------
  Fase 5 - Ficha técnica (BOM) e consumo de materiais
  ------------------------------------------------------------ }

function TProducaoService.CustoMaterial(AProdutoId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(E.CUSTO_MEDIO, 0) AS NUMERIC(18,4)) AS CUSTO_MEDIO, ' +
      '       CAST(COALESCE(P.PRECO_CUSTO, 0) AS NUMERIC(18,4)) AS PRECO_CUSTO ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ' +
      '  ON E.PRODUTO_ID = P.ID AND E.EMPRESA_ID = :EMP ' +
      'WHERE P.ID = :PROD';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      Result := LQuery.FieldByName('CUSTO_MEDIO').AsFloat;
      if Result <= 0 then
        Result := LQuery.FieldByName('PRECO_CUSTO').AsFloat;
    end;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.ConsumoAtivoDoMapa(AMapaId: Int64): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM CONSUMO_MATERIAL ' +
      'WHERE MAPA_PRODUCAO_ID = :MAPA AND STATUS IN (''PENDENTE'', ''CONFIRMADO'') ' +
      'ORDER BY ID DESC';
    LQuery.ParamByName('MAPA').AsLargeInt := AMapaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.FichaTecnicaDoProduto(AProdutoId: Int64;
  out ADescricao: string; out ABase: Double): TItensFichaTecnica;
var
  LQuery: TSQLQuery;
  LFichaId: Int64;
begin
  Result := nil;
  ADescricao := '';
  ABase := 1;
  LFichaId := 0;

  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO, QUANTIDADE_BASE FROM FICHA_TECNICA ' +
      'WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD AND ATIVO = ''A''';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      LFichaId := LQuery.FieldByName('ID').AsLargeInt;
      ADescricao := LQuery.FieldByName('DESCRICAO').AsString;
      ABase := LQuery.FieldByName('QUANTIDADE_BASE').AsFloat;
    end;
    LQuery.Close;

    if LFichaId = 0 then
      Exit;

    LQuery.SQL.Text :=
      'SELECT FI.MATERIAL_ID, FI.QUANTIDADE, FI.PERDA_PERCENTUAL ' +
      'FROM FICHA_TECNICA_ITEM FI ' +
      'WHERE FI.FICHA_TECNICA_ID = :FICHA ' +
      'ORDER BY FI.ID';
    LQuery.ParamByName('FICHA').AsLargeInt := LFichaId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].MaterialId :=
        LQuery.FieldByName('MATERIAL_ID').AsLargeInt;
      Result[High(Result)].Quantidade :=
        LQuery.FieldByName('QUANTIDADE').AsFloat;
      Result[High(Result)].PerdaPercentual :=
        LQuery.FieldByName('PERDA_PERCENTUAL').AsFloat;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TProducaoService.GravarFichaTecnica(AProdutoId: Int64;
  const ADescricao: string; ABase: Double;
  const AItens: TItensFichaTecnica): Int64;
var
  LQry: TSQLQuery;
  LFichaId: Int64;
  LIndice, LJ: Integer;
  LBaseAnterior: string;
begin
  if AProdutoId <= 0 then
    raise EProducao.Create('Selecione o produto que receberá a ficha técnica.');
  if ABase <= 0 then
    raise EProducao.Create('A quantidade base (rendimento) deve ser maior que zero.');
  if Length(AItens) = 0 then
    raise EProducao.Create('A ficha técnica precisa de ao menos um material.');

  for LIndice := 0 to High(AItens) do
  begin
    if AItens[LIndice].MaterialId = AProdutoId then
      raise EProducao.Create(
        'A ficha técnica não pode usar o próprio produto como material.');
    if AItens[LIndice].Quantidade <= 0 then
      raise EProducao.Create('Todos os materiais devem ter quantidade maior que zero.');
    if AItens[LIndice].PerdaPercentual < 0 then
      raise EProducao.Create('O percentual de perda não pode ser negativo.');
    for LJ := LIndice + 1 to High(AItens) do
      if AItens[LJ].MaterialId = AItens[LIndice].MaterialId then
        raise EProducao.Create('Material duplicado na ficha técnica.');
  end;

  FConexao.IniciarTransacao;
  LQry := NovaConsulta;
  try
    try
      { upsert do cabeçalho (índice único EMPRESA+PRODUTO) }
      LQry.SQL.Text :=
        'SELECT ID, QUANTIDADE_BASE FROM FICHA_TECNICA ' +
        'WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD';
      LQry.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQry.ParamByName('PROD').AsLargeInt := AProdutoId;
      LQry.Open;
      if LQry.IsEmpty then
      begin
        LFichaId := 0;
        LBaseAnterior := '';
      end
      else
      begin
        LFichaId := LQry.FieldByName('ID').AsLargeInt;
        LBaseAnterior := LQry.FieldByName('QUANTIDADE_BASE').AsString;
      end;
      LQry.Close;

      if LFichaId = 0 then
      begin
        LQry.SQL.Text :=
          'INSERT INTO FICHA_TECNICA (EMPRESA_ID, PRODUTO_ID, DESCRICAO, ' +
          '  QUANTIDADE_BASE, ATIVO, USUARIO_ID) ' +
          'VALUES (:EMP, :PROD, :DESCR, :BASE, ''A'', :USR)';
        LQry.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQry.ParamByName('PROD').AsLargeInt := AProdutoId;
        LQry.ParamByName('DESCR').AsString := ADescricao;
        LQry.ParamByName('BASE').AsFloat := ABase;
        LQry.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
        LQry.ExecSQL;
        { o trigger BI já usou o gerador: o valor atual é o ID novo }
        LQry.SQL.Text :=
          'SELECT GEN_ID(GEN_FICHA_TECNICA_ID, 0) FROM RDB$DATABASE';
        LQry.Open;
        LFichaId := LQry.Fields[0].AsLargeInt;
        LQry.Close;
      end
      else
      begin
        LQry.SQL.Text :=
          'UPDATE FICHA_TECNICA SET DESCRICAO = :DESCR, ' +
          '  QUANTIDADE_BASE = :BASE, ATIVO = ''A'', USUARIO_ID = :USR ' +
          'WHERE ID = :ID';
        LQry.ParamByName('DESCR').AsString := ADescricao;
        LQry.ParamByName('BASE').AsFloat := ABase;
        LQry.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
        LQry.ParamByName('ID').AsLargeInt := LFichaId;
        LQry.ExecSQL;
      end;

      { os itens são substituídos por completo, na mesma transação }
      LQry.SQL.Text :=
        'DELETE FROM FICHA_TECNICA_ITEM WHERE FICHA_TECNICA_ID = :FICHA';
      LQry.ParamByName('FICHA').AsLargeInt := LFichaId;
      LQry.ExecSQL;

      for LIndice := 0 to High(AItens) do
      begin
        LQry.SQL.Text :=
          'INSERT INTO FICHA_TECNICA_ITEM (FICHA_TECNICA_ID, MATERIAL_ID, ' +
          '  QUANTIDADE, PERDA_PERCENTUAL) ' +
          'VALUES (:FICHA, :MAT, :QTD, :PERDA)';
        LQry.ParamByName('FICHA').AsLargeInt := LFichaId;
        LQry.ParamByName('MAT').AsLargeInt := AItens[LIndice].MaterialId;
        LQry.ParamByName('QTD').AsFloat := AItens[LIndice].Quantidade;
        LQry.ParamByName('PERDA').AsFloat := AItens[LIndice].PerdaPercentual;
        LQry.ExecSQL;
      end;

      RegistrarAuditoria('FICHA_TECNICA', 'SALVAR', LFichaId,
        ResumoAuditoria(['BASE=' + LBaseAnterior]),
        ResumoAuditoria([
          'PRODUTO=' + IntToStr(AProdutoId),
          'BASE=' + FloatToStr(ABase),
          'ITENS=' + IntToStr(Length(AItens))]));

      FConexao.Confirmar;
      Result := LFichaId;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQry.Free;
  end;
end;

function TProducaoService.GerarConsumoMaterial(AMapaId: Int64;
  const AJustificativa: string; APorPlanejado: Boolean): Int64;
var
  LQry, LGrava: TSQLQuery;
  LConsumoId: Int64;
  LConsumoPendente: Int64;
  LStatusMapa: string;
  LProdutoId: Int64;
  LCodigoProduto, LDescFicha: string;
  LProduzido, LBase, LQtdPrevista, LQtdBase: Double;
  LItensFicha: TItensFichaTecnica;
  LIndice, LJ, LPos: Integer;
  LMatIds: array of Int64;
  LMatQtds: array of Double;
  SSemFicha: string;
  LBaseModo: string;
begin
  if AMapaId <= 0 then
    raise EProducao.Create('Selecione o mapa de produção para gerar o consumo.');
  if Length(Trim(AJustificativa)) > 500 then
    raise EProducao.Create('A justificativa pode ter no máximo 500 caracteres.');

  SetLength(LMatIds, 0);
  SetLength(LMatQtds, 0);
  SSemFicha := '';

  FConexao.IniciarTransacao;
  LQry := NovaConsulta;
  LGrava := NovaConsulta;
  try
    try
      { mapa existe, não cancelado e sem consumo que impeça o novo }
      LQry.SQL.Text :=
        'SELECT FIRST 1 M.NUMERO, M.STATUS, C.ID AS CONSUMO_ID, ' +
        '  C.STATUS AS CONSUMO_STATUS ' +
        'FROM MAPA_PRODUCAO M ' +
        '  LEFT JOIN CONSUMO_MATERIAL C ON C.MAPA_PRODUCAO_ID = M.ID ' +
        '     AND C.STATUS IN (''PENDENTE'', ''CONFIRMADO'') ' +
        'WHERE M.ID = :MAPA ' +
        'ORDER BY C.ID DESC';
      LQry.ParamByName('MAPA').AsLargeInt := AMapaId;
      LQry.Open;
      if LQry.IsEmpty then
        raise EProducao.Create('Mapa de produção não encontrado.');
      LStatusMapa := LQry.FieldByName('STATUS').AsString;
      if not LQry.FieldByName('CONSUMO_ID').IsNull and
         (Trim(LQry.FieldByName('CONSUMO_STATUS').AsString) = 'CONFIRMADO') then
        raise EProducao.Create(
          'Este mapa já tem consumo CONFIRMADO (#' +
          LQry.FieldByName('CONSUMO_ID').AsString + ').' + sLineBreak +
          'Estorne-o antes de gerar um novo consumo.');
      { consumo PENDENTE é substituído: ainda não movimentou estoque }
      LConsumoPendente := 0;
      if not LQry.FieldByName('CONSUMO_ID').IsNull then
        LConsumoPendente := LQry.FieldByName('CONSUMO_ID').AsLargeInt;
      LQry.Close;

      if LConsumoPendente > 0 then
      begin
        { descarta o pendente (sem movimento vinculado) e gera outro }
        LGrava.SQL.Text :=
          'DELETE FROM CONSUMO_MATERIAL_ITEM WHERE CONSUMO_MATERIAL_ID = :ID';
        LGrava.ParamByName('ID').AsLargeInt := LConsumoPendente;
        LGrava.ExecSQL;
        LGrava.SQL.Text := 'DELETE FROM CONSUMO_MATERIAL WHERE ID = :ID';
        LGrava.ParamByName('ID').AsLargeInt := LConsumoPendente;
        LGrava.ExecSQL;
        RegistrarAuditoria('CONSUMO_MATERIAL', 'SUBSTITUIR', LConsumoPendente,
          'STATUS=PENDENTE', 'STATUS=DESCARTADO');
      end;

      if LStatusMapa = 'CANCELADO' then
        raise EProducao.Create(
          'Não é possível gerar consumo de um mapa cancelado.');

      { produção concluída por produto (talões CONCLUÍDOS) }
      { CAST obrigatório: o SQLDB lê COALESCE((subquery),0) sem tipo como 0 }
      LQry.SQL.Text :=
        'SELECT MI.PRODUTO_ID, P.CODIGO, MI.QUANTIDADE AS PLANEJADO, ' +
        '  CAST(COALESCE((SELECT SUM(T.QUANTIDADE) FROM TALAO T ' +
        '     WHERE T.MAPA_PRODUCAO_ITEM_ID = MI.ID ' +
        '       AND T.STATUS = ''CONCLUIDO''), 0) AS NUMERIC(18,4)) AS PRODUZIDO ' +
        'FROM MAPA_PRODUCAO_ITEM MI ' +
        '  JOIN PRODUTO P ON P.ID = MI.PRODUTO_ID ' +
        'WHERE MI.MAPA_PRODUCAO_ID = :MAPA AND MI.STATUS <> ''CANCELADO'' ' +
        'ORDER BY MI.ID';
      LQry.ParamByName('MAPA').AsLargeInt := AMapaId;
      LQry.Open;
      while not LQry.EOF do
      begin
        LProdutoId := LQry.FieldByName('PRODUTO_ID').AsLargeInt;
        LCodigoProduto := Trim(LQry.FieldByName('CODIGO').AsString);
        LProduzido := LQry.FieldByName('PRODUZIDO').AsFloat;
        if APorPlanejado then
          LQtdBase := LQry.FieldByName('PLANEJADO').AsFloat
        else
          LQtdBase := LProduzido;
        LQry.Next;

        if LQtdBase <= 0 then
          Continue;

        LItensFicha := FichaTecnicaDoProduto(LProdutoId, LDescFicha, LBase);
        if Length(LItensFicha) = 0 then
        begin
          if SSemFicha <> '' then
            SSemFicha := SSemFicha + ', ';
          SSemFicha := SSemFicha + LCodigoProduto;
          Continue;
        end;

        for LIndice := 0 to High(LItensFicha) do
        begin
          { QTD_PREVISTA = (base / rendimento) x consumo x (1 + perda%)
            base = produzido (talões concluídos) ou planejado (item do mapa) }
          LQtdPrevista := (LQtdBase / LBase) *
            LItensFicha[LIndice].Quantidade *
            (1 + LItensFicha[LIndice].PerdaPercentual / 100);
          LQtdPrevista := SimpleRoundTo(LQtdPrevista, -4);

          { agrega pelo material (fichas diferentes podem usar o mesmo) }
          LPos := -1;
          for LJ := 0 to High(LMatIds) do
            if LMatIds[LJ] = LItensFicha[LIndice].MaterialId then
            begin
              LPos := LJ;
              Break;
            end;
          if LPos < 0 then
          begin
            LPos := Length(LMatIds);
            SetLength(LMatIds, LPos + 1);
            SetLength(LMatQtds, LPos + 1);
            LMatIds[LPos] := LItensFicha[LIndice].MaterialId;
            LMatQtds[LPos] := 0;
          end;
          LMatQtds[LPos] := LMatQtds[LPos] + LQtdPrevista;
        end;
      end;
      LQry.Close;

      if SSemFicha <> '' then
      begin
        if APorPlanejado then
          raise EProducao.Create(
            'Produto(s) do mapa sem ficha técnica ativa: ' + SSemFicha + '.' +
            sLineBreak + 'Cadastre a ficha técnica antes de gerar o consumo.')
        else
          raise EProducao.Create(
            'Produto(s) concluído(s) sem ficha técnica ativa: ' + SSemFicha + '.' +
            sLineBreak + 'Cadastre a ficha técnica antes de gerar o consumo.');
      end;
      if Length(LMatIds) = 0 then
      begin
        if APorPlanejado then
          raise EProducao.Create(
            'Nenhum material calculado: o mapa não tem itens com quantidade ' +
            'planejada.')
        else
          raise EProducao.Create(
            'Nenhum material calculado: o mapa ainda não tem produção concluída.');
      end;

      { cabeçalho do consumo }
      LGrava.SQL.Text :=
        'INSERT INTO CONSUMO_MATERIAL (EMPRESA_ID, MAPA_PRODUCAO_ID, ' +
        '  DATA_CONSUMO, STATUS, JUSTIFICATIVA, USUARIO_ID) ' +
        'VALUES (:EMP, :MAPA, :DATA, ''PENDENTE'', :JUST, :USR)';
      LGrava.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LGrava.ParamByName('MAPA').AsLargeInt := AMapaId;
      LGrava.ParamByName('DATA').AsDate := Date;
      LGrava.ParamByName('JUST').AsString := Trim(AJustificativa);
      LGrava.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LGrava.ExecSQL;
      LGrava.SQL.Text :=
        'SELECT GEN_ID(GEN_CONSUMO_MATERIAL_ID, 0) FROM RDB$DATABASE';
      LGrava.Open;
      LConsumoId := LGrava.Fields[0].AsLargeInt;
      LGrava.Close;

      for LIndice := 0 to High(LMatIds) do
      begin
        LGrava.SQL.Text :=
          'INSERT INTO CONSUMO_MATERIAL_ITEM (CONSUMO_MATERIAL_ID, ' +
          '  MATERIAL_ID, QTD_PREVISTA, QTD_REAL) ' +
          'VALUES (:CONS, :MAT, :QTD, 0)';
        LGrava.ParamByName('CONS').AsLargeInt := LConsumoId;
        LGrava.ParamByName('MAT').AsLargeInt := LMatIds[LIndice];
        LGrava.ParamByName('QTD').AsFloat := LMatQtds[LIndice];
        LGrava.ExecSQL;
      end;

      if APorPlanejado then
        LBaseModo := 'PLANEJADO'
      else
        LBaseModo := 'PRODUZIDO';
      RegistrarAuditoria('CONSUMO_MATERIAL', 'GERAR', LConsumoId, '',
        ResumoAuditoria([
          'MAPA=' + IntToStr(AMapaId),
          'BASE=' + LBaseModo,
          'ITENS=' + IntToStr(Length(LMatIds))]));

      FConexao.Confirmar;
      Result := LConsumoId;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQry.Free;
    LGrava.Free;
  end;
end;

procedure TProducaoService.ConfirmarConsumo(AConsumoId: Int64;
  const AItens: TItensConsumoConfirmar);
var
  LQry: TSQLQuery;
  LStatus: string;
  LNumeroMapa: Integer;
  LPermiteNegativo: Boolean;
  LDocumento: string;
  LIndice, LJ: Integer;
  LMaterialId: Int64;
  LMovId: Int64;
  LQtdReal, LSaldo, LCusto: Double;
  LEncontrado: Boolean;
  LItensIds: array of Int64;
  LItensMat: array of Int64;
  LItensPrev: array of Double;
  LItensReal: array of Double;
  LCodigos: array of string;
begin
  if AConsumoId <= 0 then
    raise EProducao.Create('Consumo de materiais não encontrado.');

  FConexao.IniciarTransacao;
  LQry := NovaConsulta;
  try
    try
      { cabeçalho: precisa existir e estar PENDENTE }
      LQry.SQL.Text :=
        'SELECT C.STATUS, M.NUMERO FROM CONSUMO_MATERIAL C ' +
        '  JOIN MAPA_PRODUCAO M ON M.ID = C.MAPA_PRODUCAO_ID ' +
        'WHERE C.ID = :ID';
      LQry.ParamByName('ID').AsLargeInt := AConsumoId;
      LQry.Open;
      if LQry.IsEmpty then
        raise EProducao.Create('Consumo de materiais não encontrado.');
      LStatus := LQry.FieldByName('STATUS').AsString;
      LNumeroMapa := LQry.FieldByName('NUMERO').AsInteger;
      LQry.Close;

      if LStatus <> 'PENDENTE' then
        raise EProducao.CreateFmt(
          'Só é possível confirmar um consumo PENDENTE (situação atual: %s).',
          [LStatus]);

      LPermiteNegativo :=
        UpperCase(LerConfiguracao('PRODUCAO_PERMITE_ESTOQUE_NEGATIVO', 'N')) = 'S';

      { itens do consumo }
      LQry.SQL.Text :=
        'SELECT I.ID, I.MATERIAL_ID, I.QTD_PREVISTA, P.CODIGO ' +
        'FROM CONSUMO_MATERIAL_ITEM I ' +
        '  JOIN PRODUTO P ON P.ID = I.MATERIAL_ID ' +
        'WHERE I.CONSUMO_MATERIAL_ID = :CONS ORDER BY I.ID';
      LQry.ParamByName('CONS').AsLargeInt := AConsumoId;
      LQry.Open;
      SetLength(LItensIds, 0);
      while not LQry.EOF do
      begin
        LJ := Length(LItensIds);
        SetLength(LItensIds, LJ + 1);
        SetLength(LItensMat, LJ + 1);
        SetLength(LItensPrev, LJ + 1);
        SetLength(LItensReal, LJ + 1);
        SetLength(LCodigos, LJ + 1);
        LItensIds[LJ] := LQry.FieldByName('ID').AsLargeInt;
        LItensMat[LJ] := LQry.FieldByName('MATERIAL_ID').AsLargeInt;
        LItensPrev[LJ] := LQry.FieldByName('QTD_PREVISTA').AsFloat;
        { padrão: consome a quantidade prevista }
        LItensReal[LJ] := LQry.FieldByName('QTD_PREVISTA').AsFloat;
        LCodigos[LJ] := Trim(LQry.FieldByName('CODIGO').AsString);
        LQry.Next;
      end;
      LQry.Close;

      if Length(LItensIds) = 0 then
        raise EProducao.Create('Este consumo não tem itens para confirmar.');

      { aplica as quantidades reais informadas (e valida os IDs) }
      for LIndice := 0 to High(AItens) do
      begin
        LEncontrado := False;
        for LJ := 0 to High(LItensIds) do
          if LItensIds[LJ] = AItens[LIndice].ItemId then
          begin
            LItensReal[LJ] := AItens[LIndice].QtdReal;
            LEncontrado := True;
            Break;
          end;
        if not LEncontrado then
          raise EProducao.Create('Item do consumo inválido na confirmação.');
      end;

      LDocumento := Format('CONSUMO MAPA %d - #%d', [LNumeroMapa, AConsumoId]);

      { baixa de estoque item a item }
      for LIndice := 0 to High(LItensIds) do
      begin
        LQtdReal := LItensReal[LIndice];
        if LQtdReal <= 0 then
          raise EProducao.CreateFmt(
            'Quantidade real deve ser maior que zero (material %s).',
            [LCodigos[LIndice]]);

        LMaterialId := LItensMat[LIndice];
        LCusto := CustoMaterial(LMaterialId);

        LQry.SQL.Text :=
          'SELECT COALESCE(E.QUANTIDADE, 0) AS SALDO FROM ESTOQUE E ' +
          'WHERE E.EMPRESA_ID = :EMP AND E.PRODUTO_ID = :PROD';
        LQry.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQry.ParamByName('PROD').AsLargeInt := LMaterialId;
        LQry.Open;
        if LQry.IsEmpty then
          LSaldo := 0
        else
          LSaldo := LQry.FieldByName('SALDO').AsFloat;
        LQry.Close;

        if (not LPermiteNegativo) and (LSaldo < LQtdReal) then
          raise EProducao.CreateFmt(
            'Saldo insuficiente do material %s: disponível %s, consumo %s.',
            [LCodigos[LIndice], FormatFloat('#,##0.####', LSaldo),
             FormatFloat('#,##0.####', LQtdReal)]);

        { saída: o trigger TRG_MOVEST_AI dá a baixa no ESTOQUE }
        LQry.SQL.Text :=
          'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, ' +
          '  QUANTIDADE, CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, ' +
          '  DATA_MOVIMENTO, USUARIO_ID) ' +
          'VALUES (:EMP, :PROD, ''S'', :QTD, :CUSTO, :DOC, :OBS, :DATA, :USR)';
        LQry.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQry.ParamByName('PROD').AsLargeInt := LMaterialId;
        LQry.ParamByName('QTD').AsFloat := LQtdReal;
        LQry.ParamByName('CUSTO').AsFloat := LCusto;
        LQry.ParamByName('DOC').AsString := LDocumento;
        LQry.ParamByName('OBS').AsString :=
          'Baixa por consumo de materiais da produção.';
        LQry.ParamByName('DATA').AsDate := Date;
        LQry.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
        LQry.ExecSQL;

        { ID do movimento recém-gerado pelo trigger BI }
        LQry.SQL.Text :=
          'SELECT GEN_ID(GEN_MOVIMENTO_ESTOQUE_ID, 0) FROM RDB$DATABASE';
        LQry.Open;
        LMovId := LQry.Fields[0].AsLargeInt;
        LQry.Close;

        { vincula o movimento ao item do consumo }
        LQry.SQL.Text :=
          'UPDATE CONSUMO_MATERIAL_ITEM SET QTD_REAL = :QTD, ' +
          '  CUSTO_UNITARIO = :CUSTO, MOVIMENTO_ESTOQUE_ID = :MOV ' +
          'WHERE ID = :ID';
        LQry.ParamByName('QTD').AsFloat := LQtdReal;
        LQry.ParamByName('CUSTO').AsFloat := LCusto;
        LQry.ParamByName('MOV').AsLargeInt := LMovId;
        LQry.ParamByName('ID').AsLargeInt := LItensIds[LIndice];
        LQry.ExecSQL;

        RegistrarAuditoria('CONSUMO_MATERIAL_ITEM', 'BAIXA', LItensIds[LIndice],
          ResumoAuditoria([
            'MATERIAL=' + LCodigos[LIndice],
            'PREVISTA=' + FormatFloat('#,##0.####', LItensPrev[LIndice])]),
          ResumoAuditoria([
            'REAL=' + FormatFloat('#,##0.####', LQtdReal),
            'CUSTO=' + FormatFloat('#,##0.####', LCusto),
            'MOVIMENTO=' + IntToStr(LMovId)]));
      end;

      { confirma o consumo }
      LQry.SQL.Text :=
        'UPDATE CONSUMO_MATERIAL SET STATUS = ''CONFIRMADO'', ' +
        '  DATA_CONFIRMACAO = CURRENT_TIMESTAMP ' +
        'WHERE ID = :ID AND STATUS = ''PENDENTE''';
      LQry.ParamByName('ID').AsLargeInt := AConsumoId;
      LQry.ExecSQL;

      { confere se a transição aconteceu (protege contra corrida) }
      LQry.SQL.Text := 'SELECT STATUS FROM CONSUMO_MATERIAL WHERE ID = :ID';
      LQry.ParamByName('ID').AsLargeInt := AConsumoId;
      LQry.Open;
      LStatus := LQry.FieldByName('STATUS').AsString;
      LQry.Close;
      if LStatus <> 'CONFIRMADO' then
        raise EProducao.Create(
          'Não foi possível confirmar o consumo (situação alterada por outro usuário).');

      RegistrarAuditoria('CONSUMO_MATERIAL', 'CONFIRMAR', AConsumoId,
        'STATUS=PENDENTE',
        ResumoAuditoria([
          'STATUS=CONFIRMADO',
          'ITENS=' + IntToStr(Length(LItensIds))]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQry.Free;
  end;
end;

procedure TProducaoService.EstornarConsumo(AConsumoId: Int64;
  const AMotivo: string);
var
  LQry: TSQLQuery;
  LStatus: string;
  LJustificativa: string;
  LDocumento: string;
  LIndice, LJ: Integer;
  LMovId: Int64;
  LItensIds: array of Int64;
  LItensMat: array of Int64;
  LItensQtd: array of Double;
  LItensCusto: array of Double;
  LCodigos: array of string;
begin
  if AConsumoId <= 0 then
    raise EProducao.Create('Consumo de materiais não encontrado.');
  if Trim(AMotivo) = '' then
    raise EProducao.Create('Informe o motivo do estorno do consumo.');

  FConexao.IniciarTransacao;
  LQry := NovaConsulta;
  try
    try
      LQry.SQL.Text :=
        'SELECT STATUS, COALESCE(JUSTIFICATIVA, '''') AS JUSTIFICATIVA ' +
        'FROM CONSUMO_MATERIAL WHERE ID = :ID';
      LQry.ParamByName('ID').AsLargeInt := AConsumoId;
      LQry.Open;
      if LQry.IsEmpty then
        raise EProducao.Create('Consumo de materiais não encontrado.');
      LStatus := LQry.FieldByName('STATUS').AsString;
      LJustificativa := Trim(LQry.FieldByName('JUSTIFICATIVA').AsString);
      LQry.Close;

      if LStatus <> 'CONFIRMADO' then
        raise EProducao.CreateFmt(
          'Só é possível estornar um consumo CONFIRMADO (situação atual: %s).',
          [LStatus]);

      LDocumento := Format('ESTORNO CONSUMO MAPA - #%d', [AConsumoId]);

      { itens que tiveram baixa (movimento vinculado) }
      LQry.SQL.Text :=
        'SELECT I.ID, I.MATERIAL_ID, I.QTD_REAL, I.CUSTO_UNITARIO, ' +
        '  P.CODIGO ' +
        'FROM CONSUMO_MATERIAL_ITEM I ' +
        '  JOIN PRODUTO P ON P.ID = I.MATERIAL_ID ' +
        'WHERE I.CONSUMO_MATERIAL_ID = :CONS ' +
        '  AND I.MOVIMENTO_ESTOQUE_ID IS NOT NULL ORDER BY I.ID';
      LQry.ParamByName('CONS').AsLargeInt := AConsumoId;
      LQry.Open;
      SetLength(LItensIds, 0);
      while not LQry.EOF do
      begin
        LJ := Length(LItensIds);
        SetLength(LItensIds, LJ + 1);
        SetLength(LItensMat, LJ + 1);
        SetLength(LItensQtd, LJ + 1);
        SetLength(LItensCusto, LJ + 1);
        SetLength(LCodigos, LJ + 1);
        LItensIds[LJ] := LQry.FieldByName('ID').AsLargeInt;
        LItensMat[LJ] := LQry.FieldByName('MATERIAL_ID').AsLargeInt;
        LItensQtd[LJ] := LQry.FieldByName('QTD_REAL').AsFloat;
        LItensCusto[LJ] := LQry.FieldByName('CUSTO_UNITARIO').AsFloat;
        LCodigos[LJ] := Trim(LQry.FieldByName('CODIGO').AsString);
        LQry.Next;
      end;
      LQry.Close;

      if Length(LItensIds) = 0 then
        raise EProducao.Create(
          'Este consumo não tem baixas de estoque para estornar.');

      { devolve ao estoque cada item baixado }
      for LIndice := 0 to High(LItensIds) do
      begin
        LQry.SQL.Text :=
          'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, ' +
          '  QUANTIDADE, CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, ' +
          '  DATA_MOVIMENTO, USUARIO_ID) ' +
          'VALUES (:EMP, :PROD, ''E'', :QTD, :CUSTO, :DOC, :OBS, :DATA, :USR)';
        LQry.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQry.ParamByName('PROD').AsLargeInt := LItensMat[LIndice];
        LQry.ParamByName('QTD').AsFloat := LItensQtd[LIndice];
        LQry.ParamByName('CUSTO').AsFloat := LItensCusto[LIndice];
        LQry.ParamByName('DOC').AsString := LDocumento;
        LQry.ParamByName('OBS').AsString := 'Estorno: ' + Trim(AMotivo);
        LQry.ParamByName('DATA').AsDate := Date;
        LQry.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
        LQry.ExecSQL;

        LQry.SQL.Text :=
          'SELECT GEN_ID(GEN_MOVIMENTO_ESTOQUE_ID, 0) FROM RDB$DATABASE';
        LQry.Open;
        LMovId := LQry.Fields[0].AsLargeInt;
        LQry.Close;

        RegistrarAuditoria('CONSUMO_MATERIAL_ITEM', 'ESTORNO', LItensIds[LIndice],
          ResumoAuditoria([
            'MATERIAL=' + LCodigos[LIndice],
            'QTD=' + FormatFloat('#,##0.####', LItensQtd[LIndice])]),
          ResumoAuditoria([
            'MOVIMENTO=' + IntToStr(LMovId),
            'MOTIVO=' + Trim(AMotivo)]));
      end;

      { a justificativa acumula o motivo do estorno }
      if LJustificativa <> '' then
        LJustificativa := LJustificativa + ' | ESTORNO: ' + Trim(AMotivo)
      else
        LJustificativa := 'ESTORNO: ' + Trim(AMotivo);
      if Length(LJustificativa) > 500 then
        LJustificativa := Copy(LJustificativa, 1, 500);

      LQry.SQL.Text :=
        'UPDATE CONSUMO_MATERIAL SET STATUS = ''ESTORNADO'', ' +
        '  DATA_ESTORNO = CURRENT_TIMESTAMP, USUARIO_ESTORNO_ID = :USR, ' +
        '  JUSTIFICATIVA = :JUST ' +
        'WHERE ID = :ID AND STATUS = ''CONFIRMADO''';
      LQry.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQry.ParamByName('JUST').AsString := LJustificativa;
      LQry.ParamByName('ID').AsLargeInt := AConsumoId;
      LQry.ExecSQL;

      LQry.SQL.Text := 'SELECT STATUS FROM CONSUMO_MATERIAL WHERE ID = :ID';
      LQry.ParamByName('ID').AsLargeInt := AConsumoId;
      LQry.Open;
      LStatus := LQry.FieldByName('STATUS').AsString;
      LQry.Close;
      if LStatus <> 'ESTORNADO' then
        raise EProducao.Create(
          'Não foi possível estornar o consumo (situação alterada por outro usuário).');

      RegistrarAuditoria('CONSUMO_MATERIAL', 'ESTORNAR', AConsumoId,
        'STATUS=CONFIRMADO',
        ResumoAuditoria([
          'STATUS=ESTORNADO',
          'ITENS=' + IntToStr(Length(LItensIds)),
          'MOTIVO=' + Trim(AMotivo)]));

      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQry.Free;
  end;
end;

end.
