unit uNotaSaidaService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 2 - Nota de Saída (faturamento de venda)
  ------------------------------------------------------------
  Concentra as regras de negócio do faturamento:

    - CriarDoPedido: gera a nota a partir de um PEDIDO_VENDA
      (copia cliente, condição de pagamento e itens);
    - RecalcularTotais: totais do cabeçalho a partir dos itens;
    - Faturar: baixa o estoque (MOVIMENTO_ESTOQUE TIPO = 'S'),
      gera as parcelas em CONTA_RECEBER, apura a chave de acesso
      (44 dígitos, com dígito verificador) e marca o pedido como
      Faturado (NUMERO_NFE / CHAVE_NFE);
    - Cancelar: nota Aberta apenas muda para Cancelada; nota já
      faturada é estornada (estoque devolvido por movimento de
      entrada e parcelas em aberto canceladas);
    - GerarXML: monta o XML da NF-e (gancho para o ACBr emitir o
      documento com assinatura e transmissão à SEFAZ).

  O saldo de ESTOQUE é mantido pelo trigger TRG_MOVEST_AI a partir
  de MOVIMENTO_ESTOQUE; aqui apenas gravamos os movimentos.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, DB, uConexao;

type
  ENotaSaida = class(Exception);

  TNotaSaidaService = class
  private
    FConexao: TConexao;
    function  NovaConsulta: TSQLQuery;
    function  LerSaldo(AEmpresaId, AProdutoId: Int64; out AQuantidade: Double): Boolean;
    function  GarantirFinanceiro(const ATipo, ADescricao: string): Int64;
    function  ProximoNumero: Integer;
    function  CustoUnitario(AEmpresaId, AProdutoId: Int64): Double;
    function  StatusDaNota(ANotaId: Int64): string;
    procedure GerarContasReceber(ANotaId: Int64);
    function  DigitoChave(const ABase: string): Integer;
  public
    constructor Create;

    function  NotaDoPedido(APedidoId: Int64): Int64;
    function  CriarDoPedido(APedidoId: Int64): Int64;
    function  QuantidadeItens(ANotaId: Int64): Integer;
    function  PrimeiroItemSemProduto(ANotaId: Int64): string;
    function  VerificarSaldo(ANotaId: Int64; out ADescricao: string;
      out ADisponivel, ASolicitado: Double): Boolean;
    procedure RecalcularTotais(ANotaId: Int64);
    procedure AtualizarCabecalho(ANotaId, AClienteId: Int64;
      const ANumero, ASerie, AModelo, ANatureza, ACFOP: string;
      ADataEmissao, ADataSaida: TDate; ACondicaoId: Int64;
      AFrete, ASeguro, AOutras: Double);
    function  GerarChaveAcesso(ANotaId: Int64): string;
    procedure Faturar(ANotaId: Int64);
    procedure Cancelar(ANotaId: Int64; const AMotivo: string);
    procedure ExcluirItem(AItemId: Int64);
    function  GerarXML(ANotaId: Int64): string;
  end;

implementation

uses
  Math, DateUtils, uSessao;

type
  TItemSaida = record
    Id: Int64;
    ProdutoId: Int64;
    Descricao: string;
    Quantidade: Double;
    ValorUnitario: Double;
    AtualizaEstoque: Boolean;
  end;

constructor TNotaSaidaService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TNotaSaidaService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConexao.Connection;
  Result.Transaction := FConexao.Transaction;
end;

// Localiza (ou cria) o registro do plano financeiro usado pelas contas a
// receber da empresa. Necessário porque CONTA_RECEBER.FINANCEIRO_ID e
// CLIENTE_ID usam o domínio DM_ID, que é NOT NULL.
function TNotaSaidaService.GarantirFinanceiro(const ATipo,
  ADescricao: string): Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM FINANCEIRO ' +
      'WHERE EMPRESA_ID = :EMP AND TIPO = :TIPO ORDER BY ID';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt
    else
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO FINANCEIRO (EMPRESA_ID, TIPO, DESCRICAO, STATUS) ' +
        'VALUES (:EMP, :TIPO, :DESC, ''A'') RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ParamByName('TIPO').AsString := ATipo;
      LQuery.ParamByName('DESC').AsString := ADescricao;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNotaSaidaService.LerSaldo(AEmpresaId, AProdutoId: Int64;
  out AQuantidade: Double): Boolean;
var
  LQuery: TSQLQuery;
begin
  AQuantidade := 0;
  Result := False;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT QUANTIDADE FROM ESTOQUE WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      AQuantidade := LQuery.FieldByName('QUANTIDADE').AsFloat;
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

// Custo usado no movimento de saída: custo médio do estoque; quando ainda
// não houver custo médio, usa o preço de custo cadastrado no produto.
function TNotaSaidaService.CustoUnitario(AEmpresaId, AProdutoId: Int64): Double;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(E.CUSTO_MEDIO, 0) AS NUMERIC(18,4)) AS CUSTO_MEDIO, ' +
      '       CAST(COALESCE(P.PRECO_CUSTO, 0) AS NUMERIC(18,4)) AS PRECO_CUSTO ' +
      'FROM PRODUTO P LEFT JOIN ESTOQUE E ' +
      '  ON E.PRODUTO_ID = P.ID AND E.EMPRESA_ID = :EMP ' +
      'WHERE P.ID = :PROD';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      Result := LQuery.FieldByName('CUSTO_MEDIO').AsFloat;
      if Result <= 0 then
        Result := LQuery.FieldByName('PRECO_CUSTO').AsFloat;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNotaSaidaService.ProximoNumero: Integer;
var
  LQuery: TSQLQuery;
