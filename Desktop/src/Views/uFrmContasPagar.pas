unit uFrmContasPagar;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 5 - Contas a Pagar
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, DateUtils,
  uConexao, uSessao;

type
  TfrmContasPagar = class(TForm)
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
    btnNovo: TBitBtn;
    btnBaixar: TBitBtn;
    btnFechar: TBitBtn;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    pnlResumo: TPanel;
    lblTotalAberto: TLabel;
    lblTotalPago: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnNovoClick(Sender: TObject);
    procedure btnBaixarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    procedure CarregarContas;
  end;

var
  frmContasPagar: TfrmContasPagar;

implementation

{$R *.lfm}

procedure TfrmContasPagar.FormCreate(Sender: TObject);
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

procedure TfrmContasPagar.FormShow(Sender: TObject);
begin
  try
    edtDataInicio.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -1));
    edtDataFim.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, 1));

    // Inicializar ComboBox de filtro
    cmbStatusFiltro.Items.Clear;
    cmbStatusFiltro.Items.Add('Todos');
    cmbStatusFiltro.Items.Add('Aberto');
    cmbStatusFiltro.Items.Add('Pago');
    cmbStatusFiltro.Items.Add('Cancelado');
    cmbStatusFiltro.ItemIndex := 0;

    CarregarContas;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmContasPagar.CarregarContas;
var
  LSQL: string;
  LAberto: Double;
  LPago: Double;
  LStatus: string;
begin
  LSQL :=
    'SELECT CP.ID, F.NOME_FANTASIA AS FORNECEDOR, CP.DESCRICAO, CP.VALOR, ' +
    'CP.DATA_VENCIMENTO, CP.DATA_PAGAMENTO, CP.VALOR_PAGO, ' +
    'CASE CP.STATUS WHEN ''A'' THEN ''Aberta'' WHEN ''P'' THEN ''Paga'' ' +
    'WHEN ''C'' THEN ''Cancelada'' END AS STATUS_DESC ' +
    'FROM CONTA_PAGAR CP ' +
    'LEFT JOIN FORNECEDOR F ON F.ID = CP.FORNECEDOR_ID ' +
    'WHERE CP.DATA_VENCIMENTO BETWEEN :DI AND :DF';

  if cmbStatusFiltro.ItemIndex > 0 then
  begin
    case cmbStatusFiltro.ItemIndex of
      1: LStatus := 'A';
      2: LStatus := 'P';
      3: LStatus := 'C';
    end;
    LSQL := LSQL + ' AND CP.STATUS = :STATUS';
  end;

  LSQL := LSQL + ' ORDER BY CP.DATA_VENCIMENTO';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  FQuery.ParamByName('DI').AsDate := StrToDateDef(edtDataInicio.Text, Now);
  FQuery.ParamByName('DF').AsDate := StrToDateDef(edtDataFim.Text, Now);
  if cmbStatusFiltro.ItemIndex > 0 then
    FQuery.ParamByName('STATUS').AsString := LStatus;
  FQuery.Open;
  DataSource1.DataSet := FQuery;

  LAberto := 0;
  LPago := 0;
  FQuery.First;
  while not FQuery.EOF do
  begin
    if FQuery.FieldByName('STATUS_DESC').AsString = 'Aberta' then
      LAberto := LAberto + FQuery.FieldByName('VALOR').AsFloat
    else if FQuery.FieldByName('STATUS_DESC').AsString = 'Paga' then
      LPago := LPago + FQuery.FieldByName('VALOR_PAGO').AsFloat;
    FQuery.Next;
  end;
  FQuery.First;
  lblTotalAberto.Caption := 'Em Aberto: R$ ' + FormatFloat('#,##0.00', LAberto);
  lblTotalPago.Caption := 'Pago: R$ ' + FormatFloat('#,##0.00', LPago);
end;

procedure TfrmContasPagar.btnNovoClick(Sender: TObject);
var
  LDesc, LValor, LVenc: string;
  LQuery: TSQLQuery;
begin
  if not InputQuery('Nova Conta a Pagar', 'Descrição:', LDesc) then Exit;
  if not InputQuery('Nova Conta a Pagar', 'Valor:', LValor) then Exit;
  if not InputQuery('Nova Conta a Pagar', 'Vencimento (DD/MM/AAAA):', LVenc) then Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text :=
      'INSERT INTO CONTA_PAGAR (EMPRESA_ID, DESCRICAO, VALOR, DATA_VENCIMENTO, STATUS) ' +
      'VALUES (:EMP, :DESC, :VLR, :VENC, ''A'')';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('DESC').AsString := LDesc;
    LQuery.ParamByName('VLR').AsFloat := StrToFloatDef(LValor, 0);
    LQuery.ParamByName('VENC').AsDate := StrToDateDef(LVenc, Now + 30);
    LQuery.ExecSQL;
    FConexao.Confirmar;
    CarregarContas;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmContasPagar.btnBaixarClick(Sender: TObject);
var
  LQuery: TSQLQuery;
begin
  if FQuery.IsEmpty then Exit;
  if FQuery.FieldByName('STATUS_DESC').AsString <> 'Aberta' then
  begin
    MessageDlg('Apenas contas em aberto podem ser baixadas.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Confirma baixa desta conta?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text :=
      'UPDATE CONTA_PAGAR SET STATUS = ''P'', DATA_PAGAMENTO = CURRENT_DATE, ' +
      'VALOR_PAGO = VALOR WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FQuery.FieldByName('ID').AsLargeInt;
    LQuery.ExecSQL;
    FConexao.Confirmar;
    CarregarContas;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmContasPagar.btnFiltrarClick(Sender: TObject);
begin
  CarregarContas;
end;

procedure TfrmContasPagar.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
