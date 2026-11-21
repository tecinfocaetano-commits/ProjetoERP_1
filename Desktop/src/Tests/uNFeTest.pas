unit uNFeTest;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Testes da NF-e (ACBrHelper)
  ------------------------------------------------------------
  Cobre TACBrHelper (uACBrHelper), que concentra as regras da
  tela uFrmNFe:

    - configuração: certificado, senha, UF e ambiente (padrão
      homologação/'SP');
    - emissão simulada (sem ACBr instalado): exige certificado e
      senha, só aceita pedido da empresa da sessão, calcula o
      próximo NUMERO_NFE por empresa, grava NUMERO_NFE/CHAVE_NFE
      no pedido e audita em LOG_SISTEMA;
    - numeração: MAX(NUMERO_NFE) da empresa da sessão + 1,
      ignorando outras empresas;
    - NFC-e: mesma emissão com natureza "VENDA AO CONSUMIDOR";
    - consulta: exige configuração e devolve a chave informada;
    - cancelamento: justificativa de no mínimo 15 caracteres;
    - manifestação: exige configuração (simulação devolve False).

  Padrão da suíte: dados com sufixo de timestamp, limpeza
  explícita no finally e nenhum mock de banco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao, uACBrHelper,
  uNFeXmlService, uConfiguracaoService, uImportacaoXmlMapService;

type
  { TNFeTest }
  TNFeTest = class
  public
    class procedure RunAllTests(ASuite: TTestSuite);
  end;

implementation

{ TNFeTest }

