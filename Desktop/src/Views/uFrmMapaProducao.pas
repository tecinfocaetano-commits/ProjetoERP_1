unit uFrmMapaProducao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 3 - Produção - Mapa de Produção (Fase 2)

  Tela:
    - lista os mapas de produção (filtro por período e status);
    - "Novo do Pedido" mostra os pedidos com saldo a produzir; o
      usuário escolhe o pedido, os itens e as quantidades
      (inclusive parciais) e gera o mapa;
    - ao selecionar um mapa, o painel inferior mostra os itens, os
      talões e o progresso (produzido / em produção / total);
    - "Cancelar Mapa" cancela com motivo (devolve o pedido);

  Nenhuma regra de negócio fica nos eventos: a tela apenas valida
  campos e chama o TProducaoService.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, Grids, DBGrids, DB, SQLDB, DateUtils, Menus,
  LR_Class, LR_DBSet, LR_Barc, lr_e_fclpdf,
  uConexao, uSessao, uProducaoService, uPedidoStatus, uMapaProducaoStatus, uPermissao,
  uGrade, uGradeService, uFrmGradeQuantidades;

type
  { TfrmMapaProducao }
  TfrmMapaProducao = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlFiltros: TPanel;
    lblFiltroDe: TLabel;
    edtFiltroDe: TEdit;
    lblFiltroAte: TLabel;
    edtFiltroAte: TEdit;
    lblFiltroStatus: TLabel;
    cmbFiltroStatus: TComboBox;
    btnFiltrar: TBitBtn;
    pnlBotoes: TPanel;
    btnNovoMapa: TBitBtn;
    btnCancelarMapa: TBitBtn;
    btnFechar: TBitBtn;
    pnlLista: TPanel;
    dbGridMapas: TDBGrid;
    pnlDetalhe: TPanel;
    lblDetalheTitulo: TLabel;
    lblProgresso: TLabel;
    lblTaloesTitulo: TLabel;
    dbGridItensMapa: TDBGrid;
    pnlTaloesBarra: TPanel;
    lblTaloesSel: TLabel;
    btnGerarTaloes: TBitBtn;
    btnVisualizarTalao: TBitBtn;
    btnRelatorioMenu: TBitBtn;      { "Relatório ▼": atalhos do relatório }
    btnImprimirTalao: TBitBtn;
    btnCancelarTalao: TBitBtn;
    pmRelatorio: TPopupMenu;
    mnuRelVisualizar: TMenuItem;
    mnuRelTalaoModeloI: TMenuItem;
    mnuRelTalaoModeloII: TMenuItem;
    mnuRelEditar: TMenuItem;
    mnuRelConfigurar: TMenuItem;
    mnuRelRestaurar: TMenuItem;
    mnuRelSep1: TMenuItem;
    mnuRelTalaoPdf: TMenuItem;
    mnuRelSep2: TMenuItem;
    mnuRelMapaPreview: TMenuItem;
    mnuRelMapaModeloI: TMenuItem;
    mnuRelMapaModeloII: TMenuItem;
    mnuRelMapaPdf: TMenuItem;
    lblQtdTaloes: TLabel;
    dbGridTaloes: TDBGrid;
    pnlCriar: TPanel;
    lblPedidosTitulo: TLabel;
    dbGridPedidos: TDBGrid;
    lblItensTitulo: TLabel;
    dbGridItensPedido: TDBGrid;
    pnlAddItens: TPanel;
    lblQtd: TLabel;
    edtQuantidade: TEdit;
    btnIncluirItem: TBitBtn;
    btnIncluirTodos: TBitBtn;
    btnRemoverItem: TBitBtn;
    lblNovosTitulo: TLabel;
    sgItensNovos: TStringGrid;
    pnlRodapeCriar: TPanel;
    lblObservacao: TLabel;
    edtObservacao: TEdit;
    lblDataPrevista: TLabel;
    edtDataPrevista: TEdit;
    btnGerarMapa: TBitBtn;
    btnVoltar: TBitBtn;
    chkConsumoAutomatico: TCheckBox;
    pnlGrade: TPanel;
    lblGradeTitulo: TLabel;
    lblGradeResumo: TLabel;
    btnEditarGrade: TBitBtn;
    btnCopiarGradePedido: TBitBtn;
    DataSourceMapas: TDataSource;
    DataSourceItensMapa: TDataSource;
    DataSourcePedidos: TDataSource;
    DataSourceItensPedido: TDataSource;
    DataSourceTaloes: TDataSource;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnNovoMapaClick(Sender: TObject);
    procedure btnCancelarMapaClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnVoltarClick(Sender: TObject);
    procedure btnIncluirItemClick(Sender: TObject);
    procedure btnIncluirTodosClick(Sender: TObject);
    procedure btnRemoverItemClick(Sender: TObject);
    procedure btnGerarMapaClick(Sender: TObject);
    procedure dbGridItensPedidoDblClick(Sender: TObject);
    procedure dbGridMapasDblClick(Sender: TObject);
    procedure btnGerarTaloesClick(Sender: TObject);
    procedure btnVisualizarTalaoClick(Sender: TObject);
    procedure btnRelatorioMenuClick(Sender: TObject);
    procedure mnuRelEditarClick(Sender: TObject);
    procedure mnuRelConfigurarClick(Sender: TObject);
    procedure mnuRelRestaurarClick(Sender: TObject);
    procedure mnuRelTalaoPdfClick(Sender: TObject);
    procedure mnuRelMapaPreviewClick(Sender: TObject);
    procedure mnuRelMapaPdfClick(Sender: TObject);
    procedure mnuRelTalaoModelo1Click(Sender: TObject);
    procedure mnuRelTalaoModelo2Click(Sender: TObject);
    procedure mnuRelMapaModelo1Click(Sender: TObject);
    procedure mnuRelMapaModelo2Click(Sender: TObject);
    procedure btnImprimirTalaoClick(Sender: TObject);
    procedure btnCancelarTalaoClick(Sender: TObject);
    procedure DataSourceMapasDataChange(Sender: TObject; Field: TField);
    procedure DataSourcePedidosDataChange(Sender: TObject; Field: TField);
    procedure DataSourceItensPedidoDataChange(Sender: TObject; Field: TField);
    procedure DataSourceItensMapaDataChange(Sender: TObject; Field: TField);
    procedure btnEditarGradeClick(Sender: TObject);
    procedure btnCopiarGradePedidoClick(Sender: TObject);
  private
    FConexao: TConexao;
    FGradeService: TGradeService;
    FUsaGrade: Boolean;
    FAtualizandoGrade: Boolean;
    FMapas: TSQLQuery;
    FItensMapa: TSQLQuery;
    FPedidos: TSQLQuery;
    FItensPedido: TSQLQuery;
    FTaloes: TSQLQuery;          { fonte da grade/relatório de talões }
    FRelMapa: TSQLQuery;         { fonte do relatório do mapa (Fase 6) }
    FFrReport: TfrReport;        { LazReport: talão com código de barras }
    FFrDBTalao: TfrDBDataSet;    { nome deve bater com o DatasetStr do .lrf }
    FFrDBMapa: TfrDBDataSet;     { frDBMapa do mapa_producao.lrf (Fase 6) }
    FService: TProducaoService;
    FMapaId: Int64;
    FPedidoId: Int64;
    FCarregando: Boolean;

    { itens escolhidos para o novo mapa (fonte da verdade) }
    FItensNovos: TItensMapa;
    FCodigos: array of string;
    FDescricoes: array of string;

    procedure CarregarComboStatus;
    procedure CarregarMapas;
    procedure CarregarDetalheMapa(AMapaId: Int64);
    procedure CarregarTaloes(AMapaId: Int64);
    procedure PrepararRelatorioTalao;
    procedure PrepararRelatorioTalaoModelo(const AModelo: Integer);
    function  CaminhoRelatorioTalao: string;
    procedure PrepararRelatorioMapa;
    procedure PrepararRelatorioMapaModelo(const AModelo: Integer);
    function  CaminhoRelatorioMapa: string;
    procedure VisualizarModeloTalao(const AModelo: Integer);
    procedure VisualizarModeloMapa(const AModelo: Integer);
    procedure MarcarModelosNoMenu;
    procedure ExportarPdf(const ASugerido: string);
    function  ItemSelecionadoDoMapa: Int64;
    function  TalaoSelecionado: Int64;
    procedure ModoLista;
    procedure ModoCriar;
    procedure CarregarPedidos;
    procedure CarregarItensPedido(APedidoId: Int64);
    procedure AtualizarGridNovos;
    procedure LimparItensNovos;
    function  IndiceDoItem(AItemPedidoId: Int64): Integer;
    procedure IncluirItem(AQuantidadePendente: Boolean);
    function  LerQuantidade(const ATexto: string): Double;
    function  NumeroDoMapa(AMapaId: Int64): Integer;
    function  VerificarPermissaoAcao(const AAcao, AMensagem: string): Boolean;
    procedure AtualizarInfoGrade;
    function  GradePadraoDoProduto(AProdutoId: Int64): TGradeTamanhos;
    function  EditarGrade(const ATitulo: string;
      const AEntrada: TGradeTamanhos; AExigirQuantidade: Boolean;
      out ASaida: TGradeTamanhos): Boolean;
  end;

var
  frmMapaProducao: TfrmMapaProducao;

