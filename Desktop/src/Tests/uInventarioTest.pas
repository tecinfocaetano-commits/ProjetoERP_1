unit uInventarioTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes unitários do Inventário de Estoque
  Cobertura:
  - listagem no escopo da empresa (EMPRESA_ID)
  - filtro por descrição e código (parametrizado)
  - filtros opcionais: apenas com estoque e abaixo do mínimo
  - cálculo do valor total do estoque (quantidade × custo)
  - apenas produtos com CONTROLE_ESTOQUE='S' e ATIVO='A'
  ============================================================ }

interface

uses
  Classes, SysUtils, fpcunit, testregistry, SQLDB, uConexao, uSessao,
  uInventarioService;

type
  { TInventarioTest }
  TInventarioTest = class(TTestCase)
  private
    FConexao: TConexao;
    FService: TInventarioService;
    FEmpresaId: Int64;
    procedure LimparDados;
    function CriarProduto(const ACodigo, ADescricao: string;
      APrecoCusto, APrecoVenda, AEstoqueMinimo: Double;
      AControlaEstoque: Char = 'S'): Int64;
    function CriarEstoque(AProdutoId: Int64; AQuantidade: Double): Int64;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestListar_EscopoEmpresa;
    procedure TestListar_SoControlaEstoqueS;
    procedure TestListar_SoAtivoA;
    procedure TestListar_PesquisaDescricao;
    procedure TestListar_PesquisaCodigo;
    procedure TestListar_ApenasComEstoque;
    procedure TestListar_AbaixoMinimo;
    procedure TestValorTotalEstoque;
    procedure TestValorTotalEstoque_Vazio;
  end;

implementation

{ TInventarioTest }

procedure TInventarioTest.SetUp;
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;
    
  FService := TInventarioService.Create;
  
  // Usar empresa fixa para testes
  FEmpresaId := 1;
  
  // Sessão já é inicializada no uTestRunner
  LimparDados;
end;

procedure TInventarioTest.TearDown;
begin
  LimparDados;
  FService.Free;
  FConexao := nil;
end;

procedure TInventarioTest.LimparDados;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'DELETE FROM ESTOQUE WHERE PRODUTO_ID IN ' +
      '(SELECT ID FROM PRODUTO WHERE EMPRESA_ID = :EMP)';
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

function TInventarioTest.CriarProduto(const ACodigo, ADescricao: string;
  APrecoCusto, APrecoVenda, AEstoqueMinimo: Double;
  AControlaEstoque: Char): Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'INSERT INTO PRODUTO (EMPRESA_ID, CODIGO, DESCRICAO, ' +
      '  PRECO_CUSTO, PRECO_VENDA, ESTOQUE_MINIMO, CONTROLA_ESTOQUE, ATIVO) ' +
      'VALUES (:EMP, :COD, :DESC, :PCUSTO, :PVENDA, :EMIN, :CESTOQUE, ''A'') ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := FEmpresaId;
    LQuery.ParamByName('COD').AsString := ACodigo;
    LQuery.ParamByName('DESC').AsString := ADescricao;
    LQuery.ParamByName('PCUSTO').AsFloat := APrecoCusto;
    LQuery.ParamByName('PVENDA').AsFloat := APrecoVenda;
    LQuery.ParamByName('EMIN').AsFloat := AEstoqueMinimo;
    LQuery.ParamByName('CESTOQUE').AsString := AControlaEstoque;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

