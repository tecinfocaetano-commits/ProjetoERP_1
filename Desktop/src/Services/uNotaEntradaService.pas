unit uNotaEntradaService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Módulo 1 - Nota de Entrada (compra de mercadoria)
  ------------------------------------------------------------
  Concentra as regras de negócio da nota de entrada:

    - PrimeiroItemSemProduto / QuantidadeItens: validações;
    - RecalcularTotais: totais do cabeçalho a partir dos itens;
    - Processar: dá entrada no estoque (MOVIMENTO_ESTOQUE), atualiza
      o custo médio e gera as parcelas em CONTA_PAGAR;
    - Cancelar: apenas enquanto a nota está Aberta;
    - ExcluirItem.

  O saldo de ESTOQUE é mantido pelo trigger TRG_MOVEST_AI a partir
  de MOVIMENTO_ESTOQUE; aqui apenas gravamos os movimentos.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, DB, uConexao;

type
  ENotaEntrada = class(Exception);

  { Dados do cabeçalho da nota de entrada digitada na tela.
    CondicaoPagamentoId = 0 grava NULL. }
  TNotaEntradaCabecalho = record
    FornecedorId: Int64;
    Numero: string;
    Serie: string;
    Modelo: string;
    ChaveAcesso: string;
    DataEmissao: TDate;
    DataEntrada: TDate;
    NaturezaOperacao: string;
    Cfop: string;
    ValorFrete: Double;
    ValorSeguro: Double;
    ValorOutras: Double;
    ValorDesconto: Double;
    CondicaoPagamentoId: Int64;
  end;

  TNotaEntradaService = class
  private
    FConexao: TConexao;
    function  NovaConsulta: TSQLQuery;
    function  LerSaldo(AEmpresaId, AProdutoId: Int64;
      out AQuantidade, ACustoMedio: Double): Boolean;
    function  LerSaldoMaterial(AEmpresaId, AMaterialId: Int64;
      out AQuantidade: Double): Boolean;
    function  GarantirFinanceiro(const ATipo, ADescricao: string): Int64;
    procedure GerarContasPagar(ANotaId: Int64);
  public
    constructor Create;

    function  QuantidadeItens(ANotaId: Int64): Integer;
    function  PrimeiroItemSemProduto(ANotaId: Int64): string;
    // Classificação fiscal do produto: usa o PRODUTO_FISCAL vinculado e cai
    // para os campos do próprio cadastro quando não houver vínculo.
    procedure CarregarFiscalDoProduto(AProdutoId: Int64;
      out AProdutoFiscalId: Int64; out ANcm, ACfop, ACstIcms: string;
      out AAliqIcms: Double);
    procedure RecalcularTotais(ANotaId: Int64);
    { Grava o cabeçalho digitado na tela (insert quando ANotaId = 0,
      update caso contrário), recalcula os totais e audita.
      Devolve o ID da nota. }
    function  SalvarCabecalho(ANotaId: Int64;
      const ADados: TNotaEntradaCabecalho): Int64;
    { Grava um item da nota (insert quando AItemId = 0, update caso
      contrário), herdando a classificação fiscal do PRODUTO_FISCAL
      (CarregarFiscalDoProduto), recalcula os totais e audita.
      Devolve o ID do item. }
    function  SalvarItem(ANotaId, AItemId, AProdutoId: Int64;
      const ADescricao: string; AQuantidade, AValorUnitario,
      ADesconto: Double): Int64;
    procedure Processar(ANotaId: Int64);
    procedure Cancelar(ANotaId: Int64);
    procedure ExcluirItem(AItemId: Int64);

    // Gera a nota de entrada (status Aberta) a partir de um pedido de
    // compra confirmado: cabeçalho, itens de material com a classificação
    // fiscal do PRODUTO_FISCAL vinculado e vínculo no pedido.
    function  CriarDoPedidoCompra(APedidoCompraId: Int64): Int64;
  end;

implementation

uses
  Math, DateUtils, StrUtils, uSessao, uAuditoria;

type
  TItemNota = record
    Id: Int64;
    ProdutoId: Int64;
    MaterialId: Int64;
    Descricao: string;
    Quantidade: Double;
    ValorUnitario: Double;
    AtualizaEstoque: Boolean;
    AtualizaCusto: Boolean;
  end;

constructor TNotaEntradaService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TNotaEntradaService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConexao.Connection;
  Result.Transaction := FConexao.Transaction;
end;

