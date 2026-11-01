unit uFrmProdutos;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário de Produtos
  Descrição: CRUD completo de Produtos
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao, uGradeService;

type
  { TfrmProdutos }
  TfrmProdutos = class(TfrmCadastroBase)
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblCodigoBarras: TLabel;
    edtCodigoBarras: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    lblDescricaoPDV: TLabel;
    edtDescricaoPDV: TEdit;
    lblCategoria: TLabel;
    cmbCategoria: TComboBox;
    lblUnidade: TLabel;
    cmbUnidade: TComboBox;
    lblGrade: TLabel;
    cmbGrade: TComboBox;
    lblNcm: TLabel;
    edtNcm: TEdit;
    lblCest: TLabel;
    edtCest: TEdit;
    lblCfopVenda: TLabel;
    edtCfopVenda: TEdit;
    lblPrecoCusto: TLabel;
    edtPrecoCusto: TEdit;
    lblPrecoVenda: TLabel;
    edtPrecoVenda: TEdit;
    lblMargemLucro: TLabel;
    edtMargemLucro: TEdit;
    lblEstoqueMin: TLabel;
    edtEstoqueMin: TEdit;
    lblEstoqueMax: TLabel;
    edtEstoqueMax: TEdit;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    chkControlaEstoque: TCheckBox;
    lblObservacoes: TLabel;
    mmoObservacoes: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure edtPrecoCustoExit(Sender: TObject);
    procedure edtMargemLucroExit(Sender: TObject);
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
    FGradeService: TGradeService;
    procedure ConfigurarGrid;
    procedure CarregarCategorias;
    procedure CarregarUnidades;
    procedure CarregarGrades;
    procedure CalcularPrecoVenda;
  end;

var
  frmProdutos: TfrmProdutos;

implementation

{$R *.lfm}

{ TfrmProdutos }

procedure TfrmProdutos.FormCreate(Sender: TObject);
begin
  try
    // Inicializar FConexao primeiro (como faz a classe base)
    FConexao := TConexao.GetInstance;

    // Iniciar conexão com o banco
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    FGradeService := TGradeService.Create;

    // Criar DataSource1 se não existir
    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Cadastro de Produtos';
    Caption := 'Produtos';
    ConfigurarGrid;
    CarregarCategorias;
    CarregarUnidades;
    CarregarGrades;

    // Inicializar ComboBox de status
    cmbStatus.Items.Clear;
    cmbStatus.Items.Add('Ativo');
    cmbStatus.Items.Add('Inativo');
    cmbStatus.ItemIndex := 0;

    // Configurar estado inicial (como faz a classe base)
    FEstado := efNavegando;
    Position := poScreenCenter;
    BorderStyle := bsSizeable;

    // Agora carregar os dados
    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmProdutos.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FGradeService);
  inherited;
end;

procedure TfrmProdutos.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Código'; FieldName := 'CODIGO'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 250; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Preço Venda'; FieldName := 'PRECO_VENDA'; Width := 100; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'NCM'; FieldName := 'NCM'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Ativo'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmProdutos.CarregarCategorias;
var
  LQuery: TSQLQuery;
begin
  cmbCategoria.Items.Clear;
  cmbCategoria.Items.Add(''); // vazio
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, NOME FROM CATEGORIA WHERE ATIVO = ''A'' ORDER BY NOME';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbCategoria.Items.AddObject(LQuery.FieldByName('NOME').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmProdutos.CarregarUnidades;
var
  LQuery: TSQLQuery;
begin
  cmbUnidade.Items.Clear;
  cmbUnidade.Items.Add(''); // vazio
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

procedure TfrmProdutos.CarregarGrades;
var
  LQuery: TSQLQuery;
