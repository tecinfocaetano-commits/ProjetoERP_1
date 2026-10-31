unit uTelasAdmTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes das telas de administracao
  ------------------------------------------------------------
  Cobre as telas novas do menu principal (30/10/2026):
    - seed de PERMISSAO das 4 telas (script 013 / 007);
    - TConfiguracaoService: grava (INSERT), atualiza (UPDATE),
      carrega filtrado e exclui, com auditoria - e no fim nada
      sobra (nem chave nem LOG_SISTEMA);
    - TPermissaoService: UPSERT por (GRUPO_ID, MODULO, TELA) sem
      duplicar linha, e limpeza completa do grupo de teste;
    - TCaixaService: leitura de caixa/resumo/movimentos com SALDO
      TIPADO (o CAST evita ftUnknown) e NENHUMA escrita.
  ============================================================ }

interface

uses
  Classes, SysUtils, DB, SQLDB, uAssert, uConexao, uSessao,
  uConfiguracaoService, uPermissaoService, uCaixaService;

type
  { TTelasAdmTest }
  TTelasAdmTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

const
  { 4 telas novas: mesma ordem nos dois arrays }
  ADM_MODULOS: array[0..3] of string = (
    'SISTEMA', 'SISTEMA', 'FINANCEIRO', 'RELATORIOS');
  ADM_TELAS: array[0..3] of string = (
    'CONFIGURACOES', 'PERMISSOES', 'CAIXA', 'CENTRAL_RELATORIOS');

  { chave criada e apagada pelo proprio teste }
  CHAVE_TESTE = 'TESTE_ADM_CHAVE';

{ TTelasAdmTest }

