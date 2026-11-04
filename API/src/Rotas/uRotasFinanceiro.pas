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
  SysUtils, fpjson, jsonparser, SQLDB, uConexao, uMiddlewareJWT;

procedure GetResumoFinanceiro(Req: THorseRequest; Res: THorseResponse);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
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

    LObj := TJSONObject.Create;

    // Contas a Receber
    // CAST para DOUBLE PRECISION: sem isto o driver devolve o SUM(CASE ...)
    // como BCD nulo (NUMERIC(18,4)), e o resumo saia sempre zerado.
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(CASE WHEN STATUS = ''A'' THEN VALOR ELSE 0 END), 0) AS DOUBLE PRECISION) AS A_RECEBER, ' +
      'CAST(COALESCE(SUM(CASE WHEN STATUS = ''P'' THEN VALOR_PAGO ELSE 0 END), 0) AS DOUBLE PRECISION) AS RECEBIDO ' +
      'FROM CONTA_RECEBER WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;
    LObj.Add('a_receber', LQuery.FieldByName('A_RECEBER').AsFloat);
    LObj.Add('recebido', LQuery.FieldByName('RECEBIDO').AsFloat);
    LQuery.Close;

    // Contas a Pagar
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(CASE WHEN STATUS = ''A'' THEN VALOR ELSE 0 END), 0) AS DOUBLE PRECISION) AS A_PAGAR, ' +
      'CAST(COALESCE(SUM(CASE WHEN STATUS = ''P'' THEN VALOR_PAGO ELSE 0 END), 0) AS DOUBLE PRECISION) AS PAGO ' +
      'FROM CONTA_PAGAR WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;
    LObj.Add('a_pagar', LQuery.FieldByName('A_PAGAR').AsFloat);
    LObj.Add('pago', LQuery.FieldByName('PAGO').AsFloat);
    LQuery.Close;

    // Faturamento do mês
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(TOTAL), 0) AS DOUBLE PRECISION) AS FATURAMENTO_MES ' +
      'FROM PEDIDO_VENDA WHERE STATUS = ''F'' AND EMPRESA_ID = :EMP ' +
      'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) ' +
      'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LQuery.Open;
    LObj.Add('faturamento_mes', LQuery.FieldByName('FATURAMENTO_MES').AsFloat);
    LQuery.Close;

    // Vendas do mês
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS QTD_VENDAS FROM PEDIDO_VENDA ' +
      'WHERE STATUS IN (''F'', ''A'') AND EMPRESA_ID = :EMP ' +
      'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) ' +
      'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
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
      'SELECT CR.ID, C.NOME AS CLIENTE, CR.DESCRICAO, CR.VALOR, ' +
      'CR.DATA_VENCIMENTO, CR.STATUS ' +
      'FROM CONTA_RECEBER CR LEFT JOIN PESSOA C ON C.ID = CR.CLIENTE_ID AND C.TIPO = ''C'' ' +
      'WHERE CR.STATUS = ''A'' AND CR.EMPRESA_ID = :EMP ' +
      'ORDER BY CR.DATA_VENCIMENTO ROWS 100';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
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
      'SELECT CP.ID, COALESCE(F.NOME_FANTASIA, F.NOME) AS FORNECEDOR, CP.DESCRICAO, CP.VALOR, ' +
      'CP.DATA_VENCIMENTO, CP.STATUS ' +
      'FROM CONTA_PAGAR CP LEFT JOIN PESSOA F ON F.ID = CP.FORNECEDOR_ID AND F.TIPO = ''F'' ' +
      'WHERE CP.STATUS = ''A'' AND CP.EMPRESA_ID = :EMP ' +
      'ORDER BY CP.DATA_VENCIMENTO ROWS 100';
    LQuery.ParamByName('EMP').AsLargeInt := LEmpresaId;
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
