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
  uFrmCadastroBase, uConexao, uSessao,
  uUsuarioService, uUsuario;

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
    FService: TUsuarioService;
    procedure CarregarGrupos;
    procedure ConfigurarGrid;
  end;

var
  frmUsuarios: TfrmUsuarios;

implementation

{$R *.lfm}

{ TfrmUsuarios }

destructor TfrmUsuarios.Destroy;
begin
  FreeAndNil(FService);
  inherited Destroy;
end;

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
    FService := TUsuarioService.Create;

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
  LGrupoId: Int64;
  I: Integer;
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

      cmbGrupo.ItemIndex := 0;
      if (LQuery.FindField('GRUPO_ID') <> nil) and
         (not LQuery.FieldByName('GRUPO_ID').IsNull) then
      begin
        LGrupoId := LQuery.FieldByName('GRUPO_ID').AsLargeInt;
        for I := 1 to cmbGrupo.Items.Count - 1 do
          if (cmbGrupo.Items.Objects[I] <> nil) and
             (PtrInt(cmbGrupo.Items.Objects[I]) = LGrupoId) then
          begin
            cmbGrupo.ItemIndex := I;
            Break;
          end;
      end;
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

  if (cmbGrupo.ItemIndex <= 0) or
     (cmbGrupo.Items.Objects[cmbGrupo.ItemIndex] = nil) then
  begin
    MessageDlg('Selecione o Grupo do usuário.', mtWarning, [mbOK], 0);
    cmbGrupo.SetFocus;
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
  LUsuario: TUsuario;
begin
  Result := False;
  LUsuario := TUsuario.Create;
  try
    if FEstado = efInserindo then
      LUsuario.Id := 0
    else
      LUsuario.Id := FIdSelecionado;
    LUsuario.EmpresaId := TSessao.GetInstance.EmpresaId;
    LUsuario.Nome := Trim(edtNome.Text);
    LUsuario.Login := Trim(edtLogin.Text);
    LUsuario.Email := Trim(edtEmail.Text);
    LUsuario.Telefone := Trim(edtTelefone.Text);
    if chkAdministrador.Checked then
      LUsuario.Administrador := True
    else
      LUsuario.Administrador := False;
    if cmbStatus.ItemIndex = 0 then
      LUsuario.Ativo := 'A'
    else
      LUsuario.Ativo := 'I';

    if (cmbGrupo.ItemIndex > 0) and
       (cmbGrupo.Items.Objects[cmbGrupo.ItemIndex] <> nil) then
      LUsuario.GrupoId := PtrInt(cmbGrupo.Items.Objects[cmbGrupo.ItemIndex])
    else
      LUsuario.GrupoId := 0;

    { a senha chega em texto puro e o Service grava o hash SHA-256;
      vazia na edição = manter a senha atual }
    if LUsuario.Id = 0 then
      LUsuario.Id := FService.Inserir(LUsuario, edtSenha.Text)
    else
      FService.Atualizar(LUsuario, edtSenha.Text);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao salvar: ' + E.Message, mtError, [mbOK], 0);
  end;
  LUsuario.Free;
end;

function TfrmUsuarios.Excluir: Boolean;
begin
  Result := False;

  if FIdSelecionado = TSessao.GetInstance.UsuarioId then
  begin
    MessageDlg('Não é possível excluir o próprio usuário logado.', mtError, [mbOK], 0);
    Exit;
  end;

  try
    FService.Excluir(FIdSelecionado);
    Result := True;
  except
    on E: Exception do
      MessageDlg('Erro ao excluir: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
