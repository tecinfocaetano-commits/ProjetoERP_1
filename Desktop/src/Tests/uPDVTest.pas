unit uPDVTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do PDV (frente de caixa)
  ------------------------------------------------------------
  Cobre TPDVService (extraído de uFrmPDV):

    - totais: item = quantidade * preço unitário e venda =
      subtotal - desconto, ambos nunca negativos (reaproveitados
      do pedido de venda);
    - numeração: maior NUMERO numérico da empresa + 1, ignorando
      textos e registros de outra empresa (PEDIDO_VENDA e CAIXA);
    - caixa: CaixaAberto por empresa/usuário, abertura com número
      automático e auditoria INSERT, recusa de abertura duplicada
      e de valor negativo;
    - busca de produto por código ou código de barras, somente
      ativo e da empresa;
    - venda: PEDIDO_VENDA com STATUS 'F', cliente informado ou
      "Consumidor Final" da empresa, itens em ITEM_PEDIDO e um
      movimento de caixa 'V' na MESMA transação, com auditoria;
    - saldo: abertura + entradas ('E' e 'V') - saídas ('S'),
      conferido também pelo TCaixaService (grade e resumo);
    - movimentos avulsos: somente 'E'/'S', valor > 0, caixa aberto
      da empresa, descrição até 255 e auditoria;
    - fechamento: grava STATUS 'F', VALOR_FECHAMENTO e auditoria;
      fechar de novo é recusado;
    - validações: sem itens, caixa/produto/cliente inválidos,
      quantidade, preço e desconto, observações longas.

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uPDVService, uCaixaService;

type
  { TPDVTest }
  TPDVTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TPDVTest }

