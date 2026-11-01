unit uFrmGrade;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Fase 2 - Formulário: Grade
  Cadastro da GRADE (tabela principal) + sub-tabela de tamanhos
  (número de tamanhos variável: calçado / confecção / grupo).
  A regra fica no TGradeService; a tela só monta e valida campos.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls, Grids,
  uFrmCadastroBase, uConexao, uGrade, uGradeService;

type
  { TfrmGrade }
  TfrmGrade = class(TfrmCadastroBase)
    lblNome: TLabel;
    edtNome: TEdit;
    lblTipo: TLabel;
    cmbTipo: TComboBox;
    lblStatus: TLabel;
    cmbStatus: TComboBox;
    lblObservacao: TLabel;
    memObservacao: TMemo;
    lblTamanhos: TLabel;
    sgTamanhos: TStringGrid;
    btnAdicionarTamanho: TBitBtn;
    btnRemoverTamanho: TBitBtn;
    lblDicaTamanhos: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnAdicionarTamanhoClick(Sender: TObject);
    procedure btnRemoverTamanhoClick(Sender: TObject);
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
    FService: TGradeService;
    procedure ConfigurarGrid;
    procedure ConfigurarTamanhosGrid;
    procedure LimparTamanhos;
    procedure CarregarTamanhos(AGradeId: Int64);
    function TamanhosDoGrid: TGradeTamanhos;
    function LinhaSelecionadaTamanho: Integer;
  end;

var
  frmGrade: TfrmGrade;

implementation

{$R *.lfm}

{ TfrmGrade }

procedure TfrmGrade.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TGradeService.Create;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    lblTitulo.Caption := 'Cadastro de Grades';
    Caption := 'Grades';

    ConfigurarGrid;
    ConfigurarTamanhosGrid;

    cmbTipo.Items.Clear;
    cmbTipo.Items.Add(GRADE_TIPOS_DESCRICAO[0]);
    cmbTipo.Items.Add(GRADE_TIPOS_DESCRICAO[1]);
    cmbTipo.Items.Add(GRADE_TIPOS_DESCRICAO[2]);
    cmbTipo.Items.Add(GRADE_TIPOS_DESCRICAO[3]);
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

procedure TfrmGrade.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FService);
end;

procedure TfrmGrade.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Nome'; FieldName := 'NOME'; Width := 280; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Tipo'; FieldName := 'TIPO'; Width := 110; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Ativo'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmGrade.ConfigurarTamanhosGrid;
begin
  sgTamanhos.ColCount := 2;
  sgTamanhos.FixedCols := 0;
  sgTamanhos.FixedRows := 1;
  sgTamanhos.RowCount := 2;
  sgTamanhos.DefaultRowHeight := 22;
  sgTamanhos.Options := [goFixedVertLine, goFixedHorzLine, goVertLine,
    goHorzLine, goEditing, goTabs, goThumbTracking];
  sgTamanhos.ColWidths[0] := 130;
  sgTamanhos.ColWidths[1] := 90;
  sgTamanhos.Cells[0, 0] := 'Tamanho';
  sgTamanhos.Cells[1, 0] := 'Ativo (A/I)';
  LimparTamanhos;
end;

procedure TfrmGrade.LimparTamanhos;
var
  I: Integer;
begin
  sgTamanhos.RowCount := 2;
  for I := 1 to sgTamanhos.RowCount - 1 do
  begin
    sgTamanhos.Cells[0, I] := '';
    sgTamanhos.Cells[1, I] := 'A';
  end;
end;

procedure TfrmGrade.CarregarTamanhos(AGradeId: Int64);
var
  LTamanhos: TGradeTamanhos;
  I: Integer;
begin
  LimparTamanhos;
  if AGradeId <= 0 then
    Exit;

  LTamanhos := FService.ListarTamanhos(AGradeId);
  if Length(LTamanhos) = 0 then
    Exit;

  sgTamanhos.RowCount := Length(LTamanhos) + 1;
  for I := 0 to High(LTamanhos) do
  begin
    sgTamanhos.Cells[0, I + 1] := LTamanhos[I].Tamanho;
    if LTamanhos[I].Ativo = 'I' then
      sgTamanhos.Cells[1, I + 1] := 'I'
    else
      sgTamanhos.Cells[1, I + 1] := 'A';
  end;
end;

function TfrmGrade.TamanhosDoGrid: TGradeTamanhos;
var
  I: Integer;
  LTam, LAtivo: string;
begin
  Result := nil;
  for I := 1 to sgTamanhos.RowCount - 1 do
  begin
    LTam := Trim(sgTamanhos.Cells[0, I]);
    if LTam = '' then
      Continue;

    LAtivo := UpperCase(Trim(sgTamanhos.Cells[1, I]));
    if LAtivo <> 'I' then
      LAtivo := 'A';

    SetLength(Result, Length(Result) + 1);
    with Result[High(Result)] do
    begin
      Id := 0;
      Tamanho := LTam;
      Ordem := Length(Result) - 1;
      Quantidade := 0;
      Ativo := LAtivo;
    end;
  end;
end;

function TfrmGrade.LinhaSelecionadaTamanho: Integer;
begin
  Result := sgTamanhos.Row;
  if Result < 1 then
    Result := 1;
  if Result > sgTamanhos.RowCount - 1 then
    Result := sgTamanhos.RowCount - 1;
end;

procedure TfrmGrade.btnAdicionarTamanhoClick(Sender: TObject);
var
  LNova: Integer;
