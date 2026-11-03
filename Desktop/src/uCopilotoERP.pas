unit uCopilotoERP;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 9 - Copiloto ERP (Inteligência Artificial)
  Descrição: Motor de processamento de linguagem natural para
             consultas ao banco de dados do ERP
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, IBConnection;

type
  TTipoPergunta = (
    tpFaturamento,
    tpInadimplentes,
    tpEstoque,
    tpProdutosSemVenda,
    tpTopClientes,
    tpTopProdutos,
    tpContasVencidas,
    tpFornecedorCredito,
    tpFluxoCaixa,
    tpComparativoMensal,
    tpEstoqueBaixo,
    tpSugestaoCompra,
    tpDesconhecido
  );

  TRespostaCopiloto = record
    Pergunta: string;
    SQL: string;
    Resposta: string;
    Tipo: TTipoPergunta;
    Sucesso: Boolean;
  end;

  { TCopilotoERP }
  TCopilotoERP = class
  private
    FConnection: TIBConnection;
    FTransaction: TSQLTransaction;
    function ClassificarPergunta(const APergunta: string): TTipoPergunta;
    function GerarSQL(ATipo: TTipoPergunta; const APergunta: string): string;
    function ExecutarSQL(const ASQL: string): string;
    function ExtrairPeriodo(const APergunta: string): string;
    function ContemPalavra(const ATexto, APalavra: string): Boolean;
  public
    constructor Create(AConnection: TIBConnection; ATransaction: TSQLTransaction);
    function Perguntar(const APergunta: string): TRespostaCopiloto;
    function ObterSugestaoEstoque: string;
    function ObterSugestaoCompra: string;
    function ObterAlertasFinanceiros: string;
    function ObterInsightsVendas: string;
  end;

implementation

constructor TCopilotoERP.Create(AConnection: TIBConnection; ATransaction: TSQLTransaction);
begin
  inherited Create;
  FConnection := AConnection;
  FTransaction := ATransaction;
end;

function TCopilotoERP.ContemPalavra(const ATexto, APalavra: string): Boolean;
begin
  Result := Pos(UpperCase(APalavra), UpperCase(ATexto)) > 0;
end;

function TCopilotoERP.ClassificarPergunta(const APergunta: string): TTipoPergunta;
var
  LP: string;
begin
  LP := UpperCase(APergunta);

  if ContemPalavra(LP, 'FATURAMENTO') or ContemPalavra(LP, 'FATUREI') or
     ContemPalavra(LP, 'VENDAS TOTAL') or ContemPalavra(LP, 'RECEITA') then
    Result := tpFaturamento
  else if ContemPalavra(LP, 'INADIMPLENTE') or ContemPalavra(LP, 'DEVENDO') or
          ContemPalavra(LP, 'ATRASAD') then
    Result := tpInadimplentes
  else if ContemPalavra(LP, 'ESTOQUE BAIXO') or ContemPalavra(LP, 'ABAIXO DO MINIMO') or
          ContemPalavra(LP, 'ESTOQUE MINIMO') then
    Result := tpEstoqueBaixo
  else if ContemPalavra(LP, 'SEM VENDA') or ContemPalavra(LP, 'PARADO') or
          ContemPalavra(LP, 'ENCALHADO') then
    Result := tpProdutosSemVenda
  else if ContemPalavra(LP, 'TOP CLIENTE') or ContemPalavra(LP, 'MELHOR CLIENTE') or
          ContemPalavra(LP, 'MAIORES CLIENTE') then
    Result := tpTopClientes
  else if ContemPalavra(LP, 'TOP PRODUTO') or ContemPalavra(LP, 'MAIS VENDIDO') or
          ContemPalavra(LP, 'PRODUTO MAIS') then
    Result := tpTopProdutos
  else if ContemPalavra(LP, 'CONTAS VENCIDAS') or ContemPalavra(LP, 'VENCENDO') or
          ContemPalavra(LP, 'PAGAR HOJE') then
    Result := tpContasVencidas
  else if ContemPalavra(LP, 'FORNECEDOR') and (ContemPalavra(LP, 'CREDITO') or ContemPalavra(LP, 'CRÉDITO')) then
    Result := tpFornecedorCredito
  else if ContemPalavra(LP, 'FLUXO') or ContemPalavra(LP, 'CAIXA') then
    Result := tpFluxoCaixa
  else if ContemPalavra(LP, 'COMPARATIV') or ContemPalavra(LP, 'MES ANTERIOR') or
          ContemPalavra(LP, 'EVOLUÇÃO') then
    Result := tpComparativoMensal
  else if ContemPalavra(LP, 'SUGESTAO COMPRA') or ContemPalavra(LP, 'PRECISO COMPRAR') or
          ContemPalavra(LP, 'REPOR') then
    Result := tpSugestaoCompra
  else if ContemPalavra(LP, 'ESTOQUE') or ContemPalavra(LP, 'QUANTIDAD') then
    Result := tpEstoque
  else
    Result := tpDesconhecido;
