unit uMiddlewareCORS;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Middleware CORS
  Descrição: Cross-Origin Resource Sharing
  ============================================================ }

interface

uses
  Horse;

procedure MiddlewareCORS(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);

implementation

procedure MiddlewareCORS(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  Res.RawWebResponse.SetCustomHeader('Access-Control-Allow-Origin', '*');
  Res.RawWebResponse.SetCustomHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  Res.RawWebResponse.SetCustomHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if Req.RawWebRequest.Method = 'OPTIONS' then
  begin
    Res.Send('').Status(THTTPStatus.NoContent);
    Exit;
  end;

  Next;
end;

end.
