unit uKardexTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes unitários do Kardex do Produto
  Cobertura:
  - busca de produto por código, código de barras ou ID
  - carregamento de movimentos de estoque por produto e período
  - pesquisa por documento e observação
  - cálculo de entradas/saídas e saldo final
  - filtro por empresa (MOVIMENTO_ESTOQUE.EMPRESA_ID)
  ============================================================ }

interface

uses
  Classes, SysUtils, fpcunit, testregistry, SQLDB, uConexao, uSessao,
  uKardexService;

type
  { TKardexTest }
  TKardexTest = class(TTestCase)
  private
    FConexao: TConexao;
    FService: TKardexService;
    FEmpresaId: Int64;
    procedure LimparDados;
    function CriarProduto(const ACodigo, ADescricao: string;
      APrecoCusto, APrecoVenda: Double): Int64;
    function CriarMovimento(AProdutoId: Int64; TIPO: Char;
      AQuantidade, ACustoUnitario: Double;
      const ADataMovimento, ADocumento, AObservacao: string): Int64;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestBuscarProduto_PorCodigo;
    procedure TestBuscarProduto_PorCodigoBarras;
    procedure TestBuscarProduto_PorId;
    procedure TestBuscarProduto_NaoEncontrado;
    procedure TestCarregarKardex_EscopoEmpresa;
    procedure TestCarregarKardex_FiltroPeriodo;
    procedure TestCarregarKardex_PesquisaDocumento;
    procedure TestCarregarKardex_PesquisaObservacao;
    procedure TestCarregarResumo_EntradasSaidasSaldo;
    procedure TestCarregarResumo_PeriodoVazio;
  end;

implementation

{ TKardexTest }

procedure TKardexTest.SetUp;
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;
    
  FService := TKardexService.Create;
  
  // Usar empresa fixa para testes
  FEmpresaId := 1;
  
  // Sessão já é inicializada no uTestRunner
  LimparDados;
end;

procedure TKardexTest.TearDown;
begin
  LimparDados;
  FService.Free;
  FConexao := nil;
end;

procedure TKardexTest.LimparDados;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'DELETE FROM MOVIMENTO_ESTOQUE WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := FEmpresaId;
    LQuery.ExecSQL;
    LQuery.SQL.Text := 'DELETE FROM PRODUTO WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := FEmpresaId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

function TKardexTest.CriarProduto(const ACodigo, ADescricao: string;
  APrecoCusto, APrecoVenda: Double): Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CODIGO, CODIGO_BARRAS, DESCRICAO, ' +
      '  PRECO_CUSTO, PRECO_VENDA, ATIVO) ' +
      'VALUES (:EMP, :COD, :CBARRA, :DESC, :PCUSTO, :PVENDA, ''A'') ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := FEmpresaId;
    LQuery.ParamByName('COD').AsString := ACodigo;
    LQuery.ParamByName('CBARRA').AsString := '789' + ACodigo;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('PCUSTO').AsFloat := APrecoCusto;
    LQuery.ParamByName('PVENDA').AsFloat := APrecoVenda;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

