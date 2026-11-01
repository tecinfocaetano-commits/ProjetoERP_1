unit uFrmConfiguracoes;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Sistema > Configurações
  Descrição: edição das chaves da CONFIGURACAO da empresa
  (as mesmas chaves que os módulos leem em tempo de execução).
  A regra de gravação fica no TConfiguracaoService; este form só
  monta a tela e devolve os campos para o service.
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uConfiguracaoService, uGradeService;

type
  { TfrmConfiguracoes }
  TfrmConfiguracoes = class(TfrmCadastroBase)
    lblChave: TLabel;
    edtChave: TEdit;
    lblValor: TLabel;
    edtValor: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    chkUsaGrade: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure chkUsaGradeClick(Sender: TObject);
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
    FService: TConfiguracaoService;
    procedure ConfigurarGrid;
    procedure CarregarUsaGrade;
  end;

var
  frmConfiguracoes: TfrmConfiguracoes;

implementation

{$R *.lfm}

{ TfrmConfiguracoes }

procedure TfrmConfiguracoes.FormCreate(Sender: TObject);
begin
  try
    FConexao := TConexao.GetInstance;
    if not FConexao.Conectado then
      FConexao.Conectar;

    FService := TConfiguracaoService.Create;

    FQuery := TSQLQuery.Create(Self);
    FQuery.DataBase := FConexao.Connection;
    FQuery.Transaction := FConexao.Transaction;

    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Configurações do Sistema';
    Caption := 'Configurações';
    ConfigurarGrid;

    edtChave.MaxLength := 50;
    edtValor.MaxLength := 255;
    edtDescricao.MaxLength := 255;

    FEstado := efNavegando;
    Position := poScreenCenter;
    BorderStyle := bsSizeable;

    CarregarDados;
  except
    on E: Exception do
      MessageDlg('Erro ao inicializar formulário: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmConfiguracoes.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FService);
end;

procedure TfrmConfiguracoes.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Chave'; FieldName := 'CHAVE'; Width := 250; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Valor'; FieldName := 'VALOR'; Width := 160; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 250; end;
end;

procedure TfrmConfiguracoes.CarregarDados(const AFiltro: string);
begin
  FService.Carregar(FQuery, AFiltro);
  DataSource1.DataSet := FQuery;
  CarregarUsaGrade;
end;

procedure TfrmConfiguracoes.CarregarUsaGrade;
var
  LService: TGradeService;
begin
  LService := TGradeService.Create;
  try
    chkUsaGrade.Checked := LService.UsaGrade;
  finally
    LService.Free;
  end;
end;

procedure TfrmConfiguracoes.chkUsaGradeClick(Sender: TObject);
var
  LService: TGradeService;
begin
  LService := TGradeService.Create;
  try
    try
      LService.DefinirUsaGrade(chkUsaGrade.Checked);
      CarregarDados;
    except
      on E: Exception do
      begin
        MessageDlg('Erro ao gravar a preferência USA_GRADE: ' + E.Message,
          mtError, [mbOK], 0);
        CarregarUsaGrade;
      end;
    end;
  finally
    LService.Free;
  end;
end;

procedure TfrmConfiguracoes.HabilitarCampos(AHabilitar: Boolean);
begin
  edtChave.Enabled := AHabilitar;
  edtValor.Enabled := AHabilitar;
  edtDescricao.Enabled := AHabilitar;
end;

procedure TfrmConfiguracoes.LimparCampos;
begin
  edtChave.Clear;
  edtValor.Clear;
  edtDescricao.Clear;
end;

procedure TfrmConfiguracoes.PreencherCampos;
begin
  { a listagem já está aberta: localizar a linha evita SQL no form
    (mesmo registro que a grade está mostrando) }
  if FQuery.Locate('ID', FIdSelecionado, []) then
  begin
    edtChave.Text := FQuery.FieldByName('CHAVE').AsString;
    edtValor.Text := FQuery.FieldByName('VALOR').AsString;
    edtDescricao.Text := FQuery.FieldByName('DESCRICAO').AsString;
  end;
end;

procedure TfrmConfiguracoes.PreencherObjeto;
begin
end;

function TfrmConfiguracoes.Validar: Boolean;
begin
  Result := False;
  if Trim(edtChave.Text) = '' then
  begin
    MessageDlg('O campo Chave é obrigatório.', mtWarning, [mbOK], 0);
    edtChave.SetFocus;
    Exit;
  end;
  if Length(Trim(edtChave.Text)) > 50 then
  begin
    MessageDlg('A Chave pode ter no máximo 50 caracteres.', mtWarning, [mbOK], 0);
    edtChave.SetFocus;
    Exit;
  end;
  Result := True;
end;

function TfrmConfiguracoes.Salvar: Boolean;
begin
  Result := False;
  try
    if Trim(edtValor.Text) = '' then
    begin
      { valor vazio = remover a configuração e voltar ao padrão }
      if MessageDlg('Valor vazio',
        'Deixar o Valor vazio remove esta configuração e volta ao padrão ' +
        'do sistema.' + sLineBreak + sLineBreak + 'Remover a configuração?',
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
        Exit;
    end;

    FService.Gravar(edtChave.Text, edtValor.Text, edtDescricao.Text);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

function TfrmConfiguracoes.Excluir: Boolean;
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
