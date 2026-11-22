unit uIniServidor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

{ Configuração de rede do ERP — arquivo erp2026.ini ao lado do exe.
  Lido ANTES de conectar no banco (resolve o problema do ovo e
  galinha: CONFIGURACAO fica dentro do banco, não pode guiar a
  primeira conexão). }

{ Caminho absoluto do ini: <pasta do exe>\erp2026.ini }
function IniServidorCaminho: string;

{ Lê uma chave da seção [servidor]; devolve APadrao se ausente. }
function LerServidor(const AChave, APadrao: string): string;

{ Grava/atualiza uma chave na seção [servidor]. }
procedure GravarServidor(const AChave, AValor: string);

{ True quando o ini existe e tem ao menos banco_caminho ou
  banco_host preenchido — ou seja, o wizard já foi respondido. }
function ServidorConfigurado: Boolean;

{ Carrega todos os valores de uma vez (para uConexao/uApiSaude). }
procedure CarregarServidor(out AHost: string; out APorta: Integer;
  out ACaminhoBanco, AApiUrl: string);

implementation

uses
  inifiles;

const
  SECAO = 'servidor';
  CH_HOST = 'banco_host';
  CH_PORTA = 'banco_porta';
  CH_CAMINHO = 'banco_caminho';
  CH_API = 'api_url';

function IniServidorCaminho: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'erp2026.ini';
end;

function LerServidor(const AChave, APadrao: string): string;
var
  LIni: TIniFile;
begin
  Result := APadrao;
  if not FileExists(IniServidorCaminho) then
    Exit;
  LIni := TIniFile.Create(IniServidorCaminho);
  try
    Result := Trim(LIni.ReadString(SECAO, AChave, APadrao));
    if Result = '' then
      Result := APadrao;
  finally
    LIni.Free;
  end;
end;

procedure GravarServidor(const AChave, AValor: string);
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(IniServidorCaminho);
  try
    LIni.WriteString(SECAO, AChave, AValor);
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;

function ServidorConfigurado: Boolean;
begin
  Result := (Trim(LerServidor(CH_CAMINHO, '')) <> '') or
    (Trim(LerServidor(CH_HOST, '')) <> '');
end;

procedure CarregarServidor(out AHost: string; out APorta: Integer;
  out ACaminhoBanco, AApiUrl: string);
begin
  AHost := LerServidor(CH_HOST, '');
  APorta := StrToIntDef(LerServidor(CH_PORTA, '3050'), 3050);
  ACaminhoBanco := LerServidor(CH_CAMINHO, '');
  AApiUrl := LerServidor(CH_API, '');
end;

end.
