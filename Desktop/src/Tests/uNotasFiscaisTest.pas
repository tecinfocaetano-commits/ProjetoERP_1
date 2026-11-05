unit uNotasFiscaisTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes das notas fiscais de entrada e saída
  ------------------------------------------------------------
  Cobre as regras de negócio dos Services:

    - TNotaEntradaService: criação a partir do pedido de compra,
      processamento (estoque de produto e de material, custo médio,
      contas a pagar), cancelamento, itens, classificação fiscal e
      auditoria;
    - TNotaSaidaService: criação a partir do pedido de venda,
      faturamento (baixa de estoque, contas a receber, chave de
      acesso de 44 dígitos com DV), cancelamento/estorno, cabeçalho,
      itens e XML.

  Padrão da suíte: dados com sufixo de timestamp e limpeza explícita
  no finally, sem mock de banco. Os Services confirmam a transação
  internamente; por isso os fixtures são confirmados antes de cada
  caso para que um rollback do Service não os apague. A limpeza
  final remove tudo pelo sufixo e corta o LOG_SISTEMA no topo
  capturado antes da suíte.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uNotaEntradaService, uNotaSaidaService;

type
  { TNotasFiscaisTest }
  TNotasFiscaisTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

uses
  DateUtils;

{ TNotasFiscaisTest }

