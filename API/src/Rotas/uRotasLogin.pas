unit uRotasLogin;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rota de Login
  Endpoint: POST /api/login
  ============================================================ }

interface

uses
  Horse, fpjson, jsonparser;

procedure RotaLogin(Req: THorseRequest; Res: THorseResponse);

implementation

uses
  SysUtils, SQLDB, md5, uConexao, uMiddlewareJWT;

procedure RotaLogin(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LData: TJSONData;
  LLogin, LSenha: string;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LResult: TJSONObject;
  LToken: string;
begin
  try
    LData := nil;
    try
      LData := GetJSON(Req.Body);
    except
      LData := nil;
    end;
    if not (LData is TJSONObject) then
    begin
      if LData <> nil then
        LData.Free;
      Res.Send('{"error":"Corpo da requisição inválido (objeto JSON esperado)"}').Status(THTTPStatus.BadRequest);
      Exit;
    end;
    LBody := TJSONObject(LData);
    try
      LLogin := LBody.Get('login', '');
      LSenha := LBody.Get('senha', '');
    finally
      LBody.Free;
    end;

    if (LLogin = '') or (LSenha = '') then
    begin
      Res.Send('{"error":"Login e senha são obrigatórios"}').Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LConexao := TConexao.GetInstance;
    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := LConexao.Connection;
      LQuery.Transaction := LConexao.Transaction;
      LQuery.SQL.Text :=
        'SELECT U.ID, U.NOME, U.LOGIN, U.EMPRESA_ID ' +
        'FROM USUARIO U WHERE U.LOGIN = :LOGIN AND U.SENHA = :SENHA AND U.ATIVO = ''A''';
      LQuery.ParamByName('LOGIN').AsString := LLogin;
      LQuery.ParamByName('SENHA').AsString := LSenha;
      LQuery.Open;

      if LQuery.IsEmpty then
      begin
        Res.Send('{"error":"Credenciais inválidas"}').Status(THTTPStatus.Unauthorized);
        Exit;
      end;

      LToken := GerarToken(
        LQuery.FieldByName('ID').AsLargeInt,
        LQuery.FieldByName('NOME').AsString,
        LQuery.FieldByName('LOGIN').AsString,
        LQuery.FieldByName('EMPRESA_ID').AsLargeInt
      );

      LResult := TJSONObject.Create;
      try
        LResult.Add('token', LToken);
        LResult.Add('usuario_id', LQuery.FieldByName('ID').AsLargeInt);
        LResult.Add('nome', LQuery.FieldByName('NOME').AsString);
        LResult.Add('empresa_id', LQuery.FieldByName('EMPRESA_ID').AsLargeInt);
        Res.Send(LResult.AsJSON).Status(THTTPStatus.OK);
      finally
        LResult.Free;
      end;
    finally
      LQuery.Free;
    end;
  except
    on E: Exception do
      Res.Send('{"error":"' + E.Message + '"}').Status(THTTPStatus.InternalServerError);
  end;
end;

end.
