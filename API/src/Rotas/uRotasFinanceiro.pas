unit uRotasFinanceiro;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - Rotas Financeiro
  Endpoints: GET /api/financeiro
  ============================================================ }

interface

uses
  Horse;

procedure RegistrarRotasFinanceiro;

implementation

uses
  SysUtils, fpjson, jsonparser, SQLDB, uConexao;

procedure GetResumoFinanceiro(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LObj: TJSONObject;
begin
  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    LObj := TJSONObject.Create;

    // Contas a Receber
    LQuery.SQL.Text :=
      'SELECT COALESCE(SUM(CASE WHEN STATUS = ''A'' THEN VALOR ELSE 0 END), 0) AS A_RECEBER, ' +
      'COALESCE(SUM(CASE WHEN STATUS = ''P'' THEN VALOR_PAGO ELSE 0 END), 0) AS RECEBIDO ' +
      'FROM CONTA_RECEBER';
    LQuery.Open;
    LObj.Add('a_receber', LQuery.FieldByName('A_RECEBER').AsFloat);
    LObj.Add('recebido', LQuery.FieldByName('RECEBIDO').AsFloat);
    LQuery.Close;

    // Contas a Pagar
    LQuery.SQL.Text :=
      'SELECT COALESCE(SUM(CASE WHEN STATUS = ''A'' THEN VALOR ELSE 0 END), 0) AS A_PAGAR, ' +
      'COALESCE(SUM(CASE WHEN STATUS = ''P'' THEN VALOR_PAGO ELSE 0 END), 0) AS PAGO ' +
      'FROM CONTA_PAGAR';
    LQuery.Open;
    LObj.Add('a_pagar', LQuery.FieldByName('A_PAGAR').AsFloat);
    LObj.Add('pago', LQuery.FieldByName('PAGO').AsFloat);
    LQuery.Close;

    // Faturamento do mês
    LQuery.SQL.Text :=
      'SELECT COALESCE(SUM(TOTAL), 0) AS FATURAMENTO_MES ' +
      'FROM PEDIDO_VENDA WHERE STATUS = ''F'' ' +
      'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) ' +
      'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)';
    LQuery.Open;
    LObj.Add('faturamento_mes', LQuery.FieldByName('FATURAMENTO_MES').AsFloat);
    LQuery.Close;

    // Vendas do mês
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS QTD_VENDAS FROM PEDIDO_VENDA ' +
      'WHERE STATUS IN (''F'', ''A'') ' +
      'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) ' +
      'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)';
    LQuery.Open;
    LObj.Add('vendas_mes', LQuery.FieldByName('QTD_VENDAS').AsInteger);

    Res.Send(LObj.AsJSON).Status(THTTPStatus.OK);
    LObj.Free;
  finally
    LQuery.Free;
  end;
end;

procedure GetContasReceber(Req: THorseRequest; Res: THorseResponse);
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
      'SELECT CR.ID, C.NOME AS CLIENTE, CR.DESCRICAO, CR.VALOR, ' +
      'CR.DATA_VENCIMENTO, CR.STATUS ' +
      'FROM CONTA_RECEBER CR LEFT JOIN CLIENTE C ON C.ID = CR.CLIENTE_ID ' +
      'WHERE CR.STATUS = ''A'' ORDER BY CR.DATA_VENCIMENTO ROWS 100';
    LQuery.Open;

    LArray := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('cliente', LQuery.FieldByName('CLIENTE').AsString);
      LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
      LObj.Add('valor', LQuery.FieldByName('VALOR').AsFloat);
      LObj.Add('vencimento', LQuery.FieldByName('DATA_VENCIMENTO').AsString);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

procedure GetContasPagar(Req: THorseRequest; Res: THorseResponse);
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
      'SELECT CP.ID, F.NOME_FANTASIA AS FORNECEDOR, CP.DESCRICAO, CP.VALOR, ' +
      'CP.DATA_VENCIMENTO, CP.STATUS ' +
      'FROM CONTA_PAGAR CP LEFT JOIN FORNECEDOR F ON F.ID = CP.FORNECEDOR_ID ' +
      'WHERE CP.STATUS = ''A'' ORDER BY CP.DATA_VENCIMENTO ROWS 100';
    LQuery.Open;

    LArray := TJSONArray.Create;
    while not LQuery.EOF do
    begin
      LObj := TJSONObject.Create;
      LObj.Add('id', LQuery.FieldByName('ID').AsLargeInt);
      LObj.Add('fornecedor', LQuery.FieldByName('FORNECEDOR').AsString);
      LObj.Add('descricao', LQuery.FieldByName('DESCRICAO').AsString);
      LObj.Add('valor', LQuery.FieldByName('VALOR').AsFloat);
      LObj.Add('vencimento', LQuery.FieldByName('DATA_VENCIMENTO').AsString);
      LArray.Add(LObj);
      LQuery.Next;
    end;
    Res.Send(LArray.AsJSON).Status(THTTPStatus.OK);
    LArray.Free;
  finally
    LQuery.Free;
  end;
end;

procedure RegistrarRotasFinanceiro;
begin
  THorse.Get('/api/financeiro', @GetResumoFinanceiro);
  THorse.Get('/api/financeiro/receber', @GetContasReceber);
  THorse.Get('/api/financeiro/pagar', @GetContasPagar);
end;

end.
