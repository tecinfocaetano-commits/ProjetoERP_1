unit uRotasPDV;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Rotas do PDV Mobile (frente de caixa)
  Endpoints:
    GET  /api/pdv/status                  - caixa aberto do usuário + saldo
    POST /api/pdv/caixa/abrir              - abre o caixa ({valor_abertura})
    POST /api/pdv/caixa/fechar             - fecha o caixa (devolve saldo)
    POST /api/pdv/caixa/movimento          - suprimento 'E' / sangria 'S'
    GET  /api/pdv/produtos?busca=          - produtos ativos da empresa
    GET  /api/pdv/produtos/buscar?codigo=  - busca exata por código/barras
    GET  /api/pdv/formas-pagamento         - formas ativas (tabela global)
    POST /api/pdv/vendas                   - venda balcão via TPDVService

  Todas as regras ficam em TPDVService (Desktop\src\Services):
  um caixa aberto por usuário, venda STATUS 'F' + itens + movimento
  de caixa 'V' na mesma transação, auditoria e EMPRESA_ID do JWT.
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasPDV;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT,
  uPDVService;

const
  LIMITE_PRODUTOS = 60;

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

function TokenOuErro(Req: THorseRequest; Res: THorseResponse;
  var LUsuarioId, LEmpresaId: Int64): Boolean;
begin
  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  Result := (LUsuarioId > 0) and (LEmpresaId > 0);
  if not Result then
    EnviarErro(Res, 'Token sem usuário/empresa. Entre novamente.',
      THTTPStatus.Unauthorized);
end;

{ ------------------------------------------------------------------
  GET /api/pdv/status
  ------------------------------------------------------------------ }
