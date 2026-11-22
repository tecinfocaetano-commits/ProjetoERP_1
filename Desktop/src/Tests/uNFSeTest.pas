unit uNFSeTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes da NFS-e Nacional (marco 3.92)
  ------------------------------------------------------------
  Cobre TNFSeHelper e TNotaSaidaServicoService SEM ACBr:

    - preferências NFSE_* e padrões (SIMULADO/homologação);
    - geração da DPS 1.01 em modo desenvolvedor (sem certificado);
    - recusa de código de serviço inválido;
    - retenções ISS/PIS/COFINS/INSS no XML;
    - dedupe por série/número e ID_DPS único;
    - nenhuma baixa de estoque e nenhuma conta a receber;
    - recusa de NFSE_MODO=REAL sem certificado;
    - validação estrutural e cancelamento.

  Padrão da suíte: sufixo de timestamp, limpeza explícita no
  finally e restauro de todas as preferências alteradas.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao,
  uTNFSeHelper, uNotaSaidaServicoService, uConfiguracaoService;

type
  TNFSeTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

class procedure TNFSeTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LConfig: TConfiguracaoService;
  LService: TNotaSaidaServicoService;
  LHelper: TNFSeHelper;
  LIds: array of Int64;
  LArqs: array of string;
  LOldIM, LOldModo: string;
  LSufixo: string;
  LSeq: Integer;

  procedure Registrar(const ANome: string);
  begin
    ASuite.AddResult(ANome, True, '');
  end;

  procedure Falha(const ANome, AMensagem: string);
  begin
    ASuite.AddResult(ANome, False, AMensagem);
  end;

  function NovoValor(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  procedure Guardar(AId: Int64);
  begin
    SetLength(LIds, Length(LIds) + 1);
    LIds[High(LIds)] := AId;
  end;

  function QtdSql(const ASQL: string): Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function TextoSql(const ASQL: string): string;
  begin
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.Open;
    if LQuery.IsEmpty then
      Result := ''
    else
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function CampoNota(AId: Int64; const ACampo: string): string;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(500)) AS VALOR ' +
      'FROM NOTA_SAIDA_SERVICO WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Result := ''
    else
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function CriarNota(ACodigo: string; AValor: Double): Int64;
  begin
    Result := LService.Criar('3550308', ACodigo, NovoValor('SERVICO NFS-E'),
      AValor, 0, 2, '1', 0, 0, 0, 0);
    Guardar(Result);
  end;

  function Gerar(AId: Int64; out AXml, AArquivo, AMsg: string): Boolean;
  begin
    Result := LService.GerarXML(AId, '', AXml, AArquivo, AMsg);
    if AArquivo <> '' then
    begin
      SetLength(LArqs, Length(LArqs) + 1);
      LArqs[High(LArqs)] := AArquivo;
    end;
  end;

  // ------------------------------------------------------------------
  // Testes
  // ------------------------------------------------------------------

  procedure TestConfigPadrao;
  begin
    try
      LHelper.CarregarConfiguracao;
      AssertEquals('SIMULADO', LHelper.Modo, 'modo padrao');
      AssertEquals('2', LHelper.Ambiente, 'ambiente padrao');
      AssertEquals('1', LHelper.Serie, 'serie padrao');
      AssertEquals('1.01', LHelper.Versao, 'versao dos schemas');
      AssertEquals('NACIONAL', LHelper.Provedor, 'provedor padrao');
      AssertTrue(Pos('DPS_v1.01.xsd', LHelper.CaminhoSchema) > 0,
        'caminho do XSD oficial');
      Registrar('TestNFSeConfigPadrao');
    except
      on E: Exception do Falha('TestNFSeConfigPadrao', E.Message);
    end;
  end;

  procedure TestGerarDPSModoTeste;
  var
    LId: Int64;
    LXml, LArquivo, LMsg, LIdDps: string;
  begin
    try
      LId := CriarNota('010101', 100);
      AssertTrue(Gerar(LId, LXml, LArquivo, LMsg), LMsg);
      AssertTrue(Pos('versao="1.01"', LXml) > 0, 'versao no XML');
      AssertTrue(Pos('xmlns="http://www.sped.fazenda.gov.br/nfse"', LXml) > 0,
        'namespace nacional');
      AssertTrue(Pos('<vServ>100.00</vServ>', LXml) > 0, 'valor do servico');
      AssertTrue(Pos('<tpRetISSQN>1</tpRetISSQN>', LXml) > 0, 'sem retencao ISS');
      AssertTrue(Pos('<Signature', LXml) = 0, 'simulado nao assina');
      AssertTrue(FileExists(LArquivo), 'arquivo XML gravado');
      AssertEquals('VALIDADA', CampoNota(LId, 'SITUACAO'), 'situacao apos gerar');
      LIdDps := CampoNota(LId, 'ID_DPS');
      AssertEquals('45', IntToStr(Length(LIdDps)), 'tamanho do ID_DPS');
      AssertTrue(Pos('DPS', LIdDps) = 1, 'prefixo do ID_DPS');
      Registrar('TestNFSeGerarDPSModoTeste');
    except
      on E: Exception do Falha('TestNFSeGerarDPSModoTeste', E.Message);
    end;
  end;

  procedure TestRecusaSemCodigoServico;
  var
    LRecusou: Boolean;
  begin
    try
      LRecusou := False;
      try
        LService.Criar('3550308', '123', 'SEM CODIGO', 10, 0, 0, '1', 0, 0, 0, 0);
      except
        on E: ENotaSaidaServico do LRecusou := True;
      end;
      AssertTrue(LRecusou, 'codigo de servico invalido deve ser recusado');
      Registrar('TestNFSeRecusaSemCodigoServico');
    except
      on E: Exception do Falha('TestNFSeRecusaSemCodigoServico', E.Message);
    end;
  end;

  procedure TestRetencoesNoXml;
  var
    LId: Int64;
    LXml, LArquivo, LMsg: string;
  begin
    try
      LId := LService.Criar('3550308', '010101', NovoValor('SERVICO RETENCAO'),
        200, 20, 5, '2', 0, 1.5, 3, 12);
      Guardar(LId);
      AssertTrue(Gerar(LId, LXml, LArquivo, LMsg), LMsg);
      AssertTrue(Pos('<vServ>180.00</vServ>', LXml) > 0, 'valor com desconto');
      AssertTrue(Pos('<vDescIncond>20.00</vDescIncond>', LXml) > 0, 'desconto');
      AssertTrue(Pos('<tpRetISSQN>2</tpRetISSQN>', LXml) > 0, 'ISS retido');
      AssertTrue(Pos('<vPis>1.50</vPis>', LXml) > 0, 'retencao PIS');
      AssertTrue(Pos('<vCofins>3.00</vCofins>', LXml) > 0, 'retencao COFINS');
      AssertTrue(Pos('<vRetCP>12.00</vRetCP>', LXml) > 0, 'retencao INSS/CP');
      Registrar('TestNFSeRetencoesNoXml');
    except
      on E: Exception do Falha('TestNFSeRetencoesNoXml', E.Message);
    end;
  end;

  procedure TestDedupeSequencia;
  var
    LId1, LId2: Int64;
    LXml, LArquivo, LMsg, LChave1, LChave2: string;
  begin
    try
      LId1 := CriarNota('010101', 50);
      LId2 := CriarNota('010102', 70);
      AssertTrue(Gerar(LId1, LXml, LArquivo, LMsg), LMsg);
      LChave1 := CampoNota(LId1, 'ID_DPS');
      AssertTrue(Gerar(LId2, LXml, LArquivo, LMsg), LMsg);
      LChave2 := CampoNota(LId2, 'ID_DPS');
      AssertTrue(LChave1 <> LChave2, 'IDs de DPS devem ser diferentes');
      AssertTrue(CampoNota(LId2, 'NUMERO') <> CampoNota(LId1, 'NUMERO'),
        'numeracao sequencial por serie');
      AssertEquals('1', IntToStr(QtdSql(
        'SELECT COUNT(*) FROM NOTA_SAIDA_SERVICO WHERE ID = ' + IntToStr(LId1))),
        'gerar nao duplica registro');
      AssertEquals('2', IntToStr(QtdSql(
        'SELECT COUNT(DISTINCT ID_DPS) FROM NOTA_SAIDA_SERVICO ' +
        'WHERE ID IN (' + IntToStr(LId1) + ',' + IntToStr(LId2) + ')')),
        'ID_DPS distinto por nota');
      Registrar('TestNFSeDedupeSequencia');
    except
      on E: Exception do Falha('TestNFSeDedupeSequencia', E.Message);
    end;
  end;

  procedure TestSemEstoqueFinanceiro;
  var
    LId: Int64;
    LEstoque, LContas, LEstoqueDepois, LContasDepois: Integer;
    LXml, LArquivo, LMsg: string;
  begin
    try
      LEstoque := QtdSql('SELECT COUNT(*) FROM MOVIMENTO_ESTOQUE');
      LContas := QtdSql('SELECT COUNT(*) FROM CONTA_RECEBER');
      LId := CriarNota('010101', 90);
      AssertTrue(Gerar(LId, LXml, LArquivo, LMsg), LMsg);
      LEstoqueDepois := QtdSql('SELECT COUNT(*) FROM MOVIMENTO_ESTOQUE');
      LContasDepois := QtdSql('SELECT COUNT(*) FROM CONTA_RECEBER');
      AssertEquals(IntToStr(LEstoque), IntToStr(LEstoqueDepois),
        'servico nao mexe estoque');
      AssertEquals(IntToStr(LContas), IntToStr(LContasDepois),
        'servico nao cria conta a receber');
      Registrar('TestNFSeSemEstoqueFinanceiro');
    except
      on E: Exception do Falha('TestNFSeSemEstoqueFinanceiro', E.Message);
    end;
  end;

  procedure TestValidacaoEstrutural;
  var
    LMsg: string;
  begin
    try
      AssertFalse(LHelper.ValidarDPS('<DPS/>', LMsg), 'XML invalido recusado');
      AssertTrue(LMsg <> '', 'mensagem de erro preenchida');
      Registrar('TestNFSeValidacaoEstrutural');
    except
      on E: Exception do Falha('TestNFSeValidacaoEstrutural', E.Message);
    end;
  end;

  procedure TestModoRealSemCertificado;
  var
    LDados: TNFSeDados;
    LXml, LMsg, LErro: string;
    LRecusou: Boolean;
  begin
    try
      LOldModo := LConfig.LerValor('NFSE_MODO');
      LConfig.Gravar('NFSE_MODO', 'REAL', 'teste 3.92');
      LHelper.CarregarConfiguracao;
      LDados := Default(TNFSeDados);
      LDados.Numero := 999;
      LDados.Serie := '1';
      LDados.MunicipioIBGE := '3550308';
      LDados.CodigoServico := '010101';
      LDados.DescricaoServico := 'TESTE REAL SEM CERTIFICADO';
      LDados.ValorServico := 10;
      LDados.AliquotaISS := 2;
      LDados.TipoRetencaoISS := '1';
      LDados.DataEmissao := Now;
      LDados.DataCompetencia := Date;
      LErro := '';
      LRecusou := False;
      try
        LHelper.GerarDPS(LDados, '', LXml, LMsg);
      except
        on E: Exception do
        begin
          LErro := E.Message;
          LRecusou := (Pos('certificado', LowerCase(LErro)) > 0) or
            (Pos('acbr', LowerCase(LErro)) > 0);
        end;
      end;
      AssertTrue(LRecusou, 'REAL sem certificado deve ser recusado: ' + LErro);
      Registrar('TestNFSeModoRealSemCertificado');
    except
      on E: Exception do Falha('TestNFSeModoRealSemCertificado', E.Message);
    end;
  end;

  procedure TestCancelar;
  var
    LId: Int64;
    LXml, LArquivo, LMsg: string;
    LRecusou: Boolean;
  begin
    try
      LId := CriarNota('010101', 30);
      AssertTrue(LService.Cancelar(LId, 'teste de cancelamento'), 'cancelou');
      AssertEquals('CANCELADA', CampoNota(LId, 'SITUACAO'), 'situacao cancelada');
      LRecusou := False;
      try
        Gerar(LId, LXml, LArquivo, LMsg);
      except
        on E: ENotaSaidaServico do LRecusou := True;
      end;
      AssertTrue(LRecusou, 'nota cancelada nao gera XML');
      Registrar('TestNFSeCancelar');
    except
      on E: Exception do Falha('TestNFSeCancelar', E.Message);
    end;
  end;

