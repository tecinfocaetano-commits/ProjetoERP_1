unit uApiSaude;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Windows, ShellApi;

{ URL base da API REST. Lê a chave API_URL de CONFIGURACAO
  (empresa da sessão, fallback global); padrão local. }
function ApiUrlPadrao: string;

{ True se a API responde 200 em GET <base>/api/health
  dentro do timeout. Nunca levanta exceção. }
function VerificarApi(const ABaseUrl: string): Boolean;

{ True quando a URL aponta para a própria máquina
  (localhost/127.0.0.1) — só aí faz sentido tentar subir
  a API localmente. }
function ApiEhLocal(const ABaseUrl: string): Boolean;

{ Executa API\bin\ERP2026API.exe a partir da pasta do projeto
  (Desktop\bin\..\..\API\bin). Retorna False se o exe não existir. }
function IniciarApiLocal: Boolean;

{ Thread de verificação: roda VerificarApi fora da thread principal
  e devolve o resultado via callback na thread da UI, sem método
  anônimo — compatível com {$mode objfpc}. }
type
  TApiCheckCallback = procedure(AOk: Boolean;
    const AUrl: string) of object;

  TApiCheckThread = class(TThread)
  private
    FUrl: string;
    FOnResult: TApiCheckCallback;
    FOk: Boolean;
    procedure Notificar;
  protected
    procedure Execute; override;
  public
    constructor Create(const AUrl: string;
      AOnResult: TApiCheckCallback);
  end;

implementation

uses
  fphttpclient, uConfiguracaoService, uIniServidor;

const
  CHAVE_API_URL = 'API_URL';
  API_URL_PADRAO = 'http://127.0.0.1:9000';

function ApiUrlPadrao: string;
var
  LUrl: string;
  LConfig: TConfiguracaoService;
begin
  { 1) erp2026.ini — funciona até sem banco conectado;
    2) CONFIGURACAO.API_URL — override por empresa no banco;
    3) padrão local }
  LUrl := Trim(LerServidor('api_url', ''));
  if LUrl <> '' then
  begin
    Result := LUrl;
    Exit;
  end;
  LConfig := TConfiguracaoService.Create;
  try
    LUrl := Trim(LConfig.LerValor(CHAVE_API_URL));
  finally
    LConfig.Free;
  end;
  if LUrl = '' then
    Result := API_URL_PADRAO
  else
    Result := LUrl;
end;

function VerificarApi(const ABaseUrl: string): Boolean;
var
  LClient: TFPHTTPClient;
  LResp: string;
begin
  Result := False;
  LClient := TFPHTTPClient.Create(nil);
  try
    LClient.ConnectTimeout := 2000;
    LResp := LClient.Get(ABaseUrl + '/api/health');
    Result := Pos('"banco"', LResp) > 0;
  except
    Result := False;
  end;
  LClient.Free;
end;

function ApiEhLocal(const ABaseUrl: string): Boolean;
var
  LUrl: string;
begin
  LUrl := LowerCase(Trim(ABaseUrl));
  Result := (Pos('127.0.0.1', LUrl) > 0) or
    (Pos('localhost', LUrl) > 0);
end;

function IniciarApiLocal: Boolean;
var
  LExe, LProjeto: string;
  LTentativas: Integer;
begin
  { ERP2026.exe está em <projeto>\Desktop\bin — sobe dois níveis
    até a raiz e entra em API\bin\ERP2026API.exe. ExpandFileName
    resolve os '..' para o caminho absoluto. }
  LProjeto := ExtractFilePath(Application.ExeName);
  LExe := ExpandFileName(IncludeTrailingPathDelimiter(LProjeto) +
    '..' + PathDelim + '..' + PathDelim + 'API' + PathDelim +
    'bin' + PathDelim + 'ERP2026API.exe');
  Result := FileExists(LExe);
  if not Result then
    Exit;

  { ShellExecute abre a API em processo independente (janela de
    console visível, com o log); não bloqueia o desktop }
  Result := PtrUInt(ShellExecute(0, 'open', PChar(LExe),
    PChar(''), PChar(''), SW_SHOWNORMAL)) > 32;
  if not Result then
    Exit;

  { a API demora alguns segundos para abrir a porta (banner +
    pool de conexões); tenta de novo por até ~12s }
  Result := False;
  for LTentativas := 1 to 12 do
  begin
    Sleep(1000);
    if VerificarApi(API_URL_PADRAO) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

{ ------------------------------------------------------------------
  TApiCheckThread
  ------------------------------------------------------------------ }

constructor TApiCheckThread.Create(const AUrl: string;
  AOnResult: TApiCheckCallback);
begin
  inherited Create(True);
  FUrl := AUrl;
  FOnResult := AOnResult;
  FreeOnTerminate := True;
end;

procedure TApiCheckThread.Execute;
begin
  FOk := VerificarApi(FUrl);
  Synchronize(@Notificar);
end;

procedure TApiCheckThread.Notificar;
begin
  { roda na thread principal via Synchronize }
  FOnResult(FOk, FUrl);
end;

end.
