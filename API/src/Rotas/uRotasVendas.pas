unit uRotasVendas;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Rotas de Vendas
  Endpoints: GET/POST /api/vendas, GET /api/vendas/:id
  F1: POST usa TPedidoVendaService (mesma regra do desktop) para criar
  o pedido com STATUS 'P', itens/totais recalculados e auditoria.
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasVendas;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uPedidoStatus, uMiddlewareJWT,
  uPaginacao, uPedidoVendaService;

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

procedure EnviarErro(Res: THorseResponse; const AMensagem: string;
  AStatus: THTTPStatus);
begin
  Res.Send(ErroJSON(AMensagem)).Status(AStatus);
end;

function CorpoJSON(Req: THorseRequest; Res: THorseResponse;
  out LBody: TJSONObject): Boolean;
var
  LData: TJSONData;
begin
  Result := False;
  LBody := nil;
  LData := nil;
  try
    LData := GetJSON(Req.Body);
  except
    LData := nil;
  end;
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    EnviarErro(Res, 'Corpo da requisição inválido (objeto JSON esperado)',
      THTTPStatus.BadRequest);
    Exit;
  end;
  LBody := TJSONObject(LData);
  Result := True;
end;

{ F1: prepara os itens para o Service. Quando valor_unitario não vem no
  JSON, usa o PRECO_VENDA do produto da empresa — mesma regra do POST de
  orçamento. A validação final permanece no Service. }
function ItensDaVenda(AItens: TJSONArray; AQuery: TSQLQuery;
  AEmpresaId: Int64; out AItensServico: TItensPedidoEntrada;
  out AMensagem: string): Boolean;
var
  LItem: TJSONObject;
  LDado: TJSONData;
  I: Integer;
begin
  Result := False;
  AMensagem := '';
  SetLength(AItensServico, AItens.Count);
  for I := 0 to AItens.Count - 1 do
  begin
    if not (AItens.Items[I] is TJSONObject) then
    begin
      AMensagem := Format('Item %d inválido.', [I + 1]);
      Exit;
    end;
    LItem := TJSONObject(AItens.Items[I]);
    AItensServico[I].ProdutoId := LItem.Get('produto_id', Int64(0));
    AItensServico[I].Quantidade := LItem.Get('quantidade', Double(0));
    AItensServico[I].Desconto := LItem.Get('desconto', Double(0));
    AItensServico[I].Cfop := LItem.Get('cfop', '');
    LDado := LItem.Find('valor_unitario');
    if LDado <> nil then
      AItensServico[I].ValorUnitario := LDado.AsFloat
    else
    begin
      AQuery.SQL.Text :=
        'SELECT PRECO_VENDA FROM PRODUTO WHERE ID = :ID AND ATIVO = ''A'' ' +
        'AND EMPRESA_ID = :EMP';
      AQuery.ParamByName('ID').AsLargeInt := AItensServico[I].ProdutoId;
      AQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
      AQuery.Open;
      if AQuery.IsEmpty then
      begin
        AQuery.Close;
        AMensagem := Format('Item %d: produto não encontrado ou inativo.', [I + 1]);
        Exit;
      end;
      AItensServico[I].ValorUnitario := AQuery.FieldByName('PRECO_VENDA').AsFloat;
      AQuery.Close;
    end;
  end;
  Result := True;
end;

