unit uFrmInventario;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 3 - Inventário de Estoque
  Descrição: Posição atual de estoque de todos os produtos
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uConexao;

type
  { TfrmInventario }
  TfrmInventario = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlFiltro: TPanel;
    edtPesquisa: TEdit;
    btnPesquisar: TBitBtn;
    chkApenasComEstoque: TCheckBox;
    chkAbaixoMinimo: TCheckBox;
    btnFechar: TBitBtn;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    pnlResumo: TPanel;
    lblTotalItens: TLabel;
    lblValorTotal: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnPesquisarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure chkApenasComEstoqueChange(Sender: TObject);
    procedure chkAbaixoMinimoChange(Sender: TObject);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    procedure CarregarInventario;
  end;

var
  frmInventario: TfrmInventario;

implementation

{$R *.lfm}

procedure TfrmInventario.FormCreate(Sender: TObject);
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
    CarregarInventario;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmInventario.CarregarInventario;
var
  LSQL, LWhere: string;
  LTotal: Double;
begin
  LSQL :=
    'SELECT P.ID, P.CODIGO, P.DESCRICAO, ' +
    'COALESCE(E.QUANTIDADE, 0) AS QTD_ATUAL, ' +
    'P.ESTOQUE_MINIMO, P.ESTOQUE_MAXIMO, ' +
    'P.PRECO_CUSTO, P.PRECO_VENDA, ' +
    '(COALESCE(E.QUANTIDADE, 0) * P.PRECO_CUSTO) AS VALOR_ESTOQUE ' +
    'FROM PRODUTO P ' +
    'LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
    'WHERE P.CONTROLA_ESTOQUE = ''S'' AND P.ATIVO = ''A''';

  if Trim(edtPesquisa.Text) <> '' then
    LSQL := LSQL + ' AND (UPPER(P.DESCRICAO) CONTAINING UPPER(:FILTRO) OR P.CODIGO CONTAINING :FILTRO2)';

  if chkApenasComEstoque.Checked then
    LSQL := LSQL + ' AND COALESCE(E.QUANTIDADE, 0) > 0';

  if chkAbaixoMinimo.Checked then
    LSQL := LSQL + ' AND COALESCE(E.QUANTIDADE, 0) < P.ESTOQUE_MINIMO AND P.ESTOQUE_MINIMO > 0';

  LSQL := LSQL + ' ORDER BY P.DESCRICAO';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  if Trim(edtPesquisa.Text) <> '' then
  begin
    FQuery.ParamByName('FILTRO').AsString := edtPesquisa.Text;
    FQuery.ParamByName('FILTRO2').AsString := edtPesquisa.Text;
  end;
  FQuery.Open;
  DataSource1.DataSet := FQuery;

  // Resumo
  FQuery.Last;
  lblTotalItens.Caption := Format('Total Itens: %d', [FQuery.RecordCount]);
  FQuery.First;

  // Calcular valor total
  LTotal := 0;
  while not FQuery.EOF do
  begin
    LTotal := LTotal + FQuery.FieldByName('VALOR_ESTOQUE').AsFloat;
    FQuery.Next;
  end;
  FQuery.First;
  lblValorTotal.Caption := Format('Valor Total Estoque: R$ %s', [FormatFloat('#,##0.00', LTotal)]);
end;

procedure TfrmInventario.btnPesquisarClick(Sender: TObject);
begin
  CarregarInventario;
end;

procedure TfrmInventario.chkApenasComEstoqueChange(Sender: TObject);
begin
  CarregarInventario;
end;

procedure TfrmInventario.chkAbaixoMinimoChange(Sender: TObject);
begin
  CarregarInventario;
end;

procedure TfrmInventario.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