// Localiza (ou cria) o registro do plano financeiro usado pelas contas a
// pagar/receber da empresa. Necessário porque CONTA_PAGAR.FINANCEIRO_ID usa o
// domínio DM_ID, que é NOT NULL.
function TNotaEntradaService.GarantirFinanceiro(const ATipo,
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

function TNotaEntradaService.QuantidadeItens(ANotaId: Int64): Integer;
var
  LQuery: TSQLQuery;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS TOTAL FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    Result := LQuery.FieldByName('TOTAL').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.PrimeiroItemSemProduto(ANotaId: Int64): string;
var
  LQuery: TSQLQuery;
begin
  Result := '';
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT FIRST 1 DESCRICAO FROM NOTA_ENTRADA_ITEM ' +
      'WHERE NOTA_ENTRADA_ID = :ID ' +
      '  AND (PRODUTO_ID IS NULL OR PRODUTO_ID = 0) ' +
      '  AND (MATERIAL_ID IS NULL OR MATERIAL_ID = 0) ' +
      '  AND ATUALIZA_ESTOQUE = ''S'' ORDER BY ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('DESCRICAO').AsString);
  finally
    LQuery.Free;
  end;
end;

procedure TNotaEntradaService.CarregarFiscalDoProduto(AProdutoId: Int64;
  out AProdutoFiscalId: Int64; out ANcm, ACfop, ACstIcms: string;
  out AAliqIcms: Double);
var
  LQuery: TSQLQuery;
begin
  AProdutoFiscalId := 0;
  ANcm := '';
  ACfop := '';
  ACstIcms := '';
  AAliqIcms := 0;
  if AProdutoId <= 0 then
    Exit;

  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT P.PRODUTO_FISCAL_ID, ' +
      '       COALESCE(F.NCM, P.NCM, '''') AS NCM, ' +
      '       COALESCE(F.CFOP_COMPRA, F.CFOP, P.CFOP_COMPRA, P.CFOP, '''') AS CFOP, ' +
      '       COALESCE(F.CST_ICMS, P.CST_ICMS, '''') AS CST, ' +
      '       COALESCE(F.ALIQ_ICMS, P.ALIQ_ICMS, 0) AS ALIQ ' +
      'FROM PRODUTO P LEFT JOIN PRODUTO_FISCAL F ON F.ID = P.PRODUTO_FISCAL_ID ' +
      'WHERE P.ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;

    AProdutoFiscalId := LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt;
    ANcm := Trim(LQuery.FieldByName('NCM').AsString);
    ACfop := Trim(LQuery.FieldByName('CFOP').AsString);
    ACstIcms := Trim(LQuery.FieldByName('CST').AsString);
    AAliqIcms := LQuery.FieldByName('ALIQ').AsFloat;
  finally
    LQuery.Free;
  end;
end;

procedure TNotaEntradaService.RecalcularTotais(ANotaId: Int64);
var
  LQuery: TSQLQuery;
  LProdutos, LDesconto: Double;
begin
  LQuery := NovaConsulta;
  try
    // ATENÇÃO: o SQLDB (Firebird) não lê corretamente expressões monetárias
    // cujo resultado tem escala maior que 4 (ex.: NUMERIC(18,4) * NUMERIC(18,4)
    // gera NUMERIC(18,8) -> TFMTBCDField -> volta como NULL). Por isso o CAST.
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(QUANTIDADE * VALOR_UNITARIO), 0) AS NUMERIC(18,4)) AS PRODUTOS, ' +
      '       CAST(COALESCE(SUM(DESCONTO), 0) AS NUMERIC(18,4)) AS DESCONTO ' +
      'FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    LProdutos := LQuery.FieldByName('PRODUTOS').AsFloat;
    LDesconto := LQuery.FieldByName('DESCONTO').AsFloat;
    LQuery.Close;

    // Total = produtos + frete + seguro + outras despesas - desconto
    LQuery.SQL.Text :=
      'UPDATE NOTA_ENTRADA SET VALOR_PRODUTOS = :PROD, ' +
      '  VALOR_TOTAL = :PROD + ' +
      '    COALESCE(VALOR_FRETE, 0) + COALESCE(VALOR_SEGURO, 0) + ' +
      '    COALESCE(VALOR_OUTRAS, 0) - COALESCE(VALOR_DESCONTO, 0) ' +
      'WHERE ID = :ID';
    LQuery.ParamByName('PROD').AsFloat := LProdutos;
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.SalvarCabecalho(ANotaId: Int64;
  const ADados: TNotaEntradaCabecalho): Int64;
var
  LQuery: TSQLQuery;
  LAntes: string;
begin
  if ADados.FornecedorId <= 0 then
    raise ENotaEntrada.Create('Informe o fornecedor.');
  if Trim(ADados.Numero) = '' then
    raise ENotaEntrada.Create('Informe o número do documento.');

  Result := ANotaId;
  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    try
      if ANotaId = 0 then
      begin
        LQuery.SQL.Text :=
          'INSERT INTO NOTA_ENTRADA (EMPRESA_ID, FORNECEDOR_ID, NUMERO, ' +
          '  SERIE, MODELO, CHAVE_ACESSO, DATA_EMISSAO, DATA_ENTRADA, ' +
          '  NATUREZA_OPERACAO, CFOP, VALOR_FRETE, VALOR_SEGURO, ' +
          '  VALOR_OUTRAS, VALOR_DESCONTO, VALOR_PRODUTOS, VALOR_TOTAL, ' +
          '  STATUS, CONDICAO_PAGAMENTO_ID, USUARIO_ID, DATA_CADASTRO) ' +
          'VALUES (:EMP, :FORN, :NUM, :SERIE, :MODELO, :CHAVE, :DEMI, ' +
          '  :DENT, :NAT, :CFOP, :FRETE, :SEGURO, :OUTRAS, :DESCONTO, ' +
          '  0, 0, ''A'', :COND, :USU, CURRENT_TIMESTAMP) RETURNING ID';
        LQuery.ParamByName('EMP').AsLargeInt :=
          TSessao.GetInstance.EmpresaId;
        LQuery.ParamByName('FORN').AsLargeInt := ADados.FornecedorId;
        LQuery.ParamByName('NUM').AsString := Trim(ADados.Numero);
        LQuery.ParamByName('SERIE').AsString := Trim(ADados.Serie);
        LQuery.ParamByName('MODELO').AsString := Trim(ADados.Modelo);
        LQuery.ParamByName('CHAVE').AsString := Trim(ADados.ChaveAcesso);
        LQuery.ParamByName('DEMI').AsDate := ADados.DataEmissao;
        LQuery.ParamByName('DENT').AsDate := ADados.DataEntrada;
        LQuery.ParamByName('NAT').AsString := Trim(ADados.NaturezaOperacao);
        LQuery.ParamByName('CFOP').AsString := Trim(ADados.Cfop);
        LQuery.ParamByName('FRETE').AsFloat := ADados.ValorFrete;
        LQuery.ParamByName('SEGURO').AsFloat := ADados.ValorSeguro;
        LQuery.ParamByName('OUTRAS').AsFloat := ADados.ValorOutras;
        LQuery.ParamByName('DESCONTO').AsFloat := ADados.ValorDesconto;
        if ADados.CondicaoPagamentoId > 0 then
          LQuery.ParamByName('COND').AsLargeInt := ADados.CondicaoPagamentoId
        else
          LQuery.ParamByName('COND').Clear;
        LQuery.ParamByName('USU').AsLargeInt := TSessao.GetInstance.UsuarioId;
        LQuery.Open;
        Result := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;

        RegistrarAuditoria('NOTA_ENTRADA', 'I', Result, '',
          'NUMERO=' + Trim(ADados.Numero) +
          '; FORNECEDOR=' + IntToStr(ADados.FornecedorId));
      end
      else
      begin
        LAntes := 'FORNECEDOR=' + IntToStr(ADados.FornecedorId) +
          '; NUMERO=' + Trim(ADados.Numero);
        LQuery.SQL.Text :=
          'UPDATE NOTA_ENTRADA SET FORNECEDOR_ID = :FORN, NUMERO = :NUM, ' +
          '  SERIE = :SERIE, MODELO = :MODELO, CHAVE_ACESSO = :CHAVE, ' +
          '  DATA_EMISSAO = :DEMI, DATA_ENTRADA = :DENT, ' +
          '  NATUREZA_OPERACAO = :NAT, CFOP = :CFOP, VALOR_FRETE = :FRETE, ' +
          '  VALOR_SEGURO = :SEGURO, VALOR_OUTRAS = :OUTRAS, ' +
          '  VALOR_DESCONTO = :DESCONTO, CONDICAO_PAGAMENTO_ID = :COND, ' +
          '  EMPRESA_ID = :EMP ' +
          'WHERE ID = :ID AND STATUS <> ''P''';
        LQuery.ParamByName('FORN').AsLargeInt := ADados.FornecedorId;
        LQuery.ParamByName('NUM').AsString := Trim(ADados.Numero);
        LQuery.ParamByName('SERIE').AsString := Trim(ADados.Serie);
        LQuery.ParamByName('MODELO').AsString := Trim(ADados.Modelo);
        LQuery.ParamByName('CHAVE').AsString := Trim(ADados.ChaveAcesso);
        LQuery.ParamByName('DEMI').AsDate := ADados.DataEmissao;
        LQuery.ParamByName('DENT').AsDate := ADados.DataEntrada;
        LQuery.ParamByName('NAT').AsString := Trim(ADados.NaturezaOperacao);
        LQuery.ParamByName('CFOP').AsString := Trim(ADados.Cfop);
        LQuery.ParamByName('FRETE').AsFloat := ADados.ValorFrete;
        LQuery.ParamByName('SEGURO').AsFloat := ADados.ValorSeguro;
        LQuery.ParamByName('OUTRAS').AsFloat := ADados.ValorOutras;
        LQuery.ParamByName('DESCONTO').AsFloat := ADados.ValorDesconto;
        if ADados.CondicaoPagamentoId > 0 then
          LQuery.ParamByName('COND').AsLargeInt := ADados.CondicaoPagamentoId
        else
          LQuery.ParamByName('COND').Clear;
        LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQuery.ParamByName('ID').AsLargeInt := ANotaId;
        LQuery.ExecSQL;
        if LQuery.RowsAffected = 0 then
          raise ENotaEntrada.Create(
            'Não foi possível alterar a nota (processada ou de outra empresa).');

        RegistrarAuditoria('NOTA_ENTRADA', 'U', ANotaId, LAntes,
          'NUMERO=' + Trim(ADados.Numero));
      end;

      RecalcularTotais(Result);
      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.SalvarItem(ANotaId, AItemId, AProdutoId: Int64;
  const ADescricao: string; AQuantidade, AValorUnitario,
  ADesconto: Double): Int64;
var
  LQuery: TSQLQuery;
  LProdutoFiscalId: Int64;
  LNcm, LCfop, LCst: string;
  LAliq, LValorIcms, LValorTotal: Double;
begin
  if ANotaId <= 0 then
    raise ENotaEntrada.Create('Salve o cabeçalho da nota antes dos itens.');
  if AQuantidade <= 0 then
    raise ENotaEntrada.Create('Informe uma quantidade maior que zero.');

  LQuery := NovaConsulta;
  try
    try
      { classificação fiscal herdada do PRODUTO_FISCAL (com fallback
        para os campos do próprio produto) }
      LProdutoFiscalId := 0;
      LNcm := '';
      LCfop := '';
      LCst := '';
      LAliq := 0;
      if AProdutoId > 0 then
        CarregarFiscalDoProduto(AProdutoId, LProdutoFiscalId,
          LNcm, LCfop, LCst, LAliq);

      LValorIcms := AQuantidade * AValorUnitario * LAliq / 100;
      LValorTotal := AQuantidade * AValorUnitario;

      FConexao.IniciarTransacao;
      try
        if AItemId = 0 then
        begin
          LQuery.SQL.Text :=
            'INSERT INTO NOTA_ENTRADA_ITEM (NOTA_ENTRADA_ID, PRODUTO_ID, ' +
            '  PRODUTO_FISCAL_ID, DESCRICAO, NCM, CFOP, CST_ICMS, ' +
            '  ALIQ_ICMS, VALOR_ICMS, QUANTIDADE, VALOR_UNITARIO, ' +
            '  VALOR_TOTAL, DESCONTO, ATUALIZA_ESTOQUE, ATUALIZA_CUSTO) ' +
            'VALUES (:NOTA, :PROD, :PFISCAL, :DESC, :NCM, :CFOP, :CST, ' +
            '  :ALIQ, :VICMS, :QTD, :VUN, :VTOT, :DSC, ''S'', ''S'') ' +
            'RETURNING ID';
        end
        else
        begin
          LQuery.SQL.Text :=
            'UPDATE NOTA_ENTRADA_ITEM SET PRODUTO_ID = :PROD, ' +
            '  PRODUTO_FISCAL_ID = :PFISCAL, DESCRICAO = :DESC, ' +
            '  NCM = :NCM, CFOP = :CFOP, CST_ICMS = :CST, ALIQ_ICMS = :ALIQ, ' +
            '  VALOR_ICMS = :VICMS, QUANTIDADE = :QTD, ' +
            '  VALOR_UNITARIO = :VUN, VALOR_TOTAL = :VTOT, ' +
            '  DESCONTO = :DSC ' +
            'WHERE ID = :ID AND NOTA_ENTRADA_ID = :NOTA';
          LQuery.ParamByName('ID').AsLargeInt := AItemId;
        end;

        LQuery.ParamByName('NOTA').AsLargeInt := ANotaId;
        if AProdutoId > 0 then
          LQuery.ParamByName('PROD').AsLargeInt := AProdutoId
        else
          LQuery.ParamByName('PROD').Clear;
        if LProdutoFiscalId > 0 then
          LQuery.ParamByName('PFISCAL').AsLargeInt := LProdutoFiscalId
        else
          LQuery.ParamByName('PFISCAL').Clear;
        LQuery.ParamByName('DESC').AsString := ADescricao;
        LQuery.ParamByName('NCM').AsString := LNcm;
        LQuery.ParamByName('CFOP').AsString := LCfop;
        LQuery.ParamByName('CST').AsString := LCst;
        LQuery.ParamByName('ALIQ').AsFloat := LAliq;
        LQuery.ParamByName('VICMS').AsFloat := LValorIcms;
        LQuery.ParamByName('QTD').AsFloat := AQuantidade;
        LQuery.ParamByName('VUN').AsFloat := AValorUnitario;
        LQuery.ParamByName('VTOT').AsFloat := LValorTotal;
        LQuery.ParamByName('DSC').AsFloat := ADesconto;

        if AItemId = 0 then
        begin
          LQuery.Open;
          Result := LQuery.FieldByName('ID').AsLargeInt;
          LQuery.Close;
        end
        else
        begin
          LQuery.ExecSQL;
          if LQuery.RowsAffected = 0 then
            raise ENotaEntrada.Create('Item não encontrado nesta nota.');
          Result := AItemId;
        end;

        RegistrarAuditoria('NOTA_ENTRADA_ITEM',
          IfThen(AItemId = 0, 'I', 'U'), Result, '',
          'NOTA=' + IntToStr(ANotaId) + '; PRODUTO=' +
          IntToStr(AProdutoId) + '; QTD=' +
          FormatFloat('#,##0.####', AQuantidade));

        RecalcularTotais(ANotaId);
        FConexao.Confirmar;
      except
        FConexao.Cancelar;
        raise;
      end;
    finally
      LQuery.Close;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.LerSaldo(AEmpresaId, AProdutoId: Int64;
  out AQuantidade, ACustoMedio: Double): Boolean;
var
  LQuery: TSQLQuery;
begin
  AQuantidade := 0;
  ACustoMedio := 0;
  Result := False;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT QUANTIDADE, CUSTO_MEDIO FROM ESTOQUE ' +
      'WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      AQuantidade := LQuery.FieldByName('QUANTIDADE').AsFloat;
      ACustoMedio := LQuery.FieldByName('CUSTO_MEDIO').AsFloat;
      Result := True;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNotaEntradaService.LerSaldoMaterial(AEmpresaId,
  AMaterialId: Int64; out AQuantidade: Double): Boolean;
var
  LQuery: TSQLQuery;
begin
  AQuantidade := 0;
  Result := False;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT QUANTIDADE FROM ESTOQUE_MATERIAL ' +
      'WHERE EMPRESA_ID = :EMP AND MATERIAL_ID = :MAT';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('MAT').AsLargeInt := AMaterialId;
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

procedure TNotaEntradaService.ExcluirItem(AItemId: Int64);
var
  LQuery: TSQLQuery;
begin
  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'DELETE FROM NOTA_ENTRADA_ITEM WHERE ID = :ID';
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

procedure TNotaEntradaService.GerarContasPagar(ANotaId: Int64);
var
  LCab: TSQLQuery;
  LTot: TSQLQuery;
  LParcelas, LDias, LIndice: Integer;
  LTotal, LValorParcela, LAcumulado: Double;
  LVencimento: TDate;
  LEmpresaId, LFornecedorId, LCondicaoId: Int64;
  LFinanceiroId: Int64;
  LNumero: string;
begin
  LCab := NovaConsulta;
  LTot := NovaConsulta;
  try
    LCab.SQL.Text :=
      'SELECT EMPRESA_ID, FORNECEDOR_ID, CONDICAO_PAGAMENTO_ID, NUMERO, ' +
      '       VALOR_TOTAL, COALESCE(DATA_ENTRADA, CURRENT_DATE) AS DATA_BASE ' +
      'FROM NOTA_ENTRADA WHERE ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaEntrada.Create('Nota de entrada não encontrada.');

    LEmpresaId     := LCab.FieldByName('EMPRESA_ID').AsLargeInt;
    LFornecedorId  := LCab.FieldByName('FORNECEDOR_ID').AsLargeInt;
    LCondicaoId    := LCab.FieldByName('CONDICAO_PAGAMENTO_ID').AsLargeInt;
    LNumero        := Trim(LCab.FieldByName('NUMERO').AsString);
    LTotal         := LCab.FieldByName('VALOR_TOTAL').AsFloat;
    LVencimento    := LCab.FieldByName('DATA_BASE').AsDateTime;

    // Só gera contas a pagar se houver fornecedor informado
    if (LFornecedorId = 0) or (LTotal <= 0) then
      Exit;

    LFinanceiroId := GarantirFinanceiro('P', 'Contas a pagar de compras');

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
        'INSERT INTO CONTA_PAGAR ' +
        '  (EMPRESA_ID, FINANCEIRO_ID, FORNECEDOR_ID, DESCRICAO, VALOR, ' +
        '   DATA_VENCIMENTO, STATUS, PARCELA) ' +
        'VALUES (:EMP, :FIN, :FORN, :DESC, :VALOR, :VENC, ''A'', :PARC)';
      LTot.ParamByName('EMP').AsLargeInt := LEmpresaId;
      LTot.ParamByName('FIN').AsLargeInt := LFinanceiroId;
      LTot.ParamByName('FORN').AsLargeInt := LFornecedorId;
      LTot.ParamByName('DESC').AsString :=
        'NF de entrada ' + LNumero + ' (' + IntToStr(LIndice) + '/' + IntToStr(LParcelas) + ')';
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

procedure TNotaEntradaService.Processar(ANotaId: Int64);
var
  LCab: TSQLQuery;
  LMov: TSQLQuery;
  LUpd: TSQLQuery;
  LItens: array of TItemNota;
  LStatus, LModelo, LSerie, LNumero, LDocumento: string;
  LStatusItem: string;
  LEmpresaId, LUsuarioId, LIndice: Integer;
  LDataEntrada: TDate;
  LQuantidade, LValorUnitario, LSaldo, LCustoMedio, LNovoCusto: Double;
  LSaldoPosterior: Double;
  LAtualEstoque, LAtualCusto: Boolean;
  LReg: TSQLQuery;
begin
  FConexao.IniciarTransacao;
  LCab := NovaConsulta;
  LReg := NovaConsulta;
  LMov := NovaConsulta;
  LUpd := NovaConsulta;
  try
    // --- Cabeçalho -------------------------------------------------------
    LCab.SQL.Text :=
      'SELECT STATUS, MODELO, SERIE, NUMERO, EMPRESA_ID, COALESCE(DATA_ENTRADA, CURRENT_DATE) AS DATA_ENTRADA ' +
      'FROM NOTA_ENTRADA WHERE ID = :ID';
    LCab.ParamByName('ID').AsLargeInt := ANotaId;
    LCab.Open;
    if LCab.IsEmpty then
      raise ENotaEntrada.Create('Nota de entrada não encontrada.');

    LStatus := Trim(LCab.FieldByName('STATUS').AsString);
    if LStatus <> 'A' then
      raise ENotaEntrada.Create(
        'Somente notas com status "Aberta" podem ser processadas.');
    LModelo      := Trim(LCab.FieldByName('MODELO').AsString);
    LSerie       := Trim(LCab.FieldByName('SERIE').AsString);
    LNumero      := Trim(LCab.FieldByName('NUMERO').AsString);
    LEmpresaId   := LCab.FieldByName('EMPRESA_ID').AsLargeInt;
    LDataEntrada := LCab.FieldByName('DATA_ENTRADA').AsDateTime;

    if LEmpresaId = 0 then
      LEmpresaId := TSessao.GetInstance.EmpresaId;
    LUsuarioId := TSessao.GetInstance.UsuarioId;

    // --- Itens -----------------------------------------------------------
    LReg.SQL.Text :=
      'SELECT ID, PRODUTO_ID, MATERIAL_ID, DESCRICAO, QUANTIDADE, VALOR_UNITARIO, ' +
      '       ATUALIZA_ESTOQUE, ATUALIZA_CUSTO ' +
      'FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID ORDER BY ID';
    LReg.ParamByName('ID').AsLargeInt := ANotaId;
    LReg.Open;
    SetLength(LItens, 0);
    while not LReg.EOF do
    begin
      SetLength(LItens, Length(LItens) + 1);
      with LItens[High(LItens)] do
      begin
        Id := LReg.FieldByName('ID').AsLargeInt;
        ProdutoId := LReg.FieldByName('PRODUTO_ID').AsLargeInt;
        MaterialId := LReg.FieldByName('MATERIAL_ID').AsLargeInt;
        Descricao := Trim(LReg.FieldByName('DESCRICAO').AsString);
        Quantidade := LReg.FieldByName('QUANTIDADE').AsFloat;
        ValorUnitario := LReg.FieldByName('VALOR_UNITARIO').AsFloat;
        LStatusItem := Trim(LReg.FieldByName('ATUALIZA_ESTOQUE').AsString);
        AtualizaEstoque := (LStatusItem = '') or (LStatusItem = 'S');
        LStatusItem := Trim(LReg.FieldByName('ATUALIZA_CUSTO').AsString);
        AtualizaCusto := (LStatusItem = '') or (LStatusItem = 'S');
      end;
      LReg.Next;
    end;
    LReg.Close;

    if Length(LItens) = 0 then
      raise ENotaEntrada.Create('A nota não possui itens para processar.');

    LDocumento := 'NF ENTRADA';
    if LNumero <> '' then
      LDocumento := LDocumento + ' ' + LModelo + '/' + LSerie + '-' + LNumero;

    // --- Movimentos de estoque + custo médio ------------------------------
    for LIndice := 0 to High(LItens) do
    begin
      if not LItens[LIndice].AtualizaEstoque then
        Continue;

      LQuantidade := LItens[LIndice].Quantidade;
      LValorUnitario := LItens[LIndice].ValorUnitario;

      if LItens[LIndice].ProdutoId > 0 then
      begin
        LerSaldo(LEmpresaId, LItens[LIndice].ProdutoId, LSaldo, LCustoMedio);

        // O trigger TRG_MOVEST_AI atualiza ESTOQUE.QUANTIDADE
        LMov.SQL.Text :=
          'INSERT INTO MOVIMENTO_ESTOQUE ' +
          '  (EMPRESA_ID, PRODUTO_ID, TIPO, QUANTIDADE, CUSTO_UNITARIO, ' +
          '   DOCUMENTO, OBSERVACAO, DATA_MOVIMENTO, USUARIO_ID) ' +
          'VALUES (:EMP, :PROD, ''E'', :QTD, :CUSTO, :DOC, :OBS, :DATA, :USU)';
        LMov.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LMov.ParamByName('PROD').AsLargeInt := LItens[LIndice].ProdutoId;
        LMov.ParamByName('QTD').AsFloat := LQuantidade;
        LMov.ParamByName('CUSTO').AsFloat := LValorUnitario;
        LMov.ParamByName('DOC').AsString := LDocumento;
        LMov.ParamByName('OBS').AsString := 'Entrada por nota de compra';
        LMov.ParamByName('DATA').AsDate := LDataEntrada;
        LMov.ParamByName('USU').AsLargeInt := LUsuarioId;
        LMov.ExecSQL;

        // Custo médio ponderado. Se o saldo atual tem custo desconhecido
        // (ESTOQUE.CUSTO_MEDIO = 0, ex.: saldo inicial importado sem custo), o
        // preço desta compra vira o novo custo médio - caso contrário um saldo
        // grande e sem custo diluiria o custo da compra a quase zero.
        if LItens[LIndice].AtualizaCusto and (LSaldo + LQuantidade > 0) then
        begin
          if LCustoMedio > 0 then
            LNovoCusto :=
              ((LSaldo * LCustoMedio) + (LQuantidade * LValorUnitario)) /
              (LSaldo + LQuantidade)
          else
            LNovoCusto := LValorUnitario;

          LUpd.SQL.Text :=
            'UPDATE ESTOQUE SET CUSTO_MEDIO = :CUSTO ' +
            'WHERE EMPRESA_ID = :EMP AND PRODUTO_ID = :PROD';
          LUpd.ParamByName('CUSTO').AsFloat := LNovoCusto;
          LUpd.ParamByName('EMP').AsLargeInt := LEmpresaId;
          LUpd.ParamByName('PROD').AsLargeInt := LItens[LIndice].ProdutoId;
          LUpd.ExecSQL;

          LUpd.SQL.Text :=
            'UPDATE PRODUTO SET PRECO_CUSTO = :CUSTO WHERE ID = :PROD';
          LUpd.ParamByName('CUSTO').AsFloat := LNovoCusto;
          LUpd.ParamByName('PROD').AsLargeInt := LItens[LIndice].ProdutoId;
          LUpd.ExecSQL;
        end;
      end
      else if LItens[LIndice].MaterialId > 0 then
      begin
        // Item de material (compras): o saldo de ESTOQUE_MATERIAL não tem
        // trigger, então o service grava o movimento e atualiza o saldo.
        LerSaldoMaterial(LEmpresaId, LItens[LIndice].MaterialId, LSaldo);
        LSaldoPosterior := LSaldo + LQuantidade;

        LMov.SQL.Text :=
          'INSERT INTO MOVIMENTO_MATERIAL ' +
          '  (EMPRESA_ID, MATERIAL_ID, TIPO, QUANTIDADE, SALDO_ANTERIOR, ' +
          '   SALDO_POSTERIOR, CUSTO_UNITARIO, ORIGEM, DOCUMENTO_ID, ' +
          '   OBSERVACOES, USUARIO_ID, DATA_MOVIMENTO) ' +
          'VALUES (:EMP, :MAT, ''E'', :QTD, :SALDO_ANT, :SALDO_POS, :CUSTO, ' +
          '  ''NOTA_ENTRADA'', :DOC_ID, :OBS, :USU, :DATA)';
        LMov.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LMov.ParamByName('MAT').AsLargeInt := LItens[LIndice].MaterialId;
        LMov.ParamByName('QTD').AsFloat := LQuantidade;
        LMov.ParamByName('SALDO_ANT').AsFloat := LSaldo;
        LMov.ParamByName('SALDO_POS').AsFloat := LSaldoPosterior;
        LMov.ParamByName('CUSTO').AsFloat := LValorUnitario;
        LMov.ParamByName('DOC_ID').AsLargeInt := ANotaId;
        LMov.ParamByName('OBS').AsString := 'Entrada por nota de compra';
        LMov.ParamByName('USU').AsLargeInt := LUsuarioId;
        LMov.ParamByName('DATA').AsDate := LDataEntrada;
        LMov.ExecSQL;

        LUpd.SQL.Text :=
          'UPDATE ESTOQUE_MATERIAL SET QUANTIDADE = :QTD, ' +
          '  DATA_ATUALIZACAO = CURRENT_TIMESTAMP ' +
          'WHERE EMPRESA_ID = :EMP AND MATERIAL_ID = :MAT';
        LUpd.ParamByName('QTD').AsFloat := LSaldoPosterior;
        LUpd.ParamByName('EMP').AsLargeInt := LEmpresaId;
        LUpd.ParamByName('MAT').AsLargeInt := LItens[LIndice].MaterialId;
        LUpd.ExecSQL;

        if not LerSaldoMaterial(LEmpresaId, LItens[LIndice].MaterialId, LSaldo) then
        begin
          LUpd.SQL.Text :=
            'INSERT INTO ESTOQUE_MATERIAL (EMPRESA_ID, MATERIAL_ID, QUANTIDADE, ' +
            '  DATA_ATUALIZACAO) VALUES (:EMP, :MAT, :QTD, CURRENT_TIMESTAMP)';
          LUpd.ParamByName('EMP').AsLargeInt := LEmpresaId;
          LUpd.ParamByName('MAT').AsLargeInt := LItens[LIndice].MaterialId;
          LUpd.ParamByName('QTD').AsFloat := LSaldoPosterior;
          LUpd.ExecSQL;
        end;

        // Material não tem custo médio: o último custo de compra vira o
        // PRECO_CUSTO do cadastro.
        if LItens[LIndice].AtualizaCusto then
        begin
          LUpd.SQL.Text :=
            'UPDATE MATERIAL SET PRECO_CUSTO = :CUSTO WHERE ID = :MAT';
          LUpd.ParamByName('CUSTO').AsFloat := LValorUnitario;
          LUpd.ParamByName('MAT').AsLargeInt := LItens[LIndice].MaterialId;
          LUpd.ExecSQL;
        end;
      end
      else
        raise ENotaEntrada.Create(
          'O item "' + LItens[LIndice].Descricao +
          '" não está ligado a um produto nem a um material.');
    end;

    // --- Financeiro -------------------------------------------------------
    GerarContasPagar(ANotaId);

    // --- Fecha a nota -----------------------------------------------------
    LUpd.SQL.Text :=
      'UPDATE NOTA_ENTRADA SET STATUS = ''P'', DATA_PROCESSAMENTO = CURRENT_TIMESTAMP ' +
      'WHERE ID = :ID';
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

// Gera a nota de entrada (status Aberta) a partir do pedido de compra.
function TNotaEntradaService.CriarDoPedidoCompra(APedidoCompraId: Int64): Int64;
var
  LPed, LItens, LFisc, LIns, LItem, LUpd: TSQLQuery;
  LStatus, LNumero, LNcm, LCfop, LCst, LControle, LObs: string;
  LEmpresaId, LFornecedorId, LProdutoFiscalId: Int64;
  LQuantidade, LValorUnitario, LValorTotal, LDesconto: Double;
  LAliq, LValorIcms: Double;
  LDataEmissao: TDate;
  LQtdItens: Integer;
begin
  Result := 0;
  FConexao.IniciarTransacao;
  LPed   := NovaConsulta;
  LItens := NovaConsulta;
  LFisc  := NovaConsulta;
  LIns   := NovaConsulta;
  LItem  := NovaConsulta;
  LUpd   := NovaConsulta;
  try
    // --- Pedido de compra --------------------------------------------------
    LPed.SQL.Text :=
      'SELECT STATUS, EMPRESA_ID, FORNECEDOR_ID, NUMERO, ' +
      '       COALESCE(DATA_EMISSAO, CURRENT_DATE) AS DATA_EMISSAO, NOTA_ENTRADA_ID ' +
      'FROM PEDIDO_COMPRA WHERE ID = :ID';
    LPed.ParamByName('ID').AsLargeInt := APedidoCompraId;
    LPed.Open;
    if LPed.IsEmpty then
      raise ENotaEntrada.Create('Pedido de compra não encontrado.');

    LStatus := UpperCase(Trim(LPed.FieldByName('STATUS').AsString));
    if LStatus = 'CANCELADO' then
      raise ENotaEntrada.Create(
        'Pedido de compra cancelado não gera nota de entrada.');
    if LPed.FieldByName('NOTA_ENTRADA_ID').AsLargeInt > 0 then
      raise ENotaEntrada.Create(
        'Este pedido de compra já gerou a nota de entrada nº ' +
        IntToStr(LPed.FieldByName('NOTA_ENTRADA_ID').AsLargeInt) + '.');

    LEmpresaId := LPed.FieldByName('EMPRESA_ID').AsLargeInt;
    if LEmpresaId = 0 then
      LEmpresaId := TSessao.GetInstance.EmpresaId;
    LFornecedorId := LPed.FieldByName('FORNECEDOR_ID').AsLargeInt;
    LNumero       := Trim(LPed.FieldByName('NUMERO').AsString);
    LDataEmissao  := LPed.FieldByName('DATA_EMISSAO').AsDateTime;

    // --- Itens do pedido (com os dados do material) ------------------------
    LItens.SQL.Text :=
      'SELECT I.MATERIAL_ID, I.QUANTIDADE, I.VALOR_UNITARIO, ' +
      '       COALESCE(I.DESCONTO, 0) AS DESCONTO, ' +
      '       COALESCE(M.DESCRICAO, ''Material '' || I.MATERIAL_ID) AS DESCRICAO, ' +
      '       M.CODIGO, M.PRODUTO_FISCAL_ID, M.CONTROLA_ESTOQUE ' +
      'FROM PEDIDO_COMPRA_ITEM I LEFT JOIN MATERIAL M ON M.ID = I.MATERIAL_ID ' +
      'WHERE I.PEDIDO_COMPRA_ID = :ID ORDER BY I.ID';
    LItens.ParamByName('ID').AsLargeInt := APedidoCompraId;
    LItens.Open;
    if LItens.IsEmpty then
      raise ENotaEntrada.Create('O pedido de compra não possui itens.');
    LItens.First;

    // --- Cabeçalho da nota (Aberta, CFOP de compra padrão) -----------------
    LObs := 'Gerada do pedido de compra Nº ' + LNumero;
    LIns.SQL.Text :=
      'INSERT INTO NOTA_ENTRADA (EMPRESA_ID, FORNECEDOR_ID, NUMERO, SERIE, MODELO, ' +
      '  DATA_EMISSAO, DATA_ENTRADA, NATUREZA_OPERACAO, CFOP, VALOR_PRODUTOS, ' +
      '  VALOR_TOTAL, STATUS, OBSERVACOES, USUARIO_ID, DATA_CADASTRO) ' +
      'VALUES (:EMP, :FORN, :NUM, ''1'', ''55'', :DEMI, :DENT, ' +
      '  ''Compra para comercialização'', ''1102'', 0, 0, ''A'', :OBS, :USU, ' +
      '  CURRENT_TIMESTAMP) RETURNING ID';
    LIns.ParamByName('EMP').AsLargeInt := LEmpresaId;
    if LFornecedorId > 0 then
      LIns.ParamByName('FORN').AsLargeInt := LFornecedorId
    else
      LIns.ParamByName('FORN').Clear;
    LIns.ParamByName('NUM').AsString := LNumero;
    LIns.ParamByName('DEMI').AsDate := LDataEmissao;
    LIns.ParamByName('DENT').AsDate := Now;
    LIns.ParamByName('OBS').AsString := LObs;
    LIns.ParamByName('USU').AsLargeInt := TSessao.GetInstance.UsuarioId;
    LIns.Open;
    Result := LIns.FieldByName('ID').AsLargeInt;
    LIns.Close;

    // --- Itens da nota -----------------------------------------------------
    LQtdItens := 0;
    while not LItens.EOF do
    begin
      LProdutoFiscalId := LItens.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt;
      LNcm  := '';
      LCfop := '1102';
      LCst  := '';
      LAliq := 0;

      if LProdutoFiscalId > 0 then
      begin
        LFisc.SQL.Text :=
          'SELECT COALESCE(NCM, '''') AS NCM, ' +
          '       COALESCE(CFOP_COMPRA, CFOP, '''') AS CFOP, ' +
          '       COALESCE(CST_ICMS, '''') AS CST, ' +
          '       COALESCE(ALIQ_ICMS, 0) AS ALIQ ' +
          'FROM PRODUTO_FISCAL WHERE ID = :ID';
        LFisc.ParamByName('ID').AsLargeInt := LProdutoFiscalId;
        LFisc.Open;
        if not LFisc.IsEmpty then
        begin
          if Trim(LFisc.FieldByName('NCM').AsString) <> '' then
            LNcm := Trim(LFisc.FieldByName('NCM').AsString);
          if Trim(LFisc.FieldByName('CFOP').AsString) <> '' then
            LCfop := Trim(LFisc.FieldByName('CFOP').AsString);
          LCst  := Trim(LFisc.FieldByName('CST').AsString);
          LAliq := LFisc.FieldByName('ALIQ').AsFloat;
        end;
        LFisc.Close;
      end;

      LQuantidade    := LItens.FieldByName('QUANTIDADE').AsFloat;
      LValorUnitario := LItens.FieldByName('VALOR_UNITARIO').AsFloat;
      LDesconto      := LItens.FieldByName('DESCONTO').AsFloat;
      LValorTotal    := LQuantidade * LValorUnitario - LDesconto;
      LValorIcms     := LQuantidade * LValorUnitario * LAliq / 100;

      // Materiais sem controle de estoque não geram movimento.
      LControle := UpperCase(Trim(LItens.FieldByName('CONTROLA_ESTOQUE').AsString));
      if LControle <> 'N' then
        LControle := 'S';

      LItem.SQL.Text :=
        'INSERT INTO NOTA_ENTRADA_ITEM (NOTA_ENTRADA_ID, MATERIAL_ID, ' +
        '  PRODUTO_FISCAL_ID, DESCRICAO, NCM, CFOP, CST_ICMS, ALIQ_ICMS, ' +
        '  VALOR_ICMS, QUANTIDADE, VALOR_UNITARIO, VALOR_TOTAL, DESCONTO, ' +
        '  ATUALIZA_ESTOQUE, ATUALIZA_CUSTO) ' +
        'VALUES (:NOTA, :MAT, :PFISC, :DESC, :NCM, :CFOP, :CST, :ALIQ, :VICMS, ' +
        '  :QTD, :VUN, :VTOT, :DSC, :ATEST, ''S'')';
      LItem.ParamByName('NOTA').AsLargeInt := Result;
      LItem.ParamByName('MAT').AsLargeInt := LItens.FieldByName('MATERIAL_ID').AsLargeInt;
      if LProdutoFiscalId > 0 then
        LItem.ParamByName('PFISC').AsLargeInt := LProdutoFiscalId
      else
        LItem.ParamByName('PFISC').Clear;
      LItem.ParamByName('DESC').AsString := Trim(LItens.FieldByName('DESCRICAO').AsString);
      LItem.ParamByName('NCM').AsString := LNcm;
      LItem.ParamByName('CFOP').AsString := LCfop;
      LItem.ParamByName('CST').AsString := LCst;
      LItem.ParamByName('ALIQ').AsFloat := LAliq;
      LItem.ParamByName('VICMS').AsFloat := LValorIcms;
      LItem.ParamByName('QTD').AsFloat := LQuantidade;
      LItem.ParamByName('VUN').AsFloat := LValorUnitario;
      LItem.ParamByName('VTOT').AsFloat := LValorTotal;
      LItem.ParamByName('DSC').AsFloat := LDesconto;
      LItem.ParamByName('ATEST').AsString := LControle;
      LItem.ExecSQL;

      Inc(LQtdItens);
      LItens.Next;
    end;

    // --- Totais + vínculo no pedido ---------------------------------------
    RecalcularTotais(Result);

    LUpd.SQL.Text :=
      'UPDATE PEDIDO_COMPRA SET NOTA_ENTRADA_ID = :NOTA, STATUS = ''CONFIRMADO'', ' +
      '  DATA_ATUALIZACAO = CURRENT_TIMESTAMP WHERE ID = :ID';
    LUpd.ParamByName('NOTA').AsLargeInt := Result;
    LUpd.ParamByName('ID').AsLargeInt := APedidoCompraId;
    LUpd.ExecSQL;

    RegistrarAuditoria('NOTA_ENTRADA', 'I', Result, '',
      'ORIGEM=PEDIDO_COMPRA; PEDIDO=' + IntToStr(APedidoCompraId) +
      '; ITENS=' + IntToStr(LQtdItens));

    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LPed.Free;
    LItens.Free;
    LFisc.Free;
    LIns.Free;
    LItem.Free;
    LUpd.Free;
    raise;
  end;

  LPed.Free;
  LItens.Free;
  LFisc.Free;
  LIns.Free;
  LItem.Free;
  LUpd.Free;
end;

procedure TNotaEntradaService.Cancelar(ANotaId: Int64);
var
  LQuery: TSQLQuery;
  LStatus: string;
begin
  FConexao.IniciarTransacao;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text := 'SELECT STATUS FROM NOTA_ENTRADA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise ENotaEntrada.Create('Nota de entrada não encontrada.');
    LStatus := Trim(LQuery.FieldByName('STATUS').AsString);
    LQuery.Close;

    if LStatus = 'P' then
      raise ENotaEntrada.Create(
        'Esta nota já foi processada. Cancele a movimentação de estoque ' +
        'e as contas a pagar manualmente.');
    if LStatus = 'C' then
      raise ENotaEntrada.Create('Esta nota já está cancelada.');

    LQuery.SQL.Text := 'UPDATE NOTA_ENTRADA SET STATUS = ''C'' WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  except
    FConexao.Cancelar;
    LQuery.Free;
    raise;
  end;
  LQuery.Free;
end;

end.