procedure GetVendas(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
  P: TPaginacao;
  LTotal: Int64;
  LSql: string;
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

    { F6: sem parâmetros, mantém o array de até 100 do contrato antigo.
      Com pagina/por_pagina, informa total e devolve só a fatia pedida. }
    LerPaginacao(Req, P);
    if P.Ativa then
    begin
      LQuery.SQL.Text :=
        'SELECT COUNT(*) FROM PEDIDO_VENDA PV WHERE PV.EMPRESA_ID = :EMP';
      LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
      LQuery.Open;
      LTotal := LQuery.Fields[0].AsLargeInt;
      LQuery.Close;
    end
    else
      LTotal := 0;

    LSql :=
      'SELECT PV.ID, PV.NUMERO, C.NOME AS CLIENTE, PV.TOTAL, PV.DATA_EMISSAO, ' +
      // rótulos de status centralizados em uPedidoStatus; 'O' (orçamento) à parte
      'CASE WHEN PV.STATUS = ''O'' THEN ''Orçamento'' ELSE ' +
        SqlCaseStatusPedido('PV.STATUS') + ' END AS STATUS ' +
      'FROM PEDIDO_VENDA PV LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
      'WHERE PV.EMPRESA_ID = :EMP ';
    if P.Ativa then
      LSql := LSql + 'ORDER BY PV.DATA_EMISSAO DESC, PV.ID DESC ROWS :LINI TO :LIMF'
    else
      LSql := LSql + 'ORDER BY PV.DATA_EMISSAO DESC ROWS 100';
    LQuery.SQL.Text := LSql;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    if P.Ativa then
    begin
      LQuery.ParamByName('LINI').AsInteger := PrimeiraLinha(P);
      LQuery.ParamByName('LIMF').AsInteger := UltimaLinha(P);
    end;
    LQuery.Open;

    LArray := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('numero', LQuery.FieldByName('NUMERO').AsString);
      LObj.Add('cliente', LQuery.FieldByName('CLIENTE').AsString);
      LObj.Add('total', LQuery.FieldByName('TOTAL').AsFloat);
      LObj.Add('data_emissao', LQuery.FieldByName('DATA_EMISSAO').AsString);
      LObj.Add('status', LQuery.FieldByName('STATUS').AsString);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    if P.Ativa then
      EnviarPagina(Res, LArray, LTotal, P)
    else
      Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

procedure GetVendaById(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LObj: TJSONObject;
  LItens: TJSONArray;
  LItem: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);

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

    // Cabeçalho
    LQuery.SQL.Text :=
      'SELECT PV.*, C.NOME AS CLIENTE_NOME FROM PEDIDO_VENDA PV ' +
      'LEFT JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
      'WHERE PV.ID = :ID AND PV.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      Res.Send('{"error":"Venda não encontrada"}').Status(THTTPStatus.NotFound);
      Exit;
    end;

    LObj := TJSONObject.Create;
    LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
    LObj.Add('numero', LQuery.FieldByName('NUMERO').AsString);
    LObj.Add('cliente', LQuery.FieldByName('CLIENTE_NOME').AsString);
    LObj.Add('total', LQuery.FieldByName('TOTAL').AsFloat);
    LObj.Add('subtotal', LQuery.FieldByName('SUBTOTAL').AsFloat);
    LObj.Add('desconto', LQuery.FieldByName('DESCONTO').AsFloat);
    LQuery.Close;

    // Itens
    LQuery.SQL.Text :=
      'SELECT IP.*, P.DESCRICAO AS PRODUTO_DESC FROM ITEM_PEDIDO IP ' +
      'JOIN PRODUTO P ON P.ID = IP.PRODUTO_ID WHERE IP.PEDIDO_VENDA_ID = :PED';
    LQuery.ParamByName('PED').AsLargeInt := LId;
    LQuery.Open;

    LItens := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LItem := TJSONObject.Create;
      LItem.Add('produto', LQuery.FieldByName('PRODUTO_DESC').AsString);
      LItem.Add('quantidade', LQuery.FieldByName('QUANTIDADE').AsFloat);
      LItem.Add('valor_unitario', LQuery.FieldByName('PRECO_UNITARIO').AsFloat);
      LItem.Add('valor_total', LQuery.FieldByName('VALOR_TOTAL').AsFloat);
      LItens.Add(LItem);
      LQuery.Next;
    end;
    LObj.Add('itens', LItens);

    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
    LObj.Free;
  finally
    LQuery.Free;
  end;
end;

procedure PostVenda(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LDadosItens: TJSONData;
  LItens: TJSONArray;
  LItensServico: TItensPedidoEntrada;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LServico: TPedidoVendaService;
  LResposta: TJSONObject;
  LUsuarioId, LEmpresaId: Int64;
  LClienteId, LId, LFormaId, LCondicaoId: Int64;
  LDesconto, LSubtotal, LTotal: Double;
  LNumero, LMensagem: string;
begin
  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if (LUsuarioId <= 0) or (LEmpresaId <= 0) then
  begin
    EnviarErro(Res, 'Token sem usuário/empresa. Entre novamente.',
      THTTPStatus.Unauthorized);
    Exit;
  end;

  if not CorpoJSON(Req, Res, LBody) then
    Exit;
  try
    try
      LClienteId := LBody.Get('cliente_id', Int64(0));
      if LClienteId <= 0 then
      begin
        EnviarErro(Res, 'Informe o cliente (cliente_id).', THTTPStatus.BadRequest);
        Exit;
      end;

      LDadosItens := LBody.Find('itens');
      if not (LDadosItens is TJSONArray) then
      begin
        EnviarErro(Res, 'Informe os itens da venda (itens).',
          THTTPStatus.BadRequest);
        Exit;
      end;
      LItens := TJSONArray(LDadosItens);
      if LItens.Count = 0 then
      begin
        EnviarErro(Res, 'Adicione pelo menos um item à venda.',
          THTTPStatus.BadRequest);
        Exit;
      end;

      LDesconto := LBody.Get('desconto', Double(0));
      if LDesconto < 0 then
      begin
        EnviarErro(Res, 'O desconto da venda não pode ser negativo.',
          THTTPStatus.BadRequest);
        Exit;
      end;

      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        if not ItensDaVenda(LItens, LQuery, LEmpresaId, LItensServico, LMensagem) then
        begin
          EnviarErro(Res, LMensagem, THTTPStatus.BadRequest);
          Exit;
        end;
      finally
        LQuery.Free;
      end;

      LServico := TPedidoVendaService.Create;
      try
        LNumero := Trim(LBody.Get('numero', ''));
        if (LNumero = '') or (LNumero = '0') then
          LNumero := IntToStr(LServico.ProximoNumero);
        LFormaId := LBody.Get('forma_pagamento_id', Int64(0));
        LCondicaoId := LBody.Get('condicao_pagamento_id', Int64(0));
        LSubtotal := LServico.SubtotalDosItens(LItensServico);
        LTotal := LServico.TotalDoPedido(LItensServico, LDesconto);

        { F1: SalvarPedido valida cliente/itens/totais, usa a empresa e o
          usuário do JWT via TSessao, grava STATUS 'P' e audita INSERT. }
        LId := LServico.SalvarPedido(LClienteId, LNumero, LItensServico,
          LDesconto, LFormaId, LCondicaoId, LBody.Get('observacoes', ''));
      finally
        LServico.Free;
      end;

      LResposta := TJSONObject.Create;
      try
        LResposta.Add('id', LId);
        LResposta.Add('numero', LNumero);
        LResposta.Add('subtotal', LSubtotal);
        LResposta.Add('desconto', LDesconto);
        LResposta.Add('total', LTotal);
        LResposta.Add('message', 'Venda criada com sucesso');
        Res.Send(LResposta.AsJSON).Status(THTTPStatus.Created);
      finally
        LResposta.Free;
      end;
    except
      on E: Exception do
        EnviarErro(Res, E.Message, THTTPStatus.BadRequest);
    end;
  finally
    LBody.Free;
  end;
end;

procedure RegistrarRotasVendas;
begin
  THorse.Get('/api/vendas', @GetVendas);
  THorse.Get('/api/vendas/:id', @GetVendaById);
  THorse.Post('/api/vendas', @PostVenda);
end;

end.
