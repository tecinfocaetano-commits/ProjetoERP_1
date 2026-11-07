unit uContasTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes de contas a pagar e a receber
  ------------------------------------------------------------
  Cobre TContasService (extraído de uFrmContasPagar e
  uFrmContasReceber):
    - plano financeiro: reutiliza o primeiro FINANCEIRO da empresa
      por tipo e cria o padrão quando não existe;
    - criação: grava FINANCEIRO_ID/FORNECEDOR_ID/CLIENTE_ID (domínio
      DM_ID NOT NULL), status 'A', parcela 1, valor e vencimento;
      recusa descrição vazia, valor <= 0 e vencimento zerado;
    - baixa: só conta em aberto; grava STATUS 'P', DATA_PAGAMENTO e
      VALOR_PAGO = VALOR; recusa inexistente, paga e cancelada;
    - listagem: período, status, pesquisa por nome/descrição (texto
      longo), ordem de vencimento e escopo da empresa da sessão;
    - auditoria INSERT/BAIXA em LOG_SISTEMA.

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco. O Service abre e confirma a
  própria transação; a limpeza corta o LOG_SISTEMA no topo capturado
  antes da suíte.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao, uContasService;

type
  { TContasTest }
  TContasTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

uses
  DateUtils;

{ TContasTest }

