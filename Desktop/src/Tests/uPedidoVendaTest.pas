unit uPedidoVendaTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do pedido de venda
  ------------------------------------------------------------
  Cobre TPedidoVendaService (extraído de uFrmPedidoVenda):

    - totais: item = quantidade * valor - desconto (nunca
      negativo) e pedido = subtotal - desconto (nunca negativo);
    - numeração: maior NUMERO numérico da empresa + 1, ignorando
      textos como "PV-TESTE-5" e pedidos de outra empresa;
    - gravação: cabeçalho (empresa, cliente, usuário, status 'P',
      subtotal, desconto, total, forma/condição, observações e
      entrega opcionais) e itens (PRECO_UNITARIO e VALOR_UNITARIO,
      CFOP padrão 5102) na MESMA transação, com auditoria INSERT;
    - grade: a quantidade do item passa a ser a soma das
      quantidades por tamanho e a grade efetiva é gravada em
      ITEM_PEDIDO_GRADE;
    - validações: cliente ativo tipo 'C' da empresa, pelo menos um
      item, produto da empresa, quantidade > 0, valores não
      negativos, CFOP até 5, observações até 255, número até 20 e
      status de 1 caractere.

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uGrade, uPedidoVendaService;

type
  { TPedidoVendaTest }
  TPedidoVendaTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TPedidoVendaTest }

