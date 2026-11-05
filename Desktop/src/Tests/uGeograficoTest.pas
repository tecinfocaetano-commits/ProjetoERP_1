unit uGeograficoTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes dos cadastros geográficos
  ------------------------------------------------------------
  Cobre os Services ainda sem teste:
    - TPaisService: CRUD, nome/código obrigatórios e busca;
    - TEstadoService: CRUD, UF com 2 caracteres, país obrigatório
      e filtro por país;
    - TCidadeService: CRUD, nome/estado obrigatórios e filtro por
      estado.

  Padrão da suíte: dados com sufixo de timestamp, limpeza explícita
  no finally e nenhum mock de banco. As tabelas geográficas são
  globais (sem EMPRESA_ID) e não geram LOG_SISTEMA.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uPais, uEstado, uCidade,
  uPaisService, uEstadoService, uCidadeService;

type
  { TGeograficoTest }
  TGeograficoTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TGeograficoTest }

class procedure TGeograficoTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LLista: TSQLQuery;
  LPaisService: TPaisService;
  LEstadoService: TEstadoService;
  LCidadeService: TCidadeService;
  LSufixo: string;

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

  procedure TestPaisCicloCompleto;
  var
    LPais, LLido: TPais;
    LId: Int64;
    LNome: string;
    LAchou: Boolean;
  begin
    LNome := 'PAIS TESTE ' + LSufixo;
    LPais := TPais.Create;
    LId := 0;
    try
      try
        LPais.Nome := LNome;
        LPais.Codigo := 'P' + Copy(LSufixo, 1, 4);
        LPais.Ddi := '55';
        LId := LPaisService.Inserir(LPais);

        AssertTrue(LId > 0, 'o INSERT do país deve devolver o ID');
        AssertEquals('1', IntToStr(ContarPorId('PAIS', LId)),
          'o país deve existir no banco');

        LLido := LPaisService.BuscarPorId(LId);
        try
          AssertNotNull(LLido, 'BuscarPorId deve achar o país');
          AssertEquals(LNome, LLido.Nome, 'o nome deve voltar do banco');
          AssertEquals('55', LLido.Ddi, 'o DDI deve voltar do banco');
        finally
          LLido.Free;
        end;

        LPais.Id := LId;
        LPais.Nome := LNome + ' II';
        LPais.Ddi := '99';
        AssertTrue(LPaisService.Atualizar(LPais), 'Atualizar deve retornar True');

        LLido := LPaisService.BuscarPorId(LId);
        try
          AssertEquals(LNome + ' II', LLido.Nome, 'o UPDATE deve gravar o nome');
          AssertEquals('99', LLido.Ddi, 'o UPDATE deve gravar o DDI');
        finally
          LLido.Free;
        end;

        LLista := LPaisService.BuscarTodos;
        try
          LAchou := False;
          LLista.First;
          while not LLista.EOF do
          begin
            if LLista.FieldByName('ID').AsLargeInt = LId then
              LAchou := True;
            LLista.Next;
          end;
          AssertTrue(LAchou, 'BuscarTodos deve listar o país');
        finally
          LLista.Close;
        end;

        AssertTrue(LPaisService.Excluir(LId), 'Excluir deve retornar True');
        AssertNil(LPaisService.BuscarPorId(LId),
          'o país excluído não deve ser encontrado');
        AssertEquals('0', IntToStr(ContarPorId('PAIS', LId)),
          'o país deve sumir do banco');
        LId := 0;

        ASuite.AddResult('TestPaisCicloCompleto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestPaisCicloCompleto', False, E.Message);
      end;
    finally
      if LId > 0 then
        try
          LPaisService.Excluir(LId);
        except
          { limpeza não pode derrubar a suíte }
        end;
      LPais.Free;
    end;
  end;

  procedure TestPaisSemNome;
  var
    LPais: TPais;
    LDeu: Boolean;
    LCodigo: string;
  begin
    LCodigo := 'SN' + Copy(LSufixo, 1, 3);
    LPais := TPais.Create;
    try
      try
        LPais.Nome := '';
        LPais.Codigo := LCodigo;
        LDeu := False;
        try
          LPaisService.Inserir(LPais);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'país sem nome deve ser recusado');
        AssertEquals('0', IntToStr(ContarPorCampo('PAIS', 'CODIGO', LCodigo)),
          'nada deve ser gravado');
        ASuite.AddResult('TestPaisSemNome', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestPaisSemNome', False, E.Message);
      end;
    finally
      LPais.Free;
    end;
  end;

  procedure TestPaisSemCodigo;
  var
    LPais: TPais;
    LDeu: Boolean;
    LNome: string;
  begin
    LNome := 'PAIS SEM CODIGO ' + LSufixo;
    LPais := TPais.Create;
    try
      try
        LPais.Nome := LNome;
        LPais.Codigo := '';
        LDeu := False;
        try
          LPaisService.Inserir(LPais);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'país sem código deve ser recusado pelo Service');
        AssertEquals('0', IntToStr(ContarPorCampo('PAIS', 'NOME', LNome)),
          'nada deve ser gravado');
        ASuite.AddResult('TestPaisSemCodigo', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestPaisSemCodigo', False, E.Message);
      end;
    finally
      LPais.Free;
    end;
  end;

  procedure TestPaisBuscarInexistente;
  begin
    try
      AssertNil(LPaisService.BuscarPorId(999999999),
        'BuscarPorId de país inexistente deve devolver nil');
      ASuite.AddResult('TestPaisBuscarInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPaisBuscarInexistente', False, E.Message);
    end;
  end;

  procedure TestEstadoCicloCompleto;
  var
    LPais, LLidoPais: TPais;
    LEstado, LLido: TEstado;
    LPaisId, LEstadoId: Int64;
    LNome: string;
    LAchou: Boolean;
  begin
    LPaisId := 0;
    LEstadoId := 0;
    LNome := 'ESTADO TESTE ' + LSufixo;
    LPais := TPais.Create;
    LEstado := TEstado.Create;
    try
      try
        LPais.Nome := 'PAIS DO ESTADO ' + LSufixo;
        LPais.Codigo := 'E' + Copy(LSufixo, 1, 4);
        LPais.Ddi := '55';
        LPaisId := LPaisService.Inserir(LPais);
        AssertTrue(LPaisId > 0, 'o país de apoio deve ser criado');

        LEstado.PaisId := LPaisId;
        LEstado.Nome := LNome;
        LEstado.Uf := 'TS';
        LEstado.CodigoIbge := '99';
        LEstadoId := LEstadoService.Inserir(LEstado);
        AssertTrue(LEstadoId > 0, 'o INSERT do estado deve devolver o ID');

        LLido := LEstadoService.BuscarPorId(LEstadoId);
        try
          AssertNotNull(LLido, 'BuscarPorId deve achar o estado');
          AssertEquals(IntToStr(LPaisId), IntToStr(LLido.PaisId),
            'o PAIS_ID deve voltar do banco');
          AssertEquals(LNome, LLido.Nome, 'o nome deve voltar do banco');
          AssertEquals('TS', LLido.Uf, 'a UF deve voltar do banco');
          AssertEquals('99', LLido.CodigoIbge, 'o IBGE deve voltar do banco');
        finally
          LLido.Free;
        end;

        LLista := LEstadoService.BuscarTodos(LPaisId);
        try
          LAchou := False;
          LLista.First;
          while not LLista.EOF do
          begin
            if LLista.FieldByName('ID').AsLargeInt = LEstadoId then
              LAchou := True;
            LLista.Next;
          end;
          AssertTrue(LAchou, 'o filtro por país deve listar o estado');
        finally
          LLista.Close;
        end;

        LLista := LEstadoService.BuscarTodos(LPaisId + 1000);
        try
          LAchou := False;
          LLista.First;
          while not LLista.EOF do
          begin
            if LLista.FieldByName('ID').AsLargeInt = LEstadoId then
              LAchou := True;
            LLista.Next;
          end;
          AssertFalse(LAchou, 'o filtro por outro país não deve listar o estado');
        finally
          LLista.Close;
        end;

        LEstado.Id := LEstadoId;
        LEstado.Nome := LNome + ' II';
        LEstado.Uf := 'T2';
        LEstado.CodigoIbge := '98';
        AssertTrue(LEstadoService.Atualizar(LEstado), 'Atualizar deve retornar True');

        LLido := LEstadoService.BuscarPorId(LEstadoId);
        try
          AssertEquals(LNome + ' II', LLido.Nome, 'o UPDATE deve gravar o nome');
          AssertEquals('T2', LLido.Uf, 'o UPDATE deve gravar a UF');
          AssertEquals('98', LLido.CodigoIbge, 'o UPDATE deve gravar o IBGE');
        finally
          LLido.Free;
        end;

        AssertTrue(LEstadoService.Excluir(LEstadoId),
          'Excluir deve retornar True');
        AssertNil(LEstadoService.BuscarPorId(LEstadoId),
          'o estado excluído não deve ser encontrado');
        LEstadoId := 0;

        { o país de apoio continua válido e pode ser lido }
        LLidoPais := LPaisService.BuscarPorId(LPaisId);
        try
          AssertNotNull(LLidoPais, 'o país de apoio deve continuar existindo');
        finally
          LLidoPais.Free;
        end;

        ASuite.AddResult('TestEstadoCicloCompleto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestEstadoCicloCompleto', False, E.Message);
      end;
    finally
      if LEstadoId > 0 then
        try
          LEstadoService.Excluir(LEstadoId);
        except
        end;
      if LPaisId > 0 then
        try
          LPaisService.Excluir(LPaisId);
        except
        end;
      LEstado.Free;
      LPais.Free;
    end;
  end;

  procedure TestEstadoUfInvalida;
  var
    LPais: TPais;
    LEstado: TEstado;
    LPaisId: Int64;
    LDeu: Boolean;
    LNome: string;

    function InserirComUf(const AUf: string): Boolean;
    begin
      LEstado.Uf := AUf;
      try
        LEstadoService.Inserir(LEstado);
        Result := False;
      except
        on E: Exception do
          Result := True;
      end;
    end;

  begin
    LPaisId := 0;
    LNome := 'ESTADO UF INVALIDA ' + LSufixo;
    LPais := TPais.Create;
    LEstado := TEstado.Create;
    try
      try
        LPais.Nome := 'PAIS UF INVALIDA ' + LSufixo;
        LPais.Codigo := 'U' + Copy(LSufixo, 1, 4);
        LPais.Ddi := '55';
        LPaisId := LPaisService.Inserir(LPais);

        LEstado.PaisId := LPaisId;
        LEstado.Nome := LNome;

        LDeu := InserirComUf('T');
        AssertTrue(LDeu, 'UF com 1 caractere deve ser recusada');
        LDeu := InserirComUf('TST');
        AssertTrue(LDeu, 'UF com 3 caracteres deve ser recusada');
        LDeu := InserirComUf('  ');
        AssertTrue(LDeu, 'UF vazia deve ser recusada');

        AssertEquals('0', IntToStr(ContarPorCampo('ESTADO', 'NOME', LNome)),
          'nenhum estado inválido deve ser gravado');

        ASuite.AddResult('TestEstadoUfInvalida', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestEstadoUfInvalida', False, E.Message);
      end;
    finally
      if LPaisId > 0 then
        try
          LPaisService.Excluir(LPaisId);
        except
        end;
      LEstado.Free;
      LPais.Free;
    end;
  end;

  procedure TestEstadoSemPais;
  var
    LEstado: TEstado;
    LDeu: Boolean;
    LNome: string;
  begin
    LNome := 'ESTADO SEM PAIS ' + LSufixo;
    LEstado := TEstado.Create;
    try
      try
        LEstado.PaisId := 0;
        LEstado.Nome := LNome;
        LEstado.Uf := 'TS';
        LDeu := False;
        try
          LEstadoService.Inserir(LEstado);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'estado sem país deve ser recusado');
        AssertEquals('0', IntToStr(ContarPorCampo('ESTADO', 'NOME', LNome)),
          'nada deve ser gravado');
        ASuite.AddResult('TestEstadoSemPais', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestEstadoSemPais', False, E.Message);
      end;
    finally
      LEstado.Free;
    end;
  end;

  procedure TestEstadoSemNome;
  var
    LPais: TPais;
    LEstado: TEstado;
    LPaisId: Int64;
    LDeu: Boolean;
    LNome: string;
  begin
    LPaisId := 0;
    LNome := 'ESTADO SEM NOME ' + LSufixo;
    LPais := TPais.Create;
    LEstado := TEstado.Create;
    try
      try
        LPais.Nome := 'PAIS DO ESTADO SEM NOME ' + LSufixo;
        LPais.Codigo := 'N' + Copy(LSufixo, 1, 4);
        LPais.Ddi := '55';
        LPaisId := LPaisService.Inserir(LPais);

        LEstado.PaisId := LPaisId;
        LEstado.Nome := '';
        LEstado.Uf := 'TS';
        LDeu := False;
        try
          LEstadoService.Inserir(LEstado);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'estado sem nome deve ser recusado');
        AssertEquals('0', IntToStr(ContarPorCampo('ESTADO', 'NOME', LNome)),
          'nada deve ser gravado');
        ASuite.AddResult('TestEstadoSemNome', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestEstadoSemNome', False, E.Message);
      end;
    finally
      if LPaisId > 0 then
        try
          LPaisService.Excluir(LPaisId);
        except
        end;
      LEstado.Free;
      LPais.Free;
    end;
  end;

  procedure TestCidadeCicloCompleto;
  var
    LPais: TPais;
    LEstado: TEstado;
    LCidade, LLido: TCidade;
    LPaisId, LEstadoId, LCidadeId: Int64;
    LNome: string;
    LAchou: Boolean;
  begin
    LPaisId := 0;
    LEstadoId := 0;
    LCidadeId := 0;
    LNome := 'CIDADE TESTE ' + LSufixo;
    LPais := TPais.Create;
    LEstado := TEstado.Create;
    LCidade := TCidade.Create;
    try
      try
        LPais.Nome := 'PAIS DA CIDADE ' + LSufixo;
        LPais.Codigo := 'C' + Copy(LSufixo, 1, 4);
        LPais.Ddi := '55';
        LPaisId := LPaisService.Inserir(LPais);

        LEstado.PaisId := LPaisId;
        LEstado.Nome := 'ESTADO DA CIDADE ' + LSufixo;
        LEstado.Uf := 'TS';
        LEstadoId := LEstadoService.Inserir(LEstado);

        LCidade.EstadoId := LEstadoId;
        LCidade.Nome := LNome;
        LCidade.CodigoIbge := '3550308';
        LCidadeId := LCidadeService.Inserir(LCidade);
        AssertTrue(LCidadeId > 0, 'o INSERT da cidade deve devolver o ID');

        LLido := LCidadeService.BuscarPorId(LCidadeId);
        try
          AssertNotNull(LLido, 'BuscarPorId deve achar a cidade');
          AssertEquals(IntToStr(LEstadoId), IntToStr(LLido.EstadoId),
            'o ESTADO_ID deve voltar do banco');
          AssertEquals(LNome, LLido.Nome, 'o nome deve voltar do banco');
          AssertEquals('3550308', LLido.CodigoIbge,
            'o IBGE deve voltar do banco');
        finally
          LLido.Free;
        end;

        LLista := LCidadeService.BuscarTodos(LEstadoId);
        try
          LAchou := False;
          LLista.First;
          while not LLista.EOF do
          begin
            if LLista.FieldByName('ID').AsLargeInt = LCidadeId then
              LAchou := True;
            LLista.Next;
          end;
          AssertTrue(LAchou, 'o filtro por estado deve listar a cidade');
        finally
          LLista.Close;
        end;

        LLista := LCidadeService.BuscarTodos(LEstadoId + 1000);
        try
          LAchou := False;
          LLista.First;
          while not LLista.EOF do
          begin
            if LLista.FieldByName('ID').AsLargeInt = LCidadeId then
              LAchou := True;
            LLista.Next;
          end;
          AssertFalse(LAchou, 'o filtro por outro estado não deve listar a cidade');
        finally
          LLista.Close;
        end;

        LCidade.Id := LCidadeId;
        LCidade.Nome := LNome + ' II';
        LCidade.CodigoIbge := '3550309';
        AssertTrue(LCidadeService.Atualizar(LCidade), 'Atualizar deve retornar True');

        LLido := LCidadeService.BuscarPorId(LCidadeId);
        try
          AssertEquals(LNome + ' II', LLido.Nome, 'o UPDATE deve gravar o nome');
          AssertEquals('3550309', LLido.CodigoIbge,
            'o UPDATE deve gravar o IBGE');
        finally
          LLido.Free;
        end;

        AssertTrue(LCidadeService.Excluir(LCidadeId),
          'Excluir deve retornar True');
        AssertNil(LCidadeService.BuscarPorId(LCidadeId),
          'a cidade excluída não deve ser encontrada');
        LCidadeId := 0;

        ASuite.AddResult('TestCidadeCicloCompleto', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCidadeCicloCompleto', False, E.Message);
      end;
    finally
      if LCidadeId > 0 then
        try
          LCidadeService.Excluir(LCidadeId);
        except
        end;
      if LEstadoId > 0 then
        try
          LEstadoService.Excluir(LEstadoId);
        except
        end;
      if LPaisId > 0 then
        try
          LPaisService.Excluir(LPaisId);
        except
        end;
      LCidade.Free;
      LEstado.Free;
      LPais.Free;
    end;
  end;

  procedure TestCidadeSemNome;
  var
    LPais: TPais;
    LEstado: TEstado;
    LCidade: TCidade;
    LPaisId, LEstadoId: Int64;
    LDeu: Boolean;
    LNome: string;
  begin
    LPaisId := 0;
    LEstadoId := 0;
    LNome := 'CIDADE SEM NOME ' + LSufixo;
    LPais := TPais.Create;
    LEstado := TEstado.Create;
    LCidade := TCidade.Create;
    try
      try
        LPais.Nome := 'PAIS CIDADE SEM NOME ' + LSufixo;
        LPais.Codigo := 'S' + Copy(LSufixo, 1, 4);
        LPais.Ddi := '55';
        LPaisId := LPaisService.Inserir(LPais);

        LEstado.PaisId := LPaisId;
        LEstado.Nome := 'ESTADO CIDADE SEM NOME ' + LSufixo;
        LEstado.Uf := 'TS';
        LEstadoId := LEstadoService.Inserir(LEstado);

        LCidade.EstadoId := LEstadoId;
        LCidade.Nome := '';
        LDeu := False;
        try
          LCidadeService.Inserir(LCidade);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'cidade sem nome deve ser recusada');
        AssertEquals('0', IntToStr(ContarPorCampo('CIDADE', 'NOME', LNome)),
          'nada deve ser gravado');
        ASuite.AddResult('TestCidadeSemNome', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCidadeSemNome', False, E.Message);
      end;
    finally
      if LEstadoId > 0 then
        try
          LEstadoService.Excluir(LEstadoId);
        except
        end;
      if LPaisId > 0 then
        try
          LPaisService.Excluir(LPaisId);
        except
        end;
      LCidade.Free;
      LEstado.Free;
      LPais.Free;
    end;
  end;

  procedure TestCidadeSemEstado;
  var
    LCidade: TCidade;
    LDeu: Boolean;
    LNome: string;
  begin
    LNome := 'CIDADE SEM ESTADO ' + LSufixo;
    LCidade := TCidade.Create;
    try
      try
        LCidade.EstadoId := 0;
        LCidade.Nome := LNome;
        LDeu := False;
        try
          LCidadeService.Inserir(LCidade);
        except
          on E: Exception do
            LDeu := True;
        end;
        AssertTrue(LDeu, 'cidade sem estado deve ser recusada');
        AssertEquals('0', IntToStr(ContarPorCampo('CIDADE', 'NOME', LNome)),
          'nada deve ser gravado');
        ASuite.AddResult('TestCidadeSemEstado', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCidadeSemEstado', False, E.Message);
      end;
    finally
      LCidade.Free;
    end;
  end;

  procedure LimparSobraPorSufixo;
  var
    LMascara: string;
  begin
    LMascara := '%' + LSufixo + '%';
    try
      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM CIDADE WHERE NOME LIKE :M';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;
      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM ESTADO WHERE NOME LIKE :M';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;
      LQuery.Close;
      LQuery.SQL.Text := 'DELETE FROM PAIS WHERE NOME LIKE :M';
      LQuery.ParamByName('M').AsString := LMascara;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    except
      { limpeza não pode derrubar a suíte }
    end;
  end;

begin
  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LLista := nil;
  LPaisService := TPaisService.Create;
  LEstadoService := TEstadoService.Create;
  LCidadeService := TCidadeService.Create;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DOS CADASTROS GEOGRAFICOS');
    WriteLn('========================================');

    TestPaisCicloCompleto;
    TestPaisSemNome;
    TestPaisSemCodigo;
    TestPaisBuscarInexistente;
    TestEstadoCicloCompleto;
    TestEstadoUfInvalida;
    TestEstadoSemPais;
    TestEstadoSemNome;
    TestCidadeCicloCompleto;
    TestCidadeSemNome;
    TestCidadeSemEstado;
  finally
    LimparSobraPorSufixo;
    LCidadeService.Free;
    LEstadoService.Free;
    LPaisService.Free;
    LQuery.Free;
  end;
end;

end.
