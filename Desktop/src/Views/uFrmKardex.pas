unit uFrmKardex;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 3 - Kardex do Produto
  Descrição: Histórico de movimentações de um produto
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, DateUtils,
  uConexao, uKardexService;

type
  { TfrmKardex }
  TfrmKardex = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlFiltro: TPanel;
    lblProduto: TLabel;
    edtProduto: TEdit;
    btnBuscar: TBitBtn;
    lblProdutoNome: TLabel;
    lblEstoqueAtual: TLabel;
    lblDataInicio: TLabel;
    edtDataInicio: TEdit;
    lblDataFim: TLabel;
    edtDataFim: TEdit;
    btnFiltrar: TBitBtn;
    lblPesquisa: TLabel;
    edtPesquisa: TEdit;
    btnPesquisarMov: TBitBtn;
    btnFechar: TBitBtn;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    pnlResumo: TPanel;
    lblTotalEntradas: TLabel;
    lblTotalSaidas: TLabel;
    lblSaldoFinal: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnBuscarClick(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnPesquisarMovClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: char);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    FService: TKardexService;
    FProdutoId: Int64;
    procedure CarregarKardex;
    procedure CarregarResumo;
  end;

var
  frmKardex: TfrmKardex;

implementation

{$R *.lfm}

procedure TfrmKardex.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TKardexService.Create;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;
    FProdutoId := 0;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    // Não inicializar datas aqui - fazer no FormShow para garantir que componentes existam
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmKardex.FormShow(Sender: TObject);
begin
  try
    // Inicializar datas após os componentes visuais serem criados
    if edtDataInicio <> nil then
      edtDataInicio.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -3));
    if edtDataFim <> nil then
      edtDataFim.Text := FormatDateTime('dd/mm/yyyy', Now);
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar datas: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmKardex.btnBuscarClick(Sender: TObject);
var
  LProdutoId: Int64;
  LDescricao: string;
  LEstoqueAtual: Double;
begin
  if Trim(edtProduto.Text) = '' then Exit;

  if FService.BuscarProduto(Trim(edtProduto.Text),
    LProdutoId, LDescricao, LEstoqueAtual) then
  begin
    FProdutoId := LProdutoId;
    lblProdutoNome.Caption := LDescricao;
    lblEstoqueAtual.Caption := 'Estoque Atual: ' +
      FormatFloat('#,##0.0000', LEstoqueAtual);
    CarregarKardex;
    CarregarResumo;
  end
  else
  begin
    MessageDlg('Produto não encontrado.', mtWarning, [mbOK], 0);
    FProdutoId := 0;
    lblProdutoNome.Caption := '';
    lblEstoqueAtual.Caption := '';
  end;
end;

procedure TfrmKardex.CarregarKardex;
var
  LDataInicio, LDataFim: TDateTime;
begin
  try
    if FProdutoId <= 0 then Exit;

    LDataInicio := StrToDateDef(edtDataInicio.Text, Now);
    LDataFim := StrToDateDef(edtDataFim.Text, Now);

    FService.CarregarKardex(FQuery, FProdutoId, LDataInicio, LDataFim,
      edtPesquisa.Text);
    DataSource1.DataSet := FQuery;
  except
    on E: Exception do
      MessageDlg('Erro ao carregar kardex: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmKardex.CarregarResumo;
var
  LDataInicio, LDataFim: TDateTime;
  LResumo: TKardexResumo;
begin
  try
    LDataInicio := StrToDateDef(edtDataInicio.Text, Now);
    LDataFim := StrToDateDef(edtDataFim.Text, Now);

    FService.CarregarResumo(FProdutoId, LDataInicio, LDataFim,
      edtPesquisa.Text, LResumo);

    lblTotalEntradas.Caption := 'Entradas: ' + FormatFloat('#,##0.0000', LResumo.Entradas);
    lblTotalSaidas.Caption := 'Saídas: ' + FormatFloat('#,##0.0000', LResumo.Saidas);
    lblSaldoFinal.Caption := 'Saldo: ' + FormatFloat('#,##0.0000', LResumo.Saldo);
  except
    on E: Exception do
      MessageDlg('Erro ao carregar resumo: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmKardex.btnFiltrarClick(Sender: TObject);
begin
  CarregarKardex;
  CarregarResumo;
end;

procedure TfrmKardex.btnPesquisarMovClick(Sender: TObject);
begin
  CarregarKardex;
  CarregarResumo;
end;

procedure TfrmKardex.edtPesquisaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnPesquisarMovClick(Sender);
  end;
end;

procedure TfrmKardex.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