begin
  Result := 1;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COALESCE(MAX(CASE WHEN NUMERO SIMILAR TO ''[0-9]+'' ' +
      '                         THEN CAST(NUMERO AS INTEGER) ELSE 0 END), 0) + 1 AS PROX ' +
      'FROM NOTA_SAIDA';
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('PROX').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TNotaSaidaService.StatusDaNota(ANotaId: Int64): string;
var
  LQuery: TSQLQuery;
begin
  Result := '';
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT STATUS FROM NOTA_SAIDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('STATUS').AsString);
  finally
    LQuery.Free;
  end;
end;

function TNotaSaidaService.NotaDoPedido(APedidoId: Int64): Int64;
var
  LQuery: TSQLQuery;
begin
  Result := 0;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM NOTA_SAIDA ' +
      'WHERE PEDIDO_VENDA_ID = :PED AND STATUS <> ''C'' ORDER BY ID DESC';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

// Gera a nota de saída a partir do pedido de venda (cabeçalho + itens).
function TNotaSaidaService.CriarDoPedido(APedidoId: Int64): Int64;
var
  LPed, LNota, LItens, LProd: TSQLQuery;
  LStatus, LNumero: string;
  LEmpresaId, LClienteId, LCondicaoId, LFormaId: Int64;
  LDataEmissao: TDate;
  LQtd, LVun, LAliq, LVicms, LVTotal: Double;
begin
  FConexao.IniciarTransacao;
  LPed := NovaConsulta;
  LNota := NovaConsulta;
  LItens := NovaConsulta;
  LProd := NovaConsulta;
  try
    LPed.SQL.Text :=
      'SELECT STATUS, EMPRESA_ID, CLIENTE_ID, CONDICAO_PAGAMENTO_ID, ' +
      '       FORMA_PAGAMENTO_ID, NUMERO, COALESCE(DATA_EMISSAO, CURRENT_DATE) AS DATA_EMISSAO ' +
      'FROM PEDIDO_VENDA WHERE ID = :ID';
    LPed.ParamByName('ID').AsLargeInt := APedidoId;
    LPed.Open;
    if LPed.IsEmpty then
      raise ENotaSaida.Create('Pedido de venda não encontrado.');

    LStatus := Trim(LPed.FieldByName('STATUS').AsString);
    if (LStatus = 'F') or (LStatus = 'C') then
      raise ENotaSaida.Create(
        'Este pedido já está faturado ou cancelado. Não é possível gerar a nota de saída.');

    LEmpresaId   := LPed.FieldByName('EMPRESA_ID').AsLargeInt;
    LClienteId   := LPed.FieldByName('CLIENTE_ID').AsLargeInt;
    LCondicaoId  := LPed.FieldByName('CONDICAO_PAGAMENTO_ID').AsLargeInt;
    LFormaId     := LPed.FieldByName('FORMA_PAGAMENTO_ID').AsLargeInt;
    LNumero      := Trim(LPed.FieldByName('NUMERO').AsString);
    LDataEmissao := LPed.FieldByName('DATA_EMISSAO').AsDateTime;

    // Um pedido não pode ter duas notas de saída ativas
    LNota.SQL.Text :=
      'SELECT FIRST 1 ID FROM NOTA_SAIDA ' +
      'WHERE PEDIDO_VENDA_ID = :PED AND STATUS <> ''C'' ORDER BY ID DESC';
    LNota.ParamByName('PED').AsLargeInt := APedidoId;
    LNota.Open;
    if not LNota.IsEmpty then
      raise ENotaSaida.Create('Este pedido já possui uma nota de saída. Cancele-a antes de gerar outra.');
    LNota.Close;

    LNota.SQL.Text :=
      'INSERT INTO NOTA_SAIDA (EMPRESA_ID, CLIENTE_ID, PEDIDO_VENDA_ID, NUMERO, SERIE, ' +
      '  MODELO, NATUREZA_OPERACAO, CFOP, DATA_EMISSAO, DATA_SAIDA, STATUS, ' +
      '  CONDICAO_PAGAMENTO_ID, FORMA_PAGAMENTO_ID, OBSERVACOES, USUARIO_ID) ' +
      'VALUES (:EMP, :CLI, :PED, :NUM, ''1'', ''55'', ''VENDA DE MERCADORIA'', ''5102'', ' +
      '  :EMI, :SAI, ''A'', :COND, :FORMA, :OBS, :USR) RETURNING ID';
    LNota.ParamByName('EMP').AsLargeInt := LEmpresaId;
    LNota.ParamByName('CLI').AsLargeInt := LClienteId;
    LNota.ParamByName('PED').AsLargeInt := APedidoId;
    LNota.ParamByName('NUM').AsString := IntToStr(ProximoNumero);
    LNota.ParamByName('EMI').AsDate := LDataEmissao;
    LNota.ParamByName('SAI').AsDate := Date;
    LNota.ParamByName('OBS').AsString := 'Faturamento do pedido ' + LNumero;
    LNota.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
    if LCondicaoId > 0 then
      LNota.ParamByName('COND').AsLargeInt := LCondicaoId
    else
      LNota.ParamByName('COND').Clear;
    if LFormaId > 0 then
      LNota.ParamByName('FORMA').AsLargeInt := LFormaId
    else
      LNota.ParamByName('FORMA').Clear;
    LNota.Open;
    Result := LNota.FieldByName('ID').AsLargeInt;
    LNota.Close;

    // Itens do pedido -> itens da nota (com os dados fiscais do produto)
    LItens.SQL.Text :=
      'SELECT I.PRODUTO_ID, I.QUANTIDADE, I.DESCONTO, I.CFOP, ' +
      '       COALESCE(I.VALOR_UNITARIO, I.PRECO_UNITARIO, 0) AS VALOR_UNITARIO, ' +
      '       COALESCE(I.ALIQ_ICMS, P.ALIQ_ICMS, 0) AS ALIQ_ICMS, ' +
      '       P.CODIGO, P.DESCRICAO, COALESCE(U.SIGLA, U.ABREVIATURA, ''UN'') AS UNIDADE, ' +
      '       P.NCM, P.CST_ICMS, P.CFOP_VENDA ' +
      'FROM ITEM_PEDIDO I LEFT JOIN PRODUTO P ON P.ID = I.PRODUTO_ID ' +
      '  LEFT JOIN UNIDADE U ON U.ID = P.UNIDADE_ID ' +
      'WHERE I.PEDIDO_VENDA_ID = :PED ORDER BY I.ID';
    LItens.ParamByName('PED').AsLargeInt := APedidoId;
    LItens.Open;
    while not LItens.EOF do
    begin
      // Os valores são calculados aqui (e não em expressões SQL) para não
      // depender da inferência de tipo dos parâmetros pelo Firebird.
      LQtd    := LItens.FieldByName('QUANTIDADE').AsFloat;
      LVun    := LItens.FieldByName('VALOR_UNITARIO').AsFloat;
      LAliq   := LItens.FieldByName('ALIQ_ICMS').AsFloat;
      LVicms  := LQtd * LVun * LAliq / 100;
      LVTotal := LQtd * LVun;

      LProd.SQL.Text :=
        'INSERT INTO NOTA_SAIDA_ITEM (NOTA_SAIDA_ID, PRODUTO_ID, CODIGO, DESCRICAO, UNIDADE, ' +
        '  NCM, CFOP, CST_ICMS, ALIQ_ICMS, VALOR_ICMS, QUANTIDADE, VALOR_UNITARIO, ' +
        '  VALOR_TOTAL, DESCONTO, ATUALIZA_ESTOQUE) ' +
        'VALUES (:NOTA, :PROD, :COD, :DESC, :UN, :NCM, :CFOP, :CST, :ALIQ, :VICMS, ' +
        '  :QTD, :VUN, :VTOT, :DSC, ''S'')';
      LProd.ParamByName('NOTA').AsLargeInt := Result;
      if LItens.FieldByName('PRODUTO_ID').AsLargeInt > 0 then
        LProd.ParamByName('PROD').AsLargeInt := LItens.FieldByName('PRODUTO_ID').AsLargeInt
      else
        LProd.ParamByName('PROD').Clear;
      LProd.ParamByName('COD').AsString := Trim(LItens.FieldByName('CODIGO').AsString);
      LProd.ParamByName('DESC').AsString := Trim(LItens.FieldByName('DESCRICAO').AsString);
      LProd.ParamByName('UN').AsString := Trim(LItens.FieldByName('UNIDADE').AsString);
      LProd.ParamByName('NCM').AsString := Trim(LItens.FieldByName('NCM').AsString);
      if Trim(LItens.FieldByName('CFOP').AsString) <> '' then
        LProd.ParamByName('CFOP').AsString := Trim(LItens.FieldByName('CFOP').AsString)
      else if Trim(LItens.FieldByName('CFOP_VENDA').AsString) <> '' then
        LProd.ParamByName('CFOP').AsString := Trim(LItens.FieldByName('CFOP_VENDA').AsString)
      else
        LProd.ParamByName('CFOP').AsString := '5102';
      LProd.ParamByName('CST').AsString := Trim(LItens.FieldByName('CST_ICMS').AsString);
      LProd.ParamByName('ALIQ').AsFloat := LAliq;
      LProd.ParamByName('VICMS').AsFloat := LVicms;
      LProd.ParamByName('QTD').AsFloat := LQtd;
      LProd.ParamByName('VUN').AsFloat := LVun;
      LProd.ParamByName('VTOT').AsFloat := LVTotal;
      LProd.ParamByName('DSC').AsFloat := LItens.FieldByName('DESCONTO').AsFloat;
      LProd.ExecSQL;
      LItens.Next;
    end;
    LItens.Close;

    RecalcularTotais(Result);
    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LPed.Free;
    LNota.Free;
    LItens.Free;
    LProd.Free;
    raise;
  end;
  LPed.Free;
  LNota.Free;
  LItens.Free;
  LProd.Free;
end;

function TNotaSaidaService.QuantidadeItens(ANotaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS TOTAL FROM NOTA_SAIDA_ITEM WHERE NOTA_SAIDA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    Result := LQuery.FieldByName('TOTAL').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TNotaSaidaService.PrimeiroItemSemProduto(ANotaId: Int64): string;
var
  LQuery: TSQLQuery;
begin
  Result := '';
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 DESCRICAO FROM NOTA_SAIDA_ITEM ' +
      'WHERE NOTA_SAIDA_ID = :ID AND (PRODUTO_ID IS NULL OR PRODUTO_ID = 0) ' +
      'AND ATUALIZA_ESTOQUE = ''S'' ORDER BY ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('DESCRICAO').AsString);
  finally
    LQuery.Free;
  end;
end;

// Verifica se todos os itens que baixam estoque têm saldo suficiente.
function TNotaSaidaService.VerificarSaldo(ANotaId: Int64; out ADescricao: string;
  out ADisponivel, ASolicitado: Double): Boolean;
var
  LQuery: TSQLQuery;
  LEmpresaId: Int64;
  LSaldo: Double;
begin
  Result := True;
  ADescricao := '';
  ADisponivel := 0;
  ASolicitado := 0;

  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT EMPRESA_ID FROM NOTA_SAIDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;
    LEmpresaId := LQuery.FieldByName('EMPRESA_ID').AsLargeInt;
    LQuery.Close;

    LQuery.SQL.Text :=
      'SELECT DESCRICAO, PRODUTO_ID, QUANTIDADE FROM NOTA_SAIDA_ITEM ' +
      'WHERE NOTA_SAIDA_ID = :ID AND ATUALIZA_ESTOQUE = ''S'' ORDER BY ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    while not LQuery.EOF do
    begin
      LerSaldo(LEmpresaId, LQuery.FieldByName('PRODUTO_ID').AsLargeInt, LSaldo);
      if LSaldo < LQuery.FieldByName('QUANTIDADE').AsFloat then
      begin
        Result := False;
        ADescricao := Trim(LQuery.FieldByName('DESCRICAO').AsString);
        ADisponivel := LSaldo;
        ASolicitado := LQuery.FieldByName('QUANTIDADE').AsFloat;
        Break;
      end;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TNotaSaidaService.RecalcularTotais(ANotaId: Int64);
var
  LQuery: TSQLQuery;
  LProdutos, LDesconto, LFrete, LSeguro, LOutras, LIcms, LTotal: Double;
begin
  LQuery := NovaConsulta;
  try
    // Soma dos itens
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(QUANTIDADE * VALOR_UNITARIO), 0) AS NUMERIC(18,4)) AS PRODUTOS, ' +
      '       CAST(COALESCE(SUM(DESCONTO), 0) AS NUMERIC(18,4)) AS DESCONTO, ' +
      '       CAST(COALESCE(SUM(VALOR_ICMS), 0) AS NUMERIC(18,4)) AS ICMS ' +
      'FROM NOTA_SAIDA_ITEM WHERE NOTA_SAIDA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    LProdutos := LQuery.FieldByName('PRODUTOS').AsFloat;
    LDesconto := LQuery.FieldByName('DESCONTO').AsFloat;
    LIcms     := LQuery.FieldByName('ICMS').AsFloat;
    LQuery.Close;

    // Despesas acessórias do cabeçalho
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(VALOR_FRETE, 0) AS NUMERIC(18,4)) AS FRETE, ' +
      '       CAST(COALESCE(VALOR_SEGURO, 0) AS NUMERIC(18,4)) AS SEGURO, ' +
      '       CAST(COALESCE(VALOR_OUTRAS, 0) AS NUMERIC(18,4)) AS OUTRAS ' +
      'FROM NOTA_SAIDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    LFrete  := LQuery.FieldByName('FRETE').AsFloat;
    LSeguro := LQuery.FieldByName('SEGURO').AsFloat;
    LOutras := LQuery.FieldByName('OUTRAS').AsFloat;
    LQuery.Close;

    // Os totais são calculados aqui (parâmetro dentro de expressão aritmética
    // faz o Firebird não conseguir inferir o tipo: "Data type unknown").
    LTotal := LProdutos + LFrete + LSeguro + LOutras - LDesconto;

    LQuery.SQL.Text :=
      'UPDATE NOTA_SAIDA SET VALOR_PRODUTOS = :PRODUTOS, ' +
      '  VALOR_DESCONTO = :DESCONTO, VALOR_ICMS = :ICMS, VALOR_TOTAL = :TOTAL ' +
      'WHERE ID = :ID';
    LQuery.ParamByName('PRODUTOS').AsFloat := LProdutos;
    LQuery.ParamByName('DESCONTO').AsFloat := LDesconto;
    LQuery.ParamByName('ICMS').AsFloat := LIcms;
    LQuery.ParamByName('TOTAL').AsFloat := LTotal;
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

