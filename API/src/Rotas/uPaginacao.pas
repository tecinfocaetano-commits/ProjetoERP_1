unit uPaginacao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - F6 - Paginação opcional nas listagens da API
  ------------------------------------------------------------
  Sem parâmetros, a rota continua devolvendo o array de até 100
  registros (contrato usado pelo app Android hoje).

  Com ?pagina=N e/ou ?por_pagina=M, a resposta passa a ser um objeto
  com total, pagina, por_pagina, total_paginas e itens (array).

  Valores inválidos são normalizados (nunca viram 500):
    pagina < 1            -> 1
    por_pagina < 1        -> 50
    por_pagina > 200      -> 200
  ============================================================ }

interface

uses
  Horse, fpjson;

type
  TPaginacao = record
    Ativa: Boolean;
    Pagina: Integer;
    PorPagina: Integer;
  end;

function LerPaginacao(Req: THorseRequest; out P: TPaginacao): Boolean;
function PrimeiraLinha(const P: TPaginacao): Integer;
function UltimaLinha(const P: TPaginacao): Integer;
procedure EnviarPagina(Res: THorseResponse; AItens: TJSONArray;
  ATotal: Int64; const P: TPaginacao);

implementation

uses
  SysUtils;

function LerPaginacao(Req: THorseRequest; out P: TPaginacao): Boolean;
var
  SPagina, SPorPagina: string;
begin
  SPagina := Trim(Req.Query['pagina']);
  SPorPagina := Trim(Req.Query['por_pagina']);

  P.Ativa := (SPagina <> '') or (SPorPagina <> '');
  P.Pagina := StrToIntDef(SPagina, 1);
  if P.Pagina < 1 then
    P.Pagina := 1;
  if P.Pagina > 100000 then
    P.Pagina := 100000;

  P.PorPagina := StrToIntDef(SPorPagina, 50);
  if P.PorPagina < 1 then
    P.PorPagina := 50;
  if P.PorPagina > 200 then
    P.PorPagina := 200;

  Result := P.Ativa;
end;

function PrimeiraLinha(const P: TPaginacao): Integer;
begin
  Result := (P.Pagina - 1) * P.PorPagina + 1;
end;

function UltimaLinha(const P: TPaginacao): Integer;
begin
  Result := P.Pagina * P.PorPagina;
end;

procedure EnviarPagina(Res: THorseResponse; AItens: TJSONArray;
  ATotal: Int64; const P: TPaginacao);
var
  LObj: TJSONObject;
  LTotalPaginas: Int64;
begin
  if ATotal <= 0 then
    LTotalPaginas := 0
  else
    LTotalPaginas := (ATotal + P.PorPagina - 1) div P.PorPagina;

  LObj := TJSONObject.Create;
  try
    LObj.Add('total', ATotal);
    LObj.Add('pagina', P.Pagina);
    LObj.Add('por_pagina', P.PorPagina);
    LObj.Add('total_paginas', LTotalPaginas);
    { TJSONObject.Add assume a posse do TJSONData; clonamos para que a
      rota continue liberando o array original sem double-free. }
    LObj.Add('itens', TJSONArray(AItens.Clone));
    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
  finally
    LObj.Free;
  end;
end;

end.