var
  I: Integer;
begin
  LConexao := TConexao.GetInstance;
  LSessao := TSessao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  LConfig := TConfiguracaoService.Create;
  LService := TNotaSaidaServicoService.Create;
  LHelper := TNFSeHelper.Create;
  SetLength(LIds, 0);
  SetLength(LArqs, 0);
  LSeq := 0;
  LSufixo := FormatDateTime('yyyymmddhhnnss', Now);

  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    LOldIM := LConfig.LerValor('NFSE_INSCRICAO_MUNICIPAL');
    LOldModo := LConfig.LerValor('NFSE_MODO');
    LConfig.Gravar('NFSE_INSCRICAO_MUNICIPAL', '123456', 'teste 3.92');
    LConfig.Gravar('NFSE_MODO', 'SIMULADO', 'teste 3.92');
    LHelper.CarregarConfiguracao;

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DA NFS-e NACIONAL');
    WriteLn('========================================');

    TestConfigPadrao;
    TestGerarDPSModoTeste;
    TestRecusaSemCodigoServico;
    TestRetencoesNoXml;
    TestDedupeSequencia;
    TestSemEstoqueFinanceiro;
    TestValidacaoEstrutural;
    TestModoRealSemCertificado;
    TestCancelar;
  finally
    for I := 0 to High(LIds) do
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'DELETE FROM NOTA_SAIDA_SERVICO WHERE ID = :ID AND EMPRESA_ID = :EMP';
      LQuery.ParamByName('ID').AsLargeInt := LIds[I];
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ExecSQL;
      LConexao.Confirmar;
    end;
    for I := 0 to High(LArqs) do
      if LArqs[I] <> '' then
        DeleteFile(LArqs[I]);
    LConfig.Gravar('NFSE_INSCRICAO_MUNICIPAL', LOldIM, 'restauro teste 3.92');
    LConfig.Gravar('NFSE_MODO', LOldModo, 'restauro teste 3.92');
    LHelper.CarregarConfiguracao;
    LHelper.Free;
    LService.Free;
    LConfig.Free;
    LQuery.Free;
  end;
end;

end.
