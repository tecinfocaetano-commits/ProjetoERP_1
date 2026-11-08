unit uPedidoCompraTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do pedido de compra
  ------------------------------------------------------------
  Cobre TPedidoCompraService (extraído de uFrmCompras):

    - totais: item = quantidade * valor - desconto (nunca
      negativo) e pedido = subtotal - desconto (nunca negativo);
    - numeração: maior NUMERO numérico da empresa + 1, ignorando
      textos como "PC-TESTE-8" e pedidos de outra empresa;
    - gravação: cabeçalho (empresa, fornecedor, usuário, número,
      status, subtotal, desconto, total, observações e datas) e
      itens na MESMA transação, com auditoria INSERT;
    - status: ABERTO (padrão), CONFIRMADO ou CANCELADO;
    - validações: fornecedor ativo tipo 'F' da empresa, pelo menos
      um material da empresa, quantidade > 0, valores não negativos,
      observações até 500 e número até 20.

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uPedidoCompraService;

type
  { TPedidoCompraTest }
  TPedidoCompraTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TPedidoCompraTest }

class procedure TPedidoCompraTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LPedido: TPedidoCompraService;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;
  LFornecedor: Int64;
  LFornecedorInativo: Int64;
  LCliente: Int64;
  LFornecedorOutraEmpresa: Int64;
  LMaterialA: Int64;
  LMaterialB: Int64;
  LMaterialOutraEmpresa: Int64;

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

  function CriarMaterial(const ADescricao: string; AEmpresaId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO MATERIAL (EMPRESA_ID, DESCRICAO, CODIGO, PRECO_CUSTO, ' +
      '  CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, :DESC, :COD, 1, ''S'', ''A'') RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('COD').AsString := 'PC' + Copy(LSufixo, 1, 12) +
      IntToStr(LSeq);
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function ItemSimples(AMaterialId: Int64; AQtd, AVlr, ADesc: Double):
    TItemCompraEntrada;
  begin
    Result.MaterialId := AMaterialId;
    Result.Quantidade := AQtd;
    Result.ValorUnitario := AVlr;
    Result.Desconto := ADesc;
  end;

  function TextoPedido(const ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(1000)) AS VALOR ' +
      'FROM PEDIDO_COMPRA WHERE ID = :ID';
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
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_COMPRA WHERE ID = :ID';
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
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_COMPRA WHERE ID = :ID';
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
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_COMPRA WHERE ID = :ID';
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
      'SELECT FIRST 1 ID FROM PEDIDO_COMPRA_ITEM WHERE PEDIDO_COMPRA_ID = :PED ' +
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
      'FROM PEDIDO_COMPRA_ITEM WHERE ID = :ID';
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
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_COMPRA_ITEM WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function ContarLog(AId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM LOG_SISTEMA WHERE TABELA = ''PEDIDO_COMPRA'' ' +
      '  AND OPERACAO = ''INSERT'' AND REGISTRO_ID = :REG';
    LQuery.ParamByName('REG').AsLargeInt := AId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function InserirPedidoDireto(AEmpresaId, AFornecedorId: Int64;
    const ANumero: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_COMPRA (EMPRESA_ID, FORNECEDOR_ID, USUARIO_ID, ' +
      '  NUMERO, STATUS, SUBTOTAL, DESCONTO, TOTAL) ' +
      'VALUES (:EMP, :FORN, :USR, :NUM, ''ABERTO'', 0, 0, 0) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('FORN').AsLargeInt := AFornecedorId;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function RecusouSalvar(AFornecedorId: Int64;
    const AItens: TItensCompraEntrada; ADesconto: Double;
    const ANumero, AObs, AStatus: string): Boolean;
  begin
    Result := False;
    try
      LPedido.SalvarPedido(AFornecedorId, ANumero, AItens, ADesconto, AObs,
        AStatus);
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
      AssertTrue(QuaseIgual(19, TotalItemCompra(2, 10, 1)),
        'item: 2 * 10 - 1 = 19');
      AssertTrue(QuaseIgual(0, TotalItemCompra(2, 10, 25)),
        'desconto maior que o valor zera o item');
      AssertTrue(QuaseIgual(7, TotalDoPedidoCompra(10, 3)),
        'pedido: 10 - 3 = 7');
      AssertTrue(QuaseIgual(0, TotalDoPedidoCompra(10, 15)),
        'desconto maior que o subtotal zera o pedido');

      ASuite.AddResult('TestCompraTotais', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraTotais', False, E.Message);
    end;
  end;

  procedure TestTotaisDosItensNoService;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 2);
      LItens[0] := ItemSimples(LMaterialA, 2, 10, 1);  // 19
      LItens[1] := ItemSimples(LMaterialB, 3, 5, 0);   // 15

      AssertTrue(QuaseIgual(34, LPedido.SubtotalDosItens(LItens)),
        'subtotal deve somar os itens');
      AssertTrue(QuaseIgual(30, LPedido.TotalDoPedido(LItens, 4)),
        'total do pedido deve descontar do subtotal');

      ASuite.AddResult('TestCompraTotaisDosItensNoService', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraTotaisDosItensNoService', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Gravação
  // ------------------------------------------------------------------

  procedure TestSalvarPedidoCompleto;
  var
    LId, LItemId: Int64;
    LItens: TItensCompraEntrada;
    LNumero: string;
  begin
    try
      LNumero := 'C' + Copy(LSufixo, 1, 12);
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 2, 10, 1);
      LId := LPedido.SalvarPedido(LFornecedor, LNumero, LItens, 0,
        'OBS ' + LSufixo, 'ABERTO');

      AssertTrue(LId > 0, 'SalvarPedido deve devolver o ID');
      AssertEquals(LNumero, TextoPedido('NUMERO', LId),
        'o número informado deve ser gravado');
      AssertEquals('ABERTO', TextoPedido('STATUS', LId),
        'o status deve ser gravado');
      AssertEquals(IntToStr(LSessao.EmpresaId), TextoPedido('EMPRESA_ID', LId),
        'o pedido deve pertencer à empresa da sessão');
      AssertEquals(IntToStr(LFornecedor), TextoPedido('FORNECEDOR_ID', LId),
        'o fornecedor deve ser gravado');
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
      AssertEquals(IntToStr(LMaterialA), TextoItem('MATERIAL_ID', LItemId),
        'o material do item deve ser gravado');
      AssertTrue(QuaseIgual(2, FloatItem('QUANTIDADE', LItemId)),
        'a quantidade do item deve ser gravada');
      AssertTrue(QuaseIgual(10, FloatItem('VALOR_UNITARIO', LItemId)),
        'o valor unitário deve ser gravado');
      AssertTrue(QuaseIgual(1, FloatItem('DESCONTO', LItemId)),
        'o desconto do item deve ser gravado');
      AssertTrue(QuaseIgual(19, FloatItem('VALOR_TOTAL', LItemId)),
        'o total do item deve ser calculado');

      ASuite.AddResult('TestCompraSalvarCompleto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraSalvarCompleto', False, E.Message);
    end;
  end;

  procedure TestNumeroAutomatico;
  var
    LId: Int64;
    LItens: TItensCompraEntrada;
    LBase: Integer;
  begin
    try
      LBase := LPedido.ProximoNumero;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);

      LId := LPedido.SalvarPedido(LFornecedor, '', LItens, 0);
      AssertEquals(IntToStr(LBase), TextoPedido('NUMERO', LId),
        'número vazio deve usar o próximo número');

      LId := LPedido.SalvarPedido(LFornecedor, '0', LItens, 0);
      AssertEquals(IntToStr(LBase + 1), TextoPedido('NUMERO', LId),
        'número "0" também deve usar o próximo número');

      ASuite.AddResult('TestCompraNumeroAutomatico', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraNumeroAutomatico', False, E.Message);
    end;
  end;

  procedure TestProximoNumeroIgnoraTexto;
  var
    LItens: TItensCompraEntrada;
    LBase: Integer;
    LId: Int64;
  begin
    try
      LBase := LPedido.ProximoNumero;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);

      LId := LPedido.SalvarPedido(LFornecedor, IntToStr(LBase), LItens, 0);
      AssertEquals(IntToStr(LBase), TextoPedido('NUMERO', LId),
        'o número numérico deve ser gravado');
      AssertTrue(LPedido.ProximoNumero = LBase + 1,
        'o próximo número deve avançar após o numérico');

      LId := LPedido.SalvarPedido(LFornecedor,
        'PC-' + Copy(LSufixo, 1, 10), LItens, 0);
      AssertTrue(LId > 0, 'pedido com número texto deve ser aceito');
      AssertTrue(LPedido.ProximoNumero = LBase + 1,
        'número texto não pode entrar na numeração');

      ASuite.AddResult('TestCompraProximoNumeroIgnoraTexto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraProximoNumeroIgnoraTexto', False,
          E.Message);
    end;
  end;

  procedure TestProximoNumeroPorEmpresa;
  var
    LBase: Integer;
  begin
    try
      LBase := LPedido.ProximoNumero;
      InserirPedidoDireto(999999, LFornecedorOutraEmpresa, '987654');
      AssertTrue(LPedido.ProximoNumero = LBase,
        'pedido de outra empresa não pode entrar na numeração');

      ASuite.AddResult('TestCompraProximoNumeroPorEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraProximoNumeroPorEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestSalvarPedidoMultiplosItens;
  var
    LId: Int64;
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 2);
      LItens[0] := ItemSimples(LMaterialA, 2, 10, 2);  // 18
      LItens[1] := ItemSimples(LMaterialB, 1, 5, 0);   // 5
      LId := LPedido.SalvarPedido(LFornecedor, 'M' + Copy(LSufixo, 1, 12),
        LItens, 3);

      AssertTrue(QuaseIgual(23, FloatPedido('SUBTOTAL', LId)),
        'o subtotal deve somar os dois itens');
      AssertTrue(QuaseIgual(3, FloatPedido('DESCONTO', LId)),
        'o desconto do pedido deve ser gravado');
      AssertTrue(QuaseIgual(20, FloatPedido('TOTAL', LId)),
        'o total deve descontar o valor do pedido');
      AssertEquals('2', IntToStr(LPedido.QuantidadeItens(LId)),
        'o pedido deve ter dois itens');

      ASuite.AddResult('TestCompraSalvarMultiplosItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraSalvarMultiplosItens', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoDescontoMaior;
  var
    LId: Int64;
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      LId := LPedido.SalvarPedido(LFornecedor, 'D' + Copy(LSufixo, 1, 12),
        LItens, 15);

      AssertTrue(QuaseIgual(10, FloatPedido('SUBTOTAL', LId)),
        'o subtotal continua sendo o dos itens');
      AssertTrue(QuaseIgual(0, FloatPedido('TOTAL', LId)),
        'o total do pedido nunca fica negativo');

      ASuite.AddResult('TestCompraSalvarDescontoMaior', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraSalvarDescontoMaior', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoStatus;
  var
    LId: Int64;
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);

      LId := LPedido.SalvarPedido(LFornecedor, 'S' + Copy(LSufixo, 1, 12),
        LItens, 0, '', '');
      AssertEquals('ABERTO', TextoPedido('STATUS', LId),
        'status vazio deve assumir ABERTO');

      LId := LPedido.SalvarPedido(LFornecedor, 'A' + Copy(LSufixo, 1, 12),
        LItens, 0, '', 'CONFIRMADO');
      AssertEquals('CONFIRMADO', TextoPedido('STATUS', LId),
        'status CONFIRMADO deve ser gravado');

      LId := LPedido.SalvarPedido(LFornecedor, 'X' + Copy(LSufixo, 1, 12),
        LItens, 0, '', 'CANCELADO');
      AssertEquals('CANCELADO', TextoPedido('STATUS', LId),
        'status CANCELADO deve ser gravado');

      ASuite.AddResult('TestCompraSalvarStatus', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraSalvarStatus', False, E.Message);
    end;
  end;

  procedure TestSalvarPedidoDatas;
  var
    LId: Int64;
    LItens: TItensCompraEntrada;
    LEmissao, LEntrega: TDateTime;
  begin
    try
      LEmissao := Trunc(Now) - 2;
      LEntrega := Trunc(Now) + 5;
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      LId := LPedido.SalvarPedido(LFornecedor, 'E' + Copy(LSufixo, 1, 12),
        LItens, 0, '', 'ABERTO', LEmissao, LEntrega);

      AssertTrue(Trunc(DataPedido('DATA_EMISSAO', LId)) = LEmissao,
        'a data de emissão informada deve ser gravada');
      AssertTrue(Trunc(DataPedido('DATA_ENTREGA', LId)) = LEntrega,
        'a data de entrega deve ser gravada');

      LId := LPedido.SalvarPedido(LFornecedor, 'F' + Copy(LSufixo, 1, 12),
        LItens, 0, '', 'ABERTO', 0, 0);
      AssertTrue(Trunc(DataPedido('DATA_EMISSAO', LId)) = Trunc(Now),
        'sem data informada a trigger usa a data atual');
      AssertTrue(NuloPedido('DATA_ENTREGA', LId),
        'entrega não informada deve ficar nula');

      ASuite.AddResult('TestCompraSalvarDatas', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraSalvarDatas', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Validações
  // ------------------------------------------------------------------

  procedure TestRecusarFornecedorInativo;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedorInativo, LItens, 0, 'X', '', 'ABERTO'),
        'fornecedor inativo deve ser recusado');

      ASuite.AddResult('TestCompraRecusarFornecedorInativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarFornecedorInativo', False,
          E.Message);
    end;
  end;

  procedure TestRecusarFornecedorInvalido;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      AssertTrue(RecusouSalvar(0, LItens, 0, 'X', '', 'ABERTO'),
        'fornecedor 0 deve ser recusado');
      AssertTrue(RecusouSalvar(999999999, LItens, 0, 'X', '', 'ABERTO'),
        'fornecedor inexistente deve ser recusado');

      ASuite.AddResult('TestCompraRecusarFornecedorInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarFornecedorInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRecusarClienteComoFornecedor;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LCliente, LItens, 0, 'X', '', 'ABERTO'),
        'pessoa tipo C não pode ser fornecedor do pedido');

      ASuite.AddResult('TestCompraRecusarClienteComoFornecedor', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarClienteComoFornecedor', False,
          E.Message);
    end;
  end;

  procedure TestRecusarSemItens;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      LItens := nil;
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'pedido sem itens deve ser recusado');

      ASuite.AddResult('TestCompraRecusarSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarSemItens', False, E.Message);
    end;
  end;

  procedure TestRecusarMaterialInvalido;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(0, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'material 0 deve ser recusado');

      LItens[0] := ItemSimples(999999999, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'material inexistente deve ser recusado');

      ASuite.AddResult('TestCompraRecusarMaterialInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarMaterialInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRecusarMaterialOutraEmpresa;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialOutraEmpresa, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'material de outra empresa deve ser recusado');

      ASuite.AddResult('TestCompraRecusarMaterialOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarMaterialOutraEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestRecusarQuantidadeInvalida;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 0, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'quantidade zero deve ser recusada');

      LItens[0] := ItemSimples(LMaterialA, -1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'quantidade negativa deve ser recusada');

      ASuite.AddResult('TestCompraRecusarQuantidadeInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarQuantidadeInvalida', False,
          E.Message);
    end;
  end;

  procedure TestRecusarValoresNegativos;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, -1, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'valor unitário negativo deve ser recusado');

      LItens[0] := ItemSimples(LMaterialA, 1, 10, -1);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'ABERTO'),
        'desconto negativo no item deve ser recusado');

      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, -1, 'X', '', 'ABERTO'),
        'desconto negativo no pedido deve ser recusado');

      ASuite.AddResult('TestCompraRecusarValoresNegativos', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarValoresNegativos', False,
          E.Message);
    end;
  end;

  procedure TestRecusarObservacoesLongas;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X',
        StringOfChar('X', 501), 'ABERTO'),
        'observações com mais de 500 caracteres devem ser recusadas');

      ASuite.AddResult('TestCompraRecusarObservacoesLongas', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarObservacoesLongas', False,
          E.Message);
    end;
  end;

  procedure TestRecusarNumeroLongo;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, StringOfChar('9', 21),
        '', 'ABERTO'),
        'número com mais de 20 caracteres deve ser recusado');

      ASuite.AddResult('TestCompraRecusarNumeroLongo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarNumeroLongo', False, E.Message);
    end;
  end;

  procedure TestRecusarStatusInvalido;
  var
    LItens: TItensCompraEntrada;
  begin
    try
      SetLength(LItens, 1);
      LItens[0] := ItemSimples(LMaterialA, 1, 10, 0);
      AssertTrue(RecusouSalvar(LFornecedor, LItens, 0, 'X', '', 'PENDENTE'),
        'status fora de ABERTO/CONFIRMADO/CANCELADO deve ser recusado');

      ASuite.AddResult('TestCompraRecusarStatusInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraRecusarStatusInvalido', False,
          E.Message);
    end;
  end;

  procedure TestQuantidadeItensInexistente;
  begin
    try
      AssertTrue(LPedido.QuantidadeItens(0) = 0,
        'pedido 0 não deve ter itens');
      AssertTrue(LPedido.QuantidadeItens(999999999) = 0,
        'pedido inexistente não deve ter itens');

      ASuite.AddResult('TestCompraQuantidadeItensInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCompraQuantidadeItensInexistente', False,
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
        'DELETE FROM PEDIDO_COMPRA_ITEM WHERE PEDIDO_COMPRA_ID IN (' +
        '  SELECT P.ID FROM PEDIDO_COMPRA P ' +
        '  JOIN PESSOA F ON F.ID = P.FORNECEDOR_ID ' +
        '  WHERE F.NOME CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM PEDIDO_COMPRA WHERE FORNECEDOR_ID IN (' +
        '  SELECT ID FROM PESSOA WHERE NOME CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo('DELETE FROM MATERIAL WHERE DESCRICAO CONTAINING :P1');
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
  LPedido := TPedidoCompraService.Create;
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
    WriteLn('EXECUTANDO TESTES DE PEDIDO DE COMPRA');
    WriteLn('========================================');

    LFornecedor := CriarPessoa(NovoNome('FORNECEDOR COMPRA'), 'F', 'A',
      LSessao.EmpresaId);
    LFornecedorInativo := CriarPessoa(NovoNome('FORNECEDOR INATIVO'), 'F',
      'I', LSessao.EmpresaId);
    LCliente := CriarPessoa(NovoNome('CLIENTE COMPRA'), 'C', 'A',
      LSessao.EmpresaId);
    LFornecedorOutraEmpresa := CriarPessoa(NovoNome('FORNECEDOR OUTRA'),
      'F', 'A', 999999);
    LMaterialA := CriarMaterial(NovoNome('MATERIAL COMPRA A'),
      LSessao.EmpresaId);
    LMaterialB := CriarMaterial(NovoNome('MATERIAL COMPRA B'),
      LSessao.EmpresaId);
    LMaterialOutraEmpresa := CriarMaterial(NovoNome('MATERIAL OUTRA'),
      999999);

    TestTotais;
    TestTotaisDosItensNoService;
    TestSalvarPedidoCompleto;
    TestNumeroAutomatico;
    TestProximoNumeroIgnoraTexto;
    TestProximoNumeroPorEmpresa;
    TestSalvarPedidoMultiplosItens;
    TestSalvarPedidoDescontoMaior;
    TestSalvarPedidoStatus;
    TestSalvarPedidoDatas;
    TestRecusarFornecedorInativo;
    TestRecusarFornecedorInvalido;
    TestRecusarClienteComoFornecedor;
    TestRecusarSemItens;
    TestRecusarMaterialInvalido;
    TestRecusarMaterialOutraEmpresa;
    TestRecusarQuantidadeInvalida;
    TestRecusarValoresNegativos;
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
