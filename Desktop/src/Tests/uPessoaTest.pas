unit uPessoaTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - D3 - Testes da entidade unificada PESSOA
  Cobre CRUD, filtro por TIPO, validações e integridade da 018.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao, uPessoa,
  uPessoaService;

type
  { TPessoaTest }
  TPessoaTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

const
  MARCA_TESTE = 'TESTE_D3';

{ TPessoaTest }

class procedure TPessoaTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LSvc: TPessoaService;
  LSeq: Integer;
  LClienteId: Int64;
  LFornecedorId: Int64;
  LCpfCliente: string;
  LCpfFornecedor: string;

  function NovoCpf: string;
  begin
    Inc(LSeq);
    Result := '9' + FormatDateTime('yymmddhhnnss', Now) + IntToStr(LSeq);
  end;

  function NovaPessoa(ATipo: Char; const ANome, ACpf: string): TPessoa;
  begin
    Result := TPessoa.Create;
    Result.EmpresaId := 1;
    Result.Tipo := ATipo;
    Result.TipoPessoa := 'F';
    Result.Nome := ANome;
    Result.CpfCnpj := ACpf;
    Result.Cidade := 'Cidade Teste';
    Result.Uf := 'SP';
    Result.Ativo := 'A';
    Result.Observacoes := MARCA_TESTE;
    Result.LimiteCredito := 0;
  end;

  procedure LimparTestes;
  begin
    if LConexao.EmTransacao then
      LConexao.Confirmar;
    LConexao.IniciarTransacao;
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM LOG_SISTEMA WHERE TABELA = ''PESSOA'' AND REGISTRO_ID IN ' +
        '(SELECT ID FROM PESSOA WHERE OBSERVACOES = :MARCA)';
      LQuery.ParamByName('MARCA').AsString := MARCA_TESTE;
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM PESSOA WHERE OBSERVACOES = :MARCA';
      LQuery.ParamByName('MARCA').AsString := MARCA_TESTE;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
      LConexao.Cancelar;
      raise;
    end;
  end;

  function ExisteId(AQuery: TSQLQuery; AId: Int64): Boolean;
  begin
    Result := False;
    AQuery.First;
    while not AQuery.EOF do
    begin
      if AQuery.FieldByName('ID').AsLargeInt = AId then
      begin
        Result := True;
        Break;
      end;
      AQuery.Next;
    end;
  end;

  procedure TestInserirCliente;
  var
    LP: TPessoa;
    LB: TPessoa;
  begin
    try
      LCpfCliente := NovoCpf;
      LP := NovaPessoa('C', 'Pessoa Teste Cliente', LCpfCliente);
      try
        LClienteId := LSvc.Inserir(LP);
      finally
        LP.Free;
      end;
      AssertTrue(LClienteId > 0, 'Cliente deve ser inserido com sucesso');

      LB := LSvc.BuscarPorId(LClienteId);
      try
        AssertNotNull(LB, 'Cliente deve ser encontrado por ID');
        AssertEquals('C', LB.Tipo, 'TIPO do cliente deve ser C');
        AssertEquals(LCpfCliente, LB.CpfCnpj, 'CPF/CNPJ do cliente deve corresponder');
      finally
        LB.Free;
      end;
      ASuite.AddResult('TestInserirCliente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInserirCliente', False, E.Message);
    end;
  end;

  procedure TestInserirFornecedor;
  var
    LP: TPessoa;
    LB: TPessoa;
  begin
    try
      LCpfFornecedor := NovoCpf;
      LP := NovaPessoa('F', 'Pessoa Teste Fornecedor', LCpfFornecedor);
      try
        LFornecedorId := LSvc.Inserir(LP);
      finally
        LP.Free;
      end;
      AssertTrue(LFornecedorId > 0, 'Fornecedor deve ser inserido com sucesso');

      LB := LSvc.BuscarPorId(LFornecedorId);
      try
        AssertNotNull(LB, 'Fornecedor deve ser encontrado por ID');
        AssertEquals('F', LB.Tipo, 'TIPO do fornecedor deve ser F');
      finally
        LB.Free;
      end;
      ASuite.AddResult('TestInserirFornecedor', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInserirFornecedor', False, E.Message);
    end;
  end;

  procedure TestFiltrarPorTipo;
  var
    Q: TSQLQuery;
  begin
    try
      AssertTrue(LClienteId > 0, 'Cliente de teste deve existir');
      AssertTrue(LFornecedorId > 0, 'Fornecedor de teste deve existir');

      Q := LSvc.BuscarTodos('C');
      AssertTrue(ExisteId(Q, LClienteId), 'Filtro C deve listar o cliente');
      AssertFalse(ExisteId(Q, LFornecedorId), 'Filtro C não deve listar o fornecedor');

      Q := LSvc.BuscarTodos('F');
      AssertTrue(ExisteId(Q, LFornecedorId), 'Filtro F deve listar o fornecedor');
      AssertFalse(ExisteId(Q, LClienteId), 'Filtro F não deve listar o cliente');

      Q := LSvc.BuscarTodos(#0);
      AssertTrue(ExisteId(Q, LClienteId), 'Filtro Todos deve listar o cliente');
      AssertTrue(ExisteId(Q, LFornecedorId), 'Filtro Todos deve listar o fornecedor');

      ASuite.AddResult('TestFiltrarPorTipo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFiltrarPorTipo', False, E.Message);
    end;
  end;

  procedure TestPesquisarNomeCpfCidade;
  var
    LP: TPessoa;
    LId: Int64;
    LCpf: string;
    Q: TSQLQuery;
  begin
    try
      LCpf := NovoCpf;
      LP := NovaPessoa('C', 'Pessoa D''Ávila Teste', LCpf);
      try
        LP.Cidade := 'Cidade D''Ávila';
        LId := LSvc.Inserir(LP);
      finally
        LP.Free;
      end;
      AssertTrue(LId > 0, 'Pessoa para pesquisa deve ser inserida');

      Q := LSvc.Pesquisar('D''Ávila', 'C');
      AssertTrue(ExisteId(Q, LId), 'Pesquisa deve encontrar pelo nome/cidade com apóstrofo');

      Q := LSvc.Pesquisar(LCpf, 'C');
      AssertTrue(ExisteId(Q, LId), 'Pesquisa deve encontrar pelo CPF/CNPJ');

      ASuite.AddResult('TestPesquisarNomeCpfCidade', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPesquisarNomeCpfCidade', False, E.Message);
    end;
  end;

  procedure TestAtualizarPessoa;
  var
    LP: TPessoa;
    LB: TPessoa;
    LId: Int64;
  begin
    try
      LP := NovaPessoa('F', 'Fornecedor Teste Update', NovoCpf);
      try
        LId := LSvc.Inserir(LP);
      finally
        LP.Free;
      end;
      AssertTrue(LId > 0, 'Pessoa para atualização deve ser inserida');

      LB := LSvc.BuscarPorId(LId);
      try
        AssertNotNull(LB, 'Pessoa para atualização deve existir');
        LB.Nome := 'Fornecedor Teste Atualizado';
        LB.Cidade := 'São Paulo';
        AssertTrue(LSvc.Atualizar(LB), 'Service deve atualizar a pessoa');
      finally
        LB.Free;
      end;

      LB := LSvc.BuscarPorId(LId);
      try
        AssertNotNull(LB, 'Pessoa atualizada deve existir');
        AssertEquals('Fornecedor Teste Atualizado', LB.Nome, 'Nome deve estar atualizado');
        AssertEquals('São Paulo', LB.Cidade, 'Cidade deve estar atualizada');
      finally
        LB.Free;
      end;

      ASuite.AddResult('TestAtualizarPessoa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestAtualizarPessoa', False, E.Message);
    end;
  end;

  procedure TestExcluirPessoa;
  var
    LP: TPessoa;
    LId: Int64;
    LB: TPessoa;
  begin
    try
      LP := NovaPessoa('C', 'Pessoa Teste Exclusão', NovoCpf);
      try
        LId := LSvc.Inserir(LP);
      finally
        LP.Free;
      end;
      AssertTrue(LId > 0, 'Pessoa para exclusão deve ser inserida');
      AssertTrue(LSvc.Excluir(LId), 'Service deve excluir a pessoa');

      LB := LSvc.BuscarPorId(LId);
      try
        AssertNil(LB, 'Pessoa deve sumir após exclusão');
      finally
        LB.Free;
      end;

      ASuite.AddResult('TestExcluirPessoa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestExcluirPessoa', False, E.Message);
    end;
  end;

  procedure TestRecusarTipoInvalido;
  var
    LP: TPessoa;
    LRecusou: Boolean;
  begin
    LRecusou := False;
    LP := NovaPessoa('X', 'Pessoa Tipo Inválido', NovoCpf);
    try
      try
        LSvc.Inserir(LP);
      except
        on E: Exception do
          LRecusou := True;
      end;
      AssertTrue(LRecusou, 'Service deve recusar TIPO diferente de C/F');
      ASuite.AddResult('TestRecusarTipoInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestRecusarTipoInvalido', False, E.Message);
    end;
    LP.Free;
  end;

  procedure TestRecusarTrocaTipo;
  var
    LP: TPessoa;
    LB: TPessoa;
    LId: Int64;
    LRecusou: Boolean;
  begin
    LRecusou := False;
    try
      LP := NovaPessoa('C', 'Pessoa Teste Troca Tipo', NovoCpf);
      try
        LId := LSvc.Inserir(LP);
      finally
        LP.Free;
      end;
      AssertTrue(LId > 0, 'Pessoa para troca de tipo deve ser inserida');

      LB := LSvc.BuscarPorId(LId);
      try
        AssertNotNull(LB, 'Pessoa para troca de tipo deve existir');
        LB.Tipo := 'F';
        try
          LSvc.Atualizar(LB);
        except
          on E: Exception do
            LRecusou := Pos('alterar o tipo', E.Message) > 0;
        end;
      finally
        LB.Free;
      end;

      AssertTrue(LRecusou, 'Service deve recusar a troca de TIPO na atualização');
      ASuite.AddResult('TestRecusarTrocaTipo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestRecusarTrocaTipo', False, E.Message);
    end;
  end;

  procedure TestBloquearCpfDuplicadoMesmoTipo;
  var
    LP1, LP2: TPessoa;
    LId: Int64;
    LCpf: string;
    LBloqueou: Boolean;
  begin
    LBloqueou := False;
    LCpf := NovoCpf;
    LP1 := NovaPessoa('C', 'Pessoa Teste Duplicada 1', LCpf);
    LP2 := NovaPessoa('C', 'Pessoa Teste Duplicada 2', LCpf);
    try
      try
        LId := LSvc.Inserir(LP1);
        AssertTrue(LId > 0, 'Primeira pessoa deve ser inserida');
        try
          LSvc.Inserir(LP2);
        except
          on E: Exception do
            LBloqueou := Pos('existe uma pessoa', E.Message) > 0;
        end;
      finally
        LP1.Free;
        LP2.Free;
      end;

      AssertTrue(LBloqueou, 'Service deve bloquear CPF/CNPJ duplicado no mesmo TIPO');
      ASuite.AddResult('TestBloquearCpfDuplicadoMesmoTipo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestBloquearCpfDuplicadoMesmoTipo', False, E.Message);
    end;
  end;

  procedure TestPermitirMesmoCpfTiposDiferentes;
  var
    LP1, LP2: TPessoa;
    LId1, LId2: Int64;
    LCpf: string;
  begin
    LCpf := NovoCpf;
    LP1 := NovaPessoa('C', 'Pessoa Teste Mesmo CPF Cliente', LCpf);
    LP2 := NovaPessoa('F', 'Pessoa Teste Mesmo CPF Fornecedor', LCpf);
    try
      try
        LId1 := LSvc.Inserir(LP1);
        LId2 := LSvc.Inserir(LP2);
        AssertTrue(LId1 > 0, 'Cliente com o CPF/CNPJ compartilhado deve ser inserido');
        AssertTrue(LId2 > 0, 'Fornecedor com o mesmo CPF/CNPJ deve ser inserido');
        ASuite.AddResult('TestPermitirMesmoCpfTiposDiferentes', True, '');
      finally
        LP1.Free;
        LP2.Free;
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestPermitirMesmoCpfTiposDiferentes', False, E.Message);
    end;
  end;

  procedure TestBloquearExclusaoReferenciada;
  var
    LId: Int64;
    LBloqueou: Boolean;
  begin
    LBloqueou := False;
    try
      LId := 0;
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT FIRST 1 CLIENTE_ID FROM CONTA_RECEBER WHERE CLIENTE_ID > 0';
      LQuery.Open;
      if not LQuery.IsEmpty then
        LId := LQuery.FieldByName('CLIENTE_ID').AsLargeInt;
      LQuery.Close;

      if LId = 0 then
      begin
        LQuery.SQL.Text := 'SELECT FIRST 1 FORNECEDOR_ID FROM CONTA_PAGAR WHERE FORNECEDOR_ID > 0';
        LQuery.Open;
        if not LQuery.IsEmpty then
          LId := LQuery.FieldByName('FORNECEDOR_ID').AsLargeInt;
        LQuery.Close;
      end;

      if LId <= 0 then
      begin
        ASuite.AddResult('TestBloquearExclusaoReferenciada', True,
          'Skipped - sem pessoa referenciada');
        Exit;
      end;

      try
        LSvc.Excluir(LId);
      except
        on E: Exception do
          LBloqueou := Pos('usada em', E.Message) > 0;
      end;

      AssertTrue(LBloqueou, 'Service deve bloquear exclusão de pessoa referenciada');
      ASuite.AddResult('TestBloquearExclusaoReferenciada', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestBloquearExclusaoReferenciada', False, E.Message);
    end;
  end;

  procedure TestIntegridade018;
  var
    LClientes, LFornecedores, LOrfaos, LTabelasAntigas: Int64;
    LGerador, LMaiorId: Int64;
  begin
    try
      LimparTestes;

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT ' +
        '(SELECT COUNT(*) FROM PESSOA WHERE TIPO = ''C'') AS CLIENTES, ' +
        '(SELECT COUNT(*) FROM PESSOA WHERE TIPO = ''F'') AS FORNECEDORES, ' +
        '(SELECT COUNT(*) FROM RDB$RELATIONS WHERE RDB$RELATION_NAME IN (''CLIENTE'', ''FORNECEDOR'')) AS ANTIGAS ' +
        'FROM RDB$DATABASE';
      LQuery.Open;
      LClientes := LQuery.FieldByName('CLIENTES').AsLargeInt;
      LFornecedores := LQuery.FieldByName('FORNECEDORES').AsLargeInt;
      LTabelasAntigas := LQuery.FieldByName('ANTIGAS').AsLargeInt;
      LQuery.Close;

      AssertEquals('9', IntToStr(LClientes), 'PESSOA deve manter os 9 clientes migrados');
      AssertEquals('2', IntToStr(LFornecedores), 'PESSOA deve manter os 2 fornecedores migrados');
      AssertEquals('0', IntToStr(LTabelasAntigas), 'CLIENTE e FORNECEDOR não devem mais existir');

      LQuery.SQL.Text :=
        'SELECT ' +
        '(SELECT COUNT(*) FROM CONTA_RECEBER CR WHERE CR.CLIENTE_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = CR.CLIENTE_ID AND P.TIPO = ''C'')) + ' +
        '(SELECT COUNT(*) FROM CONTA_PAGAR CP WHERE CP.FORNECEDOR_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = CP.FORNECEDOR_ID AND P.TIPO = ''F'')) + ' +
        '(SELECT COUNT(*) FROM NOTA_ENTRADA N WHERE N.FORNECEDOR_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = N.FORNECEDOR_ID AND P.TIPO = ''F'')) + ' +
        '(SELECT COUNT(*) FROM NOTA_SAIDA N WHERE N.CLIENTE_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = N.CLIENTE_ID AND P.TIPO = ''C'')) + ' +
        '(SELECT COUNT(*) FROM PEDIDO_COMPRA PC WHERE PC.FORNECEDOR_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = PC.FORNECEDOR_ID AND P.TIPO = ''F'')) + ' +
        '(SELECT COUNT(*) FROM PEDIDO_VENDA PV WHERE PV.CLIENTE_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = PV.CLIENTE_ID AND P.TIPO = ''C'')) + ' +
        '(SELECT COUNT(*) FROM PRODUTO PR WHERE PR.FORNECEDOR_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = PR.FORNECEDOR_ID AND P.TIPO = ''F'')) + ' +
        '(SELECT COUNT(*) FROM FINANCEIRO F WHERE F.CLIENTE_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = F.CLIENTE_ID AND P.TIPO = ''C'')) + ' +
        '(SELECT COUNT(*) FROM FINANCEIRO F WHERE F.FORNECEDOR_ID > 0 AND NOT EXISTS ' +
        '  (SELECT 1 FROM PESSOA P WHERE P.ID = F.FORNECEDOR_ID AND P.TIPO = ''F'')) ' +
        'AS ORFAOS ' +
        'FROM RDB$DATABASE';
      LQuery.Open;
      LOrfaos := LQuery.FieldByName('ORFAOS').AsLargeInt;
      LQuery.Close;

      AssertEquals('0', IntToStr(LOrfaos), 'Não deve haver referências órfãs');

      LQuery.SQL.Text :=
        'SELECT GEN_ID(GEN_PESSOA_ID, 0) AS GERADOR, ' +
        '(SELECT COALESCE(MAX(ID), 0) FROM PESSOA) AS MAIOR FROM RDB$DATABASE';
      LQuery.Open;
      LGerador := LQuery.FieldByName('GERADOR').AsLargeInt;
      LMaiorId := LQuery.FieldByName('MAIOR').AsLargeInt;
      LQuery.Close;
      AssertTrue(LGerador >= LMaiorId, 'Gerador deve estar acima do maior ID');

      ASuite.AddResult('TestIntegridade018', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestIntegridade018', False, E.Message);
    end;
  end;

begin
  WriteLn('========================================');
  WriteLn('EXECUTANDO TESTES DE PESSOAS (D3)');
  WriteLn('========================================');

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LSvc := TPessoaService.Create;
  LSeq := 0;

  try
    LConexao.Conectar;
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    LimparTestes;

    TestInserirCliente;
    TestInserirFornecedor;
    TestFiltrarPorTipo;
    TestPesquisarNomeCpfCidade;
    TestAtualizarPessoa;
    TestExcluirPessoa;
    TestRecusarTipoInvalido;
    TestRecusarTrocaTipo;
    TestBloquearCpfDuplicadoMesmoTipo;
    TestPermitirMesmoCpfTiposDiferentes;
    TestBloquearExclusaoReferenciada;
    TestIntegridade018;
  finally
    try
      LimparTestes;
    except
      // A limpeza não deve mascarar o resultado dos testes.
    end;
    LQuery.Free;
    LSvc.Free;
  end;
end;

end.