implementation

uses
  { editor do LazReport (usuário final): esta unit registra
    ProcedureInitDesigner na initialization dela; sem ela,
    TfrReport.DesignReport volta em silêncio — o clique em
    "Editar relatório (abrir editor)..." não abriria janela nenhuma }
  lr_desgn;

{$R *.lfm}

const
  TOL_QTD = 0.0001;

{ Converte o texto digitado em quantidade, aceitando vírgula ou ponto. }
function TfrmMapaProducao.LerQuantidade(const ATexto: string): Double;
var
  LTexto: string;
begin
  LTexto := Trim(ATexto);
  Result := 0;
  if LTexto = '' then
    Exit;
  LTexto := StringReplace(LTexto, ' ', '', [rfReplaceAll]);
  try
    Result := StrToFloat(LTexto);
  except
    try
      Result := StrToFloat(StringReplace(LTexto, ',', '.', [rfReplaceAll]));
    except
      Result := 0;
    end;
  end;
end;

procedure TfrmMapaProducao.FormCreate(Sender: TObject);
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;

  FMapas := TSQLQuery.Create(Self);
  FMapas.DataBase := FConexao.Connection;
  FMapas.Transaction := FConexao.Transaction;
  DataSourceMapas.DataSet := FMapas;

  FItensMapa := TSQLQuery.Create(Self);
  FItensMapa.DataBase := FConexao.Connection;
  FItensMapa.Transaction := FConexao.Transaction;
  DataSourceItensMapa.DataSet := FItensMapa;

  FPedidos := TSQLQuery.Create(Self);
  FPedidos.DataBase := FConexao.Connection;
  FPedidos.Transaction := FConexao.Transaction;
  DataSourcePedidos.DataSet := FPedidos;

  FItensPedido := TSQLQuery.Create(Self);
  FItensPedido.DataBase := FConexao.Connection;
  FItensPedido.Transaction := FConexao.Transaction;
  DataSourceItensPedido.DataSet := FItensPedido;

  FTaloes := TSQLQuery.Create(Self);
  FTaloes.DataBase := FConexao.Connection;
  FTaloes.Transaction := FConexao.Transaction;
  DataSourceTaloes.DataSet := FTaloes;

  // LazReport: nome do dataset = DatasetStr do relatório talão.lrf
  FFrDBTalao := TfrDBDataSet.Create(Self);
  FFrDBTalao.Name := 'frDBTalao';
  FFrDBTalao.DataSet := FTaloes;
  FFrReport := TfrReport.Create(Self);
  FFrReport.ShowProgress := False;   { relatório curto: sem janela de progresso }

  // Fase 6: dataset do relatório do mapa (mapa_producao.lrf usa frDBMapa)
  FRelMapa := TSQLQuery.Create(Self);
  FRelMapa.DataBase := FConexao.Connection;
  FRelMapa.Transaction := FConexao.Transaction;
  { nome público da query: as expressões do .lrf usam [qryMapaRel."CAMPO"] porque
    o LazReport só resolve TfrDBDataSet pela banda (GetDefaultDataSet devolve nil
    em PageHeader); TDataSet nomeado é achado por frFindComponent em qualquer banda }
  FRelMapa.Name := 'qryMapaRel';
  FFrDBMapa := TfrDBDataSet.Create(Self);
  FFrDBMapa.Name := 'frDBMapa';
  FFrDBMapa.DataSet := FRelMapa;

  FService := TProducaoService.Create;
  FGradeService := TGradeService.Create;
  FUsaGrade := FGradeService.UsaGrade;
  FAtualizandoGrade := False;
  pnlGrade.Visible := FUsaGrade;
  { sem grade a lista de itens usa a largura inteira }
  if not FUsaGrade then
    dbGridItensMapa.Width := dbGridItensMapa.Width + pnlGrade.Width + 8;
  FMapaId := 0;
  FPedidoId := 0;
  FCarregando := False;
  LimparItensNovos;
end;

procedure TfrmMapaProducao.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FGradeService);
end;

procedure TfrmMapaProducao.FormShow(Sender: TObject);
begin
  // permissão de acesso à tela
  if not TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar o Mapa de Produção.',
      mtError, [mbOK], 0);
    Close;
    Exit;
  end;

  CarregarComboStatus;
  edtFiltroDe.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -3));
  edtFiltroAte.Text := FormatDateTime('dd/mm/yyyy', Now);
  edtDataPrevista.Text := FormatDateTime('dd/mm/yyyy', IncDay(Now, 7));
  ModoLista;
  CarregarMapas;
end;

procedure TfrmMapaProducao.CarregarComboStatus;
begin
  cmbFiltroStatus.Items.Clear;
  cmbFiltroStatus.Items.Add('Todos');
  cmbFiltroStatus.Items.Add('Aberto');
  cmbFiltroStatus.Items.Add('Em produção');
  cmbFiltroStatus.Items.Add('Concluído');
  cmbFiltroStatus.Items.Add('Cancelado');
  cmbFiltroStatus.ItemIndex := 0;
end;

procedure TfrmMapaProducao.ModoLista;
begin
  pnlCriar.Visible := False;
  pnlLista.Visible := True;
  btnNovoMapa.Enabled := True;
  btnCancelarMapa.Enabled := True;
end;

procedure TfrmMapaProducao.ModoCriar;
begin
  pnlLista.Visible := False;
  pnlCriar.Visible := True;
  btnNovoMapa.Enabled := False;
  btnCancelarMapa.Enabled := False;
  LimparItensNovos;
  edtObservacao.Text := '';
  edtDataPrevista.Text := FormatDateTime('dd/mm/yyyy', IncDay(Now, 7));
  chkConsumoAutomatico.Checked := False;
  CarregarPedidos;
end;

procedure TfrmMapaProducao.CarregarMapas;
var
  LStatus: string;
  LDataDe, LDataAte: TDate;
begin
  LDataDe := StrToDateDef(edtFiltroDe.Text, IncMonth(Now, -3));
  LDataAte := StrToDateDef(edtFiltroAte.Text, Now);

  if FMapas.Active then
    FMapas.Close;

  FMapas.SQL.Text :=
    'SELECT M.ID, M.NUMERO, M.DATA_CRIACAO, M.DATA_PREVISTA, M.DATA_FIM, ' +
    '  M.STATUS, PV.NUMERO AS PEDIDO, COALESCE(C.NOME, ''(sem cliente)'') AS CLIENTE, ' +
    '  ' + SqlCaseStatusMapa('M.STATUS') + ' AS STATUS_DESC, ' +
    '  (SELECT COUNT(*) FROM MAPA_PRODUCAO_ITEM MI ' +
    '     WHERE MI.MAPA_PRODUCAO_ID = M.ID AND MI.STATUS <> ''CANCELADO'') AS ITENS ' +
    'FROM MAPA_PRODUCAO M ' +
    '  JOIN PEDIDO_VENDA PV ON PV.ID = M.PEDIDO_VENDA_ID ' +
    '  LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    'WHERE M.DATA_CRIACAO >= :DI AND M.DATA_CRIACAO < :DF';

  LStatus := '';
  case cmbFiltroStatus.ItemIndex of
    1: LStatus := 'ABERTO';
    2: LStatus := 'EM_PRODUCAO';
    3: LStatus := 'CONCLUIDO';
    4: LStatus := 'CANCELADO';
  end;
  if LStatus <> '' then
    FMapas.SQL.Text := FMapas.SQL.Text + ' AND M.STATUS = :STATUS';

  FMapas.SQL.Text := FMapas.SQL.Text + ' ORDER BY M.ID DESC';

  FMapas.ParamByName('DI').AsDate := LDataDe;
  FMapas.ParamByName('DF').AsDate := LDataAte + 1;
  if LStatus <> '' then
    FMapas.ParamByName('STATUS').AsString := LStatus;

  FCarregando := True;
  try
    FMapas.Open;
  finally
    FCarregando := False;
  end;

  // mantém o mapa que o usuário estava vindo a ver (se ainda existir no filtro)
  if FMapas.IsEmpty then
    CarregarDetalheMapa(0)
  else
  begin
    if FMapaId > 0 then
      FMapas.Locate('ID', FMapaId, []);   { se não achar, fica no 1º }
    CarregarDetalheMapa(FMapas.FieldByName('ID').AsLargeInt);
  end;

  { após um COMMIT os cursores SQLDB são invalidados e os TDBGrid não se
    repintam sozinhos quando a recarga não vem de um clique do usuário;
    invalidar as três grades garante que sempre reflitam os dados }
  dbGridMapas.Invalidate;
  dbGridItensMapa.Invalidate;
  dbGridTaloes.Invalidate;
end;

procedure TfrmMapaProducao.CarregarDetalheMapa(AMapaId: Int64);
var
  LProduzido, LEmProducao, LTotal: Double;
  LCabecalho: TSQLQuery;
  LPedido, LCliente, LStatus: string;
