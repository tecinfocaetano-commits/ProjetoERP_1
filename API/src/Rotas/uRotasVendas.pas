unit uRotasVendas;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rotas de Vendas
  Endpoints: GET/POST /api/vendas
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasVendas;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uPedidoStatus;

procedure GetVendas(Req: THorseRequest; Res: THorseResponse);
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
      'SELECT PV.ID, PV.NUMERO, C.NOME AS CLIENTE, PV.TOTAL, PV.DATA_EMISSAO, ' +
      // rótulos de status centralizados em uPedidoStatus; 'O' (orçamento) à parte
      'CASE WHEN PV.STATUS = ''O'' THEN ''Orçamento'' ELSE ' +
        SqlCaseStatusPedido('PV.STATUS') + ' END AS STATUS ' +
      'FROM PEDIDO_VENDA PV LEFT JOIN CLIENTE C ON C.ID = PV.CLIENTE_ID ' +
      'ORDER BY PV.DATA_EMISSAO DESC ROWS 100';
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
begin
  LId := StrToInt64Def(Req.Params['id'], 0);
  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Cabeçalho
    LQuery.SQL.Text :=
      'SELECT PV.*, C.NOME AS CLIENTE_NOME FROM PEDIDO_VENDA PV ' +
      'LEFT JOIN CLIENTE C ON C.ID = PV.CLIENTE_ID WHERE PV.ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
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

procedure RegistrarRotasVendas;
begin
  THorse.Get('/api/vendas', @GetVendas);
  THorse.Get('/api/vendas/:id', @GetVendaById);
end;

end.