class procedure TNFeTest.RunAllTests(ASuite: TTestSuite);
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LHelper: TACBrHelper;
  LSufixo: string;
  LSeq: Integer;
  LTopoLog: Int64;
  LCliente: Int64;
  LClienteOutraEmpresa: Int64;
  LCertificado: string;

  function NovoNome(const APrefixo: string): string;
  begin
    Inc(LSeq);
    Result := APrefixo + ' ' + LSufixo + '-' + IntToStr(LSeq);
  end;

  function NovoDocumento: string;
  begin
    Inc(LSeq);
    Result := Copy(LSufixo, 1, 14) + IntToStr(LSeq);
  end;

  function NovoNumeroPedido: string;
  begin
    Inc(LSeq);
    Result := 'NFE' + Copy(LSufixo, 1, 10) + '-' + IntToStr(LSeq);
  end;

  // ------------------------------------------------------------------
  // Helpers de banco
  // ------------------------------------------------------------------

  function CriarPessoa(const ANome: string; AEmpresaId: Int64): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, ' +
      '  ATIVO, DATA_CADASTRO) ' +
      'VALUES (:EMP, ''C'', ''F'', :NOME, :DOC, ''A'', CURRENT_TIMESTAMP) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('NOME').AsString := ANome;
    LQuery.ParamByName('DOC').AsString := NovoDocumento;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  { Cliente com CPF válido e sem endereço: usado para conferir que a
    NFC-e não exige endereço e que a NF-e exige. }
  function CriarPessoaSemEndereco(const ANome, ADoc: string): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, ' +
      '  ATIVO, DATA_CADASTRO) ' +
      'VALUES (:EMP, ''C'', ''F'', :NOME, :DOC, ''A'', CURRENT_TIMESTAMP) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('NOME').AsString := ANome;
    LQuery.ParamByName('DOC').AsString := ADoc;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function CriarPedido(AEmpresaId, AClienteId: Int64;
    ANumeroNfe: Integer): Int64;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PEDIDO_VENDA (EMPRESA_ID, CLIENTE_ID, USUARIO_ID, ' +
      '  NUMERO, DATA_EMISSAO, STATUS, SUBTOTAL, DESCONTO, TOTAL, ' +
      '  OBSERVACOES, NUMERO_NFE) ' +
      'VALUES (:EMP, :CLI, :USR, :NUM, CURRENT_DATE, ''A'', 0, 0, 0, ' +
      '  :OBS, :NFE) RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := AEmpresaId;
    LQuery.ParamByName('CLI').AsLargeInt := AClienteId;
    LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
    LQuery.ParamByName('NUM').AsString := NovoNumeroPedido;
    LQuery.ParamByName('OBS').AsString := 'NFE ' + LSufixo;
    if ANumeroNfe > 0 then
      LQuery.ParamByName('NFE').AsInteger := ANumeroNfe
    else
      LQuery.ParamByName('NFE').Clear;
    LQuery.Open;
    Result := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;
  end;

  function ProximoNumeroNfe: Integer;
  begin
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COALESCE(MAX(NUMERO_NFE), 0) + 1 FROM PEDIDO_VENDA ' +
      'WHERE NUMERO_NFE IS NOT NULL AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
    LQuery.Close;
  end;

  function IntPedido(const ACampo: string; AId: Int64): Integer;
  begin
    Result := 0;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').AsInteger;
    LQuery.Close;
  end;

  function TextoPedido(const ACampo: string; AId: Int64): string;
  begin
    Result := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT CAST(' + ACampo + ' AS VARCHAR(1000)) AS VALOR ' +
      'FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := Trim(LQuery.FieldByName('VALOR').AsString);
    LQuery.Close;
  end;

  function NuloPedido(const ACampo: string; AId: Int64): Boolean;
  begin
    Result := False;
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT ' + ACampo + ' AS VALOR FROM PEDIDO_VENDA WHERE ID = :ID';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('VALOR').IsNull;
    LQuery.Close;
  end;

  function LogNFe(AId: Int64; out AUsuario: Int64;
    out ADadosNovos: string): Boolean;
  begin
    Result := False;
    AUsuario := 0;
    ADadosNovos := '';
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT USUARIO_ID, DADOS_NOVOS FROM LOG_SISTEMA ' +
      'WHERE TABELA = ''PEDIDO_VENDA'' AND OPERACAO = ''NFE'' ' +
      '  AND REGISTRO_ID = :ID ORDER BY ID DESC';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      AUsuario := LQuery.FieldByName('USUARIO_ID').AsLargeInt;
      ADadosNovos := LQuery.FieldByName('DADOS_NOVOS').AsString;
      Result := True;
    end;
    LQuery.Close;
  end;

  // ------------------------------------------------------------------
  // Helpers de "recusa"
  // ------------------------------------------------------------------

  function RecusouGerar(APedidoId: Int64): Boolean;
  begin
    Result := False;
    try
      LHelper.GerarNFe(APedidoId);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouConsultar(const AChave: string): Boolean;
  begin
    Result := False;
    try
      LHelper.ConsultarNFe(AChave);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouCancelar(const AChave, AJustificativa: string): Boolean;
  begin
    Result := False;
    try
      LHelper.CancelarNFe(AChave, AJustificativa);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouManifestar(const AChave: string): Boolean;
  begin
    Result := False;
    try
      LHelper.ManifestarNFe(AChave, 210200);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouCartaCorrecao(const AChave, ACorrecao: string): Boolean;
  begin
    Result := False;
    try
      LHelper.EnviarCartaCorrecao(AChave, ACorrecao, 1);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  function RecusouInutilizar(AModelo, ASerie, AInicial, AFinal: Integer;
    const AJustificativa: string): Boolean;
  begin
    Result := False;
    try
      LHelper.InutilizarNumeracao(AModelo, ASerie, AInicial, AFinal, 2026,
        AJustificativa);
    except
      on E: Exception do
        Result := True;
    end;
  end;

  // ------------------------------------------------------------------
  // Configuração
  // ------------------------------------------------------------------

  procedure TestConfigurar;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        AssertEquals('2', IntToStr(LHelper.Ambiente),
          'ambiente padrão deve ser homologação (2)');
        AssertEquals('SP', LHelper.UF, 'UF padrão deve ser SP');
        AssertEquals('', LHelper.CaminhoCertificado,
          'certificado começa vazio');

        LHelper.Configurar(LCertificado, '1234', 'MG', 1);
        AssertEquals('1', IntToStr(LHelper.Ambiente),
          'Configurar deve gravar o ambiente');
        AssertEquals('MG', LHelper.UF, 'Configurar deve gravar a UF');
        AssertEquals(LCertificado, LHelper.CaminhoCertificado,
          'Configurar deve gravar o certificado');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeConfigurar', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeConfigurar', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Emissão simulada
  // ------------------------------------------------------------------

  procedure TestGerarSemCertificado;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar('', '1234', 'SP', 2);
        AssertTrue(RecusouGerar(1),
          'emissão sem certificado deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarSemCertificado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarSemCertificado', False, E.Message);
    end;
  end;

  procedure TestGerarSemSenha;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '', 'SP', 2);
        AssertTrue(RecusouGerar(1),
          'emissão sem senha deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarSemSenha', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarSemSenha', False, E.Message);
    end;
  end;

  procedure TestGerarPedidoInexistente;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertTrue(RecusouGerar(999999999),
          'pedido inexistente deve ser recusado');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarPedidoInexistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarPedidoInexistente', False, E.Message);
    end;
  end;

  procedure TestGerarOutraEmpresa;
  var
    LPedido: Int64;
  begin
    try
      LPedido := CriarPedido(999999, LClienteOutraEmpresa, 0);
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertTrue(RecusouGerar(LPedido),
          'pedido de outra empresa deve ser recusado');
        AssertTrue(NuloPedido('NUMERO_NFE', LPedido),
          'pedido de outra empresa não pode receber NUMERO_NFE');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarOutraEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarOutraEmpresa', False, E.Message);
    end;
  end;

  procedure TestGerarGravaNumeroChave;
  var
    LPedido: Int64;
    LDados: TACBrDadosNFe;
    LBase: Integer;
  begin
    try
      LBase := ProximoNumeroNfe;
      LPedido := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        LDados := LHelper.GerarNFe(LPedido);

        AssertEquals(IntToStr(LBase), IntToStr(LDados.Numero),
          'número da NF-e deve ser o próximo da empresa');
        AssertEquals('1', IntToStr(LDados.Serie), 'série padrão deve ser 1');
        AssertEquals('VENDA', LDados.NaturezaOperacao,
          'natureza padrão deve ser VENDA');
        AssertEquals('5102', LDados.CFOP, 'CFOP padrão deve ser 5102');
        AssertTrue(LDados.ChaveAcesso <> '', 'chave de acesso não pode ser vazia');
        AssertEquals('SIM', Copy(LDados.Protocolo, 1, 3),
          'protocolo simulado começa com SIM');
        AssertTrue(LDados.Status = ansPendente,
          'emissão simulada fica pendente');
        AssertTrue(LDados.XML <> '', 'XML simulado não pode ser vazio');

        AssertEquals(IntToStr(LDados.Numero), IntToStr(IntPedido('NUMERO_NFE', LPedido)),
          'NUMERO_NFE deve ser gravado no pedido');
        AssertEquals(LDados.ChaveAcesso, TextoPedido('CHAVE_NFE', LPedido),
          'CHAVE_NFE deve ser gravada no pedido');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarGravaNumeroChave', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarGravaNumeroChave', False, E.Message);
    end;
  end;

  procedure TestGerarSequencial;
  var
    LPedidoA, LPedidoB: Int64;
    LDadosA, LDadosB: TACBrDadosNFe;
  begin
    try
      LPedidoA := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LPedidoB := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        LDadosA := LHelper.GerarNFe(LPedidoA);
        LDadosB := LHelper.GerarNFe(LPedidoB);
        AssertEquals(IntToStr(LDadosA.Numero + 1), IntToStr(LDadosB.Numero),
          'emissões seguidas devem avançar o número');
        AssertTrue(LDadosA.ChaveAcesso <> LDadosB.ChaveAcesso,
          'cada pedido deve receber uma chave própria');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarSequencial', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarSequencial', False, E.Message);
    end;
  end;

  procedure TestGerarNumeroEscopoEmpresa;
  var
    LMarcador: Integer;
    LPedido, LOutraEmpresa: Int64;
    LDados: TACBrDadosNFe;
  begin
    try
      { marcador alto na empresa da sessão e um ainda maior em outra
        empresa: a numeração deve considerar só a empresa da sessão }
      LMarcador := ProximoNumeroNfe + 100;
      CriarPedido(LSessao.EmpresaId, LCliente, LMarcador);
      LOutraEmpresa := CriarPedido(999999, LClienteOutraEmpresa,
        LMarcador + 5000);

      LPedido := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        LDados := LHelper.GerarNFe(LPedido);
        AssertEquals(IntToStr(LMarcador + 1), IntToStr(LDados.Numero),
          'numeração deve ignorar outras empresas');
        AssertEquals(IntToStr(LMarcador + 5000),
          IntToStr(IntPedido('NUMERO_NFE', LOutraEmpresa)),
          'pedido de outra empresa não pode ser alterado');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarNumeroEscopoEmpresa', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarNumeroEscopoEmpresa', False, E.Message);
    end;
  end;

  procedure TestGerarAtualizaSoPedido;
  var
    LPedidoA, LPedidoB: Int64;
  begin
    try
      LPedidoA := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LPedidoB := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        LHelper.GerarNFe(LPedidoA);
        AssertTrue(NuloPedido('NUMERO_NFE', LPedidoB),
          'emissão não pode alterar outro pedido');
        AssertTrue(NuloPedido('CHAVE_NFE', LPedidoB),
          'emissão não pode gravar chave em outro pedido');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarAtualizaSoPedido', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarAtualizaSoPedido', False, E.Message);
    end;
  end;

  procedure TestGerarAuditoria;
  var
    LPedido: Int64;
    LDados: TACBrDadosNFe;
    LUsuario: Int64;
    LDadosNovos: string;
  begin
    try
      LPedido := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        LDados := LHelper.GerarNFe(LPedido);
        AssertTrue(LogNFe(LPedido, LUsuario, LDadosNovos),
          'emissão deve auditar em LOG_SISTEMA');
        AssertEquals(IntToStr(LSessao.UsuarioId), IntToStr(LUsuario),
          'auditoria deve usar o usuário da sessão');
        AssertTrue(Pos('NUMERO_NFE=' + IntToStr(LDados.Numero),
          LDadosNovos) > 0, 'auditoria deve citar o número da NF-e');
        AssertTrue(Pos('CHAVE=' + LDados.ChaveAcesso,
          LDadosNovos) > 0, 'auditoria deve citar a chave');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarAuditoria', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarAuditoria', False, E.Message);
    end;
  end;

  procedure TestGerarNFCe;
  var
    LPedido: Int64;
    LDados: TACBrDadosNFe;
  begin
    try
      LPedido := CriarPedido(LSessao.EmpresaId, LCliente, 0);
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        LDados := LHelper.GerarNFCe(LPedido);
        AssertEquals('VENDA AO CONSUMIDOR', LDados.NaturezaOperacao,
          'NFC-e deve usar a natureza de venda ao consumidor');
        AssertTrue(LDados.ChaveAcesso <> '', 'NFC-e deve gerar chave');
        AssertTrue(IntPedido('NUMERO_NFE', LPedido) > 0,
          'NFC-e deve gravar NUMERO_NFE no pedido');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeGerarNFCe', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeGerarNFCe', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // Consulta / cancelamento / manifestação
  // ------------------------------------------------------------------

  procedure TestConsultarSemConfiguracao;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        AssertTrue(RecusouConsultar('CHAVE123'),
          'consulta sem certificado deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeConsultarSemConfiguracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeConsultarSemConfiguracao', False, E.Message);
    end;
  end;

  procedure TestConsultarComConfiguracao;
  var
    LDados: TACBrDadosNFe;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        LDados := LHelper.ConsultarNFe('CHAVE123');
        AssertEquals('CHAVE123', LDados.ChaveAcesso,
          'consulta deve devolver a chave informada');
        AssertTrue(LDados.Status = ansPendente,
          'consulta simulada fica pendente');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeConsultarComConfiguracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeConsultarComConfiguracao', False, E.Message);
    end;
  end;

  procedure TestCancelarJustificativaCurta;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertTrue(RecusouCancelar('CHAVE123', 'curta'),
          'justificativa com menos de 15 caracteres deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeCancelarJustificativaCurta', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeCancelarJustificativaCurta', False, E.Message);
    end;
  end;

  procedure TestCancelarComConfiguracao;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertFalse(LHelper.CancelarNFe('CHAVE123',
          'Justificativa valida com mais de quinze caracteres'),
          'cancelamento simulado devolve False');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeCancelarComConfiguracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeCancelarComConfiguracao', False, E.Message);
    end;
  end;

  procedure TestManifestarSemConfiguracao;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        AssertTrue(RecusouManifestar('CHAVE123'),
          'manifestação sem certificado deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeManifestarSemConfiguracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeManifestarSemConfiguracao', False, E.Message);
    end;
  end;

  procedure TestManifestarComConfiguracao;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertFalse(LHelper.ManifestarNFe('CHAVE123', 210200),
          'manifestação simulada devolve False');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeManifestarComConfiguracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeManifestarComConfiguracao', False, E.Message);
    end;
  end;

  // ------------------------------------------------------------------
  // CC-e / inutilização
  // ------------------------------------------------------------------

  procedure TestCartaCorrecaoCurta;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertTrue(RecusouCartaCorrecao(
          '35260100000000000000550010000000011000000010', 'curta'),
          'correção com menos de 15 caracteres deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeCartaCorrecaoCurta', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeCartaCorrecaoCurta', False, E.Message);
    end;
  end;

  procedure TestCartaCorrecaoChaveInvalida;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertTrue(RecusouCartaCorrecao('123',
          'Correcao valida com mais de quinze caracteres'),
          'chave sem 44 dígitos deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeCartaCorrecaoChaveInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeCartaCorrecaoChaveInvalida', False, E.Message);
    end;
  end;

  procedure TestCartaCorrecaoComConfiguracao;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertFalse(LHelper.EnviarCartaCorrecao(
          '35260100000000000000550010000000011000000010',
          'Correcao valida com mais de quinze caracteres', 1),
          'CC-e simulada devolve False');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeCartaCorrecaoComConfiguracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeCartaCorrecaoComConfiguracao', False, E.Message);
    end;
  end;

  procedure TestInutilizarJustificativaCurta;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertTrue(RecusouInutilizar(55, 1, 1, 10, 'curta'),
          'justificativa com menos de 15 caracteres deve ser recusada');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeInutilizarJustificativaCurta', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeInutilizarJustificativaCurta', False, E.Message);
    end;
  end;

  procedure TestInutilizarFaixaInvalida;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertTrue(RecusouInutilizar(55, 1, 10, 1,
          'Justificativa valida com mais de quinze caracteres'),
          'faixa com final menor que o inicial deve ser recusada');
        AssertTrue(RecusouInutilizar(99, 1, 1, 10,
          'Justificativa valida com mais de quinze caracteres'),
          'modelo diferente de 55/65 deve ser recusado');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeInutilizarFaixaInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeInutilizarFaixaInvalida', False, E.Message);
    end;
  end;

  procedure TestInutilizarComConfiguracao;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertFalse(LHelper.InutilizarNumeracao(55, 1, 1, 10, 2026,
          'Justificativa valida com mais de quinze caracteres'),
          'inutilização simulada devolve False');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeInutilizarComConfiguracao', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeInutilizarComConfiguracao', False, E.Message);
    end;
  end;

  procedure TestProximaSequenciaCce;
  var
    LChave: string;
    LI: Integer;
  begin
    try
      LChave := Copy('35' + LSufixo + StringOfChar('0', 44), 1, 44);
      for LI := 1 to 2 do
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'INSERT INTO LOG_SISTEMA (EMPRESA_ID, USUARIO_ID, TABELA, ' +
          '  OPERACAO, REGISTRO_ID, DADOS_NOVOS, DATA_OPERACAO, DATA_HORA) ' +
          'VALUES (:EMP, :USR, ''NFE'', ''CCE'', 0, :DADOS, ' +
          '  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)';
        LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
        LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
        LQuery.ParamByName('DADOS').AsString := 'CHAVE=' + LChave;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;

      LHelper := TACBrHelper.Create;
      try
        AssertEquals('3', IntToStr(LHelper.ProximaSequenciaCce(LChave)),
          'duas CC-e auditadas devem deixar a sequência em 3');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeProximaSequenciaCce', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeProximaSequenciaCce', False, E.Message);
    end;
  end;

  procedure TestDANFEChaveInvalida;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        try
          LHelper.GerarDANFEPDF('123');
          AssertTrue(False, 'chave sem 44 dígitos deve ser recusada');
        except
          on E: Exception do
            AssertTrue(Pos('44', E.Message) > 0,
              'mensagem deve citar os 44 dígitos');
        end;
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeDANFEChaveInvalida', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeDANFEChaveInvalida', False, E.Message);
    end;
  end;

  procedure TestDANFEModoSimulado;
  begin
    try
      LHelper := TACBrHelper.Create;
      try
        LHelper.Configurar(LCertificado, '1234', 'SP', 2);
        AssertEquals('',
          LHelper.GerarDANFEPDF('35260100000000000000550010000000011000000010'),
          'DANFE em modo simulado não gera arquivo');
      finally
        LHelper.Free;
        LHelper := nil;
      end;
      ASuite.AddResult('TestNFeDANFEModoSimulado', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeDANFEModoSimulado', False, E.Message);
    end;
  end;

  { Carrega as chaves fiscais da CONFIGURACAO. As chaves originais são
    guardadas e restauradas no finally para não alterar o banco do usuário. }
  procedure TestCarregarConfiguracaoFiscal;
  const
    CHAVES: array[0..4] of string = ('NFE_CERTIFICADO', 'NFE_AMBIENTE',
      'NFE_MODO', 'NFCE_ID_CSC', 'NFCE_CSC');
    VALORES: array[0..4] of string = ('C:\teste\certificado.pfx', '2',
      'REAL', 'ID-TESTE', 'CSC-TESTE');
  var
    LOriginais: TStringList;
    LI: Integer;
  begin
    LOriginais := TStringList.Create;
    try
      try
        for LI := 0 to High(CHAVES) do
        begin
          LQuery.Close;
          LQuery.SQL.Text :=
            'SELECT FIRST 1 VALOR FROM CONFIGURACAO WHERE CHAVE = :CHAVE ' +
            'AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL) ' +
            'ORDER BY EMPRESA_ID DESC';
          LQuery.ParamByName('CHAVE').AsString := CHAVES[LI];
          LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
          LQuery.Open;
          if LQuery.IsEmpty then
            LOriginais.Add('')
          else
            LOriginais.Add(Trim(LQuery.FieldByName('VALOR').AsString));
          LQuery.Close;

          LQuery.SQL.Text :=
            'DELETE FROM CONFIGURACAO WHERE CHAVE = :CHAVE AND EMPRESA_ID = :EMP';
          LQuery.ParamByName('CHAVE').AsString := CHAVES[LI];
          LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
          LQuery.ExecSQL;

          LQuery.SQL.Text :=
            'INSERT INTO CONFIGURACAO (EMPRESA_ID, CHAVE, VALOR, DESCRICAO) ' +
            'VALUES (:EMP, :CHAVE, :VALOR, ''teste'')';
          LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
          LQuery.ParamByName('CHAVE').AsString := CHAVES[LI];
          LQuery.ParamByName('VALOR').AsString := VALORES[LI];
          LQuery.ExecSQL;
        end;
        LConexao.Confirmar;

        LHelper := TACBrHelper.Create;
        try
          LHelper.CarregarConfiguracaoFiscal;
          AssertEquals(VALORES[0], LHelper.CaminhoCertificado,
            'NFE_CERTIFICADO deve preencher o certificado');
          AssertEquals('2', IntToStr(LHelper.Ambiente),
            'NFE_AMBIENTE deve preencher o ambiente');
          AssertEquals(VALORES[3], LHelper.IdCSC, 'NFCE_ID_CSC');
          AssertEquals(VALORES[4], LHelper.CSC, 'NFCE_CSC');
          AssertFalse(LHelper.ModoSimulado, 'NFE_MODO=REAL desliga a simulação');
          AssertEquals('SP', LHelper.UF, 'UF deve vir da EMPRESA');
        finally
          LHelper.Free;
          LHelper := nil;
        end;
        ASuite.AddResult('TestNFeCarregarConfiguracaoFiscal', True, '');
      finally
        for LI := 0 to High(CHAVES) do
        begin
          LQuery.Close;
          LQuery.SQL.Text :=
            'DELETE FROM CONFIGURACAO WHERE CHAVE = :CHAVE AND EMPRESA_ID = :EMP';
          LQuery.ParamByName('CHAVE').AsString := CHAVES[LI];
          LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
          LQuery.ExecSQL;
          if LOriginais[LI] <> '' then
          begin
            LQuery.SQL.Text :=
              'INSERT INTO CONFIGURACAO (EMPRESA_ID, CHAVE, VALOR, DESCRICAO) ' +
              'VALUES (:EMP, :CHAVE, :VALOR, ''restaurado'')';
            LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
            LQuery.ParamByName('CHAVE').AsString := CHAVES[LI];
            LQuery.ParamByName('VALOR').AsString := LOriginais[LI];
            LQuery.ExecSQL;
          end;
        end;
        LConexao.Confirmar;
      end;
    except
      on E: Exception do
        ASuite.AddResult('TestNFeCarregarConfiguracaoFiscal', False, E.Message);
    end;
    LOriginais.Free;
  end;

  { Preferência de homologação: o interruptor da tela de Configurações
    grava NFE_AMBIENTE=2 + NFE_MODO=REAL e o ACBrHelper passa a mirar a
    SEFAZ de homologação; desativar volta para o modo simulado. }
  procedure TestModoHomologacao;
  var
    LConfig: TConfiguracaoService;
    LAux: TACBrHelper;
    LAmbienteAntes, LModoAntes: string;
    LAmbienteDesc, LModoDesc: string;
    LAmbienteExiste, LModoExiste: Boolean;

    procedure CapturarChave(const AChave: string; out AExiste: Boolean;
      out AValor, ADescricao: string);
    begin
      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT FIRST 1 VALOR, DESCRICAO FROM CONFIGURACAO ' +
        'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL) ' +
        'ORDER BY EMPRESA_ID DESC NULLS LAST';
      LQuery.ParamByName('CHAVE').AsString := AChave;
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.Open;
      AExiste := not LQuery.IsEmpty;
      if AExiste then
      begin
        AValor := Trim(LQuery.FieldByName('VALOR').AsString);
        ADescricao := LQuery.FieldByName('DESCRICAO').AsString;
      end
      else
      begin
        AValor := '';
        ADescricao := '';
      end;
      LQuery.Close;
    end;

    procedure RestaurarChave(const AChave: string; AExiste: Boolean;
      const AValor, ADescricao: string);
    begin
      LQuery.Close;
      if (not AExiste) or (AValor = '') then
        LQuery.SQL.Text :=
          'DELETE FROM CONFIGURACAO ' +
          'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)'
      else
      begin
        LQuery.SQL.Text :=
          'UPDATE CONFIGURACAO SET VALOR = :VALOR, DESCRICAO = :DESCR ' +
          'WHERE CHAVE = :CHAVE AND (EMPRESA_ID = :EMP OR EMPRESA_ID IS NULL)';
        LQuery.ParamByName('VALOR').AsString := AValor;
        LQuery.ParamByName('DESCR').AsString := ADescricao;
      end;
      LQuery.ParamByName('CHAVE').AsString := AChave;
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ExecSQL;
    end;

  begin
    LConfig := TConfiguracaoService.Create;
    LAux := TACBrHelper.Create;
    try
      try
        LConexao.IniciarTransacao;
        CapturarChave('NFE_AMBIENTE', LAmbienteExiste, LAmbienteAntes,
          LAmbienteDesc);
        CapturarChave('NFE_MODO', LModoExiste, LModoAntes, LModoDesc);
        LConexao.Confirmar;

        LConfig.DefinirModoHomologacao(True);
        AssertTrue(LConfig.HomologacaoAtiva, 'HomologacaoAtiva apos ativar');
        LAux.CarregarConfiguracaoFiscal;
        AssertEquals('2', IntToStr(LAux.Ambiente),
          'Ambiente do ACBrHelper = homologacao');
        AssertTrue(not LAux.ModoSimulado,
          'ModoSimulado desligado no modo homologacao');

        LConfig.DefinirModoHomologacao(False);
        AssertTrue(not LConfig.HomologacaoAtiva, 'HomologacaoAtiva apos desativar');
        LAux.CarregarConfiguracaoFiscal;
        AssertTrue(LAux.ModoSimulado, 'ModoSimulado ligado apos desativar');
      finally
        LConexao.IniciarTransacao;
        try
          RestaurarChave('NFE_AMBIENTE', LAmbienteExiste, LAmbienteAntes,
            LAmbienteDesc);
          RestaurarChave('NFE_MODO', LModoExiste, LModoAntes, LModoDesc);
          LQuery.Close;
          LQuery.SQL.Text :=
            'DELETE FROM LOG_SISTEMA WHERE TABELA = :TAB AND ID > :TOPO';
          LQuery.ParamByName('TAB').AsString := 'CONFIGURACAO';
          LQuery.ParamByName('TOPO').AsLargeInt := LTopoLog;
          LQuery.ExecSQL;
          LConexao.Confirmar;
        except
          LConexao.Cancelar;
          raise;
        end;
      end;
      ASuite.AddResult('TestNFeModoHomologacao', True);
    except
      on E: Exception do
        ASuite.AddResult('TestNFeModoHomologacao', False, E.Message);
    end;
    LAux.Free;
    LConfig.Free;
  end;

  { Destinatário opcional na NFC-e: cliente com CPF e sem endereço passa
    na NFC-e, mas a NF-e exige o endereço completo. }
  procedure TestDestinatarioOpcionalNFCe;
  var
    LClienteSemEndereco: Int64;
    LPedido: Int64;
    LFaltando: string;
  begin
    try
      LClienteSemEndereco := CriarPessoaSemEndereco(
        NovoNome('CLIENTE SEM ENDERECO'), '12345678901');
      LPedido := CriarPedido(LSessao.EmpresaId, LClienteSemEndereco, 0);

      LFaltando := LHelper.CamposFaltandoDestinatario(LPedido, 65);
      AssertEquals('', LFaltando,
        'Na NFC-e o destinatário sem endereço não pode faltar');

      LFaltando := LHelper.CamposFaltandoDestinatario(LPedido, 55);
      AssertTrue(LFaltando <> '', 'Na NF-e o endereço é obrigatório');
      AssertTrue(Pos('ENDERECO', LFaltando) > 0,
        'A NF-e deve apontar o endereço que falta');
      AssertTrue(Pos('CIDADE', LFaltando) > 0,
        'A NF-e deve apontar a cidade que falta');

      { A validação local também deve recusar a NF-e e não recusar a
        NFC-e por causa do destinatário. }
      try
        LHelper.ValidarNFe(LPedido);
        AssertFail('A NF-e deve recusar o pedido sem endereço do destinatário');
      except
        on E: TAssertException do
          raise;
        on E: Exception do
          AssertTrue(Pos('destinat', LowerCase(E.Message)) > 0,
            'A NF-e deve avisar sobre o destinatário: ' + E.Message);
      end;

      try
        LHelper.ValidarNFCe(LPedido);
      except
        on E: Exception do
          AssertTrue(Pos('destinat', LowerCase(E.Message)) = 0,
            'A NFC-e não pode recusar por falta de dados do destinatário: ' +
            E.Message);
      end;

      ASuite.AddResult('TestNFeDestinatarioOpcionalNFCe', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeDestinatarioOpcionalNFCe', False, E.Message);
    end;
  end;

  { XML de NF-e (com prefixo de namespace de proposito) importado como
    nota de entrada: fornecedor por CNPJ, produto por codigo, fiscal do
    documento e recusa da mesma chave na segunda tentativa. }
  procedure TestImportarXmlNotaEntrada;
  var
    LFornecedorId, LProdutoId, LNotaCriada, LTentativa: Int64;
    LIncluidos, LSemProduto: Integer;
    LChave, LArquivo, LXml, LCodigoProduto, LDOC: string;
    LLista: TStringList;
    LImportou, LRecusouDuplicada: Boolean;
  begin
    LFornecedorId := 0;
    LProdutoId := 0;
    LNotaCriada := 0;
    LCodigoProduto := 'XML' + Copy(LSufixo, 1, 10);
    LDOC := Copy('99' + LSufixo, 1, 14);
    LChave := Copy('35' + LSufixo +
      '0000000000000000000000000000000000', 1, 44);
    LArquivo := IncludeTrailingPathDelimiter(GetTempDir) +
      'nfe_import_' + LSufixo + '.xml';
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, ' +
        '  ATIVO, DATA_CADASTRO) ' +
        'VALUES (:EMP, ''F'', ''J'', :NOME, :DOC, ''A'', CURRENT_TIMESTAMP) ' +
        'RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ParamByName('NOME').AsString := NovoNome('FORNECEDOR XML');
      LQuery.ParamByName('DOC').AsString := LDOC;
      LQuery.Open;
      LFornecedorId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;
      LConexao.Confirmar;

      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
        '  DESCRICAO, PRECO_CUSTO, PRECO_VENDA, CONTROLA_ESTOQUE, ATIVO) ' +
        'VALUES (:EMP, 1, 1, :COD, :DESC, 1, 2, ''S'', ''A'') RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ParamByName('COD').AsString := LCodigoProduto;
      LQuery.ParamByName('DESC').AsString := NovoNome('PRODUTO XML');
      LQuery.Open;
      LProdutoId := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;
      LConexao.Confirmar;

      LXml :=
        '<nfe:nfeProc xmlns:nfe="http://www.portalfiscal.inf.br/nfe">' +
        '<nfe:NFe><nfe:infNFe Id="NFe' + LChave + '">' +
        '<nfe:ide><nfe:natOp>COMPRA PARA COMERCIALIZACAO</nfe:natOp>' +
        '<nfe:mod>55</nfe:mod><nfe:serie>1</nfe:serie>' +
        '<nfe:nNF>9001</nfe:nNF>' +
        '<nfe:dhEmi>2026-11-14T10:00:00-03:00</nfe:dhEmi></nfe:ide>' +
        '<nfe:emit><nfe:CNPJ>' + LDOC + '</nfe:CNPJ>' +
        '<nfe:xNome>FORNECEDOR XML ' + LSufixo + '</nfe:xNome></nfe:emit>' +
        '<nfe:det nItem="1"><nfe:prod>' +
        '<nfe:cProd>' + LCodigoProduto + '</nfe:cProd>' +
        '<nfe:cEAN></nfe:cEAN>' +
        '<nfe:xProd>PRODUTO &amp; XML</nfe:xProd>' +
        '<nfe:NCM>84713012</nfe:NCM><nfe:CFOP>1102</nfe:CFOP>' +
        '<nfe:uCom>UN</nfe:uCom><nfe:qCom>2.0000</nfe:qCom>' +
        '<nfe:vUnCom>10.00</nfe:vUnCom><nfe:vDesc>0</nfe:vDesc>' +
        '</nfe:prod><nfe:imposto><nfe:ICMS><nfe:ICMS00>' +
        '<nfe:CST>00</nfe:CST><nfe:pICMS>18.00</nfe:pICMS>' +
        '</nfe:ICMS00></nfe:ICMS></nfe:imposto></nfe:det>' +
        '<nfe:total><nfe:ICMSTot><nfe:vProd>20.00</nfe:vProd>' +
        '<nfe:vFrete>0</nfe:vFrete><nfe:vSeg>0</nfe:vSeg>' +
        '<nfe:vDesc>0</nfe:vDesc><nfe:vOutro>0</nfe:vOutro>' +
        '<nfe:vNF>20.00</nfe:vNF></nfe:ICMSTot></nfe:total>' +
        '</nfe:infNFe></nfe:NFe></nfe:nfeProc>';

      LLista := TStringList.Create;
      try
        LLista.Text := LXml;
        LLista.SaveToFile(LArquivo);
      finally
        LLista.Free;
      end;

      LImportou := TNFeImportService.Importar(LArquivo, LNotaCriada,
        LIncluidos, LSemProduto);
      AssertTrue(LImportou and (LNotaCriada > 0) and (LIncluidos = 1) and
        (LSemProduto = 0),
        'XML deve gerar nota de entrada com um item vinculado');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT CHAVE_ACESSO, FORNECEDOR_ID, VALOR_TOTAL ' +
        'FROM NOTA_ENTRADA WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LNotaCriada;
      LQuery.Open;
      AssertTrue((not LQuery.IsEmpty) and
        (Trim(LQuery.FieldByName('CHAVE_ACESSO').AsString) = LChave) and
        (LQuery.FieldByName('FORNECEDOR_ID').AsLargeInt = LFornecedorId) and
        (Abs(LQuery.FieldByName('VALOR_TOTAL').AsFloat - 20) < 0.01),
        'cabeçalho deve guardar chave, fornecedor e total do XML');
      LQuery.Close;

      LQuery.SQL.Text :=
        'SELECT DESCRICAO, NCM, CFOP, CST_ICMS, QUANTIDADE, VALOR_UNITARIO ' +
        'FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LNotaCriada;
      LQuery.Open;
      AssertTrue((not LQuery.IsEmpty) and
        (Trim(LQuery.FieldByName('DESCRICAO').AsString) = 'PRODUTO & XML') and
        (Trim(LQuery.FieldByName('NCM').AsString) = '84713012') and
        (Trim(LQuery.FieldByName('CFOP').AsString) = '1102') and
        (Trim(LQuery.FieldByName('CST_ICMS').AsString) = '00') and
        (Abs(LQuery.FieldByName('QUANTIDADE').AsFloat - 2) < 0.01) and
        (Abs(LQuery.FieldByName('VALOR_UNITARIO').AsFloat - 10) < 0.01),
        'item deve herdar NCM/CFOP/CST do XML');
      LQuery.Close;

      LQuery.SQL.Text :=
        'SELECT COUNT(*) AS QTD FROM LOG_SISTEMA WHERE TABELA = :T ' +
        'AND OPERACAO = :O AND REGISTRO_ID = :ID AND USUARIO_ID = :USR';
      LQuery.ParamByName('T').AsString := 'XML_FISCAL';
      LQuery.ParamByName('O').AsString := 'IMPORTACAO_XML';
      LQuery.ParamByName('ID').AsLargeInt := LNotaCriada;
      LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
      LQuery.Open;
      AssertTrue(LQuery.FieldByName('QTD').AsInteger = 1,
        'importacao deve auditar XML_FISCAL/IMPORTACAO_XML');
      LQuery.Close;

      LRecusouDuplicada := False;
      LTentativa := 0;
      try
        TNFeImportService.Importar(LArquivo, LTentativa, LIncluidos,
          LSemProduto);
      except
        on E: ENFeXml do
          LRecusouDuplicada := True;
      end;
      AssertTrue(LRecusouDuplicada,
        'reimportar a mesma chave deve ser recusado');

      ASuite.AddResult('TestNFeImportarXmlNotaEntrada', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestNFeImportarXmlNotaEntrada', False, E.Message);
    end;

    { limpeza: itens, nota, produto, fornecedor e arquivo }
    try
      if LNotaCriada > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'DELETE FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LNotaCriada;
        LQuery.ExecSQL;
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM NOTA_ENTRADA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LNotaCriada;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;
    except
    end;
    try
      if LProdutoId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM PRODUTO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LProdutoId;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;
    except
    end;
    try
      if LFornecedorId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM PESSOA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LFornecedorId;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;
    except
    end;
    try
      if FileExists(LArquivo) then
        DeleteFile(LArquivo);
    except
    end;
  end;

  // ------------------------------------------------------------------
  // Marco 3.88 - rastro e mapeamento de produto do XML
  // ------------------------------------------------------------------

  procedure PrepararXmlSemProduto(const ACodigo: string;
    out AFornecedorId: Int64; out AChave, AArquivo: string);
  var
    LXml: string;
    LLista: TStringList;
    LDoc: string;
  begin
    Inc(LSeq);
    AChave := Copy('35' + LSufixo + IntToStr(LSeq) +
      StringOfChar('0', 44), 1, 44);
    LDoc := Copy('98' + LSufixo, 1, 14);
    AFornecedorId := 0;

    LQuery.Close;
    LQuery.SQL.Text :=
      'INSERT INTO PESSOA (EMPRESA_ID, TIPO, TIPO_PESSOA, NOME, CPF_CNPJ, ' +
      '  ATIVO, DATA_CADASTRO) ' +
      'VALUES (:EMP, ''F'', ''J'', :NOME, :DOC, ''A'', CURRENT_TIMESTAMP) ' +
      'RETURNING ID';
    LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
    LQuery.ParamByName('NOME').AsString := NovoNome('FORNECEDOR MAPA');
    LQuery.ParamByName('DOC').AsString := LDoc;
    LQuery.Open;
    AFornecedorId := LQuery.FieldByName('ID').AsLargeInt;
    LQuery.Close;
    LConexao.Confirmar;

    AArquivo := IncludeTrailingPathDelimiter(GetTempDir) + 'nfe_mapa_' +
      LSufixo + '_' + IntToStr(LSeq) + '.xml';
    LXml :=
      '<nfe:nfeProc xmlns:nfe="http://www.portalfiscal.inf.br/nfe">' +
      '<nfe:NFe><nfe:infNFe Id="NFe' + AChave + '">' +
      '<nfe:ide><nfe:natOp>COMPRA PARA COMERCIALIZACAO</nfe:natOp>' +
      '<nfe:mod>55</nfe:mod><nfe:serie>1</nfe:serie>' +
      '<nfe:nNF>' + IntToStr(9000 + LSeq) + '</nfe:nNF>' +
      '<nfe:dhEmi>2026-11-14T10:00:00-03:00</nfe:dhEmi></nfe:ide>' +
      '<nfe:emit><nfe:CNPJ>' + LDoc + '</nfe:CNPJ>' +
      '<nfe:xNome>FORNECEDOR MAPA ' + LSufixo + '</nfe:xNome></nfe:emit>' +
      '<nfe:det nItem="1"><nfe:prod>' +
      '<nfe:cProd>' + ACodigo + '</nfe:cProd>' +
      '<nfe:cEAN>SEM GTIN</nfe:cEAN>' +
      '<nfe:xProd>PRODUTO SEM CADASTRO &amp; TESTE</nfe:xProd>' +
      '<nfe:NCM>84713012</nfe:NCM><nfe:CFOP>1102</nfe:CFOP>' +
      '<nfe:uCom>UN</nfe:uCom><nfe:qCom>3.0000</nfe:qCom>' +
      '<nfe:vUnCom>12.50</nfe:vUnCom><nfe:vDesc>0</nfe:vDesc>' +
      '</nfe:prod><nfe:imposto><nfe:ICMS><nfe:ICMS00>' +
      '<nfe:CST>00</nfe:CST></nfe:ICMS00></nfe:ICMS></nfe:imposto></nfe:det>' +
      '<nfe:total><nfe:ICMSTot><nfe:vProd>37.50</nfe:vProd>' +
      '<nfe:vFrete>0</nfe:vFrete><nfe:vSeg>0</nfe:vSeg>' +
      '<nfe:vDesc>0</nfe:vDesc><nfe:vOutro>0</nfe:vOutro>' +
      '<nfe:vNF>37.50</nfe:vNF></nfe:ICMSTot></nfe:total>' +
      '</nfe:infNFe></nfe:NFe></nfe:nfeProc>';
    LLista := TStringList.Create;
    try
      LLista.Text := LXml;
      LLista.SaveToFile(AArquivo);
    finally
      LLista.Free;
    end;
  end;

  procedure LimparCenario(ANotaId, AFornecedorId, AProdutoId: Int64;
    const AArquivo: string);
  begin
    try
      if ANotaId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text :=
          'DELETE FROM IMPORTACAO_XML_ITEM WHERE NOTA_ENTRADA_ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := ANotaId;
        LQuery.ExecSQL;
        LQuery.Close;
        LQuery.SQL.Text :=
          'DELETE FROM NOTA_ENTRADA_ITEM WHERE NOTA_ENTRADA_ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := ANotaId;
        LQuery.ExecSQL;
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM NOTA_ENTRADA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := ANotaId;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;
    except
      LConexao.Cancelar;
    end;
    try
      if AProdutoId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM PRODUTO WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := AProdutoId;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;
    except
      LConexao.Cancelar;
    end;
    try
      if AFornecedorId > 0 then
      begin
        LQuery.Close;
        LQuery.SQL.Text := 'DELETE FROM PESSOA WHERE ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := AFornecedorId;
        LQuery.ExecSQL;
        LConexao.Confirmar;
      end;
    except
      LConexao.Cancelar;
    end;
    try
      if FileExists(AArquivo) then
        DeleteFile(AArquivo);
    except
    end;
  end;

  procedure TestImportacaoXmlRastroItem;
  var
    LFornecedor, LNota: Int64;
    LChave, LArquivo, LCodigo: string;
    LIncluidos, LSem: Integer;
  begin
    LFornecedor := 0;
    LNota := 0;
    LCodigo := 'SEM' + Copy(LSufixo, 1, 10);
    PrepararXmlSemProduto(LCodigo, LFornecedor, LChave, LArquivo);
    try
      AssertTrue(TNFeImportService.Importar(LArquivo, LNota,
        LIncluidos, LSem) and (LIncluidos = 1) and (LSem = 1),
        'item sem cadastro deve ser importado e contado');

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT ID, FORNECEDOR_CNPJ, DESCRICAO_ORIGINAL, ' +
        ' CODIGO_PRODUTO_NOTA, CLASSIFICACAO_FISCAL, SITUACAO, PRODUTO_ID ' +
        'FROM IMPORTACAO_XML_ITEM WHERE EMPRESA_ID = :EMP ' +
        'AND NOTA_ENTRADA_ID = :NOTA';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ParamByName('NOTA').AsLargeInt := LNota;
      LQuery.Open;
      AssertTrue((not LQuery.IsEmpty) and
        (Trim(LQuery.FieldByName('DESCRICAO_ORIGINAL').AsString) =
          'PRODUTO SEM CADASTRO & TESTE') and
        (Trim(LQuery.FieldByName('CODIGO_PRODUTO_NOTA').AsString) = LCodigo) and
        (Trim(LQuery.FieldByName('CLASSIFICACAO_FISCAL').AsString) =
          'NCM 84713012; CFOP 1102; CST 00') and
        (Trim(LQuery.FieldByName('SITUACAO').AsString) = 'PENDENTE') and
        LQuery.FieldByName('PRODUTO_ID').IsNull and
        (Trim(LQuery.FieldByName('FORNECEDOR_CNPJ').AsString) <> ''),
        'rastro deve guardar CNPJ, descrição original e classificação do XML');
      LQuery.Close;
      ASuite.AddResult('TestImportacaoXmlRastroItem', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestImportacaoXmlRastroItem', False, E.Message);
    end;
    LimparCenario(LNota, LFornecedor, 0, LArquivo);
  end;

  procedure TestImportacaoXmlMapeiaProdutoExistente;
  var
    LFornecedor, LNota, LProduto, LMapId: Int64;
    LChave, LArquivo, LCodigoXml, LCodigoCad: string;
    LIncluidos, LSem, LQtdLog: Integer;
    LMap: TImportacaoXmlMapService;
  begin
    LFornecedor := 0;
    LNota := 0;
    LProduto := 0;
    LMapId := 0;
    LCodigoXml := 'NAO' + Copy(LSufixo, 1, 10);
    LCodigoCad := 'CAD' + Copy(LSufixo, 1, 10);
    PrepararXmlSemProduto(LCodigoXml, LFornecedor, LChave, LArquivo);
    try
      LQuery.Close;
      LQuery.SQL.Text :=
        'INSERT INTO PRODUTO (EMPRESA_ID, CATEGORIA_ID, UNIDADE_ID, CODIGO, ' +
        '  DESCRICAO, PRECO_CUSTO, PRECO_VENDA, CONTROLA_ESTOQUE, ATIVO) ' +
        'VALUES (:EMP, 1, 1, :COD, :DESC, 10, 20, ''S'', ''A'') RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ParamByName('COD').AsString := LCodigoCad;
      LQuery.ParamByName('DESC').AsString := NovoNome('COMPATIVEL XML');
      LQuery.Open;
      LProduto := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;
      LConexao.Confirmar;

      AssertTrue(TNFeImportService.Importar(LArquivo, LNota,
        LIncluidos, LSem) and (LSem = 1),
        'XML com código desconhecido deve ficar pendente');

      LMap := TImportacaoXmlMapService.Create;
      try
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT ID FROM IMPORTACAO_XML_ITEM WHERE NOTA_ENTRADA_ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LNota;
        LQuery.Open;
        LMapId := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;

        LMap.AplicarMapeamento(LMapId, LProduto, 'XML');
      finally
        LMap.Free;
      end;

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT SITUACAO, PRODUTO_ID FROM IMPORTACAO_XML_ITEM WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LMapId;
      LQuery.Open;
      AssertTrue((Trim(LQuery.FieldByName('SITUACAO').AsString) = 'MAPEADO') and
        (LQuery.FieldByName('PRODUTO_ID').AsLargeInt = LProduto),
        'escolha de compatível deve marcar o rastro como MAPEADO');
      LQuery.Close;

      LQuery.SQL.Text :=
        'SELECT PRODUTO_ID, NCM, CFOP, CST_ICMS FROM NOTA_ENTRADA_ITEM ' +
        'WHERE NOTA_ENTRADA_ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LNota;
      LQuery.Open;
      AssertTrue((LQuery.FieldByName('PRODUTO_ID').AsLargeInt = LProduto) and
        (Trim(LQuery.FieldByName('NCM').AsString) = '84713012') and
        (Trim(LQuery.FieldByName('CFOP').AsString) = '1102'),
        'item da nota deve herdar o produto escolhido e a classificação');
      LQuery.Close;

      LQuery.SQL.Text :=
        'SELECT COUNT(*) AS QTD FROM LOG_SISTEMA WHERE TABELA = :T ' +
        'AND OPERACAO = :O AND REGISTRO_ID = :ID AND USUARIO_ID = :USR';
      LQuery.ParamByName('T').AsString := 'IMPORTACAO_XML';
      LQuery.ParamByName('O').AsString := 'MAPEAMENTO_PRODUTO';
      LQuery.ParamByName('ID').AsLargeInt := LMapId;
      LQuery.ParamByName('USR').AsLargeInt := LSessao.UsuarioId;
      LQuery.Open;
      LQtdLog := LQuery.FieldByName('QTD').AsInteger;
      LQuery.Close;
      AssertTrue(LQtdLog = 1,
        'mapeamento deve auditar usuário, empresa e origem XML');
      ASuite.AddResult('TestImportacaoXmlMapeiaProdutoExistente', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestImportacaoXmlMapeiaProdutoExistente', False,
          E.Message);
    end;
    LimparCenario(LNota, LFornecedor, LProduto, LArquivo);
  end;

  procedure TestImportacaoXmlCriaProdutoNovo;
  var
    LFornecedor, LNota, LProduto, LMapId: Int64;
    LChave, LArquivo, LCodigo: string;
    LIncluidos, LSem, LQtd: Integer;
    LMap: TImportacaoXmlMapService;
  begin
    LFornecedor := 0;
    LNota := 0;
    LProduto := 0;
    LMapId := 0;
    LCodigo := 'NOVO' + Copy(LSufixo, 1, 9);
    PrepararXmlSemProduto(LCodigo, LFornecedor, LChave, LArquivo);
    try
      AssertTrue(TNFeImportService.Importar(LArquivo, LNota,
        LIncluidos, LSem) and (LSem = 1),
        'XML sem produto deve gerar pendência');

      LMap := TImportacaoXmlMapService.Create;
      try
        LQuery.Close;
        LQuery.SQL.Text :=
          'SELECT ID FROM IMPORTACAO_XML_ITEM WHERE NOTA_ENTRADA_ID = :ID';
        LQuery.ParamByName('ID').AsLargeInt := LNota;
        LQuery.Open;
        LMapId := LQuery.FieldByName('ID').AsLargeInt;
        LQuery.Close;

        LProduto := LMap.CriarProdutoDoItem(LMapId, 12.5);
        AssertTrue(LProduto > 0, 'cadastro manual deve criar produto');

        { reprocessar a mesma chave/código não duplica o rastro nem
          desfaz o produto escolhido }
        LMap.RegistrarItem(LChave, '55', 'NACIONAL', '',
          'PRODUTO SEM CADASTRO & TESTE', LCodigo,
          'NCM 84713012; CFOP 1102; CST 00', '84713012', '1102',
          '00', '', 'UN', 3, 12.5, LNota, 0, LProduto, 'PENDENTE');
      finally
        LMap.Free;
      end;

      LQuery.Close;
      LQuery.SQL.Text :=
        'SELECT COUNT(*) AS QTD, MAX(SITUACAO) AS SIT, ' +
        ' MAX(PRODUTO_ID) AS PROD FROM IMPORTACAO_XML_ITEM ' +
        'WHERE EMPRESA_ID = :EMP AND CHAVE = :CHAVE';
      LQuery.ParamByName('EMP').AsLargeInt := LSessao.EmpresaId;
      LQuery.ParamByName('CHAVE').AsString := LChave;
      LQuery.Open;
      LQtd := LQuery.FieldByName('QTD').AsInteger;
      AssertTrue((LQtd = 1) and
        (Trim(LQuery.FieldByName('SIT').AsString) = 'NOVO') and
        (LQuery.FieldByName('PROD').AsLargeInt = LProduto),
        'reprocessamento deve reaproveitar o mapeamento do produto novo');
      LQuery.Close;

      LQuery.SQL.Text :=
        'SELECT NCM, DESCRICAO FROM PRODUTO WHERE ID = :ID';
      LQuery.ParamByName('ID').AsLargeInt := LProduto;
      LQuery.Open;
      AssertTrue((Trim(LQuery.FieldByName('NCM').AsString) = '84713012') and
        (Trim(LQuery.FieldByName('DESCRICAO').AsString) =
          'PRODUTO SEM CADASTRO & TESTE'),
        'produto novo deve ser pré-preenchido com os dados do XML');
      LQuery.Close;
      ASuite.AddResult('TestImportacaoXmlCriaProdutoNovo', True, '');
    except
      on E: Exception do
        ASuite.AddResult('TestImportacaoXmlCriaProdutoNovo', False, E.Message);
    end;
    LimparCenario(LNota, LFornecedor, LProduto, LArquivo);
  end;

  // ------------------------------------------------------------------
  // Limpeza
  // ------------------------------------------------------------------

  procedure ExecSufixo(const ASQL: string);
  begin
    LQuery.Close;
    LQuery.SQL.Text := ASQL;
    LQuery.ParamByName('P1').AsString := LSufixo;
    LQuery.ExecSQL;
    LConexao.Confirmar;
  end;

  procedure LimparSobraPorSufixo;
  begin
    try
      ExecSufixo('DELETE FROM PEDIDO_VENDA WHERE OBSERVACOES CONTAINING :P1');
    except
    end;
    try
      ExecSufixo('DELETE FROM PESSOA WHERE NOME CONTAINING :P1');
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
  LHelper := nil;
  LSufixo := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSeq := 0;
  LCertificado := 'C:\certificados\teste.pfx';
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

    // resíduo de execução anterior interrompida
    LimparSobraPorSufixo;

    WriteLn('========================================');
    WriteLn('EXECUTANDO TESTES DA NF-e');
    WriteLn('========================================');

    LCliente := CriarPessoa(NovoNome('CLIENTE NFE'), LSessao.EmpresaId);
    LClienteOutraEmpresa := CriarPessoa(NovoNome('CLIENTE NFE OUTRA'),
      999999);

    TestConfigurar;
    TestGerarSemCertificado;
    TestGerarSemSenha;
    TestGerarPedidoInexistente;
    TestGerarOutraEmpresa;
    TestGerarGravaNumeroChave;
    TestGerarSequencial;
    TestGerarNumeroEscopoEmpresa;
    TestGerarAtualizaSoPedido;
    TestGerarAuditoria;
    TestGerarNFCe;
    TestConsultarSemConfiguracao;
    TestConsultarComConfiguracao;
    TestCancelarJustificativaCurta;
    TestCancelarComConfiguracao;
    TestManifestarSemConfiguracao;
    TestManifestarComConfiguracao;
    TestCartaCorrecaoCurta;
    TestCartaCorrecaoChaveInvalida;
    TestCartaCorrecaoComConfiguracao;
    TestInutilizarJustificativaCurta;
    TestInutilizarFaixaInvalida;
    TestInutilizarComConfiguracao;
    TestProximaSequenciaCce;
    TestDANFEChaveInvalida;
    TestDANFEModoSimulado;
    TestCarregarConfiguracaoFiscal;
    TestModoHomologacao;
    TestDestinatarioOpcionalNFCe;
    TestImportarXmlNotaEntrada;
    TestImportacaoXmlRastroItem;
    TestImportacaoXmlMapeiaProdutoExistente;
    TestImportacaoXmlCriaProdutoNovo;
  finally
    LimparSobraPorSufixo;
    LHelper.Free;
    LQuery.Free;
  end;
end;

end.
