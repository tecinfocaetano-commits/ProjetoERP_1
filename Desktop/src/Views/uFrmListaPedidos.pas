unit uFrmListaPedidos;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 4 - Lista de Pedidos de Venda
  Descrição: Consulta e gerenciamento de pedidos
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, DateUtils,
  LR_Class, LR_DBSet,
  uConexao, uSessao, uFrmPedidoVenda, uPedidoStatus, uPermissao, uFrmMapaProducao;

type
  { TfrmListaPedidos }
  TfrmListaPedidos = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlFiltro: TPanel;
    lblDataInicio: TLabel;
    edtDataInicio: TEdit;
    lblDataFim: TLabel;
    edtDataFim: TEdit;
    lblStatusFiltro: TLabel;
    cmbStatusFiltro: TComboBox;
    btnFiltrar: TBitBtn;
    pnlBotoes: TPanel;
    btnNovoPedido: TBitBtn;
    btnVisualizar: TBitBtn;
    btnMapaProducao: TBitBtn;
    btnImprimir: TBitBtn;
    btnFechar: TBitBtn;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnNovoPedidoClick(Sender: TObject);
    procedure btnVisualizarClick(Sender: TObject);
    procedure btnMapaProducaoClick(Sender: TObject);
    procedure btnImprimirClick(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    FRelPedidos: TSQLQuery;      { query do relatório (mesmo filtro da grade) }
    FFrDBPedidos: TfrDBDataSet;  { DatasetStr 'frDBPedidos' do pedidos_venda.lrf }
    FFrReport: TfrReport;
    function  SqlPedidos(AComDataStr: Boolean): string;
    procedure VincularParamsPedidos(AQuery: TSQLQuery);
    procedure PrepararRelatorio;
    procedure CarregarPedidos;
  end;

var
  frmListaPedidos: TfrmListaPedidos;

implementation

{$R *.lfm}

procedure TfrmListaPedidos.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if FConexao = nil then
      raise Exception.Create('FConexao não foi inicializado');

    // Iniciar conexão com o banco
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    if FQuery = nil then
      raise Exception.Create('FQuery não foi criado');

    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    { Relatório LazReport: a query do relatório repete o filtro da
      grade e adiciona DATA_EMISSAO_STR (dd/mm/yyyy) para o .lrf }
    FRelPedidos := TSQLQuery.Create(Self);
    FRelPedidos.Name := 'qryPedidosRel';
    FRelPedidos.DataBase := FConexao.Connection;
    FRelPedidos.Transaction := FConexao.Transaction;
    FFrDBPedidos := TfrDBDataSet.Create(Self);
    FFrDBPedidos.Name := 'frDBPedidos';
    FFrDBPedidos.DataSet := FRelPedidos;
    FFrReport := TfrReport.Create(Self);
    FFrReport.ShowProgress := False;

    // Criar DataSource1 se não existir
    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmListaPedidos.FormShow(Sender: TObject);
var
  LStatusEnum: TPedidoStatus;
begin
  try
    edtDataInicio.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -1));
    edtDataFim.Text := FormatDateTime('dd/mm/yyyy', Now);

    // Inicializar ComboBox de filtro (rótulos vêm de uPedidoStatus)
    cmbStatusFiltro.Items.Clear;
    cmbStatusFiltro.Items.Add('Todos');
    for LStatusEnum := Low(TPedidoStatus) to High(TPedidoStatus) do
      cmbStatusFiltro.Items.Add(DescricaoDoStatusEnum(LStatusEnum));
    cmbStatusFiltro.ItemIndex := 0;

    CarregarPedidos;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar componentes: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

function TfrmListaPedidos.SqlPedidos(AComDataStr: Boolean): string;
var
  LStatus: string;
