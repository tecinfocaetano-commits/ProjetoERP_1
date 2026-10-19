unit uHMAC;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - HMAC-SHA256 (RFC 2104 / FIPS 198-1)

  Combinado ao SHA-256 em Pascal puro de uSenhaHash, dá um
  HMAC-SHA256 de verdade — usado pelo middleware JWT da API para
  assinar tokens "alg: HS256" sem mentir no rótulo.

  Vetor de teste RFC 4231, caso 1:
    chave  = 20 bytes de 0x0B
    dados  = "Hi There"
    saída  = b0344c61d8db38535ca8afceaf0bf12b
             881dc200c9833da726e9376c2e32cff7
  (verificado em uHMACTest)

  A unit é compartilhada pelo Desktop e pela API: o caminho de
  unit "Desktop\src\Utils" está nos dois builds.
  ============================================================ }

interface

{ HMAC-SHA256 em hex minúsculo (64 caracteres). }
function HMAC_SHA256_Hex(const ADados, AChave: string): string;

{ HMAC-SHA256 em 32 bytes crus (string de 32 caracteres). É a
  forma usada pela assinatura JWT: os bytes crus entram no
  Base64URL, como manda a RFC 7519. }
function HMAC_SHA256_Raw(const ADados, AChave: string): string;

implementation

uses
  SysUtils, uSenhaHash;

const
  BLOCO = 64; { bytes do bloco do SHA-256 (ipad/opad) }

function HMAC_SHA256_Raw(const ADados, AChave: string): string;
var
  LChave, LInner, LIPad, LOPad: string;
  I: Integer;
begin
  { chave maior que um bloco é resumida; menor é zero-padded }
  if Length(AChave) > BLOCO then
    LChave := SHA256Raw(AChave)
  else
    LChave := AChave;

  LIPad := '';
  LOPad := '';
  for I := 1 to BLOCO do
  begin
    if I <= Length(LChave) then
    begin
      LIPad := LIPad + Chr(Ord(LChave[I]) xor $36);
      LOPad := LOPad + Chr(Ord(LChave[I]) xor $5C);
    end
    else
    begin
      { byte de preenchimento (0) XOR o constante do ipad/opad }
      LIPad := LIPad + Chr($36);
      LOPad := LOPad + Chr($5C);
    end;
  end;

  { inner = H(ipad || dados); outer = H(opad || inner) }
  LInner := SHA256Raw(LIPad + ADados);
  Result := SHA256Raw(LOPad + LInner);
end;

function HMAC_SHA256_Hex(const ADados, AChave: string): string;
var
  LRaw: string;
  I: Integer;
begin
  LRaw := HMAC_SHA256_Raw(ADados, AChave);
  Result := '';
  for I := 1 to Length(LRaw) do
    Result := Result + LowerCase(IntToHex(Ord(LRaw[I]), 2));
end;

end.
