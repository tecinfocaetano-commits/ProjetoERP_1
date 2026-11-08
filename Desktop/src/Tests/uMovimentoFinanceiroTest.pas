unit uMovimentoFinanceiroTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes unitários do Movimento Financeiro
  Cobertura:
  - validação de tipo (E/S), descrição, categoria, valor, data e documento
  - inclusão com EMPRESA_ID/USUARIO_ID da sessão
  - alteração e exclusão só alcançam registro da empresa da sessão
  - listagem no escopo da empresa com pesquisa
  - tipos e categorias
  ============================================================ }

interface

uses
  Classes, SysUtils, fpcunit, testregistry, SQLDB, uConexao, uSessao,
  uMovimentoFinanceiroService, uAssert;

type
  { TMovimentoFinanceiroTest }
  TMovimentoFinanceiroTest = class(TTestCase)
  private
    FConexao: TConexao;
    FService: TMovimentoFinanceiroService;
    FEmpresaId: Int64;
    FUsuarioId: Int64;
    procedure LimparDados;
    function CriarMovimento(const AData: TDateTime; ATipo: Char;
      const ACategoria, ADescricao: string; AValor: Double;
      ADocumentoId: Int64 = 0): Int64;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestValidar_TipoInvalido;
    procedure TestValidar_DescricaoVazia;
    procedure TestValidar_DescricaoMuitoLonga;
    procedure TestValidar_CategoriaMuitoLonga;
    procedure TestValidar_DataInvalida;
    procedure TestValidar_ValorZero;
    procedure TestValidar_ValorNegativo;
    procedure TestValidar_DocumentoNegativo;
    procedure TestIncluir_EmpresaSessao;
    procedure TestIncluir_DataAtual;
    procedure TestIncluir_UsuarioSessao;
    procedure TestAlterar_SoMesmaEmpresa;
    procedure TestAlterar_OutraEmpresa_Bloqueado;
    procedure TestExcluir_SoMesmaEmpresa;
    procedure TestExcluir_OutraEmpresa_Bloqueado;
    procedure TestListar_EscopoEmpresa;
    procedure TestListar_PesquisaDescricao;
    procedure TestListar_PesquisaCategoria;
    procedure TestListar_PesquisaDocumento;
    procedure TestListar_OrdemDataDescIdDesc;
    procedure TestBuscar_NaoEncontrado;
    procedure TestCarregarTipos;
    procedure TestCarregarCategorias;
  end;

implementation

{ TMovimentoFinanceiroTest }

procedure TMovimentoFinanceiroTest.SetUp;
begin
  FConexao := TConexao.GetInstance;
  if not FConexao.Conectado then
    FConexao.Conectar;
    
  FService := TMovimentoFinanceiroService.Create;
  
  // Usar empresa e usuário fixos para testes
  FEmpresaId := 1;
  FUsuarioId := 1;
  
  // Sessão já é inicializada no uTestRunner
  // TSessao.GetInstance.Logar já foi chamado
  
  LimparDados;
end;

procedure TMovimentoFinanceiroTest.TearDown;
begin
  LimparDados;
  FService.Free;
  FConexao := nil;
end;

procedure TMovimentoFinanceiroTest.LimparDados;
var
  LQuery: TSQLQuery;
begin
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'DELETE FROM MOVIMENTO_FINANCEIRO WHERE EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := FEmpresaId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

function TMovimentoFinanceiroTest.CriarMovimento(const AData: TDateTime;
  ATipo: Char; const ACategoria, ADescricao: string; AValor: Double;
  ADocumentoId: Int64): Int64;
var
  LDados: TMovimentoFinanceiroDados;
begin
  LDados.Id := 0;
  LDados.DataMovimento := AData;
  LDados.Tipo := ATipo;
  LDados.Categoria := ACategoria;
  LDados.Descricao := ADescricao;
  LDados.Valor := AValor;
  LDados.DocumentoId := ADocumentoId;
  Result := FService.SalvarMovimento(LDados);
end;

procedure TMovimentoFinanceiroTest.TestValidar_TipoInvalido;
var
  LDados: TMovimentoFinanceiroDados;
  LException: Exception;