// Atualiza o cabeçalho (somente em nota Aberta) e recalcula os totais.
procedure TNotaSaidaService.AtualizarCabecalho(ANotaId, AClienteId: Int64;
  const ANumero, ASerie, AModelo, ANatureza, ACFOP: string;
  ADataEmissao, ADataSaida: TDate; ACondicaoId: Int64;
  AFrete, ASeguro, AOutras: Double);
var
  LQuery: TSQLQuery;
begin
  if AClienteId <= 0 then
    raise ENotaSaida.Create('Informe o cliente da nota de saída.');

  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    if StatusDaNota(ANotaId) <> 'A' then
      raise ENotaSaida.Create('Somente notas de saída abertas podem ser alteradas.');

    LQuery.SQL.Text :=
      'UPDATE NOTA_SAIDA SET CLIENTE_ID = :CLI, NUMERO = :NUM, SERIE = :SER, ' +
      '  MODELO = :MOD, NATUREZA_OPERACAO = :NAT, CFOP = :CFOP, DATA_EMISSAO = :DEMI, ' +
      '  DATA_SAIDA = :DSAI, CONDICAO_PAGAMENTO_ID = :COND, VALOR_FRETE = :FRETE, ' +
      '  VALOR_SEGURO = :SEGURO, VALOR_OUTRAS = :OUTRAS ' +
      'WHERE ID = :ID';
    LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.ParamByName('SER').AsString := ASerie;
    LQuery.ParamByName('MOD').AsString := AModelo;
    LQuery.ParamByName('NAT').AsString := ANatureza;
    LQuery.ParamByName('CFOP').AsString := ACFOP;
    LQuery.ParamByName('DEMI').AsDate := ADataEmissao;
    LQuery.ParamByName('DSAI').AsDate := ADataSaida;
    if ACondicaoId > 0 then
      LQuery.ParamByName('COND').AsLargeInt := ACondicaoId
    else
      LQuery.ParamByName('COND').Clear;
    LQuery.ParamByName('FRETE').AsFloat := AFrete;
    LQuery.ParamByName('SEGURO').AsFloat := ASeguro;
    LQuery.ParamByName('OUTRAS').AsFloat := AOutras;
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.ExecSQL;

    RecalcularTotais(ANotaId);
    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LQuery.Free;
    raise;
  end;
  LQuery.Free;
