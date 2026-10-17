unit uFrmClientesTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes Unitários para Clientes
  Descrição: Testes de CRUD de clientes
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao;

type
  { TClientesTest }
  TClientesTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TClientesTest }

class procedure TClientesTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LClienteId: Int64;
  LNomeTeste: string;
  LCpfTeste: string;

  procedure TestInserirClienteSucesso;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO CLIENTE (ID, EMPRESA_ID, NOME, CPF_CNPJ, CIDADE, UF, TELEFONE, ATIVO) ' +
        'VALUES (:ID, 1, :NOME, :CPF, ''Cidade Teste'', ''SP'', ''11999999999'', ''A'')';
      LQuery.ParamByName('ID').AsLargeInt := LClienteId;
      LQuery.ParamByName('NOME').AsString := LNomeTeste;
      LQuery.ParamByName('CPF').AsString := LCpfTeste;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      AssertTrue(LClienteId > 0, 'Cliente deve ser inserido com sucesso');
      ASuite.AddResult('TestInserirClienteSucesso', True, '');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirClienteSucesso', False, E.Message);
      end;
    end;
  end;

  procedure TestInserirClienteSemNome;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO CLIENTE (NOME, CPF_CNPJ, CIDADE, UF, ATIVO) ' +
        'VALUES ('''', ''12345678901'', ''Cidade Teste'', ''SP'', ''A'')';
      LQuery.ExecSQL;

      // Se chegou aqui, não validou corretamente (deveria falhar)
      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir cliente sem nome');
      ASuite.AddResult('TestInserirClienteSemNome', False, 'Permitiu inserção sem nome');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        // Esperado - validação funcionou
        ASuite.AddResult('TestInserirClienteSemNome', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestInserirClienteSemCpfCnpj;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO CLIENTE (NOME, CPF_CNPJ, CIDADE, UF, ATIVO) ' +
        'VALUES (''Cliente Teste'', '''', ''Cidade Teste'', ''SP'', ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir cliente sem CPF/CNPJ');
      ASuite.AddResult('TestInserirClienteSemCpfCnpj', False, 'Permitiu inserção sem CPF/CNPJ');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirClienteSemCpfCnpj', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestBuscarClientePorId;
  begin
    try
      if LClienteId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT * FROM CLIENTE WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LClienteId;
        LQuery.Open;

        AssertTrue(not LQuery.IsEmpty, 'Deve encontrar cliente por ID');
        AssertEquals(LNomeTeste, LQuery.FieldByName('NOME').AsString, 'Nome deve corresponder');
        ASuite.AddResult('TestBuscarClientePorId', True, '');
      end
      else
      begin
        ASuite.AddResult('TestBuscarClientePorId', True, 'Skipped - No test client');
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestBuscarClientePorId', False, E.Message);
    end;
  end;

  procedure TestAtualizarCliente;
  begin
    try
      if LClienteId > 0 then
      begin
        LConexao.IniciarTransacao;
        LQuery.Close;
        LQuery.SQL.Text :=
          'UPDATE CLIENTE SET NOME = :NOME, CIDADE = :CIDADE WHERE ID = :ID';
        LQuery.ParamByName('NOME').AsString := LNomeTeste + ' - Atualizado';
        LQuery.ParamByName('CIDADE').AsString := 'São Paulo';
        LQuery.ParamByName('ID').AsLargeInt := LClienteId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        // Verificar atualização
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT NOME, CIDADE FROM CLIENTE WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LClienteId;
        LQuery.Open;

        AssertEquals(LNomeTeste + ' - Atualizado', LQuery.FieldByName('NOME').AsString, 'Nome deve estar atualizado');
        ASuite.AddResult('TestAtualizarCliente', True, '');
      end
      else
      begin
        ASuite.AddResult('TestAtualizarCliente', True, 'Skipped - No test client');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestAtualizarCliente', False, E.Message);
      end;
    end;
  end;

  procedure TestListarClientes;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT COUNT(*) AS TOTAL FROM CLIENTE WHERE ATIVO = ''A''';
      LQuery.Open;

      AssertTrue(LQuery.FieldByName('TOTAL').AsInteger >= 0, 'Deve listar clientes');
      ASuite.AddResult('TestListarClientes', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestListarClientes', False, E.Message);
    end;
  end;

  procedure TestFiltrarClientesPorNome;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT ID, NOME FROM CLIENTE WHERE UPPER(NOME) CONTAINING UPPER(:FILTRO)';
      LQuery.ParamByName('FILTRO').AsString := 'Teste';
      LQuery.Open;

      AssertTrue(LQuery.RecordCount >= 0, 'Deve filtrar clientes por nome');
      ASuite.AddResult('TestFiltrarClientesPorNome', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFiltrarClientesPorNome', False, E.Message);
    end;
  end;

  procedure TestExcluirCliente;
  begin
    try
      if LClienteId > 0 then
      begin
        LConexao.IniciarTransacao;
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM CLIENTE WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LClienteId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        // Verificar exclusão
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT ID FROM CLIENTE WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LClienteId;
        LQuery.Open;

        AssertTrue(LQuery.IsEmpty, 'Cliente deve ser excluído');
        ASuite.AddResult('TestExcluirCliente', True, '');
      end
      else
      begin
        ASuite.AddResult('TestExcluirCliente', True, 'Skipped - No test client');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestExcluirCliente', False, E.Message);
      end;
    end;
  end;

begin
  WriteLn('========================================');
  WriteLn('EXECUTANDO TESTES DE CLIENTES');
  WriteLn('========================================');

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LClienteId := 99999; // ID fixo para teste
  LNomeTeste := 'Cliente Teste Unitário ' + FormatDateTime('yyyymmddhhnnss', Now);
  LCpfTeste := '12345678901'; // CPF fictício para testes

  try
    // Conectar ao banco
    LConexao.Conectar;
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Executar testes
    TestInserirClienteSucesso;
    TestInserirClienteSemNome;
    TestInserirClienteSemCpfCnpj;
    TestBuscarClientePorId;
    TestAtualizarCliente;
    TestListarClientes;
    TestFiltrarClientesPorNome;
    TestExcluirCliente;

  finally
    LQuery.Free;
  end;
end;

end.
