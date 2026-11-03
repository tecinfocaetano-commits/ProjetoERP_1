unit uFrmLogin;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário de Login
  Descrição: Autenticação do usuário no sistema
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, SQLDB, uConexao, uSessao, uSenhaHash;

type
  { TfrmLogin }
  TfrmLogin = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    pnlCentro: TPanel;
    lblUsuario: TLabel;
    edtUsuario: TEdit;
    lblSenha: TLabel;
    edtSenha: TEdit;
    btnEntrar: TBitBtn;
    btnSair: TBitBtn;
    lblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnEntrarClick(Sender: TObject);
    procedure btnSairClick(Sender: TObject);
    procedure edtSenhaKeyPress(Sender: TObject; var Key: char);
    procedure FormShow(Sender: TObject);
  private
    FTentativas: Integer;
    function Autenticar(const ALogin, ASenha: string): Boolean;
    procedure ExibirErro(const AMsg: string);
    procedure LimparCampos;
  public
  end;

var
  frmLogin: TfrmLogin;

implementation

{$R *.lfm}

{ TfrmLogin }

procedure TfrmLogin.FormCreate(Sender: TObject);
begin
  FTentativas := 0;
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  Caption := 'ERP 2026 - Login';
  KeyPreview := True;
end;

procedure TfrmLogin.FormShow(Sender: TObject);
begin
  // Preencher credenciais padrão para facilitar testes
  edtUsuario.Text := 'admin';
  edtSenha.Text := 'admin123';
  edtUsuario.SetFocus;
  lblStatus.Caption := '';
end;

procedure TfrmLogin.btnEntrarClick(Sender: TObject);
begin
  if Trim(edtUsuario.Text) = '' then
  begin
    ExibirErro('Informe o usuário.');
    edtUsuario.SetFocus;
    Exit;
  end;

  if Trim(edtSenha.Text) = '' then
  begin
    ExibirErro('Informe a senha.');
    edtSenha.SetFocus;
    Exit;
  end;

  if Autenticar(edtUsuario.Text, edtSenha.Text) then
  begin
    ModalResult := mrOk;
  end
  else
  begin
    Inc(FTentativas);
    if FTentativas >= 3 then
    begin
      MessageDlg('Limite de tentativas excedido. O sistema será encerrado.',
        mtError, [mbOK], 0);
      Application.Terminate;
    end
    else
    begin
      ExibirErro(Format('Usuário ou senha inválidos. Tentativa %d de 3.',
        [FTentativas]));
      edtSenha.Clear;
      edtSenha.SetFocus;
    end;
  end;
end;

procedure TfrmLogin.btnSairClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmLogin.edtSenhaKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnEntrarClick(Sender);
  end;
end;

function TfrmLogin.Autenticar(const ALogin, ASenha: string): Boolean;
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LSenhaGuardada: string;
  LId: Int64;
  LEmpresaId, LGrupoId: Int64;
  LNome, LLogin, LAdmin: string;
begin
  Result := False;
  LConexao := TConexao.GetInstance;

  try
    LConexao.Conectar;
  except
    on E: Exception do
    begin
      ExibirErro('Erro ao conectar ao banco: ' + E.Message);
      Exit;
    end;
  end;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    { a senha não entra mais no WHERE: o banco guarda SHA-256 e a
      comparação é feita em código (uSenhaHash) — assim o login
      também aceita senha legada em texto puro (migração) }
    LQuery.SQL.Text :=
      'SELECT U.ID, U.EMPRESA_ID, U.GRUPO_ID, U.NOME, U.LOGIN, U.ADMINISTRADOR, U.ATIVO, U.SENHA ' +
      'FROM USUARIO U ' +
      'WHERE U.LOGIN = :LOGIN AND U.ATIVO = ''A''';
    LQuery.ParamByName('LOGIN').AsString := ALogin;
    LQuery.Open;

    if LQuery.IsEmpty then
      Exit;

    LSenhaGuardada := LQuery.FieldByName('SENHA').AsString;
    if not SenhaConfere(ASenha, LSenhaGuardada) then
      Exit;

    LId := LQuery.FieldByName('ID').AsLargeInt;
    LEmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
    LGrupoId := LQuery.FieldByName('GRUPO_ID').AsLargeInt;
    LNome := LQuery.FieldByName('NOME').AsString;
    LLogin := LQuery.FieldByName('LOGIN').AsString;
    LAdmin := LQuery.FieldByName('ADMINISTRADOR').AsString;

    TSessao.GetInstance.Logar(
      LId,
      LEmpresaId,
      LGrupoId,
      LNome,
      LLogin,
      LAdmin = 'S'
    );

    // Atualizar último acesso (+ migração da senha legada para SHA-256)
    LQuery.Close;
    if PrecisaMigrarSenha(LSenhaGuardada) then
      LQuery.SQL.Text :=
        'UPDATE USUARIO SET SENHA = :SENHA, ULTIMO_ACESSO = CURRENT_TIMESTAMP WHERE ID = :ID'
    else
      LQuery.SQL.Text :=
        'UPDATE USUARIO SET ULTIMO_ACESSO = CURRENT_TIMESTAMP WHERE ID = :ID';
    if PrecisaMigrarSenha(LSenhaGuardada) then
      LQuery.ParamByName('SENHA').AsString := HashSenha(ASenha);
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ExecSQL;
    LConexao.Confirmar;

    Result := True;
  finally
    LQuery.Free;
  end;
end;

procedure TfrmLogin.ExibirErro(const AMsg: string);
begin
  lblStatus.Caption := AMsg;
  lblStatus.Font.Color := clRed;
end;

procedure TfrmLogin.LimparCampos;
begin
  edtUsuario.Clear;
  edtSenha.Clear;
  lblStatus.Caption := '';
end;

end.