end;

// ---------------------------------------------------------------------------
// Chave de acesso (44 dígitos): cUF + AAMM + CNPJ + mod + série + nNF +
// tpEmis + cNF(8) + DV. O dígito verificador é o módulo 11 padrão da NF-e.
// ---------------------------------------------------------------------------

function SomenteDigitos(const AValor: string): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 1 to Length(AValor) do
    if (AValor[LI] >= '0') and (AValor[LI] <= '9') then
      Result := Result + AValor[LI];
end;

function PadNum(const AValor: string; ATamanho: Integer): string;
var
  LDigitos: string;
begin
  LDigitos := SomenteDigitos(AValor);
  if Length(LDigitos) > ATamanho then
    LDigitos := Copy(LDigitos, Length(LDigitos) - ATamanho + 1, ATamanho);
  while Length(LDigitos) < ATamanho do
    LDigitos := '0' + LDigitos;
  Result := LDigitos;
end;

function CodigoUF(const AUF: string): Integer;
begin
  if AUF = 'AC' then Result := 12
  else if AUF = 'AL' then Result := 27
  else if AUF = 'AP' then Result := 16
  else if AUF = 'AM' then Result := 13
  else if AUF = 'BA' then Result := 29
  else if AUF = 'CE' then Result := 23
  else if AUF = 'DF' then Result := 53
  else if AUF = 'ES' then Result := 32
  else if AUF = 'GO' then Result := 52
  else if AUF = 'MA' then Result := 21
  else if AUF = 'MT' then Result := 51
  else if AUF = 'MS' then Result := 50
  else if AUF = 'MG' then Result := 31
  else if AUF = 'PA' then Result := 15
  else if AUF = 'PB' then Result := 25
  else if AUF = 'PR' then Result := 41
  else if AUF = 'PE' then Result := 26
  else if AUF = 'PI' then Result := 22
  else if AUF = 'RJ' then Result := 33
  else if AUF = 'RN' then Result := 24
  else if AUF = 'RS' then Result := 43
  else if AUF = 'RO' then Result := 11
  else if AUF = 'RR' then Result := 14
  else if AUF = 'SC' then Result := 42
  else if AUF = 'SP' then Result := 35
  else if AUF = 'SE' then Result := 28
  else if AUF = 'TO' then Result := 17
  else Result := 35; // padrão: SP
end;

function TNotaSaidaService.DigitoChave(const ABase: string): Integer;
var
  LI, LPeso, LSoma, LDig: Integer;
begin
  LSoma := 0;
  LPeso := 2;
  for LI := Length(ABase) downto 1 do
  begin
    if (ABase[LI] >= '0') and (ABase[LI] <= '9') then
      LSoma := LSoma + (Ord(ABase[LI]) - Ord('0')) * LPeso;
    Inc(LPeso);
    if LPeso > 9 then
      LPeso := 2;
  end;
  LDig := 11 - (LSoma mod 11);
  if LDig >= 10 then
    LDig := 0;
  Result := LDig;
end;

function TNotaSaidaService.GerarChaveAcesso(ANotaId: Int64): string;
var
  LQuery: TSQLQuery;
  LBase, LCnpj, LUF: string;
  LData: TDate;
  LCNF: Int64;
begin
  Result := '';
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT NS.NUMERO, NS.SERIE, NS.MODELO, ' +
      '       COALESCE(NS.DATA_EMISSAO, CURRENT_DATE) AS DATA_EMISSAO, ' +
      '       E.CNPJ, E.UF ' +
      'FROM NOTA_SAIDA NS LEFT JOIN EMPRESA E ON E.ID = NS.EMPRESA_ID ' +
      'WHERE NS.ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise ENotaSaida.Create('Nota de saída não encontrada.');

    LData := LQuery.FieldByName('DATA_EMISSAO').AsDateTime;
    LCnpj := PadNum(LQuery.FieldByName('CNPJ').AsString, 14);
    LUF := Trim(LQuery.FieldByName('UF').AsString);

    // cNF: código numérico do emitente (aqui derivado da nota + hora, o
    // suficiente para gerar uma chave única no ambiente de homologação)
    LCNF := (ANotaId * 104729 + StrToIntDef(FormatDateTime('hhnnss', Now), 0)) mod 100000000;

    LBase := Format('%.2d', [CodigoUF(LUF)]) +
             FormatDateTime('yymm', LData) +
             LCnpj +
             PadNum(LQuery.FieldByName('MODELO').AsString, 2) +
             PadNum(LQuery.FieldByName('SERIE').AsString, 3) +
             PadNum(LQuery.FieldByName('NUMERO').AsString, 9) +
             '1' +
             PadNum(IntToStr(LCNF), 8);

    Result := LBase + IntToStr(DigitoChave(LBase));
  finally
    LQuery.Free;
  end;
end;

procedure TNotaSaidaService.GerarContasReceber(ANotaId: Int64);
var
  LCab, LTot: TSQLQuery;
  LParcelas, LDias, LIndice: Integer;
  LTotal, LValorParcela, LAcumulado: Double;
  LVencimento: TDate;
  LEmpresaId, LClienteId, LCondicaoId, LFinanceiroId: Int64;
  LNumero: string;
