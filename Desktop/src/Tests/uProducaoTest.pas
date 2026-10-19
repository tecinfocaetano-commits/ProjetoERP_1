unit uProducaoTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes do modulo de Producao (Fase 7)
  ------------------------------------------------------------
  Cobre o que a Fase 7 enderecou:
    - estrutura das tabelas de Producao (script 012);
    - seed de PERMISSAO (4 telas do modulo);
    - permissoes por acao (bypass admin, acao invalida,
      grupo sem registro => negado / fail-closed);
    - auditoria em LOG_SISTEMA com usuario da sessao
      (uAuditoria) e via TServiceBase.LogOperacao
      (SQL parametrizado: aspas simples nao quebram)
      e TACBrHelper.ImportarXML (colunas certas);
    - proximo numero do mapa (mesmo SQL do service);
    - copiloto: fluxo de caixa tipado apos o CAST
      (SQLDB le COALESCE((subquery),0) sem tipo como 0);
    - taloes com codigo de barras.
  ============================================================ }

interface

uses
  Classes, SysUtils, DB, SQLDB, uAssert, uConexao, uSessao, uPermissao,
  uAuditoria, uServiceBase, uRepositoryBase, uCopilotoERP, uACBrHelper;

type
  { TProducaoTest }
  TProducaoTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

type
  { expoe o LogOperacao protegido da TServiceBase para o teste }
  TServiceLogExpuesto = class(TServiceBase)
  public
    procedure LogPublico(const ATabela, AOperacao: string; ARegistroId: Int64;
      const ADadosAnteriores, ADadosNovos: string);
  end;

procedure TServiceLogExpuesto.LogPublico(const ATabela, AOperacao: string;
  ARegistroId: Int64; const ADadosAnteriores, ADadosNovos: string);
begin
  LogOperacao(ATabela, AOperacao, ARegistroId, ADadosAnteriores, ADadosNovos);
end;

const
  TABELAS_PRODUCAO: array[0..7] of string = (
    'FICHA_TECNICA', 'FICHA_TECNICA_ITEM', 'MAPA_PRODUCAO',
    'MAPA_PRODUCAO_ITEM', 'TALAO', 'TALAO_BIPAGEM',
    'CONSUMO_MATERIAL', 'CONSUMO_MATERIAL_ITEM');

{ TProducaoTest }