begin
  Result :=
    'SELECT PV.ID, PV.NUMERO, PV.DATA_EMISSAO, C.NOME AS CLIENTE, ' +
    'PV.TOTAL, ' +
    SqlCaseStatusPedido('PV.STATUS') + ' AS STATUS_DESC ';

  if AComDataStr then
    Result := Result +
      ', SUBSTRING(CAST(CAST(PV.DATA_EMISSAO AS DATE) AS VARCHAR(10)) FROM 9 FOR 2) || ''/'' || ' +
      'SUBSTRING(CAST(CAST(PV.DATA_EMISSAO AS DATE) AS VARCHAR(10)) FROM 6 FOR 2) || ''/'' || ' +
      'SUBSTRING(CAST(CAST(PV.DATA_EMISSAO AS DATE) AS VARCHAR(10)) FROM 1 FOR 4) AS DATA_EMISSAO_STR ';

  Result := Result +
    'FROM PEDIDO_VENDA PV ' +
    'JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
    'WHERE PV.DATA_EMISSAO BETWEEN :DI AND :DF AND PV.EMPRESA_ID = :EMP';

  if cmbStatusFiltro.ItemIndex > 0 then
  begin
    // índice 1..6 na mesma ordem do tipo TPedidoStatus (uPedidoStatus)
    LStatus := CodigoDoStatus(
      TPedidoStatus(cmbStatusFiltro.ItemIndex - 1));
    Result := Result + ' AND PV.STATUS = :STATUS';
  end;

  Result := Result + ' ORDER BY PV.NUMERO DESC';
end;

procedure TfrmListaPedidos.VincularParamsPedidos(AQuery: TSQLQuery);
var
  LStatus: string;
begin
  AQuery.ParamByName('DI').AsDate := StrToDateDef(edtDataInicio.Text, Now);
  AQuery.ParamByName('DF').AsDate := StrToDateDef(edtDataFim.Text, Now) + 1;
  AQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  if cmbStatusFiltro.ItemIndex > 0 then
  begin
    LStatus := CodigoDoStatus(
      TPedidoStatus(cmbStatusFiltro.ItemIndex - 1));
    AQuery.ParamByName('STATUS').AsString := LStatus;
  end;
end;

procedure TfrmListaPedidos.CarregarPedidos;
begin
  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := SqlPedidos(False);
  VincularParamsPedidos(FQuery);
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmListaPedidos.btnNovoPedidoClick(Sender: TObject);
var
  LForm: TfrmPedidoVenda;
begin
  LForm := TfrmPedidoVenda.Create(Application);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
  CarregarPedidos;
end;

procedure TfrmListaPedidos.btnVisualizarClick(Sender: TObject);
begin
  if FQuery.IsEmpty then Exit;
  // TODO: Abrir pedido para visualização/edição
  MessageDlg('Pedido Nº ' + FQuery.FieldByName('NUMERO').AsString + #13#10 +
    'Cliente: ' + FQuery.FieldByName('CLIENTE').AsString + #13#10 +
    'Total: R$ ' + FormatFloat('#,##0.00', FQuery.FieldByName('TOTAL').AsFloat) + #13#10 +
    'Status: ' + FQuery.FieldByName('STATUS_DESC').AsString,
    mtInformation, [mbOK], 0);
end;

procedure TfrmListaPedidos.btnMapaProducaoClick(Sender: TObject);
begin
  if not TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, PERM_VISUALIZAR) then
  begin
    MessageDlg('Seu usuário não tem permissão para acessar o Mapa de Produção.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  with TfrmMapaProducao.Create(Application) do
    try
      ShowModal;
    finally
      Free;
    end;
  CarregarPedidos;
end;

procedure TfrmListaPedidos.PrepararRelatorio;
var
  LCaminho: string;
begin
  { mesmo filtro da grade, com a coluna de data formatada para o .lrf }
  if FRelPedidos.Active then
    FRelPedidos.Close;
  FRelPedidos.SQL.Text := SqlPedidos(True);
  VincularParamsPedidos(FRelPedidos);
  FRelPedidos.Open;
  try
    { padrão: o exe roda de Desktop\bin\ e relatorios\<arquivo> }
    LCaminho := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
      'relatorios' + PathDelim + 'pedidos_venda.lrf';
    if not FileExists(LCaminho) then
      raise Exception.Create(
        'Relatório não encontrado: ' + LCaminho);
    FFrReport.LoadFromFile(LCaminho);   { .lrf = XML do LazReport }
    FFrReport.ShowReport;               { pré-visualização }
  finally
    FRelPedidos.Close;
  end;
end;

procedure TfrmListaPedidos.btnImprimirClick(Sender: TObject);
begin
  try
    PrepararRelatorio;
  except
    on E: Exception do
      MessageDlg('Erro ao gerar relatório: ' + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TfrmListaPedidos.btnFiltrarClick(Sender: TObject);
begin
  CarregarPedidos;
end;

procedure TfrmListaPedidos.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
