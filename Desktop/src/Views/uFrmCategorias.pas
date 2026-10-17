unit uFrmCategorias;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário de Categorias
  Descrição: CRUD de Categorias de Produtos
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao;

type
  { TfrmCategorias }
  TfrmCategorias = class(TfrmCadastroBase)
    lblNome: TLabel;
    edtNome: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
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
  frmCategorias: TfrmCategorias;

implementation

{$R *.lfm}

{ TfrmCategorias }

procedure TfrmCategorias.FormCreate(Sender: TObject);
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

    // Criar DataSource1 se não existir
    if DataSource1 = nil then
      DataSource1 := TDataSource.Create(Self);

    lblTitulo.Caption := 'Cadastro de Categorias';
    Caption := 'Categorias';
    ConfigurarGrid;

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

procedure TfrmCategorias.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Nome'; FieldName := 'NOME'; Width := 200; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Descrição'; FieldName := 'DESCRICAO'; Width := 250; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Status'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmCategorias.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, NOME, DESCRICAO, ATIVO FROM CATEGORIA';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(NOME) CONTAINING UPPER(:FILTRO)';
  LSQL := LSQL + ' ORDER BY NOME';

  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Text := LSQL;
  if AFiltro <> '' then
    FQuery.ParamByName('FILTRO').AsString := AFiltro;
  FQuery.Open;
  DataSource1.DataSet := FQuery;
end;

procedure TfrmCategorias.HabilitarCampos(AHabilitar: Boolean);
begin
  edtNome.Enabled := AHabilitar;
  edtDescricao.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
end;

procedure TfrmCategorias.LimparCampos;
begin
  edtNome.Clear;
  edtDescricao.Clear;
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmCategorias.PreencherCampos;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM CATEGORIA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      edtNome.Text := LQuery.FieldByName('NOME').AsString;
      edtDescricao.Text := LQuery.FieldByName('DESCRICAO').AsString;
      if LQuery.FieldByName('ATIVO').AsString = 'A' then
        cmbStatus.ItemIndex := 0
      else
        cmbStatus.ItemIndex := 1;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmCategorias.PreencherObjeto;
begin
end;

function TfrmCategorias.Validar: Boolean;
begin
  Result := False;
  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('O campo Nome é obrigatório.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;
  Result := True;
end;

function TfrmCategorias.Salvar: Boolean;
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
        'INSERT INTO CATEGORIA (EMPRESA_ID, NOME, DESCRICAO, ATIVO) ' +
        'VALUES (:EMP, :NOME, :DESC, :ATIVO)';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    end
    else
    begin
      LQuery.SQL.Text :=
        'UPDATE CATEGORIA SET NOME = :NOME, DESCRICAO = :DESC, ATIVO = :ATIVO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    end;

    LQuery.ParamByName('NOME').AsString := edtNome.Text;
    LQuery.ParamByName('DESC').AsString := edtDescricao.Text;
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

function TfrmCategorias.Excluir: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text := 'DELETE FROM CATEGORIA WHERE ID = :ID';
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
