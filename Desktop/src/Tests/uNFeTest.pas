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
  Classes, SysUtils, SQLDB, uAssert, uConexao, uSessao, uACBrHelper;

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
  finally
    LimparSobraPorSufixo;
    LHelper.Free;
    LQuery.Free;
  end;
end;

end.
