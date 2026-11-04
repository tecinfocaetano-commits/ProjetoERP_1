unit uRotasEstoque;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rotas de Estoque
  Endpoints: GET/POST /api/estoque
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasEstoque;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT;

procedure GetEstoque(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send('{"error":"Token sem empresa. Entre novamente."}')
      .Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT P.ID, P.CODIGO, P.DESCRICAO, COALESCE(E.QUANTIDADE, 0) AS QUANTIDADE, ' +
      'P.ESTOQUE_MINIMO, P.ESTOQUE_MAXIMO, P.PRECO_CUSTO, ' +
      '(COALESCE(E.QUANTIDADE, 0) * P.PRECO_CUSTO) AS VALOR_ESTOQUE ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
      'WHERE P.CONTROLA_ESTOQUE = ''S'' AND P.EMPRESA_ID = :EMP ORDER BY P.DESCRICAO';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;

    LArray := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('codigo', LQuery.FieldByName('CODIGO').AsString);
      LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
      LObj.Add('quantidade', LQuery.FieldByName('QUANTIDADE').AsFloat);
      LObj.Add('estoque_minimo', LQuery.FieldByName('ESTOQUE_MINIMO').AsFloat);
      LObj.Add('estoque_maximo', LQuery.FieldByName('ESTOQUE_MAXIMO').AsFloat);
      LObj.Add('valor_estoque', LQuery.FieldByName('VALOR_ESTOQUE').AsFloat);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

procedure PostMovimento(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LData: TJSONData;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LUsuarioId, LEmpresaId: Int64;
begin
  try
    DadosDoToken(Req, LUsuarioId, LEmpresaId);
    if LEmpresaId <= 0 then
    begin
      Res.Send('{"error":"Token sem empresa. Entre novamente."}')
        .Status(THTTPStatus.Unauthorized);
      Exit;
    end;

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
      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LQuery.SQL.Text :=
          'INSERT INTO MOVIMENTO_ESTOQUE (ID, EMPRESA_ID, PRODUTO_ID, TIPO, QUANTIDADE, ' +
          'CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, USUARIO_ID) ' +
          'VALUES (GEN_ID(GEN_MOVIMENTO_ESTOQUE_ID, 1), :EMP, :PROD, :TIPO, :QTD, :CUSTO, :DOC, :OBS, :USU)';
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LQuery.ParamByName('USU').AsLargeInt := LUsuarioId;
        LQuery.ParamByName('PROD').AsLargeInt := LBody.Get('produto_id', Int64(0));
        LQuery.ParamByName('TIPO').AsString := LBody.Get('tipo', 'E');
        LQuery.ParamByName('QTD').AsFloat := LBody.Get('quantidade', Double(0));
        LQuery.ParamByName('CUSTO').AsFloat := LBody.Get('custo_unitario', Double(0));
        LQuery.ParamByName('DOC').AsString := LBody.Get('documento', '');
        LQuery.ParamByName('OBS').AsString := LBody.Get('observacao', '');
        LQuery.ExecSQL;
        LConexao.Confirmar;
        Res.Send('{"message":"Movimento registrado com sucesso"}').Status(THTTPStatus.Created);
      finally
        LQuery.Free;
      end;
    finally
      LBody.Free;
    end;
  except
    on E: Exception do
      Res.Send('{"error":"' + E.Message + '"}').Status(THTTPStatus.InternalServerError);
  end;
end;

procedure RegistrarRotasEstoque;
begin
  THorse.Get('/api/estoque', @GetEstoque);
  THorse.Post('/api/estoque/movimento', @PostMovimento);
end;

end.
