unit uFrmMovimentoFinanceiro;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Movimentação
  Financeira
  Descrição: CRUD da movimentação financeira (separada do
             Caixa). Entradas/saídas por categoria.

  A tela apenas coleta os dados e delega as regras ao
  TMovimentoFinanceiroService (validação, transação, escopo da
  empresa e auditoria).
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao, uMovimentoFinanceiroService;

type
  { TfrmMovimentoFinanceiro }
  TfrmMovimentoFinanceiro = class(TfrmCadastroBase)
    lblData: TLabel;
    edtData: TEdit;
    lblTipo: TLabel;
    cmbTipo: TComboBox;
    lblCategoria: TLabel;
    cmbCategoria: TComboBox;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    lblValor: TLabel;
    edtValor: TEdit;
    lblDocumento: TLabel;
    edtDocumento: TEdit;
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
    FService: TMovimentoFinanceiroService;
    procedure ConfigurarGrid;
    function MontarDados: TMovimentoFinanceiroDados;
    procedure SelecionarTipo(ATipo: Char);
    procedure SelecionarCategoria(const ACategoria: string);
  end;

var
  frmMovimentoFinanceiro: TfrmMovimentoFinanceiro;

implementation

{$R *.lfm}

{ TfrmMovimentoFinanceiro }

procedure TfrmMovimentoFinanceiro.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TMovimentoFinanceiroService.Create;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Movimentação Financeira';
    Caption := 'Movimentação Financeira';
    ConfigurarGrid;

    FService.CarregarTipos(cmbTipo.Items);
    cmbTipo.ItemIndex := 0;

    // categoria é sugestão (editável)
    FService.CarregarCategorias(cmbCategoria.Items);
    cmbCategoria.ItemIndex := 0;

    FEstado := efNavegando;
    Position := poScreenCenter;
    BorderStyle := bsSizeable;
    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

destructor TfrmMovimentoFinanceiro.Destroy;
begin
  FService.Free;
  inherited Destroy;
end;

procedure TfrmMovimentoFinanceiro.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Data'; FieldName := 'DATA_MOVIMENTO'; Width := 90; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Tipo'; FieldName := 'TIPO'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Categoria'; FieldName := 'CATEGORIA'; Width := 130; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 260; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Valor'; FieldName := 'VALOR'; Width := 100; end;
end;

procedure TfrmMovimentoFinanceiro.CarregarDados(const AFiltro: string);
begin
  FService.CarregarMovimentos(FQuery, AFiltro);
  DataSource1.DataSet := FQuery;
end;

procedure TfrmMovimentoFinanceiro.HabilitarCampos(AHabilitar: Boolean);
begin
  edtData.Enabled := AHabilitar;
  cmbTipo.Enabled := AHabilitar;
  cmbCategoria.Enabled := AHabilitar;
  edtDescricao.Enabled := AHabilitar;
  edtValor.Enabled := AHabilitar;
  edtDocumento.Enabled := AHabilitar;
end;

procedure TfrmMovimentoFinanceiro.LimparCampos;
begin
  edtData.Text := FormatDateTime('dd/mm/yyyy', Now);
  cmbTipo.ItemIndex := 0;
  cmbCategoria.ItemIndex := 0;
  edtDescricao.Clear;
  edtValor.Text := '0,00';
  edtDocumento.Clear;
end;

procedure TfrmMovimentoFinanceiro.SelecionarTipo(ATipo: Char);
var
  LIdx: Integer;
begin
  for LIdx := 0 to cmbTipo.Items.Count - 1 do
    if (cmbTipo.Items.Objects[LIdx] <> nil) and
       (Chr(PtrInt(cmbTipo.Items.Objects[LIdx])) = ATipo) then
    begin
      cmbTipo.ItemIndex := LIdx;
      Exit;
    end;
  cmbTipo.ItemIndex := 0;
end;

procedure TfrmMovimentoFinanceiro.SelecionarCategoria(const ACategoria: string);
var
  LIdx: Integer;
begin
  // categoria pode não estar na lista de sugestões
  cmbCategoria.ItemIndex := -1;
  cmbCategoria.Text := ACategoria;
  for LIdx := 0 to cmbCategoria.Items.Count - 1 do
    if SameText(cmbCategoria.Items[LIdx], ACategoria) then
    begin
      cmbCategoria.ItemIndex := LIdx;
      Break;
    end;
end;

procedure TfrmMovimentoFinanceiro.PreencherCampos;
var
  LDados: TMovimentoFinanceiroDados;
begin
  if not FService.BuscarMovimento(FIdSelecionado, LDados) then
    Exit;

  edtData.Text := FormatDateTime('dd/mm/yyyy', LDados.DataMovimento);
  SelecionarTipo(LDados.Tipo);
  SelecionarCategoria(LDados.Categoria);
  edtDescricao.Text := LDados.Descricao;
  edtValor.Text := FormatFloat('#,##0.00', LDados.Valor);
  if LDados.DocumentoId > 0 then
    edtDocumento.Text := IntToStr(LDados.DocumentoId)
  else
    edtDocumento.Clear;
end;

function TfrmMovimentoFinanceiro.MontarDados: TMovimentoFinanceiroDados;
begin
  Result.Id := FIdSelecionado;
  Result.DataMovimento := StrToDateDef(edtData.Text, 0);
  if (cmbTipo.ItemIndex >= 0) and (cmbTipo.Items.Objects[cmbTipo.ItemIndex] <> nil) then
    Result.Tipo := Chr(PtrInt(cmbTipo.Items.Objects[cmbTipo.ItemIndex]))
  else
    Result.Tipo := 'E';
  Result.Categoria := Trim(cmbCategoria.Text);
  Result.Descricao := edtDescricao.Text;
  Result.Valor := StrToFloatDef(edtValor.Text, 0);
  Result.DocumentoId := StrToInt64Def(Trim(edtDocumento.Text), 0);
end;

procedure TfrmMovimentoFinanceiro.PreencherObjeto;
begin
  // montado em MontarDados no Salvar
end;

function TfrmMovimentoFinanceiro.Validar: Boolean;
begin
  Result := False;

  if Trim(edtDescricao.Text) = '' then
  begin
    MessageDlg('O campo Descrição é obrigatório.', mtWarning, [mbOK], 0);
    edtDescricao.SetFocus;
    Exit;
  end;

  if StrToDateDef(edtData.Text, 0) = 0 then
  begin
    MessageDlg('Informe uma data válida (dd/mm/aaaa).', mtWarning, [mbOK], 0);
    edtData.SetFocus;
    Exit;
  end;

  if StrToFloatDef(edtValor.Text, 0) <= 0 then
  begin
    MessageDlg('O Valor deve ser maior que zero.', mtWarning, [mbOK], 0);
    edtValor.SetFocus;
    Exit;
  end;

  if StrToInt64Def(Trim(edtDocumento.Text), 0) < 0 then
  begin
    MessageDlg('O documento não pode ser negativo.', mtWarning, [mbOK], 0);
    edtDocumento.SetFocus;
    Exit;
  end;

  Result := True;
end;

function TfrmMovimentoFinanceiro.Salvar: Boolean;
var
  LDados: TMovimentoFinanceiroDados;
begin
  Result := False;
  LDados := MontarDados;
  try
    FService.SalvarMovimento(LDados);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

function TfrmMovimentoFinanceiro.Excluir: Boolean;
begin
  Result := False;
  try
    FService.ExcluirMovimento(FIdSelecionado);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
