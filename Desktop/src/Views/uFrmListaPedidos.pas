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
  uConexao, uFrmPedidoVenda;

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
    btnFechar: TBitBtn;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnNovoPedidoClick(Sender: TObject);
    procedure btnVisualizarClick(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
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

    // Criar DataSource1 se não existir
    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmListaPedidos.FormShow(Sender: TObject);
begin
  try
    edtDataInicio.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -1));
    edtDataFim.Text := FormatDateTime('dd/mm/yyyy', Now);

    // Inicializar ComboBox de filtro
    cmbStatusFiltro.Items.Clear;
    cmbStatusFiltro.Items.Add('Todos');
    cmbStatusFiltro.Items.Add('Pendente');
    cmbStatusFiltro.Items.Add('Aberto');
    cmbStatusFiltro.Items.Add('Cancelado');
    cmbStatusFiltro.ItemIndex := 0;

    CarregarPedidos;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar componentes: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmListaPedidos.CarregarPedidos;
var
  LSQL: string;
  LStatus: string;
begin
  LSQL :=
    'SELECT PV.ID, PV.NUMERO, PV.DATA_EMISSAO, C.NOME AS CLIENTE, ' +
    'PV.TOTAL, ' +
    'CASE PV.STATUS WHEN ''P'' THEN ''Pendente'' WHEN ''A'' THEN ''Aprovado'' ' +
    'WHEN ''F'' THEN ''Faturado'' WHEN ''C'' THEN ''Cancelado'' END AS STATUS_DESC ' +
    'FROM PEDIDO_VENDA PV ' +
    'JOIN CLIENTE C ON C.ID = PV.CLIENTE_ID ' +
    'WHERE PV.DATA_EMISSAO BETWEEN :DI AND :DF';

  if cmbStatusFiltro.ItemIndex > 0 then
  begin
    case cmbStatusFiltro.ItemIndex of
      1: LStatus := 'P';
      2: LStatus := 'A';
      3: LStatus := 'F';
      4: LStatus := 'C';
    end;
    LSQL := LSQL + ' AND PV.STATUS = :STATUS';
  end;

  LSQL := LSQL + ' ORDER BY PV.NUMERO DESC';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  FQuery.ParamByName('DI').AsDate := StrToDateDef(edtDataInicio.Text, Now);
  FQuery.ParamByName('DF').AsDate := StrToDateDef(edtDataFim.Text, Now) + 1;
  if cmbStatusFiltro.ItemIndex > 0 then
    FQuery.ParamByName('STATUS').AsString := LStatus;
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

procedure TfrmListaPedidos.btnFiltrarClick(Sender: TObject);
begin
  CarregarPedidos;
end;

procedure TfrmListaPedidos.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
