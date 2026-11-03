unit uFrmMovEstoque;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 3 - Movimentação de Estoque
  Descrição: Entrada, Saída, Ajuste de estoque
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, Spin, DateUtils,
  uConexao, uSessao;

type
  { TfrmMovEstoque }
  TfrmMovEstoque = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlFiltros: TPanel;
    lblDataInicio: TLabel;
    edtDataInicio: TEdit;
    lblDataFim: TLabel;
    edtDataFim: TEdit;
    lblTipoFiltro: TLabel;
    cmbTipoFiltro: TComboBox;
    btnFiltrar: TBitBtn;
    lblPesquisa: TLabel;
    edtPesquisa: TEdit;
    pnlBotoes: TPanel;
    btnNovaMovimentacao: TBitBtn;
    btnFechar: TBitBtn;
    dbGrid: TDBGrid;
    DataSource1: TDataSource;
    pnlMovimentacao: TPanel;
    lblTipo: TLabel;
    cmbTipo: TComboBox;
    lblProduto: TLabel;
    edtProduto: TEdit;
    btnBuscarProduto: TBitBtn;
    lblProdutoDesc: TLabel;
    lblQuantidade: TLabel;
    edtQuantidade: TEdit;
    lblCustoUnit: TLabel;
    edtCustoUnit: TEdit;
    lblDocumento: TLabel;
    edtDocumento: TEdit;
    lblObservacao: TLabel;
    mmoObservacao: TMemo;
    btnConfirmar: TBitBtn;
    btnCancelarMov: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnNovaMovimentacaoClick(Sender: TObject);
    procedure btnConfirmarClick(Sender: TObject);
    procedure btnCancelarMovClick(Sender: TObject);
    procedure btnFiltrarClick(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnBuscarProdutoClick(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: char);
  private
    FConexao: TConexao;
    FQuery: TSQLQuery;
    FProdutoId: Int64;
    procedure CarregarMovimentos;
    procedure MostrarPainelMovimentacao(AVisivel: Boolean);
    procedure LimparMovimentacao;
  end;

var
  frmMovEstoque: TfrmMovEstoque;

implementation

{$R *.lfm}

procedure TfrmMovEstoque.FormCreate(Sender: TObject);
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

    // Não inicializar datas aqui - fazer no FormShow para garantir que componentes existem
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMovEstoque.FormShow(Sender: TObject);
begin
  try
    // Inicializar datas após os componentes visuais serem criados
    if edtDataInicio <> nil then
      edtDataInicio.Text := FormatDateTime('dd/mm/yyyy', IncMonth(Now, -1));
    if edtDataFim <> nil then
      edtDataFim.Text := FormatDateTime('dd/mm/yyyy', Now);

    // Inicializar ComboBox de filtro
    if cmbTipoFiltro <> nil then
    begin
      cmbTipoFiltro.Items.Clear;
      cmbTipoFiltro.Items.Add('Todos');
      cmbTipoFiltro.Items.Add('Entrada');
      cmbTipoFiltro.Items.Add('Saída');
      cmbTipoFiltro.Items.Add('Ajuste');
      cmbTipoFiltro.Items.Add('Inventário');
      cmbTipoFiltro.ItemIndex := 0;
    end;

    // Inicializar ComboBox de tipo de movimentação
    if cmbTipo <> nil then
    begin
      cmbTipo.Items.Clear;
      cmbTipo.Items.Add('Entrada');
      cmbTipo.Items.Add('Saída');
      cmbTipo.Items.Add('Ajuste');
      cmbTipo.Items.Add('Inventário');
      cmbTipo.ItemIndex := 0;
    end;

    MostrarPainelMovimentacao(False);
    CarregarMovimentos;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMovEstoque.CarregarMovimentos;
var
  LSQL, LFiltroTipo: string;
  LDataInicio, LDataFim: TDateTime;
begin
  try
    if FQuery = nil then
      raise Exception.Create('FQuery não foi inicializado');

    LSQL :=
      'SELECT ME.ID, P.DESCRICAO AS PRODUTO, ' +
      'CASE ME.TIPO WHEN ''E'' THEN ''Entrada'' WHEN ''S'' THEN ''Saída'' ' +
      'WHEN ''A'' THEN ''Ajuste'' WHEN ''I'' THEN ''Inventário'' END AS TIPO_DESC, ' +
      'ME.QUANTIDADE, ME.CUSTO_UNITARIO, ME.DOCUMENTO, ME.DATA_MOVIMENTO ' +
      'FROM MOVIMENTO_ESTOQUE ME ' +
      'JOIN PRODUTO P ON P.ID = ME.PRODUTO_ID ' +
      'WHERE ME.DATA_MOVIMENTO BETWEEN :DI AND :DF';

    if cmbTipoFiltro.ItemIndex > 0 then
    begin
      case cmbTipoFiltro.ItemIndex of
        1: LFiltroTipo := 'E';
        2: LFiltroTipo := 'S';
        3: LFiltroTipo := 'A';
        4: LFiltroTipo := 'I';
      end;
      LSQL := LSQL + ' AND ME.TIPO = :TIPO';
    end;

    if Trim(edtPesquisa.Text) <> '' then
      LSQL := LSQL + ' AND (UPPER(P.DESCRICAO) CONTAINING UPPER(:PESQ)' +
                     ' OR P.CODIGO CONTAINING :PESQ2' +
                     ' OR UPPER(COALESCE(ME.DOCUMENTO, '''')) CONTAINING UPPER(:PESQ3))';

    LSQL := LSQL + ' ORDER BY ME.DATA_MOVIMENTO DESC';

    LDataInicio := StrToDateDef(edtDataInicio.Text, Now);
    LDataFim := StrToDateDef(edtDataFim.Text, Now);

    if FQuery.Active then
      FQuery.Close;
    FQuery.SQL.Text := LSQL;
    FQuery.ParamByName('DI').AsDate := LDataInicio;
    FQuery.ParamByName('DF').AsDate := LDataFim + 1;
    if cmbTipoFiltro.ItemIndex > 0 then
      FQuery.ParamByName('TIPO').AsString := LFiltroTipo;
    if Trim(edtPesquisa.Text) <> '' then
    begin
      FQuery.ParamByName('PESQ').AsString := Trim(edtPesquisa.Text);
      FQuery.ParamByName('PESQ2').AsString := Trim(edtPesquisa.Text);
      FQuery.ParamByName('PESQ3').AsString := Trim(edtPesquisa.Text);
    end;
    FQuery.Open;
    DataSource1.DataSet := FQuery;
  except
    on E: Exception do
      MessageDlg('Erro ao carregar movimentos: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMovEstoque.MostrarPainelMovimentacao(AVisivel: Boolean);
begin
  pnlMovimentacao.Visible := AVisivel;
  btnNovaMovimentacao.Enabled := not AVisivel;
end;

procedure TfrmMovEstoque.LimparMovimentacao;
begin
  cmbTipo.ItemIndex := 0;
  edtProduto.Clear;
  lblProdutoDesc.Caption := '';
  edtQuantidade.Text := '0';
  edtCustoUnit.Text := '0,00';
  edtDocumento.Clear;
  mmoObservacao.Clear;
  FProdutoId := 0;
end;

procedure TfrmMovEstoque.btnNovaMovimentacaoClick(Sender: TObject);
begin
  LimparMovimentacao;
  MostrarPainelMovimentacao(True);
  edtProduto.SetFocus;
end;

procedure TfrmMovEstoque.btnBuscarProdutoClick(Sender: TObject);
var
  LQuery: TSQLQuery;
begin
  if Trim(edtProduto.Text) = '' then Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO, PRECO_CUSTO FROM PRODUTO ' +
      'WHERE CODIGO = :COD OR CODIGO_BARRAS = :COD OR CAST(ID AS VARCHAR(20)) = :COD';
    LQuery.ParamByName('COD').AsString := Trim(edtProduto.Text);
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      FProdutoId := LQuery.FieldByName('ID').AsLargeInt;
      lblProdutoDesc.Caption := LQuery.FieldByName('DESCRICAO').AsString;
      edtCustoUnit.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('PRECO_CUSTO').AsFloat);
    end
    else
    begin
      MessageDlg('Produto não encontrado.', mtWarning, [mbOK], 0);
      FProdutoId := 0;
      lblProdutoDesc.Caption := '';
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmMovEstoque.btnConfirmarClick(Sender: TObject);
var
  LQuery: TSQLQuery;
  LTipo: string;
begin
  if FProdutoId <= 0 then
  begin
    MessageDlg('Selecione um produto.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if StrToFloatDef(edtQuantidade.Text, 0) <= 0 then
  begin
    MessageDlg('Informe uma quantidade válida.', mtWarning, [mbOK], 0);
    Exit;
  end;

  case cmbTipo.ItemIndex of
    0: LTipo := 'E';
    1: LTipo := 'S';
    2: LTipo := 'A';
    3: LTipo := 'I';
  else LTipo := 'E';
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, QUANTIDADE, ' +
      'CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, USUARIO_ID) ' +
      'VALUES (:EMP, :PROD, :TIPO, :QTD, :CUSTO, :DOC, :OBS, :USR)';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := FProdutoId;
    LQuery.ParamByName('TIPO').AsString := LTipo;
    LQuery.ParamByName('QTD').AsFloat := StrToFloatDef(edtQuantidade.Text, 0);
    LQuery.ParamByName('CUSTO').AsFloat := StrToFloatDef(edtCustoUnit.Text, 0);
    LQuery.ParamByName('DOC').AsString := edtDocumento.Text;
    LQuery.ParamByName('OBS').AsString := mmoObservacao.Text;
    LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LQuery.ExecSQL;
    FConexao.Confirmar;

    MessageDlg('Movimentação registrada com sucesso!', mtInformation, [mbOK], 0);
    MostrarPainelMovimentacao(False);
    CarregarMovimentos;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

procedure TfrmMovEstoque.btnCancelarMovClick(Sender: TObject);
begin
  MostrarPainelMovimentacao(False);
end;

procedure TfrmMovEstoque.btnFiltrarClick(Sender: TObject);
begin
  CarregarMovimentos;
end;

procedure TfrmMovEstoque.edtPesquisaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarMovimentos;
  end;
end;

procedure TfrmMovEstoque.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
