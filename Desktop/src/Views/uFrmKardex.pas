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
  uConexao;

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
    procedure btnFecharClick(Sender: TObject);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
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
    FProdutoId := 0;

    // Criar DataSource1 se não existir
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
  LQuery: TSQLQuery;
begin
  if Trim(edtProduto.Text) = '' then Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT P.ID, P.DESCRICAO, COALESCE(E.QUANTIDADE, 0) AS ESTOQUE_ATUAL ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
      'WHERE P.CODIGO = :COD OR P.CODIGO_BARRAS = :COD OR CAST(P.ID AS VARCHAR(20)) = :COD';
    LQuery.ParamByName('COD').AsString := Trim(edtProduto.Text);
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      FProdutoId := LQuery.FieldByName('ID').AsLargeInt;
      lblProdutoNome.Caption := LQuery.FieldByName('DESCRICAO').AsString;
      lblEstoqueAtual.Caption := 'Estoque Atual: ' +
        FormatFloat('#,##0.0000', LQuery.FieldByName('ESTOQUE_ATUAL').AsFloat);
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
  finally
    LQuery.Free;
  end;
end;

procedure TfrmKardex.CarregarKardex;
var
  LDataInicio, LDataFim: TDateTime;
begin
  try
    if FProdutoId <= 0 then Exit;

    if FQuery = nil then
      raise Exception.Create('FQuery não foi inicializado');

    LDataInicio := StrToDateDef(edtDataInicio.Text, Now);
    LDataFim := StrToDateDef(edtDataFim.Text, Now);

    if FQuery.Active then
      FQuery.Close;
    FQuery.SQL.Text :=
      'SELECT ME.DATA_MOVIMENTO, ' +
      'CASE ME.TIPO WHEN ''E'' THEN ''Entrada'' WHEN ''S'' THEN ''Saída'' ' +
      'WHEN ''A'' THEN ''Ajuste'' WHEN ''I'' THEN ''Inventário'' END AS TIPO, ' +
      'ME.QUANTIDADE, ME.CUSTO_UNITARIO, ' +
      '(ME.QUANTIDADE * ME.CUSTO_UNITARIO) AS VALOR_TOTAL, ' +
      'ME.DOCUMENTO, ME.OBSERVACAO ' +
      'FROM MOVIMENTO_ESTOQUE ME ' +
      'WHERE ME.PRODUTO_ID = :PROD ' +
      'AND ME.DATA_MOVIMENTO BETWEEN :DI AND :DF ' +
      'ORDER BY ME.DATA_MOVIMENTO';
    FQuery.ParamByName('PROD').AsLargeInt := FProdutoId;
    FQuery.ParamByName('DI').AsDate := LDataInicio;
    FQuery.ParamByName('DF').AsDate := LDataFim + 1;
    FQuery.Open;
    DataSource1.DataSet := FQuery;
  except
    on E: Exception do
      MessageDlg('Erro ao carregar kardex: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmKardex.CarregarResumo;
var
  LQuery: TSQLQuery;
  LDataInicio, LDataFim: TDateTime;
begin
  try
    if FConexao = nil then
      raise Exception.Create('FConexao não foi inicializado');

    LDataInicio := StrToDateDef(edtDataInicio.Text, Now);
    LDataFim := StrToDateDef(edtDataFim.Text, Now);

    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := FConexao.Connection;
      LQuery.Transaction := FConexao.Transaction;
      LQuery.SQL.Text :=
        'SELECT ' +
        'COALESCE(SUM(CASE WHEN TIPO IN (''E'',''A'') THEN QUANTIDADE ELSE 0 END), 0) AS ENTRADAS, ' +
        'COALESCE(SUM(CASE WHEN TIPO = ''S'' THEN QUANTIDADE ELSE 0 END), 0) AS SAIDAS ' +
        'FROM MOVIMENTO_ESTOQUE ' +
        'WHERE PRODUTO_ID = :PROD AND DATA_MOVIMENTO BETWEEN :DI AND :DF';
      LQuery.ParamByName('PROD').AsLargeInt := FProdutoId;
      LQuery.ParamByName('DI').AsDate := LDataInicio;
      LQuery.ParamByName('DF').AsDate := LDataFim + 1;
      LQuery.Open;

      lblTotalEntradas.Caption := 'Entradas: ' + FormatFloat('#,##0.0000', LQuery.FieldByName('ENTRADAS').AsFloat);
      lblTotalSaidas.Caption := 'Saídas: ' + FormatFloat('#,##0.0000', LQuery.FieldByName('SAIDAS').AsFloat);
      lblSaldoFinal.Caption := 'Saldo: ' + FormatFloat('#,##0.0000',
        LQuery.FieldByName('ENTRADAS').AsFloat - LQuery.FieldByName('SAIDAS').AsFloat);
    finally
      LQuery.Free;
    end;
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

procedure TfrmKardex.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