function TKardexTest.CriarMovimento(AProdutoId: Int64; TIPO: Char;
  AQuantidade, ACustoUnitario: Double;
  const ADataMovimento, ADocumento, AObservacao: string): Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_ESTOQUE (EMPRESA_ID, PRODUTO_ID, TIPO, ' +
      '  QUANTIDADE, CUSTO_UNITARIO, DATA_MOVIMENTO, DOCUMENTO, OBSERVACAO) ' +
      'VALUES (:EMP, :PROD, :TIPO, :QTD, :CUSTO, :DATA, :DOC, :OBS) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := FEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('TIPO').AsString := TIPO;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.ParamByName('CUSTO').AsFloat := ACustoUnitario;
    LQuery.ParamByName('DATA').AsDateTime := StrToDateTime(ADataMovimento);
    LQuery.ParamByName('DOC').AsString := ADocumento;
    LQuery.ParamByName('OBS').AsString := AObservacao;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

procedure TKardexTest.TestBuscarProduto_PorCodigo;
var
  LProdutoId: Int64;
  LDescricao: string;
  LEstoqueAtual: Double;
begin
  CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  
  AssertTrue('Deve encontrar produto por código',
    FService.BuscarProduto('PROD-TEST', LProdutoId, LDescricao, LEstoqueAtual));
  AssertEquals('Descrição deve ser a esperada', 'Produto Teste', LDescricao);
  AssertEquals('Estoque atual deve ser 0', 0, LEstoqueAtual);
end;

procedure TKardexTest.TestBuscarProduto_PorCodigoBarras;
var
  LProdutoId: Int64;
  LDescricao: string;
  LEstoqueAtual: Double;
begin
  CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  
  AssertTrue('Deve encontrar produto por código de barras',
    FService.BuscarProduto('789PROD-TEST', LProdutoId, LDescricao, LEstoqueAtual));
  AssertEquals('Descrição deve ser a esperada', 'Produto Teste', LDescricao);
end;

procedure TKardexTest.TestBuscarProduto_PorId;
var
  LProdutoId, LId: Int64;
  LDescricao: string;
  LEstoqueAtual: Double;
begin
  LId := CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  
  AssertTrue('Deve encontrar produto por ID',
    FService.BuscarProduto(IntToStr(LId), LProdutoId, LDescricao, LEstoqueAtual));
  AssertEquals('ID deve ser o mesmo', LId, LProdutoId);
end;

procedure TKardexTest.TestBuscarProduto_NaoEncontrado;
var
  LProdutoId: Int64;
  LDescricao: string;
  LEstoqueAtual: Double;
begin
  AssertFalse('Não deve encontrar produto inexistente',
    FService.BuscarProduto('NAO-EXISTE', LProdutoId, LDescricao, LEstoqueAtual));
  AssertEquals('ProdutoId deve ser 0', 0, LProdutoId);
  AssertEquals('Descrição deve ser vazia', '', LDescricao);
  AssertEquals('EstoqueAtual deve ser 0', 0, LEstoqueAtual);
end;

procedure TKardexTest.TestCarregarKardex_EscopoEmpresa;
var
  LQuery: TSQLQuery;
  LProdutoId: Int64;
begin
  LProdutoId := CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  CriarMovimento(LProdutoId, 'E', 100, 10, '2026-01-01', 'DOC1', 'Teste');
  CriarMovimento(LProdutoId, 'S', 50, 10, '2026-01-02', 'DOC2', 'Teste');
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarKardex(LQuery, LProdutoId, 
      EncodeDate(2026, 1, 1), EncodeDate(2026, 12, 31), '');
    AssertEquals('Deve listar 2 movimentos', 2, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TKardexTest.TestCarregarKardex_FiltroPeriodo;
var
  LQuery: TSQLQuery;
  LProdutoId: Int64;
begin
  LProdutoId := CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  CriarMovimento(LProdutoId, 'E', 100, 10, '2026-01-01', 'DOC1', 'Teste');
  CriarMovimento(LProdutoId, 'S', 50, 10, '2026-06-01', 'DOC2', 'Teste');
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarKardex(LQuery, LProdutoId, 
      EncodeDate(2026, 1, 1), EncodeDate(2026, 3, 31), '');
    AssertEquals('Deve listar 1 movimento (jan-mar)', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TKardexTest.TestCarregarKardex_PesquisaDocumento;
var
  LQuery: TSQLQuery;
  LProdutoId: Int64;
begin
  LProdutoId := CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  CriarMovimento(LProdutoId, 'E', 100, 10, '2026-01-01', 'DOC-UNICO', 'Teste');
  CriarMovimento(LProdutoId, 'S', 50, 10, '2026-01-02', 'OUTRO', 'Teste');
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarKardex(LQuery, LProdutoId, 
      EncodeDate(2026, 1, 1), EncodeDate(2026, 12, 31), 'DOC-UNICO');
    AssertEquals('Deve listar 1 movimento (documento)', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TKardexTest.TestCarregarKardex_PesquisaObservacao;
var
  LQuery: TSQLQuery;
  LProdutoId: Int64;
begin
  LProdutoId := CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  CriarMovimento(LProdutoId, 'E', 100, 10, '2026-01-01', 'DOC1', 'Observação Única');
  CriarMovimento(LProdutoId, 'S', 50, 10, '2026-01-02', 'DOC2', 'Outra');
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarKardex(LQuery, LProdutoId, 
      EncodeDate(2026, 1, 1), EncodeDate(2026, 12, 31), 'Observação');
    AssertEquals('Deve listar 1 movimento (observação)', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TKardexTest.TestCarregarResumo_EntradasSaidasSaldo;
var
  LProdutoId: Int64;
  LResumo: TKardexResumo;
begin
  LProdutoId := CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  CriarMovimento(LProdutoId, 'E', 100, 10, '2026-01-01', 'DOC1', 'Teste');
  CriarMovimento(LProdutoId, 'E', 50, 10, '2026-01-02', 'DOC2', 'Teste');
  CriarMovimento(LProdutoId, 'S', 30, 10, '2026-01-03', 'DOC3', 'Teste');
  
  FService.CarregarResumo(LProdutoId, 
    EncodeDate(2026, 1, 1), EncodeDate(2026, 12, 31), '', LResumo);
  
  AssertEquals('Entradas deve ser 150', 150, LResumo.Entradas);
  AssertEquals('Saídas deve ser 30', 30, LResumo.Saidas);
  AssertEquals('Saldo deve ser 120', 120, LResumo.Saldo);
end;

procedure TKardexTest.TestCarregarResumo_PeriodoVazio;
var
  LProdutoId: Int64;
  LResumo: TKardexResumo;
begin
  LProdutoId := CriarProduto('PROD-TEST', 'Produto Teste', 10, 20);
  
  FService.CarregarResumo(LProdutoId, 
    EncodeDate(2026, 1, 1), EncodeDate(2026, 12, 31), '', LResumo);
  
  AssertEquals('Entradas deve ser 0', 0, LResumo.Entradas);
  AssertEquals('Saídas deve ser 0', 0, LResumo.Saidas);
  AssertEquals('Saldo deve ser 0', 0, LResumo.Saldo);
end;

initialization
  RegisterTest(TKardexTest);
end.
