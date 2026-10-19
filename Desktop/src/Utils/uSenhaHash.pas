unit uSenhaHash;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Hash de senha (SHA-256)

  A instalação do FPC 3.2.2 usada pelo projeto não traz a unit
  "sha256" do pacote hash (só md5/sha1), e a regra do projeto é
  não instalar pacotes novos — então o SHA-256 é implementado
  aqui em Pascal puro (FIPS 180-4), sem dependências externas.

  A unit é compartilhada pelo Desktop (login e cadastro de
  usuários) e pela API REST (rota de login): o caminho de unit
  "Desktop\src\Utils" está nos dois builds.

  Vetores de teste conhecidos (uSenhaHashTest):
    SHA256('')        = e3b0c44298fc1c149afbf4c8996fb924
                        27ae41e4649b934ca495991b7852b855
    SHA256('abc')     = ba7816bf8f01cfea414140de5dae2223
                        b00361a396177a9cb410ff61f20015ad
    SHA256('admin123')= 240be518fabd2724ddb6f04eeb1da596
                        7448d7e831c08c8fa822809f74c720a9

  Observação: senhas com acento são hasheadas pelos bytes do
  texto (codepage do sistema no Desktop; a API envia UTF-8 via
  JSON). Senhas ASCII (regra do cadastro) são idênticas nos
  dois mundos.
  ============================================================ }

interface

{ SHA-256 puro: devolve o hash em hex minúsculo (64 caracteres). }
function SHA256Hex(const ATexto: string): string;

{ Hash de senha de usuário (mesmo que SHA256Hex; ponto único de
  decisão sobre o algoritmo guardado no banco). }
function HashSenha(const ASenha: string): string;

{ True se o valor armazenado tem cara de hash SHA-256
  (64 caracteres hexadecimais). }
function EhHashSHA256(const AValor: string): boolean;

{ Confere a senha digitada contra a guardada no banco:
  - se a guardada é hash SHA-256, compara o hash da digitada;
  - senão (legado em texto puro), compara o texto — migração
    progressiva: quem logar com senha antiga volta a ser
    migrado para hash pelo próprio login. }
function SenhaConfere(const ASenhaDigitada, ASenhaGuardada: string): boolean;

{ True quando a senha guardada ainda está em texto puro e deve
  ser regravada como hash no próximo login bem-sucedido. }
function PrecisaMigrarSenha(const ASenhaGuardada: string): boolean;

implementation

uses
  SysUtils;

const
  K: array[0..63] of LongWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2);

type
  TSHA256State = array[0..7] of LongWord;

function Rotr(X: LongWord; N: Byte): LongWord; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

{ Transforma um bloco de 64 bytes no estado (FIPS 180-4, 4.1.2). }
procedure Transform(var AState: TSHA256State; const ABlock: array of Byte);
var
  W: array[0..63] of LongWord;
  A, B, C, D, E, F, G, H, T1, T2, S0, S1: LongWord;
  I: Integer;
begin
  for I := 0 to 15 do
    W[I] := (LongWord(ABlock[I * 4]) shl 24) or
            (LongWord(ABlock[I * 4 + 1]) shl 16) or
            (LongWord(ABlock[I * 4 + 2]) shl 8) or
            LongWord(ABlock[I * 4 + 3]);

  for I := 16 to 63 do
  begin
    S0 := Rotr(W[I - 15], 7) xor Rotr(W[I - 15], 18) xor (W[I - 15] shr 3);
    S1 := Rotr(W[I - 2], 17) xor Rotr(W[I - 2], 19) xor (W[I - 2] shr 10);
    W[I] := W[I - 16] + S0 + W[I - 7] + S1;
  end;

  A := AState[0]; B := AState[1]; C := AState[2]; D := AState[3];
  E := AState[4]; F := AState[5]; G := AState[6]; H := AState[7];

  for I := 0 to 63 do
  begin
    S1 := Rotr(E, 6) xor Rotr(E, 11) xor Rotr(E, 25);
    T1 := H + S1 + ((E and F) xor ((not E) and G)) + K[I] + W[I];
    S0 := Rotr(A, 2) xor Rotr(A, 13) xor Rotr(A, 22);
    T2 := S0 + ((A and B) xor (A and C) xor (B and C));
    H := G; G := F; F := E; E := D + T1;
    D := C; C := B; B := A; A := T1 + T2;
  end;

  AState[0] := AState[0] + A; AState[1] := AState[1] + B;
  AState[2] := AState[2] + C; AState[3] := AState[3] + D;
  AState[4] := AState[4] + E; AState[5] := AState[5] + F;
  AState[6] := AState[6] + G; AState[7] := AState[7] + H;