end;

function TCopilotoERP.ExtrairPeriodo(const APergunta: string): string;
var
  LP: string;
begin
  LP := UpperCase(APergunta);
  if ContemPalavra(LP, 'HOJE') then
    Result := 'AND CAST(DATA_EMISSAO AS DATE) = CURRENT_DATE'
  else if ContemPalavra(LP, 'SEMANA') then
    Result := 'AND DATA_EMISSAO >= CURRENT_DATE - 7'
  else if ContemPalavra(LP, 'MES') or ContemPalavra(LP, 'MÊS') then
    Result := 'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) ' +
              'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)'
  else if ContemPalavra(LP, 'ANO') then
    Result := 'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)'
  else
    Result := 'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) ' +
              'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)';
end;

function TCopilotoERP.GerarSQL(ATipo: TTipoPergunta; const APergunta: string): string;
begin
  case ATipo of
    tpFaturamento:
      Result := 'SELECT COALESCE(SUM(TOTAL), 0) AS VALOR FROM PEDIDO_VENDA ' +
                'WHERE STATUS IN (''F'', ''A'') ' + ExtrairPeriodo(APergunta);

    tpInadimplentes:
      Result := 'SELECT C.NOME, CR.VALOR, CR.DATA_VENCIMENTO ' +
                'FROM CONTA_RECEBER CR JOIN PESSOA C ON C.ID = CR.CLIENTE_ID AND C.TIPO = ''C'' ' +
                'WHERE CR.STATUS = ''A'' AND CR.DATA_VENCIMENTO < CURRENT_DATE ' +
                'ORDER BY CR.DATA_VENCIMENTO';

    tpEstoque:
      Result := 'SELECT P.DESCRICAO, COALESCE(E.QUANTIDADE, 0) AS QTD ' +
                'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
                'WHERE P.ATIVO = ''A'' ORDER BY P.DESCRICAO';

    tpEstoqueBaixo:
      Result := 'SELECT P.DESCRICAO, COALESCE(E.QUANTIDADE, 0) AS QTD_ATUAL, P.ESTOQUE_MINIMO ' +
                'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
                'WHERE P.CONTROLA_ESTOQUE = ''S'' AND COALESCE(E.QUANTIDADE, 0) < P.ESTOQUE_MINIMO ' +
                'AND P.ESTOQUE_MINIMO > 0 ORDER BY (P.ESTOQUE_MINIMO - COALESCE(E.QUANTIDADE, 0)) DESC';

    tpProdutosSemVenda:
      Result := 'SELECT P.DESCRICAO, P.PRECO_VENDA FROM PRODUTO P ' +
                'WHERE P.ATIVO = ''A'' AND P.ID NOT IN ' +
                '(SELECT DISTINCT IP.PRODUTO_ID FROM ITEM_PEDIDO IP ' +
                'JOIN PEDIDO_VENDA PV ON PV.ID = IP.PEDIDO_VENDA_ID ' +
                'WHERE PV.DATA_EMISSAO >= CURRENT_DATE - 90) ' +
                'ORDER BY P.DESCRICAO';

    tpTopClientes:
      Result := 'SELECT FIRST 10 C.NOME, SUM(PV.TOTAL) AS TOTAL_COMPRAS, COUNT(*) AS QTD ' +
                'FROM PEDIDO_VENDA PV JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
                'WHERE PV.STATUS IN (''F'', ''A'') ' +
                'GROUP BY C.NOME ORDER BY TOTAL_COMPRAS DESC';

    tpTopProdutos:
      Result := 'SELECT FIRST 10 P.DESCRICAO, SUM(IP.QUANTIDADE) AS QTD_VENDIDA, ' +
                'SUM(IP.VALOR_TOTAL) AS VALOR_TOTAL ' +
                'FROM ITEM_PEDIDO IP JOIN PRODUTO P ON P.ID = IP.PRODUTO_ID ' +
                'JOIN PEDIDO_VENDA PV ON PV.ID = IP.PEDIDO_VENDA_ID ' +
                'WHERE PV.STATUS IN (''F'', ''A'') ' +
                'GROUP BY P.DESCRICAO ORDER BY QTD_VENDIDA DESC';

    tpContasVencidas:
      Result := 'SELECT ''A Receber'' AS TIPO, C.NOME AS ENTIDADE, CR.VALOR, CR.DATA_VENCIMENTO ' +
                'FROM CONTA_RECEBER CR LEFT JOIN PESSOA C ON C.ID = CR.CLIENTE_ID AND C.TIPO = ''C'' ' +
                'WHERE CR.STATUS = ''A'' AND CR.DATA_VENCIMENTO <= CURRENT_DATE ' +
                'UNION ALL ' +
                'SELECT ''A Pagar'', F.NOME, CP.VALOR, CP.DATA_VENCIMENTO ' +
                'FROM CONTA_PAGAR CP LEFT JOIN PESSOA F ON F.ID = CP.FORNECEDOR_ID AND F.TIPO = ''F'' ' +
                'WHERE CP.STATUS = ''A'' AND CP.DATA_VENCIMENTO <= CURRENT_DATE ' +
                'ORDER BY 4';

    tpFornecedorCredito:
      Result := 'SELECT FIRST 10 F.NOME, SUM(CP.VALOR) AS TOTAL_COMPRAS ' +
                'FROM CONTA_PAGAR CP JOIN PESSOA F ON F.ID = CP.FORNECEDOR_ID AND F.TIPO = ''F'' ' +
                'GROUP BY F.NOME ORDER BY TOTAL_COMPRAS DESC';

    tpFluxoCaixa:
      { CAST obrigatório: o SQLDB lê COALESCE((subquery),0) sem tipo como 0 }
      Result := 'SELECT ' +
                'CAST(COALESCE((SELECT SUM(VALOR) FROM CONTA_RECEBER WHERE STATUS = ''A'' AND DATA_VENCIMENTO <= CURRENT_DATE + 30), 0) AS NUMERIC(18,4)) AS RECEBER_30D, ' +
                'CAST(COALESCE((SELECT SUM(VALOR) FROM CONTA_PAGAR WHERE STATUS = ''A'' AND DATA_VENCIMENTO <= CURRENT_DATE + 30), 0) AS NUMERIC(18,4)) AS PAGAR_30D ' +
                'FROM RDB$DATABASE';

    tpComparativoMensal:
      { CAST obrigatório: idem (SQLDB lê 0 sem tipo) }
      Result := 'SELECT ' +
                'CAST(COALESCE((SELECT SUM(TOTAL) FROM PEDIDO_VENDA WHERE STATUS IN (''F'',''A'') ' +
                'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) ' +
                'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)), 0) AS NUMERIC(18,4)) AS MES_ATUAL, ' +
                'CAST(COALESCE((SELECT SUM(TOTAL) FROM PEDIDO_VENDA WHERE STATUS IN (''F'',''A'') ' +
                'AND EXTRACT(MONTH FROM DATA_EMISSAO) = EXTRACT(MONTH FROM CURRENT_DATE) - 1 ' +
                'AND EXTRACT(YEAR FROM DATA_EMISSAO) = EXTRACT(YEAR FROM CURRENT_DATE)), 0) AS NUMERIC(18,4)) AS MES_ANTERIOR ' +
                'FROM RDB$DATABASE';

    tpSugestaoCompra:
      Result := 'SELECT P.DESCRICAO, COALESCE(E.QUANTIDADE, 0) AS QTD_ATUAL, ' +
                'P.ESTOQUE_MINIMO, (P.ESTOQUE_MAXIMO - COALESCE(E.QUANTIDADE, 0)) AS QTD_SUGERIDA, ' +
                'P.PRECO_CUSTO, ((P.ESTOQUE_MAXIMO - COALESCE(E.QUANTIDADE, 0)) * P.PRECO_CUSTO) AS VALOR_ESTIMADO ' +
                'FROM PRODUTO P LEFT JOIN ESTOQUE E ON E.PRODUTO_ID = P.ID ' +
                'WHERE P.CONTROLA_ESTOQUE = ''S'' AND COALESCE(E.QUANTIDADE, 0) < P.ESTOQUE_MINIMO ' +
                'AND P.ESTOQUE_MINIMO > 0 ORDER BY QTD_SUGERIDA DESC';
  else
    Result := '';
  end;
