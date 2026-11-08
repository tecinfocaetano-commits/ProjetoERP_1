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
  uConexao, uInventarioService;

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
    FService: TInventarioService;
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
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TInventarioService.Create;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

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
  LTotal: Double;
begin
  FService.CarregarInventario(FQuery, edtPesquisa.Text,
    chkApenasComEstoque.Checked, chkAbaixoMinimo.Checked);
  DataSource1.DataSet := FQuery;

  // Resumo
  FQuery.Last;
  lblTotalItens.Caption := Format('Total Itens: %d', [FQuery.RecordCount]);
  FQuery.First;

  // Calcular valor total usando o Service
  LTotal := FService.ValorTotalEstoque;
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