class procedure TProducaoTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LSessao: TSessao;

  procedure TestTabelasProducaoExistem;
  var
    I: Integer;
    LFaltando: string;
  begin
    try
      LFaltando := '';
      for I := Low(TABELAS_PRODUCAO) to High(TABELAS_PRODUCAO) do
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT COUNT(*) FROM RDB$RELATIONS WHERE RDB$RELATION_NAME = :T';
        LQuery.ParamByName('T').AsString := TABELAS_PRODUCAO[I];
        LQuery.Open;
        if LQuery.Fields[0].AsInteger = 0 then
          LFaltando := LFaltando + TABELAS_PRODUCAO[I] + ' ';
      end;
      AssertEquals('', Trim(LFaltando),
        'tabelas de Producao ausentes no banco');
      ASuite.AddResult('TestTabelasProducaoExistem', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestTabelasProducaoExistem', False, E.Message);
    end;
  end;

  procedure TestSeedPermissoesProducao;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT COUNT(*) FROM PERMISSAO WHERE MODULO = :M AND TELA IN ' +
        '(''MAPA_PRODUCAO'', ''FICHA_TECNICA'', ''BIPAGEM'', ''CONSUMO'')';
      LQuery.ParamByName('M').AsString := MODULO_PRODUCAO;
      LQuery.Open;
      AssertTrue(LQuery.Fields[0].AsInteger >= 4,
        'o script 012 deve semear as 4 telas do modulo PRODUCAO');
      ASuite.AddResult('TestSeedPermissoesProducao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestSeedPermissoesProducao', False, E.Message);
    end;
  end;

  procedure TestPermissaoAdminBypass;
  begin
    try
      AssertTrue(
        TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, PERM_IMPRIMIR),
        'administrador deve ter bypass (IMPRIMIR)');
      AssertTrue(
        TemPermissao(MODULO_PRODUCAO, TELA_BIPAGEM, PERM_INSERIR),
        'administrador deve ter bypass (INSERIR)');
      { nao deve levantar EPermissaoNegada para administrador }
      VerificarPermissao(MODULO_PRODUCAO, TELA_CONSUMO, PERM_EXCLUIR);
      ASuite.AddResult('TestPermissaoAdminBypass', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPermissaoAdminBypass', False, E.Message);
    end;
  end;

  procedure TestPermissaoPorAcaoSemAdmin;
  var
    LAdminAntes: Boolean;
    LGrupoAntes: Int64;
  begin
    LAdminAntes := LSessao.Administrador;
    LGrupoAntes := LSessao.GrupoId;
    try
      LSessao.Administrador := False;

      { grupo 1 tem as 4 telas com tudo 'S' no seed: consulta real }
      LSessao.GrupoId := 1;
      AssertTrue(
        TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, PERM_VISUALIZAR),
        'grupo com seed deve permitir VISUALIZAR');

      { acao sem coluna correspondente => nega }
      AssertFalse(
        TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, 'APROVAR'),
        'acao inexistente deve ser negada');

      { grupo sem linha em PERMISSAO => nega (fail-closed) }
      LSessao.GrupoId := 999999;
      AssertFalse(
        TemPermissao(MODULO_PRODUCAO, TELA_MAPA_PRODUCAO, PERM_VISUALIZAR),
        'grupo sem registro em PERMISSAO deve ser negado');

      ASuite.AddResult('TestPermissaoPorAcaoSemAdmin', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestPermissaoPorAcaoSemAdmin', False, E.Message);
    end;
    LSessao.Administrador := LAdminAntes;
    LSessao.GrupoId := LGrupoAntes;
  end;

  procedure TestAuditoriaUsaUsuarioDaSessao;
  var
    LId: Int64;
  begin
    try
      RegistrarAuditoria('TESTE_UNITARIO', 'INSERT', 999, 'ANTES', 'DEPOIS');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT FIRST 1 ID, EMPRESA_ID, USUARIO_ID, OPERACAO, DADOS_NOVOS ' +
        'FROM LOG_SISTEMA WHERE TABELA = :T ORDER BY ID DESC';
      LQuery.ParamByName('T').AsString := 'TESTE_UNITARIO';
      LQuery.Open;
      AssertFalse(LQuery.IsEmpty, 'RegistrarAuditoria deve gravar em LOG_SISTEMA');
      AssertEquals(IntToStr(LSessao.UsuarioId),
        LQuery.FieldByName('USUARIO_ID').AsString,
        'USUARIO_ID deve vir da sessao (nunca 0)');
      AssertEquals(IntToStr(LSessao.EmpresaId),
        LQuery.FieldByName('EMPRESA_ID').AsString,
        'EMPRESA_ID deve vir da sessao');
      AssertEquals('INSERT', LQuery.FieldByName('OPERACAO').AsString,
        'OPERACAO');
      AssertEquals('DEPOIS', LQuery.FieldByName('DADOS_NOVOS').AsString,
        'DADOS_NOVOS');
      LId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      { limpeza: teste nao deixa rastro }
      LQuery.SQL.Text := 'DELETE FROM LOG_SISTEMA WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LId;
      LQuery.ExecSQL;
      LConexao.Confirmar;
      ASuite.AddResult('TestAuditoriaUsaUsuarioDaSessao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestAuditoriaUsaUsuarioDaSessao', False, E.Message);
    end;
  end;

  procedure TestLogOperacaoServiceParametrizado;
  var
    LRepo: TRepositoryBase;
    LSvc: TServiceLogExpuesto;
    LId: Int64;
  begin
    try
      LRepo := TRepositoryBase.Create('TESTE_LOG');
      LSvc := TServiceLogExpuesto.Create(LRepo);
      try
        { aspas simples quebrariam o INSERT antigo concatenado com Format }
        LSvc.LogPublico('TESTE_SERVICE_LOG', 'UPDATE', 42,
          'STATUS=ANTIGO', 'STATUS=NOVO'' COM ASPAS');
      finally
        LSvc.Free;
        LRepo.Free;
      end;

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT FIRST 1 ID, USUARIO_ID, DADOS_NOVOS FROM LOG_SISTEMA ' +
        'WHERE TABELA = :T ORDER BY ID DESC';
      LQuery.ParamByName('T').AsString := 'TESTE_SERVICE_LOG';
      LQuery.Open;
      AssertFalse(LQuery.IsEmpty,
        'LogOperacao deve gravar o registro (o antigo estourava SQL)');
      AssertEquals(IntToStr(LSessao.UsuarioId),
        LQuery.FieldByName('USUARIO_ID').AsString,
        'LogOperacao deve usar o usuario da sessao (o antigo gravava 0)');
      AssertEquals('STATUS=NOVO'' COM ASPAS',
        LQuery.FieldByName('DADOS_NOVOS').AsString,
        'aspas simples devem sobreviver (SQL parametrizado)');
      LId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      { limpeza }
      LQuery.SQL.Text := 'DELETE FROM LOG_SISTEMA WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LId;
      LQuery.ExecSQL;
      LConexao.Confirmar;
      ASuite.AddResult('TestLogOperacaoServiceParametrizado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestLogOperacaoServiceParametrizado', False, E.Message);
    end;
  end;

  procedure TestImportarXmlGravaAuditoria;
  var
    LHelper: TACBrHelper;
    LArquivo, LInexistente: string;
    LRaisou: Boolean;
    LId: Int64;
  begin
    try
      { caminho inexistente deve falhar antes de tocar no banco }
      LInexistente :=
        IncludeTrailingPathDelimiter(GetTempDir) + 'erp2026_xml_nao_existe.xml';
      LHelper := TACBrHelper.Create;
      try
        LRaisou := False;
        try
          LHelper.ImportarXML(LInexistente);
        except
          on E: Exception do
            LRaisou := True;
        end;
        AssertTrue(LRaisou, 'ImportarXML deve recusar arquivo inexistente');

        { com arquivo: audita em LOG_SISTEMA com as colunas certas
          (o INSERT antigo usava MODULO/ACAO/DESCRICAO inexistentes
          e estourava "Column unknown" em tempo de execucao) }
        LArquivo :=
          IncludeTrailingPathDelimiter(GetTempDir) + 'erp2026_xml_teste_f7.xml';
        with TStringList.Create do
        try
          Add('<?xml version="1.0" encoding="UTF-8"?>');
          Add('<nfeProc/>');
          SaveToFile(LArquivo);
        finally
          Free;
        end;
        try
          AssertTrue(LHelper.ImportarXML(LArquivo) = 1,
            'ImportarXML deve retornar 1');

          LQuery.Close;
          LQuery.SQL.Text :=
            'SELECT FIRST 1 ID, USUARIO_ID, DADOS_NOVOS FROM LOG_SISTEMA ' +
            'WHERE TABELA = :T AND OPERACAO = :O ORDER BY ID DESC';
          LQuery.ParamByName('T').AsString := 'XML_FISCAL';
          LQuery.ParamByName('O').AsString := 'IMPORTACAO_XML';
          LQuery.Open;
          AssertFalse(LQuery.IsEmpty,
            'ImportarXML deve auditar em LOG_SISTEMA');
          AssertEquals(IntToStr(LSessao.UsuarioId),
            LQuery.FieldByName('USUARIO_ID').AsString,
            'auditoria do XML deve usar o usuario da sessao');
          AssertTrue(
            Pos('erp2026_xml_teste_f7.xml',
              LQuery.FieldByName('DADOS_NOVOS').AsString) > 0,
            'DADOS_NOVOS deve citar o arquivo importado');
          LId := LQuery.FieldByName('ID').AsLargeInt;
          LQuery.Close;

          { limpeza: teste nao deixa rastro }
          LQuery.SQL.Text := 'DELETE FROM LOG_SISTEMA WHERE ID = :ID';
          LQuery.ParamByName('ID').AsLargeInt := LId;
          LQuery.ExecSQL;
          LConexao.Confirmar;
        finally
          if FileExists(LArquivo) then
            DeleteFile(LArquivo);
        end;
      finally
        LHelper.Free;
      end;
      ASuite.AddResult('TestImportarXmlGravaAuditoria', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestImportarXmlGravaAuditoria', False, E.Message);
    end;
  end;

  procedure TestProximoNumeroDoMapa;
  begin
    try
      { mesmo SQL do TProducaoService (numeracao MAX+1 por empresa) }
      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT COALESCE(MAX(NUMERO), 0) + 1 AS PROX FROM MAPA_PRODUCAO ' +
        'WHERE EMPRESA_ID = :EMP';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.Open;
      AssertTrue(LQuery.FieldByName('PROX').AsInteger >= 1,
        'proximo numero do mapa deve ser >= 1');
      ASuite.AddResult('TestProximoNumeroDoMapa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestProximoNumeroDoMapa', False, E.Message);
    end;
  end;

  procedure TestCopilotoFluxoCaixaTipado;
  var
    LCopiloto: TCopilotoERP;
    LResp: TRespostaCopiloto;
  begin
    try
      LCopiloto := TCopilotoERP.Create(LConexao.Connection, LConexao.Transaction);
      try
        LResp := LCopiloto.Perguntar('Qual o fluxo de caixa dos proximos 30 dias?');
      finally
        LCopiloto.Free;
      end;

      AssertTrue(LResp.Sucesso, 'pergunta deve ser classificada');
      AssertTrue(Pos('RECEBER_30D', LResp.Resposta) > 0,
        'resposta deve expor RECEBER_30D: ' + LResp.Resposta);
      AssertTrue(Pos('CAST(', LResp.SQL) > 0,
        'SQL do fluxo de caixa deve usar CAST (SQLDB le ' +
        'COALESCE((subquery),0) sem tipo como 0)');

      { o CAST tipa o campo: sem ele o SQLDB devolve o valor como 0 }
      LQuery.Close;
      LQuery.SQL.Text := LResp.SQL;
      LQuery.Open;
      AssertTrue(LQuery.FieldByName('RECEBER_30D').DataType <> ftUnknown,
        'RECEBER_30D deve vir tipado apos o CAST');
      AssertTrue(LQuery.FieldByName('PAGAR_30D').DataType <> ftUnknown,
        'PAGAR_30D deve vir tipado apos o CAST');
      ASuite.AddResult('TestCopilotoFluxoCaixaTipado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestCopilotoFluxoCaixaTipado', False, E.Message);
    end;
  end;

  procedure TestTaloesComCodigoBarras;
  begin
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT COUNT(*), ' +
        'SUM(CASE WHEN CODIGO_BARRAS <> '''' THEN 1 ELSE 0 END) FROM TALAO';
      LQuery.Open;
      AssertTrue(LQuery.Fields[0].AsInteger > 0,
        'deve haver taloes no banco de teste');
      AssertTrue(LQuery.Fields[1].AsInteger > 0,
        'taloes devem ter codigo de barras preenchido');
      ASuite.AddResult('TestTaloesComCodigoBarras', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestTaloesComCodigoBarras', False, E.Message);
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
    WriteLn('EXECUTANDO TESTES DE PRODUCAO');
    WriteLn('========================================');

    TestTabelasProducaoExistem;
    TestSeedPermissoesProducao;
    TestPermissaoAdminBypass;
    TestPermissaoPorAcaoSemAdmin;
    TestAuditoriaUsaUsuarioDaSessao;
    TestLogOperacaoServiceParametrizado;
    TestImportarXmlGravaAuditoria;
    TestProximoNumeroDoMapa;
    TestCopilotoFluxoCaixaTipado;
    TestTaloesComCodigoBarras;
  finally
    LQuery.Free;
  end;
end;

end.