end;

function SHA256Hex(const ATexto: string): string;
var
  LState: TSHA256State;
  LBlock: array[0..63] of Byte;
  LLen, LPos, LN: Integer;
  LBits: QWord;
  LJ: Integer;
begin
  LState[0] := $6a09e667; LState[1] := $bb67ae85;
  LState[2] := $3c6ef372; LState[3] := $a54ff53a;
  LState[4] := $510e527f; LState[5] := $9b05688c;
  LState[6] := $1f83d9ab; LState[7] := $5be0cd19;

  LLen := Length(ATexto);
  { mensagem + padding: 0x80, zeros até sobrar 8 bytes do fim do
    bloco e o tamanho original em bits (big-endian, 8 bytes) }
  LPos := 1;
  while LPos <= LLen do
  begin
    FillChar(LBlock, SizeOf(LBlock), 0);
    LN := 0;
    while (LN < 64) and (LPos <= LLen) do
    begin
      LBlock[LN] := Ord(ATexto[LPos]);
      Inc(LN);
      Inc(LPos);
    end;
    if LN = 64 then
      Transform(LState, LBlock)
    else
    begin
      LBlock[LN] := $80;
      if LN >= 56 then
      begin
        Transform(LState, LBlock);
        FillChar(LBlock, SizeOf(LBlock), 0);
      end;
      LBits := QWord(LLen) * 8;
      for LJ := 0 to 7 do
        LBlock[56 + LJ] := Byte((LBits shr (8 * (7 - LJ))) and $FF);
      Transform(LState, LBlock);
    end;
  end;
  { texto vazio (ou mensagem cujo último bloco já foi completo):
    garante o bloco final de padding }
  if (LLen = 0) or (LLen mod 64 = 0) then
  begin
    FillChar(LBlock, SizeOf(LBlock), 0);
    LBlock[0] := $80;
    LBits := QWord(LLen) * 8;
    for LJ := 0 to 7 do
      LBlock[56 + LJ] := Byte((LBits shr (8 * (7 - LJ))) and $FF);
    Transform(LState, LBlock);
  end;

  Result := '';
  for LJ := 0 to 7 do
    Result := Result + LowerCase(IntToHex(LState[LJ], 8));
end;

function HashSenha(const ASenha: string): string;
begin
  Result := SHA256Hex(ASenha);
end;

function EhHashSHA256(const AValor: string): boolean;
var
  I: Integer;
begin
  Result := Length(AValor) = 64;
  if not Result then
    Exit;
  for I := 1 to 64 do
    if not (AValor[I] in ['0'..'9', 'a'..'f', 'A'..'F']) then
    begin
      Result := False;
      Exit;
    end;
end;

function SenhaConfere(const ASenhaDigitada, ASenhaGuardada: string): boolean;
begin
  if EhHashSHA256(ASenhaGuardada) then
    Result := HashSenha(ASenhaDigitada) = LowerCase(ASenhaGuardada)
  else
    Result := ASenhaGuardada = ASenhaDigitada;
end;

function PrecisaMigrarSenha(const ASenhaGuardada: string): boolean;
begin
  Result := not EhHashSHA256(ASenhaGuardada);
end;

end.
