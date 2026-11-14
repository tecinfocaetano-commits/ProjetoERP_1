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
  SysUtils, SQLDB, uConexao, uMiddlewareJWT, uSenhaHash;

procedure RotaLogin(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LData: TJSONData;
  LLogin, LSenha: string;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LResult: TJSONObject;
  LToken: string;
  LSenhaGuardada: string;
  LUsuarioId, LEmpresaId: Int64;
  LEmpresaIdPedido: Int64;
  LEmpresaAtual: Int64;
  LEmpresas: string;
  LDadoEmpresa: TJSONData;
  LNome, LLoginDb: string;
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
      LEmpresaIdPedido := 0;
      LDadoEmpresa := LBody.Find('empresa_id');
      if LDadoEmpresa <> nil then
        LEmpresaIdPedido := StrToInt64Def(Trim(LDadoEmpresa.AsString), 0);
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
      { a senha não entra no WHERE: o banco guarda SHA-256 e a
        comparação é feita em código (uSenhaHash) — aceita também
        senha legada em texto puro, com migração no login }
      LQuery.SQL.Text :=
        'SELECT U.ID, U.NOME, U.LOGIN, U.EMPRESA_ID, U.SENHA ' +
        'FROM USUARIO U WHERE U.LOGIN = :LOGIN AND U.ATIVO = ''A''';
      if LEmpresaIdPedido > 0 then
        LQuery.SQL.Text := LQuery.SQL.Text + ' AND U.EMPRESA_ID = :EMP';
      LQuery.ParamByName('LOGIN').AsString := LLogin;
      if LEmpresaIdPedido > 0 then
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaIdPedido;
      LQuery.Open;

      if LQuery.IsEmpty then
      begin
        Res.Send('{"error":"Credenciais inválidas"}').Status(THTTPStatus.Unauthorized);
        Exit;
      end;

      { Sem empresa_id, o login precisa identificar uma unica empresa.
        Antes isto pegava a primeira linha silenciosamente. }
      if LEmpresaIdPedido = 0 then
      begin
        LQuery.First;
        LEmpresaAtual := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
        LEmpresas := '';
        LQuery.Next;
        while not LQuery.EOF do
        begin
          if LQuery.FieldByName('EMPRESA_ID').AsLargeInt <> LEmpresaAtual then
          begin
            if LEmpresas = '' then
              LEmpresas := IntToStr(LEmpresaAtual);
            LEmpresas := LEmpresas + ', ' +
              IntToStr(LQuery.FieldByName('EMPRESA_ID').AsLargeInt);
          end;
          LQuery.Next;
        end;
        if LEmpresas <> '' then
        begin
          Res.Send('{"error":"Login existe em mais de uma empresa (' +
            LEmpresas + '). Informe empresa_id."}').Status(THTTPStatus.BadRequest);
          Exit;
        end;
        LQuery.First;
      end;

      LSenhaGuardada := LQuery.FieldByName('SENHA').AsString;
      if not SenhaConfere(LSenha, LSenhaGuardada) then
      begin
        Res.Send('{"error":"Credenciais inválidas"}').Status(THTTPStatus.Unauthorized);
        Exit;
      end;

      LUsuarioId := LQuery.FieldByName('ID').AsLargeInt;
      LNome := LQuery.FieldByName('NOME').AsString;
      LLoginDb := LQuery.FieldByName('LOGIN').AsString;
      LEmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;

      { migração progressiva: senha ainda em texto puro → regrava em SHA-256 }
      if PrecisaMigrarSenha(LSenhaGuardada) then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'UPDATE USUARIO SET SENHA = :SENHA WHERE ID = :ID';
        LQuery.ParamByName('SENHA').AsString := HashSenha(LSenha);
        LQuery.ParamByName('ID').AsLargeInt := LUsuarioId;
        try
          LConexao.IniciarTransacao;
          LQuery.ExecSQL;
          LConexao.Confirmar;
        except
          on E: Exception do
          begin
            { falha na migração não derruba o login: só loga }
            try
              LConexao.Cancelar;
            except
            end;
          end;
        end;
      end;

      LToken := GerarToken(LUsuarioId, LNome, LLoginDb, LEmpresaId);

      LResult := TJSONObject.Create;
      try
        LResult.Add('token', LToken);
        LResult.Add('usuario_id', LUsuarioId);
        LResult.Add('nome', LNome);
        LResult.Add('empresa_id', LEmpresaId);
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
