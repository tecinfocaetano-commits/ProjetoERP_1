unit uCaixaTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do Service do Caixa (Financeiro)
  ------------------------------------------------------------
  Cobre TCaixaService, que é somente leitura:
    - CarregarCaixas: saldo por caixa (entradas 'E' menos saídas
      'S'; 'G'/'P' não entram no saldo), número como texto, nome do
      usuário, status/datas, escopo da empresa da sessão (inclui
      EMPRESA_ID nulo), ordenação por ID decrescente e filtro por
      número/usuário;
    - CarregarMovimentos: tradução do TIPO (E→ENTRADA, S→SAIDA,
      G/P mantidos), ordenação por ID e filtros por descrição, tipo
      e usuário;
    - CarregarResumo: ENTRADAS, SAIDAS e SALDO com CAST numérico;
    - validações de query nula e caixa inválido.

  Padrão da suíte: dados com sufixo de timestamp e limpeza explícita
  no finally, sem mock de banco. O Service não grava nem audita; os
  fixtures são confirmados para ficarem visíveis às consultas.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao, uCaixaService;

type
  { TCaixaTest }
  TCaixaTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TCaixaTest }

class procedure TCaixaTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LService: TCaixaService;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;

  function QuaseIgual(A, B: Double): Boolean;
  begin
    Result := Abs(A - B) < 0.001;
  end;

  function NovoNumero: string;
  begin
    Inc(LSeq);
    Result := 'CX' + Copy(LSufixo, 1, 8) + '-' + IntToStr(LSeq);
  end;

  function InserirCaixa(const ANumero: string; AEmpresaId, AUsuarioId: Int64;
    AStatus: Char; AValorAbertura: Double): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO CAIXA (EMPRESA_ID, USUARIO_ID, NUMERO, DATA_ABERTURA, ' +
      '  VALOR_ABERTURA, STATUS, OBSERVACOES) ' +
      'VALUES (:EMP, :USU, :NUM, CURRENT_TIMESTAMP, :VALOR, :STATUS, :OBS) ' +
      'RETURNING ID';
    if AEmpresaId > 0 then
      LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId
    else
      LQuery.ParamByName('EMP').Clear;
    if AUsuarioId > 0 then
      LQuery.ParamByName('USU').AsLargeInt := AUsuarioId
    else
      LQuery.ParamByName('USU').Clear;
    LQuery.ParamByName('NUM').AsString := ANumero;
    LQuery.ParamByName('VALOR').AsFloat := AValorAbertura;
    LQuery.ParamByName('STATUS').AsString := AStatus;
    LQuery.ParamByName('OBS').AsString := 'TESTE CAIXA ' + LSufixo;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
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
    if AUsuarioId > 0 then
      LQuery.ParamByName('USU').AsLargeInt := AUsuarioId
    else
      LQuery.ParamByName('USU').Clear;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  { Posiciona LLista no caixa de número informado; devolve False se
    não estiver no resultado (útil para provar o escopo da empresa). }
  function LocalizarCaixa(const ANumero: string; out ASaldo: Double;
    out AUsuario: string): Boolean;
  begin
    Result := False;
    ASaldo := 0;
    AUsuario := '';
    LLista.First;
    while not LLista.EOF do
    begin
      if Trim(LLista.FieldByName('NUMERO').AsString) = ANumero then
      begin
        ASaldo := LLista.FieldByName('SALDO').AsFloat;
        AUsuario := Trim(LLista.FieldByName('USUARIO').AsString);
        Result := True;
        Exit;
      end;
      LLista.Next;
    end;
  end;

  function ContarMovimentos: Integer;
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
  // Fixtures
  // ------------------------------------------------------------------

  function InserirCaixaComMovimentos(out ANumero: string): Int64;
  begin
    ANumero := NovoNumero;
    Result := InserirCaixa(ANumero, LSessao.EmpresaId, LSessao.UsuarioId,
      'A', 150);
    InserirMovimento(Result, 'E', 100.25, 'Venda teste', LSessao.UsuarioId);
    InserirMovimento(Result, 'S', 40.10, 'Sangria teste', LSessao.UsuarioId);
    InserirMovimento(Result, 'G', 10, 'Suprimento teste', LSessao.UsuarioId);
    InserirMovimento(Result, 'P', 5, 'Pagamento teste', LSessao.UsuarioId);
  end;

  // ------------------------------------------------------------------
  // CarregarCaixas
  // ------------------------------------------------------------------

  procedure TestCarregarCaixasQueryNula;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LService.CarregarCaixas(nil);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'CarregarCaixas sem query deve levantar exceção');
      ASuite.AddResult('TestCaixaCarregarCaixasQueryNula', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasQueryNula', False, E.Message);
    end;
  end;

  procedure TestCarregarCaixasSaldo;
  var
    LCaixaId: Int64;
    LNumero: string;
    LSaldo: Double;
    LUsuario: string;
  begin
    try
      LCaixaId := InserirCaixaComMovimentos(LNumero);
      LService.CarregarCaixas(LLista, LNumero);

      AssertEquals('1', IntToStr(ContarMovimentos),
        'o filtro pelo número deve achar só o caixa criado');
      AssertTrue(LocalizarCaixa(LNumero, LSaldo, LUsuario),
        'o caixa criado deve aparecer no resultado');

      { saldo = entradas 'E' - saídas 'S'; 'G' e 'P' não entram }
      AssertTrue(QuaseIgual(60.15, LSaldo),
        'saldo deve ser 100,25 - 40,10 = 60,15 (G/P ignorados); veio ' +
        FloatToStr(LSaldo));
      AssertEquals('Administrador', LUsuario,
        'o nome do usuário deve vir do LEFT JOIN USUARIO');
      AssertEquals('A', Trim(LLista.FieldByName('STATUS').AsString),
        'o status deve ser preservado');
      AssertTrue(QuaseIgual(150, LLista.FieldByName('VALOR_ABERTURA').AsFloat),
        'o valor de abertura deve ser preservado');
      AssertFalse(LLista.FieldByName('DATA_ABERTURA').IsNull,
        'a data de abertura deve estar preenchida');

      ASuite.AddResult('TestCaixaCarregarCaixasSaldo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasSaldo', False, E.Message);
    end;
  end;

  procedure TestCarregarCaixasSemMovimento;
  var
    LCaixaId: Int64;
    LNumero: string;
    LSaldo: Double;
    LUsuario: string;
  begin
    try
      LNumero := NovoNumero;
      LCaixaId := InserirCaixa(LNumero, LSessao.EmpresaId,
        LSessao.UsuarioId, 'A', 0);
      LService.CarregarCaixas(LLista, LNumero);

      AssertTrue(LocalizarCaixa(LNumero, LSaldo, LUsuario),
        'caixa sem movimento deve aparecer');
      AssertTrue(QuaseIgual(0, LSaldo),
        'saldo de caixa sem movimento deve ser 0; veio ' + FloatToStr(LSaldo));

      ASuite.AddResult('TestCaixaCarregarCaixasSemMovimento', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasSemMovimento', False,
          E.Message);
    end;
  end;

  procedure TestCarregarCaixasFiltroUsuario;
  var
    LCaixaId: Int64;
    LNumero: string;
    LSaldo: Double;
    LUsuario: string;
    LAchou: Boolean;
  begin
    try
      LCaixaId := InserirCaixaComMovimentos(LNumero);
      LService.CarregarCaixas(LLista, 'Administrador');

      LAchou := False;
      LLista.First;
      while not LLista.EOF do
      begin
        if Trim(LLista.FieldByName('NUMERO').AsString) = LNumero then
          LAchou := True;
        LLista.Next;
      end;
      AssertTrue(LAchou, 'o filtro por usuário deve achar o caixa criado');
      AssertTrue(ContarMovimentos >= 1,
        'o filtro por usuário deve retornar ao menos uma linha');

      ASuite.AddResult('TestCaixaCarregarCaixasFiltroUsuario', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasFiltroUsuario', False,
          E.Message);
    end;
  end;

  procedure TestCarregarCaixasFiltroInexistente;
  begin
    try
      LService.CarregarCaixas(LLista, 'NAO EXISTE ' + LSufixo);
      AssertEquals('0', IntToStr(ContarMovimentos),
        'filtro sem correspondência deve devolver zero linhas');
      ASuite.AddResult('TestCaixaCarregarCaixasFiltroInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasFiltroInexistente', False,
          E.Message);
    end;
  end;

  procedure TestCarregarCaixasEscopoEmpresa;
  var
    LNumeroOutra: string;
    LSaldo: Double;
    LUsuario: string;
  begin
    try
      { empresa 999999 não existe e não há FK no banco real; o filtro
        precisa excluir mesmo assim }
      LNumeroOutra := NovoNumero;
      InserirCaixa(LNumeroOutra, 999999, LSessao.UsuarioId, 'A', 0);

      LService.CarregarCaixas(LLista, LNumeroOutra);
      AssertFalse(LocalizarCaixa(LNumeroOutra, LSaldo, LUsuario),
        'caixa de outra empresa não deve aparecer');

      ASuite.AddResult('TestCaixaCarregarCaixasEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasEscopoEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestCarregarCaixasOrdem;
  var
    LAnterior, LAtual: Int64;
    LOk: Boolean;
  begin
    try
      LService.CarregarCaixas(LLista);
      LOk := True;
      LAnterior := High(Int64);
      LLista.First;
      while not LLista.EOF do
      begin
        LAtual := LLista.FieldByName('ID').AsLargeInt;
        if LAtual > LAnterior then
          LOk := False;
        LAnterior := LAtual;
        LLista.Next;
      end;
      AssertTrue(LOk, 'os caixas devem vir em ID decrescente');
      ASuite.AddResult('TestCaixaCarregarCaixasOrdem', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasOrdem', False, E.Message);
    end;
  end;

  procedure TestCarregarCaixasFechado;
  var
    LCaixaId: Int64;
    LNumero: string;
  begin
    try
      LNumero := NovoNumero;
      LCaixaId := InserirCaixa(LNumero, LSessao.EmpresaId,
        LSessao.UsuarioId, 'F', 200);
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE CAIXA SET DATA_FECHAMENTO = CURRENT_TIMESTAMP, ' +
        '  VALOR_FECHAMENTO = 210 WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LCaixaId;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      LService.CarregarCaixas(LLista, LNumero);
      AssertEquals('1', IntToStr(ContarMovimentos),
        'o caixa fechado deve ser listado');
      AssertEquals('F', Trim(LLista.FieldByName('STATUS').AsString),
        'o status F deve ser preservado');
      AssertFalse(LLista.FieldByName('DATA_FECHAMENTO').IsNull,
        'a data de fechamento deve vir preenchida');
      AssertTrue(QuaseIgual(210,
        LLista.FieldByName('VALOR_FECHAMENTO').AsFloat),
        'o valor de fechamento deve vir preenchido');

      ASuite.AddResult('TestCaixaCarregarCaixasFechado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasFechado', False, E.Message);
    end;
  end;

  procedure TestCarregarCaixasUsuarioInexistente;
  var
    LNumero: string;
    LSaldo: Double;
    LUsuario: string;
  begin
    try
      { USUARIO_ID é DM_ID NOT NULL (não aceita NULL), mas sem FK no
        banco real: um ID inexistente prova o LEFT JOIN }
      LNumero := NovoNumero;
      InserirCaixa(LNumero, LSessao.EmpresaId, 999999, 'A', 0);
      LService.CarregarCaixas(LLista, LNumero);
      AssertTrue(LocalizarCaixa(LNumero, LSaldo, LUsuario),
        'caixa com usuário inexistente deve ser listado');
      AssertEquals('', LUsuario,
        'sem usuário correspondente o nome deve vir vazio, não estourar');
      ASuite.AddResult('TestCaixaCarregarCaixasUsuarioInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarCaixasUsuarioInexistente', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // CarregarMovimentos
  // ------------------------------------------------------------------

  procedure TestCarregarMovimentosQueryNula;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LService.CarregarMovimentos(nil, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'CarregarMovimentos sem query deve levantar exceção');
      ASuite.AddResult('TestCaixaCarregarMovimentosQueryNula', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarMovimentosQueryNula', False,
          E.Message);
    end;
  end;

  procedure TestCarregarMovimentosCaixaInvalido;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LService.CarregarMovimentos(LLista, 0);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'caixa 0 deve ser recusado');

      LDeu := False;
      try
        LService.CarregarMovimentos(LLista, -1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'caixa negativo deve ser recusado');

      ASuite.AddResult('TestCaixaCarregarMovimentosCaixaInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarMovimentosCaixaInvalido', False,
          E.Message);
    end;
  end;

  procedure TestCarregarMovimentosTiposEOrdem;
  var
    LCaixaId: Int64;
    LNumero: string;
    LIds: array of Int64;
    LTipos: array of string;
    LValores: array of Double;
    I: Integer;
  begin
    try
      LCaixaId := InserirCaixaComMovimentos(LNumero);
      LService.CarregarMovimentos(LLista, LCaixaId);

      SetLength(LIds, 0);
      SetLength(LTipos, 0);
      SetLength(LValores, 0);
      LLista.First;
      while not LLista.EOF do
      begin
        SetLength(LIds, Length(LIds) + 1);
        SetLength(LTipos, Length(LTipos) + 1);
        SetLength(LValores, Length(LValores) + 1);
        I := High(LIds);
        LIds[I] := LLista.FieldByName('ID').AsLargeInt;
        LTipos[I] := Trim(LLista.FieldByName('TIPO').AsString);
        LValores[I] := LLista.FieldByName('VALOR').AsFloat;
        LLista.Next;
      end;

      AssertEquals('4', IntToStr(Length(LIds)),
        'o caixa deve ter os 4 movimentos criados');
      AssertEquals('ENTRADA', LTipos[0], 'E deve virar ENTRADA');
      AssertEquals('SAIDA', LTipos[1], 'S deve virar SAIDA');
      AssertEquals('G', LTipos[2], 'G deve ser mantido');
      AssertEquals('P', LTipos[3], 'P deve ser mantido');
      AssertTrue(QuaseIgual(100.25, LValores[0]),
        'o valor da entrada deve ser preservado');
      AssertTrue((LIds[0] < LIds[1]) and (LIds[1] < LIds[2]) and
        (LIds[2] < LIds[3]), 'os movimentos devem vir em ID crescente');
      AssertEquals('Administrador',
        Trim(LLista.FieldByName('USUARIO').AsString),
        'o usuário do movimento deve vir do LEFT JOIN');
      AssertEquals('Pagamento teste',
        Trim(LLista.FieldByName('DESCRICAO').AsString),
        'a última linha deve ser o pagamento');

      ASuite.AddResult('TestCaixaCarregarMovimentosTiposEOrdem', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarMovimentosTiposEOrdem', False,
          E.Message);
    end;
  end;

  procedure TestCarregarMovimentosFiltros;
  var
    LCaixaId: Int64;
    LNumero: string;
  begin
    try
      LCaixaId := InserirCaixaComMovimentos(LNumero);

      LService.CarregarMovimentos(LLista, LCaixaId, 'sangria');
      AssertEquals('1', IntToStr(ContarMovimentos),
        'o filtro por descrição deve achar só a sangria');

      LService.CarregarMovimentos(LLista, LCaixaId, 'SAIDA');
      AssertEquals('1', IntToStr(ContarMovimentos),
        'o filtro por tipo deve achar só a saída');

      LService.CarregarMovimentos(LLista, LCaixaId, 'Administrador');
      AssertEquals('4', IntToStr(ContarMovimentos),
        'o filtro por usuário deve achar os 4 movimentos');

      LService.CarregarMovimentos(LLista, LCaixaId, 'NAO EXISTE ' + LSufixo);
      AssertEquals('0', IntToStr(ContarMovimentos),
        'filtro sem correspondência deve devolver zero linhas');

      ASuite.AddResult('TestCaixaCarregarMovimentosFiltros', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarMovimentosFiltros', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // CarregarResumo
  // ------------------------------------------------------------------

  procedure TestCarregarResumoQueryNula;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LService.CarregarResumo(nil, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'CarregarResumo sem query deve levantar exceção');
      ASuite.AddResult('TestCaixaCarregarResumoQueryNula', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarResumoQueryNula', False, E.Message);
    end;
  end;

  procedure TestCarregarResumoCaixaInvalido;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LService.CarregarResumo(LLista, 0);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'resumo de caixa 0 deve ser recusado');
      ASuite.AddResult('TestCaixaCarregarResumoCaixaInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarResumoCaixaInvalido', False,
          E.Message);
    end;
  end;

  procedure TestCarregarResumoValores;
  var
    LCaixaId: Int64;
    LNumero: string;
  begin
    try
      LCaixaId := InserirCaixaComMovimentos(LNumero);
      LService.CarregarResumo(LLista, LCaixaId);

      AssertFalse(LLista.IsEmpty, 'o resumo deve devolver uma linha');
      AssertTrue(QuaseIgual(100.25,
        LLista.FieldByName('ENTRADAS').AsFloat),
        'entradas devem somar só o tipo E');
      AssertTrue(QuaseIgual(40.10,
        LLista.FieldByName('SAIDAS').AsFloat),
        'saídas devem somar só o tipo S');
      AssertTrue(QuaseIgual(60.15,
        LLista.FieldByName('SALDO').AsFloat),
        'saldo do resumo deve ser E - S');

      ASuite.AddResult('TestCaixaCarregarResumoValores', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarResumoValores', False, E.Message);
    end;
  end;

  procedure TestCarregarResumoVazio;
  var
    LCaixaId: Int64;
    LNumero: string;
  begin
    try
      LNumero := NovoNumero;
      LCaixaId := InserirCaixa(LNumero, LSessao.EmpresaId,
        LSessao.UsuarioId, 'A', 0);
      LService.CarregarResumo(LLista, LCaixaId);

      AssertFalse(LLista.IsEmpty, 'caixa sem movimento ainda devolve uma linha');
      AssertTrue(QuaseIgual(0, LLista.FieldByName('ENTRADAS').AsFloat),
        'entradas de caixa vazio devem ser 0');
      AssertTrue(QuaseIgual(0, LLista.FieldByName('SAIDAS').AsFloat),
        'saídas de caixa vazio devem ser 0');
      AssertTrue(QuaseIgual(0, LLista.FieldByName('SALDO').AsFloat),
        'saldo de caixa vazio deve ser 0');

      ASuite.AddResult('TestCaixaCarregarResumoVazio', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCaixaCarregarResumoVazio', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Limpeza
  // ------------------------------------------------------------------

  procedure ExecSufixo(const ASQL: string; const AParams: array of string);
  var
    I: Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    for I := 0 to High(AParams) do
      LQuery.ParamByName(AParams[I]).AsString := LSufixo;
    LQuery.ExecSQL;
    LConexao.Confirmar;
  end;

  procedure LimparSobraPorSufixo;
  begin
    try
      ExecSufixo(
        'DELETE FROM MOVIMENTO_CAIXA WHERE CAIXA_ID IN (' +
        '  SELECT ID FROM CAIXA WHERE OBSERVACOES CONTAINING :P1)',
        ['P1']);
    except
    end;
    try
      ExecSufixo(
        'DELETE FROM CAIXA WHERE OBSERVACOES CONTAINING :P1', ['P1']);
    except
    end;
    try
      { corta a auditoria gerada nesta rodada, se houver }
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
  LService := TCaixaService.Create;
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
    WriteLn('EXECUTANDO TESTES DO CAIXA');
    WriteLn('========================================');

    TestCarregarCaixasQueryNula;
    TestCarregarCaixasSaldo;
    TestCarregarCaixasSemMovimento;
    TestCarregarCaixasFiltroUsuario;
    TestCarregarCaixasFiltroInexistente;
    TestCarregarCaixasEscopoEmpresa;
    TestCarregarCaixasOrdem;
    TestCarregarCaixasFechado;
    TestCarregarCaixasUsuarioInexistente;
    TestCarregarMovimentosQueryNula;
    TestCarregarMovimentosCaixaInvalido;
    TestCarregarMovimentosTiposEOrdem;
    TestCarregarMovimentosFiltros;
    TestCarregarResumoQueryNula;
    TestCarregarResumoCaixaInvalido;
    TestCarregarResumoValores;
    TestCarregarResumoVazio;
  finally
    LimparSobraPorSufixo;
    LService.Free;
    LLista.Free;
    LQuery.Free;
  end;
end;

end.