begin
  FMapaId := AMapaId;

  if FItensMapa.Active then
    FItensMapa.Close;

  CarregarTaloes(AMapaId);   { grade de talões acompanha o mapa selecionado }

  if AMapaId <= 0 then
  begin
    lblDetalheTitulo.Caption := 'Selecione um mapa na lista para ver os itens.';
    lblProgresso.Caption := '';
    AtualizarInfoGrade;
    Exit;
  end;

  FItensMapa.SQL.Text :=
    'SELECT MI.ID, MI.PRODUTO_ID, MI.STATUS, MI.QUANTIDADE, PR.CODIGO, PR.DESCRICAO, ' +
    '  CASE MI.STATUS WHEN ''PENDENTE'' THEN ''Pendente'' ' +
    '       WHEN ''EM_PRODUCAO'' THEN ''Em produção'' ' +
    '       WHEN ''CONCLUIDO'' THEN ''Concluído'' ' +
    '       WHEN ''CANCELADO'' THEN ''Cancelado'' ELSE MI.STATUS END AS STATUS_DESC, ' +
    '  (SELECT COUNT(*) FROM TALAO T WHERE T.MAPA_PRODUCAO_ITEM_ID = MI.ID ' +
    '     AND T.STATUS <> ''CANCELADO'') AS TALOES, ' +
    '  (SELECT COUNT(*) FROM TALAO T WHERE T.MAPA_PRODUCAO_ITEM_ID = MI.ID ' +
    '     AND T.STATUS = ''CONCLUIDO'') AS CONCLUIDOS, ' +
    '  CAST(COALESCE((SELECT SUM(T.QUANTIDADE) FROM TALAO T ' +
    '     WHERE T.MAPA_PRODUCAO_ITEM_ID = MI.ID AND T.STATUS = ''CONCLUIDO''), 0) ' +
    '     AS NUMERIC(18,4)) AS PRODUZIDO ' +
    'FROM MAPA_PRODUCAO_ITEM MI ' +
    '  LEFT JOIN PRODUTO PR ON PR.ID = MI.PRODUTO_ID ' +
    'WHERE MI.MAPA_PRODUCAO_ID = :ID ORDER BY MI.ID';
  FItensMapa.ParamByName('ID').AsLargeInt := AMapaId;
  FItensMapa.Open;

  // cabeçalho + progresso (regra de negócio no service)
  LCabecalho := TSQLQuery.Create(nil);
  try
    LCabecalho.DataBase := FConexao.Connection;
    LCabecalho.Transaction := FConexao.Transaction;
    LCabecalho.SQL.Text :=
      'SELECT M.NUMERO, M.STATUS, PV.NUMERO AS PEDIDO, ' +
      '  COALESCE(C.NOME, ''(sem cliente)'') AS CLIENTE ' +
      'FROM MAPA_PRODUCAO M ' +
      '  JOIN PEDIDO_VENDA PV ON PV.ID = M.PEDIDO_VENDA_ID ' +
      '  LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
      'WHERE M.ID = :ID';
    LCabecalho.ParamByName('ID').AsLargeInt := AMapaId;
    LCabecalho.Open;
    if not LCabecalho.IsEmpty then
    begin
      LPedido := Trim(LCabecalho.FieldByName('PEDIDO').AsString);
      LCliente := Trim(LCabecalho.FieldByName('CLIENTE').AsString);
      LStatus := Trim(LCabecalho.FieldByName('STATUS').AsString);
      lblDetalheTitulo.Caption := Format('Mapa %s   |   Pedido %s   |   %s   |   %s',
        [Trim(LCabecalho.FieldByName('NUMERO').AsString), LPedido, LCliente,
         DescricaoDoStatus(LStatus)]);
    end;
  finally
    LCabecalho.Free;
  end;

  if FService.ProgressoMapa(AMapaId, LProduzido, LEmProducao, LTotal) then
  begin
    if LTotal > TOL_QTD then
      lblProgresso.Caption := Format('Produzido: %s de %s   |   Em produção: %s   |   %s',
        [FormatFloat('#,##0.####', LProduzido), FormatFloat('#,##0.####', LTotal),
         FormatFloat('#,##0.####', LEmProducao),
         FormatFloat('0.0', (LProduzido / LTotal) * 100) + '%'])
    else
      lblProgresso.Caption := 'Mapa sem itens ativos.';
  end
  else
    lblProgresso.Caption := '';

  AtualizarInfoGrade;
end;

procedure TfrmMapaProducao.DataSourceMapasDataChange(Sender: TObject;
  Field: TField);
begin
  if FCarregando then
    Exit;
  if FMapas.Active and (not FMapas.IsEmpty) then
    CarregarDetalheMapa(FMapas.FieldByName('ID').AsLargeInt);
end;

procedure TfrmMapaProducao.CarregarPedidos;
begin
  FPedidoId := 0;
  if FPedidos.Active then
    FPedidos.Close;

  FPedidos.SQL.Text :=
    'SELECT PV.ID, PV.NUMERO, PV.DATA_EMISSAO, PV.TOTAL, PV.STATUS, ' +
    '  COALESCE(C.NOME, ''(sem cliente)'') AS CLIENTE, ' +
    '  ' + SqlCaseStatusPedido('PV.STATUS') + ' AS STATUS_DESC ' +
    'FROM PEDIDO_VENDA PV LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    'WHERE PV.STATUS IN (''P'', ''A'', ''E'') AND PV.EMPRESA_ID = :EMP ' +
    '  AND EXISTS (SELECT 1 FROM ITEM_PEDIDO I WHERE I.PEDIDO_VENDA_ID = PV.ID ' +
    '        AND I.QUANTIDADE > COALESCE((SELECT SUM(MI.QUANTIDADE) ' +
    '              FROM MAPA_PRODUCAO_ITEM MI ' +
    '                JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
    '              WHERE MI.ITEM_PEDIDO_ID = I.ID AND M.STATUS <> ''CANCELADO''), 0)) ' +
    'ORDER BY PV.ID DESC';
  FPedidos.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  FPedidos.Open;

  if FItensPedido.Active then
    FItensPedido.Close;
  if FPedidos.IsEmpty then
  begin
    lblItensTitulo.Caption := 'Não há pedidos com saldo a produzir.';
    lblPedidosTitulo.Caption := 'Pedidos com saldo a produzir - nenhum encontrado';
  end
  else
  begin
    lblPedidosTitulo.Caption := 'Pedidos com saldo a produzir (selecione um)';
    DataSourcePedidosDataChange(nil, nil);
  end;
end;

procedure TfrmMapaProducao.DataSourcePedidosDataChange(Sender: TObject;
  Field: TField);
begin
  if (not FPedidos.Active) or FPedidos.IsEmpty then
    Exit;
  CarregarItensPedido(FPedidos.FieldByName('ID').AsLargeInt);
end;

procedure TfrmMapaProducao.CarregarItensPedido(APedidoId: Int64);
begin
  FPedidoId := APedidoId;
  if FItensPedido.Active then
    FItensPedido.Close;

  FItensPedido.SQL.Text :=
    'SELECT I.ID, I.PRODUTO_ID, PR.CODIGO, PR.DESCRICAO, ' +
    '  CAST(I.QUANTIDADE AS NUMERIC(18,4)) AS PEDIDA, ' +
    '  CAST(COALESCE((SELECT SUM(MI.QUANTIDADE) FROM MAPA_PRODUCAO_ITEM MI ' +
    '        JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
    '        WHERE MI.ITEM_PEDIDO_ID = I.ID AND M.STATUS <> ''CANCELADO''), 0) ' +
    '      AS NUMERIC(18,4)) AS MAPEADO, ' +
    '  CAST(I.QUANTIDADE - COALESCE((SELECT SUM(MI.QUANTIDADE) ' +
    '        FROM MAPA_PRODUCAO_ITEM MI ' +
    '          JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
    '        WHERE MI.ITEM_PEDIDO_ID = I.ID AND M.STATUS <> ''CANCELADO''), 0) ' +
    '      AS NUMERIC(18,4)) AS PENDENTE ' +
    'FROM ITEM_PEDIDO I LEFT JOIN PRODUTO PR ON PR.ID = I.PRODUTO_ID ' +
    'WHERE I.PEDIDO_VENDA_ID = :PED ORDER BY I.ID';
  FItensPedido.ParamByName('PED').AsLargeInt := APedidoId;
  FItensPedido.Open;

  if FItensPedido.IsEmpty then
    lblItensTitulo.Caption := 'Itens do pedido - nenhum item'
  else
    lblItensTitulo.Caption := 'Itens do pedido (duplo clique inclui a quantidade pendente)';
end;

procedure TfrmMapaProducao.DataSourceItensPedidoDataChange(Sender: TObject;
  Field: TField);
begin
  if (not FItensPedido.Active) or FItensPedido.IsEmpty then
    Exit;
  edtQuantidade.Text := FormatFloat('0.####', FItensPedido.FieldByName('PENDENTE').AsFloat);
end;

{ ---------------- GRADE do item do mapa (sob USA_GRADE) ---------------- }

procedure TfrmMapaProducao.AtualizarInfoGrade;
var
  LTamanhos: TGradeTamanhos;
  LResumo: string;
  I: Integer;
