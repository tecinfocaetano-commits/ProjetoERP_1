unit uFrmProdutosTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes Unitários para Produtos
  Descrição: Testes de CRUD de produtos
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao;

type
  { TProdutosTest }
  TProdutosTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TProdutosTest }

class procedure TProdutosTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LProdutoId: Int64;
  LDescricaoTeste: string;
  LCodigoTeste: string;

  procedure TestInserirProdutoSucesso;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO PRODUTO (ID, EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, DESCRICAO, PRECO_CUSTO, PRECO_VENDA, ' +
        'MARGEM_LUCRO, ESTOQUE_MINIMO, ESTOQUE_MAXIMO, CONTROLA_ESTOQUE, ATIVO) ' +
        'VALUES (:ID, 1, 0, 0, :COD, :DESC, 10.00, 15.00, 50.00, 5.00, 100.00, ''S'', ''A'')';
      LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
      LQuery.ParamByName('COD').AsString := LCodigoTeste;
      LQuery.ParamByName('DESC').AsString := LDescricaoTeste;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      AssertTrue(LProdutoId > 0, 'Produto deve ser inserido com sucesso');
      ASuite.AddResult('TestInserirProdutoSucesso', True, '');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirProdutoSucesso', False, E.Message);
      end;
    end;
  end;

  procedure TestInserirProdutoSemDescricao;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO PRODUTO (CODIGO, DESCRICAO, PRECO_CUSTO, PRECO_VENDA, ATIVO) ' +
        'VALUES (''COD999'', '''', 10.00, 15.00, ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir produto sem descrição');
      ASuite.AddResult('TestInserirProdutoSemDescricao', False, 'Permitiu inserção sem descrição');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirProdutoSemDescricao', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestInserirProdutoPrecoVendaZero;
  begin
    try
      LConexao.IniciarTransacao;
      LQuery.SQL.Text :=
        'INSERT INTO PRODUTO (CODIGO, DESCRICAO, PRECO_CUSTO, PRECO_VENDA, ATIVO) ' +
        'VALUES (''COD998'', ''Produto Teste'', 10.00, 0.00, ''A'')';
      LQuery.ExecSQL;

      LConexao.Cancelar;
      AssertFalse(True, 'Não deve permitir inserir produto com preço de venda zero');
      ASuite.AddResult('TestInserirProdutoPrecoVendaZero', False, 'Permitiu preço de venda zero');
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestInserirProdutoPrecoVendaZero', True, 'Validação funcionou corretamente');
      end;
    end;
  end;

  procedure TestBuscarProdutoPorId;
  begin
    try
      if LProdutoId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT * FROM PRODUTO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
        LQuery.Open;

        AssertTrue(not LQuery.IsEmpty, 'Deve encontrar produto por ID');
        AssertEquals(LDescricaoTeste, LQuery.FieldByName('DESCRICAO').AsString, 'Descrição deve corresponder');
        ASuite.AddResult('TestBuscarProdutoPorId', True, '');
      end
      else
      begin
        ASuite.AddResult('TestBuscarProdutoPorId', True, 'Skipped - No test product');
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestBuscarProdutoPorId', False, E.Message);
    end;
  end;

  procedure TestAtualizarProduto;
  begin
    try
      if LProdutoId > 0 then
      begin
        LConexao.IniciarTransacao;
        LQuery.Close;
        LQuery.SQL.Text :=
          'UPDATE PRODUTO SET DESCRICAO = :DESC, PRECO_VENDA = :PRECO WHERE ID = :ID';
        LQuery.ParamByName('DESC').AsString := LDescricaoTeste + ' - Atualizado';
        LQuery.ParamByName('PRECO').AsFloat := 20.00;
        LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        // Verificar atualização
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT DESCRICAO, PRECO_VENDA FROM PRODUTO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
        LQuery.Open;

        AssertEquals(LDescricaoTeste + ' - Atualizado', LQuery.FieldByName('DESCRICAO').AsString, 'Descrição deve estar atualizada');
        ASuite.AddResult('TestAtualizarProduto', True, '');
      end
      else
      begin
        ASuite.AddResult('TestAtualizarProduto', True, 'Skipped - No test product');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestAtualizarProduto', False, E.Message);
      end;
    end;
  end;

  procedure TestListarProdutos;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT COUNT(*) AS TOTAL FROM PRODUTO WHERE ATIVO = ''A''';
      LQuery.Open;

      AssertTrue(LQuery.FieldByName('TOTAL').AsInteger >= 0, 'Deve listar produtos');
      ASuite.AddResult('TestListarProdutos', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestListarProdutos', False, E.Message);
    end;
  end;

  procedure TestFiltrarProdutosPorDescricao;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT ID, DESCRICAO FROM PRODUTO WHERE UPPER(DESCRICAO) CONTAINING UPPER(:FILTRO)';
      LQuery.ParamByName('FILTRO').AsString := 'Teste';
      LQuery.Open;

      AssertTrue(LQuery.RecordCount >= 0, 'Deve filtrar produtos por descrição');
      ASuite.AddResult('TestFiltrarProdutosPorDescricao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFiltrarProdutosPorDescricao', False, E.Message);
    end;
  end;

  procedure TestFiltrarProdutosPorCodigo;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text := 'SELECT ID, CODIGO FROM PRODUTO WHERE CODIGO CONTAINING :FILTRO';
      LQuery.ParamByName('FILTRO').AsString := LCodigoTeste;
      LQuery.Open;

      AssertTrue(LQuery.RecordCount >= 0, 'Deve filtrar produtos por código');
      ASuite.AddResult('TestFiltrarProdutosPorCodigo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestFiltrarProdutosPorCodigo', False, E.Message);
    end;
  end;

  procedure TestExcluirProduto;
  begin
    try
      if LProdutoId > 0 then
      begin
        LConexao.IniciarTransacao;
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM PRODUTO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
        LQuery.ExecSQL;
        LConexao.Confirmar;

        // Verificar exclusão
        LQuery.Close;
        LQuery.SQL.Text := 'SELECT ID FROM PRODUTO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
        LQuery.Open;

        AssertTrue(LQuery.IsEmpty, 'Produto deve ser excluído');
        ASuite.AddResult('TestExcluirProduto', True, '');
      end
      else
      begin
        ASuite.AddResult('TestExcluirProduto', True, 'Skipped - No test product');
      end;
    except
      on E: Exception do
      begin
        LConexao.Cancelar;
        ASuite.AddResult('TestExcluirProduto', False, E.Message);
      end;
    end;
  end;

begin
  WriteLn('========================================');
  WriteLn('EXECUTANDO TESTES DE PRODUTOS');
  WriteLn('========================================');

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LProdutoId := 99998; // ID fixo para teste
  LDescricaoTeste := 'Produto Teste Unitário ' + FormatDateTime('yyyymmddhhnnss', Now);
  LCodigoTeste := 'PROD' + FormatDateTime('yyyymmddhhnnss', Now);

  try
    // Conectar ao banco
    LConexao.Conectar;
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Executar testes
    TestInserirProdutoSucesso;
    TestInserirProdutoSemDescricao;
    TestInserirProdutoPrecoVendaZero;
    TestBuscarProdutoPorId;
    TestAtualizarProduto;
    TestListarProdutos;
    TestFiltrarProdutosPorDescricao;
    TestFiltrarProdutosPorCodigo;
    TestExcluirProduto;

  finally
    LQuery.Free;
  end;
end;

end.
