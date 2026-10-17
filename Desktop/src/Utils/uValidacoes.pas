unit uValidacoes;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Utilitários de Validação
  Descrição: Funções de validação de CPF, CNPJ, Email, etc.
  ============================================================ }

interface

uses
  Classes, SysUtils;

function ValidarCPF(const ACPF: string): Boolean;
function ValidarCNPJ(const ACNPJ: string): Boolean;
function ValidarEmail(const AEmail: string): Boolean;
function ApenasNumeros(const ATexto: string): string;
function FormatarCPF(const ACPF: string): string;
function FormatarCNPJ(const ACNPJ: string): string;
function FormatarCEP(const ACEP: string): string;
function FormatarTelefone(const ATelefone: string): string;

implementation

function ApenasNumeros(const ATexto: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ATexto) do
    if ATexto[I] in ['0'..'9'] then
      Result := Result + ATexto[I];
end;

function ValidarCPF(const ACPF: string): Boolean;
var
  LNumeros: string;
  LSoma, I, LDigito1, LDigito2: Integer;
begin
  Result := False;
  LNumeros := ApenasNumeros(ACPF);

  if Length(LNumeros) <> 11 then Exit;

  // Verifica se todos os dígitos são iguais
  if (LNumeros = StringOfChar(LNumeros[1], 11)) then Exit;

  // Calcula primeiro dígito verificador
  LSoma := 0;
  for I := 1 to 9 do
    LSoma := LSoma + StrToInt(LNumeros[I]) * (11 - I);
  LDigito1 := (LSoma * 10) mod 11;
  if LDigito1 = 10 then LDigito1 := 0;

  // Calcula segundo dígito verificador
  LSoma := 0;
  for I := 1 to 10 do
    LSoma := LSoma + StrToInt(LNumeros[I]) * (12 - I);
  LDigito2 := (LSoma * 10) mod 11;
  if LDigito2 = 10 then LDigito2 := 0;

  Result := (LDigito1 = StrToInt(LNumeros[10])) and
            (LDigito2 = StrToInt(LNumeros[11]));
end;

function ValidarCNPJ(const ACNPJ: string): Boolean;
var
  LNumeros: string;
  LSoma, I, LDigito1, LDigito2: Integer;
const
  Peso1: array[1..12] of Integer = (5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
  Peso2: array[1..13] of Integer = (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
begin
  Result := False;
  LNumeros := ApenasNumeros(ACNPJ);

  if Length(LNumeros) <> 14 then Exit;

  // Verifica se todos os dígitos são iguais
  if (LNumeros = StringOfChar(LNumeros[1], 14)) then Exit;

  // Calcula primeiro dígito verificador
  LSoma := 0;
  for I := 1 to 12 do
    LSoma := LSoma + StrToInt(LNumeros[I]) * Peso1[I];
  LDigito1 := LSoma mod 11;
  if LDigito1 < 2 then LDigito1 := 0
  else LDigito1 := 11 - LDigito1;

  // Calcula segundo dígito verificador
  LSoma := 0;
  for I := 1 to 13 do
    LSoma := LSoma + StrToInt(LNumeros[I]) * Peso2[I];
  LDigito2 := LSoma mod 11;
  if LDigito2 < 2 then LDigito2 := 0
  else LDigito2 := 11 - LDigito2;

  Result := (LDigito1 = StrToInt(LNumeros[13])) and
            (LDigito2 = StrToInt(LNumeros[14]));
end;

function ValidarEmail(const AEmail: string): Boolean;
var
  LPosArroba, LPosPonto, I: Integer;
begin
  Result := False;
  LPosArroba := Pos('@', AEmail);
  if LPosArroba < 2 then Exit;

  LPosPonto := 0;
  // Procura o último ponto após o @
  for I := Length(AEmail) downto LPosArroba do
    if AEmail[I] = '.' then
    begin
      LPosPonto := I;
      Break;
    end;

  Result := (LPosPonto > LPosArroba + 1) and (LPosPonto < Length(AEmail));
end;

function FormatarCPF(const ACPF: string): string;
var
  LNum: string;
begin
  LNum := ApenasNumeros(ACPF);
  if Length(LNum) = 11 then
    Result := Format('%s.%s.%s-%s',
      [Copy(LNum, 1, 3), Copy(LNum, 4, 3), Copy(LNum, 7, 3), Copy(LNum, 10, 2)])
  else
    Result := ACPF;
end;

function FormatarCNPJ(const ACNPJ: string): string;
var
  LNum: string;
begin
  LNum := ApenasNumeros(ACNPJ);
  if Length(LNum) = 14 then
    Result := Format('%s.%s.%s/%s-%s',
      [Copy(LNum, 1, 2), Copy(LNum, 3, 3), Copy(LNum, 6, 3),
       Copy(LNum, 9, 4), Copy(LNum, 13, 2)])
  else
    Result := ACNPJ;
end;

function FormatarCEP(const ACEP: string): string;
var
  LNum: string;
begin
  LNum := ApenasNumeros(ACEP);
  if Length(LNum) = 8 then
    Result := Format('%s-%s', [Copy(LNum, 1, 5), Copy(LNum, 6, 3)])
  else
    Result := ACEP;
end;

function FormatarTelefone(const ATelefone: string): string;
var
  LNum: string;
begin
  LNum := ApenasNumeros(ATelefone);
  case Length(LNum) of
    10: Result := Format('(%s) %s-%s',
          [Copy(LNum, 1, 2), Copy(LNum, 3, 4), Copy(LNum, 7, 4)]);
    11: Result := Format('(%s) %s-%s',
          [Copy(LNum, 1, 2), Copy(LNum, 3, 5), Copy(LNum, 8, 4)]);
  else
    Result := ATelefone;
  end;
end;

end.
