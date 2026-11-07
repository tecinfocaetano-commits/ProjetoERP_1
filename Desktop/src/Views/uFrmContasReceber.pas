unit uFrmContasReceber;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 5 - Contas a Receber
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, DateUtils,
  uConexao, uSessao, uContasService;

type
  TfrmContasReceber = class(TForm)
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
  end;

var
  frmContasReceber: TfrmContasReceber;

implementation

{$R *.lfm}

procedure TfrmContasReceber.FormCreate(Sender: TObject);
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

procedure TfrmContasReceber.FormShow(Sender: TObject);
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
      MessageDlg('Erro ao inicializar componentes: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmContasReceber.CarregarContas;
var
  LStatus: string;
  LAberto: Double;
  LPago: Double;
  LContas: TContasService;
begin
  case cmbStatusFiltro.ItemIndex of
    1: LStatus := 'A';
    2: LStatus := 'P';
    3: LStatus := 'C';
  else
    LStatus := '';
  end;

  LContas := TContasService.Create;
  try
    LContas.CarregarContasReceber(FQuery,
      StrToDateDef(edtDataInicio.Text, Now),
      StrToDateDef(edtDataFim.Text, Now),
      LStatus, Trim(edtPesquisa.Text));
  finally
    LContas.Free;
  end;

  DataSource1.DataSet := FQuery;

  // Resumo
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

procedure TfrmContasReceber.btnNovoClick(Sender: TObject);
var
  LDesc, LValor, LVenc: string;
  LContas: TContasService;
begin
  if not InputQuery('Nova Conta a Receber', 'Descrição:', LDesc) then Exit;
  if not InputQuery('Nova Conta a Receber', 'Valor:', LValor) then Exit;
  if not InputQuery('Nova Conta a Receber', 'Vencimento (DD/MM/AAAA):', LVenc) then Exit;

  LContas := TContasService.Create;
  try
    try
      LContas.CriarContaReceber(LDesc, StrToFloatDef(LValor, 0),
        StrToDateDef(LVenc, Now + 30));
      CarregarContas;
    except
      on E: Exception do
        MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    LContas.Free;
  end;
end;

procedure TfrmContasReceber.btnBaixarClick(Sender: TObject);
var
  LContas: TContasService;
begin
  if FQuery.IsEmpty then Exit;
  if FQuery.FieldByName('STATUS_DESC').AsString <> 'Aberta' then
  begin
    MessageDlg('Apenas contas em aberto podem ser baixadas.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('Confirma baixa desta conta?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  LContas := TContasService.Create;
  try
    try
      LContas.BaixarContaReceber(FQuery.FieldByName('ID').AsLargeInt);
      CarregarContas;
    except
      on E: Exception do
        MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    LContas.Free;
  end;
end;

procedure TfrmContasReceber.btnFiltrarClick(Sender: TObject);
begin
  CarregarContas;
end;

procedure TfrmContasReceber.edtPesquisaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarContas;
  end;
end;

procedure TfrmContasReceber.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
