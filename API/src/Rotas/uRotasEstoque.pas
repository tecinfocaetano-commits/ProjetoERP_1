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
  SysUtils, fpjson, jsonparser, SQLDB, uConexao;

procedure GetEstoque(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
begin
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
      'WHERE P.CONTROLA_ESTOQUE = ''S'' ORDER BY P.DESCRICAO';
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
  LConexao: TConexao;
  LQuery: TSQLQuery;
begin
  try
    LBody := TJSONObject(GetJSON(Req.Body));
    try
      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LQuery.SQL.Text :=
          'INSERT INTO MOVIMENTO_ESTOQUE (ID, EMPRESA_ID, PRODUTO_ID, TIPO, QUANTIDADE, ' +
          'CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, USUARIO_ID) ' +
          'VALUES (GEN_ID(GEN_MOVIMENTO_ESTOQUE_ID, 1), 1, :PROD, :TIPO, :QTD, :CUSTO, :DOC, :OBS, 1)';
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