class procedure TPedidoVendaTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LPedido: TPedidoVendaService;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;
  LCliente: Int64;
  LClienteInativo: Int64;
  LClienteFornecedor: Int64;
  LClienteOutraEmpresa: Int64;
  LProdutoA: Int64;
  LProdutoB: Int64;
  LProdutoOutraEmpresa: Int64;

  function QuaseIgual(A, B: Double): Boolean;
  begin
    Result := Abs(A - B) < 0.001;
  end;

  function NovoNome(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  function NovoDocumento: string;
  begin
    Inc(LSeq);
    Result := Copy(LSufixo, 1, 14) + IntToStr(LSeq);
  end;

  function CriarPessoa(const ANome, ATipo, AAtivo: string;
    AEmpresaId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, ' +
      '  ATIVO, DATA_CADASTRO) ' +
      'VALUES (:EMP, :TIPO, ''F'', :NOME, :DOC, :ATIVO, CURRENT_TIMESTAMP) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('NOME').AsString := ANome;
    LQuery.ParamByName('DOC').AsString := NovoDocumento;
    LQuery.ParamByName('ATIVO').AsString := AAtivo;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function CriarProduto(const ADescricao: string; AEmpresaId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
      '  DESCRICAO, PRECO_CUSTO, PRECO_VENDA, CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, 1, 1, :COD, :DESC, 1, 2, ''S'', ''A'') RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('COD').AsString := 'PED' + Copy(LSufixo, 1, 12) +
      IntToStr(LSeq);
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function ItemSimples(AProdutoId: Int64; AQtd, AVlr, ADesc: Double;
    const ACfop: string): TItemPedidoEntrada;
  begin
    Result.ProdutoId := AProdutoId;
    Result.Quantidade := AQtd;
    Result.ValorUnitario := AVlr;
    Result.Desconto := ADesc;
    Result.Cfop := ACfop;
    Result.Tamanhos := nil;
  end;

  function ItemComGrade(AProdutoId: Int64; AVlr, AQtd1, AQtd2: Double):
    TItemPedidoEntrada;
  begin
    Result := ItemSimples(AProdutoId, 0, AVlr, 0, '5102');
    SetLength(Result.Tamanhos, 2);
    Result.Tamanhos[0].Tamanho := 'P';
    Result.Tamanhos[0].Ordem := 0;
    Result.Tamanhos[0].Quantidade := AQtd1;
    Result.Tamanhos[0].Ativo := 'A';
    Result.Tamanhos[1].Tamanho := 'M';
    Result.Tamanhos[1].Ordem := 1;
    Result.Tamanhos[1].Quantidade := AQtd2;
    Result.Tamanhos[1].Ativo := 'A';
  end;

  function TextoPedido(const ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(1000)) AS VALOR ' +
      'FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function FloatPedido(const ACampo: string; AId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function DataPedido(const ACampo: string; AId: Int64): TDateTime;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsDateTime;
    LQuery.Close;
  end;

  function NuloPedido(const ACampo: string; AId: Int64): Boolean;
  begin
    Result := False;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').IsNull;
    LQuery.Close;
  end;

  function PrimeiroItem(AId: Int64): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = :PED ' +
      'ORDER BY ID';
    LQuery.ParamByName('PED').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  end;

  function TextoItem(const ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(1000)) AS VALOR ' +
      'FROM ITEM_PEDIDO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function FloatItem(const ACampo: string; AId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM ITEM_PEDIDO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function ContarGrade(AItemId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM ITEM_PEDIDO_GRADE WHERE ITEM_PEDIDO_ID = :ITEM';
    LQuery.ParamByName('ITEM').AsLargeInt := AItemId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function SomaGrade(AItemId: Int64): Double;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(QUANTIDADE), 0) AS NUMERIC(15,4)) AS VALOR ' +
      'FROM ITEM_PEDIDO_GRADE WHERE ITEM_PEDIDO_ID = :ITEM';
    LQuery.ParamByName('ITEM').AsLargeInt := AItemId;
    LQuery.Open;
    Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function ContarLog(AId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM LOG_SISTEMA WHERE TABELA = ''PEDIDO_VENDA'' ' +
      '  AND OPERACAO = ''INSERT'' AND REGISTRO_ID = :REG';
    LQuery.ParamByName('REG').AsLargeInt := AId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function InserirPedidoDireto(AEmpresaId, AClienteId: Int64;
    const ANumero: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, ' +
      '  NUMERO, STATUS, SUBTOTAL, DESCONTO, TOTAL) ' +
      'VALUES (:EMP, :CLI, :USR, :NUM, ''P'', 0, 0, 0) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function RecusouSalvar(AClienteId: Int64;
    const AItens: TItensPedidoEntrada; ADesconto: Double;
    const ANumero, AObs, AStatus: string): Boolean;
  begin
    Result := False;
    try
      LPedido.SalvarPedido(AClienteId, ANumero, AItens, ADesconto, 0, 0,
        AObs, AStatus);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  // ------------------------------------------------------------------
  // Totais
  // ------------------------------------------------------------------

  procedure TestTotais;
  begin
    try
      AssertTrue(QuaseIgual(19, TotalItemPedido(2, 10, 1)),
        'item: 2 * 10 - 1 = 19');
      AssertTrue(QuaseIgual(0, TotalItemPedido(2, 10, 25)),
        'desconto maior que o valor zera o item');
      AssertTrue(QuaseIgual(7, TotalDoPedidoVenda(10, 3)),
        'pedido: 10 - 3 = 7');
      AssertTrue(QuaseIgual(0, TotalDoPedidoVenda(10, 15)),
        'desconto maior que o subtotal zera o pedido');

      ASuite.AddResult('TestPedidoTotais', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoTotais', False, E.Message);
    end;
  end;

  procedure TestTotaisDosItensNoService;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 2);
      LItens[0] := ItemSimples(LProdutoA, 2, 10, 1, '5102');   // 19
      LItens[1] := ItemComGrade(LProdutoB, 5, 2, 3);           // 5 * 5 = 25

      AssertTrue(QuaseIgual(44, LPedido.SubtotalDosItens(LItens)),
        'subtotal deve somar os itens (inclusive pela grade)');
      AssertTrue(QuaseIgual(40, LPedido.TotalDoPedido(LItens, 4)),
        'total do pedido deve descontar do subtotal');

      ASuite.AddResult('TestPedidoTotaisDosItensNoService', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoTotaisDosItensNoService', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Gravação
  // ------------------------------------------------------------------

  procedure TestSalvarPedidoCompleto;
  var
    LId, LItemId: Int64;
    LItens: TItensPedidoEntrada;
    LNumero: string;
  begin
    try
      LNumero := 'T' + Copy(LSufixo, 1, 12);
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 2, 10, 1, '');
      LId := LPedido.SalvarPedido(LCliente, LNumero, LItens, 0, 0, 0,
        'OBS ' + LSufixo, 'P');

      AssertTrue(LId > 0, 'SalvarPedido deve devolver o ID');
      AssertEquals(LNumero, TextoPedido('NUMERO', LId),
        'o número informado deve ser gravado');
      AssertEquals('P', TextoPedido('STATUS', LId),
        'o status deve ser gravado');
      AssertEquals(IntToStr(LSessao.EmpresaId), TextoPedido('EMPRESA_ID', LId),
        'o pedido deve pertencer à empresa da sessão');
      AssertEquals(IntToStr(LCliente), TextoPedido('CLIENTE_ID', LId),
        'o cliente deve ser gravado');
      AssertEquals(IntToStr(LSessao.UsuarioId), TextoPedido('USUARIO_ID', LId),
        'o usuário da sessão deve ser gravado');
      AssertTrue(QuaseIgual(19, FloatPedido('SUBTOTAL', LId)),
        'o subtotal deve ser calculado pelos itens');
      AssertTrue(QuaseIgual(0, FloatPedido('DESCONTO', LId)),
        'o desconto do pedido deve ser gravado');
      AssertTrue(QuaseIgual(19, FloatPedido('TOTAL', LId)),
        'o total deve ser calculado');
      AssertEquals('OBS ' + LSufixo, TextoPedido('OBSERVACOES', LId),
        'as observações devem ser gravadas');
      AssertFalse(DataPedido('DATA_EMISSAO', LId) = 0,
        'a data de emissão deve ser preenchida pela trigger');
      AssertTrue(ContarLog(LId) = 1, 'o pedido deve gerar auditoria INSERT');
      AssertEquals('1', IntToStr(LPedido.QuantidadeItens(LId)),
        'o pedido deve ter um item');

      LItemId := PrimeiroItem(LId);
      AssertTrue(LItemId > 0, 'o item deve ser gravado');
      AssertEquals(IntToStr(LProdutoA), TextoItem('PRODUTO_ID', LItemId),
        'o produto do item deve ser gravado');
      AssertTrue(QuaseIgual(2, FloatItem('QUANTIDADE', LItemId)),
        'a quantidade do item deve ser gravada');
      AssertTrue(QuaseIgual(10, FloatItem('PRECO_UNITARIO', LItemId)),
        'o preço unitário deve ser gravado');
      AssertTrue(QuaseIgual(10, FloatItem('VALOR_UNITARIO', LItemId)),
        'o valor unitário deve ser gravado');
      AssertTrue(QuaseIgual(1, FloatItem('DESCONTO', LItemId)),
        'o desconto do item deve ser gravado');
      AssertTrue(QuaseIgual(19, FloatItem('VALOR_TOTAL', LItemId)),
        'o total do item deve ser calculado');
      AssertEquals('5102', TextoItem('CFOP', LItemId),
        'o CFOP vazio deve usar o padrão 5102');
      AssertTrue(ContarGrade(LItemId) = 0,
        'item sem grade não deve gravar ITEM_PEDIDO_GRADE');

      ASuite.AddResult('TestPedidoSalvarCompleto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoSalvarCompleto', False, E.Message);
    end;
  end;

  procedure TestNumeroAutomatico;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
    LBase: Integer;
  begin
    try
      LBase := LPedido.ProximoNumero;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');

      LId := LPedido.SalvarPedido(LCliente, '', LItens, 0);
      AssertEquals(IntToStr(LBase), TextoPedido('NUMERO', LId),
        'número vazio deve usar o próximo número');

      LId := LPedido.SalvarPedido(LCliente, '0', LItens, 0);
      AssertEquals(IntToStr(LBase + 1), TextoPedido('NUMERO', LId),
        'número "0" também deve usar o próximo número');

      ASuite.AddResult('TestPedidoNumeroAutomatico', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoNumeroAutomatico', False, E.Message);
    end;
  end;

  procedure TestProximoNumeroIgnoraTexto;
  var
    LItens: TItensPedidoEntrada;
    LBase: Integer;
    LId: Int64;
  begin
    try
      LBase := LPedido.ProximoNumero;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');

      LId := LPedido.SalvarPedido(LCliente, IntToStr(LBase), LItens, 0);
      AssertEquals(IntToStr(LBase), TextoPedido('NUMERO', LId),
        'o número numérico deve ser gravado');
      AssertTrue(LPedido.ProximoNumero = LBase + 1,
        'o próximo número deve avançar após o numérico');

      LId := LPedido.SalvarPedido(LCliente,
        'PV-' + Copy(LSufixo, 1, 10), LItens, 0);
      AssertTrue(LId > 0, 'pedido com número texto deve ser aceito');
      AssertTrue(LPedido.ProximoNumero = LBase + 1,
        'número texto não pode entrar na numeração');

      ASuite.AddResult('TestPedidoProximoNumeroIgnoraTexto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoProximoNumeroIgnoraTexto', False, E.Message);
    end;
  end;

  procedure TestProximoNumeroPorEmpresa;
  var
    LBase: Integer;
  begin
    try
      LBase := LPedido.ProximoNumero;
      InserirPedidoDireto(999999, LClienteOutraEmpresa, '987654');
      AssertTrue(LPedido.ProximoNumero = LBase,
        'pedido de outra empresa não pode entrar na numeração');

      ASuite.AddResult('TestPedidoProximoNumeroPorEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoProximoNumeroPorEmpresa', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoComGrade;
  var
    LId, LItemId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      { quantidade 99 é ignorada: com grade vale a soma dos tamanhos }
      LItens[0] := ItemComGrade(LProdutoA, 10, 2, 3);
      LItens[0].Quantidade := 99;
      LId := LPedido.SalvarPedido(LCliente, 'G' + Copy(LSufixo, 1, 12),
        LItens, 0);

      LItemId := PrimeiroItem(LId);
      AssertTrue(QuaseIgual(5, FloatItem('QUANTIDADE', LItemId)),
        'a quantidade do item deve ser a soma da grade');
      AssertTrue(QuaseIgual(50, FloatItem('VALOR_TOTAL', LItemId)),
        'o total do item deve usar a quantidade da grade');
      AssertTrue(QuaseIgual(50, FloatPedido('SUBTOTAL', LId)),
        'o subtotal do pedido deve usar a quantidade da grade');
      AssertEquals('2', IntToStr(ContarGrade(LItemId)),
        'a grade efetiva deve ser gravada');
      AssertTrue(QuaseIgual(5, SomaGrade(LItemId)),
        'a soma dos tamanhos gravados deve ser 5');

      ASuite.AddResult('TestPedidoSalvarComGrade', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoSalvarComGrade', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoMultiplosItens;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 2);
      LItens[0] := ItemSimples(LProdutoA, 2, 10, 2, '5102');  // 18
      LItens[1] := ItemSimples(LProdutoB, 1, 5, 0, '6102');   // 5
      LId := LPedido.SalvarPedido(LCliente, 'M' + Copy(LSufixo, 1, 12),
        LItens, 3);

      AssertTrue(QuaseIgual(23, FloatPedido('SUBTOTAL', LId)),
        'o subtotal deve somar os dois itens');
      AssertTrue(QuaseIgual(3, FloatPedido('DESCONTO', LId)),
        'o desconto do pedido deve ser gravado');
      AssertTrue(QuaseIgual(20, FloatPedido('TOTAL', LId)),
        'o total deve descontar o valor do pedido');
      AssertEquals('2', IntToStr(LPedido.QuantidadeItens(LId)),
        'o pedido deve ter dois itens');

      ASuite.AddResult('TestPedidoSalvarMultiplosItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoSalvarMultiplosItens', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoDescontoMaior;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      LId := LPedido.SalvarPedido(LCliente, 'D' + Copy(LSufixo, 1, 12),
        LItens, 15);

      AssertTrue(QuaseIgual(10, FloatPedido('SUBTOTAL', LId)),
        'o subtotal continua sendo o dos itens');
      AssertTrue(QuaseIgual(0, FloatPedido('TOTAL', LId)),
        'o total do pedido nunca fica negativo');

      ASuite.AddResult('TestPedidoSalvarDescontoMaior', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoSalvarDescontoMaior', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoDataEntrega;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
    LEntrega: TDateTime;
  begin
    try
      LEntrega := Trunc(Now) + 5;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      LId := LPedido.SalvarPedido(LCliente, 'E' + Copy(LSufixo, 1, 12),
        LItens, 0, 0, 0, '', 'P', LEntrega);

      AssertTrue(Trunc(DataPedido('DATA_ENTREGA', LId)) = LEntrega,
        'a data de entrega deve ser gravada');

      ASuite.AddResult('TestPedidoSalvarDataEntrega', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoSalvarDataEntrega', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoSemFormaCondicao;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      LId := LPedido.SalvarPedido(LCliente, 'F' + Copy(LSufixo, 1, 12),
        LItens, 0, 0, 0);

      AssertTrue(NuloPedido('FORMA_PAGAMENTO_ID', LId),
        'forma de pagamento 0 deve ficar nula');
      AssertTrue(NuloPedido('CONDICAO_PAGAMENTO_ID', LId),
        'condição de pagamento 0 deve ficar nula');
      AssertTrue(NuloPedido('DATA_ENTREGA', LId),
        'entrega não informada deve ficar nula');

      ASuite.AddResult('TestPedidoSalvarSemFormaCondicao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoSalvarSemFormaCondicao', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoStatus;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');

      LId := LPedido.SalvarPedido(LCliente, 'S' + Copy(LSufixo, 1, 12),
        LItens, 0, 0, 0, '', '');
      AssertEquals('P', TextoPedido('STATUS', LId),
        'status vazio deve assumir P (pendente)');

      LId := LPedido.SalvarPedido(LCliente, 'A' + Copy(LSufixo, 1, 12),
        LItens, 0, 0, 0, '', 'A');
      AssertEquals('A', TextoPedido('STATUS', LId),
        'status informado deve ser gravado');

      ASuite.AddResult('TestPedidoSalvarStatus', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoSalvarStatus', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Validações
  // ------------------------------------------------------------------

  procedure TestRecusarClienteInativo;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LClienteInativo, LItens, 0, 'X', '', 'P'),
        'cliente inativo deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarClienteInativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarClienteInativo', False, E.Message);
    end;
  end;

  procedure TestRecusarClienteInexistente;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(0, LItens, 0, 'X', '', 'P'),
        'cliente 0 deve ser recusado');
      AssertTrue(RecusouSalvar(999999999, LItens, 0, 'X', '', 'P'),
        'cliente inexistente deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarClienteInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarClienteInexistente', False,
          E.Message);
    end;
  end;

  procedure TestRecusarClienteFornecedor;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LClienteFornecedor, LItens, 0, 'X', '', 'P'),
        'pessoa tipo F não pode ser cliente do pedido');

      ASuite.AddResult('TestPedidoRecusarClienteFornecedor', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarClienteFornecedor', False,
          E.Message);
    end;
  end;

  procedure TestRecusarSemItens;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      LItens := nil;
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'pedido sem itens deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarSemItens', False, E.Message);
    end;
  end;

  procedure TestRecusarProdutoInvalido;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(0, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'produto 0 deve ser recusado');

      LItens[0] := ItemSimples(999999999, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'produto inexistente deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarProdutoInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarProdutoInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRecusarProdutoOutraEmpresa;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoOutraEmpresa, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'produto de outra empresa deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarProdutoOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarProdutoOutraEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestRecusarQuantidadeInvalida;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 0, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'quantidade zero deve ser recusada');

      LItens[0] := ItemSimples(LProdutoA, -1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'quantidade negativa deve ser recusada');

      LItens[0] := ItemComGrade(LProdutoA, 10, 0, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'grade com soma zero deve ser recusada');

      ASuite.AddResult('TestPedidoRecusarQuantidadeInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarQuantidadeInvalida', False,
          E.Message);
    end;
  end;

  procedure TestRecusarValoresNegativos;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, -1, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'valor unitário negativo deve ser recusado');

      LItens[0] := ItemSimples(LProdutoA, 1, 10, -1, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'desconto negativo no item deve ser recusado');

      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, -1, 'X', '', 'P'),
        'desconto negativo no pedido deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarValoresNegativos', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarValoresNegativos', False,
          E.Message);
    end;
  end;

  procedure TestRecusarCfopLongo;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '123456');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'P'),
        'CFOP com mais de 5 caracteres deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarCfopLongo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarCfopLongo', False, E.Message);
    end;
  end;

  procedure TestRecusarObservacoesLongas;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X',
        StringOfChar('X', 256), 'P'),
        'observações com mais de 255 caracteres devem ser recusadas');

      ASuite.AddResult('TestPedidoRecusarObservacoesLongas', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarObservacoesLongas', False,
          E.Message);
    end;
  end;

  procedure TestRecusarNumeroLongo;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, StringOfChar('9', 21),
        '', 'P'),
        'número com mais de 20 caracteres deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarNumeroLongo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarNumeroLongo', False, E.Message);
    end;
  end;

  procedure TestRecusarStatusInvalido;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0, '5102');
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'PX'),
        'status com mais de 1 caractere deve ser recusado');

      ASuite.AddResult('TestPedidoRecusarStatusInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoRecusarStatusInvalido', False, E.Message);
    end;
  end;

  procedure TestQuantidadeItensInexistente;
  begin
    try
      AssertTrue(LPedido.QuantidadeItens(0) = 0,
        'pedido 0 não deve ter itens');
      AssertTrue(LPedido.QuantidadeItens(999999999) = 0,
        'pedido inexistente não deve ter itens');

      ASuite.AddResult('TestPedidoQuantidadeItensInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPedidoQuantidadeItensInexistente', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Limpeza
  // ------------------------------------------------------------------

  procedure ExecSufixo(const ASQL: string);
  begin
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName('P1').AsString := LSufixo;
    LQuery.ExecSQL;
    LConexao.Confirmar;
  end;

  procedure LimparSobraPorSufixo;
  begin
    try
      ExecSufixo(
        'DELETE FROM ITEM_PEDIDO_GRADE WHERE ITEM_PEDIDO_ID IN (' +
        '  SELECT I.ID FROM ITEM_PEDIDO I ' +
        '  JOIN PEDIDO_VENDA P ON P.ID = I.PEDIDO_VENDA_ID ' +
        '  JOIN PESSOA C ON C.ID = P.CLIENTE_ID ' +
        '  WHERE C.NOME CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID IN (' +
        '  SELECT P.ID FROM PEDIDO_VENDA P ' +
        '  JOIN PESSOA C ON C.ID = P.CLIENTE_ID ' +
        '  WHERE C.NOME CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM PEDIDO_VENDA WHERE CLIENTE_ID IN (' +
        '  SELECT ID FROM PESSOA WHERE NOME CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo('DELETE FROM PRODUTO WHERE DESCRICAO CONTAINING :P1');
    except
    end;
    try
      ExecSufixo('DELETE FROM PESSOA WHERE NOME CONTAINING :P1');
    except
    end;
    try
      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM LOG_SISTEMA WHERE ID > :TOPO';
      LQuery.ParamByName('TOPO').AsLargeInt := LTopoLog;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
    end;
  end;

begin
  LConexao := TConexao.GetInstance;
  LSessao := TSessao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LPedido := TPedidoVendaService.Create;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
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
    WriteLn('EXECUTANDO TESTES DE PEDIDO DE VENDA');
    WriteLn('========================================');

    LCliente := CriarPessoa(NovoNome('CLIENTE PEDIDO'), 'C', 'A',
      LSessao.EmpresaId);
    LClienteInativo := CriarPessoa(NovoNome('CLIENTE INATIVO'), 'C', 'I',
      LSessao.EmpresaId);
    LClienteFornecedor := CriarPessoa(NovoNome('FORNECEDOR PEDIDO'), 'F',
      'A', LSessao.EmpresaId);
    LClienteOutraEmpresa := CriarPessoa(NovoNome('CLIENTE OUTRA EMPRESA'),
      'C', 'A', 999999);
    LProdutoA := CriarProduto(NovoNome('PRODUTO PEDIDO A'),
      LSessao.EmpresaId);
    LProdutoB := CriarProduto(NovoNome('PRODUTO PEDIDO B'),
      LSessao.EmpresaId);
    LProdutoOutraEmpresa := CriarProduto(NovoNome('PRODUTO PEDIDO OUTRA'),
      999999);

    TestTotais;
    TestTotaisDosItensNoService;
    TestSalvarPedidoCompleto;
    TestNumeroAutomatico;
    TestProximoNumeroIgnoraTexto;
    TestProximoNumeroPorEmpresa;
    TestSalvarPedidoComGrade;
    TestSalvarPedidoMultiplosItens;
    TestSalvarPedidoDescontoMaior;
    TestSalvarPedidoDataEntrega;
    TestSalvarPedidoSemFormaCondicao;
    TestSalvarPedidoStatus;
    TestRecusarClienteInativo;
    TestRecusarClienteInexistente;
    TestRecusarClienteFornecedor;
    TestRecusarSemItens;
    TestRecusarProdutoInvalido;
    TestRecusarProdutoOutraEmpresa;
    TestRecusarQuantidadeInvalida;
    TestRecusarValoresNegativos;
    TestRecusarCfopLongo;
    TestRecusarObservacoesLongas;
    TestRecusarNumeroLongo;
    TestRecusarStatusInvalido;
    TestQuantidadeItensInexistente;
  finally
    LimparSobraPorSufixo;
    LPedido.Free;
    LQuery.Free;
  end;
end;

end.
