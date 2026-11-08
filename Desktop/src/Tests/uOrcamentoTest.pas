unit uOrcamentoTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do orçamento
  ------------------------------------------------------------
  Cobre TOrcamentoService (extraído de uFrmOrcamento):

    - totais: item = quantidade * valor - desconto (nunca
      negativo) e pedido = subtotal - desconto (nunca negativo),
      reaproveitados do pedido de venda;
    - gravação: o orçamento é um PEDIDO_VENDA com STATUS 'O';
      cabeçalho (empresa, cliente, usuário, número, subtotal,
      desconto, total, observações e entrega opcional) e itens
      (PRECO_UNITARIO, VALOR_UNITARIO, CFOP padrão 5102) na MESMA
      transação, com auditoria INSERT;
    - numeração: maior NUMERO numérico da empresa + 1, ignorando
      textos como "ORC-TESTE-3" e orçamentos de outra empresa;
    - conversão em pedido: só orçamento da empresa com STATUS 'O'
      vira 'P'; conversão dupla e status inválido são recusados,
      com auditoria CONVERSAO;
    - validações: cliente ativo tipo 'C' da empresa, pelo menos um
      item, produto da empresa, quantidade > 0, valores não
      negativos, observações até 255 e número até 20.

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uPedidoVendaService, uOrcamentoService;

type
  { TOrcamentoTest }
  TOrcamentoTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TOrcamentoTest }