begin
  LCab := NovaConsulta;
  LTot := NovaConsulta;
  try
    LCab.SQL.Text :=
      'SELECT EMPRESA_ID, CLIENTE_ID, CONDICAO_PAGAMENTO_ID, NUMERO, ' +
      '       VALOR_TOTAL, COALESCE(DATA_SAIDA, CURRENT_DATE) AS DATA_BASE ' +
      'FROM NOTA_SAIDA WHERE ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaSaida.Create('Nota de saída não encontrada.');

    LEmpresaId  := LCab.FieldByName('EMPRESA_ID').AsLargeInt;
    LClienteId  := LCab.FieldByName('CLIENTE_ID').AsLargeInt;
    LCondicaoId := LCab.FieldByName('CONDICAO_PAGAMENTO_ID').AsLargeInt;
    LNumero     := Trim(LCab.FieldByName('NUMERO').AsString);
    LTotal      := LCab.FieldByName('VALOR_TOTAL').AsFloat;
    LVencimento := LCab.FieldByName('DATA_BASE').AsDateTime;

    // Só gera contas a receber se houver cliente e valor
    if (LClienteId = 0) or (LTotal <= 0) then
      Exit;

    LFinanceiroId := GarantirFinanceiro('R', 'Contas a receber de vendas');

    LParcelas := 1;
    LDias := 0;
    if LCondicaoId > 0 then
    begin
      LTot.SQL.Text :=
        'SELECT PARCELAS, DIAS_ENTRE_PARCELAS FROM CONDICAO_PAGAMENTO WHERE ID = :ID';
      LTot.ParamByName('ID').AsLargeInt := LCondicaoId;
      LTot.Open;
      if not LTot.IsEmpty then
      begin
        LParcelas := LTot.FieldByName('PARCELAS').AsInteger;
        LDias := LTot.FieldByName('DIAS_ENTRE_PARCELAS').AsInteger;
        if LParcelas < 1 then
          LParcelas := 1;
      end;
      LTot.Close;
    end;

    LValorParcela := ROUNDTo(LTotal / LParcelas, -2);
    if LValorParcela <= 0 then
      LValorParcela := LTotal;
    LAcumulado := 0;

    for LIndice := 1 to LParcelas do
    begin
      // A última parcela absorve a diferença de arredondamento
      if LIndice = LParcelas then
        LValorParcela := LTotal - LAcumulado;
      LAcumulado := LAcumulado + LValorParcela;

      LTot.SQL.Text :=
        'INSERT INTO CONTA_RECEBER ' +
        '  (EMPRESA_ID, FINANCEIRO_ID, CLIENTE_ID, NOTA_SAIDA_ID, DESCRICAO, VALOR, ' +
        '   DATA_VENCIMENTO, STATUS, PARCELA) ' +
        'VALUES (:EMP, :FIN, :CLI, :NOTA, :DESC, :VALOR, :VENC, ''A'', :PARC)';
      LTot.ParamByName('EMP').AsLargeInt := LEmpresaId;
      LTot.ParamByName('FIN').AsLargeInt := LFinanceiroId;
      LTot.ParamByName('CLI').AsLargeInt := LClienteId;
      LTot.ParamByName('NOTA').AsLargeInt := ANotaId;
      LTot.ParamByName('DESC').AsString :=
        'NF de saída ' + LNumero + ' (' + IntToStr(LIndice) + '/' + IntToStr(LParcelas) + ')';
      LTot.ParamByName('VALOR').AsFloat := LValorParcela;
      LTot.ParamByName('VENC').AsDate := IncDay(LVencimento, LIndice * LDias);
      LTot.ParamByName('PARC').AsInteger := LIndice;
      LTot.ExecSQL;
    end;
  finally
    LCab.Free;
    LTot.Free;
  end;
end;

procedure TNotaSaidaService.Faturar(ANotaId: Int64);
var
  LCab, LReg, LMov, LUpd: TSQLQuery;
  LItens: array of TItemSaida;
  LStatus, LModelo, LSerie, LNumero, LDocumento, LChave: string;
  LEmpresaId, LClienteId, LPedidoId, LUsuarioId: Int64;
  LIndice: Integer;
  LDataSaida: TDate;
  LQuantidade, LSaldo, LCusto: Double;
