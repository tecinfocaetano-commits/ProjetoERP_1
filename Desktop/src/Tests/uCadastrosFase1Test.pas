unit uCadastrosFase1Test;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes dos cadastros da Fase 1
  ------------------------------------------------------------
  Cobre os Services ainda sem teste:
    - TCorService: CRUD, unicidade por produto e auditoria;
    - TMaterialService: CRUD, código único/opcional, pesquisa e
      auditoria;
    - TProdutoFiscalService: CRUD, código único/opcional, pesquisa
      e auditoria;
    - TGradeService: CRUD com tamanhos, validações, bloqueio de
      exclusão de grade vinculada a produto, configuração USA_GRADE
      e auditoria;
    - funções puras do model TGrade (SomarQuantidades e tipos).

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco. Os Services confirmam a
  transação internamente, então a limpeza é feita por DELETE.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uCor, uMaterial, uProdutoFiscal, uGrade,
  uCorService, uMaterialService, uProdutoFiscalService, uGradeService;

type
  { TCadastrosFase1Test }
  TCadastrosFase1Test = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TCadastrosFase1Test }

class procedure TCadastrosFase1Test.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LCorService: TCorService;
  LMaterialService: TMaterialService;
  LProdutoFiscalService: TProdutoFiscalService;
  LGradeService: TGradeService;
  LSufixo: string;
  LTopoLog: Int64;

  function Tamanhos(const AValores: array of string): TGradeTamanhos;
  var
    I: Integer;
  begin
    Result := nil;
    SetLength(Result, Length(AValores));
    for I := 0 to High(AValores) do
    begin
      Result[I].Tamanho := AValores[I];
      Result[I].Ordem := I;
      Result[I].Ativo := 'A';
      Result[I].Quantidade := 0;
    end;
  end;

  function TamanhosComQtd(const AValores: array of string;
    const AQtds: array of Double): TGradeTamanhos;
  var
    I: Integer;
  begin
    Result := Tamanhos(AValores);
    for I := 0 to High(AQtds) do
      if I <= High(Result) then
        Result[I].Quantidade := AQtds[I];
  end;

  function ContarTotal(const ATabela: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM ' + ATabela;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarPorId(const ATabela: string; AId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM ' + ATabela + ' WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarPorCampo(const ATabela, ACampo, AValor: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM ' + ATabela +
      ' WHERE ' + ACampo + ' = :V';
    LQuery.ParamByName('V').AsString := AValor;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarTamanhos(AGradeId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM GRADE_TAMANHO WHERE GRADE_ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AGradeId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function ContarLog(const ATabela: string; ARegistroId: Int64): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COUNT(*) FROM LOG_SISTEMA ' +
      'WHERE TABELA = :T AND REGISTRO_ID = :R AND ID > :TOPO';
    LQuery.ParamByName('T').AsString := ATabela;
    LQuery.ParamByName('R').AsLargeInt := ARegistroId;
    LQuery.ParamByName('TOPO').AsLargeInt := LTopoLog;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function AchouNaLista(AQuery: TSQLQuery; AId: Int64): Boolean;
  begin
    Result := False;
    AQuery.First;
    while not AQuery.EOF do
    begin
      if AQuery.FieldByName('ID').AsLargeInt = AId then
        Result := True;
      AQuery.Next;
    end;
  end;

  procedure TestCorCicloCompleto;
  var
    LCor, LLido: TCor;
    LId: Int64;
    LNome: string;
  begin
    LNome := 'COR TESTE ' + LSufixo;
    LCor := TCor.Create;
    LId := 0;
    try
      try
        LCor.EmpresaId := LSessao.EmpresaId;
        LCor.ProdutoId := 1;
        LCor.Nome := LNome;
        LCor.Hex := '#FF0000';
        LCor.Ativo := 'A';
        LId := LCorService.Inserir(LCor);

        AssertTrue(LId > 0, 'o INSERT da cor deve devolver o ID');
        AssertEquals('1', IntToStr(ContarPorId('COR', LId)),
          'a cor deve existir no banco');

        LLido := LCorService.BuscarPorId(LId);
        try
          AssertNotNull(LLido, 'BuscarPorId deve achar a cor');
          AssertEquals(IntToStr(1), IntToStr(LLido.ProdutoId),
            'o PRODUTO_ID deve voltar do banco');
          AssertEquals(LNome, LLido.Nome, 'o nome deve voltar do banco');
          AssertEquals('#FF0000', LLido.Hex, 'o HEX deve voltar do banco');
          AssertEquals('A', LLido.Ativo, 'o ATIVO deve voltar do banco');
        finally
          LLido.Free;
        end;

        LLista := LCorService.BuscarPorProduto(1);
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'BuscarPorProduto deve listar a cor');
        finally
          LLista.Close;
        end;

        LLista := LCorService.BuscarTodos;
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'BuscarTodos deve listar a cor da empresa');
        finally
          LLista.Close;
        end;

        LCor.Id := LId;
        LCor.Nome := LNome + ' II';
        LCor.Hex := '#00FF00';
        LCor.Ativo := 'I';
        AssertTrue(LCorService.Atualizar(LCor), 'Atualizar deve retornar True');

        LLido := LCorService.BuscarPorId(LId);
        try
          AssertEquals(LNome + ' II', LLido.Nome,
            'o UPDATE deve gravar o nome');
          AssertEquals('#00FF00', LLido.Hex, 'o UPDATE deve gravar o HEX');
          AssertEquals('I', LLido.Ativo, 'o UPDATE deve gravar o ATIVO');
        finally
          LLido.Free;
        end;

        AssertTrue(LCorService.Excluir(LId), 'Excluir deve retornar True');
        AssertNil(LCorService.BuscarPorId(LId),
          'a cor excluída não deve ser encontrada');
        AssertEquals('0', IntToStr(ContarPorId('COR', LId)),
          'a cor deve sumir do banco');

        AssertTrue(ContarLog('COR', LId) >= 3,
          'INSERIR, ATUALIZAR e EXCLUIR devem gerar auditoria');
        LId := 0;

        ASuite.AddResult('TestCorCicloCompleto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCorCicloCompleto', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LCorService.Excluir(LId);
        except
        end;
      LCor.Free;
    end;
  end;

  procedure TestCorSemNome;
  var
    LCor: TCor;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LCor := TCor.Create;
    try
      try
        LAntes := ContarTotal('COR');
        LCor.EmpresaId := LSessao.EmpresaId;
        LCor.ProdutoId := 1;
        LCor.Nome := '';
        LCor.Ativo := 'A';
        LDeu := False;
        try
          LCorService.Inserir(LCor);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('COR');
        AssertTrue(LDeu, 'cor sem nome deve ser recusada');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhuma cor deve ser gravada');
        ASuite.AddResult('TestCorSemNome', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCorSemNome', False, E.Message);
      end;
    finally
      LCor.Free;
    end;
  end;

  procedure TestCorSemProduto;
  var
    LCor: TCor;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LCor := TCor.Create;
    try
      try
        LAntes := ContarTotal('COR');
        LCor.EmpresaId := LSessao.EmpresaId;
        LCor.ProdutoId := 0;
        LCor.Nome := 'COR SEM PRODUTO ' + LSufixo;
        LCor.Ativo := 'A';
        LDeu := False;
        try
          LCorService.Inserir(LCor);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('COR');
        AssertTrue(LDeu, 'cor sem produto deve ser recusada');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhuma cor deve ser gravada');
        ASuite.AddResult('TestCorSemProduto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCorSemProduto', False, E.Message);
      end;
    finally
      LCor.Free;
    end;
  end;

  procedure TestCorNomeDuplicadoNoProduto;
  var
    LPrimeira, LSegunda: TCor;
    LId: Int64;
    LNome: string;
    LDeu: Boolean;
  begin
    LNome := 'COR DUPLICADA ' + LSufixo;
    LPrimeira := TCor.Create;
    LSegunda := TCor.Create;
    LId := 0;
    try
      try
        LPrimeira.EmpresaId := LSessao.EmpresaId;
        LPrimeira.ProdutoId := 1;
        LPrimeira.Nome := LNome;
        LPrimeira.Ativo := 'A';
        LId := LCorService.Inserir(LPrimeira);
        AssertTrue(LId > 0, 'a primeira cor deve ser criada');

        { a comparação do Service é UPPER(NOME): minúsculas também colidem }
        LSegunda.EmpresaId := LSessao.EmpresaId;
        LSegunda.ProdutoId := 1;
        LSegunda.Nome := LowerCase(LNome);
        LSegunda.Ativo := 'A';
        LDeu := False;
        try
          LCorService.Inserir(LSegunda);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'nome repetido no mesmo produto deve ser recusado');
        AssertEquals('1', IntToStr(ContarPorCampo('COR', 'NOME', LNome)),
          'deve existir apenas a primeira cor');
        ASuite.AddResult('TestCorNomeDuplicadoNoProduto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCorNomeDuplicadoNoProduto', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LCorService.Excluir(LId);
        except
        end;
      LSegunda.Free;
      LPrimeira.Free;
    end;
  end;

  procedure TestMaterialCicloCompleto;
  var
    LMaterial, LLido: TMaterial;
    LId: Int64;
    LCodigo, LCodigoBarras, LDescricao: string;
  begin
    LCodigo := 'MAT' + Copy(LSufixo, 1, 10);
    LCodigoBarras := '789' + Copy(LSufixo, 1, 10);
    LDescricao := 'MATERIAL TESTE ' + LSufixo;
    LMaterial := TMaterial.Create;
    LId := 0;
    try
      try
        LMaterial.EmpresaId := LSessao.EmpresaId;
        LMaterial.Codigo := LCodigo;
        LMaterial.CodigoBarras := LCodigoBarras;
        LMaterial.Descricao := LDescricao;
        LMaterial.PrecoCusto := 12.5;
        LMaterial.ControlaEstoque := True;
        LMaterial.EstoqueMinimo := 3;
        LMaterial.Ativo := 'A';
        LMaterial.Observacoes := 'material criado pelo teste';
        LId := LMaterialService.Inserir(LMaterial);

        AssertTrue(LId > 0, 'o INSERT do material deve devolver o ID');
        AssertEquals('1', IntToStr(ContarPorId('MATERIAL', LId)),
          'o material deve existir no banco');

        LLido := LMaterialService.BuscarPorId(LId);
        try
          AssertNotNull(LLido, 'BuscarPorId deve achar o material');
          AssertEquals(LCodigo, LLido.Codigo, 'o código deve voltar do banco');
          AssertEquals(LDescricao, LLido.Descricao,
            'a descrição deve voltar do banco');
          AssertEquals(CurrToStr(12.5), CurrToStr(LLido.PrecoCusto),
            'o preço de custo deve voltar do banco');
          AssertTrue(LLido.ControlaEstoque,
            'CONTROLA_ESTOQUE = S deve voltar como True');
        finally
          LLido.Free;
        end;

        LLista := LMaterialService.Pesquisar(LCodigo);
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'Pesquisar deve achar pelo código');
        finally
          LLista.Close;
        end;

        LLista := LMaterialService.Pesquisar(LowerCase(LDescricao));
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'Pesquisar deve achar pela descrição sem diferenciar caixa');
        finally
          LLista.Close;
        end;

        LLista := LMaterialService.Pesquisar(LCodigoBarras);
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'Pesquisar deve achar pelo código de barras');
        finally
          LLista.Close;
        end;

        LLista := LMaterialService.BuscarTodos;
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'BuscarTodos deve listar o material da empresa');
        finally
          LLista.Close;
        end;

        LMaterial.Id := LId;
        LMaterial.Descricao := LDescricao + ' II';
        LMaterial.PrecoCusto := 20.75;
        LMaterial.ControlaEstoque := False;
        LMaterial.EstoqueMinimo := 7.5;
        LMaterial.Ativo := 'I';
        AssertTrue(LMaterialService.Atualizar(LMaterial),
          'Atualizar deve retornar True');

        LLido := LMaterialService.BuscarPorId(LId);
        try
          AssertEquals(LDescricao + ' II', LLido.Descricao,
            'o UPDATE deve gravar a descrição');
          AssertFalse(LLido.ControlaEstoque,
            'CONTROLA_ESTOQUE = N deve voltar como False');
          AssertEquals('I', LLido.Ativo, 'o UPDATE deve gravar o ATIVO');
          AssertEquals(CurrToStr(20.75), CurrToStr(LLido.PrecoCusto),
            'o UPDATE deve gravar o preço de custo');
        finally
          LLido.Free;
        end;

        AssertTrue(LMaterialService.Excluir(LId), 'Excluir deve retornar True');
        AssertNil(LMaterialService.BuscarPorId(LId),
          'o material excluído não deve ser encontrado');
        AssertEquals('0', IntToStr(ContarPorId('MATERIAL', LId)),
          'o material deve sumir do banco');

        AssertTrue(ContarLog('MATERIAL', LId) >= 3,
          'INSERIR, ATUALIZAR e EXCLUIR devem gerar auditoria');
        LId := 0;

        ASuite.AddResult('TestMaterialCicloCompleto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestMaterialCicloCompleto', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LMaterialService.Excluir(LId);
        except
        end;
      LMaterial.Free;
    end;
  end;

  procedure TestMaterialSemDescricao;
  var
    LMaterial: TMaterial;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LMaterial := TMaterial.Create;
    try
      try
        LAntes := ContarTotal('MATERIAL');
        LMaterial.EmpresaId := LSessao.EmpresaId;
        LMaterial.Codigo := 'SEMDESC' + Copy(LSufixo, 1, 8);
        LMaterial.Descricao := '';
        LMaterial.Ativo := 'A';
        LDeu := False;
        try
          LMaterialService.Inserir(LMaterial);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('MATERIAL');
        AssertTrue(LDeu, 'material sem descrição deve ser recusado');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhum material deve ser gravado');
        ASuite.AddResult('TestMaterialSemDescricao', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestMaterialSemDescricao', False, E.Message);
      end;
    finally
      LMaterial.Free;
    end;
  end;

  procedure TestMaterialCodigoDuplicado;
  var
    LPrimeiro, LSegundo: TMaterial;
    LId: Int64;
    LCodigo: string;
    LDeu: Boolean;
  begin
    LCodigo := 'DUPMAT' + Copy(LSufixo, 1, 8);
    LPrimeiro := TMaterial.Create;
    LSegundo := TMaterial.Create;
    LId := 0;
    try
      try
        LPrimeiro.EmpresaId := LSessao.EmpresaId;
        LPrimeiro.Codigo := LCodigo;
        LPrimeiro.Descricao := 'MATERIAL DUPLICADO A ' + LSufixo;
        LPrimeiro.Ativo := 'A';
        LId := LMaterialService.Inserir(LPrimeiro);
        AssertTrue(LId > 0, 'o primeiro material deve ser criado');

        LSegundo.EmpresaId := LSessao.EmpresaId;
        LSegundo.Codigo := LCodigo;
        LSegundo.Descricao := 'MATERIAL DUPLICADO B ' + LSufixo;
        LSegundo.Ativo := 'A';
        LDeu := False;
        try
          LMaterialService.Inserir(LSegundo);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'código de material repetido deve ser recusado');
        AssertEquals('1', IntToStr(ContarPorCampo('MATERIAL', 'CODIGO', LCodigo)),
          'deve existir apenas o primeiro material');
        ASuite.AddResult('TestMaterialCodigoDuplicado', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestMaterialCodigoDuplicado', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LMaterialService.Excluir(LId);
        except
        end;
      LSegundo.Free;
      LPrimeiro.Free;
    end;
  end;

  procedure TestMaterialCodigoVazioPermitido;
  var
    LPrimeiro, LSegundo: TMaterial;
    LId1, LId2: Int64;
  begin
    LPrimeiro := TMaterial.Create;
    LSegundo := TMaterial.Create;
    LId1 := 0;
    LId2 := 0;
    try
      try
        LPrimeiro.EmpresaId := LSessao.EmpresaId;
        LPrimeiro.Codigo := '';
        LPrimeiro.Descricao := 'MATERIAL SEM CODIGO A ' + LSufixo;
        LPrimeiro.Ativo := 'A';
        LId1 := LMaterialService.Inserir(LPrimeiro);
        AssertTrue(LId1 > 0,
          'código vazio é opcional e não pode barrar o primeiro material');

        LSegundo.EmpresaId := LSessao.EmpresaId;
        LSegundo.Codigo := '';
        LSegundo.Descricao := 'MATERIAL SEM CODIGO B ' + LSufixo;
        LSegundo.Ativo := 'A';
        LId2 := LMaterialService.Inserir(LSegundo);
        AssertTrue(LId2 > 0,
          'dois materiais sem código devem conviver sem colisão');
        AssertTrue(LId1 <> LId2, 'os dois materiais devem ter IDs distintos');

        ASuite.AddResult('TestMaterialCodigoVazioPermitido', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestMaterialCodigoVazioPermitido', False, E.Message);
      end;
    finally
      if LId2 > 0 then
        try
          LMaterialService.Excluir(LId2);
        except
        end;
      if LId1 > 0 then
        try
          LMaterialService.Excluir(LId1);
        except
        end;
      LSegundo.Free;
      LPrimeiro.Free;
    end;
  end;

  procedure TestProdutoFiscalCicloCompleto;
  var
    LProduto, LLido: TProdutoFiscal;
    LId: Int64;
    LCodigo, LDescricao: string;
  begin
    LCodigo := 'PF' + Copy(LSufixo, 1, 10);
    LDescricao := 'PRODUTO FISCAL TESTE ' + LSufixo;
    LProduto := TProdutoFiscal.Create;
    LId := 0;
    try
      try
        LProduto.EmpresaId := LSessao.EmpresaId;
        LProduto.Codigo := LCodigo;
        LProduto.Descricao := LDescricao;
        LProduto.Ncm := '61091000';
        LProduto.Cest := '';
        LProduto.Cfop := '5102';
        LProduto.CfopVenda := '5102';
        LProduto.CfopCompra := '2102';
        LProduto.CstIcms := '00';
        LProduto.CstPis := '01';
        LProduto.CstCofins := '01';
        LProduto.AliqIcms := 18;
        LProduto.AliqPis := 1.65;
        LProduto.AliqCofins := 7.6;
        LProduto.PesoLiquido := 0.2;
        LProduto.PesoBruto := 0.25;
        LProduto.Ativo := 'A';
        LProduto.Observacoes := 'produto fiscal criado pelo teste';
        LId := LProdutoFiscalService.Inserir(LProduto);

        AssertTrue(LId > 0, 'o INSERT do produto fiscal deve devolver o ID');
        AssertEquals('1', IntToStr(ContarPorId('PRODUTO_FISCAL', LId)),
          'o produto fiscal deve existir no banco');

        LLido := LProdutoFiscalService.BuscarPorId(LId);
        try
          AssertNotNull(LLido, 'BuscarPorId deve achar o produto fiscal');
          AssertEquals(LCodigo, LLido.Codigo,
            'o código deve voltar do banco');
          AssertEquals(LDescricao, LLido.Descricao,
            'a descrição deve voltar do banco');
          AssertEquals('61091000', LLido.Ncm, 'o NCM deve voltar do banco');
          AssertEquals('5102', LLido.Cfop, 'o CFOP deve voltar do banco');
          AssertEquals('00', LLido.CstIcms,
            'o CST de ICMS deve voltar do banco');
          AssertTrue(Abs(LLido.AliqIcms - 18) < 0.0001,
            'a alíquota de ICMS deve voltar do banco');
        finally
          LLido.Free;
        end;

        LLista := LProdutoFiscalService.Pesquisar(LCodigo);
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'Pesquisar deve achar pelo código');
        finally
          LLista.Close;
        end;

        LLista := LProdutoFiscalService.Pesquisar(LowerCase(LDescricao));
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'Pesquisar deve achar pela descrição sem diferenciar caixa');
        finally
          LLista.Close;
        end;

        LLista := LProdutoFiscalService.Pesquisar('61091000');
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'Pesquisar deve achar pelo NCM');
        finally
          LLista.Close;
        end;

        LLista := LProdutoFiscalService.BuscarTodos;
        try
          AssertTrue(AchouNaLista(LLista, LId),
            'BuscarTodos deve listar o produto fiscal da empresa');
        finally
          LLista.Close;
        end;

        LProduto.Id := LId;
        LProduto.Descricao := LDescricao + ' II';
        LProduto.Ncm := '62052000';
        LProduto.AliqIcms := 12;
        LProduto.Ativo := 'I';
        AssertTrue(LProdutoFiscalService.Atualizar(LProduto),
          'Atualizar deve retornar True');

        LLido := LProdutoFiscalService.BuscarPorId(LId);
        try
          AssertEquals(LDescricao + ' II', LLido.Descricao,
            'o UPDATE deve gravar a descrição');
          AssertEquals('62052000', LLido.Ncm, 'o UPDATE deve gravar o NCM');
          AssertTrue(Abs(LLido.AliqIcms - 12) < 0.0001,
            'o UPDATE deve gravar a alíquota');
          AssertEquals('I', LLido.Ativo, 'o UPDATE deve gravar o ATIVO');
        finally
          LLido.Free;
        end;

        AssertTrue(LProdutoFiscalService.Excluir(LId),
          'Excluir deve retornar True');
        AssertNil(LProdutoFiscalService.BuscarPorId(LId),
          'o produto fiscal excluído não deve ser encontrado');
        AssertEquals('0', IntToStr(ContarPorId('PRODUTO_FISCAL', LId)),
          'o produto fiscal deve sumir do banco');

        AssertTrue(ContarLog('PRODUTO_FISCAL', LId) >= 3,
          'INSERIR, ATUALIZAR e EXCLUIR devem gerar auditoria');
        LId := 0;

        ASuite.AddResult('TestProdutoFiscalCicloCompleto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestProdutoFiscalCicloCompleto', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LProdutoFiscalService.Excluir(LId);
        except
        end;
      LProduto.Free;
    end;
  end;

  procedure TestProdutoFiscalSemDescricao;
  var
    LProduto: TProdutoFiscal;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LProduto := TProdutoFiscal.Create;
    try
      try
        LAntes := ContarTotal('PRODUTO_FISCAL');
        LProduto.EmpresaId := LSessao.EmpresaId;
        LProduto.Codigo := 'PFSEMDESC' + Copy(LSufixo, 1, 8);
        LProduto.Descricao := '';
        LProduto.Ativo := 'A';
        LDeu := False;
        try
          LProdutoFiscalService.Inserir(LProduto);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('PRODUTO_FISCAL');
        AssertTrue(LDeu, 'produto fiscal sem descrição deve ser recusado');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhum produto fiscal deve ser gravado');
        ASuite.AddResult('TestProdutoFiscalSemDescricao', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestProdutoFiscalSemDescricao', False, E.Message);
      end;
    finally
      LProduto.Free;
    end;
  end;

  procedure TestProdutoFiscalCodigoDuplicado;
  var
    LPrimeiro, LSegundo: TProdutoFiscal;
    LId: Int64;
    LCodigo: string;
    LDeu: Boolean;
  begin
    LCodigo := 'DUPPF' + Copy(LSufixo, 1, 8);
    LPrimeiro := TProdutoFiscal.Create;
    LSegundo := TProdutoFiscal.Create;
    LId := 0;
    try
      try
        LPrimeiro.EmpresaId := LSessao.EmpresaId;
        LPrimeiro.Codigo := LCodigo;
        LPrimeiro.Descricao := 'PRODUTO FISCAL DUPLICADO A ' + LSufixo;
        LPrimeiro.Ativo := 'A';
        LId := LProdutoFiscalService.Inserir(LPrimeiro);
        AssertTrue(LId > 0, 'o primeiro produto fiscal deve ser criado');

        LSegundo.EmpresaId := LSessao.EmpresaId;
        LSegundo.Codigo := LCodigo;
        LSegundo.Descricao := 'PRODUTO FISCAL DUPLICADO B ' + LSufixo;
        LSegundo.Ativo := 'A';
        LDeu := False;
        try
          LProdutoFiscalService.Inserir(LSegundo);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'código de produto fiscal repetido deve ser recusado');
        AssertEquals('1',
          IntToStr(ContarPorCampo('PRODUTO_FISCAL', 'CODIGO', LCodigo)),
          'deve existir apenas o primeiro produto fiscal');
        ASuite.AddResult('TestProdutoFiscalCodigoDuplicado', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestProdutoFiscalCodigoDuplicado', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LProdutoFiscalService.Excluir(LId);
        except
        end;
      LSegundo.Free;
      LPrimeiro.Free;
    end;
  end;

  procedure TestProdutoFiscalCodigoVazioPermitido;
  var
    LPrimeiro, LSegundo: TProdutoFiscal;
    LId1, LId2: Int64;
  begin
    LPrimeiro := TProdutoFiscal.Create;
    LSegundo := TProdutoFiscal.Create;
    LId1 := 0;
    LId2 := 0;
    try
      try
        LPrimeiro.EmpresaId := LSessao.EmpresaId;
        LPrimeiro.Codigo := '';
        LPrimeiro.Descricao := 'PRODUTO FISCAL SEM CODIGO A ' + LSufixo;
        LPrimeiro.Ativo := 'A';
        LId1 := LProdutoFiscalService.Inserir(LPrimeiro);
        AssertTrue(LId1 > 0,
          'código vazio é opcional e não pode barrar o primeiro produto fiscal');

        LSegundo.EmpresaId := LSessao.EmpresaId;
        LSegundo.Codigo := '';
        LSegundo.Descricao := 'PRODUTO FISCAL SEM CODIGO B ' + LSufixo;
        LSegundo.Ativo := 'A';
        LId2 := LProdutoFiscalService.Inserir(LSegundo);
        AssertTrue(LId2 > 0,
          'dois produtos fiscais sem código devem conviver sem colisão');
        AssertTrue(LId1 <> LId2,
          'os dois produtos fiscais devem ter IDs distintos');

        ASuite.AddResult('TestProdutoFiscalCodigoVazioPermitido', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestProdutoFiscalCodigoVazioPermitido', False,
            E.Message);
      end;
    finally
      if LId2 > 0 then
        try
          LProdutoFiscalService.Excluir(LId2);
        except
        end;
      if LId1 > 0 then
        try
          LProdutoFiscalService.Excluir(LId1);
        except
        end;
      LSegundo.Free;
      LPrimeiro.Free;
    end;
  end;

  procedure TestGradeCicloCompleto;
  var
    LGrade, LLido: TGrade;
    LId: Int64;
    LNome: string;
    LTams: TGradeTamanhos;
  begin
    LNome := 'GRADE TESTE ' + LSufixo;
    LGrade := TGrade.Create;
    LId := 0;
    try
      try
        LGrade.EmpresaId := LSessao.EmpresaId;
        LGrade.Nome := LNome;
        LGrade.Tipo := 'CALCADO';
        LGrade.Ativo := 'A';
        LGrade.Observacao := 'grade criada pelo teste';
        LGrade.Tamanhos := Tamanhos(['34', '35', '36']);
        LId := LGradeService.Inserir(LGrade);

        AssertTrue(LId > 0, 'o INSERT da grade deve devolver o ID');
        AssertEquals('1', IntToStr(ContarPorId('GRADE', LId)),
          'a grade deve existir no banco');
        AssertEquals('3', IntToStr(ContarTamanhos(LId)),
          'a grade deve ter os 3 tamanhos informados');

        LLido := LGradeService.BuscarPorId(LId);
        try
          AssertNotNull(LLido, 'BuscarPorId deve achar a grade');
          AssertEquals(LNome, LLido.Nome, 'o nome deve voltar do banco');
          AssertEquals('CALCADO', LLido.Tipo, 'o tipo deve voltar do banco');
          AssertEquals('3', IntToStr(Length(LLido.Tamanhos)),
            'BuscarPorId deve carregar os tamanhos');
          AssertEquals('34', LLido.Tamanhos[0].Tamanho,
            'o primeiro tamanho deve ser 34');
          AssertEquals('0', IntToStr(LLido.Tamanhos[0].Ordem),
            'a ordem do primeiro tamanho deve ser 0');
          AssertEquals('36', LLido.Tamanhos[2].Tamanho,
            'o terceiro tamanho deve ser 36');
        finally
          LLido.Free;
        end;

        LTams := LGradeService.ListarTamanhos(LId);
        AssertEquals('3', IntToStr(Length(LTams)),
          'ListarTamanhos deve devolver os 3 tamanhos');

        LGrade.Id := LId;
        LGrade.Nome := LNome + ' II';
        LGrade.Tipo := 'CONFECCAO';
        LGrade.Ativo := 'I';
        LGrade.Tamanhos := Tamanhos(['P', 'M']);
        AssertTrue(LGradeService.Atualizar(LGrade), 'Atualizar deve retornar True');

        AssertEquals('2', IntToStr(ContarTamanhos(LId)),
          'o UPDATE deve substituir os tamanhos');
        LLido := LGradeService.BuscarPorId(LId);
        try
          AssertEquals(LNome + ' II', LLido.Nome,
            'o UPDATE deve gravar o nome');
          AssertEquals('CONFECCAO', LLido.Tipo,
            'o UPDATE deve gravar o tipo');
          AssertEquals('I', LLido.Ativo, 'o UPDATE deve gravar o ATIVO');
          AssertEquals('2', IntToStr(Length(LLido.Tamanhos)),
            'o UPDATE deve deixar 2 tamanhos');
          AssertEquals('P', LLido.Tamanhos[0].Tamanho,
            'o primeiro tamanho deve ser P');
          AssertEquals('M', LLido.Tamanhos[1].Tamanho,
            'o segundo tamanho deve ser M');
        finally
          LLido.Free;
        end;

        AssertTrue(LGradeService.Excluir(LId), 'Excluir deve retornar True');
        AssertNil(LGradeService.BuscarPorId(LId),
          'a grade excluída não deve ser encontrada');
        AssertEquals('0', IntToStr(ContarTamanhos(LId)),
          'os tamanhos devem sumir junto com a grade');
        AssertEquals('0', IntToStr(ContarPorId('GRADE', LId)),
          'a grade deve sumir do banco');

        AssertTrue(ContarLog('GRADE', LId) >= 3,
          'INSERIR, ATUALIZAR e EXCLUIR devem gerar auditoria');
        LId := 0;

        ASuite.AddResult('TestGradeCicloCompleto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeCicloCompleto', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LGradeService.Excluir(LId);
        except
        end;
      LGrade.Free;
    end;
  end;

  procedure TestGradeSemNome;
  var
    LGrade: TGrade;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LGrade := TGrade.Create;
    try
      try
        LAntes := ContarTotal('GRADE');
        LGrade.EmpresaId := LSessao.EmpresaId;
        LGrade.Nome := '';
        LGrade.Tipo := 'OUTRO';
        LGrade.Ativo := 'A';
        LGrade.Tamanhos := Tamanhos(['U']);
        LDeu := False;
        try
          LGradeService.Inserir(LGrade);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('GRADE');
        AssertTrue(LDeu, 'grade sem nome deve ser recusada');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhuma grade deve ser gravada');
        ASuite.AddResult('TestGradeSemNome', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeSemNome', False, E.Message);
      end;
    finally
      LGrade.Free;
    end;
  end;

  procedure TestGradeTipoInvalido;
  var
    LGrade: TGrade;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LGrade := TGrade.Create;
    try
      try
        LAntes := ContarTotal('GRADE');
        LGrade.EmpresaId := LSessao.EmpresaId;
        LGrade.Nome := 'GRADE TIPO INVALIDO ' + LSufixo;
        LGrade.Tipo := 'INVALIDO';
        LGrade.Ativo := 'A';
        LGrade.Tamanhos := Tamanhos(['U']);
        LDeu := False;
        try
          LGradeService.Inserir(LGrade);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('GRADE');
        AssertTrue(LDeu, 'tipo de grade inválido deve ser recusado');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhuma grade deve ser gravada');
        ASuite.AddResult('TestGradeTipoInvalido', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeTipoInvalido', False, E.Message);
      end;
    finally
      LGrade.Free;
    end;
  end;

  procedure TestGradeSemTamanho;
  var
    LGrade: TGrade;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LGrade := TGrade.Create;
    try
      try
        LAntes := ContarTotal('GRADE');
        LGrade.EmpresaId := LSessao.EmpresaId;
        LGrade.Nome := 'GRADE SEM TAMANHO ' + LSufixo;
        LGrade.Tipo := 'OUTRO';
        LGrade.Ativo := 'A';
        LGrade.Tamanhos := nil;
        LDeu := False;
        try
          LGradeService.Inserir(LGrade);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('GRADE');
        AssertTrue(LDeu, 'grade sem nenhum tamanho deve ser recusada');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhuma grade deve ser gravada');
        ASuite.AddResult('TestGradeSemTamanho', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeSemTamanho', False, E.Message);
      end;
    finally
      LGrade.Free;
    end;
  end;

  procedure TestGradeTamanhoRepetido;
  var
    LGrade: TGrade;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LGrade := TGrade.Create;
    try
      try
        LAntes := ContarTotal('GRADE');
        LGrade.EmpresaId := LSessao.EmpresaId;
        LGrade.Nome := 'GRADE TAMANHO REPETIDO ' + LSufixo;
        LGrade.Tipo := 'OUTRO';
        LGrade.Ativo := 'A';
        { a validação é case-insensitive: P e p colidem }
        LGrade.Tamanhos := Tamanhos(['P', 'p']);
        LDeu := False;
        try
          LGradeService.Inserir(LGrade);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('GRADE');
        AssertTrue(LDeu, 'tamanho repetido deve ser recusado');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhuma grade deve ser gravada');
        ASuite.AddResult('TestGradeTamanhoRepetido', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeTamanhoRepetido', False, E.Message);
      end;
    finally
      LGrade.Free;
    end;
  end;

  procedure TestGradeTamanhoLongo;
  var
    LGrade: TGrade;
    LAntes, LDepois: Integer;
    LDeu: Boolean;
  begin
    LGrade := TGrade.Create;
    try
      try
        LAntes := ContarTotal('GRADE');
        LGrade.EmpresaId := LSessao.EmpresaId;
        LGrade.Nome := 'GRADE TAMANHO LONGO ' + LSufixo;
        LGrade.Tipo := 'OUTRO';
        LGrade.Ativo := 'A';
        LGrade.Tamanhos := Tamanhos(['12345678901']);
        LDeu := False;
        try
          LGradeService.Inserir(LGrade);
        except
          on E: Exception do
            LDeu := True;
        end;
        LDepois := ContarTotal('GRADE');
        AssertTrue(LDeu, 'tamanho com mais de 10 caracteres deve ser recusado');
        AssertEquals(IntToStr(LAntes), IntToStr(LDepois),
          'nenhuma grade deve ser gravada');
        ASuite.AddResult('TestGradeTamanhoLongo', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeTamanhoLongo', False, E.Message);
      end;
    finally
      LGrade.Free;
    end;
  end;

  procedure TestGradeNomeDuplicado;
  var
    LPrimeira, LSegunda: TGrade;
    LId: Int64;
    LNome: string;
    LDeu: Boolean;
  begin
    LNome := 'GRADE DUPLICADA ' + LSufixo;
    LPrimeira := TGrade.Create;
    LSegunda := TGrade.Create;
    LId := 0;
    try
      try
        LPrimeira.EmpresaId := LSessao.EmpresaId;
        LPrimeira.Nome := LNome;
        LPrimeira.Tipo := 'OUTRO';
        LPrimeira.Ativo := 'A';
        LPrimeira.Tamanhos := Tamanhos(['U']);
        LId := LGradeService.Inserir(LPrimeira);
        AssertTrue(LId > 0, 'a primeira grade deve ser criada');

        LSegunda.EmpresaId := LSessao.EmpresaId;
        LSegunda.Nome := LNome;
        LSegunda.Tipo := 'OUTRO';
        LSegunda.Ativo := 'A';
        LSegunda.Tamanhos := Tamanhos(['V']);
        LDeu := False;
        try
          LGradeService.Inserir(LSegunda);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu,
          'o índice UQ_GRADE_NOME deve impedir nome repetido na empresa');
        AssertEquals('1', IntToStr(ContarPorCampo('GRADE', 'NOME', LNome)),
          'deve existir apenas a primeira grade');
        ASuite.AddResult('TestGradeNomeDuplicado', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeNomeDuplicado', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LGradeService.Excluir(LId);
        except
        end;
      LSegunda.Free;
      LPrimeira.Free;
    end;
  end;

  procedure TestGradeVinculadaAProdutoNaoExclui;
  var
    LGrade: TGrade;
    LGradeId, LOriginal: Int64;
    LDeu: Boolean;
  begin
    LGrade := TGrade.Create;
    LGradeId := 0;
    LOriginal := 0;
    try
      try
        LOriginal := LGradeService.GradeDoProduto(1);

        LGrade.EmpresaId := LSessao.EmpresaId;
        LGrade.Nome := 'GRADE VINCULADA ' + LSufixo;
        LGrade.Tipo := 'OUTRO';
        LGrade.Ativo := 'A';
        LGrade.Tamanhos := Tamanhos(['U']);
        LGradeId := LGradeService.Inserir(LGrade);
        AssertTrue(LGradeId > 0, 'a grade de apoio deve ser criada');

        LGradeService.DefinirGradeDoProduto(1, LGradeId);
        AssertEquals(IntToStr(LGradeId),
          IntToStr(LGradeService.GradeDoProduto(1)),
          'o produto deve apontar para a grade de teste');

        LDeu := False;
        try
          LGradeService.Excluir(LGradeId);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu,
          'grade vinculada a produto não pode ser excluída');
        AssertEquals('1', IntToStr(ContarPorId('GRADE', LGradeId)),
          'a grade vinculada deve continuar no banco');

        ASuite.AddResult('TestGradeVinculadaAProdutoNaoExclui', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestGradeVinculadaAProdutoNaoExclui', False,
            E.Message);
      end;
    finally
      try
        LGradeService.DefinirGradeDoProduto(1, LOriginal);
      except
      end;
      if LGradeId > 0 then
        try
          LGradeService.Excluir(LGradeId);
        except
        end;
      LGrade.Free;
    end;
  end;

  procedure TestUsaGradeRoundTrip;
  var
    LOriginal: string;
    LExistia: Boolean;
  begin
    LOriginal := '';
    LExistia := False;
    try
      try
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT FIRST 1 VALOR FROM CONFIGURACAO ' +
          'WHERE CHAVE = ''USA_GRADE'' ' +
          'AND (EMPRESA_ID = :E OR EMPRESA_ID IS NULL) ' +
          'ORDER BY EMPRESA_ID DESC';
        LQuery.ParamByName('E').AsLargeInt := LSessao.EmpresaId;
        LQuery.Open;
        LExistia := not LQuery.IsEmpty;
        if LExistia then
          LOriginal := UpperCase(Trim(LQuery.FieldByName('VALOR').AsString));
        LQuery.Close;

        LGradeService.DefinirUsaGrade(True);
        AssertTrue(LGradeService.UsaGrade,
          'DefinirUsaGrade(True) deve ligar a configuração');

        LGradeService.DefinirUsaGrade(False);
        AssertFalse(LGradeService.UsaGrade,
          'DefinirUsaGrade(False) deve desligar a configuração');

        AssertTrue(ContarLog('CONFIGURACAO', 0) >= 2,
          'as duas alterações de USA_GRADE devem gerar auditoria');

        ASuite.AddResult('TestUsaGradeRoundTrip', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestUsaGradeRoundTrip', False, E.Message);
      end;
    finally
      try
        if LExistia then
        begin
          LQuery.Close;
          LQuery.SQL.Text :=
            'UPDATE CONFIGURACAO SET VALOR = :V ' +
            'WHERE CHAVE = ''USA_GRADE'' ' +
            'AND (EMPRESA_ID = :E OR EMPRESA_ID IS NULL)';
          LQuery.ParamByName('V').AsString := LOriginal;
          LQuery.ParamByName('E').AsLargeInt := LSessao.EmpresaId;
          LQuery.ExecSQL;
        end
        else
        begin
          LQuery.Close;
          LQuery.SQL.Text :=
            'DELETE FROM CONFIGURACAO WHERE CHAVE = ''USA_GRADE'' ' +
            'AND EMPRESA_ID = :E';
          LQuery.ParamByName('E').AsLargeInt := LSessao.EmpresaId;
          LQuery.ExecSQL;
        end;
        LConexao.Confirmar;
      except
      end;
    end;
  end;

  procedure TestSomarQuantidades;
  var
    LTams: TGradeTamanhos;
  begin
    try
      LTams := TamanhosComQtd(['P', 'M', 'G'], [2.5, 1.5, 1]);
      AssertTrue(Abs(SomarQuantidades(LTams) - 5.0) < 0.0001,
        'a soma das quantidades deve ser 5');

      LTams := TamanhosComQtd(['P'], [0]);
      AssertTrue(Abs(SomarQuantidades(LTams) - 0) < 0.0001,
        'um tamanho com quantidade 0 deve somar 0');

      SetLength(LTams, 0);
      AssertTrue(Abs(SomarQuantidades(LTams) - 0) < 0.0001,
        'uma grade vazia deve somar 0');

      ASuite.AddResult('TestSomarQuantidades', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSomarQuantidades', False, E.Message);
    end;
  end;

  procedure TestTiposGrade;
  begin
    try
      AssertEquals('Calçado', DescricaoTipoGrade('CALCADO'),
        'CALCADO deve ter descrição amigável');
      AssertEquals('Confecção', DescricaoTipoGrade('CONFECCAO'),
        'CONFECCAO deve ter descrição amigável');
      AssertEquals('Outro', DescricaoTipoGrade('XYZ'),
        'tipo desconhecido deve cair em Outro');

      AssertEquals('2', IntToStr(IndiceTipoGrade('GRUPO')),
        'GRUPO deve estar no índice 2');
      AssertEquals('3', IntToStr(IndiceTipoGrade('XYZ')),
        'tipo desconhecido deve cair em OUTRO');

      AssertEquals('CALCADO', TipoGradePorIndice(0),
        'o índice 0 deve devolver CALCADO');
      AssertEquals('OUTRO', TipoGradePorIndice(99),
        'índice acima do fim deve devolver OUTRO');
      AssertEquals('OUTRO', TipoGradePorIndice(-1),
        'índice negativo deve devolver OUTRO');

      ASuite.AddResult('TestTiposGrade', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestTiposGrade', False, E.Message);
    end;
  end;

  procedure LimparSobraPorSufixo;
  var
    LMascara: string;
  begin
    LMascara := '%' + LSufixo + '%';
    try
      { devolve o produto 1 ao estado anterior caso a grade de teste
        tenha ficado vinculada por causa de uma falha }
      LQuery.Close;
      LQuery.SQL.Text :=
        'UPDATE PRODUTO SET GRADE_ID = NULL ' +
        'WHERE GRADE_ID IN (SELECT ID FROM GRADE WHERE NOME LIKE :M)';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM GRADE_TAMANHO ' +
        'WHERE GRADE_ID IN (SELECT ID FROM GRADE WHERE NOME LIKE :M)';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM GRADE WHERE NOME LIKE :M';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM COR WHERE NOME LIKE :M';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM MATERIAL WHERE DESCRICAO LIKE :M';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM PRODUTO_FISCAL WHERE DESCRICAO LIKE :M';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;

      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM LOG_SISTEMA WHERE ID > :TOPO ' +
        'AND TABELA IN (''COR'', ''MATERIAL'', ''PRODUTO_FISCAL'', ' +
        '''GRADE'', ''CONFIGURACAO'', ''PRODUTO'')';
      LQuery.ParamByName('TOPO').AsLargeInt := LTopoLog;
      LQuery.ExecSQL;

      LConexao.Confirmar;
    except
      { limpeza não pode derrubar a suíte }
    end;
  end;

begin
  LConexao := TConexao.GetInstance;
  LSessao := TSessao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LLista := nil;
  LCorService := TCorService.Create;
  LMaterialService := TMaterialService.Create;
  LProdutoFiscalService := TProdutoFiscalService.Create;
  LGradeService := TGradeService.Create;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    LTopoLog := 0;
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM LOG_SISTEMA ORDER BY ID DESC';
    LQuery.Open;
    if not LQuery.IsEmpty then
      LTopoLog := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DOS CADASTROS DA FASE 1');
    WriteLn('========================================');

    TestCorCicloCompleto;
    TestCorSemNome;
    TestCorSemProduto;
    TestCorNomeDuplicadoNoProduto;
    TestMaterialCicloCompleto;
    TestMaterialSemDescricao;
    TestMaterialCodigoDuplicado;
    TestMaterialCodigoVazioPermitido;
    TestProdutoFiscalCicloCompleto;
    TestProdutoFiscalSemDescricao;
    TestProdutoFiscalCodigoDuplicado;
    TestProdutoFiscalCodigoVazioPermitido;
    TestGradeCicloCompleto;
    TestGradeSemNome;
    TestGradeTipoInvalido;
    TestGradeSemTamanho;
    TestGradeTamanhoRepetido;
    TestGradeTamanhoLongo;
    TestGradeNomeDuplicado;
    TestGradeVinculadaAProdutoNaoExclui;
    TestUsaGradeRoundTrip;
    TestSomarQuantidades;
    TestTiposGrade;
  finally
    LimparSobraPorSufixo;
    LGradeService.Free;
    LProdutoFiscalService.Free;
    LMaterialService.Free;
    LCorService.Free;
    LQuery.Free;
  end;
end;

end.
