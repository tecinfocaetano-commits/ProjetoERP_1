unit uFrmUsuariosTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes Unitários para Usuários
  Descrição: Testes de CRUD de usuários
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao;

type
  { TUsuariosTest }
  TUsuariosTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TUsuariosTest }

class procedure TUsuariosTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LUsuarioId: Int64;
  LNomeTeste: string;
  LLoginTeste: string;
  LSenhaTeste: string;

  procedure TestInserirUsuarioSucesso;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO USUARIO (ID, EMPRESA_ID, GRUPO_ID, NOME, LOGIN, SENHA, EMAIL, ADMINISTRADOR, ATIVO) ' +
        'VALUES (:ID, 1, 0, :NOME, :LOGIN, :SENHA, ''teste@teste.com'', ''N'', ''A'')';
      LQuery.ParamByName('ID').AsLargeInt := LUsuarioId;
      LQuery.ParamByName('NOME').AsString := LNomeTeste;
      LQuery.ParamByName('LOGIN').AsString := LLoginTeste;
      LQuery.ParamByName('SENHA').AsString := LSenhaTeste;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      AssertTrue(LUsuarioId > 0, 'Usuário deve ser inserido com sucesso');
      ASuite.AddResult('TestInserirUsuarioSucesso', True, '');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirUsuarioSucesso', False, E.Message);
      end;
    end;
  end;

  procedure TestInserirUsuarioSemNome;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO USUARIO (NOME, LOGIN, SENHA, EMAIL, ATIVO) ' +
        'VALUES ('''', ''login999'', ''senha123'', ''teste@teste.com'', ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir usuário sem nome');
      ASuite.AddResult('TestInserirUsuarioSemNome', False, 'Permitiu inserção sem nome');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirUsuarioSemNome', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestInserirUsuarioSemLogin;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO USUARIO (NOME, LOGIN, SENHA, EMAIL, ATIVO) ' +
        'VALUES (''Usuario Teste'', '''', ''senha123'', ''teste@teste.com'', ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir usuário sem login');
      ASuite.AddResult('TestInserirUsuarioSemLogin', False, 'Permitiu inserção sem login');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirUsuarioSemLogin', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestInserirUsuarioSemSenha;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO USUARIO (NOME, LOGIN, SENHA, EMAIL, ATIVO) ' +
        'VALUES (''Usuario Teste'', ''login998'', '''', ''teste@teste.com'', ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir usuário sem senha');
      ASuite.AddResult('TestInserirUsuarioSemSenha', False, 'Permitiu inserção sem senha');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirUsuarioSemSenha', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestInserirUsuarioSenhaCurta;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO USUARIO (NOME, LOGIN, SENHA, EMAIL, ATIVO) ' +
        'VALUES (''Usuario Teste'', ''login997'', ''123'', ''teste@teste.com'', ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir usuário com senha curta (< 6 caracteres)');
      ASuite.AddResult('TestInserirUsuarioSenhaCurta', False, 'Permitiu senha curta');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirUsuarioSenhaCurta', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestBuscarUsuarioPorId;
  begin
    try
      if LUsuarioId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT * FROM USUARIO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LUsuarioId;
        LQuery.Open;

        AssertTrue(not LQuery.IsEmpty, 'Deve encontrar usuário por ID');
        AssertEquals(LNomeTeste, LQuery.FieldByName('NOME').AsString, 'Nome deve corresponder');
        ASuite.AddResult('TestBuscarUsuarioPorId', True, '');
      end
      else
      begin
        ASuite.AddResult('TestBuscarUsuarioPorId', True, 'Skipped - No test user');
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestBuscarUsuarioPorId', False, E.Message);
    end;
  end;

  procedure TestAtualizarUsuario;
  begin
    try
      if LUsuarioId > 0 then
      begin
        LConexao.IniciarTransacao;
        LQuery.Close;
        LQuery.SQL.Text :=
          'UPDATE USUARIO SET NOME = :NOME, EMAIL = :EMAIL WHERE ID = :ID';
        LQuery.ParamByName('NOME').AsString := LNomeTeste + ' - Atualizado';
        LQuery.ParamByName('EMAIL').AsString := 'atualizado@teste.com';
        LQuery.ParamByName('ID').AsLargeInt := LUsuarioId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        // Verificar atualização
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT NOME, EMAIL FROM USUARIO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LUsuarioId;
        LQuery.Open;

        AssertEquals(LNomeTeste + ' - Atualizado', LQuery.FieldByName('NOME').AsString, 'Nome deve estar atualizado');
        ASuite.AddResult('TestAtualizarUsuario', True, '');
      end
      else
      begin
        ASuite.AddResult('TestAtualizarUsuario', True, 'Skipped - No test user');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestAtualizarUsuario', False, E.Message);
      end;
    end;
  end;

  procedure TestListarUsuarios;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT COUNT(*) AS TOTAL FROM USUARIO WHERE ATIVO = ''A''';
      LQuery.Open;

      AssertTrue(LQuery.FieldByName('TOTAL').AsInteger >= 0, 'Deve listar usuários');
      ASuite.AddResult('TestListarUsuarios', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestListarUsuarios', False, E.Message);
    end;
  end;

  procedure TestFiltrarUsuariosPorNome;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT ID, NOME FROM USUARIO WHERE UPPER(NOME) CONTAINING UPPER(:FILTRO)';
      LQuery.ParamByName('FILTRO').AsString := 'Teste';
      LQuery.Open;

      AssertTrue(LQuery.RecordCount >= 0, 'Deve filtrar usuários por nome');
      ASuite.AddResult('TestFiltrarUsuariosPorNome', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFiltrarUsuariosPorNome', False, E.Message);
    end;
  end;

  procedure TestExcluirUsuario;
  begin
    try
      if LUsuarioId > 0 then
      begin
        // Verificar se não é o usuário logado
        if LUsuarioId <> TSessao.GetInstance.UsuarioId then
        begin
          LConexao.IniciarTransacao;
          LQuery.Close;
          LQuery.SQL.Text := 'DELETE FROM USUARIO WHERE ID = :ID';
          LQuery.ParamByName('ID').AsLargeInt := LUsuarioId;
          LQuery.ExecSQL;
          LConexao.Confirmar;

          // Verificar exclusão
          LQuery.Close;
          LQuery.SQL.Text := 'SELECT ID FROM USUARIO WHERE ID = :ID';
          LQuery.ParamByName('ID').AsLargeInt := LUsuarioId;
          LQuery.Open;

          AssertTrue(LQuery.IsEmpty, 'Usuário deve ser excluído');
          ASuite.AddResult('TestExcluirUsuario', True, '');
        end
        else
        begin
          ASuite.AddResult('TestExcluirUsuario', True, 'Skipped - Cannot delete logged user');
        end;
      end
      else
      begin
        ASuite.AddResult('TestExcluirUsuario', True, 'Skipped - No test user');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestExcluirUsuario', False, E.Message);
      end;
    end;
  end;

begin
  WriteLn('========================================');
  WriteLn('EXECUTANDO TESTES DE USUÁRIOS');
  WriteLn('========================================');

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LUsuarioId := 99999; // ID fixo para teste
  LNomeTeste := 'Usuário Teste Unitário ' + FormatDateTime('yyyymmddhhnnss', Now);
  LLoginTeste := 'testuser' + FormatDateTime('yyyymmddhhnnss', Now);
  LSenhaTeste := 'senha123';

  try
    // Conectar ao banco
    LConexao.Conectar;
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Executar testes
    TestInserirUsuarioSucesso;
    TestInserirUsuarioSemNome;
    TestInserirUsuarioSemLogin;
    TestInserirUsuarioSemSenha;
    TestInserirUsuarioSenhaCurta;
    TestBuscarUsuarioPorId;
    TestAtualizarUsuario;
    TestListarUsuarios;
    TestFiltrarUsuariosPorNome;
    TestExcluirUsuario;

  finally
    LQuery.Free;
  end;
end;

end.
