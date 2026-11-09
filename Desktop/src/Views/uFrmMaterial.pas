unit uFrmMaterial;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Material
  Descrição: CRUD de Materiais (insumos comprados/consumidos).
             Vincula a um Produto Fiscal e a uma Unidade.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao,
  uMaterialService, uMaterial;

type
  { TfrmMaterial }
  TfrmMaterial = class(TfrmCadastroBase)
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblCodigoBarras: TLabel;
    edtCodigoBarras: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    lblProdutoFiscal: TLabel;
    cmbProdutoFiscal: TComboBox;
    lblUnidade: TLabel;
    cmbUnidade: TComboBox;
    lblPrecoCusto: TLabel;
    edtPrecoCusto: TEdit;
    lblEstoqueMin: TLabel;
    edtEstoqueMin: TEdit;
    chkControlaEstoque: TCheckBox;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    lblObservacoes: TLabel;
    mmoObservacoes: TMemo;
    procedure FormCreate(Sender: TObject);
  public
    destructor Destroy; override;
  protected
    procedure HabilitarCampos(AHabilitar: Boolean); override;
    procedure LimparCampos; override;
    procedure PreencherCampos; override;
    procedure PreencherObjeto; override;
    function Validar: Boolean; override;
    procedure CarregarDados(const AFiltro: string = ''); override;
    function Salvar: Boolean; override;
    function Excluir: Boolean; override;
  private
    FQuery: TSQLQuery;
    FService: TMaterialService;
    procedure ConfigurarGrid;
    procedure CarregarProdutosFiscais;
    procedure CarregarUnidades;
    function IdDoItemSelecionado(ACombo: TComboBox): Int64;
    procedure SelecionarItemPorId(ACombo: TComboBox; AId: Int64);
  end;

var
  frmMaterial: TfrmMaterial;

implementation

{$R *.lfm}

{ TfrmMaterial }

destructor TfrmMaterial.Destroy;
begin
  FreeAndNil(FService);
  inherited Destroy;
end;

procedure TfrmMaterial.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;
    FService := TMaterialService.Create;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Cadastro de Materiais';
    Caption := 'Materiais';
    ConfigurarGrid;
    CarregarProdutosFiscais;
    CarregarUnidades;

    cmbStatus.Items.Clear;
    cmbStatus.Items.Add('Ativo');
    cmbStatus.Items.Add('Inativo');
    cmbStatus.ItemIndex := 0;

    FEstado := efNavegando;
    Position := poScreenCenter;
    BorderStyle := bsSizeable;
    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMaterial.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Código'; FieldName := 'CODIGO'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 260; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Custo'; FieldName := 'PRECO_CUSTO'; Width := 90; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Controla'; FieldName := 'CONTROLA_ESTOQUE'; Width := 60; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Ativo'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmMaterial.CarregarProdutosFiscais;
var
  LQuery: TSQLQuery;
begin
  cmbProdutoFiscal.Items.Clear;
  cmbProdutoFiscal.Items.AddObject('', TObject(PtrInt(0)));
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, DESCRICAO FROM PRODUTO_FISCAL WHERE ATIVO = ''A'' AND EMPRESA_ID = :EMP ORDER BY DESCRICAO';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbProdutoFiscal.Items.AddObject(LQuery.FieldByName('DESCRICAO').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmMaterial.CarregarUnidades;
var
  LQuery: TSQLQuery;
begin
  cmbUnidade.Items.Clear;
  cmbUnidade.Items.AddObject('', TObject(PtrInt(0)));
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, SIGLA FROM UNIDADE ORDER BY SIGLA';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbUnidade.Items.AddObject(LQuery.FieldByName('SIGLA').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TfrmMaterial.IdDoItemSelecionado(ACombo: TComboBox): Int64;
begin
  Result := 0;
  if (ACombo.ItemIndex >= 0) and (ACombo.Items.Objects[ACombo.ItemIndex] <> nil) then
    Result := Int64(PtrInt(ACombo.Items.Objects[ACombo.ItemIndex]));
end;

procedure TfrmMaterial.SelecionarItemPorId(ACombo: TComboBox; AId: Int64);
var
  LIdx: Integer;
begin
  ACombo.ItemIndex := 0;
  for LIdx := 0 to ACombo.Items.Count - 1 do
    if (ACombo.Items.Objects[LIdx] <> nil) and
       (Int64(PtrInt(ACombo.Items.Objects[LIdx])) = AId) then
    begin
      ACombo.ItemIndex := LIdx;
      Break;
    end;
end;

