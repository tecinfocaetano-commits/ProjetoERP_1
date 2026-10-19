unit uFrmUsuarios;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário de Usuários
  Descrição: CRUD de Usuários do sistema
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, DBGrids, DB, SQLDB, ComCtrls,
  uFrmCadastroBase, uConexao, uSessao, uSenhaHash;

type
  { TfrmUsuarios }
  TfrmUsuarios = class(TfrmCadastroBase)
    lblNome: TLabel;
    edtNome: TEdit;
    lblLogin: TLabel;
    edtLogin: TEdit;
    lblSenha: TLabel;
    edtSenha: TEdit;
    lblConfirmarSenha: TLabel;
    edtConfirmarSenha: TEdit;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblTelefone: TLabel;
    edtTelefone: TEdit;
    lblGrupo: TLabel;
    cmbGrupo: TComboBox;
    chkAdministrador: TCheckBox;
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
    procedure CarregarGrupos;
    procedure ConfigurarGrid;
  end;

var
  frmUsuarios: TfrmUsuarios;

implementation

{$R *.lfm}

{ TfrmUsuarios }

procedure TfrmUsuarios.FormCreate(Sender: TObject);
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

    lblTitulo.Caption := 'Cadastro de Usuários';
    Caption := 'Usuários';
    ConfigurarGrid;
    CarregarGrupos;

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

procedure TfrmUsuarios.ConfigurarGrid;
begin
  dbGrid.Columns.Clear;
  with dbGrid.Columns.Add do begin Title.Caption := 'ID'; FieldName := 'ID'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Nome'; FieldName := 'NOME'; Width := 200; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Login'; FieldName := 'LOGIN'; Width := 120; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Email'; FieldName := 'EMAIL'; Width := 180; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Admin'; FieldName := 'ADMINISTRADOR'; Width := 50; end;
  with dbGrid.Columns.Add do begin Title.Caption := 'Status'; FieldName := 'ATIVO'; Width := 50; end;
end;

procedure TfrmUsuarios.CarregarGrupos;
var
  LQuery: TSQLQuery;
begin
  cmbGrupo.Items.Clear;
  cmbGrupo.Items.Add('');
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT ID, NOME FROM GRUPO WHERE ATIVO = ''A'' ORDER BY NOME';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      cmbGrupo.Items.AddObject(LQuery.FieldByName('NOME').AsString,
        TObject(PtrInt(LQuery.FieldByName('ID').AsLargeInt)));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmUsuarios.CarregarDados(const AFiltro: string);
var
  LSQL: string;
begin
  LSQL := 'SELECT ID, NOME, LOGIN, EMAIL, ADMINISTRADOR, ATIVO FROM USUARIO';
  if AFiltro <> '' then
    LSQL := LSQL + ' WHERE UPPER(NOME) CONTAINING UPPER(:FILTRO) OR UPPER(LOGIN) CONTAINING UPPER(:FILTRO2)';
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

procedure TfrmUsuarios.HabilitarCampos(AHabilitar: Boolean);
begin
  edtNome.Enabled := AHabilitar;
  edtLogin.Enabled := AHabilitar;
  edtSenha.Enabled := AHabilitar;
  edtConfirmarSenha.Enabled := AHabilitar;
  edtEmail.Enabled := AHabilitar;
  edtTelefone.Enabled := AHabilitar;
  cmbGrupo.Enabled := AHabilitar;
  chkAdministrador.Enabled := AHabilitar;
  cmbStatus.Enabled := AHabilitar;
end;

procedure TfrmUsuarios.LimparCampos;
begin
  edtNome.Clear;
  edtLogin.Clear;
  edtSenha.Clear;
  edtConfirmarSenha.Clear;
  edtEmail.Clear;
  edtTelefone.Clear;
  cmbGrupo.ItemIndex := 0;
  chkAdministrador.Checked := False;
  cmbStatus.ItemIndex := 0;
end;

procedure TfrmUsuarios.PreencherCampos;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'SELECT * FROM USUARIO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      edtNome.Text := LQuery.FieldByName('NOME').AsString;
      edtLogin.Text := LQuery.FieldByName('LOGIN').AsString;
      edtSenha.Text := '';
      edtConfirmarSenha.Text := '';
      edtEmail.Text := LQuery.FieldByName('EMAIL').AsString;
      edtTelefone.Text := LQuery.FieldByName('TELEFONE').AsString;
      chkAdministrador.Checked := LQuery.FieldByName('ADMINISTRADOR').AsString = 'S';

      if LQuery.FieldByName('ATIVO').AsString = 'A' then
        cmbStatus.ItemIndex := 0
      else
        cmbStatus.ItemIndex := 1;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmUsuarios.PreencherObjeto;
