unit uMiddlewareSessao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - API - Contexto da sessao por requisicao (D3)
  ------------------------------------------------------------
  Os Services do desktop leem TSessao.GetInstance para saber a
  empresa/usuario da operacao. Na API isso nao pode ser um singleton:
  cada requisicao roda numa thread e outro usuario pode responder ao
  mesmo tempo. Este middleware roda depois do JWT, transforma as claims
  do token num contexto de thread e remove ao final, mesmo se a rota
  levantar excecao.
  ============================================================ }

interface

uses
  Horse;

procedure MiddlewareSessao(Req: THorseRequest; Res: THorseResponse;
  Next: TNextProc);

implementation

uses
  SysUtils, uSessao, uMiddlewareJWT;

procedure MiddlewareSessao(Req: THorseRequest; Res: THorseResponse;
  Next: TNextProc);
var
  LUsuarioId, LEmpresaId: Int64;
begin
  { Rotas publicas nao tem token nem contexto: mesma regra do MiddlewareJWT. }
  if SameText(Req.RawWebRequest.PathInfo, '/api/login') or
     SameText(Req.RawWebRequest.PathInfo, '/api/health') then
  begin
    Next;
    Exit;
  end;

  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send('{"error":"Token sem empresa. Entre novamente."}')
      .Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  TSessao.DefinirContexto(LUsuarioId, LEmpresaId, 0, '', '', False);
  try
    Next;
  finally
    TSessao.LimparContexto;
  end;
end;

end.
