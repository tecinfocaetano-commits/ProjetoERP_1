unit uFrmConfigServidor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs,
  IBConnection, SQLDB;

type
  { Wizard de configuração de rede — exibido antes do login quando
    erp2026.ini não existe ou está incompleto. }
  TfrmConfigServidor = class(TForm)
    lblTitulo: TLabel;
    grpBanco: TGroupBox;
    lblHost: TLabel;
    edtHost: TEdit;
    lblPorta: TLabel;
    edtPorta: TEdit;
    lblCaminho: TLabel;
    edtCaminho: TEdit;
    lblUsuario: TLabel;
    edtUsuario: TEdit;
    lblSenha: TLabel;
    edtSenha: TEdit;
    lblApi: TLabel;
    edtApiUrl: TEdit;
    lblObs: TLabel;
    btnTeste: TButton;
    btnLocal: TButton;
    btnSalvar: TButton;
    btnSair: TButton;
    constructor CreateNew(AOwner: TComponent); reintroduce;
    procedure btnTesteClick(Sender: TObject);
    procedure btnLocalClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnSairClick(Sender: TObject);
  private
    procedure MontarInterface;
    function TestarBanco: string;
    function TestarApi: string;
  public
  end;

var
  frmConfigServidor: TfrmConfigServidor;

implementation

uses
  uIniServidor, uApiSaude;

{ Caminho padrão do banco (mesmo cálculo do uConexao). }
function CaminhoBancoPadrao: string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    '..' + PathDelim + '..' + PathDelim + 'Banco' + PathDelim +
    'dados.fdb');
end;

{ CreateNew (em vez de Create) porque a classe não tem .lfm —
  TForm.Create procuraria o recurso DFM e daria erro 217. }
