unit uFrmEstado;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Estado
  CRUD do cadastro geográfico ESTADO (global, sem empresa).
  Colunas reais: PAIS_ID, NOME, UF, CODIGO_IBGE.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uEstadoService, uEstado;

type
  { TfrmEstado }
  TfrmEstado = class(TfrmCadastroBase)
    lblPais: TLabel;
    cmbPais: TComboBox;
    lblNome: TLabel;
    edtNome: TEdit;
    lblUf: TLabel;
    edtUf: TEdit;
    lblIbge: TLabel;
    edtIbge: TEdit;
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
    FService: TEstadoService;
    destructor Destroy; override;
    procedure ConfigurarGrid;
    procedure CarregarPaises;
    function IdPaisSelecionado: Int64;
    procedure SelecionarPais(AId: Int64);
  end;

var
  frmEstado: TfrmEstado;

implementation

{$R *.lfm}

{ TfrmEstado }

destructor TfrmEstado.Destroy;
begin
  FreeAndNil(FService);
  inherited Destroy;
end;

procedure TfrmEstado.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;
    FService := TEstadoService.Create;

    lblTitulo.Caption := 'Cadastro de Estados';
    Caption := 'Estados';
    ConfigurarGrid;
    CarregarPaises;

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

procedure TfrmEstado.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'UF'; FieldName := 'UF'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Nome'; FieldName := 'NOME'; Width := 220; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'País'; FieldName := 'PAIS_NOME'; Width := 150; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'IBGE'; FieldName := 'CODIGO_IBGE'; Width := 70; end;
end;

procedure TfrmEstado.CarregarPaises;
var
  LQuery: TSQLQuery;
begin
  cmbPais.Items.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, NOME FROM PAIS ORDER BY NOME';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbPais.Items.AddObject(LQuery.FieldByName('NOME').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TfrmEstado.IdPaisSelecionado: Int64;
begin
  Result := 0;
  if (cmbPais.ItemIndex >= 0) and (cmbPais.Items.Objects[cmbPais.ItemIndex] <> nil) then
    Result := Int64(PtrInt(cmbPais.Items.Objects[cmbPais.ItemIndex]));
end;

procedure TfrmEstado.SelecionarPais(AId: Int64);
var
  LIdx: Integer;
begin
  cmbPais.ItemIndex := -1;
  for LIdx := 0 to cmbPais.Items.Count - 1 do
    if (cmbPais.Items.Objects[LIdx] <> nil) and
       (Int64(PtrInt(cmbPais.Items.Objects[LIdx])) = AId) then
    begin
      cmbPais.ItemIndex := LIdx;
      Break;
    end;
end;

procedure TfrmEstado.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL :=
    'SELECT E.ID, E.PAIS_ID, E.NOME, E.UF, E.CODIGO_IBGE, E.ATIVO, ' +
    '  P.NOME AS PAIS_NOME ' +
    'FROM ESTADO E JOIN PAIS P ON P.ID = E.PAIS_ID';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(E.NOME) CONTAINING UPPER(:FILTRO) ' +
      'OR UPPER(E.UF) CONTAINING UPPER(:FILTRO2)';
  LSQL := LSQL + ' ORDER BY E.UF';

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

procedure TfrmEstado.HabilitarCampos(AHabilitar: Boolean);
begin
  cmbPais.Enabled := AHabilitar;
  edtNome.Enabled := AHabilitar;
  edtUf.Enabled := AHabilitar;
  edtIbge.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
end;

procedure TfrmEstado.LimparCampos;
begin
  cmbPais.ItemIndex := -1;
  edtNome.Clear;
  edtUf.Clear;
  edtIbge.Clear;
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmEstado.PreencherCampos;
begin
  if DataSource1.DataSet.Active and (not DataSource1.DataSet.IsEmpty) then
  begin
    SelecionarPais(DataSource1.DataSet.FieldByName('PAIS_ID').AsLargeInt);
    edtNome.Text := DataSource1.DataSet.FieldByName('NOME').AsString;
    edtUf.Text := DataSource1.DataSet.FieldByName('UF').AsString;
    edtIbge.Text := DataSource1.DataSet.FieldByName('CODIGO_IBGE').AsString;
    if DataSource1.DataSet.FieldByName('ATIVO').AsString = 'A' then
      cmbStatus.ItemIndex := 0
    else
      cmbStatus.ItemIndex := 1;
  end;
end;

procedure TfrmEstado.PreencherObjeto;
begin
  { lido direto no Salvar }
end;

function TfrmEstado.Validar: Boolean;
begin
  Result := False;
  if IdPaisSelecionado <= 0 then
  begin
    MessageDlg('Selecione o País.', mtWarning, [mbOK], 0);
    cmbPais.SetFocus;
    Exit;
  end;
  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('O campo Nome é obrigatório.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;
  if Length(Trim(edtUf.Text)) <> 2 then
  begin
    MessageDlg('A UF deve ter 2 caracteres.', mtWarning, [mbOK], 0);
    edtUf.SetFocus;
    Exit;
  end;
  Result := True;
end;

function TfrmEstado.Salvar: Boolean;
var
  LEstado: TEstado;
begin
  Result := False;
  LEstado := TEstado.Create;
  try
    if FEstado = efInserindo then
      LEstado.Id := 0
    else
      LEstado.Id := FIdSelecionado;
    LEstado.PaisId := IdPaisSelecionado;
    LEstado.Nome := Trim(edtNome.Text);
    LEstado.Uf := Trim(UpperCase(edtUf.Text));
    LEstado.CodigoIbge := Trim(edtIbge.Text);
    if cmbStatus.ItemIndex = 0 then
      LEstado.Ativo := 'A'
    else
      LEstado.Ativo := 'I';

    if LEstado.Id = 0 then
      LEstado.Id := FService.Inserir(LEstado)
    else
      FService.Atualizar(LEstado);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
  LEstado.Free;
end;

function TfrmEstado.Excluir: Boolean;
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