begin
  FConexao.IniciarTransacao;
  LCab := NovaConsulta;
  LReg := NovaConsulta;
  LMov := NovaConsulta;
  LUpd := NovaConsulta;
  try
    // --- Cabeçalho -------------------------------------------------------
    LCab.SQL.Text :=
      'SELECT STATUS, EMPRESA_ID, CLIENTE_ID, PEDIDO_VENDA_ID, NUMERO, SERIE, MODELO, ' +
      '       COALESCE(DATA_SAIDA, CURRENT_DATE) AS DATA_SAIDA ' +
      'FROM NOTA_SAIDA WHERE ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaSaida.Create('Nota de saída não encontrada.');

    LStatus := Trim(LCab.FieldByName('STATUS').AsString);
    if LStatus = 'P' then
      raise ENotaSaida.Create('Esta nota de saída já foi faturada.');
    if LStatus = 'C' then
      raise ENotaSaida.Create('Esta nota de saída está cancelada.');

    LEmpresaId  := LCab.FieldByName('EMPRESA_ID').AsLargeInt;
    LClienteId  := LCab.FieldByName('CLIENTE_ID').AsLargeInt;
    LPedidoId   := LCab.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;
    LNumero     := Trim(LCab.FieldByName('NUMERO').AsString);
    LSerie      := Trim(LCab.FieldByName('SERIE').AsString);
    LModelo     := Trim(LCab.FieldByName('MODELO').AsString);
    LDataSaida  := LCab.FieldByName('DATA_SAIDA').AsDateTime;
    LUsuarioId  := TSessao.GetInstance.UsuarioId;
    LDocumento  := 'NF SAIDA ' + LModelo + '/' + LSerie + '-' + LNumero;
    LCab.Close;

    if LClienteId = 0 then
      raise ENotaSaida.Create('Informe o cliente antes de faturar a nota de saída.');

    // --- Itens -----------------------------------------------------------
    LReg.SQL.Text :=
      'SELECT ID, PRODUTO_ID, DESCRICAO, QUANTIDADE, VALOR_UNITARIO, ATUALIZA_ESTOQUE ' +
      'FROM NOTA_SAIDA_ITEM WHERE NOTA_SAIDA_ID = :ID ORDER BY ID';
    LReg.ParamByName('ID').AsLargeInt := ANotaId;
    LReg.Open;
    SetLength(LItens, 0);
    while not LReg.EOF do
    begin
      SetLength(LItens, Length(LItens) + 1);
      LIndice := High(LItens);
      LItens[LIndice].Id              := LReg.FieldByName('ID').AsLargeInt;
      LItens[LIndice].ProdutoId       := LReg.FieldByName('PRODUTO_ID').AsLargeInt;
      LItens[LIndice].Descricao       := Trim(LReg.FieldByName('DESCRICAO').AsString);
      LItens[LIndice].Quantidade      := LReg.FieldByName('QUANTIDADE').AsFloat;
      LItens[LIndice].ValorUnitario   := LReg.FieldByName('VALOR_UNITARIO').AsFloat;
      LItens[LIndice].AtualizaEstoque :=
        UpperCase(Trim(LReg.FieldByName('ATUALIZA_ESTOQUE').AsString)) = 'S';
      LReg.Next;
    end;
    LReg.Close;

    if Length(LItens) = 0 then
      raise ENotaSaida.Create('A nota de saída não possui itens.');

    // Valida produtos e saldo antes de movimentar o estoque
    for LIndice := 0 to High(LItens) do
    begin
      if not LItens[LIndice].AtualizaEstoque then
        Continue;
      if LItens[LIndice].ProdutoId = 0 then
        raise ENotaSaida.Create('O item "' + LItens[LIndice].Descricao +
          '" não está ligado a um produto.');
      LerSaldo(LEmpresaId, LItens[LIndice].ProdutoId, LSaldo);
      if LSaldo < LItens[LIndice].Quantidade then
        raise ENotaSaida.Create('Estoque insuficiente para "' + LItens[LIndice].Descricao +
          '" (disponível: ' + FormatFloat('#,##0.####', LSaldo) +
          ', solicitado: ' + FormatFloat('#,##0.####', LItens[LIndice].Quantidade) + ').');
    end;

    // --- Baixa de estoque ------------------------------------------------
    for LIndice := 0 to High(LItens) do
    begin
      if not LItens[LIndice].AtualizaEstoque then
        Continue;
      LQuantidade := LItens[LIndice].Quantidade;
      LCusto := CustoUnitario(LEmpresaId, LItens[LIndice].ProdutoId);

      LMov.SQL.Text :=
        'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, QUANTIDADE, ' +
        '  CUSTO_UNITARIO, DOCUMENTO, DATA_MOVIMENTO, USUARIO_ID) ' +
        'VALUES (:EMP, :PROD, ''S'', :QTD, :CUSTO, :DOC, :DATA, :USR)';
      LMov.ParamByName('EMP').AsLargeInt := LEmpresaId;
      LMov.ParamByName('PROD').AsLargeInt := LItens[LIndice].ProdutoId;
      LMov.ParamByName('QTD').AsFloat := LQuantidade;
      LMov.ParamByName('CUSTO').AsFloat := LCusto;
      LMov.ParamByName('DOC').AsString := LDocumento;
      LMov.ParamByName('DATA').AsDate := LDataSaida;
      LMov.ParamByName('USR').AsLargeInt := LUsuarioId;
      LMov.ExecSQL;

      // Saldo do item para conferência (o trigger TRG_MOVEST_AI já baixou)
      LerSaldo(LEmpresaId, LItens[LIndice].ProdutoId, LSaldo);
      LUpd.SQL.Text :=
        'UPDATE NOTA_SAIDA_ITEM SET SALDO_APOS = :SALDO WHERE ID = :ID';
      LUpd.ParamByName('SALDO').AsFloat := LSaldo;
      LUpd.ParamByName('ID').AsLargeInt := LItens[LIndice].Id;
      LUpd.ExecSQL;
    end;

    // --- Financeiro ------------------------------------------------------
    GerarContasReceber(ANotaId);

    // --- Chave de acesso -------------------------------------------------
    LChave := GerarChaveAcesso(ANotaId);

    LUpd.SQL.Text :=
      'UPDATE NOTA_SAIDA SET STATUS = ''P'', CHAVE_ACESSO = :CHAVE, ' +
      '  PROTOCOLO = :PROT, DATA_PROCESSAMENTO = CURRENT_TIMESTAMP ' +
      'WHERE ID = :ID';
    LUpd.ParamByName('CHAVE').AsString := LChave;
    LUpd.ParamByName('PROT').AsString := 'HOM' + Copy(LChave, 30, 9);
    LUpd.ParamByName('ID').AsLargeInt := ANotaId;
    LUpd.ExecSQL;

    // --- Pedido faturado -------------------------------------------------
    if LPedidoId > 0 then
    begin
      LUpd.SQL.Text :=
        'UPDATE PEDIDO_VENDA SET STATUS = ''F'', NUMERO_NFE = :NUM, CHAVE_NFE = :CHAVE ' +
        'WHERE ID = :ID';
      LUpd.ParamByName('NUM').AsInteger := StrToIntDef(LNumero, 0);
      LUpd.ParamByName('CHAVE').AsString := LChave;
      LUpd.ParamByName('ID').AsLargeInt := LPedidoId;
      LUpd.ExecSQL;
    end;

    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LCab.Free;
    LReg.Free;
    LMov.Free;
    LUpd.Free;
    raise;
  end;

  LCab.Free;
  LReg.Free;
  LMov.Free;
  LUpd.Free;
end;

procedure TNotaSaidaService.Cancelar(ANotaId: Int64; const AMotivo: string);
var
  LCab, LReg, LMov, LUpd: TSQLQuery;
  LStatus, LNumero, LDocumento: string;
  LEmpresaId, LPedidoId, LUsuarioId: Int64;
  LQuantidade, LCusto: Double;
begin
  FConexao.IniciarTransacao;
  LCab := NovaConsulta;
  LReg := NovaConsulta;
  LMov := NovaConsulta;
  LUpd := NovaConsulta;
  try
    LCab.SQL.Text :=
      'SELECT STATUS, EMPRESA_ID, PEDIDO_VENDA_ID, NUMERO FROM NOTA_SAIDA WHERE ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaSaida.Create('Nota de saída não encontrada.');

    LStatus    := Trim(LCab.FieldByName('STATUS').AsString);
    if LStatus = 'C' then
      raise ENotaSaida.Create('Esta nota de saída já está cancelada.');

    LEmpresaId := LCab.FieldByName('EMPRESA_ID').AsLargeInt;
    LPedidoId  := LCab.FieldByName('PEDIDO_VENDA_ID').AsLargeInt;
    LNumero    := Trim(LCab.FieldByName('NUMERO').AsString);
    LUsuarioId := TSessao.GetInstance.UsuarioId;
    LDocumento := 'ESTORNO NF SAIDA ' + LNumero;
    LCab.Close;

    if LStatus = 'P' then
    begin
      // Estorno: devolve o estoque e cancela as parcelas em aberto
      LReg.SQL.Text :=
        'SELECT PRODUTO_ID, QUANTIDADE FROM NOTA_SAIDA_ITEM ' +
        'WHERE NOTA_SAIDA_ID = :ID AND ATUALIZA_ESTOQUE = ''S'' AND PRODUTO_ID > 0 ORDER BY ID';
      LReg.ParamByName('ID').AsLargeInt := ANotaId;
      LReg.Open;
      while not LReg.EOF do
      begin
        LQuantidade := LReg.FieldByName('QUANTIDADE').AsFloat;
        LCusto := CustoUnitario(LEmpresaId, LReg.FieldByName('PRODUTO_ID').AsLargeInt);

        LMov.SQL.Text :=
          'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, QUANTIDADE, ' +
          '  CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, DATA_MOVIMENTO, USUARIO_ID) ' +
          'VALUES (:EMP, :PROD, ''E'', :QTD, :CUSTO, :DOC, :OBS, CURRENT_DATE, :USR)';
        LMov.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LMov.ParamByName('PROD').AsLargeInt := LReg.FieldByName('PRODUTO_ID').AsLargeInt;
        LMov.ParamByName('QTD').AsFloat := LQuantidade;
        LMov.ParamByName('CUSTO').AsFloat := LCusto;
        LMov.ParamByName('DOC').AsString := LDocumento;
        LMov.ParamByName('OBS').AsString := 'Cancelamento: ' + AMotivo;
        LMov.ParamByName('USR').AsLargeInt := LUsuarioId;
        LMov.ExecSQL;
        LReg.Next;
      end;
      LReg.Close;

      LUpd.SQL.Text :=
        'UPDATE CONTA_RECEBER SET STATUS = ''C'' ' +
        'WHERE NOTA_SAIDA_ID = :ID AND STATUS = ''A''';
      LUpd.ParamByName('ID').AsLargeInt := ANotaId;
      LUpd.ExecSQL;

      if LPedidoId > 0 then
      begin
        LUpd.SQL.Text :=
          'UPDATE PEDIDO_VENDA SET STATUS = ''P'', NUMERO_NFE = NULL, CHAVE_NFE = NULL ' +
          'WHERE ID = :ID AND STATUS = ''F''';
        LUpd.ParamByName('ID').AsLargeInt := LPedidoId;
        LUpd.ExecSQL;
      end;
    end;

    LUpd.SQL.Text :=
      'UPDATE NOTA_SAIDA SET STATUS = ''C'', MOTIVO_CANCELAMENTO = :MOTIVO, ' +
      '  DATA_CANCELAMENTO = CURRENT_TIMESTAMP WHERE ID = :ID';
    LUpd.ParamByName('MOTIVO').AsString := AMotivo;
    LUpd.ParamByName('ID').AsLargeInt := ANotaId;
    LUpd.ExecSQL;

    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LCab.Free;
    LReg.Free;
    LMov.Free;
    LUpd.Free;
    raise;
  end;

  LCab.Free;
  LReg.Free;
  LMov.Free;
  LUpd.Free;