class procedure TNotasFiscaisTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LEntrada: TNotaEntradaService;
  LSaida: TNotaSaidaService;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;
  LClienteId: Int64;
  LFornecedorId: Int64;
  LCondicao3Id: Int64;
  LCondicao1Id: Int64;
  LFiscalId: Int64;

  function QuaseIgual(A, B: Double): Boolean;
  begin
    Result := Abs(A - B) < 0.001;
  end;

  function NovoNumero(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + Copy(LSufixo, 1, 8) + '-' + IntToStr(LSeq);
  end;

  function Codigo(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + Copy(LSufixo, 1, 10) + IntToStr(LSeq);
  end;

  procedure ExecId(const ASQL, AParam: string; AId: Int64);
  begin
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName(AParam).AsLargeInt := AId;
    LQuery.ExecSQL;
  end;

  function TextoPorId(const ASQL: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function FloatPorId(const ASQL: string; AId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function IntPorId(const ASQL: string; AId: Int64): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsLargeInt;
    LQuery.Close;
  end;

  // ------------------------------------------------------------------
  // Fixtures
  // ------------------------------------------------------------------

  function InserirPessoa(ATipo: Char; const ANome: string): Int64;
  var
    LDoc: string;
  begin
    Inc(LSeq);
    LDoc := '9' + Copy(LSufixo, 1, 12) + IntToStr(LSeq);
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, ' +
      '  ATIVO, DATA_CADASTRO) ' +
      'VALUES (:EMP, :TIPO, ''F'', :NOME, :DOC, ''A'', CURRENT_TIMESTAMP) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('NOME').AsString := ANome;
    LQuery.ParamByName('DOC').AsString := LDoc;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirProdutoFiscal(const ADescricao: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO_FISCAL (EMPRESA_ID, CODIGO, DESCRICAO, NCM, ' +
      '  CFOP_COMPRA, CFOP_VENDA, CST_ICMS, ALIQ_ICMS, ATIVO) ' +
      'VALUES (:EMP, :COD, :DESC, ''12345678'', ''1102'', ''5102'', ''00'', ' +
      '  18, ''A'') RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('COD').AsString := Codigo('PF');
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirCondicao(const ADescricao: string; AParcelas,
    ADias: Integer): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO CONDICAO_PAGAMENTO (DESCRICAO, PARCELAS, ' +
      '  DIAS_ENTRE_PARCELAS, STATUS, ATIVO) ' +
      'VALUES (:DESC, :PARC, :DIAS, ''A'', ''A'') RETURNING ID';
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('PARC').AsInteger := AParcelas;
    LQuery.ParamByName('DIAS').AsInteger := ADias;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirProduto(const ADescricao: string; AFiscalId: Int64;
    ACusto, AVenda: Double; const ANcm, ACfopCompra, ACfopVenda,
    ACst: string; AAliq: Double): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, DESCRICAO, ' +
      '  CODIGO, PRECO_CUSTO, PRECO_VENDA, CONTROLA_ESTOQUE, ATIVO, ' +
      '  PRODUTO_FISCAL_ID, NCM, CFOP_COMPRA, CFOP_VENDA, CST_ICMS, ALIQ_ICMS) ' +
      'VALUES (:EMP, 1, 1, :DESC, :COD, :CUSTO, :VENDA, ''S'', ''A'', :FISC, ' +
      '  :NCM, :CFOPC, :CFOPV, :CST, :ALIQ) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('COD').AsString := Codigo('P');
    LQuery.ParamByName('CUSTO').AsFloat := ACusto;
    LQuery.ParamByName('VENDA').AsFloat := AVenda;
    if AFiscalId > 0 then
      LQuery.ParamByName('FISC').AsLargeInt := AFiscalId
    else
      LQuery.ParamByName('FISC').Clear;
    LQuery.ParamByName('NCM').AsString := ANcm;
    LQuery.ParamByName('CFOPC').AsString := ACfopCompra;
    LQuery.ParamByName('CFOPV').AsString := ACfopVenda;
    LQuery.ParamByName('CST').AsString := ACst;
    LQuery.ParamByName('ALIQ').AsFloat := AAliq;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirEstoque(AProdutoId: Int64; AQuantidade,
    ACusto: Double): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO ESTOQUE (EMPRESA_ID, PRODUTO_ID, QUANTIDADE, CUSTO_MEDIO, ' +
      '  DATA_ATUALIZACAO) VALUES (:EMP, :PROD, :QTD, :CUSTO, ' +
      '  CURRENT_TIMESTAMP) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('CUSTO').AsFloat := ACusto;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirMaterial(const ADescricao: string; AFiscalId: Int64;
    ACusto: Double; AControlaEstoque: Boolean): Int64;
  var
    LCtrl: string;
  begin
    if AControlaEstoque then
      LCtrl := 'S'
    else
      LCtrl := 'N';
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO MATERIAL (EMPRESA_ID, PRODUTO_FISCAL_ID, DESCRICAO, ' +
      '  CODIGO, PRECO_CUSTO, CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, :FISC, :DESC, :COD, :CUSTO, :CTRL, ''A'') ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    if AFiscalId > 0 then
      LQuery.ParamByName('FISC').AsLargeInt := AFiscalId
    else
      LQuery.ParamByName('FISC').Clear;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('COD').AsString := Codigo('M');
    LQuery.ParamByName('CUSTO').AsFloat := ACusto;
    LQuery.ParamByName('CTRL').AsString := LCtrl;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirEstoqueMaterial(AMaterialId: Int64;
    AQuantidade: Double): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO ESTOQUE_MATERIAL (EMPRESA_ID, MATERIAL_ID, QUANTIDADE, ' +
      '  DATA_ATUALIZACAO) VALUES (:EMP, :MAT, :QTD, CURRENT_TIMESTAMP) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('MAT').AsLargeInt := AMaterialId;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirPedidoVenda(AClienteId, ACondicaoId: Int64;
    const ANumero, AStatus: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, NUMERO, ' +
      '  DATA_EMISSAO, STATUS, SUBTOTAL, DESCONTO, TOTAL, ' +
      '  CONDICAO_PAGAMENTO_ID) ' +
      'VALUES (:EMP, :CLI, :NUM, CURRENT_DATE, :STATUS, 0, 0, 0, :COND) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    if AClienteId > 0 then
      LQuery.ParamByName('CLI').AsLargeInt := AClienteId
    else
      LQuery.ParamByName('CLI').Clear;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.ParamByName('STATUS').AsString := AStatus;
    if ACondicaoId > 0 then
      LQuery.ParamByName('COND').AsLargeInt := ACondicaoId
    else
      LQuery.ParamByName('COND').Clear;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirItemPedido(APedidoId, AProdutoId: Int64;
    AQuantidade, AValorUnitario, ADesconto: Double;
    const ACfop: string): Int64;
  var
    LTotal: Double;
  begin
    LTotal := AQuantidade * AValorUnitario - ADesconto;
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO ITEM_PEDIDO (PEDIDO_VENDA_ID, PRODUTO_ID, QUANTIDADE, ' +
      '  PRECO_UNITARIO, VALOR_UNITARIO, VALOR_TOTAL, DESCONTO, CFOP) ' +
      'VALUES (:PED, :PROD, :QTD, :VUN, :VUN, :TOTAL, :DSC, :CFOP) ' +
      'RETURNING ID';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('VUN').AsFloat := AValorUnitario;
    LQuery.ParamByName('TOTAL').AsFloat := LTotal;
    LQuery.ParamByName('DSC').AsFloat := ADesconto;
    if ACfop <> '' then
      LQuery.ParamByName('CFOP').AsString := ACfop
    else
      LQuery.ParamByName('CFOP').Clear;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirPedidoCompra(AFornecedorId: Int64;
    const ANumero, AStatus: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_COMPRA (EMPRESA_ID, FORNECEDOR_ID, NUMERO, ' +
      '  DATA_EMISSAO, STATUS, SUBTOTAL, DESCONTO, TOTAL) ' +
      'VALUES (:EMP, :FORN, :NUM, CURRENT_DATE, :STATUS, 0, 0, 0) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    if AFornecedorId > 0 then
      LQuery.ParamByName('FORN').AsLargeInt := AFornecedorId
    else
      LQuery.ParamByName('FORN').Clear;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.ParamByName('STATUS').AsString := AStatus;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirItemPedidoCompra(APedidoId, AMaterialId: Int64;
    AQuantidade, AValorUnitario, ADesconto: Double): Int64;
  var
    LTotal: Double;
  begin
    LTotal := AQuantidade * AValorUnitario - ADesconto;
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_COMPRA_ITEM (PEDIDO_COMPRA_ID, MATERIAL_ID, ' +
      '  QUANTIDADE, VALOR_UNITARIO, DESCONTO, VALOR_TOTAL) ' +
      'VALUES (:PED, :MAT, :QTD, :VUN, :DSC, :TOTAL) RETURNING ID';
    LQuery.ParamByName('PED').AsLargeInt := APedidoId;
    LQuery.ParamByName('MAT').AsLargeInt := AMaterialId;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('VUN').AsFloat := AValorUnitario;
    LQuery.ParamByName('DSC').AsFloat := ADesconto;
    LQuery.ParamByName('TOTAL').AsFloat := LTotal;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirNotaEntrada(AFornecedorId, ACondicaoId: Int64;
    const ANumero: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO NOTA_ENTRADA (EMPRESA_ID, FORNECEDOR_ID, NUMERO, SERIE, ' +
      '  MODELO, DATA_EMISSAO, DATA_ENTRADA, NATUREZA_OPERACAO, CFOP, ' +
      '  STATUS, CONDICAO_PAGAMENTO_ID, OBSERVACOES, USUARIO_ID, ' +
      '  DATA_CADASTRO) ' +
      'VALUES (:EMP, :FORN, :NUM, ''1'', ''55'', CURRENT_DATE, CURRENT_DATE, ' +
      '  ''Compra para teste'', ''1102'', ''A'', :COND, :OBS, :USU, ' +
      '  CURRENT_TIMESTAMP) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    if AFornecedorId > 0 then
      LQuery.ParamByName('FORN').AsLargeInt := AFornecedorId
    else
      LQuery.ParamByName('FORN').Clear;
    LQuery.ParamByName('NUM').AsString := ANumero;
    if ACondicaoId > 0 then
      LQuery.ParamByName('COND').AsLargeInt := ACondicaoId
    else
      LQuery.ParamByName('COND').Clear;
    LQuery.ParamByName('OBS').AsString := 'Nota de entrada de teste ' + LSufixo;
    LQuery.ParamByName('USU').AsLargeInt := LSessao.UsuarioId;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirItemNotaEntrada(ANotaId, AProdutoId, AMaterialId: Int64;
    const ADescricao: string; AQuantidade, AValorUnitario: Double;
    AAtualizaEstoque: Boolean): Int64;
  var
    LTotal: Double;
    LAtualiza: string;
  begin
    LTotal := AQuantidade * AValorUnitario;
    if AAtualizaEstoque then
      LAtualiza := 'S'
    else
      LAtualiza := 'N';
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO NOTA_ENTRADA_ITEM (NOTA_ENTRADA_ID, PRODUTO_ID, ' +
      '  MATERIAL_ID, DESCRICAO, QUANTIDADE, VALOR_UNITARIO, VALOR_TOTAL, ' +
      '  DESCONTO, ATUALIZA_ESTOQUE, ATUALIZA_CUSTO) ' +
      'VALUES (:NOTA, :PROD, :MAT, :DESC, :QTD, :VUN, :TOTAL, 0, :AT, ''S'') ' +
      'RETURNING ID';
    LQuery.ParamByName('NOTA').AsLargeInt := ANotaId;
    if AProdutoId > 0 then
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId
    else
      LQuery.ParamByName('PROD').Clear;
    if AMaterialId > 0 then
      LQuery.ParamByName('MAT').AsLargeInt := AMaterialId
    else
      LQuery.ParamByName('MAT').Clear;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('VUN').AsFloat := AValorUnitario;
    LQuery.ParamByName('TOTAL').AsFloat := LTotal;
    LQuery.ParamByName('AT').AsString := LAtualiza;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirNotaSaida(AClienteId, ACondicaoId, APedidoId: Int64;
    const ANumero: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO NOTA_SAIDA (EMPRESA_ID, CLIENTE_ID, PEDIDO_VENDA_ID, ' +
      '  NUMERO, SERIE, MODELO, NATUREZA_OPERACAO, CFOP, DATA_EMISSAO, ' +
      '  DATA_SAIDA, STATUS, CONDICAO_PAGAMENTO_ID, OBSERVACOES, ' +
      '  USUARIO_ID, DATA_CADASTRO) ' +
      'VALUES (:EMP, :CLI, :PED, :NUM, ''1'', ''55'', ''VENDA DE MERCADORIA'', ' +
      '  ''5102'', CURRENT_DATE, CURRENT_DATE, ''A'', :COND, :OBS, :USU, ' +
      '  CURRENT_TIMESTAMP) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    if AClienteId > 0 then
      LQuery.ParamByName('CLI').AsLargeInt := AClienteId
    else
      LQuery.ParamByName('CLI').Clear;
    if APedidoId > 0 then
      LQuery.ParamByName('PED').AsLargeInt := APedidoId
    else
      LQuery.ParamByName('PED').Clear;
    LQuery.ParamByName('NUM').AsString := ANumero;
    if ACondicaoId > 0 then
      LQuery.ParamByName('COND').AsLargeInt := ACondicaoId
    else
      LQuery.ParamByName('COND').Clear;
    LQuery.ParamByName('OBS').AsString := 'Nota de saída de teste ' + LSufixo;
    LQuery.ParamByName('USU').AsLargeInt := LSessao.UsuarioId;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirItemNotaSaida(ANotaId, AProdutoId: Int64;
    const ADescricao: string; AQuantidade, AValorUnitario: Double;
    AAtualizaEstoque: Boolean): Int64;
  var
    LTotal: Double;
    LAtualiza: string;
  begin
    LTotal := AQuantidade * AValorUnitario;
    if AAtualizaEstoque then
      LAtualiza := 'S'
    else
      LAtualiza := 'N';
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO NOTA_SAIDA_ITEM (NOTA_SAIDA_ID, PRODUTO_ID, CODIGO, ' +
      '  DESCRICAO, UNIDADE, NCM, CFOP, CST_ICMS, ALIQ_ICMS, VALOR_ICMS, ' +
      '  QUANTIDADE, VALOR_UNITARIO, VALOR_TOTAL, DESCONTO, ' +
      '  ATUALIZA_ESTOQUE) ' +
      'VALUES (:NOTA, :PROD, :COD, :DESC, ''UN'', ''12345678'', ''5102'', ' +
      '  ''00'', 0, 0, :QTD, :VUN, :TOTAL, 0, :AT) RETURNING ID';
    LQuery.ParamByName('NOTA').AsLargeInt := ANotaId;
    if AProdutoId > 0 then
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId
    else
      LQuery.ParamByName('PROD').Clear;
    LQuery.ParamByName('COD').AsString := Codigo('S');
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('VUN').AsFloat := AValorUnitario;
    LQuery.ParamByName('TOTAL').AsFloat := LTotal;
    LQuery.ParamByName('AT').AsString := LAtualiza;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  // ------------------------------------------------------------------
  // Limpeza final (por sufixo, na ordem das dependências)
  // ------------------------------------------------------------------

  // O SQLDB/Firebird liga apenas a primeira ocorrência de um parâmetro
  // repetido (:P) e deixa as demais em NULL; por isso cada condição usa um
  // nome próprio (:P1, :P2...) e o helper liga todos ao sufixo da rodada.
  procedure ExecSufixo(const ASQL: string; const ANomes: array of string);
  var
    LIndice: Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    for LIndice := Low(ANomes) to High(ANomes) do
      LQuery.ParamByName(ANomes[LIndice]).AsString := LSufixo;
    LQuery.ExecSQL;
  end;

  procedure LimparSobraPorSufixo;
  begin
    try
      ExecSufixo(
        'DELETE FROM CONTA_RECEBER ' +
        'WHERE CLIENTE_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P1) ' +
        '  OR NOTA_SAIDA_ID IN (SELECT ID FROM NOTA_SAIDA ' +
        '       WHERE OBSERVACOES CONTAINING :P2 ' +
        '       OR PEDIDO_VENDA_ID IN (SELECT ID FROM PEDIDO_VENDA ' +
        '            WHERE NUMERO CONTAINING :P3))',
        ['P1', 'P2', 'P3']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM CONTA_PAGAR WHERE FORNECEDOR_ID IN (' +
        '  SELECT ID FROM PESSOA WHERE NOME CONTAINING :P1)', ['P1']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID IN (' +
        '  SELECT ID FROM PRODUTO WHERE DESCRICAO CONTAINING :P1)', ['P1']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM MOVIMENTO_MATERIAL WHERE MATERIAL_ID IN (' +
        '  SELECT ID FROM MATERIAL WHERE DESCRICAO CONTAINING :P1)', ['P1']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM NOTA_SAIDA_ITEM WHERE NOTA_SAIDA_ID IN (' +
        '  SELECT ID FROM NOTA_SAIDA WHERE OBSERVACOES CONTAINING :P1 ' +
        '  OR CLIENTE_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2) ' +
        '  OR PEDIDO_VENDA_ID IN (SELECT ID FROM PEDIDO_VENDA ' +
        '       WHERE NUMERO CONTAINING :P3))', ['P1', 'P2', 'P3']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM NOTA_SAIDA WHERE OBSERVACOES CONTAINING :P1 ' +
        '  OR CLIENTE_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2) ' +
        '  OR PEDIDO_VENDA_ID IN (SELECT ID FROM PEDIDO_VENDA ' +
        '       WHERE NUMERO CONTAINING :P3)', ['P1', 'P2', 'P3']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID IN (' +
        '  SELECT ID FROM NOTA_ENTRADA WHERE OBSERVACOES CONTAINING :P1 ' +
        '  OR FORNECEDOR_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2))',
        ['P1', 'P2']);
    except
    end;
    try
      ExecSufixo(
        'UPDATE PEDIDO_COMPRA SET NOTA_ENTRADA_ID = NULL ' +
        'WHERE NOTA_ENTRADA_ID IN (' +
        '  SELECT ID FROM NOTA_ENTRADA WHERE OBSERVACOES CONTAINING :P1 ' +
        '  OR FORNECEDOR_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2))',
        ['P1', 'P2']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM NOTA_ENTRADA WHERE OBSERVACOES CONTAINING :P1 ' +
        '  OR FORNECEDOR_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2)',
        ['P1', 'P2']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID IN (' +
        '  SELECT ID FROM PEDIDO_VENDA WHERE NUMERO CONTAINING :P1 ' +
        '  OR CLIENTE_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2))',
        ['P1', 'P2']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM PEDIDO_VENDA WHERE NUMERO CONTAINING :P1 ' +
        '  OR CLIENTE_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2)',
        ['P1', 'P2']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM PEDIDO_COMPRA_ITEM WHERE PEDIDO_COMPRA_ID IN (' +
        '  SELECT ID FROM PEDIDO_COMPRA WHERE NUMERO CONTAINING :P1 ' +
        '  OR FORNECEDOR_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2))',
        ['P1', 'P2']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM PEDIDO_COMPRA WHERE NUMERO CONTAINING :P1 ' +
        '  OR FORNECEDOR_ID IN (SELECT ID FROM PESSOA WHERE NOME CONTAINING :P2)',
        ['P1', 'P2']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM ESTOQUE WHERE PRODUTO_ID IN (' +
        '  SELECT ID FROM PRODUTO WHERE DESCRICAO CONTAINING :P1)', ['P1']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM ESTOQUE_MATERIAL WHERE MATERIAL_ID IN (' +
        '  SELECT ID FROM MATERIAL WHERE DESCRICAO CONTAINING :P1)', ['P1']);
    except
    end;
    try
      ExecSufixo('DELETE FROM PRODUTO WHERE DESCRICAO CONTAINING :P1', ['P1']);
    except
    end;
    try
      ExecSufixo('DELETE FROM MATERIAL WHERE DESCRICAO CONTAINING :P1', ['P1']);
    except
    end;
    try
      ExecSufixo('DELETE FROM PRODUTO_FISCAL WHERE DESCRICAO CONTAINING :P1',
        ['P1']);
    except
    end;
    try
      ExecSufixo('DELETE FROM PESSOA WHERE NOME CONTAINING :P1', ['P1']);
    except
    end;
    try
      ExecSufixo('DELETE FROM CONDICAO_PAGAMENTO WHERE DESCRICAO CONTAINING :P1',
        ['P1']);
    except
    end;
    try
      ExecId('DELETE FROM LOG_SISTEMA WHERE ID > :TOPO', 'TOPO', LTopoLog);
    except
    end;
    try
      LConexao.Confirmar;
    except
    end;
  end;

  function ContarContasPagar(AFornecedorId: Int64;
    const ANumero: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS VALOR FROM CONTA_PAGAR ' +
      'WHERE FORNECEDOR_ID = :FORN AND DESCRICAO CONTAINING :NUM';
    LQuery.ParamByName('FORN').AsLargeInt := AFornecedorId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.Open;
    Result := LQuery.FieldByName('VALOR').AsInteger;
    LQuery.Close;
  end;

  function SomaContasPagar(AFornecedorId: Int64;
    const ANumero: string): Double;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(VALOR), 0) AS NUMERIC(18,4)) AS VALOR ' +
      'FROM CONTA_PAGAR WHERE FORNECEDOR_ID = :FORN ' +
      'AND DESCRICAO CONTAINING :NUM';
    LQuery.ParamByName('FORN').AsLargeInt := AFornecedorId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.Open;
    Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function ContarContasReceber(ANotaId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS VALOR FROM CONTA_RECEBER WHERE NOTA_SAIDA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    Result := LQuery.FieldByName('VALOR').AsInteger;
    LQuery.Close;
  end;

  function SomaContasReceber(ANotaId: Int64): Double;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(VALOR), 0) AS NUMERIC(18,4)) AS VALOR ' +
      'FROM CONTA_RECEBER WHERE NOTA_SAIDA_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := ANotaId;
    LQuery.Open;
    Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  // ------------------------------------------------------------------
  // Nota de entrada
  // ------------------------------------------------------------------

  procedure TestEntradaCriarDoPedidoCompra;
  var
    LMaterialComFiscalId, LMaterialSemFiscalId: Int64;
    LPedidoId, LNotaId: Int64;
    LNumero: string;
  begin
    try
      LMaterialComFiscalId := InserirMaterial(
        'MATERIAL FISCAL ENTRADA ' + LSufixo, LFiscalId, 10, True);
      LMaterialSemFiscalId := InserirMaterial(
        'MATERIAL SEM FISCAL ENTRADA ' + LSufixo, 0, 5, False);
      LNumero := NovoNumero('PC');
      LPedidoId := InserirPedidoCompra(LFornecedorId, LNumero, 'ABERTO');
      InserirItemPedidoCompra(LPedidoId, LMaterialComFiscalId, 2, 10, 0);
      InserirItemPedidoCompra(LPedidoId, LMaterialSemFiscalId, 3, 5, 0);

      LNotaId := LEntrada.CriarDoPedidoCompra(LPedidoId);

      AssertTrue(LNotaId > 0, 'a nota de entrada deve ser criada');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'a nota deve nascer Aberta');
      AssertEquals(IntToStr(LFornecedorId), IntToStr(IntPorId(
        'SELECT FORNECEDOR_ID AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID',
        LNotaId)), 'o fornecedor deve ser copiado do pedido');
      AssertEquals(LNumero, TextoPorId(
        'SELECT NUMERO AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'o número deve ser copiado do pedido');
      AssertEquals('55', TextoPorId(
        'SELECT MODELO AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'o modelo deve ser 55');
      AssertEquals('1', TextoPorId(
        'SELECT SERIE AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'a série deve ser 1');
      AssertEquals('1102', TextoPorId(
        'SELECT CFOP AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'o CFOP de compra deve ser 1102');
      AssertTrue(QuaseIgual(35, FloatPorId(
        'SELECT VALOR_PRODUTOS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID',
        LNotaId)), 'o valor dos produtos deve ser 2*10 + 3*5');
      AssertTrue(QuaseIgual(35, FloatPorId(
        'SELECT VALOR_TOTAL AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID',
        LNotaId)), 'o total deve ser 35');
      AssertEquals('2', IntToStr(LEntrada.QuantidadeItens(LNotaId)),
        'a nota deve receber os dois itens do pedido');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT MATERIAL_ID, PRODUTO_FISCAL_ID, NCM, CFOP, CST_ICMS, ' +
        '  ALIQ_ICMS, VALOR_TOTAL, ATUALIZA_ESTOQUE ' +
        'FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID ORDER BY ID';
      LQuery.ParamByName('ID').AsLargeInt := LNotaId;
      LQuery.Open;
      AssertFalse(LQuery.IsEmpty, 'o primeiro item deve existir');
      AssertEquals(IntToStr(LMaterialComFiscalId),
        IntToStr(LQuery.FieldByName('MATERIAL_ID').AsLargeInt),
        'o primeiro item deve ser o material com fiscal');
      AssertEquals(IntToStr(LFiscalId),
        IntToStr(LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt),
        'o vínculo fiscal do material deve ser copiado');
      AssertEquals('12345678', Trim(LQuery.FieldByName('NCM').AsString),
        'o NCM deve vir do PRODUTO_FISCAL');
      AssertEquals('1102', Trim(LQuery.FieldByName('CFOP').AsString),
        'o CFOP de compra deve vir do PRODUTO_FISCAL');
      AssertEquals('00', Trim(LQuery.FieldByName('CST_ICMS').AsString),
        'o CST deve vir do PRODUTO_FISCAL');
      AssertTrue(QuaseIgual(18, LQuery.FieldByName('ALIQ_ICMS').AsFloat),
        'a alíquota deve vir do PRODUTO_FISCAL');
      AssertTrue(QuaseIgual(20, LQuery.FieldByName('VALOR_TOTAL').AsFloat),
        'o total do primeiro item deve ser 2*10');
      AssertEquals('S', Trim(LQuery.FieldByName('ATUALIZA_ESTOQUE').AsString),
        'material com controle de estoque deve atualizar o saldo');

      LQuery.Next;
      AssertFalse(LQuery.EOF, 'o segundo item deve existir');
      AssertEquals(IntToStr(LMaterialSemFiscalId),
        IntToStr(LQuery.FieldByName('MATERIAL_ID').AsLargeInt),
        'o segundo item deve ser o material sem fiscal');
      AssertEquals('0',
        IntToStr(LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt),
        'material sem vínculo fiscal deve ficar com PRODUTO_FISCAL_ID nulo');
      AssertEquals('', Trim(LQuery.FieldByName('NCM').AsString),
        'sem vínculo fiscal o NCM fica vazio');
      AssertEquals('1102', Trim(LQuery.FieldByName('CFOP').AsString),
        'sem vínculo fiscal o CFOP de compra é o padrão');
      AssertTrue(QuaseIgual(15, LQuery.FieldByName('VALOR_TOTAL').AsFloat),
        'o total do segundo item deve ser 3*5');
      AssertEquals('N', Trim(LQuery.FieldByName('ATUALIZA_ESTOQUE').AsString),
        'material sem controle de estoque não deve movimentar saldo');
      LQuery.Close;

      AssertEquals('CONFIRMADO', TextoPorId(
        'SELECT STATUS AS VALOR FROM PEDIDO_COMPRA WHERE ID = :ID', LPedidoId),
        'o pedido deve ficar Confirmado');
      AssertEquals(IntToStr(LNotaId), IntToStr(IntPorId(
        'SELECT NOTA_ENTRADA_ID AS VALOR FROM PEDIDO_COMPRA WHERE ID = :ID',
        LPedidoId)), 'o pedido deve apontar para a nota gerada');
      AssertEquals('1', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM LOG_SISTEMA WHERE TABELA = ''NOTA_ENTRADA'' ' +
        'AND OPERACAO = ''I'' AND REGISTRO_ID = :ID', LNotaId)),
        'a criação deve gerar auditoria');

      ASuite.AddResult('TestEntradaCriarDoPedidoCompra', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCriarDoPedidoCompra', False, E.Message);
    end;
  end;

  procedure TestEntradaCriarPedidoInexistente;
  var
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LDeu := False;
      LMensagem := '';
      try
        LEntrada.CriarDoPedidoCompra(999999999);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'pedido inexistente deve ser recusado');
      AssertTrue(Pos('não encontrado', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar pedido não encontrado');
      ASuite.AddResult('TestEntradaCriarPedidoInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCriarPedidoInexistente', False, E.Message);
    end;
  end;

  procedure TestEntradaCriarPedidoCancelado;
  var
    LPedidoId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LPedidoId := InserirPedidoCompra(LFornecedorId, NovoNumero('PC'),
        'CANCELADO');
      LDeu := False;
      LMensagem := '';
      try
        LEntrada.CriarDoPedidoCompra(LPedidoId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'pedido cancelado não deve gerar nota');
      AssertTrue(Pos('cancelado', LowerCase(LMensagem)) > 0,
        'a mensagem deve citar o pedido cancelado');
      ASuite.AddResult('TestEntradaCriarPedidoCancelado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCriarPedidoCancelado', False, E.Message);
    end;
  end;

  procedure TestEntradaCriarPedidoSemItens;
  var
    LPedidoId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LPedidoId := InserirPedidoCompra(LFornecedorId, NovoNumero('PC'),
        'ABERTO');
      LDeu := False;
      LMensagem := '';
      try
        LEntrada.CriarDoPedidoCompra(LPedidoId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'pedido sem itens não deve gerar nota');
      AssertTrue(Pos('não possui itens', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar que o pedido não tem itens');
      ASuite.AddResult('TestEntradaCriarPedidoSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCriarPedidoSemItens', False, E.Message);
    end;
  end;

  procedure TestEntradaCriarPedidoJaFaturado;
  var
    LMaterialId, LPedidoId, LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LMaterialId := InserirMaterial('MATERIAL JA FATURADO ' + LSufixo,
        LFiscalId, 1, True);
      LPedidoId := InserirPedidoCompra(LFornecedorId, NovoNumero('PC'),
        'ABERTO');
      InserirItemPedidoCompra(LPedidoId, LMaterialId, 1, 1, 0);
      LNotaId := LEntrada.CriarDoPedidoCompra(LPedidoId);
      AssertTrue(LNotaId > 0, 'a primeira nota deve ser criada');

      LDeu := False;
      LMensagem := '';
      try
        LEntrada.CriarDoPedidoCompra(LPedidoId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'o mesmo pedido não deve gerar duas notas');
      AssertTrue(Pos('já gerou', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar que o pedido já gerou nota');
      AssertEquals('1', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM NOTA_ENTRADA WHERE NUMERO = ' +
        '(SELECT NUMERO FROM PEDIDO_COMPRA WHERE ID = :ID)', LPedidoId)),
        'só pode existir uma nota para o pedido');
      ASuite.AddResult('TestEntradaCriarPedidoJaFaturado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCriarPedidoJaFaturado', False, E.Message);
    end;
  end;

  procedure TestEntradaProcessarProduto;
  var
    LProdutoId, LNotaId: Int64;
    LNumero, LMensagem: string;
    LDeu: Boolean;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO ENTRADA ' + LSufixo, LFiscalId,
        10, 20, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 10);
      LNumero := NovoNumero('NE');
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id, LNumero);
      InserirItemNotaEntrada(LNotaId, LProdutoId, 0,
        'ITEM PRODUTO ENTRADA ' + LSufixo, 5, 20, True);
      LEntrada.RecalcularTotais(LNotaId);
      LConexao.Confirmar;

      LEntrada.Processar(LNotaId);

      AssertEquals('P', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'a nota deve ficar Processada');
      AssertTrue(QuaseIgual(15, FloatPorId(
        'SELECT QUANTIDADE AS VALOR FROM ESTOQUE WHERE PRODUTO_ID = :ID',
        LProdutoId)), 'o saldo deve passar de 10 para 15');
      AssertTrue(QuaseIgual(13.3333, FloatPorId(
        'SELECT CUSTO_MEDIO AS VALOR FROM ESTOQUE WHERE PRODUTO_ID = :ID',
        LProdutoId)), 'o custo médio deve ser (10*10 + 5*20) / 15');
      AssertTrue(QuaseIgual(13.3333, FloatPorId(
        'SELECT PRECO_CUSTO AS VALOR FROM PRODUTO WHERE ID = :ID',
        LProdutoId)), 'o preço de custo do produto deve ser atualizado');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT TIPO, QUANTIDADE, CUSTO_UNITARIO, DOCUMENTO ' +
        'FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID = :ID ORDER BY ID';
      LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
      LQuery.Open;
      AssertFalse(LQuery.IsEmpty, 'deve existir movimento de estoque');
      AssertEquals('E', Trim(LQuery.FieldByName('TIPO').AsString),
        'o movimento deve ser de entrada');
      AssertTrue(QuaseIgual(5, LQuery.FieldByName('QUANTIDADE').AsFloat),
        'a quantidade do movimento deve ser 5');
      AssertTrue(QuaseIgual(20, LQuery.FieldByName('CUSTO_UNITARIO').AsFloat),
        'o custo do movimento deve ser o valor unitário da nota');
      AssertTrue(Pos(LNumero, LQuery.FieldByName('DOCUMENTO').AsString) > 0,
        'o documento do movimento deve citar o número da nota');
      LQuery.Close;

      AssertEquals('1', IntToStr(ContarContasPagar(LFornecedorId, LNumero)),
        'deve ser gerada uma conta a pagar');
      AssertTrue(QuaseIgual(100, SomaContasPagar(LFornecedorId, LNumero)),
        'o total das contas a pagar deve ser 5*20');

      LDeu := False;
      LMensagem := '';
      try
        LEntrada.Processar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'a nota já processada não deve ser processada de novo');
      AssertTrue(Pos('Aberta', LMensagem) > 0,
        'a mensagem deve exigir status Aberta');
      ASuite.AddResult('TestEntradaProcessarProduto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaProcessarProduto', False, E.Message);
    end;
  end;

  procedure TestEntradaProcessarMaterial;
  var
    LMaterialId, LNotaId: Int64;
    LNumero: string;
    LDataBase: TDateTime;
    LIndice: Integer;
  begin
    try
      LMaterialId := InserirMaterial('MATERIAL ENTRADA ' + LSufixo,
        LFiscalId, 1, True);
      InserirEstoqueMaterial(LMaterialId, 2);
      LNumero := NovoNumero('NE');
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao3Id, LNumero);
      InserirItemNotaEntrada(LNotaId, 0, LMaterialId,
        'ITEM MATERIAL ENTRADA ' + LSufixo, 3, 4, True);
      LEntrada.RecalcularTotais(LNotaId);
      LConexao.Confirmar;

      LEntrada.Processar(LNotaId);

      AssertEquals('P', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'a nota deve ficar Processada');
      AssertTrue(QuaseIgual(5, FloatPorId(
        'SELECT QUANTIDADE AS VALOR FROM ESTOQUE_MATERIAL WHERE MATERIAL_ID = :ID',
        LMaterialId)), 'o saldo do material deve passar de 2 para 5');
      AssertTrue(QuaseIgual(4, FloatPorId(
        'SELECT PRECO_CUSTO AS VALOR FROM MATERIAL WHERE ID = :ID',
        LMaterialId)), 'o último custo da compra deve ir para o material');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT TIPO, QUANTIDADE, SALDO_ANTERIOR, SALDO_POSTERIOR, ' +
        '  CUSTO_UNITARIO, ORIGEM, DOCUMENTO_ID ' +
        'FROM MOVIMENTO_MATERIAL WHERE MATERIAL_ID = :ID ORDER BY ID';
      LQuery.ParamByName('ID').AsLargeInt := LMaterialId;
      LQuery.Open;
      AssertFalse(LQuery.IsEmpty, 'deve existir movimento de material');
      AssertEquals('E', Trim(LQuery.FieldByName('TIPO').AsString),
        'o movimento deve ser de entrada');
      AssertTrue(QuaseIgual(3, LQuery.FieldByName('QUANTIDADE').AsFloat),
        'a quantidade do movimento deve ser 3');
      AssertTrue(QuaseIgual(2, LQuery.FieldByName('SALDO_ANTERIOR').AsFloat),
        'o saldo anterior deve ser 2');
      AssertTrue(QuaseIgual(5, LQuery.FieldByName('SALDO_POSTERIOR').AsFloat),
        'o saldo posterior deve ser 5');
      AssertTrue(QuaseIgual(4, LQuery.FieldByName('CUSTO_UNITARIO').AsFloat),
        'o custo unitário deve ser 4');
      AssertEquals('NOTA_ENTRADA', Trim(LQuery.FieldByName('ORIGEM').AsString),
        'a origem do movimento deve ser NOTA_ENTRADA');
      AssertEquals(IntToStr(LNotaId),
        IntToStr(LQuery.FieldByName('DOCUMENTO_ID').AsLargeInt),
        'o movimento deve apontar para a nota');
      LQuery.Close;

      AssertEquals('3', IntToStr(ContarContasPagar(LFornecedorId, LNumero)),
        'a condição 3x deve gerar três parcelas');
      AssertTrue(QuaseIgual(12, SomaContasPagar(LFornecedorId, LNumero)),
        'a soma das parcelas deve ser o total da nota');

      LQuery.Close;
      LQuery.SQL.Text := 'SELECT DATA_ENTRADA FROM NOTA_ENTRADA WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LNotaId;
      LQuery.Open;
      LDataBase := LQuery.FieldByName('DATA_ENTRADA').AsDateTime;
      LQuery.Close;

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT DATA_VENCIMENTO, PARCELA FROM CONTA_PAGAR ' +
        'WHERE FORNECEDOR_ID = :FORN AND DESCRICAO CONTAINING :NUM ' +
        'ORDER BY PARCELA';
      LQuery.ParamByName('FORN').AsLargeInt := LFornecedorId;
      LQuery.ParamByName('NUM').AsString := LNumero;
      LQuery.Open;
      LIndice := 1;
      while not LQuery.EOF do
      begin
        AssertEquals(IntToStr(LIndice),
          IntToStr(LQuery.FieldByName('PARCELA').AsInteger),
          'as parcelas devem ser numeradas em ordem');
        AssertEquals(FormatDateTime('yyyy-mm-dd',
          IncDay(LDataBase, LIndice * 30)),
          FormatDateTime('yyyy-mm-dd',
          LQuery.FieldByName('DATA_VENCIMENTO').AsDateTime),
          'o vencimento deve respeitar o intervalo de 30 dias');
        Inc(LIndice);
        LQuery.Next;
      end;
      AssertEquals('4', IntToStr(LIndice),
        'devem existir exatamente três parcelas');
      LQuery.Close;

      ASuite.AddResult('TestEntradaProcessarMaterial', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaProcessarMaterial', False, E.Message);
    end;
  end;

  procedure TestEntradaProcessarSemItens;
  var
    LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id,
        NovoNumero('NE'));
      LDeu := False;
      LMensagem := '';
      try
        LEntrada.Processar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota sem itens não deve ser processada');
      AssertTrue(Pos('não possui itens', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar que a nota não tem itens');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'o status deve continuar Aberta após o rollback');
      ASuite.AddResult('TestEntradaProcessarSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaProcessarSemItens', False, E.Message);
    end;
  end;

  procedure TestEntradaProcessarItemSemVinculo;
  var
    LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id,
        NovoNumero('NE'));
      InserirItemNotaEntrada(LNotaId, 0, 0,
        'ITEM SEM VINCULO ENTRADA ' + LSufixo, 1, 10, True);
      LDeu := False;
      LMensagem := '';
      try
        LEntrada.Processar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'item sem produto nem material não deve ser processado');
      AssertTrue(Pos('não está ligado', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar o item sem vínculo');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'o status deve continuar Aberta após o rollback');
      ASuite.AddResult('TestEntradaProcessarItemSemVinculo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaProcessarItemSemVinculo', False, E.Message);
    end;
  end;

  procedure TestEntradaProcessarInexistente;
  var
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LDeu := False;
      LMensagem := '';
      try
        LEntrada.Processar(999999999);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota inexistente deve ser recusada');
      AssertTrue(Pos('não encontrada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar nota não encontrada');
      ASuite.AddResult('TestEntradaProcessarInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaProcessarInexistente', False, E.Message);
    end;
  end;

  procedure TestEntradaCancelarAberta;
  var
    LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id,
        NovoNumero('NE'));
      LEntrada.Cancelar(LNotaId);
      AssertEquals('C', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'a nota Aberta deve ser cancelada');

      LDeu := False;
      LMensagem := '';
      try
        LEntrada.Cancelar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'não deve ser possível cancelar duas vezes');
      AssertTrue(Pos('já está cancelada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar que a nota já está cancelada');
      ASuite.AddResult('TestEntradaCancelarAberta', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCancelarAberta', False, E.Message);
    end;
  end;

  procedure TestEntradaCancelarProcessada;
  var
    LProdutoId, LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO CANCELAMENTO ENTRADA ' + LSufixo,
        0, 5, 9, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 5);
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id,
        NovoNumero('NE'));
      InserirItemNotaEntrada(LNotaId, LProdutoId, 0,
        'ITEM CANCELAMENTO ENTRADA ' + LSufixo, 1, 5, True);
      LEntrada.Processar(LNotaId);

      LDeu := False;
      LMensagem := '';
      try
        LEntrada.Cancelar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota processada não deve ser cancelada');
      AssertTrue(Pos('já foi processada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar que a nota já foi processada');
      AssertEquals('P', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID', LNotaId),
        'o status deve continuar Processada');
      ASuite.AddResult('TestEntradaCancelarProcessada', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCancelarProcessada', False, E.Message);
    end;
  end;

  procedure TestEntradaExcluirItem;
  var
    LProdutoA, LProdutoB, LNotaId, LItemId: Int64;
  begin
    try
      LProdutoA := InserirProduto('PRODUTO EXCLUIR A ' + LSufixo, 0,
        1, 2, '', '', '', '', 0);
      LProdutoB := InserirProduto('PRODUTO EXCLUIR B ' + LSufixo, 0,
        1, 2, '', '', '', '', 0);
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id,
        NovoNumero('NE'));
      InserirItemNotaEntrada(LNotaId, LProdutoA, 0,
        'ITEM EXCLUIR A ' + LSufixo, 2, 10, True);
      InserirItemNotaEntrada(LNotaId, LProdutoB, 0,
        'ITEM EXCLUIR B ' + LSufixo, 3, 5, True);

      LItemId := IntPorId(
        'SELECT FIRST 1 ID AS VALOR FROM NOTA_ENTRADA_ITEM ' +
        'WHERE NOTA_ENTRADA_ID = :ID ORDER BY ID', LNotaId);
      LEntrada.ExcluirItem(LItemId);
      AssertEquals('1', IntToStr(LEntrada.QuantidadeItens(LNotaId)),
        'deve restar apenas um item');

      LEntrada.RecalcularTotais(LNotaId);
      LConexao.Confirmar;
      AssertTrue(QuaseIgual(15, FloatPorId(
        'SELECT VALOR_PRODUTOS AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID',
        LNotaId)), 'o valor dos produtos deve ser recalculado para 3*5');
      AssertTrue(QuaseIgual(15, FloatPorId(
        'SELECT VALOR_TOTAL AS VALOR FROM NOTA_ENTRADA WHERE ID = :ID',
        LNotaId)), 'o total deve ser recalculado para 15');
      ASuite.AddResult('TestEntradaExcluirItem', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaExcluirItem', False, E.Message);
    end;
  end;

  procedure TestEntradaPrimeiroItemSemProduto;
  var
    LProdutoId, LNotaId, LOutraNotaId: Int64;
    LDescricao: string;
  begin
    try
      LDescricao := 'ITEM SEM VINCULO PRIMEIRO ' + LSufixo;
      LNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id,
        NovoNumero('NE'));
      InserirItemNotaEntrada(LNotaId, 0, 0, LDescricao, 1, 1, True);
      InserirItemNotaEntrada(LNotaId, 0, 0,
        'ITEM SEM ESTOQUE ' + LSufixo, 1, 1, False);
      AssertEquals(LDescricao, LEntrada.PrimeiroItemSemProduto(LNotaId),
        'deve retornar o primeiro item sem vínculo que movimenta estoque');

      LProdutoId := InserirProduto('PRODUTO COM VINCULO ' + LSufixo, 0,
        1, 2, '', '', '', '', 0);
      LOutraNotaId := InserirNotaEntrada(LFornecedorId, LCondicao1Id,
        NovoNumero('NE'));
      InserirItemNotaEntrada(LOutraNotaId, LProdutoId, 0,
        'ITEM COM PRODUTO ' + LSufixo, 1, 2, True);
      AssertEquals('', LEntrada.PrimeiroItemSemProduto(LOutraNotaId),
        'nota com todos os itens vinculados deve retornar vazio');
      ASuite.AddResult('TestEntradaPrimeiroItemSemProduto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaPrimeiroItemSemProduto', False, E.Message);
    end;
  end;

  procedure TestEntradaCarregarFiscalDoProduto;
  var
    LComFiscal, LSemFiscal: Int64;
    LFiscalProdutoId: Int64;
    LNcm, LCfop, LCst: string;
    LAliq: Double;
  begin
    try
      LComFiscal := InserirProduto('PRODUTO FISCAL VINCULADO ' + LSufixo,
        LFiscalId, 1, 2, '', '', '', '', 0);
      LSemFiscal := InserirProduto('PRODUTO FISCAL PROPRIO ' + LSufixo,
        0, 1, 2, '87654321', '1101', '5101', '10', 12);

      LEntrada.CarregarFiscalDoProduto(LComFiscal, LFiscalProdutoId,
        LNcm, LCfop, LCst, LAliq);
      AssertEquals(IntToStr(LFiscalId), IntToStr(LFiscalProdutoId),
        'o vínculo fiscal deve ser retornado');
      AssertEquals('12345678', LNcm, 'o NCM deve vir do PRODUTO_FISCAL');
      AssertEquals('1102', LCfop, 'o CFOP de compra deve vir do PRODUTO_FISCAL');
      AssertEquals('00', LCst, 'o CST deve vir do PRODUTO_FISCAL');
      AssertTrue(QuaseIgual(18, LAliq), 'a alíquota deve vir do PRODUTO_FISCAL');

      LEntrada.CarregarFiscalDoProduto(LSemFiscal, LFiscalProdutoId,
        LNcm, LCfop, LCst, LAliq);
      AssertEquals('0', IntToStr(LFiscalProdutoId),
        'produto sem vínculo deve retornar PRODUTO_FISCAL_ID zero');
      AssertEquals('87654321', LNcm, 'o NCM deve cair para o cadastro do produto');
      AssertEquals('1101', LCfop, 'o CFOP deve cair para o cadastro do produto');
      AssertEquals('10', LCst, 'o CST deve cair para o cadastro do produto');
      AssertTrue(QuaseIgual(12, LAliq), 'a alíquota deve cair para o produto');

      LEntrada.CarregarFiscalDoProduto(0, LFiscalProdutoId,
        LNcm, LCfop, LCst, LAliq);
      AssertEquals('0', IntToStr(LFiscalProdutoId),
        'produto zero deve retornar PRODUTO_FISCAL_ID zero');
      AssertEquals('', LNcm, 'produto zero deve retornar NCM vazio');
      AssertEquals('', LCfop, 'produto zero deve retornar CFOP vazio');
      AssertEquals('', LCst, 'produto zero deve retornar CST vazio');
      AssertTrue(QuaseIgual(0, LAliq), 'produto zero deve retornar alíquota zero');

      ASuite.AddResult('TestEntradaCarregarFiscalDoProduto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEntradaCarregarFiscalDoProduto', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Nota de saída
  // ------------------------------------------------------------------

  procedure TestSaidaCriarDoPedido;
  var
    LProdutoComFiscal, LProdutoSemFiscal, LPedidoId, LNotaId: Int64;
    LNumero: string;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoComFiscal := InserirProduto('PRODUTO SAIDA FISCAL ' + LSufixo,
        LFiscalId, 10, 20, '', '', '', '', 0);
      LProdutoSemFiscal := InserirProduto('PRODUTO SAIDA PROPRIO ' + LSufixo,
        0, 5, 9, '87654321', '1101', '5101', '10', 12);
      LNumero := NovoNumero('PV');
      LPedidoId := InserirPedidoVenda(LClienteId, LCondicao1Id, LNumero, 'A');
      InserirItemPedido(LPedidoId, LProdutoComFiscal, 2, 20, 0, '');
      InserirItemPedido(LPedidoId, LProdutoSemFiscal, 1, 9, 0, '');

      LNotaId := LSaida.CriarDoPedido(LPedidoId);

      AssertTrue(LNotaId > 0, 'a nota de saída deve ser criada');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'a nota deve nascer Aberta');
      AssertEquals(IntToStr(LClienteId), IntToStr(IntPorId(
        'SELECT CLIENTE_ID AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId)),
        'o cliente deve ser copiado do pedido');
      AssertEquals(IntToStr(LPedidoId), IntToStr(IntPorId(
        'SELECT PEDIDO_VENDA_ID AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId)), 'o pedido de venda deve ser vinculado');
      AssertEquals('1', TextoPorId(
        'SELECT SERIE AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'a série deve ser 1');
      AssertEquals('55', TextoPorId(
        'SELECT MODELO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'o modelo deve ser 55');
      AssertEquals('5102', TextoPorId(
        'SELECT CFOP AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'o CFOP de venda deve ser 5102');
      AssertTrue(QuaseIgual(49, FloatPorId(
        'SELECT VALOR_PRODUTOS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId)), 'o valor dos produtos deve ser 2*20 + 1*9');
      AssertTrue(QuaseIgual(49, FloatPorId(
        'SELECT VALOR_TOTAL AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId)), 'o total deve ser 49');
      AssertEquals(IntToStr(LNotaId), IntToStr(LSaida.NotaDoPedido(LPedidoId)),
        'NotaDoPedido deve localizar a nota ativa');
      AssertEquals('2', IntToStr(LSaida.QuantidadeItens(LNotaId)),
        'a nota deve receber os dois itens do pedido');
      AssertEquals('', LSaida.PrimeiroItemSemProduto(LNotaId),
        'todos os itens têm produto');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT PRODUTO_ID, PRODUTO_FISCAL_ID, NCM, CFOP, CST_ICMS, ' +
        '  ALIQ_ICMS, VALOR_TOTAL FROM NOTA_SAIDA_ITEM ' +
        'WHERE NOTA_SAIDA_ID = :ID ORDER BY ID';
      LQuery.ParamByName('ID').AsLargeInt := LNotaId;
      LQuery.Open;
      AssertFalse(LQuery.IsEmpty, 'o primeiro item deve existir');
      AssertEquals(IntToStr(LProdutoComFiscal),
        IntToStr(LQuery.FieldByName('PRODUTO_ID').AsLargeInt),
        'o primeiro item deve ser o produto com fiscal');
      AssertEquals(IntToStr(LFiscalId),
        IntToStr(LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt),
        'o vínculo fiscal do produto deve ser copiado');
      AssertEquals('12345678', Trim(LQuery.FieldByName('NCM').AsString),
        'o NCM deve vir do PRODUTO_FISCAL');
      AssertEquals('5102', Trim(LQuery.FieldByName('CFOP').AsString),
        'o CFOP deve vir do PRODUTO_FISCAL');
      AssertEquals('00', Trim(LQuery.FieldByName('CST_ICMS').AsString),
        'o CST deve vir do PRODUTO_FISCAL');
      AssertTrue(QuaseIgual(18, LQuery.FieldByName('ALIQ_ICMS').AsFloat),
        'a alíquota deve vir do PRODUTO_FISCAL');
      AssertTrue(QuaseIgual(40, LQuery.FieldByName('VALOR_TOTAL').AsFloat),
        'o total do primeiro item deve ser 2*20');

      LQuery.Next;
      AssertFalse(LQuery.EOF, 'o segundo item deve existir');
      AssertEquals(IntToStr(LProdutoSemFiscal),
        IntToStr(LQuery.FieldByName('PRODUTO_ID').AsLargeInt),
        'o segundo item deve ser o produto sem fiscal');
      AssertEquals('0',
        IntToStr(LQuery.FieldByName('PRODUTO_FISCAL_ID').AsLargeInt),
        'produto sem vínculo deve ficar com PRODUTO_FISCAL_ID nulo');
      AssertEquals('87654321', Trim(LQuery.FieldByName('NCM').AsString),
        'sem vínculo o NCM deve cair para o cadastro do produto');
      AssertEquals('5101', Trim(LQuery.FieldByName('CFOP').AsString),
        'sem vínculo o CFOP deve cair para o cadastro do produto');
      AssertEquals('10', Trim(LQuery.FieldByName('CST_ICMS').AsString),
        'sem vínculo o CST deve cair para o cadastro do produto');
      AssertTrue(QuaseIgual(12, LQuery.FieldByName('ALIQ_ICMS').AsFloat),
        'sem vínculo a alíquota deve cair para o cadastro do produto');
      AssertTrue(QuaseIgual(9, LQuery.FieldByName('VALOR_TOTAL').AsFloat),
        'o total do segundo item deve ser 1*9');
      LQuery.Close;

      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID', LPedidoId),
        'o pedido continua Aberto até o faturamento');

      LDeu := False;
      LMensagem := '';
      try
        LSaida.CriarDoPedido(LPedidoId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'o pedido não deve gerar duas notas ativas');
      AssertTrue(Pos('já possui uma nota', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar que o pedido já possui nota');
      ASuite.AddResult('TestSaidaCriarDoPedido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCriarDoPedido', False, E.Message);
    end;
  end;

  procedure TestSaidaCriarPedidoInexistente;
  var
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LDeu := False;
      LMensagem := '';
      try
        LSaida.CriarDoPedido(999999999);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'pedido de venda inexistente deve ser recusado');
      AssertTrue(Pos('não encontrado', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar pedido não encontrado');
      ASuite.AddResult('TestSaidaCriarPedidoInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCriarPedidoInexistente', False, E.Message);
    end;
  end;

  procedure TestSaidaCriarPedidoFaturado;
  var
    LPedidoId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LPedidoId := InserirPedidoVenda(LClienteId, LCondicao1Id,
        NovoNumero('PV'), 'F');
      LDeu := False;
      LMensagem := '';
      try
        LSaida.CriarDoPedido(LPedidoId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'pedido já faturado não deve gerar nota');
      AssertTrue(Pos('já está faturado', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar pedido faturado');
      ASuite.AddResult('TestSaidaCriarPedidoFaturado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCriarPedidoFaturado', False, E.Message);
    end;
  end;

  procedure TestSaidaCriarPedidoCancelado;
  var
    LPedidoId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LPedidoId := InserirPedidoVenda(LClienteId, LCondicao1Id,
        NovoNumero('PV'), 'C');
      LDeu := False;
      LMensagem := '';
      try
        LSaida.CriarDoPedido(LPedidoId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'pedido cancelado não deve gerar nota');
      AssertTrue(Pos('já está faturado ou cancelado', LowerCase(LMensagem)) > 0,
        'a mensagem deve citar faturado ou cancelado');
      ASuite.AddResult('TestSaidaCriarPedidoCancelado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCriarPedidoCancelado', False, E.Message);
    end;
  end;

  procedure TestSaidaCriarPedidoSemItens;
  var
    LPedidoId, LNotaId: Int64;
  begin
    try
      LPedidoId := InserirPedidoVenda(LClienteId, LCondicao1Id,
        NovoNumero('PV'), 'A');
      LNotaId := LSaida.CriarDoPedido(LPedidoId);
      AssertTrue(LNotaId > 0, 'a nota deve ser criada mesmo sem itens');
      AssertEquals('0', IntToStr(LSaida.QuantidadeItens(LNotaId)),
        'a nota deve ficar sem itens');
      AssertTrue(QuaseIgual(0, FloatPorId(
        'SELECT VALOR_TOTAL AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId)),
        'o total deve ficar zerado');
      ASuite.AddResult('TestSaidaCriarPedidoSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCriarPedidoSemItens', False, E.Message);
    end;
  end;

  procedure TestSaidaVerificarSaldo;
  var
    LProdutoId, LNotaOk, LNotaSemSaldo, LNotaSemEstoque: Int64;
    LDescricao: string;
    LDisponivel, LSolicitado: Double;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO SALDO SAIDA ' + LSufixo, 0,
        5, 9, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 5);

      LNotaOk := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(700000 + LSeq));
      InserirItemNotaSaida(LNotaOk, LProdutoId,
        'ITEM SALDO OK ' + LSufixo, 5, 9, True);
      AssertTrue(LSaida.VerificarSaldo(LNotaOk, LDescricao, LDisponivel,
        LSolicitado), 'saldo 10 atende a quantidade 5');

      LNotaSemSaldo := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(700000 + LSeq));
      InserirItemNotaSaida(LNotaSemSaldo, LProdutoId,
        'ITEM SALDO INSUFICIENTE ' + LSufixo, 15, 9, True);
      AssertFalse(LSaida.VerificarSaldo(LNotaSemSaldo, LDescricao,
        LDisponivel, LSolicitado), 'saldo 10 não atende a quantidade 15');
      AssertEquals('ITEM SALDO INSUFICIENTE ' + LSufixo, LDescricao,
        'a descrição do item sem saldo deve ser retornada');
      AssertTrue(QuaseIgual(10, LDisponivel),
        'o disponível deve ser o saldo atual');
      AssertTrue(QuaseIgual(15, LSolicitado),
        'o solicitado deve ser a quantidade do item');

      LNotaSemEstoque := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(700000 + LSeq));
      InserirItemNotaSaida(LNotaSemEstoque, LProdutoId,
        'ITEM SEM ESTOQUE ' + LSufixo, 999, 9, False);
      AssertTrue(LSaida.VerificarSaldo(LNotaSemEstoque, LDescricao,
        LDisponivel, LSolicitado),
        'item que não movimenta estoque não precisa de saldo');

      ASuite.AddResult('TestSaidaVerificarSaldo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaVerificarSaldo', False, E.Message);
    end;
  end;

  procedure TestSaidaAtualizarCabecalho;
  var
    LProdutoId, LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO CABECALHO ' + LSufixo, 0,
        5, 9, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 5);
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(710000 + LSeq));
      InserirItemNotaSaida(LNotaId, LProdutoId,
        'ITEM CABECALHO ' + LSufixo, 2, 10, True);

      LSaida.AtualizarCabecalho(LNotaId, LClienteId, 'NUM CAB', '2', '55',
        'VENDA TESTE', '5102', EncodeDate(2026, 1, 10),
        EncodeDate(2026, 1, 11), LCondicao1Id, 5, 2, 3);

      AssertEquals('NUM CAB', TextoPorId(
        'SELECT NUMERO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'o número deve ser atualizado');
      AssertEquals('2', TextoPorId(
        'SELECT SERIE AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'a série deve ser atualizada');
      AssertEquals('VENDA TESTE', TextoPorId(
        'SELECT NATUREZA_OPERACAO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId), 'a natureza deve ser atualizada');
      AssertTrue(QuaseIgual(20, FloatPorId(
        'SELECT VALOR_PRODUTOS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId)), 'o valor dos produtos deve ser 2*10');
      AssertTrue(QuaseIgual(30, FloatPorId(
        'SELECT VALOR_TOTAL AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId)), 'o total deve somar frete, seguro e outras despesas');

      LSaida.Faturar(LNotaId);

      LDeu := False;
      LMensagem := '';
      try
        LSaida.AtualizarCabecalho(LNotaId, LClienteId, 'OUTRO', '1', '55',
          'OUTRA', '5102', Date, Date, LCondicao1Id, 0, 0, 0);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota faturada não deve ser alterada');
      AssertTrue(Pos('abertas', LowerCase(LMensagem)) > 0,
        'a mensagem deve exigir nota aberta');

      LDeu := False;
      LMensagem := '';
      try
        LSaida.AtualizarCabecalho(LNotaId, 0, 'OUTRO', '1', '55',
          'OUTRA', '5102', Date, Date, LCondicao1Id, 0, 0, 0);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'cliente zero deve ser recusado');
      AssertTrue(Pos('informe o cliente', LowerCase(LMensagem)) > 0,
        'a mensagem deve exigir o cliente');

      ASuite.AddResult('TestSaidaAtualizarCabecalho', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaAtualizarCabecalho', False, E.Message);
    end;
  end;

  procedure TestSaidaChaveAcesso;
  var
    LNotaId: Int64;
    LChave, LBase: string;
    LIndice, LPeso, LSoma, LDig: Integer;
    LSoDigitos: Boolean;
  begin
    try
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0, '123');
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE NOTA_SAIDA SET DATA_EMISSAO = :DATA, SERIE = ''7'', ' +
        '  MODELO = ''55'' WHERE ID = :ID';
      LQuery.ParamByName('DATA').AsDate := EncodeDate(2026, 1, 15);
      LQuery.ParamByName('ID').AsLargeInt := LNotaId;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      LChave := LSaida.GerarChaveAcesso(LNotaId);

      AssertEquals('44', IntToStr(Length(LChave)),
        'a chave de acesso deve ter 44 dígitos');
      LSoDigitos := True;
      for LIndice := 1 to Length(LChave) do
        if not (LChave[LIndice] in ['0'..'9']) then
          LSoDigitos := False;
      AssertTrue(LSoDigitos, 'a chave deve conter apenas dígitos');
      AssertEquals('2601', Copy(LChave, 3, 4),
        'o AAMM deve vir da data de emissão');
      AssertEquals('55', Copy(LChave, 21, 2),
        'o modelo deve ocupar duas posições');
      AssertEquals('007', Copy(LChave, 23, 3),
        'a série deve ser preenchida com zeros à esquerda');
      AssertEquals('000000123', Copy(LChave, 26, 9),
        'o número deve ser preenchido com zeros à esquerda');

      LBase := Copy(LChave, 1, 43);
      LSoma := 0;
      LPeso := 2;
      for LIndice := Length(LBase) downto 1 do
      begin
        LSoma := LSoma + (Ord(LBase[LIndice]) - Ord('0')) * LPeso;
        Inc(LPeso);
        if LPeso > 9 then
          LPeso := 2;
      end;
      LDig := 11 - (LSoma mod 11);
      if LDig >= 10 then
        LDig := 0;
      AssertEquals(IntToStr(LDig), Copy(LChave, 44, 1),
        'o dígito verificador deve ser o módulo 11 da NF-e');

      ASuite.AddResult('TestSaidaChaveAcesso', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaChaveAcesso', False, E.Message);
    end;
  end;

  procedure TestSaidaFaturar;
  var
    LProdutoId, LPedidoId, LNotaId: Int64;
    LNumero, LChave: string;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO FATURAR ' + LSufixo, 0,
        10, 25, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 10);
      LNumero := NovoNumero('PV');
      LPedidoId := InserirPedidoVenda(LClienteId, LCondicao1Id, LNumero, 'A');
      InserirItemPedido(LPedidoId, LProdutoId, 4, 25, 0, '');
      LNotaId := LSaida.CriarDoPedido(LPedidoId);

      LSaida.Faturar(LNotaId);

      AssertEquals('P', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'a nota deve ficar Processada');
      AssertTrue(QuaseIgual(6, FloatPorId(
        'SELECT QUANTIDADE AS VALOR FROM ESTOQUE WHERE PRODUTO_ID = :ID',
        LProdutoId)), 'o saldo deve cair de 10 para 6');
      AssertTrue(QuaseIgual(6, FloatPorId(
        'SELECT SALDO_APOS AS VALOR FROM NOTA_SAIDA_ITEM WHERE NOTA_SAIDA_ID = :ID',
        LNotaId)), 'o saldo após o item deve ser 6');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT TIPO, QUANTIDADE, CUSTO_UNITARIO, DOCUMENTO ' +
        'FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID = :ID ORDER BY ID';
      LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
      LQuery.Open;
      AssertFalse(LQuery.IsEmpty, 'deve existir movimento de saída');
      AssertEquals('S', Trim(LQuery.FieldByName('TIPO').AsString),
        'o movimento deve ser de saída');
      AssertTrue(QuaseIgual(4, LQuery.FieldByName('QUANTIDADE').AsFloat),
        'a quantidade do movimento deve ser 4');
      AssertTrue(QuaseIgual(10, LQuery.FieldByName('CUSTO_UNITARIO').AsFloat),
        'o custo deve ser o custo médio do estoque');
      AssertTrue(Pos('NF SAIDA', LQuery.FieldByName('DOCUMENTO').AsString) > 0,
        'o documento deve identificar a nota de saída');
      LQuery.Close;

      AssertEquals('1', IntToStr(ContarContasReceber(LNotaId)),
        'deve ser gerada uma conta a receber');
      AssertTrue(QuaseIgual(100, SomaContasReceber(LNotaId)),
        'o total a receber deve ser 4*25');

      LChave := TextoPorId(
        'SELECT CHAVE_ACESSO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId);
      AssertEquals('44', IntToStr(Length(LChave)),
        'a chave de acesso deve ser gravada com 44 dígitos');
      AssertEquals('HOM', Copy(TextoPorId(
        'SELECT PROTOCOLO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        1, 3), 'o protocolo de homologação deve ser gravado');

      AssertEquals('F', TextoPorId(
        'SELECT STATUS AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID', LPedidoId),
        'o pedido deve ficar Faturado');
      AssertEquals(TextoPorId(
        'SELECT NUMERO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        IntToStr(IntPorId(
        'SELECT NUMERO_NFE AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID',
        LPedidoId)), 'o pedido deve receber o número da NF-e');
      AssertEquals(LChave, TextoPorId(
        'SELECT CHAVE_NFE AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID',
        LPedidoId), 'o pedido deve receber a chave da NF-e');

      LDeu := False;
      LMensagem := '';
      try
        LSaida.Faturar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'a nota já faturada não deve ser faturada de novo');
      AssertTrue(Pos('já foi faturada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar nota já faturada');

      ASuite.AddResult('TestSaidaFaturar', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaFaturar', False, E.Message);
    end;
  end;

  procedure TestSaidaFaturarSemCliente;
  var
    LProdutoId, LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO SEM CLIENTE ' + LSufixo, 0,
        5, 9, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 5);
      LNotaId := InserirNotaSaida(0, LCondicao1Id, 0,
        IntToStr(720000 + LSeq));
      InserirItemNotaSaida(LNotaId, LProdutoId,
        'ITEM SEM CLIENTE ' + LSufixo, 1, 9, True);

      LDeu := False;
      LMensagem := '';
      try
        LSaida.Faturar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota sem cliente não deve ser faturada');
      AssertTrue(Pos('informe o cliente', LowerCase(LMensagem)) > 0,
        'a mensagem deve exigir o cliente');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'o status deve continuar Aberta');
      ASuite.AddResult('TestSaidaFaturarSemCliente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaFaturarSemCliente', False, E.Message);
    end;
  end;

  procedure TestSaidaFaturarSemItens;
  var
    LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(730000 + LSeq));
      LDeu := False;
      LMensagem := '';
      try
        LSaida.Faturar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota sem itens não deve ser faturada');
      AssertTrue(Pos('não possui itens', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar que a nota não tem itens');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'o status deve continuar Aberta');
      ASuite.AddResult('TestSaidaFaturarSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaFaturarSemItens', False, E.Message);
    end;
  end;

  procedure TestSaidaFaturarEstoqueInsuficiente;
  var
    LProdutoId, LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO ESTOQUE BAIXO ' + LSufixo, 0,
        5, 9, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 1, 5);
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(740000 + LSeq));
      InserirItemNotaSaida(LNotaId, LProdutoId,
        'ITEM ESTOQUE BAIXO ' + LSufixo, 5, 9, True);

      LDeu := False;
      LMensagem := '';
      try
        LSaida.Faturar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'estoque insuficiente deve impedir o faturamento');
      AssertTrue(Pos('estoque insuficiente', LowerCase(LMensagem)) > 0,
        'a mensagem deve citar estoque insuficiente');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'o status deve continuar Aberta');
      AssertTrue(QuaseIgual(1, FloatPorId(
        'SELECT QUANTIDADE AS VALOR FROM ESTOQUE WHERE PRODUTO_ID = :ID',
        LProdutoId)), 'o saldo não deve ser alterado');
      AssertEquals('0', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM MOVIMENTO_ESTOQUE ' +
        'WHERE PRODUTO_ID = :ID', LProdutoId)),
        'nenhum movimento deve ser gravado');
      ASuite.AddResult('TestSaidaFaturarEstoqueInsuficiente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaFaturarEstoqueInsuficiente', False, E.Message);
    end;
  end;

  procedure TestSaidaFaturarItemSemProduto;
  var
    LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(750000 + LSeq));
      InserirItemNotaSaida(LNotaId, 0, 'ITEM SEM PRODUTO ' + LSufixo,
        1, 9, True);

      LDeu := False;
      LMensagem := '';
      try
        LSaida.Faturar(LNotaId);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'item sem produto não deve ser faturado');
      AssertTrue(Pos('não está ligado a um produto', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar o item sem produto');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'o status deve continuar Aberta');
      ASuite.AddResult('TestSaidaFaturarItemSemProduto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaFaturarItemSemProduto', False, E.Message);
    end;
  end;

  procedure TestSaidaFaturarInexistente;
  var
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LDeu := False;
      LMensagem := '';
      try
        LSaida.Faturar(999999999);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota de saída inexistente deve ser recusada');
      AssertTrue(Pos('não encontrada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar nota não encontrada');
      ASuite.AddResult('TestSaidaFaturarInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaFaturarInexistente', False, E.Message);
    end;
  end;

  procedure TestSaidaCancelarAberta;
  var
    LProdutoId, LNotaId: Int64;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO CANCELAR ABERTA ' + LSufixo, 0,
        5, 9, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 5);
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(760000 + LSeq));
      InserirItemNotaSaida(LNotaId, LProdutoId,
        'ITEM CANCELAR ABERTA ' + LSufixo, 2, 9, True);

      LSaida.Cancelar(LNotaId, 'desistência do cliente');

      AssertEquals('C', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'a nota Aberta deve ser cancelada');
      AssertEquals('desistência do cliente', TextoPorId(
        'SELECT MOTIVO_CANCELAMENTO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId), 'o motivo deve ser gravado');
      AssertEquals('1', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM NOTA_SAIDA WHERE ID = :ID ' +
        'AND DATA_CANCELAMENTO IS NOT NULL', LNotaId)),
        'a data de cancelamento deve ser gravada');
      AssertTrue(QuaseIgual(10, FloatPorId(
        'SELECT QUANTIDADE AS VALOR FROM ESTOQUE WHERE PRODUTO_ID = :ID',
        LProdutoId)), 'nota Aberta não movimenta estoque');
      AssertEquals('0', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM MOVIMENTO_ESTOQUE ' +
        'WHERE PRODUTO_ID = :ID', LProdutoId)),
        'nenhum movimento deve ser gravado no cancelamento da Aberta');

      LDeu := False;
      LMensagem := '';
      try
        LSaida.Cancelar(LNotaId, 'de novo');
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'não deve ser possível cancelar duas vezes');
      AssertTrue(Pos('já está cancelada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar nota já cancelada');
      ASuite.AddResult('TestSaidaCancelarAberta', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCancelarAberta', False, E.Message);
    end;
  end;

  procedure TestSaidaCancelarFaturada;
  var
    LProdutoId, LPedidoId, LNotaId: Int64;
    LNumero: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO ESTORNO ' + LSufixo, 0,
        10, 25, '', '', '', '', 0);
      InserirEstoque(LProdutoId, 10, 10);
      LNumero := NovoNumero('PV');
      LPedidoId := InserirPedidoVenda(LClienteId, LCondicao1Id, LNumero, 'A');
      InserirItemPedido(LPedidoId, LProdutoId, 4, 25, 0, '');
      LNotaId := LSaida.CriarDoPedido(LPedidoId);
      LSaida.Faturar(LNotaId);
      AssertTrue(QuaseIgual(6, FloatPorId(
        'SELECT QUANTIDADE AS VALOR FROM ESTOQUE WHERE PRODUTO_ID = :ID',
        LProdutoId)), 'o faturamento deve baixar o saldo para 6');

      LSaida.Cancelar(LNotaId, 'estorno teste');

      AssertEquals('C', TextoPorId(
        'SELECT STATUS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID', LNotaId),
        'a nota faturada deve ser cancelada');
      AssertTrue(QuaseIgual(10, FloatPorId(
        'SELECT QUANTIDADE AS VALOR FROM ESTOQUE WHERE PRODUTO_ID = :ID',
        LProdutoId)), 'o estorno deve devolver o saldo para 10');
      AssertEquals('1', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM MOVIMENTO_ESTOQUE ' +
        'WHERE PRODUTO_ID = :ID AND TIPO = ''E''', LProdutoId)),
        'o estorno deve gravar um movimento de entrada');
      AssertEquals('1', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM CONTA_RECEBER ' +
        'WHERE NOTA_SAIDA_ID = :ID AND STATUS = ''C''', LNotaId)),
        'as parcelas em aberto devem ser canceladas');
      AssertEquals('P', TextoPorId(
        'SELECT STATUS AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID', LPedidoId),
        'o pedido deve voltar para Pendente');
      AssertEquals('0', IntToStr(IntPorId(
        'SELECT NUMERO_NFE AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID',
        LPedidoId)), 'o número da NF-e deve ser limpo no pedido');
      AssertEquals('', TextoPorId(
        'SELECT CHAVE_NFE AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID',
        LPedidoId), 'a chave da NF-e deve ser limpa no pedido');
      AssertEquals('estorno teste', TextoPorId(
        'SELECT MOTIVO_CANCELAMENTO AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId), 'o motivo do cancelamento deve ser gravado');
      AssertEquals('1', IntToStr(IntPorId(
        'SELECT COUNT(*) AS VALOR FROM NOTA_SAIDA WHERE ID = :ID ' +
        'AND DATA_CANCELAMENTO IS NOT NULL', LNotaId)),
        'a data de cancelamento deve ser gravada');
      ASuite.AddResult('TestSaidaCancelarFaturada', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCancelarFaturada', False, E.Message);
    end;
  end;

  procedure TestSaidaCancelarInexistente;
  var
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LDeu := False;
      LMensagem := '';
      try
        LSaida.Cancelar(999999999, 'teste');
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'nota de saída inexistente deve ser recusada');
      AssertTrue(Pos('não encontrada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar nota não encontrada');
      ASuite.AddResult('TestSaidaCancelarInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaCancelarInexistente', False, E.Message);
    end;
  end;

  procedure TestSaidaExcluirItem;
  var
    LProdutoA, LProdutoB, LNotaId, LItemId: Int64;
  begin
    try
      LProdutoA := InserirProduto('PRODUTO SAIDA EXCLUIR A ' + LSufixo, 0,
        1, 2, '', '', '', '', 0);
      LProdutoB := InserirProduto('PRODUTO SAIDA EXCLUIR B ' + LSufixo, 0,
        1, 2, '', '', '', '', 0);
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0,
        IntToStr(770000 + LSeq));
      InserirItemNotaSaida(LNotaId, LProdutoA,
        'ITEM SAIDA EXCLUIR A ' + LSufixo, 2, 10, True);
      InserirItemNotaSaida(LNotaId, LProdutoB,
        'ITEM SAIDA EXCLUIR B ' + LSufixo, 3, 5, True);

      LItemId := IntPorId(
        'SELECT FIRST 1 ID AS VALOR FROM NOTA_SAIDA_ITEM ' +
        'WHERE NOTA_SAIDA_ID = :ID ORDER BY ID', LNotaId);
      LSaida.ExcluirItem(LItemId);
      AssertEquals('1', IntToStr(LSaida.QuantidadeItens(LNotaId)),
        'deve restar apenas um item');

      LSaida.RecalcularTotais(LNotaId);
      LConexao.Confirmar;
      AssertTrue(QuaseIgual(15, FloatPorId(
        'SELECT VALOR_PRODUTOS AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId)), 'o valor dos produtos deve ser recalculado para 3*5');
      AssertTrue(QuaseIgual(15, FloatPorId(
        'SELECT VALOR_TOTAL AS VALOR FROM NOTA_SAIDA WHERE ID = :ID',
        LNotaId)), 'o total deve ser recalculado para 15');
      ASuite.AddResult('TestSaidaExcluirItem', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaExcluirItem', False, E.Message);
    end;
  end;

  procedure TestSaidaGerarXML;
  var
    LProdutoId, LNotaId: Int64;
    LXml, LNumero: string;
    LDeu: Boolean;
    LMensagem: string;
  begin
    try
      LProdutoId := InserirProduto('PRODUTO XML ' + LSufixo, 0,
        5, 10, '', '', '', '', 0);
      LNumero := IntToStr(780000 + LSeq);
      LNotaId := InserirNotaSaida(LClienteId, LCondicao1Id, 0, LNumero);
      InserirItemNotaSaida(LNotaId, LProdutoId,
        'ITEM XML ' + LSufixo, 2, 10, True);
      LSaida.RecalcularTotais(LNotaId);
      LConexao.Confirmar;

      LXml := LSaida.GerarXML(LNotaId);

      AssertTrue(Pos('<?xml', LXml) = 1, 'o XML deve começar com a declaração');
      AssertTrue(Pos('<nfeProc', LXml) > 0, 'o XML deve conter o nó nfeProc');
      AssertTrue(Pos('<nNF>' + LNumero + '</nNF>', LXml) > 0,
        'o XML deve conter o número da nota');
      AssertTrue(Pos('ITEM XML ' + LSufixo, LXml) > 0,
        'o XML deve conter a descrição do item');
      AssertTrue(Pos('<vNF>20.00</vNF>', LXml) > 0,
        'o XML deve conter o total da nota');
      AssertTrue(Pos('CLIENTE NF TESTE ' + LSufixo, LXml) > 0,
        'o XML deve conter o nome do cliente');

      LDeu := False;
      LMensagem := '';
      try
        LSaida.GerarXML(999999999);
      except
        on E: Exception do
        begin
          LDeu := True;
          LMensagem := E.Message;
        end;
      end;
      AssertTrue(LDeu, 'XML de nota inexistente deve ser recusado');
      AssertTrue(Pos('não encontrada', LowerCase(LMensagem)) > 0,
        'a mensagem deve indicar nota não encontrada');

      ASuite.AddResult('TestSaidaGerarXML', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSaidaGerarXML', False, E.Message);
    end;
  end;



begin
  LConexao := TConexao.GetInstance;
  LSessao := TSessao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LEntrada := TNotaEntradaService.Create;
  LSaida := TNotaSaidaService.Create;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LClienteId := 0;
  LFornecedorId := 0;
  LCondicao3Id := 0;
  LCondicao1Id := 0;
  LFiscalId := 0;
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    LTopoLog := 0;
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM LOG_SISTEMA ORDER BY ID DESC';
    LQuery.Open;
    if not LQuery.IsEmpty then
      LTopoLog := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DAS NOTAS FISCAIS');
    WriteLn('========================================');

    LClienteId := InserirPessoa('C', 'CLIENTE NF TESTE ' + LSufixo);
    LFornecedorId := InserirPessoa('F', 'FORNECEDOR NF TESTE ' + LSufixo);
    LFiscalId := InserirProdutoFiscal('PRODUTO FISCAL NF TESTE ' + LSufixo);
    LCondicao3Id := InserirCondicao('CONDICAO 3X NF TESTE ' + LSufixo, 3, 30);
    LCondicao1Id := InserirCondicao('CONDICAO 1X NF TESTE ' + LSufixo, 1, 0);

    TestEntradaCriarDoPedidoCompra;
    TestEntradaCriarPedidoInexistente;
    TestEntradaCriarPedidoCancelado;
    TestEntradaCriarPedidoSemItens;
    TestEntradaCriarPedidoJaFaturado;
    TestEntradaProcessarProduto;
    TestEntradaProcessarMaterial;
    TestEntradaProcessarSemItens;
    TestEntradaProcessarItemSemVinculo;
    TestEntradaProcessarInexistente;
    TestEntradaCancelarAberta;
    TestEntradaCancelarProcessada;
    TestEntradaExcluirItem;
    TestEntradaPrimeiroItemSemProduto;
    TestEntradaCarregarFiscalDoProduto;

    TestSaidaCriarDoPedido;
    TestSaidaCriarPedidoInexistente;
    TestSaidaCriarPedidoFaturado;
    TestSaidaCriarPedidoCancelado;
    TestSaidaCriarPedidoSemItens;
    TestSaidaVerificarSaldo;
    TestSaidaAtualizarCabecalho;
    TestSaidaChaveAcesso;
    TestSaidaFaturar;
    TestSaidaFaturarSemCliente;
    TestSaidaFaturarSemItens;
    TestSaidaFaturarEstoqueInsuficiente;
    TestSaidaFaturarItemSemProduto;
    TestSaidaFaturarInexistente;
    TestSaidaCancelarAberta;
    TestSaidaCancelarFaturada;
    TestSaidaCancelarInexistente;
    TestSaidaExcluirItem;
    TestSaidaGerarXML;
  finally
    LimparSobraPorSufixo;
    LSaida.Free;
    LEntrada.Free;
    LQuery.Free;
  end;
end;

end.