procedure TfrmMaterial.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, CODIGO, DESCRICAO, PRECO_CUSTO, CONTROLA_ESTOQUE, ATIVO FROM MATERIAL WHERE EMPRESA_ID = :EMP';
  if AFiltro <> '' then
    LSQL := LSQL + ' AND (UPPER(DESCRICAO) CONTAINING UPPER(:FILTRO) OR CODIGO CONTAINING :FILTRO2 OR CODIGO_BARRAS CONTAINING :FILTRO3)';
  LSQL := LSQL + ' ORDER BY DESCRICAO';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  FQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
  if AFiltro <> '' then
  begin
    FQuery.ParamByName('FILTRO').AsString := AFiltro;
    FQuery.ParamByName('FILTRO2').AsString := AFiltro;
    FQuery.ParamByName('FILTRO3').AsString := AFiltro;
  end;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmMaterial.HabilitarCampos(AHabilitar: Boolean);
begin
  edtCodigo.Enabled := AHabilitar;
  edtCodigoBarras.Enabled := AHabilitar;
  edtDescricao.Enabled := AHabilitar;
  cmbProdutoFiscal.Enabled := AHabilitar;
  cmbUnidade.Enabled := AHabilitar;
  edtPrecoCusto.Enabled := AHabilitar;
  edtEstoqueMin.Enabled := AHabilitar;
  chkControlaEstoque.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
  mmoObservacoes.Enabled := AHabilitar;
end;

procedure TfrmMaterial.LimparCampos;
begin
  edtCodigo.Clear;
  edtCodigoBarras.Clear;
  edtDescricao.Clear;
  cmbProdutoFiscal.ItemIndex := 0;
  cmbUnidade.ItemIndex := 0;
  edtPrecoCusto.Text := '0,00';
  edtEstoqueMin.Text := '0';
  chkControlaEstoque.Checked := True;
  cmbStatus.ItemIndex := 0;
  mmoObservacoes.Clear;
end;

procedure TfrmMaterial.PreencherCampos;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM MATERIAL WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      edtCodigo.Text := LQuery.FieldByName('CODIGO').AsString;
      edtCodigoBarras.Text := LQuery.FieldByName('CODIGO_BARRAS').AsString;
      edtDescricao.Text := LQuery.FieldByName('DESCRICAO').AsString;
      SelecionarItemPorId(cmbProdutoFiscal, LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt);
      SelecionarItemPorId(cmbUnidade, LQuery.FieldByName('UNIDADE_ID').AsLargeInt);
      edtPrecoCusto.Text := FormatFloat('#,##0.00', LQuery.FieldByName('PRECO_CUSTO').AsFloat);
      edtEstoqueMin.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('ESTOQUE_MINIMO').AsFloat);
      chkControlaEstoque.Checked := LQuery.FieldByName('CONTROLA_ESTOQUE').AsString = 'S';

      if LQuery.FieldByName('ATIVO').AsString = 'A' then
        cmbStatus.ItemIndex := 0
      else
        cmbStatus.ItemIndex := 1;

      mmoObservacoes.Text := LQuery.FieldByName('OBSERVACOES').AsString;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmMaterial.PreencherObjeto;
begin
  // montado direto no Salvar
end;

function TfrmMaterial.Validar: Boolean;
begin
  Result := False;

  if Trim(edtDescricao.Text) = '' then
  begin
    MessageDlg('O campo Descrição é obrigatório.', mtWarning, [mbOK], 0);
    edtDescricao.SetFocus;
    Exit;
  end;

  Result := True;
end;

function TfrmMaterial.Salvar: Boolean;
var
  LMaterial: TMaterial;
begin
  Result := False;
  LMaterial := TMaterial.Create;
  try
    if FEstado = efInserindo then
      LMaterial.Id := 0
    else
      LMaterial.Id := FIdSelecionado;
    LMaterial.EmpresaId := TSessao.GetInstance.EmpresaId;
    LMaterial.ProdutoFiscalId := IdDoItemSelecionado(cmbProdutoFiscal);
    LMaterial.UnidadeId := IdDoItemSelecionado(cmbUnidade);
    LMaterial.Codigo := Trim(edtCodigo.Text);
    LMaterial.CodigoBarras := Trim(edtCodigoBarras.Text);
    LMaterial.Descricao := Trim(edtDescricao.Text);
    LMaterial.PrecoCusto := StrToFloatDef(edtPrecoCusto.Text, 0);
    LMaterial.ControlaEstoque := chkControlaEstoque.Checked;
    LMaterial.EstoqueMinimo := StrToFloatDef(edtEstoqueMin.Text, 0);
    LMaterial.Observacoes := mmoObservacoes.Text;
    if cmbStatus.ItemIndex = 0 then
      LMaterial.Ativo := 'A'
    else
      LMaterial.Ativo := 'I';

    if LMaterial.Id = 0 then
      LMaterial.Id := FService.Inserir(LMaterial)
    else
      FService.Atualizar(LMaterial);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
  LMaterial.Free;
end;

function TfrmMaterial.Excluir: Boolean;
begin
  Result := False;
  try
    FService.Excluir(FIdSelecionado);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
