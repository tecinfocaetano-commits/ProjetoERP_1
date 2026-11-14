unit uMiddlewareJWT;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Middleware JWT
  Descrição: Autenticação via JSON Web Token
  ============================================================ }

interface

uses
  SysUtils, Classes, fpjson, jsonparser, base64, DateUtils, Horse, uHMAC;

const
  { Usado apenas em desenvolvimento. Em producao (ERP_AMBIENTE=producao
    ou ERP_PRODUCAO=1) a API se recusa a subir sem ERP_JWT_SECRET. }
  JWT_SECRET_PADRAO_DEV = 'ERP2026_SECRET_KEY_CHANGE_IN_PRODUCTION';
  JWT_EXPIRACAO_PADRAO_HORAS = 8;
  JWT_TAMANHO_MINIMO_SEGREDO = 32;

{ Segredo efetivo: ERP_JWT_SECRET ou o padrao de desenvolvimento. }
function SegredoJWT: string;
{ Horas de validade do token: ERP_JWT_EXPIRACAO_HORAS (padrao 8). }
function HorasExpiracaoJWT: Integer;
{ Chamado na inicializacao: em producao, aborta se o segredo estiver
  ausente/fraco; em desenvolvimento, apenas avisa uma vez. }
procedure ValidarConfiguracaoJWT;

function GerarToken(AUsuarioId: Int64; const ANome, ALogin: string; AEmpresaId: Int64): string;
function ValidarToken(const AToken: string): Boolean;
function ExtrairDadosToken(const AToken: string): TJSONObject;

{ Usuario e empresa autenticados, lidos das claims do JWT (sub e
  empresa_id). Devolve 0 quando o token nao tem a claim. }
procedure DadosDoToken(Req: THorseRequest; out AUsuarioId, AEmpresaId: Int64);
procedure MiddlewareJWT(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);

implementation

var
  { Garante que o aviso de desenvolvimento apareca uma unica vez. }
  JAvisouSegredoDev: Boolean = False;

function AmbienteProducao: Boolean;
var
  LAmbiente, LFlag: string;
begin
  LAmbiente := LowerCase(Trim(GetEnvironmentVariable('ERP_AMBIENTE')));
  LFlag := Trim(GetEnvironmentVariable('ERP_PRODUCAO'));
  Result := (LAmbiente = 'producao') or (LAmbiente = 'production') or
            (LFlag = '1');
end;

function SegredoJWT: string;
begin
  Result := Trim(GetEnvironmentVariable('ERP_JWT_SECRET'));
  if Result = '' then
    Result := JWT_SECRET_PADRAO_DEV;
end;

function HorasExpiracaoJWT: Integer;
var
  LValor: string;
begin
  Result := JWT_EXPIRACAO_PADRAO_HORAS;
  LValor := Trim(GetEnvironmentVariable('ERP_JWT_EXPIRACAO_HORAS'));
  if LValor <> '' then
    Result := StrToIntDef(LValor, JWT_EXPIRACAO_PADRAO_HORAS);
  { Evita token eterno por valor absurdo ou negativo. }
  if Result < 1 then
    Result := 1;
  if Result > 24 * 30 then
    Result := 24 * 30;
end;

procedure ValidarConfiguracaoJWT;
var
  LSegredo: string;
begin
  LSegredo := SegredoJWT;
  if AmbienteProducao then
  begin
    if (LSegredo = JWT_SECRET_PADRAO_DEV) or
       (Length(LSegredo) < JWT_TAMANHO_MINIMO_SEGREDO) then
      raise Exception.Create(
        'Configuracao insegura: em producao defina ERP_JWT_SECRET com ao ' +
        'menos ' + IntToStr(JWT_TAMANHO_MINIMO_SEGREDO) + ' caracteres. ' +
        'A API nao pode iniciar com o segredo padrao de desenvolvimento.');
  end
  else if (not JAvisouSegredoDev) and (LSegredo = JWT_SECRET_PADRAO_DEV) then
  begin
    JAvisouSegredoDev := True;
    WriteLn(ErrOutput, 'AVISO: ERP_JWT_SECRET nao definido; usando o segredo ' +
      'padrao de desenvolvimento. Defina a variavel antes de publicar.');
  end;
end;

function Base64URLEncode(const AData: string): string;
begin
  Result := EncodeStringBase64(AData);
  Result := StringReplace(Result, '+', '-', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '=', '', [rfReplaceAll]);
end;

function Base64URLDecode(const AData: string): string;
var
  LData: string;
begin
  LData := AData;
  LData := StringReplace(LData, '-', '+', [rfReplaceAll]);
  LData := StringReplace(LData, '_', '/', [rfReplaceAll]);
  while Length(LData) mod 4 <> 0 do
    LData := LData + '=';
  Result := DecodeStringBase64(LData);
end;

{ Assinatura HS256 real (RFC 2104 sobre SHA-256). A forma crua de
  32 bytes é o que a RFC 7519 manda codificar em Base64URL. }
