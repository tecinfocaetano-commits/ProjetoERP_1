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
    lblPesquisa: TLabel;
    edtPesquisa: TEdit;
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
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: char);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    procedure CarregarContas;
    function  GarantirFinanceiro: Int64;
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
    'SELECT CP.ID, COALESCE(F.NOME_FANTASIA, F.NOME) AS FORNECEDOR, CP.DESCRICAO, CP.VALOR, ' +
    'CP.DATA_VENCIMENTO, CP.DATA_PAGAMENTO, CP.VALOR_PAGO, ' +
    'CASE CP.STATUS WHEN ''A'' THEN ''Aberta'' WHEN ''P'' THEN ''Paga'' ' +
    'WHEN ''C'' THEN ''Cancelada'' END AS STATUS_DESC ' +
    'FROM CONTA_PAGAR CP ' +
    'LEFT JOIN PESSOA F ON F.ID = CP.FORNECEDOR_ID AND F.TIPO = ''F'' ' +
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

  if Trim(edtPesquisa.Text) <> '' then
    LSQL := LSQL + ' AND (UPPER(COALESCE(F.NOME, '''')) CONTAINING UPPER(:PESQ)' +
                   ' OR UPPER(COALESCE(F.NOME_FANTASIA, '''')) CONTAINING UPPER(:PESQ2)' +
                   ' OR UPPER(COALESCE(CP.DESCRICAO, '''')) CONTAINING UPPER(:PESQ3))';

  LSQL := LSQL + ' ORDER BY CP.DATA_VENCIMENTO';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  FQuery.ParamByName('DI').AsDate := StrToDateDef(edtDataInicio.Text, Now);
  FQuery.ParamByName('DF').AsDate := StrToDateDef(edtDataFim.Text, Now);
  if cmbStatusFiltro.ItemIndex > 0 then
    FQuery.ParamByName('STATUS').AsString := LStatus;
  if Trim(edtPesquisa.Text) <> '' then
  begin
    FQuery.ParamByName('PESQ').AsString := Trim(edtPesquisa.Text);
    FQuery.ParamByName('PESQ2').AsString := Trim(edtPesquisa.Text);
    FQuery.ParamByName('PESQ3').AsString := Trim(edtPesquisa.Text);
  end;
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

// Localiza (ou cria) o plano financeiro "Contas a pagar" da empresa.
// CONTA_PAGAR.FINANCEIRO_ID/FORNECEDOR_ID usam o domínio DM_ID (NOT NULL),
// então precisam ser informados mesmo quando não existe vínculo.
function TfrmContasPagar.GarantirFinanceiro: Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM FINANCEIRO ' +
      'WHERE EMPRESA_ID = :EMP AND TIPO = ''P'' ORDER BY ID';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt
    else
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO FINANCEIRO (EMPRESA_ID, TIPO, DESCRICAO, STATUS) ' +
        'VALUES (:EMP, ''P'', ''Contas a pagar de compras'', ''A'') RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
    end;
  finally
    LQuery.Free;
  end;
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
    // FINANCEIRO_ID e FORNECEDOR_ID usam o domínio DM_ID (NOT NULL): precisam
    // ser informados (0 = sem vínculo com fornecedor).
    LQuery.SQL.Text :=
      'INSERT INTO CONTA_PAGAR (EMPRESA_ID, FINANCEIRO_ID, FORNECEDOR_ID, DESCRICAO, ' +
      '  VALOR, DATA_VENCIMENTO, STATUS, PARCELA) ' +
      'VALUES (:EMP, :FIN, 0, :DESC, :VLR, :VENC, ''A'', 1)';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('FIN').AsLargeInt := GarantirFinanceiro;
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

procedure TfrmContasPagar.edtPesquisaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarContas;
  end;
end;

procedure TfrmContasPagar.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
