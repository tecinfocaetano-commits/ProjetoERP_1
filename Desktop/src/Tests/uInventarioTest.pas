unit uInventarioTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do Inventário de Estoque
  ------------------------------------------------------------
  Cobre TInventarioService:

    - listagem no escopo da empresa (EMPRESA_ID), inclusive
      produto de outra empresa com o mesmo filtro;
    - somente produtos CONTROLA_ESTOQUE='S' e ATIVO='A';
    - pesquisa por descrição e código (parametrizada);
    - filtros "apenas com estoque" e "abaixo do mínimo";
    - valor total do estoque (quantidade × custo) — conferido
      por diferença antes/depois para não depender do saldo
      real da empresa.

  Padrão da suíte: dados com sufixo de timestamp, limpeza
  explícita no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uInventarioService;

type
  { TInventarioTest }
  TInventarioTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TInventarioTest }

class procedure TInventarioTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LService: TInventarioService;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LSufixo: string;
  LSeq: Integer;
  LProdutoIds: array of Int64;
  LId, LId2, LIdOutra: Int64;
  LCount: Integer;
  LValorAntes, LValorDepois, LDelta: Double;
  LDesc: string;

  function NovoCodigo(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + Copy(LSufixo, 1, 8) + IntToStr(LSeq);
  end;

  function NovoTexto(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  procedure RegistrarProduto(AId: Int64);
  var
    LLen: Integer;
  begin
    LLen := Length(LProdutoIds);
    SetLength(LProdutoIds, LLen + 1);
    LProdutoIds[LLen] := AId;
  end;

  // ------------------------------------------------------------------
  // Helpers de banco
  // ------------------------------------------------------------------

  function CriarProduto(const ACodigo, ADescricao: string;
    APrecoCusto, AEstoqueMinimo: Double;
    AControlaEstoque: Char = 'S';
    AAtivo: Char = 'A'; AEmpresaId: Int64 = 0): Int64;
  begin
    if AEmpresaId = 0 then
      AEmpresaId := LSessao.EmpresaId;
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
      '  DESCRICAO, PRECO_CUSTO, PRECO_VENDA, ESTOQUE_MINIMO, ' +
      '  CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, 1, 1, :COD, :DESC, :PCUSTO, :PVENDA, :EMIN, ' +
      '  :CESTOQUE, :ATIVO) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('COD').AsString := ACodigo;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('PCUSTO').AsFloat := APrecoCusto;
    LQuery.ParamByName('PVENDA').AsFloat := APrecoCusto * 2;
    LQuery.ParamByName('EMIN').AsFloat := AEstoqueMinimo;
    LQuery.ParamByName('CESTOQUE').AsString := AControlaEstoque;
    LQuery.ParamByName('ATIVO').AsString := AAtivo;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
    if AEmpresaId = LSessao.EmpresaId then
      RegistrarProduto(Result);
  end;

  procedure CriarOuAtualizarEstoque(AProdutoId: Int64; AQuantidade: Double);
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT FIRST 1 ID FROM ESTOQUE WHERE PRODUTO_ID = :PROD';
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    if LQuery.IsEmpty then
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO ESTOQUE (EMPRESA_ID, PRODUTO_ID, QUANTIDADE) ' +
        'VALUES (:EMP, :PROD, :QTD)';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
      LQuery.ParamByName('QTD').AsFloat := AQuantidade;
      LQuery.ExecSQL;
    end
    else
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE ESTOQUE SET QUANTIDADE = :QTD WHERE PRODUTO_ID = :PROD';
      LQuery.ParamByName('QTD').AsFloat := AQuantidade;
      LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
      LQuery.ExecSQL;
    end;
    LConexao.Confirmar;
  end;

  procedure ApagarProdutos(const AIds: array of Int64);
  var
    I: Integer;
  begin
    for I := 0 to High(AIds) do
    begin
      try
        LQuery.Close;
        LQuery.SQL.Text :=
          'DELETE FROM ESTOQUE WHERE PRODUTO_ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := AIds[I];
        LQuery.ExecSQL;
        LQuery.SQL.Text :=
          'DELETE FROM PRODUTO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := AIds[I];
        LQuery.ExecSQL;
      except
      end;
    end;
    LConexao.Confirmar;
  end;

  function ContarLista: Integer;
  begin
    Result := 0;
    LLista.First;
    while not LLista.EOF do
    begin
      Inc(Result);
      LLista.Next;
    end;
  end;

begin
  LConexao := TConexao.GetInstance;
  if not LConexao.Conectado then
    LConexao.Conectar;
  LSessao := TSessao.GetInstance;
  LService := TInventarioService.Create;
  LQuery := TSQLQuery.Create(nil);
  LLista := TSQLQuery.Create(nil);
  LQuery.DataBase := LConexao.Connection;
  LQuery.Transaction := LConexao.Transaction;
  LLista.DataBase := LConexao.Connection;
  LLista.Transaction := LConexao.Transaction;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LProdutoIds := nil;

  try
    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DO INVENTÁRIO');
    WriteLn('========================================');

    // Escopo da empresa + CONTROLA_ESTOQUE='S' + ATIVO='A'
    try
      LId := CriarProduto(NovoCodigo('INVA'),
        NovoTexto('INVENTARIO ESCOPO A'), 10, 5);
      LId2 := CriarProduto(NovoCodigo('INVB'),
        NovoTexto('INVENTARIO ESCOPO B'), 10, 5);
      LIdOutra := CriarProduto(NovoCodigo('INVO'),
        LSufixo + ' OUTRA EMPRESA', 10, 5, 'S', 'A', 999999);

      LService.CarregarInventario(LLista, LSufixo);
      AssertEquals('2', IntToStr(ContarLista),
        'só os 2 produtos da empresa devem aparecer');
      ASuite.AddResult('TestInvEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvEscopoEmpresa', False, E.Message);
    end;

    // Somente CONTROLA_ESTOQUE='S'
    try
      CriarProduto(NovoCodigo('INVS'), NovoTexto('CTRL S INVENTARIO'),
        10, 5, 'S');
      CriarProduto(NovoCodigo('INVN'), NovoTexto('CTRL N INVENTARIO'),
        10, 5, 'N');
      LService.CarregarInventario(LLista, 'CTRL');
      LCount := 0;
      LLista.First;
      while not LLista.EOF do
      begin
        Inc(LCount);
        AssertTrue(
          Pos('CTRL N', LLista.FieldByName('DESCRICAO').AsString) = 0,
          'produto com CONTROLA_ESTOQUE=N não deve aparecer');
        LLista.Next;
      end;
      AssertEquals('1', IntToStr(LCount),
        'só o produto com CONTROLA_ESTOQUE=S deve aparecer');
      ASuite.AddResult('TestInvSoControlaEstoqueS', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvSoControlaEstoqueS', False, E.Message);
    end;

    // Somente ATIVO='A'
    try
      LDesc := NovoTexto('INVENTARIO INATIVO');
      LId := CriarProduto(NovoCodigo('INVI'), LDesc, 10, 5, 'S', 'I');
      LService.CarregarInventario(LLista, LDesc);
      AssertEquals('0', IntToStr(ContarLista),
        'produto inativo não deve aparecer no inventário');
      ASuite.AddResult('TestInvSoAtivoA', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvSoAtivoA', False, E.Message);
    end;

    // Pesquisa por descrição
    try
      CriarProduto(NovoCodigo('INVP'),
        NovoTexto('INVENTARIO PESQ UNICO XYZ'), 10, 5);
      CriarProduto(NovoCodigo('INVP'),
        NovoTexto('INVENTARIO PESQ OUTRO'), 10, 5);
      LService.CarregarInventario(LLista, 'UNICO XYZ ' + LSufixo);
      AssertEquals('1', IntToStr(ContarLista),
        'pesquisa por descrição deve achar 1 produto');
      ASuite.AddResult('TestInvPesquisaDescricao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvPesquisaDescricao', False, E.Message);
    end;

    // Pesquisa por código
    try
      LId := CriarProduto(NovoCodigo('CODXYZ'),
        NovoTexto('INVENTARIO CODIGO'), 10, 5);
      CriarProduto(NovoCodigo('CODABC'),
        NovoTexto('INVENTARIO CODIGO B'), 10, 5);
      LService.CarregarInventario(LLista, 'CODXYZ');
      LCount := 0;
      LLista.First;
      while not LLista.EOF do
      begin
        if LLista.FieldByName('ID').AsLargeInt = LId then
          Inc(LCount);
        LLista.Next;
      end;
      AssertEquals('1', IntToStr(LCount),
        'pesquisa por código deve achar o produto certo');
      ASuite.AddResult('TestInvPesquisaCodigo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvPesquisaCodigo', False, E.Message);
    end;

    // Filtro apenas com estoque
    try
      LId := CriarProduto(NovoCodigo('INVCE'),
        NovoTexto('COM ESTOQUE FILTRO'), 10, 5);
      LId2 := CriarProduto(NovoCodigo('INVN E'),
        NovoTexto('SEM ESTOQUE FILTRO'), 10, 5);
      CriarOuAtualizarEstoque(LId, 100);
      LService.CarregarInventario(LLista, 'FILTRO', True, False);
      AssertEquals('1', IntToStr(ContarLista),
        'só o produto com estoque deve aparecer');
      LLista.First;
      AssertTrue(Pos('COM ESTOQUE',
        LLista.FieldByName('DESCRICAO').AsString) > 0,
        'o produto listado deve ser o que tem estoque');
      ASuite.AddResult('TestInvApenasComEstoque', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvApenasComEstoque', False, E.Message);
    end;

    // Filtro abaixo do mínimo
    try
      LId := CriarProduto(NovoCodigo('INVAM'),
        NovoTexto('ABAIXO MIN FILTRO'), 10, 50);
      LId2 := CriarProduto(NovoCodigo('INVAM'),
        NovoTexto('ACIMA MIN FILTRO'), 10, 10);
      CriarOuAtualizarEstoque(LId, 10);   // 10 < 50 -> abaixo
      CriarOuAtualizarEstoque(LId2, 100); // 100 > 10 -> acima
      LService.CarregarInventario(LLista, 'MIN FILTRO', False, True);
      AssertEquals('1', IntToStr(ContarLista),
        'só o produto abaixo do mínimo deve aparecer');
      LLista.First;
      AssertTrue(Pos('ABAIXO MIN',
        LLista.FieldByName('DESCRICAO').AsString) > 0,
        'o produto listado deve ser o abaixo do mínimo');
      ASuite.AddResult('TestInvAbaixoMinimo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvAbaixoMinimo', False, E.Message);
    end;

    // Valor total do estoque por diferença (não depende do saldo real)
    try
      LValorAntes := LService.ValorTotalEstoque;
      LId := CriarProduto(NovoCodigo('INVVT'),
        NovoTexto('INVENTARIO VALOR'), 10, 5);
      CriarOuAtualizarEstoque(LId, 100);
      LValorDepois := LService.ValorTotalEstoque;
      LDelta := LValorDepois - LValorAntes;
      AssertTrue(Abs(LDelta - 1000) < 0.01,
        'o delta do valor total deve ser 1000 (100 x custo 10), veio ' +
        FloatToStr(LDelta));
      ASuite.AddResult('TestInvValorTotalEstoque', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestInvValorTotalEstoque', False, E.Message);
    end;

  finally
    ApagarProdutos(LProdutoIds);
    // produto de outra empresa criado para o teste de escopo
    try
      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM PRODUTO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LIdOutra;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
    end;
    LLista.Free;
    LQuery.Free;
    LService.Free;
  end;
end;

end.