begin
  cmbGrade.Items.Clear;
  cmbGrade.Items.Add('');   { sem grade padrao }
  if FGradeService = nil then
    Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FGradeService.Carregar(LQuery);
    while not LQuery.EOF do
    begin
      if LQuery.FieldByName('ATIVO').AsString = 'A' then
        cmbGrade.Items.AddObject(LQuery.FieldByName('NOME').AsString,
          TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmProdutos.CalcularPrecoVenda;var
  LCusto, LMargem: Double;
begin
  LCusto := StrToFloatDef(edtPrecoCusto.Text, 0);
  LMargem := StrToFloatDef(edtMargemLucro.Text, 0);
  if (LCusto > 0) and (LMargem > 0) then
    edtPrecoVenda.Text := FormatFloat('#,##0.00', LCusto * (1 + LMargem / 100));
end;

procedure TfrmProdutos.edtPrecoCustoExit(Sender: TObject);
begin
  CalcularPrecoVenda;
end;

procedure TfrmProdutos.edtMargemLucroExit(Sender: TObject);
begin
  CalcularPrecoVenda;
end;

procedure TfrmProdutos.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, CODIGO, DESCRICAO, PRECO_VENDA, NCM, ATIVO FROM PRODUTO';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(DESCRICAO) CONTAINING UPPER(:FILTRO) OR CODIGO CONTAINING :FILTRO2 OR CODIGO_BARRAS CONTAINING :FILTRO3';
  LSQL := LSQL + ' ORDER BY DESCRICAO';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  if AFiltro <> '' then
  begin
    FQuery.ParamByName('FILTRO').AsString := AFiltro;
    FQuery.ParamByName('FILTRO2').AsString := AFiltro;
    FQuery.ParamByName('FILTRO3').AsString := AFiltro;
  end;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmProdutos.HabilitarCampos(AHabilitar: Boolean);
begin
  edtCodigo.Enabled := AHabilitar;
  edtCodigoBarras.Enabled := AHabilitar;
  edtDescricao.Enabled := AHabilitar;
  edtDescricaoPDV.Enabled := AHabilitar;
  cmbCategoria.Enabled := AHabilitar;
  cmbUnidade.Enabled := AHabilitar;
  cmbGrade.Enabled := AHabilitar;
  edtNcm.Enabled := AHabilitar;
  edtCest.Enabled := AHabilitar;
  edtCfopVenda.Enabled := AHabilitar;
  edtPrecoCusto.Enabled := AHabilitar;
  edtPrecoVenda.Enabled := AHabilitar;
  edtMargemLucro.Enabled := AHabilitar;
  edtEstoqueMin.Enabled := AHabilitar;
  edtEstoqueMax.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
  chkControlaEstoque.Enabled := AHabilitar;
  mmoObservacoes.Enabled := AHabilitar;
end;

procedure TfrmProdutos.LimparCampos;
begin
  edtCodigo.Clear;
  edtCodigoBarras.Clear;
  edtDescricao.Clear;
  edtDescricaoPDV.Clear;
  cmbCategoria.ItemIndex := 0;
  cmbUnidade.ItemIndex := 0;
  cmbGrade.ItemIndex := 0;
  edtNcm.Clear;
  edtCest.Clear;
  edtCfopVenda.Clear;
  edtPrecoCusto.Text := '0,00';
  edtPrecoVenda.Text := '0,00';
  edtMargemLucro.Text := '0,00';
  edtEstoqueMin.Text := '0';
  edtEstoqueMax.Text := '0';
  cmbStatus.ItemIndex := 0;
  chkControlaEstoque.Checked := True;
  mmoObservacoes.Clear;
end;

procedure TfrmProdutos.PreencherCampos;
var
  LQuery: TSQLQuery;
  I: Integer;
  LGradeId: Int64;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM PRODUTO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      edtCodigo.Text := LQuery.FieldByName('CODIGO').AsString;
      edtCodigoBarras.Text := LQuery.FieldByName('CODIGO_BARRAS').AsString;
      edtDescricao.Text := LQuery.FieldByName('DESCRICAO').AsString;
      edtDescricaoPDV.Text := LQuery.FieldByName('DESCRICAO_PDV').AsString;
      edtNcm.Text := LQuery.FieldByName('NCM').AsString;
      edtCest.Text := LQuery.FieldByName('CEST').AsString;
      edtCfopVenda.Text := LQuery.FieldByName('CFOP_VENDA').AsString;
      edtPrecoCusto.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('PRECO_CUSTO').AsFloat);
      edtPrecoVenda.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('PRECO_VENDA').AsFloat);
      edtMargemLucro.Text := FormatFloat('#,##0.00', LQuery.FieldByName('MARGEM_LUCRO').AsFloat);
      edtEstoqueMin.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('ESTOQUE_MINIMO').AsFloat);
      edtEstoqueMax.Text := FormatFloat('#,##0.0000', LQuery.FieldByName('ESTOQUE_MAXIMO').AsFloat);
      chkControlaEstoque.Checked := LQuery.FieldByName('CONTROLA_ESTOQUE').AsString = 'S';

      if LQuery.FieldByName('ATIVO').AsString = 'A' then
        cmbStatus.ItemIndex := 0
      else
        cmbStatus.ItemIndex := 1;

      cmbGrade.ItemIndex := 0;
      LGradeId := 0;
      if not LQuery.FieldByName('GRADE_ID').IsNull then
        LGradeId := LQuery.FieldByName('GRADE_ID').AsLargeInt;
      if LGradeId > 0 then
        for I := 1 to cmbGrade.Items.Count - 1 do
          if (cmbGrade.Items.Objects[I] <> nil) and
             (PtrInt(cmbGrade.Items.Objects[I]) = LGradeId) then
          begin
            cmbGrade.ItemIndex := I;
            Break;
          end;

      mmoObservacoes.Text := LQuery.FieldByName('OBSERVACOES').AsString;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmProdutos.PreencherObjeto;