begin
end;

function TfrmUsuarios.Validar: Boolean;
begin
  Result := False;

  if Trim(edtNome.Text) = '' then
  begin
    MessageDlg('O campo Nome é obrigatório.', mtWarning, [mbOK], 0);
    edtNome.SetFocus;
    Exit;
  end;

  if Trim(edtLogin.Text) = '' then
  begin
    MessageDlg('O campo Login é obrigatório.', mtWarning, [mbOK], 0);
    edtLogin.SetFocus;
    Exit;
  end;

  // Senha obrigatória apenas para novos usuários
  if (FEstado = efInserindo) and (Trim(edtSenha.Text) = '') then
  begin
    MessageDlg('O campo Senha é obrigatório para novos usuários.', mtWarning, [mbOK], 0);
    edtSenha.SetFocus;
    Exit;
  end;

  if (edtSenha.Text <> '') and (edtSenha.Text <> edtConfirmarSenha.Text) then
  begin
    MessageDlg('As senhas não conferem.', mtWarning, [mbOK], 0);
    edtConfirmarSenha.SetFocus;
    Exit;
  end;

  if (edtSenha.Text <> '') and (Length(edtSenha.Text) < 6) then
  begin
    MessageDlg('A senha deve ter pelo menos 6 caracteres.', mtWarning, [mbOK], 0);
    edtSenha.SetFocus;
    Exit;
  end;

  Result := True;
end;

function TfrmUsuarios.Salvar: Boolean;
var
  LQuery: TSQLQuery;
  LAdmin: string;
begin
  Result := False;
  if chkAdministrador.Checked then LAdmin := 'S' else LAdmin := 'N';

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;

    if FEstado = efInserindo then
    begin
      LQuery.SQL.Text :=
        'INSERT INTO USUARIO (EMPRESA_ID, NOME, LOGIN, SENHA, EMAIL, TELEFONE, ' +
        'ADMINISTRADOR, ATIVO) VALUES (:EMP, :NOME, :LOGIN, :SENHA, :EMAIL, ' +
        ':TEL, :ADMIN, :ATIVO)';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('SENHA').AsString := HashSenha(edtSenha.Text);
    end
    else
    begin
      if edtSenha.Text <> '' then
      begin
        LQuery.SQL.Text :=
          'UPDATE USUARIO SET NOME = :NOME, LOGIN = :LOGIN, SENHA = :SENHA, ' +
          'EMAIL = :EMAIL, TELEFONE = :TEL, ADMINISTRADOR = :ADMIN, ATIVO = :ATIVO ' +
          'WHERE ID = :ID';
        LQuery.ParamByName('SENHA').AsString := HashSenha(edtSenha.Text);
      end
      else
      begin
        LQuery.SQL.Text :=
          'UPDATE USUARIO SET NOME = :NOME, LOGIN = :LOGIN, EMAIL = :EMAIL, ' +
          'TELEFONE = :TEL, ADMINISTRADOR = :ADMIN, ATIVO = :ATIVO WHERE ID = :ID';
      end;
      LQuery.ParamByName('ID').AsLargeInt := FIdSelecionado;
    end;

    LQuery.ParamByName('NOME').AsString := edtNome.Text;
    LQuery.ParamByName('LOGIN').AsString := edtLogin.Text;
    LQuery.ParamByName('EMAIL').AsString := edtEmail.Text;
    LQuery.ParamByName('TEL').AsString := edtTelefone.Text;
    LQuery.ParamByName('ADMIN').AsString := LAdmin;

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

function TfrmUsuarios.Excluir: Boolean;
var
  LQuery: TSQLQuery;
begin
  Result := False;

  if FIdSelecionado = TSessao.GetInstance.UsuarioId then
  begin
    MessageDlg('Não é possível excluir o próprio usuário logado.', mtError, [mbOK], 0);
    Exit;
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FConexao.IniciarTransacao;
    LQuery.SQL.Text := 'DELETE FROM USUARIO WHERE ID = :ID';
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