end;

function TCopilotoERP.ExecutarSQL(const ASQL: string): string;
var
  LQuery: TSQLQuery;
  I: Integer;
  LLinha: string;
  LCount: Integer;
begin
  Result := '';
  if ASQL = '' then Exit;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConnection;
    LQuery.Transaction := FTransaction;
    LQuery.SQL.Text := ASQL;
    LQuery.Open;

    LCount := 0;
    while (not LQuery.EOF) and (LCount < 50) do
    begin
      LLinha := '';
      for I := 0 to LQuery.FieldCount - 1 do
      begin
        if I > 0 then LLinha := LLinha + ' | ';
        LLinha := LLinha + LQuery.Fields[I].FieldName + ': ' + LQuery.Fields[I].AsString;
      end;
      Result := Result + LLinha + #13#10;
      LQuery.Next;
      Inc(LCount);
    end;

    if LCount = 0 then
      Result := 'Nenhum resultado encontrado.';
  finally
    LQuery.Free;
  end;
end;

function TCopilotoERP.Perguntar(const APergunta: string): TRespostaCopiloto;
begin
  Result.Pergunta := APergunta;
  Result.Tipo := ClassificarPergunta(APergunta);

  if Result.Tipo = tpDesconhecido then
  begin
    Result.SQL := '';
    Result.Resposta :=
      'Desculpe, não entendi sua pergunta. Tente perguntar sobre:' + #13#10 +
      '- "Qual meu faturamento do mês?"' + #13#10 +
      '- "Quais clientes estão inadimplentes?"' + #13#10 +
      '- "Quais produtos estão sem venda há 90 dias?"' + #13#10 +
      '- "Qual fornecedor gera maior crédito?"' + #13#10 +
      '- "Quais produtos estão abaixo do estoque mínimo?"' + #13#10 +
      '- "Quais contas estão vencidas?"' + #13#10 +
      '- "Qual o fluxo de caixa dos próximos 30 dias?"' + #13#10 +
      '- "Qual o comparativo com o mês anterior?"' + #13#10 +
      '- "Quais os top 10 clientes?"' + #13#10 +
      '- "Quais os produtos mais vendidos?"' + #13#10 +
      '- "Sugestão de compra"';
    Result.Sucesso := False;
    Exit;
  end;

  Result.SQL := GerarSQL(Result.Tipo, APergunta);

  try
    Result.Resposta := ExecutarSQL(Result.SQL);
    Result.Sucesso := True;
  except
    on E: Exception do
    begin
      Result.Resposta := 'Erro ao executar consulta: ' + E.Message;
      Result.Sucesso := False;
    end;
  end;
