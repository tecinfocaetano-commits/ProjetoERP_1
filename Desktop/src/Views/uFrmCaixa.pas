unit uFrmCaixa;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Financeiro > Caixa
  Descrição: consulta dos caixas abertos/fechados e dos
  movimentos de cada um (entradas e saídas). Somente leitura:
  abrir caixa e lançar movimentos é papel do PDV.

  Tudo em TCaixaService; este form só carrega, mostra e navega.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, uConexao, uCaixaService;

type
  { TfrmCaixa }
  TfrmCaixa = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    lblPesquisa: TLabel;
    edtPesquisa: TEdit;
    btnPesquisar: TBitBtn;
    btnAtualizar: TBitBtn;
    btnFechar: TBitBtn;
    dbGridCaixas: TDBGrid;
    pnlResumo: TPanel;
    lblEntradas: TLabel;
    lblSaidas: TLabel;
    lblSaldo: TLabel;
    dbGridMovimentos: TDBGrid;
    DataSource1: TDataSource;
    DataSource2: TDataSource;
    procedure FormCreate(Sender: TObject);
    procedure btnAtualizarClick(Sender: TObject);
    procedure btnPesquisarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure dbGridCaixasCellClick(Column: TColumn);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: char);
  private
    FConexao: TConexao;
    FService: TCaixaService;
    FQueryCaixas: TSQLQuery;
    FQueryMovimentos: TSQLQuery;
    FQueryResumo: TSQLQuery;
    procedure ConfigurarGrades;
    procedure CarregarCaixas;
    procedure CarregarMovimentosDoSelecionado;
    procedure AtualizarResumo(ACaixaId: Int64);
    function  CaixaSelecionado: Int64;
    function  Dinheiro(AValor: Double): string;
  end;

var
  frmCaixa: TfrmCaixa;

implementation

{$R *.lfm}

{ TfrmCaixa }

procedure TfrmCaixa.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TCaixaService.Create;

    FQueryCaixas := TSQLQuery.Create(Self);
    FQueryCaixas.DataBase := FConexao.Connection;
    FQueryCaixas.Transaction := FConexao.Transaction;

    FQueryMovimentos := TSQLQuery.Create(Self);
    FQueryMovimentos.DataBase := FConexao.Connection;
    FQueryMovimentos.Transaction := FConexao.Transaction;

    FQueryResumo := TSQLQuery.Create(Self);
    FQueryResumo.DataBase := FConexao.Connection;
    FQueryResumo.Transaction := FConexao.Transaction;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);
    if DataSource2 = nil then
      DataSource2 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Caixas da Empresa';
    Caption := 'Caixa';
    ConfigurarGrades;

    Position := poScreenCenter;
    BorderStyle := bsSizeable;

    CarregarCaixas;
    CarregarMovimentosDoSelecionado;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmCaixa.ConfigurarGrades;
begin
  dbGridCaixas.ReadOnly := True;
  dbGridCaixas.Columns.Clear;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 45; end;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'Número'; FieldName := 'NUMERO'; Width := 80; end;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'Usuário'; FieldName := 'USUARIO'; Width := 140; end;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'Abertura'; FieldName := 'DATA_ABERTURA'; Width := 130; end;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'Valor abertura'; FieldName := 'VALOR_ABERTURA'; Width := 100; end;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'Status'; FieldName := 'STATUS'; Width := 55; end;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'Fechamento'; FieldName := 'DATA_FECHAMENTO'; Width := 130; end;
  with dbGridCaixas.Columns.Add do begin Title.Caption := 'Saldo'; FieldName := 'SALDO'; Width := 90; end;

  dbGridMovimentos.ReadOnly := True;
  dbGridMovimentos.Columns.Clear;
  with dbGridMovimentos.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 45; end;
  with dbGridMovimentos.Columns.Add do begin Title.Caption := 'Tipo'; FieldName := 'TIPO'; Width := 90; end;
  with dbGridMovimentos.Columns.Add do begin Title.Caption := 'Valor'; FieldName := 'VALOR'; Width := 90; end;
  with dbGridMovimentos.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 260; end;
  with dbGridMovimentos.Columns.Add do begin Title.Caption := 'Data'; FieldName := 'DATA_MOVIMENTO'; Width := 130; end;
  with dbGridMovimentos.Columns.Add do begin Title.Caption := 'Usuário'; FieldName := 'USUARIO'; Width := 140; end;
end;

function TfrmCaixa.Dinheiro(AValor: Double): string;
begin
  Result := FormatFloat('0.00', AValor);
end;

function TfrmCaixa.CaixaSelecionado: Int64;
begin
  Result := 0;
  if (DataSource1.DataSet <> nil) and (not DataSource1.DataSet.IsEmpty) then
    Result := DataSource1.DataSet.FieldByName('ID').AsLargeInt;
end;

procedure TfrmCaixa.CarregarCaixas;
begin
  FService.CarregarCaixas(FQueryCaixas, Trim(edtPesquisa.Text));
  DataSource1.DataSet := FQueryCaixas;
end;

procedure TfrmCaixa.AtualizarResumo(ACaixaId: Int64);
begin
  lblEntradas.Caption := 'Entradas: ' + Dinheiro(0);
  lblSaidas.Caption := 'Saídas: ' + Dinheiro(0);
  lblSaldo.Caption := 'Saldo: ' + Dinheiro(0);
  if ACaixaId <= 0 then
    Exit;

  FService.CarregarResumo(FQueryResumo, ACaixaId);
  if not FQueryResumo.IsEmpty then
  begin
    lblEntradas.Caption := 'Entradas: ' + Dinheiro(FQueryResumo.FieldByName('ENTRADAS').AsFloat);
    lblSaidas.Caption := 'Saídas: ' + Dinheiro(FQueryResumo.FieldByName('SAIDAS').AsFloat);
    lblSaldo.Caption := 'Saldo: ' + Dinheiro(FQueryResumo.FieldByName('SALDO').AsFloat);
  end;
end;

procedure TfrmCaixa.CarregarMovimentosDoSelecionado;
var
  LCaixa: Int64;
begin
  LCaixa := CaixaSelecionado;
  if LCaixa <= 0 then
  begin
    if FQueryMovimentos.Active then
      FQueryMovimentos.Close;
    DataSource2.DataSet := FQueryMovimentos;
    AtualizarResumo(0);
    Exit;
  end;

  FService.CarregarMovimentos(FQueryMovimentos, LCaixa, Trim(edtPesquisa.Text));
  DataSource2.DataSet := FQueryMovimentos;
  AtualizarResumo(LCaixa);
end;

procedure TfrmCaixa.dbGridCaixasCellClick(Column: TColumn);
begin
  try
    CarregarMovimentosDoSelecionado;
  except
    on E: Exception do
      MessageDlg('Erro ao carregar os movimentos: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmCaixa.btnAtualizarClick(Sender: TObject);
begin
  try
    CarregarCaixas;
    CarregarMovimentosDoSelecionado;
  except
    on E: Exception do
      MessageDlg('Erro ao atualizar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmCaixa.btnFecharClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmCaixa.btnPesquisarClick(Sender: TObject);
begin
  try
    CarregarCaixas;
    CarregarMovimentosDoSelecionado;
  except
    on E: Exception do
      MessageDlg('Erro ao pesquisar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmCaixa.edtPesquisaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnPesquisarClick(Sender);
  end;
end;

end.