constructor TfrmConfigServidor.CreateNew(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  MontarInterface;
end;

procedure TfrmConfigServidor.MontarInterface;
begin
  Caption := 'Configuração do Servidor — ERP 2026';
  Position := poScreenCenter;
  ClientWidth := 560;
  ClientHeight := 470;
  BorderStyle := bsDialog;

  lblTitulo := TLabel.Create(Self);
  lblTitulo.Parent := Self;
  lblTitulo.Left := 16; lblTitulo.Top := 12;
  lblTitulo.Caption := 'Primeira configuração — informe onde está ' +
    'o banco de dados e a API.';
  lblTitulo.AutoSize := True;

  grpBanco := TGroupBox.Create(Self);
  grpBanco.Parent := Self;
  grpBanco.Left := 16; grpBanco.Top := 44;
  grpBanco.Width := 528; grpBanco.Height := 310;
  grpBanco.Caption := 'Banco de dados (Firebird)';

  lblHost := TLabel.Create(Self);
  lblHost.Parent := grpBanco;
  lblHost.Left := 16; lblHost.Top := 24;
  lblHost.Caption := 'Servidor / IP (vazio = este computador)';
  lblHost.AutoSize := True;
  edtHost := TEdit.Create(Self);
  edtHost.Parent := grpBanco;
  edtHost.Left := 16; edtHost.Top := 44;
  edtHost.Width := 496;
  edtHost.Text := LerServidor('banco_host', '');

  lblPorta := TLabel.Create(Self);
  lblPorta.Parent := grpBanco;
  lblPorta.Left := 16; lblPorta.Top := 76;
  lblPorta.Caption := 'Porta';
  lblPorta.AutoSize := True;
  edtPorta := TEdit.Create(Self);
  edtPorta.Parent := grpBanco;
  edtPorta.Left := 16; edtPorta.Top := 96;
  edtPorta.Width := 80;
  edtPorta.Text := LerServidor('banco_porta', '3050');

  lblCaminho := TLabel.Create(Self);
  lblCaminho.Parent := grpBanco;
  lblCaminho.Left := 16; lblCaminho.Top := 128;
  lblCaminho.Caption := 'Caminho do banco .FDB no servidor';
  lblCaminho.AutoSize := True;
  edtCaminho := TEdit.Create(Self);
  edtCaminho.Parent := grpBanco;
  edtCaminho.Left := 16; edtCaminho.Top := 148;
  edtCaminho.Width := 496;
  edtCaminho.Text := LerServidor('banco_caminho',
    CaminhoBancoPadrao);

  lblUsuario := TLabel.Create(Self);
  lblUsuario.Parent := grpBanco;
  lblUsuario.Left := 16; lblUsuario.Top := 180;
  lblUsuario.Caption := 'Usuário do banco (Firebird)';
  lblUsuario.AutoSize := True;
  edtUsuario := TEdit.Create(Self);
  edtUsuario.Parent := grpBanco;
  edtUsuario.Left := 16; edtUsuario.Top := 200;
  edtUsuario.Width := 496;
  edtUsuario.Text := LerServidor('banco_usuario', 'SYSDBA');

  lblSenha := TLabel.Create(Self);
  lblSenha.Parent := grpBanco;
  lblSenha.Left := 16; lblSenha.Top := 232;
  lblSenha.Caption := 'Senha do banco';
  lblSenha.AutoSize := True;
  edtSenha := TEdit.Create(Self);
  edtSenha.Parent := grpBanco;
  edtSenha.Left := 16; edtSenha.Top := 252;
  edtSenha.Width := 496;
  edtSenha.PasswordChar := '*';
  edtSenha.Text := LerServidor('banco_senha', '');

  lblApi := TLabel.Create(Self);
  lblApi.Parent := grpBanco;
  lblApi.Left := 16; lblApi.Top := 284;
  lblApi.Caption := 'Endereço da API REST (para os apps móveis)';
  lblApi.AutoSize := True;
  edtApiUrl := TEdit.Create(Self);
  edtApiUrl.Parent := grpBanco;
  edtApiUrl.Left := 16; edtApiUrl.Top := 304;
  edtApiUrl.Width := 496;
  edtApiUrl.Text := LerServidor('api_url',
    'http://127.0.0.1:9000');

  lblObs := TLabel.Create(Self);
  lblObs.Parent := Self;
  lblObs.Left := 16; lblObs.Top := 362;
  lblObs.AutoSize := False;
  lblObs.Width := 528; lblObs.Height := 40;
  lblObs.WordWrap := True;
  lblObs.Caption := 'Em instalação local deixe os valores padrão. ' +
    'Para acessar um servidor remoto, preencha o IP do servidor ' +
    'e o caminho do .FDB como ele existe NAQUELE computador.';

  btnTeste := TButton.Create(Self);
  btnTeste.Parent := Self;
  btnTeste.Left := 16; btnTeste.Top := 410;
  btnTeste.Width := 130; btnTeste.Height := 30;
  btnTeste.Caption := 'Testar conexão';
  btnTeste.OnClick := @btnTesteClick;

  btnLocal := TButton.Create(Self);
  btnLocal.Parent := Self;
  btnLocal.Left := 156; btnLocal.Top := 410;
  btnLocal.Width := 200; btnLocal.Height := 30;
  btnLocal.Caption := 'Usar configuração local';
  btnLocal.OnClick := @btnLocalClick;

  btnSalvar := TButton.Create(Self);
  btnSalvar.Parent := Self;
  btnSalvar.Left := 366; btnSalvar.Top := 410;
  btnSalvar.Width := 90; btnSalvar.Height := 30;
  btnSalvar.Caption := 'Salvar';
  btnSalvar.ModalResult := mrOk;
  btnSalvar.OnClick := @btnSalvarClick;

  btnSair := TButton.Create(Self);
  btnSair.Parent := Self;
  btnSair.Left := 462; btnSair.Top := 410;
  btnSair.Width := 82; btnSair.Height := 30;
  btnSair.Caption := 'Sair';
  btnSair.ModalResult := mrCancel;
  btnSair.OnClick := @btnSairClick;
end;

{ Testa o banco com os valores digitados, sem tocar no singleton. }
function TfrmConfigServidor.TestarBanco: string;
var
  LConn: TIBConnection;
  LTrans: TSQLTransaction;
begin
  Result := '';
  LConn := TIBConnection.Create(nil);
  LTrans := TSQLTransaction.Create(nil);
  try
    LTrans.Params.Add('read_committed');
    LTrans.Params.Add('rec_version');
    LTrans.Params.Add('nowait');
    LConn.Transaction := LTrans;
    LTrans.DataBase := LConn;
    LConn.HostName := Trim(edtHost.Text);
    LConn.DatabaseName := Trim(edtCaminho.Text);
    LConn.UserName := Trim(edtUsuario.Text);
    LConn.Password := edtSenha.Text;
    LConn.Port := StrToIntDef(Trim(edtPorta.Text), 3050);
    LConn.CharSet := 'UTF8';
    LConn.LoginPrompt := False;
    LConn.Params.Add('isc_dpb_lc_ctype=UTF8');
    try
      LConn.Connected := True;
      Result := 'Banco: CONECTOU com sucesso.';
    except
      on E: Exception do
        Result := 'Banco: FALHOU — ' + E.Message;
    end;
    if LConn.Connected then
      LConn.Connected := False;
  finally
    LTrans.Free;
    LConn.Free;
  end;
end;

function TfrmConfigServidor.TestarApi: string;
begin
  if VerificarApi(Trim(edtApiUrl.Text)) then
    Result := 'API: respondendo em ' + Trim(edtApiUrl.Text) + '.'
  else
    Result := 'API: SEM resposta em ' + Trim(edtApiUrl.Text) +
      ' (os apps móveis não funcionarão até ela subir).';
end;

procedure TfrmConfigServidor.btnTesteClick(Sender: TObject);
begin
  MessageDlg(TestarBanco + sLineBreak + TestarApi,
    mtInformation, [mbOK], 0);
end;

procedure TfrmConfigServidor.btnLocalClick(Sender: TObject);
begin
  edtHost.Text := '';
  edtPorta.Text := '3050';
  edtCaminho.Text := CaminhoBancoPadrao;
  edtUsuario.Text := 'SYSDBA';
  edtSenha.Text := '';
  edtApiUrl.Text := 'http://127.0.0.1:9000';
end;

procedure TfrmConfigServidor.btnSalvarClick(Sender: TObject);
begin
  if Trim(edtCaminho.Text) = '' then
  begin
    MessageDlg('Informe o caminho do banco .FDB.', mtWarning,
      [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  GravarServidor('banco_host', Trim(edtHost.Text));
  GravarServidor('banco_porta', Trim(edtPorta.Text));
  GravarServidor('banco_caminho', Trim(edtCaminho.Text));
  GravarServidor('banco_usuario', Trim(edtUsuario.Text));
  GravarServidor('banco_senha', edtSenha.Text);
  GravarServidor('api_url', Trim(edtApiUrl.Text));
end;

procedure TfrmConfigServidor.btnSairClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

initialization
  frmConfigServidor := nil;

end.
