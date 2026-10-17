unit uRotasProdutos;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rotas de Produtos
  Endpoints: GET/POST /api/produtos
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasProdutos;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao;

procedure GetProdutos(Req: THorseRequest; Res: THorseResponse);
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
      'SELECT P.ID, P.CODIGO, P.DESCRICAO, P.PRECO_VENDA, P.PRECO_CUSTO, ' +
      'COALESCE(E.QUANTIDADE, 0) AS ESTOQUE, P.ATIVO ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
      'WHERE P.ATIVO = ''A'' ORDER BY P.DESCRICAO';
    LQuery.Open;

    LArray := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('codigo', LQuery.FieldByName('CODIGO').AsString);
      LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
      LObj.Add('preco_venda', LQuery.FieldByName('PRECO_VENDA').AsFloat);
      LObj.Add('preco_custo', LQuery.FieldByName('PRECO_CUSTO').AsFloat);
      LObj.Add('estoque', LQuery.FieldByName('ESTOQUE').AsFloat);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

procedure GetProdutoById(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LObj: TJSONObject;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT P.*, COALESCE(E.QUANTIDADE, 0) AS ESTOQUE FROM PRODUTO P ' +
      'LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID WHERE P.ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      Res.Send('{"error":"Produto não encontrado"}').Status(THTTPStatus.NotFound);
      Exit;
    end;

    LObj := TJSONObject.Create;
    LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
    LObj.Add('codigo', LQuery.FieldByName('CODIGO').AsString);
    LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
    LObj.Add('preco_venda', LQuery.FieldByName('PRECO_VENDA').AsFloat);
    LObj.Add('preco_custo', LQuery.FieldByName('PRECO_CUSTO').AsFloat);
    LObj.Add('ncm', LQuery.FieldByName('NCM').AsString);
    LObj.Add('estoque', LQuery.FieldByName('ESTOQUE').AsFloat);
    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
    LObj.Free;
  finally
    LQuery.Free;
  end;
end;

procedure PostProduto(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LData: TJSONData;
  LConexao: TConexao;
  LQuery: TSQLQuery;
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
      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LQuery.SQL.Text :=
          'INSERT INTO PRODUTO (ID, EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, DESCRICAO, ' +
          'PRECO_VENDA, PRECO_CUSTO, ATIVO, CONTROLA_ESTOQUE) ' +
          'VALUES (GEN_ID(GEN_PRODUTO_ID, 1), 1, :CAT, :UNI, :COD, :DESC, :PV, :PC, ''A'', ''S'')';
        LQuery.ParamByName('CAT').AsLargeInt := LBody.Get('categoria_id', Int64(1));
        LQuery.ParamByName('UNI').AsLargeInt := LBody.Get('unidade_id', Int64(1));
        LQuery.ParamByName('COD').AsString := LBody.Get('codigo', '');
        LQuery.ParamByName('DESC').AsString := LBody.Get('descricao', '');
        LQuery.ParamByName('PV').AsFloat := LBody.Get('preco_venda', Double(0));
        LQuery.ParamByName('PC').AsFloat := LBody.Get('preco_custo', Double(0));
        LQuery.ExecSQL;
        LConexao.Confirmar;
        Res.Send('{"message":"Produto criado com sucesso"}').Status(THTTPStatus.Created);
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

procedure RegistrarRotasProdutos;
begin
  THorse.Get('/api/produtos', @GetProdutos);
  THorse.Get('/api/produtos/:id', @GetProdutoById);
  THorse.Post('/api/produtos', @PostProduto);
end;

end.
