unit uFrmMovimentoFinanceiro;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Movimentação
  Financeira
  Descrição: CRUD da movimentação financeira (separada do
             Caixa). Entradas/saídas por categoria.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao;

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

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Movimentação Financeira';
    Caption := 'Movimentação Financeira';
    ConfigurarGrid;

    cmbTipo.Items.Clear;
    cmbTipo.Items.Add('Entrada');
    cmbTipo.Items.Add('Saída');
    cmbTipo.ItemIndex := 0;

    // categoria é sugestão (editável)
    cmbCategoria.Items.Clear;
    cmbCategoria.Items.Add('RECEBIMENTO');
    cmbCategoria.Items.Add('PAGAMENTO');
    cmbCategoria.Items.Add('TRANSFERENCIA');
    cmbCategoria.Items.Add('OUTRAS');
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
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, DATA_MOVIMENTO, TIPO, CATEGORIA, DESCRICAO, VALOR ' +
          'FROM MOVIMENTO_FINANCEIRO';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(DESCRICAO) CONTAINING UPPER(:FILTRO) ' +
                   'OR UPPER(CATEGORIA) CONTAINING UPPER(:FILTRO2) ' +
                   'OR DOCUMENTO_ID CONTAINING :FILTRO3';
  LSQL := LSQL + ' ORDER BY DATA_MOVIMENTO DESC, ID DESC';

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

procedure TfrmMovimentoFinanceiro.PreencherCampos;
var
  LQuery: TSQLQuery;
  LIdx: Integer;
  LTipo: string;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      edtData.Text := FormatDateTime('dd/mm/yyyy',
        LQuery.FieldByName('DATA_MOVIMENTO').AsDateTime);

      LTipo := LQuery.FieldByName('TIPO').AsString;
      if LTipo = 'E' then
        cmbTipo.ItemIndex := 0
      else
        cmbTipo.ItemIndex := 1;

      // categoria pode não estar na lista de sugestões
      cmbCategoria.Text := LQuery.FieldByName('CATEGORIA').AsString;
      for LIdx := 0 to cmbCategoria.Items.Count - 1 do
        if SameText(cmbCategoria.Items[LIdx], LQuery.FieldByName('CATEGORIA').AsString) then
        begin
          cmbCategoria.ItemIndex := LIdx;
          Break;
        end;

      edtDescricao.Text := LQuery.FieldByName('DESCRICAO').AsString;
      edtValor.Text := FormatFloat('#,##0.00', LQuery.FieldByName('VALOR').AsFloat);
      edtDocumento.Text := LQuery.FieldByName('DOCUMENTO_ID').AsString;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmMovimentoFinanceiro.PreencherObjeto;
begin
  // montado direto no Salvar
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

  Result := True;
end;

function TfrmMovimentoFinanceiro.Salvar: Boolean;
var
  LQuery: TSQLQuery;
  LTipo: string;
  LDoc: Int64;
begin
  Result := False;
  if cmbTipo.ItemIndex = 0 then LTipo := 'E' else LTipo := 'S';
  LDoc := StrToInt64Def(Trim(edtDocumento.Text), 0);

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    if FEstado = efInserindo then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO MOVIMENTO_FINANCEIRO (EMPRESA_ID, DATA_MOVIMENTO, TIPO, ' +
        'CATEGORIA, DESCRICAO, VALOR, DOCUMENTO_ID, USUARIO_ID) ' +
        'VALUES (:EMP, :DATA, :TIPO, :CAT, :DESC, :VALOR, :DOC, :USER)';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('USER').AsLargeInt := TSessao.GetInstance.UsuarioId;
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE MOVIMENTO_FINANCEIRO SET DATA_MOVIMENTO = :DATA, TIPO = :TIPO, ' +
        'CATEGORIA = :CAT, DESCRICAO = :DESC, VALOR = :VALOR, DOCUMENTO_ID = :DOC ' +
        'WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    end;

    LQuery.ParamByName('DATA').AsDate := StrToDateDef(edtData.Text, Now);
    LQuery.ParamByName('TIPO').AsString := LTipo;
    LQuery.ParamByName('CAT').AsString := Trim(cmbCategoria.Text);
    LQuery.ParamByName('DESC').AsString := edtDescricao.Text;
    LQuery.ParamByName('VALOR').AsFloat := StrToFloatDef(edtValor.Text, 0);
    LQuery.ParamByName('DOC').AsLargeInt := LDoc;

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

function TfrmMovimentoFinanceiro.Excluir: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text := 'DELETE FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
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