begin
  LDados.DataMovimento := Now;
  LDados.Tipo := 'X';
  LDados.Categoria := 'TESTE';
  LDados.Descricao := 'Teste';
  LDados.Valor := 100;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar tipo inválido',
        Pos('Tipo de movimento inválido', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestValidar_DescricaoVazia;
var
  LDados: TMovimentoFinanceiroDados;
  LException: Exception;
begin
  LDados.DataMovimento := Now;
  LDados.Tipo := 'E';
  LDados.Categoria := 'TESTE';
  LDados.Descricao := '';
  LDados.Valor := 100;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar descrição obrigatória',
        Pos('Descrição é obrigatório', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestValidar_DescricaoMuitoLonga;
var
  LDados: TMovimentoFinanceiroDados;
  LDesc: string;
  I: Integer;
  LException: Exception;
begin
  LDesc := '';
  for I := 1 to 121 do
    LDesc := LDesc + 'A';
    
  LDados.DataMovimento := Now;
  LDados.Tipo := 'E';
  LDados.Categoria := 'TESTE';
  LDados.Descricao := LDesc;
  LDados.Valor := 100;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar tamanho máximo',
        Pos('descrição deve ter no máximo', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestValidar_CategoriaMuitoLonga;
var
  LDados: TMovimentoFinanceiroDados;
  LCat: string;
  I: Integer;
  LException: Exception;
begin
  LCat := '';
  for I := 1 to 31 do
    LCat := LCat + 'A';
    
  LDados.DataMovimento := Now;
  LDados.Tipo := 'E';
  LDados.Categoria := LCat;
  LDados.Descricao := 'Teste';
  LDados.Valor := 100;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar tamanho máximo',
        Pos('categoria deve ter no máximo', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestValidar_DataInvalida;
var
  LDados: TMovimentoFinanceiroDados;
  LException: Exception;
begin
  LDados.DataMovimento := 0;
  LDados.Tipo := 'E';
  LDados.Categoria := 'TESTE';
  LDados.Descricao := 'Teste';
  LDados.Valor := 100;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar data válida',
        Pos('data válida', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestValidar_ValorZero;
var
  LDados: TMovimentoFinanceiroDados;
  LException: Exception;
begin
  LDados.DataMovimento := Now;
  LDados.Tipo := 'E';
  LDados.Categoria := 'TESTE';
  LDados.Descricao := 'Teste';
  LDados.Valor := 0;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar valor maior que zero',
        Pos('valor do movimento deve ser maior que zero', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestValidar_ValorNegativo;
var
  LDados: TMovimentoFinanceiroDados;
  LException: Exception;
begin
  LDados.DataMovimento := Now;
  LDados.Tipo := 'E';
  LDados.Categoria := 'TESTE';
  LDados.Descricao := 'Teste';
  LDados.Valor := -100;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar valor maior que zero',
        Pos('valor do movimento deve ser maior que zero', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestValidar_DocumentoNegativo;
var
  LDados: TMovimentoFinanceiroDados;
  LException: Exception;
begin
  LDados.DataMovimento := Now;
  LDados.Tipo := 'E';
  LDados.Categoria := 'TESTE';
  LDados.Descricao := 'Teste';
  LDados.Valor := 100;
  LDados.DocumentoId := -1;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
    begin
      LException := E;
      AssertTrue('Exceção deve mencionar documento não negativo',
        Pos('documento não pode ser negativo', LException.Message) > 0);
    end;
  end;
end;

procedure TMovimentoFinanceiroTest.TestIncluir_EmpresaSessao;
var
  LId: Int64;
  LQuery: TSQLQuery;
begin
  LId := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste empresa', 100);
  AssertTrue('ID deve ser maior que zero', LId > 0);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT EMPRESA_ID FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.Open;
    AssertEquals('Empresa deve ser a da sessão', FEmpresaId,
      LQuery.FieldByName('EMPRESA_ID').AsLargeInt);
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestIncluir_DataAtual;
var
  LId: Int64;
  LQuery: TSQLQuery;
  LData: TDateTime;
begin
  LData := Now;
  LId := CriarMovimento(LData, 'E', 'RECEBIMENTO', 'Teste data', 100);
  AssertTrue('ID deve ser maior que zero', LId > 0);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT DATA_MOVIMENTO FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.Open;
    AssertEquals('Data deve ser a informada', Trunc(LData),
      Trunc(LQuery.FieldByName('DATA_MOVIMENTO').AsDateTime));
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestIncluir_UsuarioSessao;
var
  LId: Int64;
  LQuery: TSQLQuery;
begin
  LId := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste usuário', 100);
  AssertTrue('ID deve ser maior que zero', LId > 0);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT USUARIO_ID FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.Open;
    AssertEquals('Usuário deve ser o da sessão', FUsuarioId,
      LQuery.FieldByName('USUARIO_ID').AsLargeInt);
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestAlterar_SoMesmaEmpresa;
var
  LId: Int64;
  LDados: TMovimentoFinanceiroDados;
begin
  LId := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste alteração', 100);
  AssertTrue('ID deve ser maior que zero', LId > 0);
  
  LDados.Id := LId;
  LDados.DataMovimento := Now;
  LDados.Tipo := 'S';
  LDados.Categoria := 'PAGAMENTO';
  LDados.Descricao := 'Teste alterado';
  LDados.Valor := 200;
  LDados.DocumentoId := 0;
  
  AssertTrue('Alteração deve retornar ID', FService.SalvarMovimento(LDados) = LId);
end;

procedure TMovimentoFinanceiroTest.TestAlterar_OutraEmpresa_Bloqueado;
var
  LId: Int64;
  LDados: TMovimentoFinanceiroDados;
  LQuery: TSQLQuery;
begin
  // Criar movimento em outra empresa
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_FINANCEIRO (EMPRESA_ID, DATA_MOVIMENTO, ' +
      '  TIPO, CATEGORIA, DESCRICAO, VALOR, USUARIO_ID) ' +
      'VALUES (:EMP, :DATA, :TIPO, :CAT, :DESC, :VALOR, :USR) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := 999;
    LQuery.ParamByName('DATA').AsDate := Now;
    LQuery.ParamByName('TIPO').AsString := 'E';
    LQuery.ParamByName('CAT').AsString := 'RECEBIMENTO';
    LQuery.ParamByName('DESC').AsString := 'Teste outra empresa';
    LQuery.ParamByName('VALOR').AsFloat := 100;
    LQuery.ParamByName('USR').AsLargeInt := 1;
    LQuery.Open;
    LId := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
  
  // Tentar alterar com sessão da empresa 1
  LDados.Id := LId;
  LDados.DataMovimento := Now;
  LDados.Tipo := 'S';
  LDados.Categoria := 'PAGAMENTO';
  LDados.Descricao := 'Teste alterado';
  LDados.Valor := 200;
  LDados.DocumentoId := 0;
  
  try
    FService.SalvarMovimento(LDados);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
      AssertTrue('Exceção deve mencionar não encontrado nesta empresa',
        Pos('não encontrado nesta empresa', E.Message) > 0);
  end;
    
  // Limpar movimento da outra empresa
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'DELETE FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestExcluir_SoMesmaEmpresa;
var
  LId: Int64;
  LDados: TMovimentoFinanceiroDados;
begin
  LId := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste exclusão', 100);
  AssertTrue('ID deve ser maior que zero', LId > 0);
  
  FService.ExcluirMovimento(LId);
  
  // Verificar se foi excluído
  LDados.Id := 0;
  AssertFalse('Buscar deve retornar False',
    FService.BuscarMovimento(LId, LDados));
end;

procedure TMovimentoFinanceiroTest.TestExcluir_OutraEmpresa_Bloqueado;
var
  LId: Int64;
  LQuery: TSQLQuery;
begin
  // Criar movimento em outra empresa
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'INSERT INTO MOVIMENTO_FINANCEIRO (EMPRESA_ID, DATA_MOVIMENTO, ' +
      '  TIPO, CATEGORIA, DESCRICAO, VALOR, USUARIO_ID) ' +
      'VALUES (:EMP, :DATA, :TIPO, :CAT, :DESC, :VALOR, :USR) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := 999;
    LQuery.ParamByName('DATA').AsDate := Now;
    LQuery.ParamByName('TIPO').AsString := 'E';
    LQuery.ParamByName('CAT').AsString := 'RECEBIMENTO';
    LQuery.ParamByName('DESC').AsString := 'Teste outra empresa';
    LQuery.ParamByName('VALOR').AsFloat := 100;
    LQuery.ParamByName('USR').AsLargeInt := 1;
    LQuery.Open;
    LId := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
  
  // Tentar excluir com sessão da empresa 1
  try
    FService.ExcluirMovimento(LId);
    AssertFail('Deveria ter lançado exceção');
  except
    on E: Exception do
      AssertTrue('Exceção deve mencionar não encontrado nesta empresa',
        Pos('não encontrado nesta empresa', E.Message) > 0);
  end;
    
  // Limpar movimento da outra empresa
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text := 'DELETE FROM MOVIMENTO_FINANCEIRO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := LId;
    LQuery.ExecSQL;
    FConexao.Confirmar;
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestListar_EscopoEmpresa;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste lista 1', 100);
  LId2 := CriarMovimento(Now, 'S', 'PAGAMENTO', 'Teste lista 2', 200);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarMovimentos(LQuery);
    AssertEquals('Deve listar 2 movimentos', 2, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestListar_PesquisaDescricao;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste descrição única', 100);
  LId2 := CriarMovimento(Now, 'S', 'PAGAMENTO', 'Outro teste', 200);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarMovimentos(LQuery, 'descrição');
    AssertEquals('Deve listar 1 movimento', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestListar_PesquisaCategoria;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste 1', 100);
  LId2 := CriarMovimento(Now, 'S', 'PAGAMENTO', 'Teste 2', 200);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarMovimentos(LQuery, 'recebimento');
    AssertEquals('Deve listar 1 movimento', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestListar_PesquisaDocumento;
var
  LQuery: TSQLQuery;
  LId1, LId2: Int64;
begin
  LId1 := CriarMovimento(Now, 'E', 'RECEBIMENTO', 'Teste 1', 100, 123);
  LId2 := CriarMovimento(Now, 'S', 'PAGAMENTO', 'Teste 2', 200, 456);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarMovimentos(LQuery, '123');
    AssertEquals('Deve listar 1 movimento', 1, LQuery.RecordCount);
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestListar_OrdemDataDescIdDesc;
var
  LQuery: TSQLQuery;
  LId1, LId2, LId3: Int64;
  LData1, LData2, LData3: TDateTime;
begin
  LData1 := EncodeDate(2026, 1, 1);
  LData2 := EncodeDate(2026, 2, 1);
  LData3 := EncodeDate(2026, 3, 1);
  
  LId1 := CriarMovimento(LData1, 'E', 'RECEBIMENTO', 'Teste 1', 100);
  LId2 := CriarMovimento(LData2, 'S', 'PAGAMENTO', 'Teste 2', 200);
  LId3 := CriarMovimento(LData3, 'E', 'RECEBIMENTO', 'Teste 3', 300);
  
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    FService.CarregarMovimentos(LQuery);
    AssertEquals('Deve listar 3 movimentos', 3, LQuery.RecordCount);
    
    // Primeiro deve ser o mais recente (data 3, ID 3)
    LQuery.First;
    AssertEquals('Primeiro deve ser o mais recente', LId3,
      LQuery.FieldByName('ID').AsLargeInt);
  finally
    LQuery.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestBuscar_NaoEncontrado;
var
  LDados: TMovimentoFinanceiroDados;
begin
  AssertFalse('Buscar ID inexistente deve retornar False',
    FService.BuscarMovimento(999999, LDados));
end;

procedure TMovimentoFinanceiroTest.TestCarregarTipos;
var
  LItems: TStringList;
begin
  LItems := TStringList.Create;
  try
    FService.CarregarTipos(LItems);
    AssertEquals('Deve ter 2 tipos', 2, LItems.Count);
    AssertEquals('Primeiro deve ser Entrada', 'Entrada', LItems[0]);
    AssertEquals('Segundo deve ser Saída', 'Saída', LItems[1]);
  finally
    LItems.Free;
  end;
end;

procedure TMovimentoFinanceiroTest.TestCarregarCategorias;
var
  LItems: TStringList;
begin
  LItems := TStringList.Create;
  try
    FService.CarregarCategorias(LItems);
    AssertEquals('Deve ter 4 categorias', 4, LItems.Count);
    AssertEquals('Primeira deve ser RECEBIMENTO', 'RECEBIMENTO', LItems[0]);
    AssertEquals('Segunda deve ser PAGAMENTO', 'PAGAMENTO', LItems[1]);
    AssertEquals('Terceira deve ser TRANSFERENCIA', 'TRANSFERENCIA', LItems[2]);
    AssertEquals('Quarta deve ser OUTRAS', 'OUTRAS', LItems[3]);
  finally
    LItems.Free;
  end;
end;

initialization
  RegisterTest(TMovimentoFinanceiroTest);
end.
