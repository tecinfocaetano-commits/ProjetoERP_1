unit uRotasOrcamentos;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rotas de Orçamentos
  Endpoints:
    GET  /api/orcamentos              lista os orçamentos em aberto
    GET  /api/orcamentos/:id          cabeçalho + itens
    POST /api/orcamentos              grava um orçamento novo
    POST /api/orcamentos/:id/converter converte em pedido (STATUS 'P')

  Regra de negócio: o orçamento é um PEDIDO_VENDA com STATUS 'O'.
  Os totais (item, subtotal, total) são sempre recalculados aqui, a
  partir da quantidade/valor/desconto enviados — nunca aceitos
  prontos do cliente. Empresa e usuário vêm do token JWT.
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasOrcamentos;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT;

const
  { DM_DESCRICAO em PEDIDO_VENDA.OBSERVACOES }
  TAMANHO_MAX_OBSERVACOES = 255;

{ ------------------------------------------------------------
  Apoio
  ------------------------------------------------------------ }

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

{ Empresa/usuário autenticados: claims sub e empresa_id do JWT. }
procedure DadosDoToken(Req: THorseRequest; out AUsuarioId, AEmpresaId: Int64);
var
  LToken: string;
  LDados: TJSONObject;
begin
  AUsuarioId := 0;
  AEmpresaId := 0;
  LToken := StringReplace(Req.Headers['Authorization'], 'Bearer ', '', [rfIgnoreCase]);
  LDados := ExtrairDadosToken(LToken);
  if LDados <> nil then
  try
    AUsuarioId := LDados.Get('sub', Int64(0));
    AEmpresaId := LDados.Get('empresa_id', Int64(0));
  finally
    LDados.Free;
  end;
end;

{ Próximo número sequencial, mantendo a regra do desktop
  (uFrmPedidoVenda.ProximoNumero): NUMERO é VARCHAR e valores não
  numéricos são ignorados. }
function ProximoNumero(AConexao: TConexao): Integer;
var
  LQuery: TSQLQuery;
  LNum: Integer;
begin
  Result := 0;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := AConexao.Connection;
    LQuery.Transaction := AConexao.Transaction;
    LQuery.SQL.Text := 'SELECT NUMERO FROM PEDIDO_VENDA';
    LQuery.Open;
    while not LQuery.EOF do
    begin
      LNum := StrToIntDef(Trim(LQuery.FieldByName('NUMERO').AsString), 0);
      if LNum > Result then
        Result := LNum;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
  Inc(Result);
end;

{ ------------------------------------------------------------
  GET /api/orcamentos
  ------------------------------------------------------------ }

procedure GetOrcamentos(Req: THorseRequest; Res: THorseResponse);
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
    Res.Send(ErroJSON('Token sem empresa. Entre novamente.')).Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT PV.ID, PV.NUMERO, C.NOME AS CLIENTE, PV.TOTAL, PV.DATA_EMISSAO, ' +
      '(SELECT COUNT(*) FROM ITEM_PEDIDO I WHERE I.PEDIDO_VENDA_ID = PV.ID) AS ITENS ' +
      'FROM PEDIDO_VENDA PV LEFT JOIN CLIENTE C ON C.ID = PV.CLIENTE_ID ' +
      'WHERE PV.STATUS = ''O'' AND PV.EMPRESA_ID = :EMP ' +
      'ORDER BY PV.DATA_EMISSAO DESC, PV.ID DESC';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
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
      LObj.Add('itens', LQuery.FieldByName('ITENS').AsInteger);
      LObj.Add('status', 'Orçamento');
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

{ ------------------------------------------------------------
  GET /api/orcamentos/:id
  ------------------------------------------------------------ }