class procedure TTelasAdmTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LSessao: TSessao;

  function TopoDoLog: Int64;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT FIRST 1 ID FROM LOG_SISTEMA ORDER BY ID DESC';
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
  end;

  function QtdLog: Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM LOG_SISTEMA';
    LQuery.Open;
    Result := LQuery.Fields[0].AsLargeInt;
    LQuery.Close;
  end;

  procedure ApagarRastroDoLog(ATopo: Int64; const ATabela: string);
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'DELETE FROM LOG_SISTEMA WHERE TABELA = :T AND ID > :ID';
    LQuery.ParamByName('T').AsString := ATabela;
    LQuery.ParamByName('ID').AsLargeInt := ATopo;
    LQuery.ExecSQL;
    LConexao.Confirmar;
  end;

  { as 4 telas novas estao semeadas (013_telas_administracao / 007) }
  procedure TestSeedPermissoesTelasAdministracao;
  var
    I: Integer;
    LFaltando: string;
  begin
    try
      LFaltando := '';
      for I := Low(ADM_MODULOS) to High(ADM_MODULOS) do
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT COUNT(*) FROM PERMISSAO WHERE GRUPO_ID = :G ' +
          'AND MODULO = :M AND TELA = :T';
        LQuery.ParamByName('G').AsLargeInt := 1;
        LQuery.ParamByName('M').AsString := ADM_MODULOS[I];
        LQuery.ParamByName('T').AsString := ADM_TELAS[I];
        LQuery.Open;
        if LQuery.Fields[0].AsInteger = 0 then
          LFaltando := LFaltando + ADM_MODULOS[I] + '/' + ADM_TELAS[I] + ' ';
        LQuery.Close;
      end;
      AssertEquals('', Trim(LFaltando),
        'seed de PERMISSAO das telas de administracao ausente');
      ASuite.AddResult('TestSeedPermissoesTelasAdministracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSeedPermissoesTelasAdministracao', False, E.Message);
    end;
  end;

  { round-trip do editor de CONFIGURACAO sem deixar rastro }
  procedure TestConfiguracaoServiceGravaEhLimpa;
  var
    LService: TConfiguracaoService;
    LLista: TSQLQuery;
    LTopo, LId: Int64;
    LQtd: Integer;
    LValor: string;
  begin
    LTopo := TopoDoLog;
    LService := TConfiguracaoService.Create;
    LLista := TSQLQuery.Create(nil);
    try
      LLista.DataBase := LConexao.Connection;
      LLista.Transaction := LConexao.Transaction;
      try
        { 1) INSERT }
        LService.Gravar(CHAVE_TESTE, 'VALOR_1', 'chave criada pelo teste');

        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT ID, VALOR FROM CONFIGURACAO WHERE CHAVE = :C ' +
          'AND EMPRESA_ID = :E';
        LQuery.ParamByName('C').AsString := CHAVE_TESTE;
        LQuery.ParamByName('E').AsLargeInt := LSessao.EmpresaId;
        LQuery.Open;
        LQtd := 0;
        LId := 0;
        LValor := '';
        if not LQuery.IsEmpty then
        begin
          LQtd := 1;
          LId := LQuery.FieldByName('ID').AsLargeInt;
          LValor := Trim(LQuery.FieldByName('VALOR').AsString);
        end;
        LQuery.Close;
        AssertEquals('1', IntToStr(LQtd), 'o INSERT deve criar exatamente uma linha');
        AssertEquals('VALOR_1', LValor, 'o INSERT deve gravar o valor');

        { 2) a listagem filtrada enxerga a chave }
        LService.Carregar(LLista, 'TESTE_ADM');
        AssertTrue(LLista.Active, 'Carregar deve abrir a query');
        AssertFalse(LLista.IsEmpty, 'a listagem filtrada deve achar a chave');

        { 3) UPDATE: a mesma chave nao pode virar linha nova }
        LService.Gravar(CHAVE_TESTE, 'VALOR_2', 'chave atualizada pelo teste');
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT COUNT(*) FROM CONFIGURACAO WHERE CHAVE = :C ' +
          'AND EMPRESA_ID = :E';
        LQuery.ParamByName('C').AsString := CHAVE_TESTE;
        LQuery.ParamByName('E').AsLargeInt := LSessao.EmpresaId;
        LQuery.Open;
        LQtd := LQuery.Fields[0].AsInteger;
        LQuery.Close;
        AssertEquals('1', IntToStr(LQtd), 'o UPDATE nao pode duplicar a chave');

        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT VALOR FROM CONFIGURACAO WHERE CHAVE = :C ' +
          'AND EMPRESA_ID = :E';
        LQuery.ParamByName('C').AsString := CHAVE_TESTE;
        LQuery.ParamByName('E').AsLargeInt := LSessao.EmpresaId;
        LQuery.Open;
        LValor := Trim(LQuery.FieldByName('VALOR').AsString);
        LQuery.Close;
        AssertEquals('VALOR_2', LValor, 'o UPDATE deve trocar o valor');

        { 4) EXCLUIR volta ao padrao (linha some) }
        LService.Excluir(LId);
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT COUNT(*) FROM CONFIGURACAO WHERE CHAVE = :C';
        LQuery.ParamByName('C').AsString := CHAVE_TESTE;
        LQuery.Open;
        LQtd := LQuery.Fields[0].AsInteger;
        LQuery.Close;
        AssertEquals('0', IntToStr(LQtd), 'o EXCLUIR deve apagar a chave');

        ASuite.AddResult('TestConfiguracaoServiceGravaEhLimpa', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestConfiguracaoServiceGravaEhLimpa', False, E.Message);
      end;
    finally
      try
        { limpeza: chave que possa ter sobrado + auditoria deste teste }
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM CONFIGURACAO WHERE CHAVE = :C';
        LQuery.ParamByName('C').AsString := CHAVE_TESTE;
        LQuery.ExecSQL;
        LConexao.Confirmar;
        ApagarRastroDoLog(LTopo, 'CONFIGURACAO');
      except
        { limpeza nao pode derrubar a suite }
      end;
      LLista.Free;
      LService.Free;
    end;
  end;

  { UPSERT por (GRUPO, MODULO, TELA) + limpeza total do grupo de teste }
  procedure TestPermissaoServiceFazUpsertSemDuplicar;
  var
    LService: TPermissaoService;
    LLista: TSQLQuery;
    LTopo, LGrupoId, LId1, LId2: Int64;
    LQtd: Integer;
    LCriou1, LCriou2: Boolean;
  begin
    LTopo := TopoDoLog;
    LGrupoId := 0;
    LService := TPermissaoService.Create;
    LLista := TSQLQuery.Create(nil);
    try
      LLista.DataBase := LConexao.Connection;
      LLista.Transaction := LConexao.Transaction;
      try
        { grupo de teste (sem service: o teste cuida do proprio rastro) }
        LQuery.Close;
        LQuery.SQL.Text :=
          'INSERT INTO GRUPO (NOME, DESCRICAO, ATIVO) ' +
          'VALUES (:N, :D, ''A'')';
        LQuery.ParamByName('N').AsString := 'TESTE_ADM_GRUPO';
        LQuery.ParamByName('D').AsString := 'grupo criado pelo teste';
        LQuery.ExecSQL;
        LConexao.Confirmar;

        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT FIRST 1 ID FROM GRUPO WHERE NOME = :N ORDER BY ID DESC';
        LQuery.ParamByName('N').AsString := 'TESTE_ADM_GRUPO';
        LQuery.Open;
        AssertFalse(LQuery.IsEmpty, 'o grupo de teste deve ter sido criado');
        LGrupoId := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;

        { 1) primeira gravacao = linha nova }
        LCriou1 := LService.Gravar(LGrupoId, 'teste_adm', 'tela_teste',
          True, False, True, False, True);
        AssertTrue(LCriou1, 'a primeira gravacao deve criar a linha');

        { 2) gravar de novo = update, nao linha nova }
        LCriou2 := LService.Gravar(LGrupoId, 'TESTE_ADM', 'TELA_TESTE',
          True, True, True, True, False);
        AssertFalse(LCriou2, 'a segunda gravacao deve atualizar a linha');

        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT COUNT(*) FROM PERMISSAO WHERE GRUPO_ID = :G ' +
          'AND UPPER(MODULO) = :M AND UPPER(TELA) = :T';
        LQuery.ParamByName('G').AsLargeInt := LGrupoId;
        LQuery.ParamByName('M').AsString := 'TESTE_ADM';
        LQuery.ParamByName('T').AsString := 'TELA_TESTE';
        LQuery.Open;
        LQtd := LQuery.Fields[0].AsInteger;
        LQuery.Close;
        AssertEquals('1', IntToStr(LQtd), 'o UPSERT nao pode duplicar a linha da matriz');

        { 3) os flags gravados sao os da ultima chamada }
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT ID, PODE_VISUALIZAR, PODE_INSERIR, PODE_IMPRIMIR ' +
          'FROM PERMISSAO WHERE GRUPO_ID = :G AND UPPER(MODULO) = :M';
        LQuery.ParamByName('G').AsLargeInt := LGrupoId;
        LQuery.ParamByName('M').AsString := 'TESTE_ADM';
        LQuery.Open;
        AssertFalse(LQuery.IsEmpty, 'a linha da matriz deve existir');
        LId1 := LQuery.FieldByName('ID').AsLargeInt;
        AssertEquals('S', Trim(LQuery.FieldByName('PODE_VISUALIZAR').AsString),
          'PODE_VISUALIZAR deve ficar S');
        AssertEquals('S', Trim(LQuery.FieldByName('PODE_INSERIR').AsString),
          'PODE_INSERIR deve ficar S');
        AssertEquals('N', Trim(LQuery.FieldByName('PODE_IMPRIMIR').AsString),
          'PODE_IMPRIMIR deve ficar N');
        LQuery.Close;

        { 4) a listagem do grupo mostra a linha }
        LService.CarregarPermissoes(LLista, LGrupoId);
        AssertTrue(LLista.Active, 'CarregarPermissoes deve abrir a query');
        AssertFalse(LLista.IsEmpty, 'a listagem deve trazer a linha criada');

        { 5) EXCLUIR volta ao estado sem a linha }
        LService.Excluir(LId1);
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT COUNT(*) FROM PERMISSAO WHERE GRUPO_ID = :G';
        LQuery.ParamByName('G').AsLargeInt := LGrupoId;
        LQuery.Open;
        LQtd := LQuery.Fields[0].AsInteger;
        LQuery.Close;
        AssertEquals('0', IntToStr(LQtd), 'o EXCLUIR deve apagar a linha da matriz');

        { id da linha nao pode ser reaproveitado sem querer }
        LId2 := 0;
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT COUNT(*) FROM PERMISSAO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LId1;
        LQuery.Open;
        LId2 := LQuery.Fields[0].AsLargeInt;
        LQuery.Close;
        AssertEquals('0', IntToStr(LId2), 'a linha excluida nao pode mais existir');

        ASuite.AddResult('TestPermissaoServiceFazUpsertSemDuplicar', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestPermissaoServiceFazUpsertSemDuplicar', False, E.Message);
      end;
    finally
      try
        if LGrupoId > 0 then
        begin
          LQuery.Close;
          LQuery.SQL.Text := 'DELETE FROM PERMISSAO WHERE GRUPO_ID = :G';
          LQuery.ParamByName('G').AsLargeInt := LGrupoId;
          LQuery.ExecSQL;
          LQuery.Close;
          LQuery.SQL.Text := 'DELETE FROM GRUPO WHERE ID = :ID';
          LQuery.ParamByName('ID').AsLargeInt := LGrupoId;
          LQuery.ExecSQL;
          LConexao.Confirmar;
        end;
        ApagarRastroDoLog(LTopo, 'PERMISSAO');
      except
        { limpeza nao pode derrubar a suite }
      end;
      LLista.Free;
      LService.Free;
    end;
  end;

  { leitura de caixa: SALDO tipado (CAST) e nenhuma escrita }
  procedure TestCaixaServiceLeSemGravar;
  var
    LService: TCaixaService;
    LLista, LResumo, LMovs: TSQLQuery;
    LTopoAntes, LTopoDepois, LCaixaId: Int64;
  begin
    LTopoAntes := QtdLog;
    LCaixaId := 0;
    LService := TCaixaService.Create;
    LLista := TSQLQuery.Create(nil);
    LResumo := TSQLQuery.Create(nil);
    LMovs := TSQLQuery.Create(nil);
    try
      LLista.DataBase := LConexao.Connection;
      LLista.Transaction := LConexao.Transaction;
      LResumo.DataBase := LConexao.Connection;
      LResumo.Transaction := LConexao.Transaction;
      LMovs.DataBase := LConexao.Connection;
      LMovs.Transaction := LConexao.Transaction;
      try
        LService.CarregarCaixas(LLista);
        AssertTrue(LLista.Active, 'CarregarCaixas deve abrir a query');
        AssertTrue(LLista.FindField('SALDO') <> nil,
          'a listagem de caixas deve trazer SALDO');

        { o CAST do COALESCE((subconsulta),0) e o que evita ftUnknown }
        AssertTrue(LLista.FindField('SALDO').DataType <> ftUnknown,
          'SALDO da listagem deve vir tipado (CAST numeric), nao ftUnknown');

        if not LLista.IsEmpty then
        begin
          LCaixaId := LLista.FieldByName('ID').AsLargeInt;

          LService.CarregarResumo(LResumo, LCaixaId);
          AssertTrue(LResumo.Active, 'CarregarResumo deve abrir a query');
          AssertTrue(LResumo.FieldByName('SALDO').DataType <> ftUnknown,
            'SALDO do resumo deve vir tipado (CAST numeric)');
          AssertTrue(LResumo.FieldByName('ENTRADAS').DataType <> ftUnknown,
            'ENTRADAS do resumo deve vir tipado (CAST numeric)');
          AssertTrue(LResumo.FieldByName('SAIDAS').DataType <> ftUnknown,
            'SAIDAS do resumo deve vir tipado (CAST numeric)');
          { leitura numerica de verdade }
          AssertTrue(LResumo.FieldByName('SALDO').AsFloat >= 0,
            'SALDO do resumo deve ser lido como numero');

          LService.CarregarMovimentos(LMovs, LCaixaId);
          AssertTrue(LMovs.Active, 'CarregarMovimentos deve abrir a query');
          AssertTrue(LMovs.FindField('TIPO') <> nil,
            'os movimentos devem trazer o TIPO legivel');
        end;

        { somente leitura: nenhum LOG_SISTEMA novo }
        LTopoDepois := QtdLog;
        AssertEquals(IntToStr(LTopoAntes), IntToStr(LTopoDepois),
          'a consulta de caixa nao pode gravar auditoria');

        ASuite.AddResult('TestCaixaServiceLeSemGravar', True, '');
      except
        on E: Exception do
          ASuite.AddResult('TestCaixaServiceLeSemGravar', False, E.Message);
      end;
    finally
      LLista.Free;
      LResumo.Free;
      LMovs.Free;
      LService.Free;
    end;
  end;

begin
  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LSessao := TSessao.GetInstance;

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DAS TELAS DE ADMINISTRACAO');
    WriteLn('========================================');

    TestSeedPermissoesTelasAdministracao;
    TestConfiguracaoServiceGravaEhLimpa;
    TestPermissaoServiceFazUpsertSemDuplicar;
    TestCaixaServiceLeSemGravar;
  finally
    LQuery.Free;
  end;
end;

end.
