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
  JWT_SECRET = 'ERP2026_SECRET_KEY_CHANGE_IN_PRODUCTION';
  JWT_EXPIRATION_HOURS = 8;

function GerarToken(AUsuarioId: Int64; const ANome, ALogin: string; AEmpresaId: Int64): string;
function ValidarToken(const AToken: string): Boolean;
function ExtrairDadosToken(const AToken: string): TJSONObject;
procedure MiddlewareJWT(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);

implementation

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
  Result := Base64URLEncode(HMAC_SHA256_Raw(ADados, JWT_SECRET));
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
    LPayloadJSON.Add('exp', DateTimeToUnix(IncHour(Now, JWT_EXPIRATION_HOURS)));
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
  if SameText(Req.RawWebRequest.PathInfo, '/api/login') then
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

end.