procedure GetStatus(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LServico: TPDVService;
  LObj: TJSONObject;
  LCaixaId: Int64;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;

  LServico := TPDVService.Create;
  try
    LCaixaId := LServico.CaixaAberto(LUsuarioId);
  finally
    LServico.Free;
  end;

  LObj := TJSONObject.Create;
  try
    LObj.Add('tem_caixa', LCaixaId > 0);
    if LCaixaId > 0 then
    begin
      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LQuery.SQL.Text :=
          'SELECT NUMERO, VALOR_ABERTURA FROM CAIXA ' +
          'WHERE ID = :ID AND EMPRESA_ID = :EMP';
        LQuery.ParamByName('ID').AsLargeInt := LCaixaId;
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LQuery.Open;
        LObj.Add('caixa_id', LCaixaId);
        LObj.Add('numero', LQuery.FieldByName('NUMERO').AsString);
        LObj.Add('valor_abertura',
          LQuery.FieldByName('VALOR_ABERTURA').AsFloat);
        LQuery.Close;
      finally
        LQuery.Free;
      end;

      LServico := TPDVService.Create;
      try
        LObj.Add('saldo', LServico.SaldoCaixa(LCaixaId));
      finally
        LServico.Free;
      end;
    end;
    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
  finally
    LObj.Free;
  end;
end;

{ ------------------------------------------------------------------
  POST /api/pdv/caixa/abrir
  ------------------------------------------------------------------ }
procedure PostAbrirCaixa(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LBody: TJSONObject;
  LServico: TPDVService;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LObj: TJSONObject;
  LCaixaId: Int64;
  LValor: Double;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;
  if not CorpoJSON(Req, Res, LBody) then
    Exit;
  try
    try
      LValor := LBody.Get('valor_abertura', Double(0));
      LServico := TPDVService.Create;
      try
        LCaixaId := LServico.AbrirCaixa(LValor);
      finally
        LServico.Free;
      end;

      { devolve número e saldo iniciais para a tela de PDV }
      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      LObj := TJSONObject.Create;
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LQuery.SQL.Text :=
          'SELECT NUMERO, VALOR_ABERTURA FROM CAIXA ' +
          'WHERE ID = :ID AND EMPRESA_ID = :EMP';
        LQuery.ParamByName('ID').AsLargeInt := LCaixaId;
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LQuery.Open;
        LObj.Add('caixa_id', LCaixaId);
        LObj.Add('numero', LQuery.FieldByName('NUMERO').AsString);
        LObj.Add('valor_abertura', LValor);
        LObj.Add('saldo', LValor);
        LQuery.Close;
        Res.Send(LObj.AsJSON).Status(THTTPStatus.Created);
      finally
        LQuery.Free;
        LObj.Free;
      end;
    except
      on E: Exception do
        EnviarErro(Res, E.Message, THTTPStatus.BadRequest);
    end;
  finally
    LBody.Free;
  end;
end;

{ ------------------------------------------------------------------
  POST /api/pdv/caixa/fechar
  ------------------------------------------------------------------ }
procedure PostFecharCaixa(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LServico: TPDVService;
  LObj: TJSONObject;
  LCaixaId: Int64;
  LSaldo: Double;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;

  LServico := TPDVService.Create;
  try
    LCaixaId := LServico.CaixaAberto(LUsuarioId);
    if LCaixaId <= 0 then
    begin
      EnviarErro(Res, 'Nenhum caixa aberto para este usuário.',
        THTTPStatus.BadRequest);
      Exit;
    end;
    LSaldo := LServico.FecharCaixa(LCaixaId);
  finally
    LServico.Free;
  end;

  LObj := TJSONObject.Create;
  try
    LObj.Add('caixa_id', LCaixaId);
    LObj.Add('valor_fechamento', LSaldo);
    LObj.Add('message', 'Caixa fechado com sucesso.');
    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
  finally
    LObj.Free;
  end;
end;

{ ------------------------------------------------------------------
  POST /api/pdv/caixa/movimento  {tipo: 'E'|'S', valor, descricao}
  ------------------------------------------------------------------ }
procedure PostMovimentoCaixa(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LBody: TJSONObject;
  LServico: TPDVService;
  LObj: TJSONObject;
  LCaixaId: Int64;
  LTipo: Char;
  LTipoStr: string;
  LValor: Double;
  LDescricao: string;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;
  if not CorpoJSON(Req, Res, LBody) then
    Exit;
  try
    try
      LDescricao := Trim(LBody.Get('descricao', ''));
      if LDescricao = '' then
      begin
        EnviarErro(Res, 'Informe a descrição do movimento.',
          THTTPStatus.BadRequest);
        Exit;
      end;
      LTipoStr := UpCase(Trim(LBody.Get('tipo', '')));
      LTipo := ' ';
      if LTipoStr <> '' then
        LTipo := LTipoStr[1];
      if (LTipo <> 'E') and (LTipo <> 'S') then
      begin
        EnviarErro(Res, 'Tipo de movimento inválido (use E ou S).',
          THTTPStatus.BadRequest);
        Exit;
      end;
      LValor := LBody.Get('valor', Double(0));

      LServico := TPDVService.Create;
      try
        LCaixaId := LServico.CaixaAberto(LUsuarioId);
        if LCaixaId <= 0 then
        begin
          EnviarErro(Res, 'Nenhum caixa aberto para este usuário.',
            THTTPStatus.BadRequest);
          Exit;
        end;
        LServico.RegistrarMovimento(LCaixaId, LTipo, LValor, LDescricao);
      finally
        LServico.Free;
      end;

      LObj := TJSONObject.Create;
      try
        LObj.Add('caixa_id', LCaixaId);
        LObj.Add('tipo', LTipo);
        LObj.Add('valor', LValor);
        LObj.Add('message', 'Movimento registrado no caixa.');
        Res.Send(LObj.AsJSON).Status(THTTPStatus.Created);
      finally
        LObj.Free;
      end;
    except
      on E: Exception do
        EnviarErro(Res, E.Message, THTTPStatus.BadRequest);
    end;
  finally
    LBody.Free;
  end;
end;

{ ------------------------------------------------------------------
  GET /api/pdv/produtos?busca=
  ------------------------------------------------------------------ }
procedure GetProdutos(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
  LBusca, LSql: string;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;

  LBusca := Trim(Req.Query['busca']);
  LSql :=
    'SELECT ID, CODIGO, CODIGO_BARRAS, DESCRICAO, ' +
    '  COALESCE(DESCRICAO_PDV, '''') AS DESCRICAO_PDV, PRECO_VENDA ' +
    'FROM PRODUTO WHERE EMPRESA_ID = :EMP AND ATIVO = ''A'' ';
  if LBusca <> '' then
    LSql := LSql +
      'AND (UPPER(CAST(DESCRICAO AS VARCHAR(1000))) CONTAINING UPPER(:T) OR ' +
      'UPPER(CAST(CODIGO AS VARCHAR(200))) CONTAINING UPPER(:T) OR ' +
      'UPPER(CAST(CODIGO_BARRAS AS VARCHAR(200))) CONTAINING UPPER(:T)) ';
  LSql := LSql + 'ORDER BY DESCRICAO ROWS :LIM';

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LArray := TJSONArray.Create;
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text := LSql;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    if LBusca <> '' then
      LQuery.ParamByName('T').AsString := LBusca;
    LQuery.ParamByName('LIM').AsInteger := LIMITE_PRODUTOS;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('codigo', LQuery.FieldByName('CODIGO').AsString);
      LObj.Add('codigo_barras', LQuery.FieldByName('CODIGO_BARRAS').AsString);
      LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
      LObj.Add('descricao_pdv', LQuery.FieldByName('DESCRICAO_PDV').AsString);
      LObj.Add('preco_venda', LQuery.FieldByName('PRECO_VENDA').AsFloat);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

{ ------------------------------------------------------------------
  GET /api/pdv/produtos/buscar?codigo=
  Busca exata por código ou código de barras (mesma regra do scanner
  do PDV desktop: TPDVService.BuscarProduto).
  ------------------------------------------------------------------ }
procedure GetProdutoBuscar(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LServico: TPDVService;
  LObj: TJSONObject;
  LProdutoId: Int64;
  LCodigo, LDescricao: string;
  LPreco: Double;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;

  LServico := TPDVService.Create;
  try
    if not LServico.BuscarProduto(Trim(Req.Query['codigo']), LProdutoId,
      LCodigo, LDescricao, LPreco) then
    begin
      EnviarErro(Res, 'Produto não encontrado.', THTTPStatus.NotFound);
      Exit;
    end;
  finally
    LServico.Free;
  end;

  LObj := TJSONObject.Create;
  try
    LObj.Add('id', LProdutoId);
    LObj.Add('codigo', LCodigo);
    LObj.Add('descricao', LDescricao);
    LObj.Add('preco_venda', LPreco);
    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
  finally
    LObj.Free;
  end;
end;

{ ------------------------------------------------------------------
  GET /api/pdv/formas-pagamento
  FORMA_PAGAMENTO é tabela global (sem EMPRESA_ID — convenção do
  projeto); só as ativas são listadas.
  ------------------------------------------------------------------ }
procedure GetFormasPagamento(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LArray: TJSONArray;
  LObj: TJSONObject;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LArray := TJSONArray.Create;
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT ID, DESCRICAO, TRIM(TIPO) AS TIPO FROM FORMA_PAGAMENTO ' +
      'WHERE ATIVO = ''A'' ORDER BY ID';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
      LObj.Add('tipo', LQuery.FieldByName('TIPO').AsString);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

{ Itens do body -> TItensPDVEntrada. Quando preco_unitario não vem,
  usa o PRECO_VENDA do produto da empresa (mesma regra do PDV desktop
  e do POST /api/vendas). }
function ItensDaVendaPDV(AItens: TJSONArray; AQuery: TSQLQuery;
  AEmpresaId: Int64; out AItensServico: TItensPDVEntrada;
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
    LDado := LItem.Find('preco_unitario');
    if LDado <> nil then
      AItensServico[I].PrecoUnitario := LDado.AsFloat
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
        AMensagem := Format('Item %d: produto não encontrado ou inativo.',
          [I + 1]);
        Exit;
      end;
      AItensServico[I].PrecoUnitario :=
        AQuery.FieldByName('PRECO_VENDA').AsFloat;
      AQuery.Close;
    end;
  end;
  Result := True;
end;

function FormaPagamentoValida(AQuery: TSQLQuery; AFormaId: Int64): Boolean;
begin
  Result := False;
  if AFormaId <= 0 then
    Exit;
  AQuery.SQL.Text :=
    'SELECT FIRST 1 ID FROM FORMA_PAGAMENTO WHERE ID = :ID AND ATIVO = ''A''';
  AQuery.ParamByName('ID').AsLargeInt := AFormaId;
  AQuery.Open;
  Result := not AQuery.IsEmpty;
  AQuery.Close;
end;

{ ------------------------------------------------------------------
  POST /api/pdv/vendas
  Body: { itens: [{produto_id, quantidade, preco_unitario?}],
          desconto?, forma_pagamento_id?, valor_pago?, observacoes? }
  Exige caixa aberto do usuário (TokenOuErro já validou empresa).
  Resposta: id, numero, subtotal, desconto, total, troco.
  ------------------------------------------------------------------ }
procedure PostVendaPDV(Req: THorseRequest; Res: THorseResponse);
var
  LUsuarioId, LEmpresaId: Int64;
  LBody: TJSONObject;
  LDadosItens: TJSONData;
  LItens: TJSONArray;
  LItensServico: TItensPDVEntrada;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LServico: TPDVService;
  LObj: TJSONObject;
  LCaixaId, LVendaId, LFormaId: Int64;
  LDesconto, LSubtotal, LTotal, LValorPago, LTroco: Double;
  LNumero, LMensagem: string;
  I: Integer;
begin
  if not TokenOuErro(Req, Res, LUsuarioId, LEmpresaId) then
    Exit;
  if not CorpoJSON(Req, Res, LBody) then
    Exit;
  try
    try
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

      LFormaId := LBody.Get('forma_pagamento_id', Int64(0));
      LValorPago := LBody.Get('valor_pago', Double(0));

      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;

        if not FormaPagamentoValida(LQuery, LFormaId) then
        begin
          EnviarErro(Res, 'Forma de pagamento inválida.',
            THTTPStatus.BadRequest);
          Exit;
        end;
        if not ItensDaVendaPDV(LItens, LQuery, LEmpresaId,
          LItensServico, LMensagem) then
        begin
          EnviarErro(Res, LMensagem, THTTPStatus.BadRequest);
          Exit;
        end;
      finally
        LQuery.Free;
      end;

      LServico := TPDVService.Create;
      try
        LCaixaId := LServico.CaixaAberto(LUsuarioId);
        if LCaixaId <= 0 then
        begin
          EnviarErro(Res, 'Nenhum caixa aberto. Abra o caixa antes de vender.',
            THTTPStatus.Conflict);
          Exit;
        end;

        LSubtotal := 0;
        for I := 0 to High(LItensServico) do
          LSubtotal := LSubtotal + TotalItemPDV(LItensServico[I].Quantidade,
            LItensServico[I].PrecoUnitario);
        LTotal := TotalVendaPDV(LSubtotal, LDesconto);

        LVendaId := LServico.SalvarVenda(LCaixaId, LItensServico,
          LDesconto, LFormaId, 0, LBody.Get('observacoes', 'PDV Mobile'));
      finally
        LServico.Free;
      end;

      { número gerado pelo Service dentro da transação }
      LNumero := '';
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LQuery.SQL.Text :=
          'SELECT NUMERO FROM PEDIDO_VENDA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LVendaId;
        LQuery.Open;
        if not LQuery.IsEmpty then
          LNumero := LQuery.FieldByName('NUMERO').AsString;
      finally
        LQuery.Free;
      end;

      LTroco := LValorPago - LTotal;
      if LTroco < 0 then
        LTroco := 0;

      LObj := TJSONObject.Create;
      try
        LObj.Add('id', LVendaId);
        LObj.Add('numero', LNumero);
        LObj.Add('caixa_id', LCaixaId);
        LObj.Add('subtotal', LSubtotal);
        LObj.Add('desconto', LDesconto);
        LObj.Add('total', LTotal);
        LObj.Add('valor_pago', LValorPago);
        LObj.Add('troco', LTroco);
        LObj.Add('message', 'Venda registrada no caixa.');
        Res.Send(LObj.AsJSON).Status(THTTPStatus.Created);
      finally
        LObj.Free;
      end;
    except
      on E: Exception do
        EnviarErro(Res, E.Message, THTTPStatus.BadRequest);
    end;
  finally
    LBody.Free;
  end;
end;

procedure RegistrarRotasPDV;
begin
  THorse.Get('/api/pdv/status', @GetStatus);
  THorse.Post('/api/pdv/caixa/abrir', @PostAbrirCaixa);
  THorse.Post('/api/pdv/caixa/fechar', @PostFecharCaixa);
  THorse.Post('/api/pdv/caixa/movimento', @PostMovimentoCaixa);
  THorse.Get('/api/pdv/produtos', @GetProdutos);
  THorse.Get('/api/pdv/produtos/buscar', @GetProdutoBuscar);
  THorse.Get('/api/pdv/formas-pagamento', @GetFormasPagamento);
  THorse.Post('/api/pdv/vendas', @PostVendaPDV);
end;

end.