begin
  LNova := sgTamanhos.RowCount;
  sgTamanhos.RowCount := LNova + 1;
  sgTamanhos.Cells[0, LNova] := '';
  sgTamanhos.Cells[1, LNova] := 'A';
  sgTamanhos.Row := LNova;
  sgTamanhos.Col := 0;
  sgTamanhos.SetFocus;
end;

procedure TfrmGrade.btnRemoverTamanhoClick(Sender: TObject);
var
  L, I: Integer;
begin
  L := LinhaSelecionadaTamanho;
  if sgTamanhos.RowCount <= 2 then
  begin
    { mantém sempre uma linha editável }
    sgTamanhos.Cells[0, 1] := '';
    sgTamanhos.Cells[1, 1] := 'A';
    Exit;
  end;

  for I := L to sgTamanhos.RowCount - 2 do
  begin
    sgTamanhos.Cells[0, I] := sgTamanhos.Cells[0, I + 1];
    sgTamanhos.Cells[1, I] := sgTamanhos.Cells[1, I + 1];
  end;
  sgTamanhos.RowCount := sgTamanhos.RowCount - 1;
end;

procedure TfrmGrade.CarregarDados(const AFiltro: string);
begin
  FService.Carregar(FQuery, AFiltro);
  DataSource1.DataSet := FQuery;
end;

procedure TfrmGrade.HabilitarCampos(AHabilitar: Boolean);
begin
  edtNome.Enabled := AHabilitar;
  cmbTipo.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
  memObservacao.Enabled := AHabilitar;
  sgTamanhos.Enabled := AHabilitar;
  btnAdicionarTamanho.Enabled := AHabilitar;
  btnRemoverTamanho.Enabled := AHabilitar;
end;

procedure TfrmGrade.LimparCampos;
begin
  edtNome.Clear;
  cmbTipo.ItemIndex := 0;
  cmbStatus.ItemIndex := 0;
  memObservacao.Clear;
  LimparTamanhos;
end;

procedure TfrmGrade.PreencherCampos;
begin
  if DataSource1.DataSet.Active and (not DataSource1.DataSet.IsEmpty) then
  begin
    edtNome.Text := DataSource1.DataSet.FieldByName('NOME').AsString;
    cmbTipo.ItemIndex := IndiceTipoGrade(
      Trim(DataSource1.DataSet.FieldByName('TIPO').AsString));
    if DataSource1.DataSet.FieldByName('ATIVO').AsString = 'A' then
      cmbStatus.ItemIndex := 0
    else
      cmbStatus.ItemIndex := 1;
    CarregarTamanhos(FIdSelecionado);
  end;
end;

procedure TfrmGrade.PreencherObjeto;
begin
  { o objeto TGrade é montado direto no Salvar (padrão dos CRUDs) }
end;

function TfrmGrade.Validar: Boolean;
var
  LTamanhos: TGradeTamanhos;
  LLista: TStringList;
  I: Integer;
begin
  Result := False;

  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('O campo Nome é obrigatório.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;
  if Length(Trim(edtNome.Text)) > 60 then
  begin
    MessageDlg('O Nome pode ter no máximo 60 caracteres.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;
  if Length(Trim(memObservacao.Text)) > 255 then
  begin
    MessageDlg('A Observação pode ter no máximo 255 caracteres.',
      mtWarning, [mbOK], 0);
    memObservacao.SetFocus;
    Exit;
  end;

  LTamanhos := TamanhosDoGrid;
  if Length(LTamanhos) = 0 then
  begin
    MessageDlg('Informe pelo menos um tamanho na grade.',
      mtWarning, [mbOK], 0);
    sgTamanhos.SetFocus;
    Exit;
  end;

  LLista := TStringList.Create;
  try
    LLista.CaseSensitive := False;
    LLista.Sorted := True;
    for I := 0 to High(LTamanhos) do
    begin
      if LLista.IndexOf(LTamanhos[I].Tamanho) >= 0 then
      begin
        MessageDlg(Format('O tamanho "%s" está repetido na grade.',
          [LTamanhos[I].Tamanho]), mtWarning, [mbOK], 0);
        sgTamanhos.Row := I + 1;
        sgTamanhos.SetFocus;
        Exit;
      end;
      LLista.Add(LTamanhos[I].Tamanho);
    end;
  finally
    LLista.Free;
  end;

  Result := True;
end;

function TfrmGrade.Salvar: Boolean;
var
  LGrade: TGrade;
begin
  Result := False;
  LGrade := TGrade.Create;
  try
    LGrade.Id := FIdSelecionado;
    LGrade.Nome := Trim(edtNome.Text);
    LGrade.Tipo := TipoGradePorIndice(cmbTipo.ItemIndex);
    if cmbStatus.ItemIndex = 1 then
      LGrade.Ativo := 'I'
    else
      LGrade.Ativo := 'A';
    LGrade.Observacao := Trim(memObservacao.Text);
    LGrade.Tamanhos := TamanhosDoGrid;

    try
      if FEstado = efInserindo then
      begin
        FService.Inserir(LGrade);
        Result := True;
      end
      else
        Result := FService.Atualizar(LGrade);
    except
      on E: Exception do
        MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    LGrade.Free;
  end;
end;

function TfrmGrade.Excluir: Boolean;
begin
  Result := False;
  try
    Result := FService.Excluir(FIdSelecionado);
  except
    on E: Exception do
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
