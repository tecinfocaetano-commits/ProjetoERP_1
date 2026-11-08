unit uKardexTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do Kardex do Produto
  ------------------------------------------------------------
  Cobre TKardexService:

    - busca de produto por código, código de barras ou ID,
      somente da empresa da sessão;
    - carregamento de movimentos por produto e período,
      com pesquisa em documento/observação;
    - resumo de entradas/saídas/saldo;
    - movimento gravado em outra empresa no mesmo produto
      não entra no kardex.

  Padrão da suíte: dados com sufixo de timestamp, limpeza
  explícita no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uKardexService;

type
  { TKardexTest }
  TKardexTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TKardexTest }

class procedure TKardexTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LService: TKardexService;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LSufixo: string;
  LSeq: Integer;
  LProdutoIds: array of Int64;
  LProdutoId, LId, LId2: Int64;
  LEstoqueAtual: Double;
  LDescricao: string;
  LResumo: TKardexResumo;
  LCount: Integer;
  LCodigo, LCodigoBarras, LDesc, LDoc: string;

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
    APrecoCusto, APrecoVenda: Double;
    AEmpresaId: Int64 = 0): Int64;
  begin
    if AEmpresaId = 0 then
      AEmpresaId := LSessao.EmpresaId;
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
      '  CODIGO_BARRAS, DESCRICAO, PRECO_CUSTO, PRECO_VENDA, ' +
      '  CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, 1, 1, :COD, :BARRAS, :DESC, :PCUSTO, :PVENDA, ' +
      '  ''S'', ''A'') RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('COD').AsString := ACodigo;
    LQuery.ParamByName('BARRAS').AsString := '789' + ACodigo;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('PCUSTO').AsFloat := APrecoCusto;
    LQuery.ParamByName('PVENDA').AsFloat := APrecoVenda;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
    if AEmpresaId = LSessao.EmpresaId then
      RegistrarProduto(Result);
  end;

  procedure CriarMovimento(AProdutoId, AEmpresaId: Int64; ATipo: Char;
    AQuantidade, ACustoUnitario: Double; ADataMovimento: TDateTime;
    const ADocumento, AObservacao: string);
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, ' +
      '  QUANTIDADE, CUSTO_UNITARIO, DATA_MOVIMENTO, DOCUMENTO, ' +
      '  OBSERVACAO, USUARIO_ID) ' +
      'VALUES (:EMP, :PROD, :TIPO, :QTD, :CUSTO, :DATA, :DOC, :OBS, :USR)';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('CUSTO').AsFloat := ACustoUnitario;
    LQuery.ParamByName('DATA').AsDateTime := ADataMovimento;
    LQuery.ParamByName('DOC').AsString := ADocumento;
    LQuery.ParamByName('OBS').AsString := AObservacao;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    LQuery.ExecSQL;
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
          'DELETE FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := AIds[I];
        LQuery.ExecSQL;
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
  LService := TKardexService.Create;
  LQuery := TSQLQuery.Create(nil);
  LLista := TSQLQuery.Create(nil);
  LQuery.DataBase := LConexao.Connection;
  LQuery.Transaction := LConexao.Transaction;
  LLista.DataBase := LConexao.Connection;
  LLista.Transaction := LConexao.Transaction;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LProdutoIds := nil;
  LDoc := 'KDX' + Copy(LSufixo, 1, 10);

  try
    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DO KARDEX');
    WriteLn('========================================');

    // Produto base dos testes de kardex
    LCodigo := NovoCodigo('KDX');
    LCodigoBarras := '789' + LCodigo;
    LDesc := NovoTexto('KARDEX PRODUTO');
    LProdutoId := CriarProduto(LCodigo, LDesc, 10, 20);

    // Buscar por código
    try
      AssertTrue(LService.BuscarProduto(LCodigo, LId, LDescricao,
        LEstoqueAtual), 'deve achar pelo código');
      AssertEquals(IntToStr(LProdutoId), IntToStr(LId), 'ID correto');
      AssertEquals(LDesc, LDescricao, 'descrição correta');
      ASuite.AddResult('TestKdxBuscarPorCodigo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxBuscarPorCodigo', False, E.Message);
    end;

    // Buscar por código de barras
    try
      AssertTrue(LService.BuscarProduto(LCodigoBarras, LId, LDescricao,
        LEstoqueAtual), 'deve achar pelo código de barras');
      AssertEquals(IntToStr(LProdutoId), IntToStr(LId), 'ID correto');
      ASuite.AddResult('TestKdxBuscarPorCodigoBarras', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxBuscarPorCodigoBarras', False, E.Message);
    end;

    // Buscar por ID
    try
      AssertTrue(LService.BuscarProduto(IntToStr(LProdutoId), LId,
        LDescricao, LEstoqueAtual), 'deve achar pelo ID');
      AssertEquals(IntToStr(LProdutoId), IntToStr(LId), 'ID correto');
      ASuite.AddResult('TestKdxBuscarPorId', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxBuscarPorId', False, E.Message);
    end;

    // Não encontrado + produto de outra empresa
    try
      AssertFalse(LService.BuscarProduto('KDXNE' + Copy(LSufixo, 1, 8),
        LId, LDescricao, LEstoqueAtual), 'inexistente deve dar False');
      LId2 := CriarProduto(NovoCodigo('KDXO'),
        LSufixo + ' KARDEX OUTRA EMP', 10, 20, 999999);
      AssertFalse(LService.BuscarProduto(
        IntToStr(LId2), LId, LDescricao, LEstoqueAtual),
        'produto de outra empresa deve dar False');
      ASuite.AddResult('TestKdxBuscarNaoEncontrado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxBuscarNaoEncontrado', False, E.Message);
    end;

    // Kardex por período + empresa
    try
      CriarMovimento(LProdutoId, LSessao.EmpresaId, 'E', 100, 10,
        EncodeDate(2020, 1, 5), LDoc + 'A', 'Entrada teste');
      CriarMovimento(LProdutoId, LSessao.EmpresaId, 'S', 40, 10,
        EncodeDate(2020, 1, 10), LDoc + 'B', 'Saída teste');
      CriarMovimento(LProdutoId, 999999, 'E', 999, 10,
        EncodeDate(2020, 1, 6), LDoc + 'C', 'Outra empresa');

      LService.CarregarKardex(LLista, LProdutoId,
        EncodeDate(2020, 1, 1), EncodeDate(2020, 12, 31), LDoc);
      AssertEquals('2', IntToStr(ContarLista),
        'só os 2 movimentos da empresa devem aparecer');
      ASuite.AddResult('TestKdxKardexEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxKardexEscopoEmpresa', False, E.Message);
    end;

    // Filtro de período
    try
      LService.CarregarKardex(LLista, LProdutoId,
        EncodeDate(2020, 1, 1), EncodeDate(2020, 1, 7), LDoc);
      AssertEquals('1', IntToStr(ContarLista),
        'só o movimento de 05/01 deve aparecer no período');
      ASuite.AddResult('TestKdxKardexFiltroPeriodo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxKardexFiltroPeriodo', False, E.Message);
    end;

    // Pesquisa por documento
    try
      CriarMovimento(LProdutoId, LSessao.EmpresaId, 'E', 5, 10,
        EncodeDate(2020, 2, 1), LDoc + 'UNICO', 'Doc único');
      LService.CarregarKardex(LLista, LProdutoId,
        EncodeDate(2020, 1, 1), EncodeDate(2020, 12, 31), 'UNICO');
      AssertEquals('1', IntToStr(ContarLista),
        'pesquisa por documento deve achar 1 movimento');
      ASuite.AddResult('TestKdxKardexPesquisaDocumento', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxKardexPesquisaDocumento', False,
          E.Message);
    end;

    // Pesquisa por observação
    try
      CriarMovimento(LProdutoId, LSessao.EmpresaId, 'S', 5, 10,
        EncodeDate(2020, 2, 2), 'DOCX', 'Observacao Unica ' + LSufixo);
      LService.CarregarKardex(LLista, LProdutoId,
        EncodeDate(2020, 1, 1), EncodeDate(2020, 12, 31),
        'Observacao Unica');
      AssertEquals('1', IntToStr(ContarLista),
        'pesquisa por observação deve achar 1 movimento');
      ASuite.AddResult('TestKdxKardexPesquisaObservacao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxKardexPesquisaObservacao', False,
          E.Message);
    end;

    // Resumo entradas/saídas/saldo em jan/2020 com filtro LDoc:
    // E100 (05/01) e S40 (10/01); o E999 é de outra empresa e o
    // E5/S5 são de fevereiro.
    try
      LService.CarregarResumo(LProdutoId, EncodeDate(2020, 1, 1),
        EncodeDate(2020, 1, 31), LDoc, LResumo);
      AssertTrue(Abs(LResumo.Entradas - 100) < 0.001,
        'entradas devem ser 100, veio ' + FloatToStr(LResumo.Entradas));
      AssertTrue(Abs(LResumo.Saidas - 40) < 0.001,
        'saídas devem ser 40, veio ' + FloatToStr(LResumo.Saidas));
      AssertTrue(Abs(LResumo.Saldo - 60) < 0.001,
        'saldo deve ser 60, veio ' + FloatToStr(LResumo.Saldo));
      ASuite.AddResult('TestKdxResumoEntradasSaidas', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxResumoEntradasSaidas', False, E.Message);
    end;

    // Resumo período vazio
    try
      LService.CarregarResumo(LProdutoId, EncodeDate(2021, 1, 1),
        EncodeDate(2021, 12, 31), LDoc, LResumo);
      AssertTrue((LResumo.Entradas = 0) and (LResumo.Saidas = 0) and
        (LResumo.Saldo = 0),
        'período sem movimentos deve zerar o resumo');
      ASuite.AddResult('TestKdxResumoPeriodoVazio', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxResumoPeriodoVazio', False, E.Message);
    end;

    // Produto de outra empresa no resumo não entra
    try
      LId2 := CriarProduto(NovoCodigo('KDXP'),
        LSufixo + ' KARDEX PROD OUTRA', 10, 20, 999999);
      CriarMovimento(LId2, 999999, 'E', 777, 10,
        EncodeDate(2020, 1, 15), LDoc + 'OUTRA', 'Outra empresa');
      LService.CarregarResumo(LId2, EncodeDate(2020, 1, 1),
        EncodeDate(2020, 12, 31), LDoc, LResumo);
      AssertTrue(LResumo.Entradas = 0,
        'resumo de produto de outra empresa deve vir zerado');
      ASuite.AddResult('TestKdxResumoOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestKdxResumoOutraEmpresa', False, E.Message);
    end;

  finally
    ApagarProdutos(LProdutoIds);
    // limpeza dos produtos auxiliares de outra empresa
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM MOVIMENTO_ESTOQUE WHERE EMPRESA_ID = 999999 ' +
        'AND OBSERVACAO CONTAINING :SUF';
      LQuery.ParamByName('SUF').AsString := LSufixo;
      LQuery.ExecSQL;
      LQuery.SQL.Text :=
        'DELETE FROM PRODUTO WHERE EMPRESA_ID = 999999 ' +
        'AND DESCRICAO CONTAINING :SUF';
      LQuery.ParamByName('SUF').AsString := LSufixo;
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