begin
  if not FUsaGrade then
    Exit;
  if FAtualizandoGrade then
    Exit;

  FAtualizandoGrade := True;
  try
    btnEditarGrade.Enabled := FItensMapa.Active and (not FItensMapa.IsEmpty);
    btnCopiarGradePedido.Enabled := btnEditarGrade.Enabled;

    if not btnEditarGrade.Enabled then
    begin
      lblGradeResumo.Caption := 'Selecione um item do mapa.';
      Exit;
    end;

    LTamanhos := FGradeService.GradeDoMapaItem(ItemSelecionadoDoMapa);
    if Length(LTamanhos) = 0 then
    begin
      lblGradeResumo.Caption :=
        'Sem grade informada para este item.' + sLineBreak +
        'Use "Editar grade..." ou "Copiar do pedido".';
      Exit;
    end;

    LResumo := '';
    for I := 0 to High(LTamanhos) do
      if LTamanhos[I].Quantidade > 0 then
        LResumo := LResumo + Format('%s:%s   ', [LTamanhos[I].Tamanho,
          FormatFloat('0.####', LTamanhos[I].Quantidade)]);
    if LResumo = '' then
      LResumo := 'Grade com ' + IntToStr(Length(LTamanhos)) +
        ' tamanho(s), ainda sem quantidades.';

    lblGradeResumo.Caption := LResumo + sLineBreak + 'Total da grade: ' +
      FormatFloat('#,##0.####', SomarQuantidades(LTamanhos));
  finally
    FAtualizandoGrade := False;
  end;
end;

procedure TfrmMapaProducao.DataSourceItensMapaDataChange(Sender: TObject;
  Field: TField);
begin
  AtualizarInfoGrade;
end;

function TfrmMapaProducao.GradePadraoDoProduto(
  AProdutoId: Int64): TGradeTamanhos;
var
  LGradeId: Int64;
  LOrigem: TGradeTamanhos;
  I: Integer;
begin
  Result := nil;
  if AProdutoId <= 0 then
    Exit;
  LGradeId := FGradeService.GradeDoProduto(AProdutoId);
  if LGradeId <= 0 then
    Exit;

  LOrigem := FGradeService.ListarTamanhos(LGradeId);
  for I := 0 to High(LOrigem) do
    if LOrigem[I].Ativo <> 'I' then
    begin
      SetLength(Result, Length(Result) + 1);
      with Result[High(Result)] do
      begin
        Id := 0;
        Tamanho := LOrigem[I].Tamanho;
        Ordem := Length(Result) - 1;
        Quantidade := 0;
        Ativo := 'A';
      end;
    end;
end;

function TfrmMapaProducao.EditarGrade(const ATitulo: string;
  const AEntrada: TGradeTamanhos; AExigirQuantidade: Boolean;
  out ASaida: TGradeTamanhos): Boolean;
begin
  ASaida := nil;
  with TfrmGradeQuantidades.Create(nil) do
  try
    Carregar(AEntrada, ATitulo, AExigirQuantidade);
    Result := ShowModal = mrOk;
    if Result then
      ASaida := Tamanhos;
  finally
    Free;
  end;
end;

procedure TfrmMapaProducao.btnEditarGradeClick(Sender: TObject);
var
  LItemId, LProdutoId: Int64;
  LTamanhos, LEntrada, LNova: TGradeTamanhos;