begin
  // montado direto no Salvar
end;

function TfrmProdutos.Validar: Boolean;
begin
  Result := False;

  if Trim(edtDescricao.Text) = '' then
  begin
    MessageDlg('O campo Descrição é obrigatório.', mtWarning, [mbOK], 0);
    edtDescricao.SetFocus;
    Exit;
  end;

  if StrToFloatDef(edtPrecoVenda.Text, 0) <= 0 then
  begin
    MessageDlg('O Preço de Venda deve ser maior que zero.', mtWarning, [mbOK], 0);
    edtPrecoVenda.SetFocus;
    Exit;
  end;

  Result := True;
end;

function TfrmProdutos.Salvar: Boolean;
var
  LQuery: TSQLQuery;
  LControla: string;
begin
  Result := False;
  if chkControlaEstoque.Checked then LControla := 'S' else LControla := 'N';

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    if FEstado = efInserindo then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO PRODUTO (EMPRESA_ID, CODIGO, CODIGO_BARRAS, DESCRICAO, DESCRICAO_PDV, ' +
        'NCM, CEST, CFOP_VENDA, PRECO_CUSTO, PRECO_VENDA, MARGEM_LUCRO, ' +
        'ESTOQUE_MINIMO, ESTOQUE_MAXIMO, CONTROLA_ESTOQUE, ATIVO, OBSERVACOES, GRADE_ID) ' +
        'VALUES (:EMP, :COD, :BAR, :DESC, :PDV, :NCM, :CEST, :CFOP, ' +
        ':CUSTO, :VENDA, :MARGEM, :MIN, :MAX, :CTRL, :ATIVO, :OBS, :GRADE)';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE PRODUTO SET CODIGO = :COD, CODIGO_BARRAS = :BAR, DESCRICAO = :DESC, ' +
        'DESCRICAO_PDV = :PDV, NCM = :NCM, CEST = :CEST, CFOP_VENDA = :CFOP, ' +
        'PRECO_CUSTO = :CUSTO, PRECO_VENDA = :VENDA, MARGEM_LUCRO = :MARGEM, ' +
        'ESTOQUE_MINIMO = :MIN, ESTOQUE_MAXIMO = :MAX, CONTROLA_ESTOQUE = :CTRL, ' +
        'ATIVO = :ATIVO, OBSERVACOES = :OBS, GRADE_ID = :GRADE WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    end;

    LQuery.ParamByName('COD').AsString := edtCodigo.Text;
    LQuery.ParamByName('BAR').AsString := edtCodigoBarras.Text;
    LQuery.ParamByName('DESC').AsString := edtDescricao.Text;
    LQuery.ParamByName('PDV').AsString := edtDescricaoPDV.Text;
    LQuery.ParamByName('NCM').AsString := edtNcm.Text;
    LQuery.ParamByName('CEST').AsString := edtCest.Text;
    LQuery.ParamByName('CFOP').AsString := edtCfopVenda.Text;
    LQuery.ParamByName('CUSTO').AsFloat := StrToFloatDef(edtPrecoCusto.Text, 0);
    LQuery.ParamByName('VENDA').AsFloat := StrToFloatDef(edtPrecoVenda.Text, 0);
    LQuery.ParamByName('MARGEM').AsFloat := StrToFloatDef(edtMargemLucro.Text, 0);
    LQuery.ParamByName('MIN').AsFloat := StrToFloatDef(edtEstoqueMin.Text, 0);
    LQuery.ParamByName('MAX').AsFloat := StrToFloatDef(edtEstoqueMax.Text, 0);
    LQuery.ParamByName('CTRL').AsString := LControla;
    LQuery.ParamByName('OBS').AsString := mmoObservacoes.Text;

    if cmbStatus.ItemIndex = 0 then
      LQuery.ParamByName('ATIVO').AsString := 'A'
    else
      LQuery.ParamByName('ATIVO').AsString := 'I';

    { grade padrao do produto (usada para preencher a grade no pedido) }
    if (cmbGrade.ItemIndex > 0) and
       (cmbGrade.Items.Objects[cmbGrade.ItemIndex] <> nil) then
      LQuery.ParamByName('GRADE').AsLargeInt :=
        PtrInt(cmbGrade.Items.Objects[cmbGrade.ItemIndex])
    else
      LQuery.ParamByName('GRADE').Clear;

    LQuery.ExecSQL;
    FConexao.Confirmar;
    Result := True;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

function TfrmProdutos.Excluir: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text := 'DELETE FROM PRODUTO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.ExecSQL;
    FConexao.Confirmar;
    Result := True;
  except
    on E: Exception do
    begin
      FConexao.Cancelar;
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  LQuery.Free;
end;

end.
