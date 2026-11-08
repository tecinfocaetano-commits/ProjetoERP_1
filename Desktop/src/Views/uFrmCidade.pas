unit uFrmCidade;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 1 (redesenho) - Formulário: Cidade
  CRUD do cadastro geográfico CIDADE (global, sem empresa).
  Colunas reais: ESTADO_ID, NOME, CODIGO_IBGE, CEP_PADRAO.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uCidadeService, uCidade;

type
  { TfrmCidade }
  TfrmCidade = class(TfrmCadastroBase)
    lblEstado: TLabel;
    cmbEstado: TComboBox;
    lblNome: TLabel;
    edtNome: TEdit;
    lblIbge: TLabel;
    edtIbge: TEdit;
    lblCep: TLabel;
    edtCep: TEdit;
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
    FService: TCidadeService;
    destructor Destroy; override;
    procedure ConfigurarGrid;
    procedure CarregarEstados;
    function IdEstadoSelecionado: Int64;
    procedure SelecionarEstado(AId: Int64);
  end;

var
  frmCidade: TfrmCidade;

implementation

{$R *.lfm}

{ TfrmCidade }

destructor TfrmCidade.Destroy;
begin
  FreeAndNil(FService);
  inherited Destroy;
end;

procedure TfrmCidade.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;
    FService := TCidadeService.Create;

    lblTitulo.Caption := 'Cadastro de Cidades';
    Caption := 'Cidades';
    ConfigurarGrid;
    CarregarEstados;

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

procedure TfrmCidade.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Cidade'; FieldName := 'NOME'; Width := 250; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'UF'; FieldName := 'UF'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'IBGE'; FieldName := 'CODIGO_IBGE'; Width := 70; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'CEP'; FieldName := 'CEP_PADRAO'; Width := 80; end;
end;

procedure TfrmCidade.CarregarEstados;
var
  LQuery: TSQLQuery;
begin
  cmbEstado.Items.Clear;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, UF, NOME FROM ESTADO ORDER BY UF';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbEstado.Items.AddObject(
        Trim(LQuery.FieldByName('UF').AsString) + ' - ' +
        LQuery.FieldByName('NOME').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TfrmCidade.IdEstadoSelecionado: Int64;
begin
  Result := 0;
  if (cmbEstado.ItemIndex >= 0) and (cmbEstado.Items.Objects[cmbEstado.ItemIndex] <> nil) then
    Result := Int64(PtrInt(cmbEstado.Items.Objects[cmbEstado.ItemIndex]));
end;

procedure TfrmCidade.SelecionarEstado(AId: Int64);
var
  LIdx: Integer;
begin
  cmbEstado.ItemIndex := -1;
  for LIdx := 0 to cmbEstado.Items.Count - 1 do
    if (cmbEstado.Items.Objects[LIdx] <> nil) and
       (Int64(PtrInt(cmbEstado.Items.Objects[LIdx])) = AId) then
    begin
      cmbEstado.ItemIndex := LIdx;
      Break;
    end;
end;

procedure TfrmCidade.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL :=
    'SELECT C.ID, C.ESTADO_ID, C.NOME, C.CODIGO_IBGE, C.CEP_PADRAO, C.ATIVO, E.UF ' +
    'FROM CIDADE C JOIN ESTADO E ON E.ID = C.ESTADO_ID';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(C.NOME) CONTAINING UPPER(:FILTRO)';
  LSQL := LSQL + ' ORDER BY E.UF, C.NOME';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  if AFiltro <> '' then
    FQuery.ParamByName('FILTRO').AsString := AFiltro;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmCidade.HabilitarCampos(AHabilitar: Boolean);
begin
  cmbEstado.Enabled := AHabilitar;
  edtNome.Enabled := AHabilitar;
  edtIbge.Enabled := AHabilitar;
  edtCep.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
end;

procedure TfrmCidade.LimparCampos;
begin
  cmbEstado.ItemIndex := -1;
  edtNome.Clear;
  edtIbge.Clear;
  edtCep.Clear;
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmCidade.PreencherCampos;
begin
  if DataSource1.DataSet.Active and (not DataSource1.DataSet.IsEmpty) then
  begin
    SelecionarEstado(DataSource1.DataSet.FieldByName('ESTADO_ID').AsLargeInt);
    edtNome.Text := DataSource1.DataSet.FieldByName('NOME').AsString;
    edtIbge.Text := DataSource1.DataSet.FieldByName('CODIGO_IBGE').AsString;
    edtCep.Text := DataSource1.DataSet.FieldByName('CEP_PADRAO').AsString;
    if DataSource1.DataSet.FieldByName('ATIVO').AsString = 'A' then
      cmbStatus.ItemIndex := 0
    else
      cmbStatus.ItemIndex := 1;
  end;
end;

procedure TfrmCidade.PreencherObjeto;
begin
  { lido direto no Salvar }
end;

function TfrmCidade.Validar: Boolean;
begin
  Result := False;
  if IdEstadoSelecionado <= 0 then
  begin
    MessageDlg('Selecione o Estado.', mtWarning, [mbOK], 0);
    cmbEstado.SetFocus;
    Exit;
  end;
  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('O campo Nome é obrigatório.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;
  Result := True;
end;

function TfrmCidade.Salvar: Boolean;
var
  LCidade: TCidade;
begin
  Result := False;
  LCidade := TCidade.Create;
  try
    if FEstado = efInserindo then
      LCidade.Id := 0
    else
      LCidade.Id := FIdSelecionado;
    LCidade.EstadoId := IdEstadoSelecionado;
    LCidade.Nome := Trim(edtNome.Text);
    LCidade.CodigoIbge := Trim(edtIbge.Text);
    LCidade.CepPadrao := Trim(edtCep.Text);
    if cmbStatus.ItemIndex = 0 then
      LCidade.Ativo := 'A'
    else
      LCidade.Ativo := 'I';

    if LCidade.Id = 0 then
      LCidade.Id := FService.Inserir(LCidade)
    else
      FService.Atualizar(LCidade);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
  LCidade.Free;
end;

function TfrmCidade.Excluir: Boolean;
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