class procedure TOrcamentoTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LOrcamento: TOrcamentoService;
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
      'VALUES (:EMP, :TIPO, ''J'', :NOME, :DOC, :ATIVO, CURRENT_TIMESTAMP) ' +
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
    LQuery.ParamByName('COD').AsString := 'ORC' + Copy(LSufixo, 1, 12) +
      IntToStr(LSeq);
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function ItemSimples(AProdutoId: Int64; AQtd, AVlr, ADesc: Double):
    TItemPedidoEntrada;
  begin
    Result.ProdutoId := AProdutoId;
    Result.Quantidade := AQtd;
    Result.ValorUnitario := AVlr;
    Result.Desconto := ADesc;
    Result.Cfop := '';
    Result.Tamanhos := nil;
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

  function ContarLog(AId: Int64; const AOperacao: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM LOG_SISTEMA WHERE TABELA = ''PEDIDO_VENDA'' ' +
      '  AND OPERACAO = :OP AND REGISTRO_ID = :REG';
    LQuery.ParamByName('OP').AsString := AOperacao;
    LQuery.ParamByName('REG').AsLargeInt := AId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function InserirPedidoDireto(AEmpresaId, AClienteId: Int64;
    const ANumero, AStatus: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, ' +
      '  NUMERO, STATUS, SUBTOTAL, DESCONTO, TOTAL) ' +
      'VALUES (:EMP, :CLI, :USR, :NUM, :STS, 0, 0, 0) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.ParamByName('STS').AsString := AStatus;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function RecusouSalvar(AClienteId: Int64;
    const AItens: TItensPedidoEntrada; ADesconto: Double;
    const ANumero, AObs: string): Boolean;
  begin
    Result := False;
    try
      LOrcamento.SalvarOrcamento(AClienteId, ANumero, AItens, ADesconto,
        AObs);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouConverter(AOrcamentoId: Int64): Boolean;
  begin
    Result := False;
    try
      LOrcamento.ConverterEmPedido(AOrcamentoId);
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

      ASuite.AddResult('TestOrcamentoTotais', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoTotais', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Gravação
  // ------------------------------------------------------------------

  procedure TestSalvarOrcamentoCompleto;
  var
    LId, LItemId: Int64;
    LItens: TItensPedidoEntrada;
    LNumero: string;
  begin
    try
      LNumero := 'O' + Copy(LSufixo, 1, 12);
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 2, 10, 1);
      LId := LOrcamento.SalvarOrcamento(LCliente, LNumero, LItens, 0,
        'OBS ' + LSufixo);

      AssertTrue(LId > 0, 'SalvarOrcamento deve devolver o ID');
      AssertEquals(LNumero, TextoPedido('NUMERO', LId),
        'o número informado deve ser gravado');
      AssertEquals('O', TextoPedido('STATUS', LId),
        'o orçamento deve ser gravado com STATUS O');
      AssertEquals(IntToStr(LSessao.EmpresaId), TextoPedido('EMPRESA_ID', LId),
        'o orçamento deve pertencer à empresa da sessão');
      AssertEquals(IntToStr(LCliente), TextoPedido('CLIENTE_ID', LId),
        'o cliente deve ser gravado');
      AssertEquals(IntToStr(LSessao.UsuarioId), TextoPedido('USUARIO_ID', LId),
        'o usuário da sessão deve ser gravado');
      AssertTrue(QuaseIgual(19, FloatPedido('SUBTOTAL', LId)),
        'o subtotal deve ser calculado pelos itens');
      AssertTrue(QuaseIgual(0, FloatPedido('DESCONTO', LId)),
        'o desconto do orçamento deve ser gravado');
      AssertTrue(QuaseIgual(19, FloatPedido('TOTAL', LId)),
        'o total deve ser calculado');
      AssertEquals('OBS ' + LSufixo, TextoPedido('OBSERVACOES', LId),
        'as observações devem ser gravadas');
      AssertFalse(DataPedido('DATA_EMISSAO', LId) = 0,
        'a data de emissão deve ser preenchida pela trigger');
      AssertTrue(NuloPedido('DATA_ENTREGA', LId),
        'a entrega não informada deve ficar nula');
      AssertTrue(ContarLog(LId, 'INSERT') = 1,
        'o orçamento deve gerar auditoria INSERT');
      AssertEquals('1', IntToStr(LOrcamento.QuantidadeItens(LId)),
        'o orçamento deve ter um item');

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

      ASuite.AddResult('TestOrcamentoSalvarCompleto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoSalvarCompleto', False, E.Message);
    end;
  end;

  procedure TestNumeroAutomatico;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
    LBase: Integer;
  begin
    try
      LBase := LOrcamento.ProximoNumero;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);

      LId := LOrcamento.SalvarOrcamento(LCliente, '', LItens, 0);
      AssertEquals(IntToStr(LBase), TextoPedido('NUMERO', LId),
        'número vazio deve usar o próximo número');

      LId := LOrcamento.SalvarOrcamento(LCliente, '0', LItens, 0);
      AssertEquals(IntToStr(LBase + 1), TextoPedido('NUMERO', LId),
        'número "0" também deve usar o próximo número');

      ASuite.AddResult('TestOrcamentoNumeroAutomatico', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoNumeroAutomatico', False, E.Message);
    end;
  end;

  procedure TestProximoNumeroIgnoraTexto;
  var
    LItens: TItensPedidoEntrada;
    LBase: Integer;
    LId: Int64;
  begin
    try
      LBase := LOrcamento.ProximoNumero;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);

      LId := LOrcamento.SalvarOrcamento(LCliente, IntToStr(LBase), LItens, 0);
      AssertEquals(IntToStr(LBase), TextoPedido('NUMERO', LId),
        'o número numérico deve ser gravado');
      AssertTrue(LOrcamento.ProximoNumero = LBase + 1,
        'o próximo número deve avançar após o numérico');

      LId := LOrcamento.SalvarOrcamento(LCliente,
        'ORC-' + Copy(LSufixo, 1, 10), LItens, 0);
      AssertTrue(LId > 0, 'orçamento com número texto deve ser aceito');
      AssertTrue(LOrcamento.ProximoNumero = LBase + 1,
        'número texto não pode entrar na numeração');

      ASuite.AddResult('TestOrcamentoProximoNumeroIgnoraTexto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoProximoNumeroIgnoraTexto', False,
          E.Message);
    end;
  end;

  procedure TestProximoNumeroPorEmpresa;
  var
    LBase: Integer;
  begin
    try
      LBase := LOrcamento.ProximoNumero;
      InserirPedidoDireto(999999, LClienteOutraEmpresa, '987654', 'O');
      AssertTrue(LOrcamento.ProximoNumero = LBase,
        'orçamento de outra empresa não pode entrar na numeração');

      ASuite.AddResult('TestOrcamentoProximoNumeroPorEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoProximoNumeroPorEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestSalvarOrcamentoMultiplosItens;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 2);
      LItens[0] := ItemSimples(LProdutoA, 2, 10, 2);  // 18
      LItens[1] := ItemSimples(LProdutoB, 1, 5, 0);   // 5
      LId := LOrcamento.SalvarOrcamento(LCliente,
        'M' + Copy(LSufixo, 1, 12), LItens, 3);

      AssertTrue(QuaseIgual(23, FloatPedido('SUBTOTAL', LId)),
        'o subtotal deve somar os dois itens');
      AssertTrue(QuaseIgual(3, FloatPedido('DESCONTO', LId)),
        'o desconto do orçamento deve ser gravado');
      AssertTrue(QuaseIgual(20, FloatPedido('TOTAL', LId)),
        'o total deve descontar o valor do orçamento');
      AssertEquals('2', IntToStr(LOrcamento.QuantidadeItens(LId)),
        'o orçamento deve ter dois itens');

      ASuite.AddResult('TestOrcamentoSalvarMultiplosItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoSalvarMultiplosItens', False,
          E.Message);
    end;
  end;

  procedure TestSalvarOrcamentoDescontoMaior;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      LId := LOrcamento.SalvarOrcamento(LCliente,
        'D' + Copy(LSufixo, 1, 12), LItens, 15);

      AssertTrue(QuaseIgual(10, FloatPedido('SUBTOTAL', LId)),
        'o subtotal continua sendo o dos itens');
      AssertTrue(QuaseIgual(0, FloatPedido('TOTAL', LId)),
        'o total do orçamento nunca fica negativo');

      ASuite.AddResult('TestOrcamentoSalvarDescontoMaior', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoSalvarDescontoMaior', False,
          E.Message);
    end;
  end;

  procedure TestSalvarOrcamentoDataEntrega;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
    LEntrega: TDateTime;
  begin
    try
      LEntrega := Trunc(Now) + 10;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      LId := LOrcamento.SalvarOrcamento(LCliente,
        'E' + Copy(LSufixo, 1, 12), LItens, 0, '', LEntrega);

      AssertTrue(Trunc(DataPedido('DATA_ENTREGA', LId)) = LEntrega,
        'a data de entrega informada deve ser gravada');

      ASuite.AddResult('TestOrcamentoSalvarDataEntrega', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoSalvarDataEntrega', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Conversão em pedido
  // ------------------------------------------------------------------

  procedure TestConverterEmPedido;
  var
    LId: Int64;
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      LId := LOrcamento.SalvarOrcamento(LCliente,
        'C' + Copy(LSufixo, 1, 12), LItens, 0);

      AssertTrue(LOrcamento.ConverterEmPedido(LId),
        'orçamento aberto deve ser convertido');
      AssertEquals('P', TextoPedido('STATUS', LId),
        'a conversão deve mudar o status para P');
      AssertTrue(ContarLog(LId, 'CONVERSAO') = 1,
        'a conversão deve gerar auditoria CONVERSAO');

      AssertTrue(RecusouConverter(LId),
        'orçamento já convertido não pode ser convertido de novo');
      AssertEquals('P', TextoPedido('STATUS', LId),
        'a conversão recusada não pode alterar o status');

      ASuite.AddResult('TestOrcamentoConverterEmPedido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoConverterEmPedido', False, E.Message);
    end;
  end;

  procedure TestConverterInexistente;
  begin
    try
      AssertTrue(RecusouConverter(0),
        'orçamento 0 deve ser recusado');
      AssertTrue(RecusouConverter(999999999),
        'orçamento inexistente deve ser recusado');

      ASuite.AddResult('TestOrcamentoConverterInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoConverterInexistente', False,
          E.Message);
    end;
  end;

  procedure TestConverterOutraEmpresa;
  var
    LId: Int64;
  begin
    try
      LId := InserirPedidoDireto(999999, LClienteOutraEmpresa,
        'X' + Copy(LSufixo, 1, 12), 'O');
      AssertTrue(RecusouConverter(LId),
        'orçamento de outra empresa deve ser recusado');
      AssertEquals('O', TextoPedido('STATUS', LId),
        'a conversão recusada não pode alterar o status');

      ASuite.AddResult('TestOrcamentoConverterOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoConverterOutraEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestConverterStatusInvalido;
  var
    LCancelado, LPedido: Int64;
  begin
    try
      LCancelado := InserirPedidoDireto(LSessao.EmpresaId, LCliente,
        'K' + Copy(LSufixo, 1, 12), 'C');
      AssertTrue(RecusouConverter(LCancelado),
        'registro cancelado não pode ser convertido');
      AssertEquals('C', TextoPedido('STATUS', LCancelado),
        'a conversão recusada não pode alterar o status');

      LPedido := InserirPedidoDireto(LSessao.EmpresaId, LCliente,
        'Z' + Copy(LSufixo, 1, 12), 'P');
      AssertTrue(RecusouConverter(LPedido),
        'pedido já existente não pode ser convertido de novo');

      ASuite.AddResult('TestOrcamentoConverterStatusInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoConverterStatusInvalido', False,
          E.Message);
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
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LClienteInativo, LItens, 0, 'X', ''),
        'cliente inativo deve ser recusado');

      ASuite.AddResult('TestOrcamentoRecusarClienteInativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarClienteInativo', False,
          E.Message);
    end;
  end;

  procedure TestRecusarClienteFornecedor;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LClienteFornecedor, LItens, 0, 'X', ''),
        'pessoa tipo F não pode ser cliente do orçamento');

      ASuite.AddResult('TestOrcamentoRecusarClienteFornecedor', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarClienteFornecedor', False,
          E.Message);
    end;
  end;

  procedure TestRecusarClienteInvalido;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      AssertTrue(RecusouSalvar(0, LItens, 0, 'X', ''),
        'cliente 0 deve ser recusado');
      AssertTrue(RecusouSalvar(999999999, LItens, 0, 'X', ''),
        'cliente inexistente deve ser recusado');

      ASuite.AddResult('TestOrcamentoRecusarClienteInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarClienteInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRecusarSemItens;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      LItens := nil;
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'orçamento sem itens deve ser recusado');

      ASuite.AddResult('TestOrcamentoRecusarSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarSemItens', False, E.Message);
    end;
  end;

  procedure TestRecusarProdutoInvalido;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(0, 1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'produto 0 deve ser recusado');

      LItens[0] := ItemSimples(999999999, 1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'produto inexistente deve ser recusado');

      ASuite.AddResult('TestOrcamentoRecusarProdutoInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarProdutoInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRecusarProdutoOutraEmpresa;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoOutraEmpresa, 1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'produto de outra empresa deve ser recusado');

      ASuite.AddResult('TestOrcamentoRecusarProdutoOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarProdutoOutraEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestRecusarQuantidadeInvalida;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 0, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'quantidade zero deve ser recusada');

      LItens[0] := ItemSimples(LProdutoA, -1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'quantidade negativa deve ser recusada');

      ASuite.AddResult('TestOrcamentoRecusarQuantidadeInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarQuantidadeInvalida', False,
          E.Message);
    end;
  end;

  procedure TestRecusarValoresNegativos;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, -1, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'valor unitário negativo deve ser recusado');

      LItens[0] := ItemSimples(LProdutoA, 1, 10, -1);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', ''),
        'desconto negativo no item deve ser recusado');

      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, -1, 'X', ''),
        'desconto negativo no orçamento deve ser recusado');

      ASuite.AddResult('TestOrcamentoRecusarValoresNegativos', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarValoresNegativos', False,
          E.Message);
    end;
  end;

  procedure TestRecusarObservacoesLongas;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X',
        StringOfChar('X', 256)),
        'observações com mais de 255 caracteres devem ser recusadas');

      ASuite.AddResult('TestOrcamentoRecusarObservacoesLongas', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarObservacoesLongas', False,
          E.Message);
    end;
  end;

  procedure TestRecusarNumeroLongo;
  var
    LItens: TItensPedidoEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LProdutoA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, StringOfChar('9', 21), ''),
        'número com mais de 20 caracteres deve ser recusado');

      ASuite.AddResult('TestOrcamentoRecusarNumeroLongo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoRecusarNumeroLongo', False, E.Message);
    end;
  end;

  procedure TestQuantidadeItensInexistente;
  begin
    try
      AssertTrue(LOrcamento.QuantidadeItens(0) = 0,
        'orçamento 0 não deve ter itens');
      AssertTrue(LOrcamento.QuantidadeItens(999999999) = 0,
        'orçamento inexistente não deve ter itens');

      ASuite.AddResult('TestOrcamentoQuantidadeItensInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestOrcamentoQuantidadeItensInexistente', False,
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
  LOrcamento := TOrcamentoService.Create;
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
    WriteLn('EXECUTANDO TESTES DE ORÇAMENTO');
    WriteLn('========================================');

    LCliente := CriarPessoa(NovoNome('CLIENTE ORCAMENTO'), 'C', 'A',
      LSessao.EmpresaId);
    LClienteInativo := CriarPessoa(NovoNome('CLIENTE ORC INATIVO'), 'C', 'I',
      LSessao.EmpresaId);
    LClienteFornecedor := CriarPessoa(NovoNome('FORNECEDOR ORCAMENTO'), 'F',
      'A', LSessao.EmpresaId);
    LClienteOutraEmpresa := CriarPessoa(NovoNome('CLIENTE ORC OUTRA'), 'C',
      'A', 999999);
    LProdutoA := CriarProduto(NovoNome('PRODUTO ORCAMENTO A'),
      LSessao.EmpresaId);
    LProdutoB := CriarProduto(NovoNome('PRODUTO ORCAMENTO B'),
      LSessao.EmpresaId);
    LProdutoOutraEmpresa := CriarProduto(NovoNome('PRODUTO ORC OUTRA'),
      999999);

    TestTotais;
    TestSalvarOrcamentoCompleto;
    TestNumeroAutomatico;
    TestProximoNumeroIgnoraTexto;
    TestProximoNumeroPorEmpresa;
    TestSalvarOrcamentoMultiplosItens;
    TestSalvarOrcamentoDescontoMaior;
    TestSalvarOrcamentoDataEntrega;
    TestConverterEmPedido;
    TestConverterInexistente;
    TestConverterOutraEmpresa;
    TestConverterStatusInvalido;
    TestRecusarClienteInativo;
    TestRecusarClienteFornecedor;
    TestRecusarClienteInvalido;
    TestRecusarSemItens;
    TestRecusarProdutoInvalido;
    TestRecusarProdutoOutraEmpresa;
    TestRecusarQuantidadeInvalida;
    TestRecusarValoresNegativos;
    TestRecusarObservacoesLongas;
    TestRecusarNumeroLongo;
    TestQuantidadeItensInexistente;
  finally
    LimparSobraPorSufixo;
    LOrcamento.Free;
    LQuery.Free;
  end;
end;

end.
