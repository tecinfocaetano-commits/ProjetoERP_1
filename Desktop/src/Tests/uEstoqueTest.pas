unit uEstoqueTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes de movimentação de estoque
  ------------------------------------------------------------
  Cobre TEstoqueService (extraído de uFrmMovEstoque):

    - registro: grava empresa, produto, tipo, quantidade, custo,
      documento, observação e usuário da sessão; devolve o ID e
      audita INSERT;
    - validações: produto existente na empresa, tipo E/S/A/I,
      quantidade > 0, custo não negativo e limites de documento
      (50) e observação (255);
    - efeito da trigger TRG_MOVEST_AI: E e A somam, S subtrai,
      I não altera o saldo e a linha de ESTOQUE é criada quando
      não existe;
    - saldo: soma por empresa/produto, isolado por empresa;
    - listagem: período com dia final inclusive, tipo, pesquisa
      por descrição/código/documento (texto longo sem "string
      right truncation") e escopo da empresa da sessão.

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco. A trigger roda de verdade.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao, uEstoqueService;

type
  { TEstoqueTest }
  TEstoqueTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

uses
  DateUtils;

{ TEstoqueTest }

class procedure TEstoqueTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LEstoque: TEstoqueService;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;
  LProdutoEntrada: Int64;
  LProdutoSaida: Int64;
  LProdutoAjuste: Int64;
  LProdutoInventario: Int64;
  LProdutoLista: Int64;
  LTokenLista: string;

  function QuaseIgual(A, B: Double): Boolean;
  begin
    Result := Abs(A - B) < 0.001;
  end;

  function Codigo(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + Copy(LSufixo, 1, 10) + IntToStr(LSeq);
  end;

  function Descricao(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  function CriarProduto(const ADescricao: string; AEmpresaId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
      '  DESCRICAO, PRECO_CUSTO, PRECO_VENDA, CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, 1, 1, :COD, :DESC, 1, 2, ''S'', ''A'') RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('COD').AsString := Codigo('EST');
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function ContarMovimentos(AProdutoId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID = :PROD';
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarMovimentosTotal: Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM MOVIMENTO_ESTOQUE';
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarEstoque(AProdutoId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM ESTOQUE WHERE PRODUTO_ID = :PROD';
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function TextoMovimento(const ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(1000)) AS VALOR ' +
      'FROM MOVIMENTO_ESTOQUE WHERE ID = :ID';
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
      'SELECT ' + ACampo + ' AS VALOR FROM MOVIMENTO_ESTOQUE WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsFloat;
    LQuery.Close;
  end;

  function DataMovimento(AId: Int64): TDateTime;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT DATA_MOVIMENTO AS VALOR FROM MOVIMENTO_ESTOQUE WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsDateTime;
    LQuery.Close;
  end;

  function ContarLog(AId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM LOG_SISTEMA WHERE TABELA = ''MOVIMENTO_ESTOQUE'' ' +
      '  AND OPERACAO = ''INSERT'' AND REGISTRO_ID = :REG';
    LQuery.ParamByName('REG').AsLargeInt := AId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
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

  procedure InserirMovimentoDireto(AProdutoId, AEmpresaId: Int64;
    const ATipo: string; AQuantidade: Double; const ADocumento: string;
    AData: TDateTime);
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, ' +
      '  QUANTIDADE, CUSTO_UNITARIO, DOCUMENTO, OBSERVACAO, USUARIO_ID, ' +
      '  DATA_MOVIMENTO) ' +
      'VALUES (:EMP, :PROD, :TIPO, :QTD, 0, :DOC, '''', :USR, :DATA)';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('TIPO').AsString := ATipo;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('DOC').AsString := ADocumento;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    LQuery.ParamByName('DATA').AsDateTime := AData;
    LQuery.ExecSQL;
    LConexao.Confirmar;
  end;

  // ------------------------------------------------------------------
  // Registro e efeito da trigger
  // ------------------------------------------------------------------

  procedure TestRegistrarEntrada;
  var
    LId: Int64;
    LDoc, LObs: string;
  begin
    try
      LDoc := 'DOC ' + LSufixo;
      LObs := 'OBS ' + LSufixo;
      LId := LEstoque.RegistrarMovimento(LProdutoEntrada, 'E', 10, 5.25,
        LDoc, LObs);

      AssertTrue(LId > 0, 'RegistrarMovimento deve devolver o ID');
      AssertEquals('1', IntToStr(ContarMovimentos(LProdutoEntrada)),
        'o movimento deve existir uma vez');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        TextoMovimento('EMPRESA_ID', LId),
        'o movimento deve pertencer à empresa da sessão');
      AssertEquals(IntToStr(LProdutoEntrada),
        TextoMovimento('PRODUTO_ID', LId), 'o produto deve ser gravado');
      AssertEquals('E', TextoMovimento('TIPO', LId),
        'o tipo de entrada deve ser gravado');
      AssertEquals(IntToStr(LSessao.UsuarioId),
        TextoMovimento('USUARIO_ID', LId),
        'o usuário da sessão deve ser gravado');
      AssertTrue(QuaseIgual(10, FloatMovimento('QUANTIDADE', LId)),
        'a quantidade deve ser gravada');
      AssertTrue(QuaseIgual(5.25, FloatMovimento('CUSTO_UNITARIO', LId)),
        'o custo unitário deve ser gravado');
      AssertEquals(LDoc, TextoMovimento('DOCUMENTO', LId),
        'o documento deve ser gravado');
      AssertEquals(LObs, TextoMovimento('OBSERVACAO', LId),
        'a observação deve ser gravada');
      AssertFalse(DataMovimento(LId) = 0,
        'a data do movimento deve ser preenchida pela trigger');
      AssertTrue(ContarLog(LId) = 1,
        'o registro deve gerar auditoria INSERT');
      AssertTrue(QuaseIgual(10, LEstoque.SaldoProduto(LProdutoEntrada)),
        'a entrada deve somar no saldo pela trigger');
      AssertTrue(ContarEstoque(LProdutoEntrada) = 1,
        'a trigger deve criar a linha de ESTOQUE');

      ASuite.AddResult('TestEstoqueRegistrarEntrada', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarEntrada', False, E.Message);
    end;
  end;

  procedure TestRegistrarSaida;
  var
    LId: Int64;
  begin
    try
      LEstoque.RegistrarMovimento(LProdutoSaida, 'E', 10, 4, 'ENTRADA');
      LId := LEstoque.RegistrarMovimento(LProdutoSaida, 'S', 3, 4, 'SAIDA');

      AssertEquals('S', TextoMovimento('TIPO', LId),
        'o tipo de saída deve ser gravado');
      AssertTrue(QuaseIgual(7, LEstoque.SaldoProduto(LProdutoSaida)),
        'a saída deve subtrair do saldo pela trigger');
      AssertTrue(ContarMovimentos(LProdutoSaida) = 2,
        'entrada e saída devem ficar registradas');

      ASuite.AddResult('TestEstoqueRegistrarSaida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarSaida', False, E.Message);
    end;
  end;

  procedure TestRegistrarAjusteSoma;
  var
    LId: Int64;
  begin
    try
      LEstoque.RegistrarMovimento(LProdutoAjuste, 'E', 5, 1, 'ENTRADA');
      LId := LEstoque.RegistrarMovimento(LProdutoAjuste, 'A', 2.5, 1, 'AJUSTE');

      AssertEquals('A', TextoMovimento('TIPO', LId),
        'o tipo de ajuste deve ser gravado');
      AssertTrue(QuaseIgual(7.5, LEstoque.SaldoProduto(LProdutoAjuste)),
        'o ajuste deve somar no saldo pela trigger');

      ASuite.AddResult('TestEstoqueRegistrarAjusteSoma', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarAjusteSoma', False, E.Message);
    end;
  end;

  procedure TestRegistrarInventarioNaoAlteraSaldo;
  var
    LId: Int64;
  begin
    try
      LEstoque.RegistrarMovimento(LProdutoInventario, 'E', 8, 2, 'ENTRADA');
      LId := LEstoque.RegistrarMovimento(LProdutoInventario, 'I', 3, 2,
        'INVENTARIO');

      AssertEquals('I', TextoMovimento('TIPO', LId),
        'o tipo de inventário deve ser gravado');
      AssertTrue(QuaseIgual(3, FloatMovimento('QUANTIDADE', LId)),
        'a quantidade inventariada deve ser gravada');
      AssertTrue(QuaseIgual(8, LEstoque.SaldoProduto(LProdutoInventario)),
        'o inventário não altera o saldo pela trigger');
      AssertTrue(ContarMovimentos(LProdutoInventario) = 2,
        'o inventário deve ficar registrado como movimento');

      ASuite.AddResult('TestEstoqueRegistrarInventarioNaoAlteraSaldo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarInventarioNaoAlteraSaldo',
          False, E.Message);
    end;
  end;

  procedure TestInventarioCriaSaldoZerado;
  var
    LProdutoId: Int64;
  begin
    try
      LProdutoId := CriarProduto(Descricao('ESTOQUE INVENTARIO NOVO'),
        LSessao.EmpresaId);
      AssertTrue(ContarEstoque(LProdutoId) = 0,
        'produto novo não deve ter linha em ESTOQUE');
      LEstoque.RegistrarMovimento(LProdutoId, 'I', 4, 0, 'INVENTARIO');

      AssertTrue(ContarEstoque(LProdutoId) = 1,
        'a trigger deve criar a linha de ESTOQUE no inventário');
      AssertTrue(QuaseIgual(0, LEstoque.SaldoProduto(LProdutoId)),
        'o inventário cria a linha com saldo zero');

      ASuite.AddResult('TestEstoqueInventarioCriaSaldoZerado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueInventarioCriaSaldoZerado', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Validações
  // ------------------------------------------------------------------

  procedure TestRegistrarProdutoInvalido;
  var
    LAntes: Integer;
    LDeu: Boolean;
  begin
    try
      LAntes := ContarMovimentosTotal;

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(0, 'E', 1, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'produto 0 deve ser recusado');

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(999999999, 'E', 1, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'produto inexistente deve ser recusado');
      AssertEquals(IntToStr(LAntes), IntToStr(ContarMovimentosTotal),
        'nada deve ser gravado');

      ASuite.AddResult('TestEstoqueRegistrarProdutoInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarProdutoInvalido', False,
          E.Message);
    end;
  end;

  procedure TestRegistrarProdutoOutraEmpresa;
  var
    LProdutoId: Int64;
    LAntes: Integer;
    LDeu: Boolean;
  begin
    try
      LProdutoId := CriarProduto(Descricao('ESTOQUE OUTRA EMPRESA'), 999999);
      LAntes := ContarMovimentosTotal;

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoId, 'E', 1, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'produto de outra empresa deve ser recusado');
      AssertEquals(IntToStr(LAntes), IntToStr(ContarMovimentosTotal),
        'nada deve ser gravado');
      AssertTrue(ContarMovimentos(LProdutoId) = 0,
        'o produto de outra empresa não pode receber movimento');

      ASuite.AddResult('TestEstoqueRegistrarProdutoOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarProdutoOutraEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestRegistrarTipoInvalido;
  var
    LAntes: Integer;
    LDeu: Boolean;
  begin
    try
      LAntes := ContarMovimentosTotal;

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoEntrada, 'X', 1, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'tipo X deve ser recusado');

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoEntrada, '', 1, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'tipo vazio deve ser recusado');
      AssertEquals(IntToStr(LAntes), IntToStr(ContarMovimentosTotal),
        'nada deve ser gravado');

      ASuite.AddResult('TestEstoqueRegistrarTipoInvalido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarTipoInvalido', False, E.Message);
    end;
  end;

  procedure TestRegistrarQuantidadeInvalida;
  var
    LAntes: Integer;
    LDeu: Boolean;
  begin
    try
      LAntes := ContarMovimentosTotal;

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoEntrada, 'E', 0, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'quantidade zero deve ser recusada');

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoEntrada, 'E', -2, 1);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'quantidade negativa deve ser recusada');
      AssertEquals(IntToStr(LAntes), IntToStr(ContarMovimentosTotal),
        'nada deve ser gravado');

      ASuite.AddResult('TestEstoqueRegistrarQuantidadeInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarQuantidadeInvalida', False,
          E.Message);
    end;
  end;

  procedure TestRegistrarCustoNegativo;
  var
    LAntes: Integer;
    LDeu: Boolean;
  begin
    try
      LAntes := ContarMovimentosTotal;
      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoEntrada, 'E', 1, -0.01);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'custo negativo deve ser recusado');
      AssertEquals(IntToStr(LAntes), IntToStr(ContarMovimentosTotal),
        'nada deve ser gravado');

      ASuite.AddResult('TestEstoqueRegistrarCustoNegativo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarCustoNegativo', False,
          E.Message);
    end;
  end;

  procedure TestRegistrarLimitesTexto;
  var
    LId: Int64;
    LDeu: Boolean;
    LDoc50, LObs255: string;
  begin
    try
      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoEntrada, 'E', 1, 1,
          StringOfChar('D', 51));
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'documento com 51 caracteres deve ser recusado');

      LDeu := False;
      try
        LEstoque.RegistrarMovimento(LProdutoEntrada, 'E', 1, 1, '',
          StringOfChar('O', 256));
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'observação com 256 caracteres deve ser recusada');

      LDoc50 := StringOfChar('D', 50);
      LObs255 := StringOfChar('O', 255);
      LId := LEstoque.RegistrarMovimento(LProdutoEntrada, 'E', 1, 1,
        LDoc50, LObs255);
      AssertEquals(LDoc50, TextoMovimento('DOCUMENTO', LId),
        'documento com 50 caracteres deve ser aceito');
      AssertEquals(LObs255, TextoMovimento('OBSERVACAO', LId),
        'observação com 255 caracteres deve ser aceita');

      ASuite.AddResult('TestEstoqueRegistrarLimitesTexto', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueRegistrarLimitesTexto', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Saldo
  // ------------------------------------------------------------------

  procedure TestSaldoProdutoInexistente;
  var
    LDeu: Boolean;
  begin
    try
      AssertTrue(QuaseIgual(0, LEstoque.SaldoProduto(999999999)),
        'produto sem estoque deve ter saldo zero');

      LDeu := False;
      try
        LEstoque.SaldoProduto(0);
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'produto inválido deve ser recusado');

      ASuite.AddResult('TestEstoqueSaldoProdutoInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueSaldoProdutoInexistente', False,
          E.Message);
    end;
  end;

  procedure TestSaldoEscopoEmpresa;
  var
    LProdutoId: Int64;
  begin
    try
      LProdutoId := CriarProduto(Descricao('ESTOQUE SALDO ESCOPO'),
        LSessao.EmpresaId);
      LEstoque.RegistrarMovimento(LProdutoId, 'E', 2, 1);

      { linha de ESTOQUE de outra empresa para o mesmo produto }
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO ESTOQUE (EMPRESA_ID, PRODUTO_ID, QUANTIDADE, ' +
        '  DATA_ATUALIZACAO) VALUES (999999, :PROD, 500, CURRENT_TIMESTAMP)';
      LQuery.ParamByName('PROD').AsLargeInt := LProdutoId;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      AssertTrue(QuaseIgual(2, LEstoque.SaldoProduto(LProdutoId)),
        'o saldo deve somar apenas a empresa da sessão');

      ASuite.AddResult('TestEstoqueSaldoEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueSaldoEscopoEmpresa', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Listagem
  // ------------------------------------------------------------------

  procedure TestCarregarMovimentosPeriodo;
  var
    LIdEntrada, LIdSaida, LIdAjuste: Int64;
    LPrimeiraData: TDateTime;
  begin
    try
      { token com 50 caracteres: maior que CODIGO (30), prova o CAST }
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE PRODUTO SET DESCRICAO = :DESC WHERE ID = :ID';
      LQuery.ParamByName('DESC').AsString := LTokenLista + ' PRODUTO';
      LQuery.ParamByName('ID').AsLargeInt := LProdutoLista;
      LQuery.ExecSQL;
      LConexao.Confirmar;

      LIdEntrada := LEstoque.RegistrarMovimento(LProdutoLista, 'E', 10, 3,
        'NF ' + LSufixo);
      LIdSaida := LEstoque.RegistrarMovimento(LProdutoLista, 'S', 2, 3,
        'NF ' + LSufixo);
      LIdAjuste := LEstoque.RegistrarMovimento(LProdutoLista, 'A', 1, 3,
        'NF ' + LSufixo);

      { movimento antigo, fora da janela de hoje }
      InserirMovimentoDireto(LProdutoLista, LSessao.EmpresaId, 'E', 5,
        'ANTIGO ' + LSufixo, Trunc(Now) - 10);

      LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), '', LTokenLista);
      AssertTrue(ContarLinhas = 3,
        'o dia final deve entrar inteiro e trazer só os 3 movimentos de hoje; ' +
        'veio ' + IntToStr(ContarLinhas));

      LLista.First;
      LPrimeiraData := LLista.FieldByName('DATA_MOVIMENTO').AsDateTime;
      AssertTrue(Trim(LLista.FieldByName('TIPO_DESC').AsString) = 'Ajuste',
        'o movimento mais recente deve vir primeiro (ajuste)');
      LLista.Next;
      AssertTrue(Trunc(LPrimeiraData) >=
        Trunc(LLista.FieldByName('DATA_MOVIMENTO').AsDateTime),
        'a listagem deve vir em ordem decrescente de data');
      AssertEquals('Saída',
        Trim(LLista.FieldByName('TIPO_DESC').AsString),
        'o tipo deve vir traduzido');

      LEstoque.CarregarMovimentos(LLista, Trunc(Now) - 15, Trunc(Now) - 5,
        '', LTokenLista);
      AssertTrue(ContarLinhas = 1,
        'a janela antiga deve trazer apenas o movimento de 10 dias atrás');

      { garante que os IDs criados nesta rodada foram os esperados }
      AssertTrue((LIdEntrada > 0) and (LIdSaida > 0) and (LIdAjuste > 0),
        'os movimentos devem ter sido gravados');

      ASuite.AddResult('TestEstoqueCarregarMovimentosPeriodo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueCarregarMovimentosPeriodo', False,
          E.Message);
    end;
  end;

  procedure TestCarregarMovimentosTipo;
  begin
    try
      LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), 'E',
        LTokenLista);
      AssertTrue(ContarLinhas = 1,
        'o filtro E deve trazer só a entrada de hoje');

      LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), 'S',
        LTokenLista);
      AssertTrue(ContarLinhas = 1,
        'o filtro S deve trazer só a saída de hoje');

      LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), 'A',
        LTokenLista);
      AssertTrue(ContarLinhas = 1,
        'o filtro A deve trazer só o ajuste de hoje');

      LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), 'I',
        LTokenLista);
      AssertTrue(ContarLinhas = 0,
        'não há inventário nesta rodada');

      ASuite.AddResult('TestEstoqueCarregarMovimentosTipo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueCarregarMovimentosTipo', False,
          E.Message);
    end;
  end;

  procedure TestCarregarMovimentosPorDocumento;
  begin
    try
      LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), '',
        'NF ' + LSufixo);
      AssertTrue(ContarLinhas = 3,
        'a pesquisa deve encontrar os movimentos pelo documento');

      ASuite.AddResult('TestEstoqueCarregarMovimentosPorDocumento', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueCarregarMovimentosPorDocumento', False,
          E.Message);
    end;
  end;

  procedure TestCarregarMovimentosEscopoEmpresa;
  begin
    try
      { mesmo produto e mesmo texto, mas movimento de outra empresa }
      InserirMovimentoDireto(LProdutoLista, 999999, 'E', 9,
        'NF ' + LSufixo, Now);

      LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), '',
        'NF ' + LSufixo);
      AssertTrue(ContarLinhas = 3,
        'movimento de outra empresa não pode aparecer na listagem');

      ASuite.AddResult('TestEstoqueCarregarMovimentosEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueCarregarMovimentosEscopoEmpresa', False,
          E.Message);
    end;
  end;

  procedure TestCarregarMovimentosValidacoes;
  var
    LDeu: Boolean;
  begin
    try
      LDeu := False;
      try
        LEstoque.CarregarMovimentos(nil, Trunc(Now), Trunc(Now));
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'listagem sem query deve ser recusada');

      LDeu := False;
      try
        LEstoque.CarregarMovimentos(LLista, Trunc(Now) + 5, Trunc(Now));
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'período invertido deve ser recusado');

      LDeu := False;
      try
        LEstoque.CarregarMovimentos(LLista, Trunc(Now), Trunc(Now), 'X');
      except
        on E: Exception do
          LDeu := True;
      end;
      AssertTrue(LDeu, 'tipo inválido na listagem deve ser recusado');

      ASuite.AddResult('TestEstoqueCarregarMovimentosValidacoes', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestEstoqueCarregarMovimentosValidacoes', False,
          E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Limpeza
  // ------------------------------------------------------------------

  procedure LimparSobraPorSufixo;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM MOVIMENTO_ESTOQUE WHERE PRODUTO_ID IN (' +
        '  SELECT ID FROM PRODUTO WHERE DESCRICAO CONTAINING :P1)';
      LQuery.ParamByName('P1').AsString := LSufixo;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
    end;
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM ESTOQUE WHERE PRODUTO_ID IN (' +
        '  SELECT ID FROM PRODUTO WHERE DESCRICAO CONTAINING :P1)';
      LQuery.ParamByName('P1').AsString := LSufixo;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
    end;
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM PRODUTO WHERE DESCRICAO CONTAINING :P1';
      LQuery.ParamByName('P1').AsString := LSufixo;
      LQuery.ExecSQL;
      LConexao.Confirmar;
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
  LEstoque := TEstoqueService.Create;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LTokenLista := 'MOV ESTOQUE ' + LSufixo + ' ' + StringOfChar('X', 20);
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
    WriteLn('EXECUTANDO TESTES DE ESTOQUE');
    WriteLn('========================================');

    LProdutoEntrada := CriarProduto(Descricao('ESTOQUE ENTRADA'),
      LSessao.EmpresaId);
    LProdutoSaida := CriarProduto(Descricao('ESTOQUE SAIDA'),
      LSessao.EmpresaId);
    LProdutoAjuste := CriarProduto(Descricao('ESTOQUE AJUSTE'),
      LSessao.EmpresaId);
    LProdutoInventario := CriarProduto(Descricao('ESTOQUE INVENTARIO'),
      LSessao.EmpresaId);
    LProdutoLista := CriarProduto(Descricao('ESTOQUE LISTA'),
      LSessao.EmpresaId);

    TestRegistrarEntrada;
    TestRegistrarSaida;
    TestRegistrarAjusteSoma;
    TestRegistrarInventarioNaoAlteraSaldo;
    TestInventarioCriaSaldoZerado;
    TestRegistrarProdutoInvalido;
    TestRegistrarProdutoOutraEmpresa;
    TestRegistrarTipoInvalido;
    TestRegistrarQuantidadeInvalida;
    TestRegistrarCustoNegativo;
    TestRegistrarLimitesTexto;
    TestSaldoProdutoInexistente;
    TestSaldoEscopoEmpresa;
    TestCarregarMovimentosPeriodo;
    TestCarregarMovimentosTipo;
    TestCarregarMovimentosPorDocumento;
    TestCarregarMovimentosEscopoEmpresa;
    TestCarregarMovimentosValidacoes;
  finally
    LimparSobraPorSufixo;
    LEstoque.Free;
    LLista.Free;
    LQuery.Free;
  end;
end;

end.