end;

procedure TNotaSaidaService.ExcluirItem(AItemId: Int64);
var
  LQuery: TSQLQuery;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'DELETE FROM NOTA_SAIDA_ITEM WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AItemId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LQuery.Free;
    raise;
  end;
  LQuery.Free;
end;

// ---------------------------------------------------------------------------
// XML da NF-e (modelo 55).
//
// Este XML é o "gancho" para a emissão real: com o ACBr configurado e o
// certificado digital, o mesmo conteúdo é assinado e transmitido à SEFAZ
// (TACBrHelper.GerarNFe). Sem certificado, o arquivo gerado serve para
// conferência dos dados fiscais do faturamento.
// ---------------------------------------------------------------------------
function TNotaSaidaService.GerarXML(ANotaId: Int64): string;
var
  LCab, LItens: TSQLQuery;
  LXml: TStringList;
  LFmt: TFormatSettings;
  LI: Integer;
  LChave, LIndice: string;
begin
  LFmt := DefaultFormatSettings;
  LFmt.DecimalSeparator := '.';
  LFmt.ThousandSeparator := #0;

  Result := '';
  LXml := TStringList.Create;
  LCab := NovaConsulta;
  LItens := NovaConsulta;
  try
    LCab.SQL.Text :=
      'SELECT NS.*, C.NOME AS CLI_NOME, C.CPF_CNPJ AS CLI_DOC, C.ENDERECO AS CLI_ENDERECO, ' +
      '       C.NUMERO AS CLI_NUMERO, C.BAIRRO AS CLI_BAIRRO, C.CIDADE AS CLI_CIDADE, ' +
      '       C.UF AS CLI_UF, C.CEP AS CLI_CEP, ' +
      '       E.RAZAO_SOCIAL, E.CNPJ AS EMP_CNPJ, E.IE AS EMP_IE, E.ENDERECO AS EMP_ENDERECO, ' +
      '       E.NUMERO AS EMP_NUMERO, E.BAIRRO AS EMP_BAIRRO, E.CIDADE AS EMP_CIDADE, ' +
      '       E.UF AS EMP_UF, E.CEP AS EMP_CEP ' +
      'FROM NOTA_SAIDA NS ' +
      'LEFT JOIN CLIENTE C ON C.ID = NS.CLIENTE_ID ' +
      'LEFT JOIN EMPRESA E ON E.ID = NS.EMPRESA_ID ' +
      'WHERE NS.ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaSaida.Create('Nota de saída não encontrada.');

    LChave := Trim(LCab.FieldByName('CHAVE_ACESSO').AsString);

    LXml.Add('<?xml version="1.0" encoding="UTF-8"?>');
    LXml.Add('<nfeProc versao="4.00" xmlns="http://www.portalfiscal.inf.br/nfe">');
    LXml.Add('  <NFe>');
    LXml.Add('    <infNFe versao="4.00" Id="NFe' + LChave + '">');
    LXml.Add('      <ide>');
    LXml.Add('        <cUF>' + IntToStr(CodigoUF(Trim(LCab.FieldByName('EMP_UF').AsString))) + '</cUF>');
    LXml.Add('        <natOp>' + Trim(LCab.FieldByName('NATUREZA_OPERACAO').AsString) + '</natOp>');
    LXml.Add('        <mod>' + Trim(LCab.FieldByName('MODELO').AsString) + '</mod>');
    LXml.Add('        <serie>' + Trim(LCab.FieldByName('SERIE').AsString) + '</serie>');
    LXml.Add('        <nNF>' + Trim(LCab.FieldByName('NUMERO').AsString) + '</nNF>');
    LXml.Add('        <dhEmi>' + FormatDateTime('yyyy-mm-dd', LCab.FieldByName('DATA_EMISSAO').AsDateTime) + 'T00:00:00-03:00</dhEmi>');
    LXml.Add('        <tpNF>1</tpNF>');
    LXml.Add('        <idDest>1</idDest>');
    LXml.Add('      </ide>');
    LXml.Add('      <emit>');
    LXml.Add('        <CNPJ>' + SomenteDigitos(LCab.FieldByName('EMP_CNPJ').AsString) + '</CNPJ>');
    LXml.Add('        <xNome>' + Trim(LCab.FieldByName('RAZAO_SOCIAL').AsString) + '</xNome>');
    LXml.Add('        <enderEmit>');
    LXml.Add('          <xLgr>' + Trim(LCab.FieldByName('EMP_ENDERECO').AsString) + '</xLgr>');
    LXml.Add('          <nro>' + Trim(LCab.FieldByName('EMP_NUMERO').AsString) + '</nro>');
    LXml.Add('          <xBairro>' + Trim(LCab.FieldByName('EMP_BAIRRO').AsString) + '</xBairro>');
    LXml.Add('          <xMun>' + Trim(LCab.FieldByName('EMP_CIDADE').AsString) + '</xMun>');
    LXml.Add('          <UF>' + Trim(LCab.FieldByName('EMP_UF').AsString) + '</UF>');
    LXml.Add('          <CEP>' + SomenteDigitos(LCab.FieldByName('EMP_CEP').AsString) + '</CEP>');
    LXml.Add('        </enderEmit>');
    LXml.Add('        <IE>' + Trim(LCab.FieldByName('EMP_IE').AsString) + '</IE>');
    LXml.Add('        <CRT>1</CRT>');
    LXml.Add('      </emit>');
    LXml.Add('      <dest>');
    LXml.Add('        <CPF>' + SomenteDigitos(LCab.FieldByName('CLI_DOC').AsString) + '</CPF>');
    LXml.Add('        <xNome>' + Trim(LCab.FieldByName('CLI_NOME').AsString) + '</xNome>');
    LXml.Add('        <enderDest>');
    LXml.Add('          <xLgr>' + Trim(LCab.FieldByName('CLI_ENDERECO').AsString) + '</xLgr>');
    LXml.Add('          <nro>' + Trim(LCab.FieldByName('CLI_NUMERO').AsString) + '</nro>');
    LXml.Add('          <xBairro>' + Trim(LCab.FieldByName('CLI_BAIRRO').AsString) + '</xBairro>');
    LXml.Add('          <xMun>' + Trim(LCab.FieldByName('CLI_CIDADE').AsString) + '</xMun>');
    LXml.Add('          <UF>' + Trim(LCab.FieldByName('CLI_UF').AsString) + '</UF>');
    LXml.Add('          <CEP>' + SomenteDigitos(LCab.FieldByName('CLI_CEP').AsString) + '</CEP>');
    LXml.Add('        </enderDest>');
    LXml.Add('        <indIEDest>9</indIEDest>');
    LXml.Add('      </dest>');

    LItens.SQL.Text :=
      'SELECT CODIGO, DESCRICAO, NCM, CFOP, CST_ICMS, UNIDADE, QUANTIDADE, ' +
      '       VALOR_UNITARIO, VALOR_TOTAL, DESCONTO, ALIQ_ICMS, VALOR_ICMS ' +
      'FROM NOTA_SAIDA_ITEM WHERE NOTA_SAIDA_ID = :ID ORDER BY ID';
    LItens.ParamByName('ID').AsLargeInt := ANotaId;
    LItens.Open;
    LI := 0;
    while not LItens.EOF do
    begin
      Inc(LI);
      LIndice := IntToStr(LI);
      LXml.Add('      <det nItem="' + LIndice + '">');
      LXml.Add('        <prod>');
      LXml.Add('          <cProd>' + Trim(LItens.FieldByName('CODIGO').AsString) + '</cProd>');
      LXml.Add('          <xProd>' + Trim(LItens.FieldByName('DESCRICAO').AsString) + '</xProd>');
      LXml.Add('          <NCM>' + Trim(LItens.FieldByName('NCM').AsString) + '</NCM>');
      LXml.Add('          <CFOP>' + Trim(LItens.FieldByName('CFOP').AsString) + '</CFOP>');
      LXml.Add('          <uCom>' + Trim(LItens.FieldByName('UNIDADE').AsString) + '</uCom>');
      LXml.Add('          <qCom>' + FormatFloat('0.0000', LItens.FieldByName('QUANTIDADE').AsFloat, LFmt) + '</qCom>');
      LXml.Add('          <vUnCom>' + FormatFloat('0.0000000000', LItens.FieldByName('VALOR_UNITARIO').AsFloat, LFmt) + '</vUnCom>');
      LXml.Add('          <vProd>' + FormatFloat('0.00', LItens.FieldByName('VALOR_TOTAL').AsFloat, LFmt) + '</vProd>');
      LXml.Add('          <vDesc>' + FormatFloat('0.00', LItens.FieldByName('DESCONTO').AsFloat, LFmt) + '</vDesc>');
      LXml.Add('        </prod>');
      LXml.Add('        <imposto>');
      LXml.Add('          <ICMS>');
      LXml.Add('            <ICMS00>');
      LXml.Add('              <orig>0</orig>');
      LXml.Add('              <CST>' + Trim(LItens.FieldByName('CST_ICMS').AsString) + '</CST>');
      LXml.Add('              <modBC>3</modBC>');
      LXml.Add('              <vBC>' + FormatFloat('0.00', LItens.FieldByName('VALOR_TOTAL').AsFloat, LFmt) + '</vBC>');
      LXml.Add('              <pICMS>' + FormatFloat('0.00', LItens.FieldByName('ALIQ_ICMS').AsFloat, LFmt) + '</pICMS>');
      LXml.Add('              <vICMS>' + FormatFloat('0.00', LItens.FieldByName('VALOR_ICMS').AsFloat, LFmt) + '</vICMS>');
      LXml.Add('            </ICMS00>');
      LXml.Add('          </ICMS>');
      LXml.Add('        </imposto>');
      LXml.Add('      </det>');
      LItens.Next;
    end;
    LItens.Close;

    LXml.Add('      <total>');
    LXml.Add('        <ICMSTot>');
    LXml.Add('          <vBC>' + FormatFloat('0.00', LCab.FieldByName('VALOR_PRODUTOS').AsFloat, LFmt) + '</vBC>');
    LXml.Add('          <vICMS>' + FormatFloat('0.00', LCab.FieldByName('VALOR_ICMS').AsFloat, LFmt) + '</vICMS>');
    LXml.Add('          <vProd>' + FormatFloat('0.00', LCab.FieldByName('VALOR_PRODUTOS').AsFloat, LFmt) + '</vProd>');
    LXml.Add('          <vFrete>' + FormatFloat('0.00', LCab.FieldByName('VALOR_FRETE').AsFloat, LFmt) + '</vFrete>');
    LXml.Add('          <vSeg>' + FormatFloat('0.00', LCab.FieldByName('VALOR_SEGURO').AsFloat, LFmt) + '</vSeg>');
    LXml.Add('          <vDesc>' + FormatFloat('0.00', LCab.FieldByName('VALOR_DESCONTO').AsFloat, LFmt) + '</vDesc>');
    LXml.Add('          <vOutro>' + FormatFloat('0.00', LCab.FieldByName('VALOR_OUTRAS').AsFloat, LFmt) + '</vOutro>');
    LXml.Add('          <vNF>' + FormatFloat('0.00', LCab.FieldByName('VALOR_TOTAL').AsFloat, LFmt) + '</vNF>');
    LXml.Add('        </ICMSTot>');
    LXml.Add('      </total>');
    LXml.Add('      <transp>');
    LXml.Add('        <modFrete>' + Trim(LCab.FieldByName('MODALIDADE_FRETE').AsString) + '</modFrete>');
    LXml.Add('      </transp>');
    LXml.Add('      <pag>');
    LXml.Add('        <detPag>');
    LXml.Add('          <tPag>01</tPag>');
    LXml.Add('          <vPag>' + FormatFloat('0.00', LCab.FieldByName('VALOR_TOTAL').AsFloat, LFmt) + '</vPag>');
    LXml.Add('        </detPag>');
    LXml.Add('      </pag>');
    LXml.Add('    </infNFe>');
    LXml.Add('  </NFe>');
    LXml.Add('  <protNFe versao="4.00">');
    LXml.Add('    <infProt>');
    LXml.Add('      <chNFe>' + LChave + '</chNFe>');
    LXml.Add('      <nProt>' + Trim(LCab.FieldByName('PROTOCOLO').AsString) + '</nProt>');
    LXml.Add('      <cStat>100</cStat>');
    LXml.Add('      <xMotivo>Autorizado o uso da NF-e</xMotivo>');
    LXml.Add('    </infProt>');
    LXml.Add('  </protNFe>');
    LXml.Add('</nfeProc>');

    Result := LXml.Text;
  finally
    LCab.Free;
    LItens.Free;
    LXml.Free;
  end;
end;

end.