begin
  if not FUsaGrade then
    Exit;

  LItemId := ItemSelecionadoDoMapa;
  if LItemId <= 0 then
  begin
    MessageDlg('Selecione um item do mapa.', mtInformation, [mbOK], 0);
    Exit;
  end;

  LTamanhos := FGradeService.GradeDoMapaItem(LItemId);
  if Length(LTamanhos) = 0 then
  begin
    LProdutoId := 0;
    if not FItensMapa.FieldByName('PRODUTO_ID').IsNull then
      LProdutoId := FItensMapa.FieldByName('PRODUTO_ID').AsLargeInt;
    LEntrada := GradePadraoDoProduto(LProdutoId);
    if Length(LEntrada) = 0 then
    begin
      MessageDlg('Este item não tem grade e o produto não possui grade ' +
        'padrão definida.' + sLineBreak + sLineBreak +
        'Defina a grade padrão em Cadastros > Produtos.',
        mtInformation, [mbOK], 0);
      Exit;
    end;
  end
  else
    LEntrada := LTamanhos;

  if not EditarGrade('Grade do item - ' +
    FItensMapa.FieldByName('DESCRICAO').AsString,
    LEntrada, False, LNova) then
    Exit;

  try
    FGradeService.SalvarGradeMapaItem(LItemId, LNova);
    CarregarMapas;
  except
    on E: Exception do
      MessageDlg('Erro ao gravar a grade do item: ' + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.btnCopiarGradePedidoClick(Sender: TObject);
var
  LItemId, LItemPedidoId: Int64;
  LCopiados: Integer;
begin
  if not FUsaGrade then
    Exit;

  LItemId := ItemSelecionadoDoMapa;
  if LItemId <= 0 then
  begin
    MessageDlg('Selecione um item do mapa.', mtInformation, [mbOK], 0);
    Exit;
  end;

  try
    LItemPedidoId := FGradeService.ItemPedidoDoMapaItem(LItemId);
    if LItemPedidoId <= 0 then
    begin
      MessageDlg('Este item do mapa não está ligado a um item do pedido.',
        mtInformation, [mbOK], 0);
      Exit;
    end;

    LCopiados := FGradeService.CopiarGradeDoPedidoParaMapa(LItemId);
    if LCopiados <= 0 then
    begin
      MessageDlg('O item do pedido não tem grade para copiar.',
        mtInformation, [mbOK], 0);
      Exit;
    end;

    CarregarMapas;
  except
    on E: Exception do
      MessageDlg('Erro ao copiar a grade do pedido: ' + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.LimparItensNovos;
begin
  SetLength(FItensNovos, 0);
  SetLength(FCodigos, 0);
  SetLength(FDescricoes, 0);
  AtualizarGridNovos;
end;

procedure TfrmMapaProducao.AtualizarGridNovos;
var
  LIndice: Integer;
begin
  sgItensNovos.RowCount := Length(FItensNovos) + 1;
  for LIndice := 0 to High(FItensNovos) do
  begin
    sgItensNovos.Cells[0, LIndice + 1] := FCodigos[LIndice];
    sgItensNovos.Cells[1, LIndice + 1] := FDescricoes[LIndice];
    sgItensNovos.Cells[2, LIndice + 1] :=
      FormatFloat('#,##0.####', FItensNovos[LIndice].Quantidade);
  end;
  sgItensNovos.Invalidate;
end;

function TfrmMapaProducao.IndiceDoItem(AItemPedidoId: Int64): Integer;
var
  LIndice: Integer;
begin
  Result := -1;
  for LIndice := 0 to High(FItensNovos) do
    if FItensNovos[LIndice].ItemPedidoId = AItemPedidoId then
      Exit(LIndice);
end;

procedure TfrmMapaProducao.IncluirItem(AQuantidadePendente: Boolean);
var
  LItemPedidoId: Int64;
  LQuantidade, LPendente: Double;
  LIndice: Integer;
begin
  if (not FItensPedido.Active) or FItensPedido.IsEmpty then
  begin
    MessageDlg('Selecione um pedido com itens para incluir no mapa.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  LItemPedidoId := FItensPedido.FieldByName('ID').AsLargeInt;
  LPendente := FItensPedido.FieldByName('PENDENTE').AsFloat;
  if LPendente <= TOL_QTD then
  begin
    MessageDlg('Este item já foi totalmente mapeado.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if AQuantidadePendente then
    LQuantidade := LPendente
  else
  begin
    LQuantidade := LerQuantidade(edtQuantidade.Text);
    if LQuantidade <= 0 then
    begin
      MessageDlg('Informe a quantidade a produzir (maior que zero).',
        mtWarning, [mbOK], 0);
      edtQuantidade.SetFocus;
      Exit;
    end;
  end;

  if LQuantidade > LPendente + TOL_QTD then
  begin
    MessageDlg(Format('A quantidade informada (%s) ultrapassa o saldo pendente do item (%s).',
      [FormatFloat('#,##0.####', LQuantidade), FormatFloat('#,##0.####', LPendente)]),
      mtWarning, [mbOK], 0);
    Exit;
  end;

  LIndice := IndiceDoItem(LItemPedidoId);
  if LIndice >= 0 then
  begin
    FItensNovos[LIndice].Quantidade := LQuantidade;
    FItensNovos[LIndice].ProdutoId := FItensPedido.FieldByName('PRODUTO_ID').AsLargeInt;
  end
  else
  begin
    SetLength(FItensNovos, Length(FItensNovos) + 1);
    LIndice := High(FItensNovos);
    FItensNovos[LIndice].ItemPedidoId := LItemPedidoId;
    FItensNovos[LIndice].ProdutoId := FItensPedido.FieldByName('PRODUTO_ID').AsLargeInt;
    FItensNovos[LIndice].Quantidade := LQuantidade;
    SetLength(FCodigos, Length(FItensNovos));
    SetLength(FDescricoes, Length(FItensNovos));
    FCodigos[LIndice] := Trim(FItensPedido.FieldByName('CODIGO').AsString);
    FDescricoes[LIndice] := Trim(FItensPedido.FieldByName('DESCRICAO').AsString);
  end;

  AtualizarGridNovos;
end;

procedure TfrmMapaProducao.btnIncluirItemClick(Sender: TObject);
begin
  IncluirItem(False);
end;

procedure TfrmMapaProducao.btnIncluirTodosClick(Sender: TObject);
var
  LMarcador: TBookmark;
  LQuantidade: Double;
  LIndice: Integer;
begin
  if (not FItensPedido.Active) or FItensPedido.IsEmpty then
  begin
    MessageDlg('Selecione um pedido com itens para incluir no mapa.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  LMarcador := FItensPedido.GetBookmark;
  FItensPedido.DisableControls;
  try
    FItensPedido.First;
    while not FItensPedido.EOF do
    begin
      LQuantidade := FItensPedido.FieldByName('PENDENTE').AsFloat;
      if LQuantidade > TOL_QTD then
      begin
        LIndice := IndiceDoItem(FItensPedido.FieldByName('ID').AsLargeInt);
        if LIndice < 0 then
        begin
          SetLength(FItensNovos, Length(FItensNovos) + 1);
          LIndice := High(FItensNovos);
          SetLength(FCodigos, Length(FItensNovos));
          SetLength(FDescricoes, Length(FItensNovos));
          FItensNovos[LIndice].ItemPedidoId := FItensPedido.FieldByName('ID').AsLargeInt;
          FCodigos[LIndice] := Trim(FItensPedido.FieldByName('CODIGO').AsString);
          FDescricoes[LIndice] := Trim(FItensPedido.FieldByName('DESCRICAO').AsString);
        end;
        FItensNovos[LIndice].ProdutoId := FItensPedido.FieldByName('PRODUTO_ID').AsLargeInt;
        FItensNovos[LIndice].Quantidade := LQuantidade;
      end;
      FItensPedido.Next;
    end;
  finally
    FItensPedido.EnableControls;
    if FItensPedido.BookmarkValid(LMarcador) then
      FItensPedido.GotoBookmark(LMarcador);
    FItensPedido.FreeBookmark(LMarcador);
  end;

  AtualizarGridNovos;
end;

procedure TfrmMapaProducao.btnRemoverItemClick(Sender: TObject);
var
  LIndice, LPosicao: Integer;
begin
  LPosicao := sgItensNovos.Row - 1;   // linha 0 é o cabeçalho
  if (LPosicao < 0) or (LPosicao > High(FItensNovos)) then
  begin
    MessageDlg('Selecione na lista um item para remover.', mtInformation, [mbOK], 0);
    Exit;
  end;

  for LIndice := LPosicao to High(FItensNovos) - 1 do
  begin
    FItensNovos[LIndice] := FItensNovos[LIndice + 1];
    FCodigos[LIndice] := FCodigos[LIndice + 1];
    FDescricoes[LIndice] := FDescricoes[LIndice + 1];
  end;
  SetLength(FItensNovos, Length(FItensNovos) - 1);
  SetLength(FCodigos, Length(FItensNovos));
  SetLength(FDescricoes, Length(FItensNovos));
  AtualizarGridNovos;
end;

procedure TfrmMapaProducao.dbGridItensPedidoDblClick(Sender: TObject);
begin
  IncluirItem(True);
end;

procedure TfrmMapaProducao.dbGridMapasDblClick(Sender: TObject);
begin
  if FMapas.Active and (not FMapas.IsEmpty) then
    CarregarDetalheMapa(FMapas.FieldByName('ID').AsLargeInt);
end;

procedure TfrmMapaProducao.btnNovoMapaClick(Sender: TObject);
begin
  if not VerificarPermissaoAcao(PERM_INSERIR,
    'Seu usuário não tem permissão para gerar mapas de produção.') then
    Exit;
  ModoCriar;
end;

procedure TfrmMapaProducao.btnVoltarClick(Sender: TObject);
begin
  ModoLista;
  CarregarMapas;
end;

procedure TfrmMapaProducao.btnGerarMapaClick(Sender: TObject);
var
  LMapaId: Int64;
  LDataPrevista: TDate;
begin
  if FPedidoId <= 0 then
  begin
    MessageDlg('Selecione o pedido de venda que será produzido.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if Length(FItensNovos) = 0 then
  begin
    MessageDlg('Inclua ao menos um item na lista do mapa.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if not VerificarPermissaoAcao(PERM_INSERIR,
    'Seu usuário não tem permissão para gerar mapas de produção.') then
    Exit;

  LDataPrevista := StrToDateDef(edtDataPrevista.Text, 0);

  try
    LMapaId := FService.CriarMapa(FPedidoId, FItensNovos, edtObservacao.Text,
      LDataPrevista);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível gerar o mapa de produção:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
      Exit;
    end;
  end;

  { consumo automático: gera o consumo pela base planejada ainda sem
    talões concluídos. Uma falha aqui não desfaz o mapa já criado. }
  if chkConsumoAutomatico.Checked then
  begin
    try
      FService.GerarConsumoMaterial(LMapaId,
        'Consumo automático (base planejada) - mapa nº ' +
        IntToStr(NumeroDoMapa(LMapaId)), True);
    except
      on E: Exception do
        MessageDlg('Mapa gerado, mas o consumo automático falhou:' +
          sLineBreak + E.Message, mtWarning, [mbOK], 0);
    end;
  end;

  MessageDlg(Format('Mapa de produção nº %d gerado com sucesso.' + sLineBreak +
    'Pedido selecionado: %d   |   Itens no mapa: %d',
    [NumeroDoMapa(LMapaId), FPedidoId, Length(FItensNovos)]),
    mtInformation, [mbOK], 0);

  ModoLista;
  CarregarMapas;
end;

procedure TfrmMapaProducao.btnCancelarMapaClick(Sender: TObject);
var
  LMotivo: string;
  LStatus: string;
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;

  LStatus := FMapas.FieldByName('STATUS').AsString;
  if LStatus = 'CANCELADO' then
  begin
    MessageDlg(Format('O mapa de produção nº %d já está cancelado.',
      [NumeroDoMapa(FMapaId)]), mtInformation, [mbOK], 0);
    Exit;
  end;

  if not VerificarPermissaoAcao(PERM_EXCLUIR,
    'Seu usuário não tem permissão para cancelar mapas de produção.') then
    Exit;

  LMotivo := '';
  if not InputQuery('Cancelar mapa de produção',
    'Motivo do cancelamento:', LMotivo) then
    Exit;
  if Trim(LMotivo) = '' then
  begin
    MessageDlg('Informe o motivo do cancelamento.', mtWarning, [mbOK], 0);
    Exit;
  end;

  try
    FService.CancelarMapa(FMapaId, LMotivo);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível cancelar o mapa:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
      Exit;
    end;
  end;

  MessageDlg(Format('Mapa de produção nº %d cancelado com sucesso.',
    [NumeroDoMapa(FMapaId)]), mtInformation, [mbOK], 0);
  CarregarMapas;
end;

procedure TfrmMapaProducao.btnFiltrarClick(Sender: TObject);
begin
  CarregarMapas;
end;

procedure TfrmMapaProducao.btnFecharClick(Sender: TObject);
begin
  Close;
end;

function TfrmMapaProducao.NumeroDoMapa(AMapaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT NUMERO FROM MAPA_PRODUCAO WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := AMapaId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('NUMERO').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TfrmMapaProducao.VerificarPermissaoAcao(const AAcao,
  AMensagem: string): Boolean;
begin
  Result := TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, AAcao);
  if not Result then
    MessageDlg(AMensagem, mtWarning, [mbOK], 0);
end;

{ =====================================================================
  TALÕES (Fase 3) - grade, geração e relatório LazReport (Code128B)
  ===================================================================== }

procedure TfrmMapaProducao.CarregarTaloes(AMapaId: Int64);
var
  LTotal: Integer;
begin
  if FTaloes.Active then
    FTaloes.Close;
  lblQtdTaloes.Caption := '';

  if AMapaId <= 0 then
    Exit;

  // mesmos campos entram na grade e no relatório talão.lrf
  FTaloes.SQL.Text :=
    'SELECT T.ID, T.NUMERO, T.SEQUENCIA, ' +
    '  CAST(T.QUANTIDADE AS NUMERIC(15,4)) AS QTD, ' +
    '  T.CODIGO_BARRAS, T.DATA_GERACAO, ' +
    '  COALESCE(T.QTD_IMPRESSOES, 0) AS QTD_IMPRESSOES, ' +
    '  CASE T.STATUS WHEN ''GERADO'' THEN ''Gerado'' ' +
    '       WHEN ''IMPRESSO'' THEN ''Impresso'' ' +
    '       WHEN ''EM_PRODUCAO'' THEN ''Em produção'' ' +
    '       WHEN ''CONCLUIDO'' THEN ''Concluído'' ' +
    '       WHEN ''CANCELADO'' THEN ''Cancelado'' ELSE T.STATUS END AS STATUS_DESC, ' +
    '  COALESCE(PR.CODIGO, '''') || ' +
    '    CASE WHEN PR.DESCRICAO IS NULL THEN '''' ELSE '' - '' || PR.DESCRICAO END ' +
    '    AS PRODUTO, ' +
    '  M.NUMERO AS MAPA_NUMERO, PV.NUMERO AS PEDIDO_NUMERO, ' +
    '  COALESCE(C.NOME, ''(sem cliente)'') AS CLIENTE, ' +
    '  CASE WHEN M.DATA_PREVISTA IS NULL THEN '''' ELSE ' +
    '    SUBSTRING(CAST(M.DATA_PREVISTA AS VARCHAR(10)) FROM 9 FOR 2) || ''/'' || ' +
    '    SUBSTRING(CAST(M.DATA_PREVISTA AS VARCHAR(10)) FROM 6 FOR 2) || ''/'' || ' +
    '    SUBSTRING(CAST(M.DATA_PREVISTA AS VARCHAR(10)) FROM 1 FOR 4) END AS PREVISTA, ' +
    '  CASE WHEN T.DATA_GERACAO IS NULL THEN '''' ELSE ' +
    '    SUBSTRING(CAST(CAST(T.DATA_GERACAO AS DATE) AS VARCHAR(10)) FROM 9 FOR 2) || ''/'' || ' +
    '    SUBSTRING(CAST(CAST(T.DATA_GERACAO AS DATE) AS VARCHAR(10)) FROM 6 FOR 2) || ''/'' || ' +
    '    SUBSTRING(CAST(CAST(T.DATA_GERACAO AS DATE) AS VARCHAR(10)) FROM 1 FOR 4) END AS EMISSAO ' +
    'FROM TALAO T ' +
    '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.ID = T.MAPA_PRODUCAO_ITEM_ID ' +
    '  JOIN MAPA_PRODUCAO M ON M.ID = MI.MAPA_PRODUCAO_ID ' +
    '  JOIN PEDIDO_VENDA PV ON PV.ID = M.PEDIDO_VENDA_ID ' +
    '  LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    '  LEFT JOIN PRODUTO PR ON PR.ID = MI.PRODUTO_ID ' +
    'WHERE M.ID = :MAPA ' +
    'ORDER BY T.NUMERO';
  FTaloes.ParamByName('MAPA').AsLargeInt := AMapaId;
  FTaloes.Open;

  { máscara do campo numérico (TField base não expõe DisplayFormat) }
  if FTaloes.FieldByName('QTD') is TNumericField then
    TNumericField(FTaloes.FieldByName('QTD')).DisplayFormat := '#,##0.####';

  LTotal := 0;
  FTaloes.First;
  while not FTaloes.EOF do
  begin
    Inc(LTotal);
    FTaloes.Next;
  end;
  FTaloes.First;

  if LTotal = 0 then
    lblQtdTaloes.Caption := 'Nenhum talão gerado para este mapa.'
  else
    lblQtdTaloes.Caption := Format(
      '%d talão(ões) no mapa   |   novos talões são gerados no item selecionado na lista acima.',
      [LTotal]);
end;

function TfrmMapaProducao.ItemSelecionadoDoMapa: Int64;
begin
  Result := 0;
  if FItensMapa.Active and (not FItensMapa.IsEmpty) then
    Result := FItensMapa.FieldByName('ID').AsLargeInt;
end;

function TfrmMapaProducao.TalaoSelecionado: Int64;
begin
  Result := 0;
  if FTaloes.Active and (not FTaloes.IsEmpty) then
    Result := FTaloes.FieldByName('ID').AsLargeInt;
end;

function TfrmMapaProducao.CaminhoRelatorioTalao: string;
begin
  { o caminho vem da CONFIGURACAO (PRODUCAO_TALAO_RELATORIO); o
    usuário final pode trocá-lo em "Relatório ▼ → Configurar" }
  Result := FService.CaminhoRelatorioTalao;
end;

{ Carrega o .lrf do modelo pedido (1 ou 2). Os DOIS modelos apontam para
  os MESMOS datasets (FFrDBTalao): só o arquivo carregado muda, então os
  dados são idênticos e só o layout difere. }
procedure TfrmMapaProducao.PrepararRelatorioTalaoModelo(const AModelo: Integer);
var
  LCaminho: string;
begin
  LCaminho := FService.CaminhoRelatorioTalaoModelo(AModelo);
  if not FileExists(LCaminho) then
    raise Exception.Create(
      'Arquivo do relatório de talão (Modelo ' + IntToStr(AModelo) +
      ') não encontrado:' + sLineBreak +
      LCaminho + sLineBreak + sLineBreak +
      'Use "Relatório ▼ → Configurar" para indicar onde está o .lrf ' +
      '(ex.: uma cópia editada) ou "Restaurar padrão" para voltar ao ' +
      'relatório padrão ao lado do ERP2026.exe.');
  FFrReport.LoadFromFile(LCaminho);   { .lrf = XML do LazReport }
end;

procedure TfrmMapaProducao.PrepararRelatorioTalao;
begin
  { visualizar/imprimir/exportar sem escolher usam o modelo ativo }
  PrepararRelatorioTalaoModelo(FService.ModeloAtivo(CFG_TALAO_MODELO));
end;

procedure TfrmMapaProducao.btnGerarTaloesClick(Sender: TObject);
var
  LItemId: Int64;
  LGerados, LUltimo: Integer;
  LModo, LStatus: string;
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;

  LItemId := ItemSelecionadoDoMapa;
  if LItemId <= 0 then
  begin
    MessageDlg('Selecione um item do mapa (lista superior) para gerar os talões.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  LStatus := Trim(FMapas.FieldByName('STATUS').AsString);
  if (LStatus <> 'ABERTO') and (LStatus <> 'EM_PRODUCAO') then
  begin
    MessageDlg(Format(
      'O mapa nº %d está como "%s": talões só podem ser gerados em mapa aberto ou em produção.',
      [NumeroDoMapa(FMapaId), DescricaoDoStatus(LStatus)]),
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if not VerificarPermissaoAcao(PERM_INSERIR,
    'Seu usuário não tem permissão para gerar talões de produção.') then
    Exit;

  LModo := FService.ModoTalao;
  if MessageDlg('Gerar talões',
    Format('Gerar talões para o item selecionado?' + sLineBreak + sLineBreak +
      'Modo configurado: %s (chave PRODUCAO_TALAO_MODO)' + sLineBreak +
      'A quantidade de talões respeita o saldo pendente do item.',
      [LModo]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    LUltimo := FService.GerarTaloes(LItemId, LModo, LGerados);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível gerar os talões:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
      { a transação do service sofreu rollback: recarrega para as grades
        não ficarem com cursores invalidados (SQLDB invalida cursores abertos) }
      try
        CarregarMapas;
      except
        { se o recarregar falhar, mantém a tela como está }
      end;
      Exit;
    end;
  end;

  MessageDlg(Format('%d talão(ões) gerado(s) com sucesso.' + sLineBreak +
    'Último número: %d   |   Código de barras: %s',
    [LGerados, LUltimo, Format('T%.6d', [LUltimo])]),
    mtInformation, [mbOK], 0);

  CarregarMapas;   { lista, itens, progresso e talões }
end;

procedure TfrmMapaProducao.btnVisualizarTalaoClick(Sender: TObject);
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (not FTaloes.Active) or FTaloes.IsEmpty then
  begin
    MessageDlg('Este mapa ainda não tem talões. Use "Gerar Talões" primeiro.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  try
    PrepararRelatorioTalao;
    FFrReport.ShowReport;   { pré-visualização; não altera status dos talões }
  except
    on E: Exception do
      MessageDlg('Não foi possível exibir o relatório de talões:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
  end;
end;

{ --- atalhos do relatório (Fase 4) ----------------------------------
  "Relatório ▼" abre um menu com:
    - Visualizar   (o mesmo botão Visualizar);
    - Modelo I / Modelo II  (escolhe o .lrf de cada relatório);
    - Editar       (abre o editor do LazReport para o usuário final
                    ajustar o layout e salvar no próprio .lrf);
    - Configurar   (troca o "link": o arquivo .lrf usado pelo sistema);
    - Restaurar padrão.
  Fase 6 (mesmo menu):
    - Exportar talões em PDF...        (TlrPdfExportFilter);
    - Relatório do mapa (visualizar)   (mapa_producao.lrf);
    - Relatório do mapa (exportar PDF). }

procedure TfrmMapaProducao.btnRelatorioMenuClick(Sender: TObject);
var
  LPos: TPoint;
begin
  { ancora o menu embaixo do próprio botão: Left/Top do botão são relativos
    ao painel que o contém, então converter para coordenadas de tela
    (ClientToScreen) — sem isso o menu abria no topo do formulário }
  LPos := btnRelatorioMenu.ClientToScreen(Point(0, btnRelatorioMenu.Height));
  MarcarModelosNoMenu;   { ponteiro no modelo ativo de cada relatório }
  pmRelatorio.PopUp(LPos.X, LPos.Y);
end;

procedure TfrmMapaProducao.mnuRelEditarClick(Sender: TObject);
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (not FTaloes.Active) or FTaloes.IsEmpty then
  begin
    MessageDlg('Este mapa ainda não tem talões. Use "Gerar Talões" primeiro.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if not VerificarPermissaoAcao(PERM_EDITAR,
    'Seu usuário não tem permissão para editar o relatório de talões.') then
    Exit;

  try
    PrepararRelatorioTalao;
    { editor do LazReport: o usuário ajusta o layout e salva no .lrf;
      o mesmo arquivo é usado pela visualização e pela impressão }
    FFrReport.DesignReport;
  except
    on E: Exception do
      MessageDlg('Não foi possível abrir o editor do relatório:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.mnuRelConfigurarClick(Sender: TObject);
var
  LDlg: TOpenDialog;
  LNovo: string;
begin
  if not VerificarPermissaoAcao(PERM_EDITAR,
    'Seu usuário não tem permissão para configurar o relatório de talões.') then
    Exit;

  LDlg := TOpenDialog.Create(Self);
  try
    LDlg.Title := 'Selecionar o arquivo do relatório de talões';
    LDlg.Filter := 'Relatórios LazReport (*.lrf)|*.lrf|Todos os arquivos (*.*)|*.*';
    LDlg.Options := LDlg.Options + [ofFileMustExist, ofPathMustExist];
    LDlg.InitialDir := ExtractFilePath(CaminhoRelatorioTalao);
    if not LDlg.Execute then
      Exit;
    LNovo := LDlg.FileName;
  finally
    LDlg.Free;
  end;

  try
    FService.DefinirCaminhoRelatorioTalao(LNovo);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível salvar a configuração:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
      { rollback no service: recarrega para as grades não ficarem vazias }
      try
        CarregarMapas;
      except
      end;
      Exit;
    end;
  end;

  MessageDlg('Relatório configurado com sucesso.' + sLineBreak + sLineBreak +
    'Visualização e impressão passam a usar:' + sLineBreak + LNovo,
    mtInformation, [mbOK], 0);
  CarregarMapas;   { o COMMIT da CONFIGURACAO invalida os cursores SQLDB }
end;

procedure TfrmMapaProducao.mnuRelRestaurarClick(Sender: TObject);
begin
  if not VerificarPermissaoAcao(PERM_EDITAR,
    'Seu usuário não tem permissão para configurar o relatório de talões.') then
    Exit;

  if MessageDlg('Restaurar o relatório padrão do sistema?' + sLineBreak + sLineBreak +
    '(relatorios\talao.lrf ao lado do ERP2026.exe)', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    FService.DefinirCaminhoRelatorioTalao('');
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível restaurar o relatório padrão:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
      try
        CarregarMapas;
      except
      end;
      Exit;
    end;
  end;

  MessageDlg('Relatório padrão restaurado.' + sLineBreak + sLineBreak +
    CaminhoRelatorioTalao, mtInformation, [mbOK], 0);
  CarregarMapas;   { o COMMIT da CONFIGURACAO invalida os cursores SQLDB }
end;

{ --- Modelos I e II (mesmos datasets) --------------------------------
  Cada relatório tem dois arquivos .lrf: Modelo I (o original) e Modelo II
  (uma cópia, para o usuário editar à parte no designer do LazReport).
  Os dois apontam para o MESMO dataset — só o layout muda. Escolher um
  modelo: 1) grava o modelo ativo na CONFIGURACAO (visualizar, imprimir e
  exportar passam a usá-lo); 2) o COMMIT invalida os cursores SQLDB, então
  a tela recarrega; 3) carrega o .lrf escolhido e abre a visualização. }

procedure TfrmMapaProducao.VisualizarModeloTalao(const AModelo: Integer);
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (not FTaloes.Active) or FTaloes.IsEmpty then
  begin
    MessageDlg('Este mapa ainda não tem talões. Use "Gerar Talões" primeiro.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  try
    if FService.DefinirModeloAtivo(CFG_TALAO_MODELO, AModelo) then
      CarregarMapas;   { o COMMIT da CONFIGURACAO invalida os cursores SQLDB }
  except
    on E: Exception do
    begin
      { persistência falhou: avisa o usuário, mas segue para a visualização }
      MessageDlg('Não foi possível gravar o modelo escolhido:' + sLineBreak +
        E.Message, mtWarning, [mbOK], 0);
      try
        CarregarMapas;
      except
      end;
    end;
  end;

  try
    PrepararRelatorioTalaoModelo(AModelo);
    FFrReport.ShowReport;   { pré-visualização; não altera status dos talões }
  except
    on E: Exception do
      MessageDlg('Não foi possível exibir o relatório de talões:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.VisualizarModeloMapa(const AModelo: Integer);
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;

  try
    if FService.DefinirModeloAtivo(CFG_MAPA_MODELO, AModelo) then
      CarregarMapas;   { o COMMIT da CONFIGURACAO invalida os cursores SQLDB }
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível gravar o modelo escolhido:' + sLineBreak +
        E.Message, mtWarning, [mbOK], 0);
      try
        CarregarMapas;
      except
      end;
    end;
  end;

  try
    PrepararRelatorioMapaModelo(AModelo);
    FFrReport.ShowReport;   { pré-visualização; não altera nada no banco }
  except
    on E: Exception do
      MessageDlg('Não foi possível exibir o relatório do mapa:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.mnuRelTalaoModelo1Click(Sender: TObject);
begin
  VisualizarModeloTalao(1);
end;

procedure TfrmMapaProducao.mnuRelTalaoModelo2Click(Sender: TObject);
begin
  VisualizarModeloTalao(2);
end;

procedure TfrmMapaProducao.mnuRelMapaModelo1Click(Sender: TObject);
begin
  VisualizarModeloMapa(1);
end;

procedure TfrmMapaProducao.mnuRelMapaModelo2Click(Sender: TObject);
begin
  VisualizarModeloMapa(2);
end;

{ Marca com o "radio" qual modelo está ativo em cada relatório. Chamado
  antes de abrir o menu; se a leitura da CONFIGURACAO falhar, o menu abre
  mesmo assim marcando os Modelos I (padrão). }
procedure TfrmMapaProducao.MarcarModelosNoMenu;
var
  LTalao, LMapa: Integer;
begin
  try
    LTalao := FService.ModeloAtivo(CFG_TALAO_MODELO);
    LMapa := FService.ModeloAtivo(CFG_MAPA_MODELO);
  except
    LTalao := 1;
    LMapa := 1;
  end;

  mnuRelTalaoModeloI.Checked := LTalao = 1;
  mnuRelTalaoModeloII.Checked := LTalao = 2;
  mnuRelMapaModeloI.Checked := LMapa = 1;
  mnuRelMapaModeloII.Checked := LMapa = 2;
end;

{ --- relatórios da Fase 6 (PDF e relatório do mapa) ---------------
  Exportação PDF via TlrPdfExportFilter (pacote lr_pdfexport / unit
  lr_e_fclpdf, que registra o filtro na initialization). O fluxo é
  PrepareReport (monta as páginas) + ExportTo (grava o arquivo);
  a impressora padrão nunca é tocada.                             }

function TfrmMapaProducao.CaminhoRelatorioMapa: string;
begin
  { relatório do mapa: fixo em relatorios\, ao lado do ERP2026.exe
    (o build copia de Desktop\relatorios); usa o modelo ativo }
  Result := FService.CaminhoRelatorioMapaModelo(
    FService.ModeloAtivo(CFG_MAPA_MODELO));
end;

procedure TfrmMapaProducao.PrepararRelatorioMapaModelo(const AModelo: Integer);
var
  LCaminho: string;
begin
  { mesmo dataset do Modelo I (FFrDBMapa): só o .lrf carregado muda }
  LCaminho := FService.CaminhoRelatorioMapaModelo(AModelo);
  if not FileExists(LCaminho) then
    raise Exception.Create(
      'Arquivo do relatório do mapa (Modelo ' + IntToStr(AModelo) +
      ') não encontrado:' + sLineBreak +
      LCaminho + sLineBreak + sLineBreak +
      'Ele fica em "relatorios" ao lado do ERP2026.exe.');

  if FRelMapa.Active then
    FRelMapa.Close;
  { mesma leitura da grade de itens + cabeçalho do mapa; subquery com
    SUM embrulhada em CAST (padrão do projeto: sem CAST o SQLDB lê 0) }
  FRelMapa.SQL.Text :=
    'SELECT M.NUMERO AS MAPA_NUMERO, PV.NUMERO AS PEDIDO_NUMERO, ' +
    '  COALESCE(C.NOME, ''(sem cliente)'') AS CLIENTE, ' +
    '  CASE M.STATUS WHEN ''ABERTO'' THEN ''Aberto'' ' +
    '       WHEN ''EM_PRODUCAO'' THEN ''Em produção'' ' +
    '       WHEN ''CONCLUIDO'' THEN ''Concluído'' ' +
    '       WHEN ''CANCELADO'' THEN ''Cancelado'' ELSE M.STATUS END AS MAPA_STATUS_DESC, ' +
    '  SUBSTRING(CAST(CAST(M.DATA_CRIACAO AS DATE) AS VARCHAR(10)) FROM 9 FOR 2) || ''/'' || ' +
    '  SUBSTRING(CAST(CAST(M.DATA_CRIACAO AS DATE) AS VARCHAR(10)) FROM 6 FOR 2) || ''/'' || ' +
    '  SUBSTRING(CAST(CAST(M.DATA_CRIACAO AS DATE) AS VARCHAR(10)) FROM 1 FOR 4) AS DATA_CRIACAO_STR, ' +
    '  SUBSTRING(CAST(CAST(M.DATA_PREVISTA AS DATE) AS VARCHAR(10)) FROM 9 FOR 2) || ''/'' || ' +
    '  SUBSTRING(CAST(CAST(M.DATA_PREVISTA AS DATE) AS VARCHAR(10)) FROM 6 FOR 2) || ''/'' || ' +
    '  SUBSTRING(CAST(CAST(M.DATA_PREVISTA AS DATE) AS VARCHAR(10)) FROM 1 FOR 4) AS DATA_PREVISTA_STR, ' +
    '  SUBSTRING(CAST(CAST(M.DATA_FIM AS DATE) AS VARCHAR(10)) FROM 9 FOR 2) || ''/'' || ' +
    '  SUBSTRING(CAST(CAST(M.DATA_FIM AS DATE) AS VARCHAR(10)) FROM 6 FOR 2) || ''/'' || ' +
    '  SUBSTRING(CAST(CAST(M.DATA_FIM AS DATE) AS VARCHAR(10)) FROM 1 FOR 4) AS DATA_FIM_STR, ' +
    '  PR.CODIGO, PR.DESCRICAO AS PRODUTO, ' +
    '  CAST(MI.QUANTIDADE AS NUMERIC(18,4)) AS PREVISTA, ' +
    '  CAST(COALESCE((SELECT SUM(T.QUANTIDADE) FROM TALAO T ' +
    '     WHERE T.MAPA_PRODUCAO_ITEM_ID = MI.ID AND T.STATUS = ''CONCLUIDO''), 0) ' +
    '     AS NUMERIC(18,4)) AS PRODUZIDO, ' +
    '  (SELECT COUNT(*) FROM TALAO T WHERE T.MAPA_PRODUCAO_ITEM_ID = MI.ID ' +
    '     AND T.STATUS <> ''CANCELADO'') AS TALOES, ' +
    '  (SELECT COUNT(*) FROM TALAO T WHERE T.MAPA_PRODUCAO_ITEM_ID = MI.ID ' +
    '     AND T.STATUS = ''CONCLUIDO'') AS CONCLUIDOS, ' +
    '  CASE MI.STATUS WHEN ''PENDENTE'' THEN ''Pendente'' ' +
    '       WHEN ''EM_PRODUCAO'' THEN ''Em produção'' ' +
    '       WHEN ''CONCLUIDO'' THEN ''Concluído'' ' +
    '       WHEN ''CANCELADO'' THEN ''Cancelado'' ELSE MI.STATUS END AS STATUS_DESC ' +
    'FROM MAPA_PRODUCAO M ' +
    '  JOIN PEDIDO_VENDA PV ON PV.ID = M.PEDIDO_VENDA_ID ' +
    '  LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    '  JOIN MAPA_PRODUCAO_ITEM MI ON MI.MAPA_PRODUCAO_ID = M.ID ' +
    '  LEFT JOIN PRODUTO PR ON PR.ID = MI.PRODUTO_ID ' +
    'WHERE M.ID = :ID ORDER BY MI.ID';
  FRelMapa.ParamByName('ID').AsLargeInt := FMapaId;
  FRelMapa.Open;
  if FRelMapa.IsEmpty then
    raise Exception.Create('Este mapa não tem itens: não há o que relatar.');

  FFrReport.LoadFromFile(LCaminho);   { .lrf = XML do LazReport }
end;

procedure TfrmMapaProducao.PrepararRelatorioMapa;
begin
  { visualizar/exportar do mapa sem escolher usam o modelo ativo }
  PrepararRelatorioMapaModelo(FService.ModeloAtivo(CFG_MAPA_MODELO));
end;

procedure TfrmMapaProducao.ExportarPdf(const ASugerido: string);
var
  LDlg: TSaveDialog;
  LArquivo: string;
begin
  LDlg := TSaveDialog.Create(Self);
  try
    LDlg.Title := 'Exportar relatório em PDF';
    LDlg.Filter := 'Documento PDF (*.pdf)|*.pdf';
    LDlg.DefaultExt := 'pdf';
    LDlg.Options := LDlg.Options + [ofOverwritePrompt, ofPathMustExist];
    LDlg.InitialDir := ExtractFilePath(CaminhoRelatorioTalao);
    LDlg.FileName := ASugerido;
    if not LDlg.Execute then
      Exit;
    LArquivo := LDlg.FileName;
  finally
    LDlg.Free;
  end;

  if not FFrReport.PrepareReport then
    raise Exception.Create('Não foi possível montar o relatório para exportar.');
  if not FFrReport.ExportTo(TlrPdfExportFilter, LArquivo) then
    raise Exception.Create('A exportação para PDF não foi concluída.');

  MessageDlg('PDF gerado com sucesso:' + sLineBreak + LArquivo,
    mtInformation, [mbOK], 0);
end;

procedure TfrmMapaProducao.mnuRelTalaoPdfClick(Sender: TObject);
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (not FTaloes.Active) or FTaloes.IsEmpty then
  begin
    MessageDlg('Este mapa ainda não tem talões. Use "Gerar Talões" primeiro.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if not VerificarPermissaoAcao(PERM_IMPRIMIR,
    'Seu usuário não tem permissão para exportar talões em PDF.') then
    Exit;

  try
    PrepararRelatorioTalao;
    ExportarPdf(Format('taloes_mapa_%d.pdf', [NumeroDoMapa(FMapaId)]));
  except
    on E: Exception do
      MessageDlg('Não foi possível exportar os talões em PDF:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.mnuRelMapaPreviewClick(Sender: TObject);
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;

  try
    PrepararRelatorioMapa;
    FFrReport.ShowReport;   { pré-visualização; não altera nada no banco }
  except
    on E: Exception do
      MessageDlg('Não foi possível exibir o relatório do mapa:' + sLineBreak +
        E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.mnuRelMapaPdfClick(Sender: TObject);
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not VerificarPermissaoAcao(PERM_IMPRIMIR,
    'Seu usuário não tem permissão para exportar o relatório do mapa em PDF.') then
    Exit;

  try
    PrepararRelatorioMapa;
    ExportarPdf(Format('mapa_%d.pdf', [NumeroDoMapa(FMapaId)]));
  except
    on E: Exception do
      MessageDlg('Não foi possível exportar o relatório do mapa em PDF:' +
        sLineBreak + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMapaProducao.btnImprimirTalaoClick(Sender: TObject);
var
  LImpressos: Integer;
  LStatus: string;
begin
  if FMapaId <= 0 then
  begin
    MessageDlg('Selecione um mapa de produção na lista.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (not FTaloes.Active) or FTaloes.IsEmpty then
  begin
    MessageDlg('Este mapa ainda não tem talões. Use "Gerar Talões" primeiro.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  LStatus := Trim(FMapas.FieldByName('STATUS').AsString);
  if (LStatus <> 'ABERTO') and (LStatus <> 'EM_PRODUCAO') then
  begin
    MessageDlg(Format(
      'O mapa nº %d está como "%s": talões só podem ser impressos em mapa aberto ou em produção.',
      [NumeroDoMapa(FMapaId), DescricaoDoStatus(LStatus)]),
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if not VerificarPermissaoAcao(PERM_IMPRIMIR,
    'Seu usuário não tem permissão para imprimir talões.') then
    Exit;

  // 1) imprime primeiro (o papel sai; o registro vem em seguida)
  try
    PrepararRelatorioTalao;
    { ErrorFlag/ErrorStr são privados do LR_Class: usamos o retorno + exceções }
    if not FFrReport.PrepareReport then
    begin
      MessageDlg('Não foi possível montar o relatório de talões.' + sLineBreak +
        'Confira se a impressora padrão está disponível.',
        mtError, [mbOK], 0);
      Exit;
    end;
    FFrReport.PrintPreparedReport('', 1);   { '' = todas as páginas }
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível imprimir os talões:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
      Exit;
    end;
  end;

  // 2) registra a impressão (transação + auditoria no service)
  try
    LImpressos := FService.ImprimirTaloesDoMapa(FMapaId);
  except
    on E: Exception do
    begin
      MessageDlg(
        'Os talões foram enviados à impressora, mas o sistema não pôde registrar ' +
        'a impressão:' + sLineBreak + E.Message, mtWarning, [mbOK], 0);
      CarregarMapas;   { recarrega lista + detalhe (cursores pós-rollback) }
      Exit;
    end;
  end;

  MessageDlg(Format(
    '%d talão(ões) enviado(s) para a impressora e registrados como impressos.',
    [LImpressos]), mtInformation, [mbOK], 0);
  CarregarMapas;   { lista, itens, progresso e talões (impressões) }
end;

procedure TfrmMapaProducao.btnCancelarTalaoClick(Sender: TObject);
var
  LTalaoId: Int64;
  LNumero: Integer;
  LMotivo: string;
begin
  LTalaoId := TalaoSelecionado;
  if LTalaoId <= 0 then
  begin
    MessageDlg('Selecione um talão na lista de talões para cancelar.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if not VerificarPermissaoAcao(PERM_EXCLUIR,
    'Seu usuário não tem permissão para cancelar talões.') then
    Exit;

  LNumero := FTaloes.FieldByName('NUMERO').AsInteger;
  LMotivo := '';
  if not InputQuery(Format('Cancelar talão nº %d', [LNumero]),
    'Motivo do cancelamento:', LMotivo) then
    Exit;
  if Trim(LMotivo) = '' then
  begin
    MessageDlg('Informe o motivo do cancelamento do talão.', mtWarning, [mbOK], 0);
    Exit;
  end;

  try
    FService.CancelarTalao(LTalaoId, LMotivo);
  except
    on E: Exception do
    begin
      MessageDlg('Não foi possível cancelar o talão:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
      { rollback no service: recarrega para as grades não ficarem vazias }
      try
        CarregarMapas;
      except
      end;
      Exit;
    end;
  end;

  MessageDlg(Format('Talão nº %d cancelado com sucesso.', [LNumero]),
    mtInformation, [mbOK], 0);
  CarregarMapas;   { lista, itens, progresso e talões }
end;

end.
