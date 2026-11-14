unit uFrmLogin;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 2 - Formulário de Login
  Descrição: Autenticação do usuário no sistema
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Buttons, SQLDB, uConexao, uSessao, uSenhaHash,
  uUsuarioService, uUsuario;

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
  { Nada de credencial pre-preenchida: em producao o operador digita
    usuario e senha. }
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
  LService: TUsuarioService;
  LUsuario: TUsuario;
  LEmpresaTexto: string;
  LEmpresaId: Int64;
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

  { autenticação e atualização de último acesso ficam no Service;
    a senha não entra no WHERE: o banco guarda SHA-256 e a comparação
    é feita em código (uSenhaHash) — aceita senha legada em texto
    puro, migrada para hash no RegistrarAcesso }
  LService := TUsuarioService.Create;
  try
    LUsuario := nil;
    try
      try
        LUsuario := LService.BuscarPorLogin(ALogin);
      except
        on E: ELoginAmbiguo do
        begin
          { login repetido em mais de uma empresa: pergunta qual }
          LEmpresaTexto := '';
          if not InputQuery('Empresa',
            E.Message + sLineBreak + sLineBreak + 'Código da empresa:',
            LEmpresaTexto) then
            Exit;
          LEmpresaId := StrToInt64Def(Trim(LEmpresaTexto), 0);
          if LEmpresaId <= 0 then
          begin
            ExibirErro('Código de empresa inválido.');
            Exit;
          end;
          LUsuario := LService.BuscarPorLogin(ALogin, LEmpresaId);
        end;
      end;

      if LUsuario = nil then
        Exit;
      if not SenhaConfere(ASenha, LUsuario.Senha) then
        Exit;

      TSessao.GetInstance.Logar(
        LUsuario.Id,
        LUsuario.EmpresaId,
        LUsuario.GrupoId,
        LUsuario.Nome,
        LUsuario.Login,
        LUsuario.Administrador
      );

      LService.RegistrarAcesso(LUsuario.Id, ASenha, LUsuario.Senha);
      Result := True;
    finally
      LUsuario.Free;
    end;
  finally
    LService.Free;
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