function Assinar(const ADados: string): string;
begin
  Result := Base64URLEncode(HMAC_SHA256_Raw(ADados, SegredoJWT));
end;

{ Comparação de assinatura em tempo constante: percorre todos os
  caracteres acumulando a diferença, sem sair na primeira divergência. }
function AssinaturaIgual(const A, B: string): Boolean;
var
  LDif: Integer;
  I: Integer;
begin
  LDif := Length(A) xor Length(B);
  for I := 1 to Length(A) do
    if I <= Length(B) then
      LDif := LDif or (Ord(A[I]) xor Ord(B[I]))
    else
      LDif := LDif or Ord(A[I]);
  for I := Length(A) + 1 to Length(B) do
    LDif := LDif or Ord(B[I]);
  Result := LDif = 0;
end;

function GerarToken(AUsuarioId: Int64; const ANome, ALogin: string; AEmpresaId: Int64): string;
var
  LHeader, LPayload, LSignature: string;
  LHeaderJSON, LPayloadJSON: TJSONObject;
begin
  LHeaderJSON := TJSONObject.Create;
  try
    LHeaderJSON.Add('alg', 'HS256');
    LHeaderJSON.Add('typ', 'JWT');
    LHeader := Base64URLEncode(LHeaderJSON.AsJSON);
  finally
    LHeaderJSON.Free;
  end;

  LPayloadJSON := TJSONObject.Create;
  try
    LPayloadJSON.Add('sub', AUsuarioId);
    LPayloadJSON.Add('nome', ANome);
    LPayloadJSON.Add('login', ALogin);
    LPayloadJSON.Add('empresa_id', AEmpresaId);
    LPayloadJSON.Add('iat', DateTimeToUnix(Now));
    LPayloadJSON.Add('exp', DateTimeToUnix(IncHour(Now, HorasExpiracaoJWT)));
    LPayload := Base64URLEncode(LPayloadJSON.AsJSON);
  finally
    LPayloadJSON.Free;
  end;

  LSignature := Assinar(LHeader + '.' + LPayload);
  Result := LHeader + '.' + LPayload + '.' + LSignature;
end;

function ValidarToken(const AToken: string): Boolean;
var
  LParts: TStringList;
  LExpectedSig, LPayloadStr: string;
  LPayload: TJSONObject;
  LExp: Int64;
begin
  Result := False;
  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '.';
    LParts.DelimitedText := AToken;

    if LParts.Count <> 3 then Exit;

    { compara a assinatura em tempo constante (evita timing attack) }
    LExpectedSig := Assinar(LParts[0] + '.' + LParts[1]);
    if (Length(LExpectedSig) <> Length(LParts[2])) or
       (not AssinaturaIgual(LExpectedSig, LParts[2])) then Exit;

    LPayloadStr := Base64URLDecode(LParts[1]);
    LPayload := TJSONObject(GetJSON(LPayloadStr));
    try
      LExp := LPayload.Get('exp', Int64(0));
      if UnixToDateTime(LExp) < Now then Exit;
      Result := True;
    finally
      LPayload.Free;
    end;
  finally
    LParts.Free;
  end;
end;

function ExtrairDadosToken(const AToken: string): TJSONObject;
var
  LParts: TStringList;
  LPayloadStr: string;
begin
  Result := nil;
  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '.';
    LParts.DelimitedText := AToken;
    if LParts.Count = 3 then
    begin
      LPayloadStr := Base64URLDecode(LParts[1]);
      Result := TJSONObject(GetJSON(LPayloadStr));
    end;
  finally
    LParts.Free;
  end;
end;

procedure MiddlewareJWT(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LAuth, LToken: string;
begin
  // Rotas publicas: nao exigem token
  if SameText(Req.RawWebRequest.PathInfo, '/api/login') or
     SameText(Req.RawWebRequest.PathInfo, '/api/health') then
  begin
    Next;
    Exit;
  end;

  LAuth := Req.Headers['Authorization'];
  if LAuth = '' then
  begin
    Res.Send('{"error":"Token não informado"}').Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  LToken := StringReplace(LAuth, 'Bearer ', '', [rfIgnoreCase]);
  if not ValidarToken(LToken) then
  begin
    Res.Send('{"error":"Token inválido ou expirado"}').Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  Next;
end;

{ Usuario e empresa autenticados, a partir das claims do token. }
procedure DadosDoToken(Req: THorseRequest; out AUsuarioId, AEmpresaId: Int64);
var
  LToken: string;
  LDados: TJSONObject;
begin
  AUsuarioId := 0;
  AEmpresaId := 0;
  LToken := StringReplace(Req.Headers['Authorization'], 'Bearer ',
    '', [rfIgnoreCase]);
  LDados := ExtrairDadosToken(LToken);
  if LDados <> nil then
  try
    AUsuarioId := LDados.Get('sub', Int64(0));
    AEmpresaId := LDados.Get('empresa_id', Int64(0));
  finally
    LDados.Free;
  end;
end;

end.