class procedure TContasTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LContas: TContasService;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;
  LFinanceiroPagarId: Int64;
  LFinanceiroReceberId: Int64;

  function QuaseIgual(A, B: Double): Boolean;
  begin
    Result := Abs(A - B) < 0.001;
  end;

  function NovaDescricao(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  function ContarContas(const ATabela: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM ' + ATabela;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarPorDescricao(const ATabela, ADescricao: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM ' + ATabela + ' WHERE DESCRICAO = :DESC';
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
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

  function DataPorId(const ASQL: string; AId: Int64): TDateTime;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsDateTime;
    LQuery.Close;
  end;

  function ContarLog(const ATabela, AOperacao: string; ARegistroId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM LOG_SISTEMA WHERE TABELA = :TAB ' +
      '  AND OPERACAO = :OP AND REGISTRO_ID = :REG';
    LQuery.ParamByName('TAB').AsString := ATabela;
    LQuery.ParamByName('OP').AsString := AOperacao;
    LQuery.ParamByName('REG').AsLargeInt := ARegistroId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  { Cria uma conta a pagar com vencimento relativo a hoje. }
  function CriarPagar(const ADescricao: string; ADiasVencimento: Integer;
    AValor: Double): Int64;
  begin
    Result := LContas.CriarContaPagar(ADescricao, AValor,
      Trunc(Now) + ADiasVencimento);
  end;

  function CriarReceber(const ADescricao: string; ADiasVencimento: Integer;
    AValor: Double): Int64;
  begin
    Result := LContas.CriarContaReceber(ADescricao, AValor,
      Trunc(Now) + ADiasVencimento);
  end;

  function AchouNaLista(const ADescricao: string): Boolean;
  begin
    Result := False;
    LLista.First;
    while not LLista.EOF do
    begin
      if Trim(LLista.FieldByName('DESCRICAO').AsString) = ADescricao then
      begin
        Result := True;
        Exit;
      end;
      LLista.Next;
    end;
  end;

  function ContarLinhas: Integer;
  begin
    Result := 0;
    LLista.First;
    while not LLista.EOF do
    begin
      Inc(Result);
      LLista.Next;
    end;
  end;

  // ------------------------------------------------------------------
  // Criação
  // ------------------------------------------------------------------

  procedure TestCriarContaPagar;
  var
    LId: Int64;
    LDescricao: string;
    LVencimento: TDateTime;
  begin
    try
      LDescricao := NovaDescricao('CONTA PAGAR');
      LVencimento := Trunc(Now) + 10;
      LId := LContas.CriarContaPagar(LDescricao, 123.45, LVencimento);

      AssertTrue(LId > 0, 'CriarContaPagar deve devolver o ID');
      AssertEquals('1', IntToStr(ContarPorDescricao('CONTA_PAGAR', LDescricao)),
        'a conta deve existir uma vez');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        TextoPorId('SELECT CAST(EMPRESA_ID AS VARCHAR(20)) AS VALOR ' +
          'FROM CONTA_PAGAR WHERE ID = :ID', LId),
        'a conta deve pertencer à empresa da sessão');
      AssertEquals(IntToStr(LFinanceiroPagarId),
        TextoPorId('SELECT CAST(FINANCEIRO_ID AS VARCHAR(20)) AS VALOR ' +
          'FROM CONTA_PAGAR WHERE ID = :ID', LId),
        'FINANCEIRO_ID deve apontar para o plano de contas a pagar');
      AssertEquals('0',
        TextoPorId('SELECT CAST(FORNECEDOR_ID AS VARCHAR(20)) AS VALOR ' +
          'FROM CONTA_PAGAR WHERE ID = :ID', LId),
        'sem fornecedor o vínculo deve ser 0');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId),
        'a conta deve nascer aberta');
      AssertEquals('1', TextoPorId(
        'SELECT CAST(PARCELA AS VARCHAR(20)) AS VALOR ' +
        'FROM CONTA_PAGAR WHERE ID = :ID', LId),
        'a conta deve nascer na parcela 1');
      AssertTrue(QuaseIgual(123.45, FloatPorId(
        'SELECT VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId)),
        'o valor deve ser gravado');
      AssertTrue(Trunc(DataPorId(
        'SELECT DATA_VENCIMENTO AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId)) =
        Trunc(LVencimento), 'o vencimento deve ser gravado');
      AssertTrue(ContarLog('CONTA_PAGAR', 'INSERT', LId) = 1,
        'a criação deve gerar auditoria INSERT');

      ASuite.AddResult('TestContasCriarContaPagar', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCriarContaPagar', False, E.Message);
    end;
  end;

  procedure TestCriarContaPagarDescricaoVazia;
  var
    LAntes: Integer;
    LDeu: Boolean;
  begin
    try
      LAntes := ContarContas('CONTA_PAGAR');
      LDeu := False;
      try
        LContas.CriarContaPagar('   ', 10, Trunc(Now) + 5);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'descrição vazia deve ser recusada');
      AssertEquals(IntToStr(LAntes), IntToStr(ContarContas('CONTA_PAGAR')),
        'nada deve ser gravado');
      ASuite.AddResult('TestContasCriarContaPagarDescricaoVazia', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCriarContaPagarDescricaoVazia', False,
          E.Message);
    end;
  end;

  procedure TestCriarContaPagarValorInvalido;
  var
    LAntes: Integer;
    LDeu: Boolean;
  begin
    try
      LAntes := ContarContas('CONTA_PAGAR');
      LDeu := False;
      try
        LContas.CriarContaPagar(NovaDescricao('CONTA PAGAR ZERO'), 0,
          Trunc(Now) + 5);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'valor zero deve ser recusado');
      AssertEquals(IntToStr(LAntes), IntToStr(ContarContas('CONTA_PAGAR')),
        'nada deve ser gravado');
      ASuite.AddResult('TestContasCriarContaPagarValorInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCriarContaPagarValorInvalido', False,
          E.Message);
    end;
  end;

  procedure TestCriarContaPagarVencimentoZero;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LContas.CriarContaPagar(NovaDescricao('CONTA PAGAR SEM VENC'), 10, 0);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'vencimento zerado deve ser recusado');
      ASuite.AddResult('TestContasCriarContaPagarVencimentoZero', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCriarContaPagarVencimentoZero', False,
          E.Message);
    end;
  end;

  procedure TestCriarContaReceber;
  var
    LId: Int64;
    LDescricao: string;
  begin
    try
      LDescricao := NovaDescricao('CONTA RECEBER');
      LId := LContas.CriarContaReceber(LDescricao, 98.70, Trunc(Now) + 12);

      AssertTrue(LId > 0, 'CriarContaReceber deve devolver o ID');
      AssertEquals(IntToStr(LFinanceiroReceberId),
        TextoPorId('SELECT CAST(FINANCEIRO_ID AS VARCHAR(20)) AS VALOR ' +
          'FROM CONTA_RECEBER WHERE ID = :ID', LId),
        'FINANCEIRO_ID deve ser gravado (DM_ID NOT NULL)');
      AssertEquals('0',
        TextoPorId('SELECT CAST(CLIENTE_ID AS VARCHAR(20)) AS VALOR ' +
          'FROM CONTA_RECEBER WHERE ID = :ID', LId),
        'sem cliente o vínculo deve ser 0');
      AssertEquals('A', TextoPorId(
        'SELECT STATUS AS VALOR FROM CONTA_RECEBER WHERE ID = :ID', LId),
        'a conta deve nascer aberta');
      AssertTrue(QuaseIgual(98.70, FloatPorId(
        'SELECT VALOR FROM CONTA_RECEBER WHERE ID = :ID', LId)),
        'o valor deve ser gravado');
      AssertTrue(ContarLog('CONTA_RECEBER', 'INSERT', LId) = 1,
        'a criação deve gerar auditoria INSERT');

      ASuite.AddResult('TestContasCriarContaReceber', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCriarContaReceber', False, E.Message);
    end;
  end;

  procedure TestCriarContaReceberComCliente;
  var
    LId: Int64;
    LDescricao: string;
  begin
    try
      LDescricao := NovaDescricao('CONTA RECEBER CLIENTE');
      LId := LContas.CriarContaReceber(LDescricao, 50, Trunc(Now) + 12, 12345);
      AssertEquals('12345',
        TextoPorId('SELECT CAST(CLIENTE_ID AS VARCHAR(20)) AS VALOR ' +
          'FROM CONTA_RECEBER WHERE ID = :ID', LId),
        'o cliente informado deve ser gravado');
      ASuite.AddResult('TestContasCriarContaReceberComCliente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCriarContaReceberComCliente', False,
          E.Message);
    end;
  end;

  procedure TestGarantirFinanceiroReutiliza;
  var
    LPagar1, LPagar2, LReceber1, LReceber2: Int64;
  begin
    try
      LPagar1 := LContas.GarantirFinanceiroPagar;
      LPagar2 := LContas.GarantirFinanceiroPagar;
      LReceber1 := LContas.GarantirFinanceiroReceber;
      LReceber2 := LContas.GarantirFinanceiroReceber;

      AssertTrue(LPagar1 > 0, 'o plano de contas a pagar deve existir');
      AssertTrue(LPagar1 = LPagar2,
        'chamar duas vezes deve reutilizar o mesmo plano');
      AssertTrue(LReceber1 > 0, 'o plano de contas a receber deve existir');
      AssertTrue(LReceber1 = LReceber2,
        'chamar duas vezes deve reutilizar o mesmo plano');
      AssertTrue(LPagar1 <> LReceber1,
        'os planos de pagar e receber devem ser distintos');
      AssertEquals('P', TextoPorId(
        'SELECT TIPO AS VALOR FROM FINANCEIRO WHERE ID = :ID', LPagar1),
        'o plano de pagar deve ter TIPO P');
      AssertEquals('R', TextoPorId(
        'SELECT TIPO AS VALOR FROM FINANCEIRO WHERE ID = :ID', LReceber1),
        'o plano de receber deve ter TIPO R');

      ASuite.AddResult('TestContasGarantirFinanceiroReutiliza', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasGarantirFinanceiroReutiliza', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Baixa
  // ------------------------------------------------------------------

  procedure TestBaixarContaPagar;
  var
    LId: Int64;
    LDescricao: string;
  begin
    try
      LDescricao := NovaDescricao('BAIXA PAGAR');
      LId := CriarPagar(LDescricao, 8, 321.99);
      LContas.BaixarContaPagar(LId);

      AssertEquals('P', TextoPorId(
        'SELECT STATUS AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId),
        'a baixa deve deixar a conta paga');
      AssertFalse(DataPorId(
        'SELECT DATA_PAGAMENTO AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId) = 0,
        'a baixa deve gravar a data de pagamento');
      AssertTrue(QuaseIgual(321.99, FloatPorId(
        'SELECT VALOR_PAGO AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId)),
        'VALOR_PAGO deve receber o valor da conta');
      AssertTrue(ContarLog('CONTA_PAGAR', 'BAIXA', LId) = 1,
        'a baixa deve gerar auditoria BAIXA');

      ASuite.AddResult('TestContasBaixarContaPagar', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasBaixarContaPagar', False, E.Message);
    end;
  end;

  procedure TestBaixarContaPagarJaPaga;
  var
    LId: Int64;
    LDeu: Boolean;
    LValorPago: Double;
  begin
    try
      LId := CriarPagar(NovaDescricao('BAIXA DUPLA'), 9, 77.50);
      LContas.BaixarContaPagar(LId);
      LValorPago := FloatPorId(
        'SELECT VALOR_PAGO AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId);

      LDeu := False;
      try
        LContas.BaixarContaPagar(LId);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'baixar conta já paga deve ser recusado');
      AssertTrue(QuaseIgual(LValorPago, FloatPorId(
        'SELECT VALOR_PAGO AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId)),
        'a segunda baixa não pode alterar o valor pago');

      ASuite.AddResult('TestContasBaixarContaPagarJaPaga', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasBaixarContaPagarJaPaga', False,
          E.Message);
    end;
  end;

  procedure TestBaixarContaPagarInexistente;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LContas.BaixarContaPagar(999999999);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'conta inexistente deve ser recusada');

      LDeu := False;
      try
        LContas.BaixarContaPagar(0);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'ID inválido deve ser recusado');

      ASuite.AddResult('TestContasBaixarContaPagarInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasBaixarContaPagarInexistente', False,
          E.Message);
    end;
  end;

  procedure TestBaixarContaPagarCancelada;
  var
    LId: Int64;
    LDeu: Boolean;
  begin
    try
      LId := CriarPagar(NovaDescricao('BAIXA CANCELADA'), 11, 60);
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE CONTA_PAGAR SET STATUS = ''C'' WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LId;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      LDeu := False;
      try
        LContas.BaixarContaPagar(LId);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'conta cancelada não pode ser baixada');
      AssertEquals('C', TextoPorId(
        'SELECT STATUS AS VALOR FROM CONTA_PAGAR WHERE ID = :ID', LId),
        'o status cancelada deve ser preservado');

      ASuite.AddResult('TestContasBaixarContaPagarCancelada', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasBaixarContaPagarCancelada', False,
          E.Message);
    end;
  end;

  procedure TestBaixarContaReceber;
  var
    LId: Int64;
    LDeu: Boolean;
  begin
    try
      LId := CriarReceber(NovaDescricao('BAIXA RECEBER'), 7, 45.60);
      LContas.BaixarContaReceber(LId);

      AssertEquals('P', TextoPorId(
        'SELECT STATUS AS VALOR FROM CONTA_RECEBER WHERE ID = :ID', LId),
        'a baixa deve deixar a conta paga');
      AssertFalse(DataPorId(
        'SELECT DATA_PAGAMENTO AS VALOR FROM CONTA_RECEBER WHERE ID = :ID', LId) = 0,
        'a baixa deve gravar a data de pagamento');
      AssertTrue(QuaseIgual(45.60, FloatPorId(
        'SELECT VALOR_PAGO AS VALOR FROM CONTA_RECEBER WHERE ID = :ID', LId)),
        'VALOR_PAGO deve receber o valor da conta');
      AssertTrue(ContarLog('CONTA_RECEBER', 'BAIXA', LId) = 1,
        'a baixa deve gerar auditoria BAIXA');

      LDeu := False;
      try
        LContas.BaixarContaReceber(LId);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'baixar conta já paga deve ser recusado');

      ASuite.AddResult('TestContasBaixarContaReceber', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasBaixarContaReceber', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Listagem
  // ------------------------------------------------------------------

  procedure TestCarregarContasPagar;
  var
    LPaga, LAberta, LFora: Int64;
    LVencAberta, LVencPaga: TDateTime;
    LPrimeiraData: TDateTime;
    LToken: string;
  begin
    try
      LToken := 'JANELA ' + LSufixo;
      LVencPaga := Trunc(Now) + 5;
      LVencAberta := Trunc(Now) + 15;
      LPaga := LContas.CriarContaPagar(LToken + ' PAGA', 500, LVencPaga);
      LAberta := LContas.CriarContaPagar(LToken + ' ABERTA', 300, LVencAberta);
      LFora := LContas.CriarContaPagar(LToken + ' FORA', 200,
        Trunc(Now) + 90);
      LContas.BaixarContaPagar(LPaga);

      { texto com mais de 20 caracteres prova o CAST do filtro }
      LContas.CarregarContasPagar(LLista, Trunc(Now), Trunc(Now) + 30,
        '', LToken);
      AssertTrue(ContarLinhas = 2,
        'o período deve trazer as duas contas dentro da janela; veio ' +
        IntToStr(ContarLinhas));
      AssertTrue(AchouNaLista(LToken + ' ABERTA'),
        'a conta aberta deve aparecer');
      AssertFalse(AchouNaLista(LToken + ' FORA'),
        'a conta fora do período não deve aparecer');

      LLista.First;
      AssertEquals('Paga',
        Trim(LLista.FieldByName('STATUS_DESC').AsString),
        'a conta de vencimento menor deve vir primeiro, já paga');
      LPrimeiraData := LLista.FieldByName('DATA_VENCIMENTO').AsDateTime;
      LLista.Next;
      if not LLista.EOF then
      begin
        AssertTrue(Trunc(LPrimeiraData) <=
          Trunc(LLista.FieldByName('DATA_VENCIMENTO').AsDateTime),
          'as contas devem vir em ordem de vencimento');
        AssertEquals('Aberta',
          Trim(LLista.FieldByName('STATUS_DESC').AsString),
          'a segunda conta deve estar aberta');
      end;

      LContas.CarregarContasPagar(LLista, Trunc(Now), Trunc(Now) + 30,
        'P', LToken);
      AssertTrue(ContarLinhas = 1,
        'o filtro de status P deve trazer só a conta paga');
      AssertTrue(AchouNaLista(LToken + ' PAGA'),
        'a conta paga deve aparecer no filtro P');

      LContas.CarregarContasPagar(LLista, Trunc(Now), Trunc(Now) + 30,
        'A', LToken);
      AssertTrue(ContarLinhas = 1,
        'o filtro de status A deve trazer só a conta aberta');
      AssertTrue(AchouNaLista(LToken + ' ABERTA'),
        'a conta aberta deve aparecer no filtro A');

      ASuite.AddResult('TestContasCarregarContasPagar', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCarregarContasPagar', False, E.Message);
    end;
  end;

  procedure TestCarregarContasPagarEscopoEmpresa;
  var
    LDescricao: string;
  begin
    try
      LDescricao := NovaDescricao('LISTA OUTRA EMPRESA');
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO CONTA_PAGAR (EMPRESA_ID, FINANCEIRO_ID, FORNECEDOR_ID, ' +
        '  DESCRICAO, VALOR, DATA_VENCIMENTO, STATUS, PARCELA) ' +
        'VALUES (999999, :FIN, 0, :DESC, 10, :VENC, ''A'', 1)';
      LQuery.ParamByName('FIN').AsLargeInt := LFinanceiroPagarId;
      LQuery.ParamByName('DESC').AsString := LDescricao;
      LQuery.ParamByName('VENC').AsDate := Trunc(Now) + 5;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      LContas.CarregarContasPagar(LLista, Trunc(Now), Trunc(Now) + 30,
        '', LDescricao);
      AssertTrue(ContarLinhas = 0,
        'conta de outra empresa não pode aparecer na listagem');

      ASuite.AddResult('TestContasCarregarContasPagarEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCarregarContasPagarEscopoEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestCarregarContasReceber;
  var
    LId: Int64;
    LDescricao: string;
    LToken: string;
  begin
    try
      LToken := 'JANELA RECEBER ' + LSufixo;
      LDescricao := LToken + ' ABERTA';
      LId := LContas.CriarContaReceber(LDescricao, 250, Trunc(Now) + 6);

      LContas.CarregarContasReceber(LLista, Trunc(Now), Trunc(Now) + 30,
        '', LToken);
      AssertTrue(ContarLinhas = 1,
        'a conta a receber do período deve aparecer sozinha');
      AssertTrue(AchouNaLista(LDescricao),
        'a conta criada deve estar na listagem');
      AssertEquals('Aberta',
        Trim(LLista.FieldByName('STATUS_DESC').AsString),
        'o status deve vir traduzido');
      AssertEquals('0',
        TextoPorId('SELECT CAST(CLIENTE_ID AS VARCHAR(20)) AS VALOR ' +
          'FROM CONTA_RECEBER WHERE ID = :ID', LId),
        'o vínculo de cliente deve continuar 0');

      LContas.CarregarContasReceber(LLista, Trunc(Now), Trunc(Now) + 30,
        'P', LToken);
      AssertTrue(ContarLinhas = 0,
        'nenhuma conta a receber desta rodada está paga');

      ASuite.AddResult('TestContasCarregarContasReceber', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCarregarContasReceber', False, E.Message);
    end;
  end;

  procedure TestCarregarContasValidacoes;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LContas.CarregarContasPagar(nil, Trunc(Now), Trunc(Now) + 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'listagem sem query deve ser recusada');

      LDeu := False;
      try
        LContas.CarregarContasReceber(LLista, Trunc(Now) + 10, Trunc(Now));
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'período invertido deve ser recusado');

      ASuite.AddResult('TestContasCarregarContasValidacoes', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestContasCarregarContasValidacoes', False,
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
        'DELETE FROM CONTA_PAGAR WHERE DESCRICAO CONTAINING :P1');
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM CONTA_RECEBER WHERE DESCRICAO CONTAINING :P1');
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
  LLista := TSQLQuery.Create(nil);
  LContas := TContasService.Create;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
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

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DE CONTAS A PAGAR/RECEBER');
    WriteLn('========================================');

    LConexao.IniciarTransacao;
    try
      LFinanceiroPagarId := LContas.GarantirFinanceiroPagar;
      LFinanceiroReceberId := LContas.GarantirFinanceiroReceber;
    finally
      LConexao.Confirmar;
    end;

    TestGarantirFinanceiroReutiliza;
    TestCriarContaPagar;
    TestCriarContaPagarDescricaoVazia;
    TestCriarContaPagarValorInvalido;
    TestCriarContaPagarVencimentoZero;
    TestCriarContaReceber;
    TestCriarContaReceberComCliente;
    TestBaixarContaPagar;
    TestBaixarContaPagarJaPaga;
    TestBaixarContaPagarInexistente;
    TestBaixarContaPagarCancelada;
    TestBaixarContaReceber;
    TestCarregarContasPagar;
    TestCarregarContasPagarEscopoEmpresa;
    TestCarregarContasReceber;
    TestCarregarContasValidacoes;
  finally
    LimparSobraPorSufixo;
    LContas.Free;
    LLista.Free;
    LQuery.Free;
  end;
end;

end.
