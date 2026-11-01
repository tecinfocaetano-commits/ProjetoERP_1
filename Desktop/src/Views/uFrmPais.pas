unit uFrmPais;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: País
  CRUD do cadastro geográfico PAIS (global, sem empresa).
  Colunas reais: NOME, CODIGO (ISO ex. BRA), DDI (ex. 55).
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao;

type
  { TfrmPais }
  TfrmPais = class(TfrmCadastroBase)
    lblNome: TLabel;
    edtNome: TEdit;
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblDdi: TLabel;
    edtDdi: TEdit;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
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
  frmPais: TfrmPais;

implementation

{$R *.lfm}

{ TfrmPais }

procedure TfrmPais.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    lblTitulo.Caption := 'Cadastro de Países';
    Caption := 'Países';
    ConfigurarGrid;

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

procedure TfrmPais.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Nome'; FieldName := 'NOME'; Width := 250; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Código'; FieldName := 'CODIGO'; Width := 80; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'DDI'; FieldName := 'DDI'; Width := 60; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Ativo'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmPais.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, NOME, CODIGO, DDI, ATIVO FROM PAIS';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(NOME) CONTAINING UPPER(:FILTRO) ' +
      'OR UPPER(CODIGO) CONTAINING UPPER(:FILTRO2)';
  LSQL := LSQL + ' ORDER BY NOME';

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

procedure TfrmPais.HabilitarCampos(AHabilitar: Boolean);
begin
  edtNome.Enabled := AHabilitar;
  edtCodigo.Enabled := AHabilitar;
  edtDdi.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
end;

procedure TfrmPais.LimparCampos;
begin
  edtNome.Clear;
  edtCodigo.Clear;
  edtDdi.Clear;
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmPais.PreencherCampos;
begin
  if DataSource1.DataSet.Active and (not DataSource1.DataSet.IsEmpty) then
  begin
    edtNome.Text := DataSource1.DataSet.FieldByName('NOME').AsString;
    edtCodigo.Text := DataSource1.DataSet.FieldByName('CODIGO').AsString;
    edtDdi.Text := DataSource1.DataSet.FieldByName('DDI').AsString;
    if DataSource1.DataSet.FieldByName('ATIVO').AsString = 'A' then
      cmbStatus.ItemIndex := 0
    else
      cmbStatus.ItemIndex := 1;
  end;
end;

procedure TfrmPais.PreencherObjeto;
begin
  { campos lidos direto no Salvar (padrão uFrmMaterial) }
end;

function TfrmPais.Validar: Boolean;
begin
  Result := False;
  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('O campo Nome é obrigatório.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;
  if Trim(edtCodigo.Text) = '' then
  begin
    MessageDlg('O campo Código é obrigatório (ex.: BRA).', mtWarning, [mbOK], 0);
    edtCodigo.SetFocus;
    Exit;
  end;
  Result := True;
end;

function TfrmPais.Salvar: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    if FEstado = efInserindo then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO PAIS (NOME, CODIGO, DDI, ATIVO) ' +
        'VALUES (:NOME, :CODIGO, :DDI, :ATIVO)';
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE PAIS SET NOME = :NOME, CODIGO = :CODIGO, DDI = :DDI, ' +
        'ATIVO = :ATIVO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    end;

    LQuery.ParamByName('NOME').AsString := Trim(edtNome.Text);
    LQuery.ParamByName('CODIGO').AsString := Trim(UpperCase(edtCodigo.Text));
    LQuery.ParamByName('DDI').AsString := Trim(edtDdi.Text);
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

function TfrmPais.Excluir: Boolean;
var
  LQuery: TSQLQuery;
  LUsos: Int64;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;

    { não deixa excluir país com estados (referência lógica) }
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM ESTADO WHERE PAIS_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;
    LUsos := LQuery.Fields[0].AsLargeInt;
    LQuery.Close;
    if LUsos > 0 then
    begin
      MessageDlg('Este país possui estados vinculados e não pode ser excluído.',
        mtWarning, [mbOK], 0);
      Exit;
    end;

    FConexao.IniciarTransacao;
    LQuery.SQL.Text := 'DELETE FROM PAIS WHERE ID = :ID';
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
