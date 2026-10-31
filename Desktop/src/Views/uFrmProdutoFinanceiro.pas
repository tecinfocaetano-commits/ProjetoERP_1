unit uFrmProdutoFinanceiro;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Produto Financeiro
  Descrição: CRUD de produtos financeiros (serviço/outros)
             usados na nota e no financeiro.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao;

type
  { TfrmProdutoFinanceiro }
  TfrmProdutoFinanceiro = class(TfrmCadastroBase)
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    lblTipo: TLabel;
    cmbTipo: TComboBox;
    lblValor: TLabel;
    edtValor: TEdit;
    lblProdutoFiscal: TLabel;
    cmbProdutoFiscal: TComboBox;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    lblObservacoes: TLabel;
    mmoObservacoes: TMemo;
    procedure FormCreate(Sender: TObject);
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
    procedure ConfigurarGrid;
    procedure CarregarProdutosFiscais;
    function IdDoItemSelecionado(ACombo: TComboBox): Int64;
    procedure SelecionarItemPorId(ACombo: TComboBox; AId: Int64);
  end;

var
  frmProdutoFinanceiro: TfrmProdutoFinanceiro;

implementation

{$R *.lfm}

{ TfrmProdutoFinanceiro }

procedure TfrmProdutoFinanceiro.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Cadastro de Produtos Financeiros';
    Caption := 'Produtos Financeiros';
    ConfigurarGrid;
    CarregarProdutosFiscais;

    cmbTipo.Items.Clear;
    cmbTipo.Items.Add('Serviço');
    cmbTipo.Items.Add('Outros');
    cmbTipo.ItemIndex := 0;

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

procedure TfrmProdutoFinanceiro.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Código'; FieldName := 'CODIGO'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 280; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Tipo'; FieldName := 'TIPO'; Width := 60; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Valor'; FieldName := 'VALOR'; Width := 90; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Ativo'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmProdutoFinanceiro.CarregarProdutosFiscais;
var
  LQuery: TSQLQuery;
begin
  cmbProdutoFiscal.Items.Clear;
  cmbProdutoFiscal.Items.AddObject('', TObject(PtrInt(0)));
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, DESCRICAO FROM PRODUTO_FISCAL WHERE ATIVO = ''A'' ORDER BY DESCRICAO';
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

function TfrmProdutoFinanceiro.IdDoItemSelecionado(ACombo: TComboBox): Int64;
begin
  Result := 0;
  if (ACombo.ItemIndex >= 0) and (ACombo.Items.Objects[ACombo.ItemIndex] <> nil) then
    Result := Int64(PtrInt(ACombo.Items.Objects[ACombo.ItemIndex]));
end;

procedure TfrmProdutoFinanceiro.SelecionarItemPorId(ACombo: TComboBox; AId: Int64);
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

procedure TfrmProdutoFinanceiro.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, CODIGO, DESCRICAO, TIPO, VALOR, ATIVO FROM PRODUTO_FINANCEIRO';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(DESCRICAO) CONTAINING UPPER(:FILTRO) OR CODIGO CONTAINING :FILTRO2';
  LSQL := LSQL + ' ORDER BY DESCRICAO';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  if AFiltro <> '' then
  begin
    FQuery.ParamByName('FILTRO').AsString := AFiltro;
    FQuery.ParamByName('FILTRO2').AsString := AFiltro;
  end;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmProdutoFinanceiro.HabilitarCampos(AHabilitar: Boolean);
begin
  edtCodigo.Enabled := AHabilitar;
  edtDescricao.Enabled := AHabilitar;
  cmbTipo.Enabled := AHabilitar;
  edtValor.Enabled := AHabilitar;
  cmbProdutoFiscal.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
  mmoObservacoes.Enabled := AHabilitar;
end;

procedure TfrmProdutoFinanceiro.LimparCampos;
begin
  edtCodigo.Clear;
  edtDescricao.Clear;
  cmbTipo.ItemIndex := 0;
  edtValor.Text := '0,00';
  cmbProdutoFiscal.ItemIndex := 0;
  cmbStatus.ItemIndex := 0;
  mmoObservacoes.Clear;
end;

procedure TfrmProdutoFinanceiro.PreencherCampos;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM PRODUTO_FINANCEIRO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      edtCodigo.Text := LQuery.FieldByName('CODIGO').AsString;
      edtDescricao.Text := LQuery.FieldByName('DESCRICAO').AsString;
      if LQuery.FieldByName('TIPO').AsString = 'S' then
        cmbTipo.ItemIndex := 0
      else
        cmbTipo.ItemIndex := 1;
      edtValor.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR').AsFloat);
      SelecionarItemPorId(cmbProdutoFiscal, LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt);

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

procedure TfrmProdutoFinanceiro.PreencherObjeto;
begin
  // montado direto no Salvar
end;

function TfrmProdutoFinanceiro.Validar: Boolean;
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

function TfrmProdutoFinanceiro.Salvar: Boolean;
var
  LQuery: TSQLQuery;
  LTipo: string;
begin
  Result := False;
  if cmbTipo.ItemIndex = 0 then LTipo := 'S' else LTipo := 'O';

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    if FEstado = efInserindo then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO PRODUTO_FINANCEIRO (EMPRESA_ID, PRODUTO_FISCAL_ID, CODIGO, ' +
        'DESCRICAO, TIPO, VALOR, ATIVO, OBSERVACOES) ' +
        'VALUES (:EMP, :PFISCAL, :COD, :DESC, :TIPO, :VALOR, :ATIVO, :OBS)';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE PRODUTO_FINANCEIRO SET PRODUTO_FISCAL_ID = :PFISCAL, CODIGO = :COD, ' +
        'DESCRICAO = :DESC, TIPO = :TIPO, VALOR = :VALOR, ATIVO = :ATIVO, ' +
        'OBSERVACOES = :OBS WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    end;

    LQuery.ParamByName('PFISCAL').AsLargeInt := IdDoItemSelecionado(cmbProdutoFiscal);
    LQuery.ParamByName('COD').AsString := edtCodigo.Text;
    LQuery.ParamByName('DESC').AsString := edtDescricao.Text;
    LQuery.ParamByName('TIPO').AsString := LTipo;
    LQuery.ParamByName('VALOR').AsFloat := StrToFloatDef(edtValor.Text, 0);
    LQuery.ParamByName('OBS').AsString := mmoObservacoes.Text;

    if cmbStatus.ItemIndex = 0 then
      LQuery.ParamByName('ATIVO').AsString := 'A'
    else
      LQuery.ParamByName('ATIVO').AsString := 'I';

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

function TfrmProdutoFinanceiro.Excluir: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text := 'DELETE FROM PRODUTO_FINANCEIRO WHERE ID = :ID';
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