end;

function TCopilotoERP.ObterSugestaoEstoque: string;
var
  LResp: TRespostaCopiloto;
begin
  LResp := Perguntar('Produtos abaixo do estoque mínimo');
  if LResp.Sucesso then
    Result := '=== ALERTA DE ESTOQUE ===' + #13#10 + LResp.Resposta
  else
    Result := 'Sem alertas de estoque no momento.';
end;

function TCopilotoERP.ObterSugestaoCompra: string;
var
  LResp: TRespostaCopiloto;
begin
  LResp := Perguntar('Sugestão de compra para repor estoque');
  if LResp.Sucesso then
    Result := '=== SUGESTÃO DE COMPRAS ===' + #13#10 + LResp.Resposta
  else
    Result := 'Sem sugestões de compra no momento.';
end;

function TCopilotoERP.ObterAlertasFinanceiros: string;
var
  LResp: TRespostaCopiloto;
begin
  LResp := Perguntar('Contas vencidas hoje');
  if LResp.Sucesso then
    Result := '=== ALERTAS FINANCEIROS ===' + #13#10 + LResp.Resposta
  else
    Result := 'Sem alertas financeiros.';
end;

function TCopilotoERP.ObterInsightsVendas: string;
var
  LComp: TRespostaCopiloto;
  LTop: TRespostaCopiloto;
begin
  LComp := Perguntar('Comparativo com mês anterior');
  LTop := Perguntar('Produtos mais vendidos');

  Result := '=== INSIGHTS DE VENDAS ===' + #13#10;
  if LComp.Sucesso then
    Result := Result + #13#10 + 'COMPARATIVO MENSAL:' + #13#10 + LComp.Resposta;
  if LTop.Sucesso then
    Result := Result + #13#10 + 'TOP PRODUTOS:' + #13#10 + LTop.Resposta;
end;

end.
