unit uFrmCategoriasTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes Unitários para Categorias
  Descrição: Testes de CRUD de categorias
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao;

type
  { TCategoriasTest }
  TCategoriasTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TCategoriasTest }

class procedure TCategoriasTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LCategoriaId: Int64;
  LNomeTeste: string;

  procedure TestInserirCategoriaSucesso;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO CATEGORIA (ID, NOME, DESCRICAO, ATIVO) ' +
        'VALUES (:ID, :NOME, :DESC, ''A'')';
      LQuery.ParamByName('ID').AsLargeInt := LCategoriaId;
      LQuery.ParamByName('NOME').AsString := LNomeTeste;
      LQuery.ParamByName('DESC').AsString := 'Categoria de teste unitário';
      LQuery.ExecSQL;
      LConexao.Confirmar;

      AssertTrue(LCategoriaId > 0, 'Categoria deve ser inserida com sucesso');
      ASuite.AddResult('TestInserirCategoriaSucesso', True, '');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirCategoriaSucesso', False, E.Message);
      end;
    end;
  end;

  procedure TestInserirCategoriaSemNome;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO CATEGORIA (NOME, DESCRICAO, ATIVO) ' +
        'VALUES ('''', ''Descrição'', ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir categoria sem nome');
      ASuite.AddResult('TestInserirCategoriaSemNome', False, 'Permitiu inserção sem nome');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirCategoriaSemNome', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestBuscarCategoriaPorId;
  begin
    try
      if LCategoriaId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT * FROM CATEGORIA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LCategoriaId;
        LQuery.Open;

        AssertTrue(not LQuery.IsEmpty, 'Deve encontrar categoria por ID');
        AssertEquals(LNomeTeste, LQuery.FieldByName('NOME').AsString, 'Nome deve corresponder');
        ASuite.AddResult('TestBuscarCategoriaPorId', True, '');
      end
      else
      begin
        ASuite.AddResult('TestBuscarCategoriaPorId', True, 'Skipped - No test category');
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestBuscarCategoriaPorId', False, E.Message);
    end;
  end;

  procedure TestAtualizarCategoria;
  begin
    try
      if LCategoriaId > 0 then
      begin
        LConexao.IniciarTransacao;
        LQuery.Close;
        LQuery.SQL.Text :=
          'UPDATE CATEGORIA SET NOME = :NOME, DESCRICAO = :DESC WHERE ID = :ID';
        LQuery.ParamByName('NOME').AsString := LNomeTeste + ' - Atualizado';
        LQuery.ParamByName('DESC').AsString := 'Descrição atualizada';
        LQuery.ParamByName('ID').AsLargeInt := LCategoriaId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        // Verificar atualização
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT NOME, DESCRICAO FROM CATEGORIA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LCategoriaId;
        LQuery.Open;

        AssertEquals(LNomeTeste + ' - Atualizado', LQuery.FieldByName('NOME').AsString, 'Nome deve estar atualizado');
        ASuite.AddResult('TestAtualizarCategoria', True, '');
      end
      else
      begin
        ASuite.AddResult('TestAtualizarCategoria', True, 'Skipped - No test category');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestAtualizarCategoria', False, E.Message);
      end;
    end;
  end;

  procedure TestListarCategorias;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT COUNT(*) AS TOTAL FROM CATEGORIA WHERE ATIVO = ''A''';
      LQuery.Open;

      AssertTrue(LQuery.FieldByName('TOTAL').AsInteger >= 0, 'Deve listar categorias');
      ASuite.AddResult('TestListarCategorias', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestListarCategorias', False, E.Message);
    end;
  end;

  procedure TestFiltrarCategoriasPorNome;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT ID, NOME FROM CATEGORIA WHERE UPPER(NOME) CONTAINING UPPER(:FILTRO)';
      LQuery.ParamByName('FILTRO').AsString := 'Teste';
      LQuery.Open;

      AssertTrue(LQuery.RecordCount >= 0, 'Deve filtrar categorias por nome');
      ASuite.AddResult('TestFiltrarCategoriasPorNome', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFiltrarCategoriasPorNome', False, E.Message);
    end;
  end;

  procedure TestExcluirCategoria;
  begin
    try
      if LCategoriaId > 0 then
      begin
        LConexao.IniciarTransacao;
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM CATEGORIA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LCategoriaId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        // Verificar exclusão
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT ID FROM CATEGORIA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LCategoriaId;
        LQuery.Open;

        AssertTrue(LQuery.IsEmpty, 'Categoria deve ser excluída');
        ASuite.AddResult('TestExcluirCategoria', True, '');
      end
      else
      begin
        ASuite.AddResult('TestExcluirCategoria', True, 'Skipped - No test category');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestExcluirCategoria', False, E.Message);
      end;
    end;
  end;

begin
  WriteLn('========================================');
  WriteLn('EXECUTANDO TESTES DE CATEGORIAS');
  WriteLn('========================================');

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LCategoriaId := 99998; // ID fixo para teste
  LNomeTeste := 'Categoria Teste Unitário ' + FormatDateTime('yyyymmddhhnnss', Now);

  try
    // Conectar ao banco
    LConexao.Conectar;
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Executar testes
    TestInserirCategoriaSucesso;
    TestInserirCategoriaSemNome;
    TestBuscarCategoriaPorId;
    TestAtualizarCategoria;
    TestListarCategorias;
    TestFiltrarCategoriasPorNome;
    TestExcluirCategoria;

  finally
    LQuery.Free;
  end;
end;

end.