function TInventarioTest.CriarEstoque(AProdutoId: Int64;
  AQuantidade: Double): Int64;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'INSERT INTO ESTOQUE (EMPRESA_ID, PRODUTO_ID, QUANTIDADE) ' +
      'VALUES (:EMP, :PROD, :QTD) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := FEmpresaId;
    LQuery.ParamByName('PROD').AsLargeInt := AProdutoId;
    LQuery.ParamByName('QTD').AsFloat := AQuantidade;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestListar_EscopoEmpresa;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarProduto('PROD-TEST-1', 'Produto Teste 1', 10, 20, 5);
  LId2 := CriarProduto('PROD-TEST-2', 'Produto Teste 2', 15, 25, 10);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarInventario(LQuery);
    AssertEquals('Deve listar 2 produtos', 2, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestListar_SoControlaEstoqueS;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarProduto('PROD-TEST-1', 'Produto Controla', 10, 20, 5, 'S');
  LId2 := CriarProduto('PROD-TEST-2', 'Produto Não Controla', 15, 25, 10, 'N');
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarInventario(LQuery);
    AssertEquals('Deve listar só 1 produto (controla estoque)', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestListar_SoAtivoA;
var
  LQuery: TSQLQuery;
  LId1: Int64;
  LProd: TSQLQuery;
begin
  LId1 := CriarProduto('PROD-TEST-1', 'Produto Ativo', 10, 20, 5);
  
  // Marcar como inativo
  LProd := TSQLQuery.Create(nil);
  try
    LProd.DataBase := FConexao.Connection;
    LProd.Transaction := FConexao.Transaction;
    LProd.SQL.Text := 'UPDATE PRODUTO SET ATIVO = ''I'' WHERE ID = :ID';
    LProd.ParamByName('ID').AsLargeInt := LId1;
    LProd.ExecSQL;
    FConexao.Confirmar;
  finally
    LProd.Free;
  end;
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarInventario(LQuery);
    AssertEquals('Deve listar 0 produtos (inativo)', 0, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestListar_PesquisaDescricao;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarProduto('PROD-TEST-1', 'Produto Único Teste', 10, 20, 5);
  LId2 := CriarProduto('PROD-TEST-2', 'Outro Produto', 15, 25, 10);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarInventario(LQuery, 'único');
    AssertEquals('Deve listar 1 produto', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestListar_PesquisaCodigo;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarProduto('COD-XYZ', 'Produto 1', 10, 20, 5);
  LId2 := CriarProduto('COD-ABC', 'Produto 2', 15, 25, 10);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarInventario(LQuery, 'XYZ');
    AssertEquals('Deve listar 1 produto', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestListar_ApenasComEstoque;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarProduto('PROD-TEST-1', 'Produto Com Estoque', 10, 20, 5);
  LId2 := CriarProduto('PROD-TEST-2', 'Produto Sem Estoque', 15, 25, 10);
  CriarEstoque(LId1, 100);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarInventario(LQuery, '', True, False);
    AssertEquals('Deve listar 1 produto (com estoque)', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestListar_AbaixoMinimo;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarProduto('PROD-TEST-1', 'Produto Abaixo', 10, 20, 50);
  LId2 := CriarProduto('PROD-TEST-2', 'Produto Acima', 15, 25, 10);
  CriarEstoque(LId1, 10);
  CriarEstoque(LId2, 100);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarInventario(LQuery, '', False, True);
    AssertEquals('Deve listar 1 produto (abaixo do mínimo)', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TInventarioTest.TestValorTotalEstoque;
var
  LId1, LId2: Int64;
  LValor: Double;
begin
  LId1 := CriarProduto('PROD-TEST-1', 'Produto 1', 10, 20, 5);
  LId2 := CriarProduto('PROD-TEST-2', 'Produto 2', 15, 25, 10);
  CriarEstoque(LId1, 100);
  CriarEstoque(LId2, 50);
  
  LValor := FService.ValorTotalEstoque;
  AssertEquals('Valor total deve ser 1250 (100×10 + 50×15)', 1250, LValor);
end;

procedure TInventarioTest.TestValorTotalEstoque_Vazio;
var
  LValor: Double;
begin
  LValor := FService.ValorTotalEstoque;
  AssertEquals('Valor total deve ser 0 (sem produtos)', 0, LValor);
end;

initialization
  RegisterTest(TInventarioTest);
end.
