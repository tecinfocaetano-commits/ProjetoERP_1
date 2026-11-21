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
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT,
  uEstoqueService;

function ErroJSON(const AMensagem: string): string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create;
  try
    LObj.Add('error', AMensagem);
    Result := LObj.AsJSON;
  finally
    LObj.Free;
  end;
end;

{ D5: as mensagens do Service são erros do cliente (validação ou produto
  de outra empresa); qualquer outra exceção continua sendo 500. Os
  prefixos não usam acentos para não depender do encoding do fonte. }
function EhErroValidacao(const AMensagem: string): Boolean;
begin
  Result :=
    (Pos('Selecione um produto', AMensagem) = 1) or
    (Pos('Tipo de movimenta', AMensagem) = 1) or
    (Pos('A quantidade deve', AMensagem) = 1) or
    (Pos('O custo unit', AMensagem) = 1) or
    (Pos('O documento deve', AMensagem) = 1) or
    (Pos('A observa', AMensagem) = 1) or
    (Pos('Produto n', AMensagem) = 1);
end;

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
  LResposta: TJSONObject;
  LServico: TEstoqueService;
  LUsuarioId, LEmpresaId: Int64;
  LProdutoId, LId: Int64;
  LQuantidade, LCusto: Double;
  LTipo, LDocumento, LObservacao: string;
begin
  try
    DadosDoToken(Req, LUsuarioId, LEmpresaId);
    if LEmpresaId <= 0 then
    begin
      Res.Status(THTTPStatus.Unauthorized)
        .Send('{"error":"Token sem empresa. Entre novamente."}');
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
      Res.Status(THTTPStatus.BadRequest)
        .Send('{"error":"Corpo da requisição inválido (objeto JSON esperado)"}');
      Exit;
    end;
    LBody := TJSONObject(LData);
    try
      LProdutoId := LBody.Get('produto_id', Int64(0));
      LTipo := LBody.Get('tipo', 'E');
      LQuantidade := LBody.Get('quantidade', Double(0));
      LCusto := LBody.Get('custo_unitario', Double(0));
      LDocumento := LBody.Get('documento', '');
      LObservacao := LBody.Get('observacao', '');

      { D5: mesma regra do desktop — validação, produto da empresa da
        sessão (contexto JWT por thread), trigger de saldo e auditoria
        atômica. A rota não faz SQL nem auditoria própria. }
      LServico := TEstoqueService.Create;
      try
        LId := LServico.RegistrarMovimento(LProdutoId, LTipo,
          LQuantidade, LCusto, LDocumento, LObservacao);
      finally
        LServico.Free;
      end;

      LResposta := TJSONObject.Create;
      try
        LResposta.Add('message', 'Movimento registrado com sucesso');
        LResposta.Add('id', LId);
        Res.Send(LResposta.AsJSON).Status(THTTPStatus.Created);
      finally
        LResposta.Free;
      end;
    finally
      LBody.Free;
    end;
  except
    on E: Exception do
    begin
      if EhErroValidacao(E.Message) then
        Res.Status(THTTPStatus.BadRequest).Send(ErroJSON(E.Message))
      else
        Res.Status(THTTPStatus.InternalServerError).Send(ErroJSON(E.Message));
    end;
  end;
end;

procedure RegistrarRotasEstoque;
begin
  THorse.Get('/api/estoque', @GetEstoque);
  THorse.Post('/api/estoque/movimento', @PostMovimento);
end;

end.