class procedure TPDVTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LService: TPDVService;
  LCaixaService: TCaixaService;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;
  LUsuarioFixo: Int64;
  LConsumidorExistia: Boolean;
  LCliente: Int64;
  LClienteInativo: Int64;
  LFornecedor: Int64;
  LClienteOutraEmpresa: Int64;
  LProdutoA: Int64;
  LProdutoB: Int64;
  LProdutoInativo: Int64;
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

  function NovoNumeroCaixa: string;
  begin
    Inc(LSeq);
    Result := 'PDV' + Copy(LSufixo, 1, 10) + '-' + IntToStr(LSeq);
  end;

  function NovoCodigoProduto: string;
  begin
    Inc(LSeq);
    Result := 'PDV' + Copy(LSufixo, 1, 12) + IntToStr(LSeq);
  end;

  function NovoCodigoBarras: string;
  begin
    Inc(LSeq);
    Result := '789' + Copy(LSufixo, 1, 10) + IntToStr(LSeq);
  end;

  function ItemPDV(AProdutoId: Int64; AQtd, APreco: Double):
    TItemPDVEntrada;
  begin
    Result.ProdutoId := AProdutoId;
    Result.Quantidade := AQtd;
    Result.PrecoUnitario := APreco;
  end;

  // ------------------------------------------------------------------
  // Helpers de banco
  // ------------------------------------------------------------------

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

  function CriarProduto(const ADescricao, ACodigo, ACodigoBarras: string;
    AAtivo: Char; AEmpresaId: Int64; APreco: Double): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
      '  CODIGO_BARRAS, DESCRICAO, PRECO_CUSTO, PRECO_VENDA, ' +
      '  CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, 1, 1, :COD, :BARRAS, :DESC, 1, :PRECO, ''S'', :ATIVO) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('COD').AsString := ACodigo;
    if ACodigoBarras <> '' then
      LQuery.ParamByName('BARRAS').AsString := ACodigoBarras
    else
      LQuery.ParamByName('BARRAS').Clear;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('PRECO').AsFloat := APreco;
    LQuery.ParamByName('ATIVO').AsString := AAtivo;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirCaixa(const ANumero: string; AEmpresaId, AUsuarioId: Int64;
    AStatus: Char; AValorAbertura: Double): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO CAIXA (EMPRESA_ID, USUARIO_ID, NUMERO, DATA_ABERTURA, ' +
      '  VALOR_ABERTURA, STATUS) ' +
      'VALUES (:EMP, :USU, :NUM, CURRENT_TIMESTAMP, :VALOR, :STATUS) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('USU').AsLargeInt := AUsuarioId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.ParamByName('VALOR').AsFloat := AValorAbertura;
    LQuery.ParamByName('STATUS').AsString := AStatus;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function CriarCaixaAberto(out ANumero: string;
    AValorAbertura: Double): Int64;
  begin
    ANumero := NovoNumeroCaixa;
    Result := InserirCaixa(ANumero, LSessao.EmpresaId, LUsuarioFixo,
      'A', AValorAbertura);
  end;

  function InserirMovimento(ACaixaId: Int64; ATipo: Char; AValor: Double;
    const ADescricao: string; AUsuarioId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_CAIXA (EMPRESA_ID, CAIXA_ID, TIPO, VALOR, ' +
      '  DESCRICAO, DATA_MOVIMENTO, USUARIO_ID) ' +
      'VALUES (:EMP, :CX, :TIPO, :VALOR, :DESC, CURRENT_TIMESTAMP, :USU) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('CX').AsLargeInt := ACaixaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('VALOR').AsFloat := AValor;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('USU').AsLargeInt := AUsuarioId;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function InserirPedidoDireto(AEmpresaId, AClienteId: Int64;
    const ANumero, AStatus, AObs: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, ' +
      '  NUMERO, STATUS, SUBTOTAL, DESCONTO, TOTAL, OBSERVACOES) ' +
      'VALUES (:EMP, :CLI, :USR, :NUM, :STS, 0, 0, 0, :OBS) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.ParamByName('STS').AsString := AStatus;
    LQuery.ParamByName('OBS').AsString := AObs;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
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

  function TextoClienteDoPedido(AVendaId: Int64;
    const ACampo: string): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(200)) AS VALOR ' +
      'FROM PEDIDO_VENDA P JOIN PESSOA PE ON PE.ID = P.CLIENTE_ID ' +
      'WHERE P.ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AVendaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function PrimeiroItem(AVendaId: Int64): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = :PED ' +
      'ORDER BY ID';
    LQuery.ParamByName('PED').AsLargeInt := AVendaId;
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

  function SomaItensDoPedido(AVendaId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(COALESCE(SUM(VALOR_TOTAL), 0) AS NUMERIC(18,4)) AS SOMA ' +
      'FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = :PED';
    LQuery.ParamByName('PED').AsLargeInt := AVendaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('SOMA').AsFloat;
    LQuery.Close;
  end;

  function PrimeiroMovimentoDoPedido(AVendaId: Int64): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM MOVIMENTO_CAIXA ' +
      'WHERE PEDIDO_VENDA_ID = :PED ORDER BY ID';
    LQuery.ParamByName('PED').AsLargeInt := AVendaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  end;

  function ContarMovimentosDoPedido(AVendaId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM MOVIMENTO_CAIXA WHERE PEDIDO_VENDA_ID = :PED';
    LQuery.ParamByName('PED').AsLargeInt := AVendaId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function MovimentoDoCaixa(ACaixaId: Int64; ATipo: Char): Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM MOVIMENTO_CAIXA ' +
      'WHERE CAIXA_ID = :CX AND TIPO = :TIPO ORDER BY ID DESC';
    LQuery.ParamByName('CX').AsLargeInt := ACaixaId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  end;

  function TextoMovimento(const ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(1000)) AS VALOR ' +
      'FROM MOVIMENTO_CAIXA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function FloatMovimento(const ACampo: string; AId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM MOVIMENTO_CAIXA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function NuloMovimento(const ACampo: string; AId: Int64): Boolean;
  begin
    Result := False;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM MOVIMENTO_CAIXA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').IsNull;
    LQuery.Close;
  end;

  function DataMovimento(const ACampo: string; AId: Int64): TDateTime;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM MOVIMENTO_CAIXA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsDateTime;
    LQuery.Close;
  end;

  function TextoCaixa(const ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(1000)) AS VALOR ' +
      'FROM CAIXA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function FloatCaixa(const ACampo: string; AId: Int64): Double;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM CAIXA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function DataCaixa(const ACampo: string; AId: Int64): TDateTime;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM CAIXA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsDateTime;
    LQuery.Close;
  end;

  function ContarLog(const ATabela: string; AId: Int64;
    const AOperacao: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM LOG_SISTEMA WHERE TRIM(TABELA) = :TAB ' +
      '  AND OPERACAO = :OP AND REGISTRO_ID = :REG';
    LQuery.ParamByName('TAB').AsString := ATabela;
    LQuery.ParamByName('OP').AsString := AOperacao;
    LQuery.ParamByName('REG').AsLargeInt := AId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarConsumidorFinal: Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM PESSOA WHERE EMPRESA_ID = :EMP ' +
      '  AND UPPER(NOME) = ''CONSUMIDOR FINAL''';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function SaldoNaGrade(const ANumero: string; out ASaldo: Double): Boolean;
  begin
    Result := False;
    ASaldo := 0;
    LCaixaService.CarregarCaixas(LLista);
    LLista.First;
    while not LLista.EOF do
    begin
      if Trim(LLista.FieldByName('NUMERO').AsString) = ANumero then
      begin
        ASaldo := LLista.FieldByName('SALDO').AsFloat;
        Result := True;
        Exit;
      end;
      LLista.Next;
    end;
  end;

  // ------------------------------------------------------------------
  // Helpers de "recusa"
  // ------------------------------------------------------------------

  function RecusouAbrir(AValor: Double): Boolean;
  var
    LSalvo: Int64;
  begin
    Result := False;
    LSalvo := LSessao.UsuarioId;
    try
      LSessao.UsuarioId := LUsuarioFixo;
      try
        LService.AbrirCaixa(AValor);
      except
        on E: Exception do
          Result := True;
      end;
    finally
      LSessao.UsuarioId := LSalvo;
    end;
  end;

  function AbrirComoUsuarioFixo(AValor: Double; out AId: Int64): Boolean;
  var
    LSalvo: Int64;
  begin
    Result := False;
    AId := 0;
    LSalvo := LSessao.UsuarioId;
    try
      LSessao.UsuarioId := LUsuarioFixo;
      AId := LService.AbrirCaixa(AValor);
      Result := True;
    finally
      LSessao.UsuarioId := LSalvo;
    end;
  end;

  function RecusouVenda(ACaixaId: Int64; const AItens: TItensPDVEntrada;
    ADesconto: Double; AFormaId, AClienteId: Int64;
    const AObs: string): Boolean;
  begin
    Result := False;
    try
      LService.SalvarVenda(ACaixaId, AItens, ADesconto, AFormaId,
        AClienteId, AObs);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouMovimento(ACaixaId: Int64; ATipo: Char; AValor: Double;
    const ADescricao: string): Boolean;
  begin
    Result := False;
    try
      LService.RegistrarMovimento(ACaixaId, ATipo, AValor, ADescricao);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouFechar(ACaixaId: Int64): Boolean;
  begin
    Result := False;
    try
      LService.FecharCaixa(ACaixaId);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouSaldo(ACaixaId: Int64): Boolean;
  begin
    Result := False;
    try
      LService.SaldoCaixa(ACaixaId);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouFormasNil: Boolean;
  begin
    Result := False;
    try
      LService.CarregarFormasPagamento(nil);
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
      AssertTrue(QuaseIgual(20, TotalItemPDV(2, 10)),
        'item: 2 * 10 = 20');
      AssertTrue(QuaseIgual(0, TotalItemPDV(2, 0)),
        'item com preço zero deve dar zero');
      AssertTrue(QuaseIgual(15, TotalVendaPDV(20, 5)),
        'venda: 20 - 5 = 15');
      AssertTrue(QuaseIgual(0, TotalVendaPDV(10, 15)),
        'desconto maior que o subtotal deve dar zero');
      ASuite.AddResult('TestPDVTotais', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVTotais', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Numeração
  // ------------------------------------------------------------------

  procedure TestProximoNumeroVenda;
  var
    LBase: Integer;
    LId1, LId2, LId3: Int64;
  begin
    try
      LBase := LService.ProximoNumeroVenda;
      LId1 := InserirPedidoDireto(LSessao.EmpresaId, LCliente,
        IntToStr(LBase), 'O', 'PDV ' + LSufixo + ' NUM1');
      AssertTrue(LService.ProximoNumeroVenda = LBase + 1,
        'número numérico deve avançar');

      LId2 := InserirPedidoDireto(LSessao.EmpresaId, LCliente,
        'ORC-' + Copy(LSufixo, 1, 12), 'O', 'PDV ' + LSufixo + ' NUM2');
      AssertTrue(LService.ProximoNumeroVenda = LBase + 1,
        'número em texto deve ser ignorado');

      LId3 := InserirPedidoDireto(999999, LClienteOutraEmpresa,
        IntToStr(LBase + 50), 'O', 'PDV ' + LSufixo + ' NUM3');
      AssertTrue(LService.ProximoNumeroVenda = LBase + 1,
        'pedido de outra empresa deve ser ignorado');
      AssertTrue((LId1 > 0) and (LId2 > 0) and (LId3 > 0),
        'os pedidos de apoio devem ser gravados');

      ASuite.AddResult('TestPDVProximoNumeroVenda', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVProximoNumeroVenda', False, E.Message);
    end;
  end;

  procedure TestProximoNumeroCaixa;
  var
    LBase: Integer;
    LId1, LId2, LId3: Int64;

    procedure ApagarCaixa(AId: Int64);
    begin
      try
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM CAIXA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := AId;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      except
      end;
    end;

  begin
    LId1 := 0;
    LId2 := 0;
    LId3 := 0;
    try
      LBase := LService.ProximoNumeroCaixa;
      LId1 := InserirCaixa(IntToStr(LBase), LSessao.EmpresaId,
        LUsuarioFixo, 'F', 0);
      AssertTrue(LService.ProximoNumeroCaixa = LBase + 1,
        'número numérico do caixa deve avançar');

      LId2 := InserirCaixa('CX' + Copy(LSufixo, 1, 12), LSessao.EmpresaId,
        LUsuarioFixo, 'F', 0);
      AssertTrue(LService.ProximoNumeroCaixa = LBase + 1,
        'número em texto do caixa deve ser ignorado');

      LId3 := InserirCaixa(IntToStr(LBase + 50), 999999, LUsuarioFixo,
        'F', 0);
      AssertTrue(LService.ProximoNumeroCaixa = LBase + 1,
        'caixa de outra empresa deve ser ignorado');

      ASuite.AddResult('TestPDVProximoNumeroCaixa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVProximoNumeroCaixa', False, E.Message);
    end;
    if LId1 > 0 then ApagarCaixa(LId1);
    if LId2 > 0 then ApagarCaixa(LId2);
    if LId3 > 0 then ApagarCaixa(LId3);
  end;

  // ------------------------------------------------------------------
  // Caixa
  // ------------------------------------------------------------------

  procedure TestCaixaAberto;
  var
    LOwn, LOutroUsuario, LOutraEmpresa, LFechado: Int64;
  begin
    try
      LOwn := InserirCaixa(NovoNumeroCaixa, LSessao.EmpresaId,
        LSessao.UsuarioId, 'A', 50);
      LOutroUsuario := InserirCaixa(NovoNumeroCaixa, LSessao.EmpresaId,
        LUsuarioFixo + 1, 'A', 60);
      LOutraEmpresa := InserirCaixa(NovoNumeroCaixa, 999999,
        LSessao.UsuarioId, 'A', 70);
      LFechado := InserirCaixa(NovoNumeroCaixa, LSessao.EmpresaId,
        LSessao.UsuarioId, 'F', 80);

      AssertTrue(LService.CaixaAberto = LOwn,
        'CaixaAberto deve achar o caixa aberto do usuário da sessão');
      AssertTrue(LService.CaixaAberto(LUsuarioFixo + 1) = LOutroUsuario,
        'CaixaAberto deve respeitar o usuário informado');
      AssertTrue(LService.CaixaAberto(LUsuarioFixo + 2) = 0,
        'usuário sem caixa aberto deve devolver 0');
      AssertTrue(LOwn <> LFechado, 'caixa fechado não é caixa aberto');
      AssertTrue(LOutraEmpresa > 0, 'caixa de apoio de outra empresa');

      ASuite.AddResult('TestPDVCaixaAberto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVCaixaAberto', False, E.Message);
    end;
  end;

  procedure TestAbrirCaixa;
  var
    LSalvo, LId: Int64;
    LNumero: string;
  begin
    LId := 0;
    try
      LSalvo := LSessao.UsuarioId;
      try
        LSessao.UsuarioId := LUsuarioFixo;
        AssertTrue(LService.CaixaAberto = 0,
          'usuário de teste deve começar sem caixa aberto');
        LNumero := IntToStr(LService.ProximoNumeroCaixa);
        LId := LService.AbrirCaixa(150.5);
        AssertTrue(LId > 0, 'AbrirCaixa deve devolver o ID');
        AssertTrue(LService.CaixaAberto = LId,
          'CaixaAberto deve achar o caixa recém-aberto');
        AssertEquals(IntToStr(LSessao.EmpresaId),
          TextoCaixa('EMPRESA_ID', LId), 'empresa do caixa');
        AssertEquals(IntToStr(LUsuarioFixo),
          TextoCaixa('USUARIO_ID', LId), 'usuário do caixa');
        AssertEquals(LNumero, TextoCaixa('NUMERO', LId),
          'número automático do caixa');
        AssertEquals('A', TextoCaixa('STATUS', LId), 'status do caixa');
        AssertTrue(QuaseIgual(150.5, FloatCaixa('VALOR_ABERTURA', LId)),
          'valor de abertura');
        AssertTrue(DataCaixa('DATA_ABERTURA', LId) <> 0,
          'data de abertura deve ser preenchida');
        AssertTrue(ContarLog('CAIXA', LId, 'INSERT') = 1,
          'abertura deve gerar auditoria INSERT');
      finally
        LSessao.UsuarioId := LSalvo;
        if LId > 0 then
        begin
          try
            LQuery.Close;
            LQuery.SQL.Text := 'DELETE FROM CAIXA WHERE ID = :ID';
            LQuery.ParamByName('ID').AsLargeInt := LId;
            LQuery.ExecSQL;
            LConexao.Confirmar;
          except
          end;
        end;
      end;
      ASuite.AddResult('TestPDVAbrirCaixa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVAbrirCaixa', False, E.Message);
    end;
  end;

  procedure TestAbrirCaixaDuplicado;
  var
    LCaixa: Int64;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 10);
      AssertTrue(RecusouAbrir(20),
        'não pode abrir um segundo caixa para o mesmo usuário');
      AssertTrue(LService.CaixaAberto(LUsuarioFixo) = LCaixa,
        'a recusa não pode alterar o caixa aberto');
      ASuite.AddResult('TestPDVAbrirCaixaDuplicado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVAbrirCaixaDuplicado', False, E.Message);
    end;
  end;

  procedure TestAbrirCaixaValorNegativo;
  begin
    try
      AssertTrue(RecusouAbrir(-1),
        'valor de abertura negativo deve ser recusado');
      ASuite.AddResult('TestPDVAbrirCaixaValorNegativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVAbrirCaixaValorNegativo', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Busca de produto
  // ------------------------------------------------------------------

  procedure TestBuscarProdutoPorCodigo;
  var
    LId: Int64;
    LCodigo, LDescricao: string;
    LPreco: Double;
  begin
    try
      AssertTrue(LService.BuscarProduto('PDVCOD' + Copy(LSufixo, 1, 10),
        LId, LCodigo, LDescricao, LPreco), 'deve achar pelo código');
      AssertTrue(LId = LProdutoA, 'ID do produto A');
      AssertEquals('PDVCOD' + Copy(LSufixo, 1, 10), LCodigo,
        'código devolvido');
      AssertTrue(Pos('PRODUTO PDV A', LDescricao) = 1, 'descrição devolvida');
      AssertTrue(QuaseIgual(10, LPreco), 'preço de venda');
      ASuite.AddResult('TestPDVBuscarProdutoPorCodigo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVBuscarProdutoPorCodigo', False, E.Message);
    end;
  end;

  procedure TestBuscarProdutoPorBarras;
  var
    LId: Int64;
    LCodigo, LDescricao: string;
    LPreco: Double;
  begin
    try
      AssertTrue(LService.BuscarProduto('789' + Copy(LSufixo, 1, 10),
        LId, LCodigo, LDescricao, LPreco), 'deve achar pelo código de barras');
      AssertTrue(LId = LProdutoA, 'mesmo produto do código');
      AssertEquals('PDVCOD' + Copy(LSufixo, 1, 10), LCodigo,
        'código do produto');
      AssertTrue(QuaseIgual(10, LPreco), 'preço de venda');
      ASuite.AddResult('TestPDVBuscarProdutoPorBarras', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVBuscarProdutoPorBarras', False, E.Message);
    end;
  end;

  procedure TestBuscarProdutoInativo;
  var
    LId: Int64;
    LCodigo, LDescricao: string;
    LPreco: Double;
  begin
    try
      AssertFalse(LService.BuscarProduto('PDVINA' + Copy(LSufixo, 1, 10),
        LId, LCodigo, LDescricao, LPreco), 'produto inativo não deve ser achado');
      AssertTrue(LId = 0, 'ID deve ser 0 quando não acha');
      ASuite.AddResult('TestPDVBuscarProdutoInativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVBuscarProdutoInativo', False, E.Message);
    end;
  end;

  procedure TestBuscarProdutoOutraEmpresa;
  var
    LId: Int64;
    LCodigo, LDescricao: string;
    LPreco: Double;
  begin
    try
      AssertFalse(LService.BuscarProduto('PDVOUT' + Copy(LSufixo, 1, 10),
        LId, LCodigo, LDescricao, LPreco),
        'produto de outra empresa não deve ser achado');
      ASuite.AddResult('TestPDVBuscarProdutoOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVBuscarProdutoOutraEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestBuscarProdutoInexistente;
  var
    LId: Int64;
    LCodigo, LDescricao: string;
    LPreco: Double;
  begin
    try
      AssertFalse(LService.BuscarProduto('', LId, LCodigo, LDescricao, LPreco),
        'código vazio não deve achar nada');
      AssertFalse(LService.BuscarProduto('NAOEXISTE' + Copy(LSufixo, 1, 8),
        LId, LCodigo, LDescricao, LPreco),
        'código inexistente não deve achar nada');
      AssertTrue(LId = 0, 'ID deve ser 0 quando não acha');
      ASuite.AddResult('TestPDVBuscarProdutoInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVBuscarProdutoInexistente', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Venda
  // ------------------------------------------------------------------

  procedure TestSalvarVendaCompleta;
  var
    LCaixa, LId, LItem, LMov: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 100);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 2, 10);

      LId := LService.SalvarVenda(LCaixa, LItens, 3, 1, LCliente,
        'PDV ' + LSufixo + ' VENDA1');
      AssertTrue(LId > 0, 'SalvarVenda deve devolver o ID');
      AssertEquals('F', TextoPedido('STATUS', LId), 'venda confirmada');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        TextoPedido('EMPRESA_ID', LId), 'empresa da venda');
      AssertEquals(IntToStr(LCliente), TextoPedido('CLIENTE_ID', LId),
        'cliente informado');
      AssertEquals(IntToStr(LSessao.UsuarioId),
        TextoPedido('USUARIO_ID', LId), 'usuário da venda');
      AssertEquals(IntToStr(LService.ProximoNumeroVenda - 1),
        TextoPedido('NUMERO', LId), 'número da venda');
      AssertTrue(QuaseIgual(20, FloatPedido('SUBTOTAL', LId)),
        'subtotal 2 * 10');
      AssertTrue(QuaseIgual(3, FloatPedido('DESCONTO', LId)),
        'desconto da venda');
      AssertTrue(QuaseIgual(17, FloatPedido('TOTAL', LId)),
        'total 20 - 3');
      AssertEquals('PDV ' + LSufixo + ' VENDA1',
        TextoPedido('OBSERVACOES', LId), 'observações da venda');
      AssertEquals('1', TextoPedido('FORMA_PAGAMENTO_ID', LId),
        'forma de pagamento');
      AssertTrue(DataPedido('DATA_EMISSAO', LId) <> 0,
        'data de emissão deve ser preenchida');
      AssertEquals('1', IntToStr(LService.QuantidadeItens(LId)),
        'quantidade de itens');

      LItem := PrimeiroItem(LId);
      AssertTrue(LItem > 0, 'o item deve ser gravado');
      AssertEquals(IntToStr(LProdutoA), TextoItem('PRODUTO_ID', LItem),
        'produto do item');
      AssertTrue(QuaseIgual(2, FloatItem('QUANTIDADE', LItem)),
        'quantidade do item');
      AssertTrue(QuaseIgual(10, FloatItem('PRECO_UNITARIO', LItem)),
        'preço unitário do item');
      AssertTrue(QuaseIgual(10, FloatItem('VALOR_UNITARIO', LItem)),
        'valor unitário do item');
      AssertTrue(QuaseIgual(0, FloatItem('DESCONTO', LItem)),
        'item sem desconto');
      AssertTrue(QuaseIgual(20, FloatItem('VALOR_TOTAL', LItem)),
        'total do item');
      AssertEquals('5102', TextoItem('CFOP', LItem), 'CFOP padrão');

      AssertEquals('1', IntToStr(ContarMovimentosDoPedido(LId)),
        'a venda deve gerar um movimento de caixa');
      LMov := PrimeiroMovimentoDoPedido(LId);
      AssertTrue(LMov > 0, 'movimento da venda');
      AssertEquals('V', TextoMovimento('TIPO', LMov), 'tipo VENDA');
      AssertTrue(QuaseIgual(17, FloatMovimento('VALOR', LMov)),
        'valor do movimento');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        TextoMovimento('EMPRESA_ID', LMov), 'empresa do movimento');
      AssertEquals(IntToStr(LCaixa), TextoMovimento('CAIXA_ID', LMov),
        'caixa do movimento');
      AssertEquals(IntToStr(LSessao.UsuarioId),
        TextoMovimento('USUARIO_ID', LMov), 'usuário do movimento');
      AssertEquals(IntToStr(LId), TextoMovimento('PEDIDO_VENDA_ID', LMov),
        'venda do movimento');
      AssertEquals('1', TextoMovimento('FORMA_PAGAMENTO_ID', LMov),
        'forma de pagamento do movimento');
      AssertTrue(DataMovimento('DATA_MOVIMENTO', LMov) <> 0,
        'data do movimento');

      AssertTrue(ContarLog('PEDIDO_VENDA', LId, 'INSERT') = 1,
        'venda deve gerar auditoria INSERT');
      AssertTrue(ContarLog('MOVIMENTO_CAIXA', LMov, 'INSERT') = 1,
        'movimento deve gerar auditoria INSERT');

      ASuite.AddResult('TestPDVSalvarVendaCompleta', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVSalvarVendaCompleta', False, E.Message);
    end;
  end;

  procedure TestSalvarVendaConsumidorFinal;
  var
    LCaixa, LId1, LId2, LCliente1, LCliente2, LMov: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, 10);

      LId1 := LService.SalvarVenda(LCaixa, LItens, 0, 0, 0,
        'PDV ' + LSufixo + ' CF1');
      LCliente1 := StrToInt64Def(TextoClienteDoPedido(LId1,
        'P.CLIENTE_ID'), 0);
      AssertTrue(LCliente1 > 0, 'consumidor final deve ser resolvido');
      AssertEquals('CONSUMIDOR FINAL',
        UpperCase(TextoClienteDoPedido(LId1, 'PE.NOME')),
        'nome do consumidor final');
      AssertEquals('C', TextoClienteDoPedido(LId1, 'PE.TIPO'),
        'consumidor final é cliente');
      AssertEquals('A', TextoClienteDoPedido(LId1, 'PE.ATIVO'),
        'consumidor final ativo');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        TextoClienteDoPedido(LId1, 'PE.EMPRESA_ID'),
        'consumidor final da empresa');

      LId2 := LService.SalvarVenda(LCaixa, LItens, 0, 0, 0,
        'PDV ' + LSufixo + ' CF2');
      LCliente2 := StrToInt64Def(TextoClienteDoPedido(LId2,
        'P.CLIENTE_ID'), 0);
      AssertTrue(LCliente1 = LCliente2,
        'a segunda venda deve reutilizar o consumidor final');
      AssertTrue(ContarConsumidorFinal = 1,
        'não pode duplicar o consumidor final da empresa');

      LMov := PrimeiroMovimentoDoPedido(LId1);
      AssertTrue(NuloMovimento('FORMA_PAGAMENTO_ID', LMov),
        'sem forma informada o movimento fica nulo');
      AssertFalse(NuloMovimento('PEDIDO_VENDA_ID', LMov),
        'o movimento deve apontar para a venda');

      ASuite.AddResult('TestPDVSalvarVendaConsumidorFinal', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVSalvarVendaConsumidorFinal', False,
          E.Message);
    end;
  end;

  procedure TestSalvarVendaMultiplosItens;
  var
    LCaixa, LId: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 2);
      LItens[0] := ItemPDV(LProdutoA, 2, 10);
      LItens[1] := ItemPDV(LProdutoB, 3, 5);

      LId := LService.SalvarVenda(LCaixa, LItens, 5, 1, LCliente,
        'PDV ' + LSufixo + ' MULTI');
      AssertTrue(QuaseIgual(35, FloatPedido('SUBTOTAL', LId)),
        'subtotal 20 + 15');
      AssertTrue(QuaseIgual(5, FloatPedido('DESCONTO', LId)),
        'desconto da venda');
      AssertTrue(QuaseIgual(30, FloatPedido('TOTAL', LId)),
        'total 35 - 5');
      AssertEquals('2', IntToStr(LService.QuantidadeItens(LId)),
        'dois itens gravados');
      AssertTrue(QuaseIgual(35, SomaItensDoPedido(LId)),
        'soma dos itens sem desconto');
      AssertTrue(QuaseIgual(30,
        FloatMovimento('VALOR', PrimeiroMovimentoDoPedido(LId))),
        'movimento com o total da venda');

      ASuite.AddResult('TestPDVSalvarVendaMultiplosItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVSalvarVendaMultiplosItens', False,
          E.Message);
    end;
  end;

  procedure TestSalvarVendaDescontoMaior;
  var
    LCaixa, LId, LMov: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, 10);

      LId := LService.SalvarVenda(LCaixa, LItens, 15, 1, LCliente,
        'PDV ' + LSufixo + ' DESC');
      AssertTrue(QuaseIgual(10, FloatPedido('SUBTOTAL', LId)),
        'subtotal da venda');
      AssertTrue(QuaseIgual(15, FloatPedido('DESCONTO', LId)),
        'desconto maior que o subtotal');
      AssertTrue(QuaseIgual(0, FloatPedido('TOTAL', LId)),
        'total nunca negativo');
      LMov := PrimeiroMovimentoDoPedido(LId);
      AssertTrue(QuaseIgual(0, FloatMovimento('VALOR', LMov)),
        'movimento acompanha o total zerado');

      ASuite.AddResult('TestPDVSalvarVendaDescontoMaior', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVSalvarVendaDescontoMaior', False,
          E.Message);
    end;
  end;

  procedure TestSalvarVendaNumeroAutomatico;
  var
    LCaixa, LId1, LId2: Int64;
    LItens: TItensPDVEntrada;
    LBase, LBase2: Integer;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, 10);

      LBase := LService.ProximoNumeroVenda;
      LId1 := LService.SalvarVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' AUTO1');
      AssertEquals(IntToStr(LBase), TextoPedido('NUMERO', LId1),
        'primeira venda usa o próximo número');

      LBase2 := LService.ProximoNumeroVenda;
      AssertTrue(LBase2 = LBase + 1,
        'o número deve avançar após a venda');
      LId2 := LService.SalvarVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' AUTO2');
      AssertEquals(IntToStr(LBase2), TextoPedido('NUMERO', LId2),
        'segunda venda usa o número seguinte');

      ASuite.AddResult('TestPDVSalvarVendaNumeroAutomatico', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVSalvarVendaNumeroAutomatico', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Saldo e movimentos
  // ------------------------------------------------------------------

  procedure TestSaldoCaixa;
  var
    LCaixa, LMovE, LMovS: Int64;
    LNumero: string;
    LSaldo: Double;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 100);
      InserirMovimento(LCaixa, 'E', 50, 'Suprimento ' + LSufixo,
        LSessao.UsuarioId);
      InserirMovimento(LCaixa, 'V', 30, 'Venda ' + LSufixo,
        LSessao.UsuarioId);
      InserirMovimento(LCaixa, 'S', 20, 'Sangria ' + LSufixo,
        LSessao.UsuarioId);
      InserirMovimento(LCaixa, 'G', 999, 'Ignorado G ' + LSufixo,
        LSessao.UsuarioId);
      InserirMovimento(LCaixa, 'P', 999, 'Ignorado P ' + LSufixo,
        LSessao.UsuarioId);

      AssertTrue(QuaseIgual(160, LService.SaldoCaixa(LCaixa)),
        'saldo = 100 + 50 + 30 - 20 (G/P ignorados)');

      { a grade do TCaixaService mostra o saldo só dos movimentos; a
        abertura entra no SaldoCaixa do PDV, por isso a diferença }
      AssertTrue(SaldoNaGrade(LNumero, LSaldo),
        'o caixa deve aparecer na grade do TCaixaService');
      AssertTrue(QuaseIgual(60, LSaldo),
        'a grade mostra 50 + 30 - 20 (sem a abertura)');
      AssertTrue(QuaseIgual(160, LSaldo + FloatCaixa('VALOR_ABERTURA',
        LCaixa)), 'grade + abertura = SaldoCaixa do PDV');

      LCaixaService.CarregarResumo(LLista, LCaixa);
      AssertTrue(QuaseIgual(80, LLista.FieldByName('ENTRADAS').AsFloat),
        'entradas = E + V');
      AssertTrue(QuaseIgual(20, LLista.FieldByName('SAIDAS').AsFloat),
        'saídas = S');
      AssertTrue(QuaseIgual(60, LLista.FieldByName('SALDO').AsFloat),
        'resumo = entradas - saídas');
      AssertTrue(QuaseIgual(LSaldo,
        LLista.FieldByName('SALDO').AsFloat),
        'grade e resumo do TCaixaService devem coincidir');

      AssertTrue(RecusouSaldo(0), 'caixa 0 deve ser recusado');
      AssertTrue(RecusouSaldo(999999999),
        'caixa inexistente deve ser recusado');

      LMovE := MovimentoDoCaixa(LCaixa, 'E');
      LMovS := MovimentoDoCaixa(LCaixa, 'S');
      AssertTrue((LMovE > 0) and (LMovS > 0),
        'movimentos de apoio devem existir');

      ASuite.AddResult('TestPDVSaldoCaixa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVSaldoCaixa', False, E.Message);
    end;
  end;

  procedure TestRegistrarMovimento;
  var
    LCaixa, LMovE, LMovS: Int64;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      LService.RegistrarMovimento(LCaixa, 'E', 25.5,
        'Suprimento ' + LSufixo);
      LService.RegistrarMovimento(LCaixa, 'S', 10.25,
        'Sangria ' + LSufixo);

      AssertTrue(QuaseIgual(15.25, LService.SaldoCaixa(LCaixa)),
        'saldo = 25,50 - 10,25');

      LMovE := MovimentoDoCaixa(LCaixa, 'E');
      LMovS := MovimentoDoCaixa(LCaixa, 'S');
      AssertTrue((LMovE > 0) and (LMovS > 0),
        'os dois movimentos devem ser gravados');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        TextoMovimento('EMPRESA_ID', LMovE), 'empresa do suprimento');
      AssertEquals(IntToStr(LSessao.UsuarioId),
        TextoMovimento('USUARIO_ID', LMovE), 'usuário do suprimento');
      AssertTrue(QuaseIgual(25.5, FloatMovimento('VALOR', LMovE)),
        'valor do suprimento');
      AssertEquals('Suprimento ' + LSufixo,
        TextoMovimento('DESCRICAO', LMovE), 'descrição do suprimento');
      AssertTrue(DataMovimento('DATA_MOVIMENTO', LMovE) <> 0,
        'data do suprimento');
      AssertTrue(NuloMovimento('PEDIDO_VENDA_ID', LMovE),
        'suprimento não aponta para venda');
      AssertTrue(ContarLog('MOVIMENTO_CAIXA', LMovE, 'INSERT') = 1,
        'suprimento deve gerar auditoria');
      AssertTrue(ContarLog('MOVIMENTO_CAIXA', LMovS, 'INSERT') = 1,
        'sangria deve gerar auditoria');

      ASuite.AddResult('TestPDVRegistrarMovimento', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRegistrarMovimento', False, E.Message);
    end;
  end;

  procedure TestRegistrarMovimentoTipoInvalido;
  var
    LCaixa: Int64;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      AssertTrue(RecusouMovimento(LCaixa, 'V', 10, 'Tipo V'),
        'movimento tipo V não pode ser lançado avulso');
      AssertTrue(RecusouMovimento(LCaixa, 'X', 10, 'Tipo X'),
        'tipo desconhecido deve ser recusado');
      AssertTrue(RecusouMovimento(LCaixa, 'e', 10, 'Minúsculo'),
        'tipo minúsculo deve ser recusado');
      ASuite.AddResult('TestPDVRegistrarMovimentoTipoInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRegistrarMovimentoTipoInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRegistrarMovimentoValorInvalido;
  var
    LCaixa: Int64;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      AssertTrue(RecusouMovimento(LCaixa, 'E', 0, 'Zero'),
        'valor zero deve ser recusado');
      AssertTrue(RecusouMovimento(LCaixa, 'S', -5, 'Negativo'),
        'valor negativo deve ser recusado');
      ASuite.AddResult('TestPDVRegistrarMovimentoValorInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRegistrarMovimentoValorInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRegistrarMovimentoCaixaInvalido;
  var
    LCaixaFechado, LCaixaOutraEmpresa: Int64;
  begin
    try
      LCaixaFechado := InserirCaixa(NovoNumeroCaixa, LSessao.EmpresaId,
        LUsuarioFixo, 'F', 0);
      LCaixaOutraEmpresa := InserirCaixa(NovoNumeroCaixa, 999999,
        LUsuarioFixo, 'A', 0);

      AssertTrue(RecusouMovimento(0, 'E', 10, 'Caixa 0'),
        'caixa 0 deve ser recusado');
      AssertTrue(RecusouMovimento(999999999, 'E', 10, 'Inexistente'),
        'caixa inexistente deve ser recusado');
      AssertTrue(RecusouMovimento(LCaixaFechado, 'E', 10, 'Fechado'),
        'caixa fechado deve ser recusado');
      AssertTrue(RecusouMovimento(LCaixaOutraEmpresa, 'E', 10, 'Outra'),
        'caixa de outra empresa deve ser recusado');

      ASuite.AddResult('TestPDVRegistrarMovimentoCaixaInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRegistrarMovimentoCaixaInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRegistrarMovimentoDescricaoLonga;
  var
    LCaixa: Int64;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      AssertTrue(RecusouMovimento(LCaixa, 'E', 10, StringOfChar('X', 256)),
        'descrição com mais de 255 caracteres deve ser recusada');
      ASuite.AddResult('TestPDVRegistrarMovimentoDescricaoLonga', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRegistrarMovimentoDescricaoLonga', False,
          E.Message);
    end;
  end;

  procedure TestFecharCaixa;
  var
    LCaixa, LMov: Int64;
    LNumero: string;
    LSaldo: Double;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 100);
      InserirMovimento(LCaixa, 'E', 50, 'Suprimento ' + LSufixo,
        LSessao.UsuarioId);
      InserirMovimento(LCaixa, 'S', 20, 'Sangria ' + LSufixo,
        LSessao.UsuarioId);

      LSaldo := LService.FecharCaixa(LCaixa);
      AssertTrue(QuaseIgual(130, LSaldo),
        'fechamento devolve o saldo 100 + 50 - 20');
      AssertEquals('F', TextoCaixa('STATUS', LCaixa),
        'caixa deve ficar fechado');
      AssertTrue(QuaseIgual(130, FloatCaixa('VALOR_FECHAMENTO', LCaixa)),
        'valor de fechamento gravado');
      AssertTrue(DataCaixa('DATA_FECHAMENTO', LCaixa) <> 0,
        'data de fechamento preenchida');
      AssertTrue(ContarLog('CAIXA', LCaixa, 'FECHAMENTO') = 1,
        'fechamento deve gerar auditoria');
      AssertTrue(RecusouFechar(LCaixa),
        'não pode fechar um caixa já fechado');
      AssertTrue(QuaseIgual(130, LService.SaldoCaixa(LCaixa)),
        'saldo continua consultável após o fechamento');

      LMov := MovimentoDoCaixa(LCaixa, 'S');
      AssertTrue(LMov > 0, 'movimento de apoio');

      ASuite.AddResult('TestPDVFecharCaixa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVFecharCaixa', False, E.Message);
    end;
  end;

  procedure TestQuantidadeItensInexistente;
  begin
    try
      AssertTrue(LService.QuantidadeItens(0) = 0,
        'venda 0 não tem itens');
      AssertTrue(LService.QuantidadeItens(999999999) = 0,
        'venda inexistente não tem itens');
      ASuite.AddResult('TestPDVQuantidadeItensInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVQuantidadeItensInexistente', False,
          E.Message);
    end;
  end;

  procedure TestCarregarFormasPagamento;
  var
    LFormas: TStringList;
    LIdx: Integer;
  begin
    try
      LFormas := TStringList.Create;
      try
        LService.CarregarFormasPagamento(LFormas);
        AssertTrue(LFormas.Count >= 7,
          'deve carregar as formas ativas do banco');
        LIdx := LFormas.IndexOf('Dinheiro');
        AssertTrue(LIdx >= 0, 'Dinheiro deve estar na lista');
        AssertTrue(Int64(PtrInt(LFormas.Objects[LIdx])) = 1,
          'o ID da forma vai em Objects');
        AssertTrue(RecusouFormasNil,
          'lista nula deve ser recusada');
      finally
        LFormas.Free;
      end;
      ASuite.AddResult('TestPDVCarregarFormasPagamento', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVCarregarFormasPagamento', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Validações da venda
  // ------------------------------------------------------------------

  procedure TestRecusarSemItens;
  var
    LCaixa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      LItens := nil;
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' SEM'),
        'venda sem itens deve ser recusada');
      SetLength(LItens, 0);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' SEM'),
        'venda com lista vazia deve ser recusada');
      ASuite.AddResult('TestPDVRecusarSemItens', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarSemItens', False, E.Message);
    end;
  end;

  procedure TestRecusarCaixaInvalido;
  var
    LCaixaOk, LCaixaFechado, LCaixaOutraEmpresa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixaOk := CriarCaixaAberto(LNumero, 0);
      LCaixaFechado := InserirCaixa(NovoNumeroCaixa, LSessao.EmpresaId,
        LUsuarioFixo, 'F', 0);
      LCaixaOutraEmpresa := InserirCaixa(NovoNumeroCaixa, 999999,
        LUsuarioFixo, 'A', 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, 10);

      AssertTrue(RecusouVenda(0, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' CX0'),
        'caixa 0 deve ser recusado');
      AssertTrue(RecusouVenda(999999999, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' CXIN'),
        'caixa inexistente deve ser recusado');
      AssertTrue(RecusouVenda(LCaixaFechado, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' CXF'),
        'caixa fechado deve ser recusado');
      AssertTrue(RecusouVenda(LCaixaOutraEmpresa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' CXE'),
        'caixa de outra empresa deve ser recusado');
      AssertTrue(LCaixaOk > 0, 'caixa de apoio');
      ASuite.AddResult('TestPDVRecusarCaixaInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarCaixaInvalido', False, E.Message);
    end;
  end;

  procedure TestRecusarProdutoInvalido;
  var
    LCaixa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(0, 1, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' P0'),
        'produto 0 deve ser recusado');
      LItens[0] := ItemPDV(999999999, 1, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' PIN'),
        'produto inexistente deve ser recusado');
      LItens[0] := ItemPDV(LProdutoInativo, 1, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' PINA'),
        'produto inativo deve ser recusado');
      LItens[0] := ItemPDV(LProdutoOutraEmpresa, 1, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' POUT'),
        'produto de outra empresa deve ser recusado');
      ASuite.AddResult('TestPDVRecusarProdutoInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarProdutoInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRecusarQuantidadeInvalida;
  var
    LCaixa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 0, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' Q0'),
        'quantidade zero deve ser recusada');
      LItens[0] := ItemPDV(LProdutoA, -1, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' QN'),
        'quantidade negativa deve ser recusada');
      ASuite.AddResult('TestPDVRecusarQuantidadeInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarQuantidadeInvalida', False,
          E.Message);
    end;
  end;

  procedure TestRecusarPrecoNegativo;
  var
    LCaixa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, -1);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        'PDV ' + LSufixo + ' PRN'),
        'preço unitário negativo deve ser recusado');
      ASuite.AddResult('TestPDVRecusarPrecoNegativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarPrecoNegativo', False, E.Message);
    end;
  end;

  procedure TestRecusarDescontoNegativo;
  var
    LCaixa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, -1, 1, LCliente,
        'PDV ' + LSufixo + ' DN'),
        'desconto negativo deve ser recusado');
      ASuite.AddResult('TestPDVRecusarDescontoNegativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarDescontoNegativo', False,
          E.Message);
    end;
  end;

  procedure TestRecusarClienteInvalido;
  var
    LCaixa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, 10);

      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, 999999999,
        'PDV ' + LSufixo + ' CIN'),
        'cliente inexistente deve ser recusado');
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LClienteInativo,
        'PDV ' + LSufixo + ' CINA'),
        'cliente inativo deve ser recusado');
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LFornecedor,
        'PDV ' + LSufixo + ' CF'),
        'pessoa tipo F não pode ser cliente');
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LClienteOutraEmpresa,
        'PDV ' + LSufixo + ' COUT'),
        'cliente de outra empresa deve ser recusado');

      ASuite.AddResult('TestPDVRecusarClienteInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarClienteInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRecusarObservacoesLongas;
  var
    LCaixa: Int64;
    LItens: TItensPDVEntrada;
    LNumero: string;
  begin
    try
      LCaixa := CriarCaixaAberto(LNumero, 0);
      SetLength(LItens, 1);
      LItens[0] := ItemPDV(LProdutoA, 1, 10);
      AssertTrue(RecusouVenda(LCaixa, LItens, 0, 1, LCliente,
        StringOfChar('X', 256)),
        'observações com mais de 255 caracteres devem ser recusadas');
      ASuite.AddResult('TestPDVRecusarObservacoesLongas', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPDVRecusarObservacoesLongas', False,
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

  procedure LimparUsuarioFixo;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM MOVIMENTO_CAIXA WHERE CAIXA_ID IN (' +
        '  SELECT ID FROM CAIXA WHERE USUARIO_ID = :USR)';
      LQuery.ParamByName('USR').AsLargeInt := LUsuarioFixo;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
    end;
    try
      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM CAIXA WHERE USUARIO_ID = :USR';
      LQuery.ParamByName('USR').AsLargeInt := LUsuarioFixo;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
    end;
  end;

  procedure LimparSobraPorSufixo;
  begin
    LimparUsuarioFixo;
    try
      ExecSufixo(
        'DELETE FROM ITEM_PEDIDO_GRADE WHERE ITEM_PEDIDO_ID IN (' +
        '  SELECT I.ID FROM ITEM_PEDIDO I ' +
        '  JOIN PEDIDO_VENDA P ON P.ID = I.PEDIDO_VENDA_ID ' +
        '  WHERE P.OBSERVACOES CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID IN (' +
        '  SELECT ID FROM PEDIDO_VENDA WHERE OBSERVACOES CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM MOVIMENTO_CAIXA WHERE CAIXA_ID IN (' +
        '  SELECT ID FROM CAIXA WHERE NUMERO CONTAINING :P1)');
    except
    end;
    try
      ExecSufixo('DELETE FROM PEDIDO_VENDA WHERE OBSERVACOES CONTAINING :P1');
    except
    end;
    try
      ExecSufixo('DELETE FROM CAIXA WHERE NUMERO CONTAINING :P1');
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
    if not LConsumidorExistia then
    begin
      try
        LQuery.Close;
        LQuery.SQL.Text :=
          'DELETE FROM PESSOA WHERE EMPRESA_ID = :EMP ' +
          '  AND UPPER(NOME) = ''CONSUMIDOR FINAL''';
        LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      except
      end;
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
  LLista := TSQLQuery.Create(nil);
  LService := TPDVService.Create;
  LCaixaService := TCaixaService.Create;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LUsuarioFixo := 990001;
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LLista.DataBase := LConexao.Connection;
    LLista.Transaction := LConexao.Transaction;

    LTopoLog := 0;
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM LOG_SISTEMA ORDER BY ID DESC';
    LQuery.Open;
    if not LQuery.IsEmpty then
      LTopoLog := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;

    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM PESSOA WHERE EMPRESA_ID = :EMP ' +
      '  AND UPPER(NOME) = ''CONSUMIDOR FINAL''';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.Open;
    LConsumidorExistia := not LQuery.IsEmpty;
    LQuery.Close;

    // resíduo de execução anterior interrompida (usuário exclusivo dos testes)
    LimparUsuarioFixo;

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DO PDV');
    WriteLn('========================================');

    LCliente := CriarPessoa(NovoNome('CLIENTE PDV'), 'C', 'A',
      LSessao.EmpresaId);
    LClienteInativo := CriarPessoa(NovoNome('CLIENTE PDV INATIVO'), 'C',
      'I', LSessao.EmpresaId);
    LFornecedor := CriarPessoa(NovoNome('FORNECEDOR PDV'), 'F', 'A',
      LSessao.EmpresaId);
    LClienteOutraEmpresa := CriarPessoa(NovoNome('CLIENTE PDV OUTRA'),
      'C', 'A', 999999);

    LProdutoA := CriarProduto(NovoNome('PRODUTO PDV A'),
      'PDVCOD' + Copy(LSufixo, 1, 10), '789' + Copy(LSufixo, 1, 10),
      'A', LSessao.EmpresaId, 10);
    LProdutoB := CriarProduto(NovoNome('PRODUTO PDV B'),
      'PDVCOB' + Copy(LSufixo, 1, 10), '788' + Copy(LSufixo, 1, 10),
      'A', LSessao.EmpresaId, 5);
    LProdutoInativo := CriarProduto(NovoNome('PRODUTO PDV INATIVO'),
      'PDVINA' + Copy(LSufixo, 1, 10), '787' + Copy(LSufixo, 1, 10),
      'I', LSessao.EmpresaId, 10);
    LProdutoOutraEmpresa := CriarProduto(NovoNome('PRODUTO PDV OUTRA'),
      'PDVOUT' + Copy(LSufixo, 1, 10), '786' + Copy(LSufixo, 1, 10),
      'A', 999999, 10);

    TestTotais;
    TestProximoNumeroVenda;
    TestAbrirCaixa;
    TestAbrirCaixaDuplicado;
    TestAbrirCaixaValorNegativo;
    TestCaixaAberto;
    TestProximoNumeroCaixa;
    TestBuscarProdutoPorCodigo;
    TestBuscarProdutoPorBarras;
    TestBuscarProdutoInativo;
    TestBuscarProdutoOutraEmpresa;
    TestBuscarProdutoInexistente;
    TestSalvarVendaCompleta;
    TestSalvarVendaConsumidorFinal;
    TestSalvarVendaMultiplosItens;
    TestSalvarVendaDescontoMaior;
    TestSalvarVendaNumeroAutomatico;
    TestSaldoCaixa;
    TestRegistrarMovimento;
    TestRegistrarMovimentoTipoInvalido;
    TestRegistrarMovimentoValorInvalido;
    TestRegistrarMovimentoCaixaInvalido;
    TestRegistrarMovimentoDescricaoLonga;
    TestFecharCaixa;
    TestQuantidadeItensInexistente;
    TestCarregarFormasPagamento;
    TestRecusarSemItens;
    TestRecusarCaixaInvalido;
    TestRecusarProdutoInvalido;
    TestRecusarQuantidadeInvalida;
    TestRecusarPrecoNegativo;
    TestRecusarDescontoNegativo;
    TestRecusarClienteInvalido;
    TestRecusarObservacoesLongas;
  finally
    LimparSobraPorSufixo;
    LCaixaService.Free;
    LService.Free;
    LLista.Free;
    LQuery.Free;
  end;
end;

end.