procedure GetOrcamentoById(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LEmpresaId, LUsuarioId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LObj: TJSONObject;
  LItens: TJSONArray;
  LItem: TJSONObject;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId <= 0 then
  begin
    Res.Send(ErroJSON('ID inválido')).Status(THTTPStatus.BadRequest);
    Exit;
  end;

  LEmpresaId := 0;
  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send(ErroJSON('Token sem empresa. Entre novamente.')).Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    LQuery.SQL.Text :=
      'SELECT PV.ID, PV.NUMERO, PV.CLIENTE_ID, PV.STATUS, PV.SUBTOTAL, ' +
      'PV.DESCONTO, PV.TOTAL, PV.DATA_EMISSAO, PV.OBSERVACOES, ' +
      'C.NOME AS CLIENTE_NOME ' +
      'FROM PEDIDO_VENDA PV LEFT JOIN CLIENTE C ON C.ID = PV.CLIENTE_ID ' +
      'WHERE PV.ID = :ID AND PV.STATUS = ''O'' AND PV.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      Res.Send(ErroJSON('Orçamento não encontrado')).Status(THTTPStatus.NotFound);
      Exit;
    end;

    LObj := TJSONObject.Create;
    try
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('numero', LQuery.FieldByName('NUMERO').AsString);
      LObj.Add('cliente_id', LQuery.FieldByName('CLIENTE_ID').AsLargeInt);
      LObj.Add('cliente', LQuery.FieldByName('CLIENTE_NOME').AsString);
      LObj.Add('status', LQuery.FieldByName('STATUS').AsString);
      LObj.Add('subtotal', LQuery.FieldByName('SUBTOTAL').AsFloat);
      LObj.Add('desconto', LQuery.FieldByName('DESCONTO').AsFloat);
      LObj.Add('total', LQuery.FieldByName('TOTAL').AsFloat);
      LObj.Add('data_emissao', LQuery.FieldByName('DATA_EMISSAO').AsString);
      LObj.Add('observacoes', LQuery.FieldByName('OBSERVACOES').AsString);
      LQuery.Close;

      LQuery.SQL.Text :=
        'SELECT I.PRODUTO_ID, P.DESCRICAO AS PRODUTO_DESC, I.QUANTIDADE, ' +
        'COALESCE(NULLIF(I.VALOR_UNITARIO, 0), I.PRECO_UNITARIO) AS VALOR_UNITARIO, ' +
        'I.DESCONTO, I.VALOR_TOTAL ' +
        'FROM ITEM_PEDIDO I LEFT JOIN PRODUTO P ON P.ID = I.PRODUTO_ID ' +
        'WHERE I.PEDIDO_VENDA_ID = :PED ORDER BY I.ID';
      LQuery.ParamByName('PED').AsLargeInt := LId;
      LQuery.Open;

      LItens := TJSONArray.Create;
      while not LQuery.EOF do
      begin
        LItem := TJSONObject.Create;
        LItem.Add('produto_id', LQuery.FieldByName('PRODUTO_ID').AsLargeInt);
        LItem.Add('produto', LQuery.FieldByName('PRODUTO_DESC').AsString);
        LItem.Add('quantidade', LQuery.FieldByName('QUANTIDADE').AsFloat);
        LItem.Add('valor_unitario', LQuery.FieldByName('VALOR_UNITARIO').AsFloat);
        LItem.Add('desconto', LQuery.FieldByName('DESCONTO').AsFloat);
        LItem.Add('valor_total', LQuery.FieldByName('VALOR_TOTAL').AsFloat);
        LItens.Add(LItem);
        LQuery.Next;
      end;
      LObj.Add('itens', LItens);

      Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
    finally
      LObj.Free;
    end;
  finally
    LQuery.Free;
  end;
end;

{ ------------------------------------------------------------
  POST /api/orcamentos
  ------------------------------------------------------------ }

procedure PostOrcamento(Req: THorseRequest; Res: THorseResponse);
var
  LData: TJSONData;
  LDadosItens: TJSONData;
  LBody: TJSONObject;
  LResposta: TJSONObject;
  LItens: TJSONArray;
  LItem: TJSONObject;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LUsuarioId, LEmpresaId: Int64;
  LClienteId, LProdutoId, LOrcamentoId: Int64;
  LQuantidade, LValorUnitario, LDescontoItem: Double;
  LTotalItem, LSubtotal, LDesconto, LTotal: Double;
  LObservacoes: string;
  LNumero: Integer;
  I: Integer;
begin
  LData := nil;
  try
    try
      LData := GetJSON(Req.Body);
    except
      LData := nil;
    end;
    if not (LData is TJSONObject) then
    begin
      Res.Send(ErroJSON('Corpo da requisição inválido (objeto JSON esperado)'))
        .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LBody := TJSONObject(LData);
    try
      LClienteId := LBody.Get('cliente_id', Int64(0));
      if LClienteId <= 0 then
      begin
        Res.Send(ErroJSON('Informe o cliente (cliente_id).')).Status(THTTPStatus.BadRequest);
        Exit;
      end;

      LDadosItens := LBody.Find('itens');
      if not (LDadosItens is TJSONArray) then
      begin
        Res.Send(ErroJSON('Informe os itens do orçamento (itens).')).Status(THTTPStatus.BadRequest);
        Exit;
      end;
      LItens := TJSONArray(LDadosItens);
      if LItens.Count = 0 then
      begin
        Res.Send(ErroJSON('Adicione pelo menos um item ao orçamento.')).Status(THTTPStatus.BadRequest);
        Exit;
      end;

      LDesconto := LBody.Get('desconto', Double(0));
      if LDesconto < 0 then
      begin
        Res.Send(ErroJSON('O desconto do orçamento não pode ser negativo.')).Status(THTTPStatus.BadRequest);
        Exit;
      end;

      LObservacoes := LBody.Get('observacoes', '');
      if Length(LObservacoes) > TAMANHO_MAX_OBSERVACOES then
      begin
        Res.Send(ErroJSON(Format('Observações acima de %d caracteres.', [TAMANHO_MAX_OBSERVACOES])))
          .Status(THTTPStatus.BadRequest);
        Exit;
      end;

      DadosDoToken(Req, LUsuarioId, LEmpresaId);
      if (LUsuarioId <= 0) or (LEmpresaId <= 0) then
      begin
        Res.Send(ErroJSON('Token sem usuário/empresa. Entre novamente.')).Status(THTTPStatus.Unauthorized);
        Exit;
      end;

      LConexao := TConexao.GetInstance;
      LQuery := TSQLQuery.Create(nil);
      try
        LQuery.DataBase := LConexao.Connection;
        LQuery.Transaction := LConexao.Transaction;
        LConexao.IniciarTransacao;

        { Cliente precisa existir, estar ativo e ser da empresa do token }
        LQuery.SQL.Text :=
          'SELECT ID FROM CLIENTE WHERE ID = :ID AND ATIVO = ''A'' AND EMPRESA_ID = :EMP';
        LQuery.ParamByName('ID').AsLargeInt := LClienteId;
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LQuery.Open;
        if LQuery.IsEmpty then
        begin
          LConexao.Cancelar;
          Res.Send(ErroJSON('Cliente não encontrado ou inativo.')).Status(THTTPStatus.BadRequest);
          Exit;
        end;
        LQuery.Close;

        { Primeira passada: valida os itens e calcula os totais }
        LSubtotal := 0;
        for I := 0 to LItens.Count - 1 do
        begin
          if not (LItens.Items[I] is TJSONObject) then
          begin
            LConexao.Cancelar;
            Res.Send(ErroJSON(Format('Item %d inválido.', [I + 1]))).Status(THTTPStatus.BadRequest);
            Exit;
          end;
          LItem := TJSONObject(LItens.Items[I]);

          LProdutoId := LItem.Get('produto_id', Int64(0));
          if LProdutoId <= 0 then
          begin
            LConexao.Cancelar;
            Res.Send(ErroJSON(Format('Item %d: informe o produto (produto_id).', [I + 1])))
              .Status(THTTPStatus.BadRequest);
            Exit;
          end;

          LQuantidade := LItem.Get('quantidade', Double(0));
          if LQuantidade <= 0 then
          begin
            LConexao.Cancelar;
            Res.Send(ErroJSON(Format('Item %d: quantidade deve ser maior que zero.', [I + 1])))
              .Status(THTTPStatus.BadRequest);
            Exit;
          end;

          LDescontoItem := LItem.Get('desconto', Double(0));
          if LDescontoItem < 0 then
          begin
            LConexao.Cancelar;
            Res.Send(ErroJSON(Format('Item %d: desconto não pode ser negativo.', [I + 1])))
              .Status(THTTPStatus.BadRequest);
            Exit;
          end;

          { Produto ativo + preço de venda (usado quando o app não informa valor) }
          LQuery.SQL.Text :=
            'SELECT PRECO_VENDA FROM PRODUTO WHERE ID = :ID AND ATIVO = ''A'' ' +
            'AND EMPRESA_ID = :EMP';
          LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
          LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
          LQuery.Open;
          if LQuery.IsEmpty then
          begin
            LQuery.Close;
            LConexao.Cancelar;
            Res.Send(ErroJSON(Format('Item %d: produto não encontrado ou inativo.', [I + 1])))
              .Status(THTTPStatus.BadRequest);
            Exit;
          end;

          if LItem.Find('valor_unitario') = nil then
            LValorUnitario := LQuery.FieldByName('PRECO_VENDA').AsFloat
          else
            LValorUnitario := LItem.Get('valor_unitario', Double(0));
          LQuery.Close;

          if LValorUnitario < 0 then
          begin
            LConexao.Cancelar;
            Res.Send(ErroJSON(Format('Item %d: valor unitário não pode ser negativo.', [I + 1])))
              .Status(THTTPStatus.BadRequest);
            Exit;
          end;

          LTotalItem := (LQuantidade * LValorUnitario) - LDescontoItem;
          if LTotalItem < 0 then
          begin
            LConexao.Cancelar;
            Res.Send(ErroJSON(Format(
              'Item %d: desconto maior que o valor do item (%s).',
              [I + 1, FormatFloat('#,##0.00', LQuantidade * LValorUnitario)])))
              .Status(THTTPStatus.BadRequest);
            Exit;
          end;

          LSubtotal := LSubtotal + LTotalItem;
        end;

        if LDesconto > LSubtotal then
        begin
          LConexao.Cancelar;
          Res.Send(ErroJSON(Format(
            'Desconto do orçamento (%s) maior que o subtotal (%s).',
            [FormatFloat('#,##0.00', LDesconto), FormatFloat('#,##0.00', LSubtotal)])))
            .Status(THTTPStatus.BadRequest);
          Exit;
        end;

        LTotal := LSubtotal - LDesconto;
        LNumero := ProximoNumero(LConexao);

        { ID vem do generator antes do INSERT: evita depender do valor
          corrente do generator (que outra thread poderia já ter avançado) }
        LQuery.SQL.Text := 'SELECT GEN_ID(GEN_PEDIDO_VENDA_ID, 1) FROM RDB$DATABASE';
        LQuery.Open;
        LOrcamentoId := LQuery.Fields[0].AsLargeInt;
        LQuery.Close;

        { Cabeçalho: orçamento = PEDIDO_VENDA com STATUS 'O' }
        LQuery.SQL.Text :=
          'INSERT INTO PEDIDO_VENDA (ID, EMPRESA_ID, CLIENTE_ID, NUMERO, DATA_EMISSAO, ' +
          'USUARIO_ID, STATUS, SUBTOTAL, DESCONTO, TOTAL, OBSERVACOES) ' +
          'VALUES (:ID, :EMP, :CLI, :NUM, CURRENT_DATE, ' +
          ':USR, ''O'', :SUB, :DESC, :TOT, :OBS)';
        LQuery.ParamByName('ID').AsLargeInt := LOrcamentoId;
        LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LQuery.ParamByName('CLI').AsLargeInt := LClienteId;
        LQuery.ParamByName('NUM').AsInteger := LNumero;
        LQuery.ParamByName('USR').AsLargeInt := LUsuarioId;
        LQuery.ParamByName('SUB').AsFloat := LSubtotal;
        LQuery.ParamByName('DESC').AsFloat := LDesconto;
        LQuery.ParamByName('TOT').AsFloat := LTotal;
        LQuery.ParamByName('OBS').AsString := LObservacoes;
        LQuery.ExecSQL;

        { Segunda passada: grava os itens com os totais recalculados }
        for I := 0 to LItens.Count - 1 do
        begin
          LItem := TJSONObject(LItens.Items[I]);
          LProdutoId := LItem.Get('produto_id', Int64(0));
          LQuantidade := LItem.Get('quantidade', Double(0));
          LDescontoItem := LItem.Get('desconto', Double(0));

          LQuery.SQL.Text :=
            'SELECT PRECO_VENDA FROM PRODUTO WHERE ID = :ID';
          LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
          LQuery.Open;
          if LItem.Find('valor_unitario') = nil then
            LValorUnitario := LQuery.FieldByName('PRECO_VENDA').AsFloat
          else
            LValorUnitario := LItem.Get('valor_unitario', Double(0));
          LQuery.Close;

          LTotalItem := (LQuantidade * LValorUnitario) - LDescontoItem;

          LQuery.SQL.Text :=
            'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, ' +
            'PRECO_UNITARIO, VALOR_UNITARIO, DESCONTO, VALOR_TOTAL) ' +
            'VALUES (:PED, :PROD, :QTD, :PRECO, :VLR, :DESC, :TOT)';
          LQuery.ParamByName('PED').AsLargeInt := LOrcamentoId;
          LQuery.ParamByName('PROD').AsLargeInt := LProdutoId;
          LQuery.ParamByName('QTD').AsFloat := LQuantidade;
          LQuery.ParamByName('PRECO').AsFloat := LValorUnitario;
          LQuery.ParamByName('VLR').AsFloat := LValorUnitario;
          LQuery.ParamByName('DESC').AsFloat := LDescontoItem;
          LQuery.ParamByName('TOT').AsFloat := LTotalItem;
          LQuery.ExecSQL;
        end;

        LConexao.Confirmar;

        LResposta := TJSONObject.Create;
        try
          LResposta.Add('id', LOrcamentoId);
          LResposta.Add('numero', LNumero);
          LResposta.Add('subtotal', LSubtotal);
          LResposta.Add('desconto', LDesconto);
          LResposta.Add('total', LTotal);
          LResposta.Add('message', 'Orçamento salvo com sucesso');
          Res.Send(LResposta.AsJSON).Status(THTTPStatus.Created);
        finally
          LResposta.Free;
        end;
      finally
        LQuery.Free;
      end;
    finally
      LData.Free;
    end;
  except
    on E: Exception do
    begin
      try
        TConexao.GetInstance.Cancelar;
      except
      end;
      Res.Send(ErroJSON(E.Message)).Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

{ ------------------------------------------------------------
  POST /api/orcamentos/:id/converter
  ------------------------------------------------------------ }

procedure ConverterOrcamento(Req: THorseRequest; Res: THorseResponse);
var
  LId: Int64;
  LUsuarioId, LEmpresaId: Int64;
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LStatus: string;
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  if LId <= 0 then
  begin
    Res.Send(ErroJSON('ID inválido')).Status(THTTPStatus.BadRequest);
    Exit;
  end;

  DadosDoToken(Req, LUsuarioId, LEmpresaId);
  if LEmpresaId <= 0 then
  begin
    Res.Send(ErroJSON('Token sem empresa. Entre novamente.')).Status(THTTPStatus.Unauthorized);
    Exit;
  end;

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LConexao.IniciarTransacao;

    LQuery.SQL.Text :=
      'SELECT STATUS FROM PEDIDO_VENDA WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;

    if LQuery.IsEmpty then
    begin
      LConexao.Cancelar;
      Res.Send(ErroJSON('Orçamento não encontrado')).Status(THTTPStatus.NotFound);
      Exit;
    end;

    LStatus := Trim(LQuery.FieldByName('STATUS').AsString);
    LQuery.Close;

    if LStatus <> 'O' then
    begin
      LConexao.Cancelar;
      Res.Send(ErroJSON('Somente orçamentos em aberto podem ser convertidos.'))
        .Status(THTTPStatus.Conflict);
      Exit;
    end;

    LQuery.SQL.Text :=
      'UPDATE PEDIDO_VENDA SET STATUS = ''P'' ' +
      'WHERE ID = :ID AND STATUS = ''O'' AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.ExecSQL;

    { Outra requisição pode ter convertido entre o SELECT e o UPDATE }
    if LQuery.RowsAffected = 0 then
    begin
      LConexao.Cancelar;
      Res.Send(ErroJSON('Somente orçamentos em aberto podem ser convertidos.'))
        .Status(THTTPStatus.Conflict);
      Exit;
    end;

    LConexao.Confirmar;

    Res.Send('{"message":"Orçamento convertido em pedido"}').Status(THTTPStatus.OK);
  except
    on E: Exception do
    begin
      try
        LConexao.Cancelar;
      except
      end;
      Res.Send(ErroJSON(E.Message)).Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

procedure RegistrarRotasOrcamentos;
begin
  THorse.Get('/api/orcamentos', @GetOrcamentos);
  THorse.Get('/api/orcamentos/:id', @GetOrcamentoById);
  THorse.Post('/api/orcamentos', @PostOrcamento);
  THorse.Post('/api/orcamentos/:id/converter', @ConverterOrcamento);
end;

end.
