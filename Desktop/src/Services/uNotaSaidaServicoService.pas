unit uNotaSaidaServicoService;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Nota de Saída de Serviço (marco 3.92)
  ------------------------------------------------------------
  Service da tabela resumida NOTA_SAIDA_SERVICO. É um documento
  de serviço "diverso": não nasce de pedido, não mexe estoque e
  não gera conta a receber automaticamente.

  Fluxo:
    Criar -> GerarXML -> (opcional) Cancelar

  GerarXML usa TNFSeHelper. Em NFSE_MODO=SIMULADO o XML é gerado
  sem certificado (modo desenvolvedor) e a nota fica VALIDADA. Em
  NFSE_MODO=REAL o XML é assinado e fica ASSINADA. Nunca há envio
  à prefeitura/SEFAZ neste marco.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao, uTNFSeHelper;

type
  ENotaSaidaServico = class(Exception);

  TNotaSaidaServicoService = class
  private
    FConexao: TConexao;
    function NovaConsulta: TSQLQuery;
    function ProximoNumero(const ASerie: string): Integer;
    function Carregar(AId: Int64; out ADados: TNFSeDados): Boolean;
    procedure GravarArquivo(const ACaminho, AXml: string);
    procedure Auditar(AId: Int64; const AOperacao, AResumo: string);
  public
    constructor Create;

    { Cria uma nota resumida na empresa da sessão. O número é
      sequencial por empresa + série. }
    function Criar(const AMunicipioIBGE, ACodigoServico, ADescricaoServico: string;
      AValorServico, ADesconto, AAliquotaISS: Double;
      const ATipoRetencaoISS: string; APessoaId: Int64;
      AValorRetPIS, AValorRetCOFINS, AValorRetINSS: Double): Int64;

    { Gera/valida a DPS e grava o XML em bin\xml\nfse. Devolve o XML
      e o caminho do arquivo. }
    function GerarXML(AId: Int64; const ASenhaCertificado: string;
      out AXml, ACaminhoArquivo, AMensagem: string): Boolean;

    function Cancelar(AId: Int64; const AMotivo: string): Boolean;
  end;

implementation

uses
  DateUtils, uSessao, uAuditoria, uConfiguracaoService, uNFSeXmlCrypto;

const
  TABELA_AUDITORIA = 'NFSE';

function SoDigitosService(const AValor: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValor) do
    if AValor[I] in ['0'..'9'] then
      Result := Result + AValor[I];
end;

constructor TNotaSaidaServicoService.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
end;

function TNotaSaidaServicoService.NovaConsulta: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConexao.Connection;
  Result.Transaction := FConexao.Transaction;
end;

function TNotaSaidaServicoService.ProximoNumero(const ASerie: string): Integer;
var
  LQuery: TSQLQuery;
begin
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COALESCE(MAX(NUMERO), 0) + 1 AS PROXIMO ' +
      'FROM NOTA_SAIDA_SERVICO WHERE EMPRESA_ID = :EMP AND SERIE = :SER';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('SER').AsString := ASerie;
    LQuery.Open;
    Result := LQuery.FieldByName('PROXIMO').AsInteger;
  finally
    LQuery.Free;
  end;
end;

function TNotaSaidaServicoService.Criar(const AMunicipioIBGE, ACodigoServico,
  ADescricaoServico: string; AValorServico, ADesconto, AAliquotaISS: Double;
  const ATipoRetencaoISS: string; APessoaId: Int64;
  AValorRetPIS, AValorRetCOFINS, AValorRetINSS: Double): Int64;
var
  LCfg: TConfiguracaoService;
  LQuery: TSQLQuery;
  LHelper: TNFSeHelper;
  LDps: TNFSeDados;
  LSerie, LMun, LUF, LIM, LProvedor, LIdDps: string;
  LNumero: Integer;
begin
  LMun := SoDigitosService(AMunicipioIBGE);
  if Length(LMun) <> 7 then
    raise ENotaSaidaServico.Create('Município IBGE deve ter 7 dígitos.');
  if Length(SoDigitosService(ACodigoServico)) <> 6 then
    raise ENotaSaidaServico.Create('Código de serviço deve ter 6 dígitos.');
  if Trim(ADescricaoServico) = '' then
    raise ENotaSaidaServico.Create('Descrição do serviço é obrigatória.');
  if (AValorServico - ADesconto) <= 0 then
    raise ENotaSaidaServico.Create('Valor do serviço após desconto deve ser maior que zero.');
  if (ATipoRetencaoISS <> '1') and (ATipoRetencaoISS <> '2') and
     (ATipoRetencaoISS <> '3') then
    raise ENotaSaidaServico.Create('Tipo de retenção de ISS inválido.');

  LCfg := TConfiguracaoService.Create;
  try
    LSerie := Copy(SoDigitosService(LCfg.LerValor('NFSE_SERIE')), 1, 5);
    if LSerie = '' then
      LSerie := '1';
    LIM := Trim(LCfg.LerValor('NFSE_INSCRICAO_MUNICIPAL'));
    LProvedor := Trim(LCfg.LerValor('NFSE_PROVEDOR'));
    if LProvedor = '' then
      LProvedor := 'NACIONAL';
  finally
    LCfg.Free;
  end;

  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COALESCE(UF, '''') AS UF FROM EMPRESA WHERE ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      LUF := UpperCase(Trim(LQuery.FieldByName('UF').AsString))
    else
      LUF := '';
  finally
    LQuery.Free;
  end;

  LQuery := NovaConsulta;
  try
    FConexao.IniciarTransacao;
    try
      LNumero := ProximoNumero(LSerie);

      { O Firebird 5 indexa NULL como valor repetido em índice UNIQUE.
        Por isso o ID_DPS é gerado já no INSERT: além do dedupe, evita
        que duas notas recém-criadas (sem XML) violem UQ_NSS_EMP_ID_DPS. }
      LHelper := TNFSeHelper.Create;
      try
        LDps := Default(TNFSeDados);
        LDps.MunicipioIBGE := LMun;
        LDps.Serie := LSerie;
        LDps.Numero := LNumero;
        LIdDps := LHelper.GerarIdDPS(LDps);
      finally
        LHelper.Free;
      end;

      LQuery.SQL.Text :=
        'INSERT INTO NOTA_SAIDA_SERVICO ' +
        '(EMPRESA_ID, PESSOA_ID, NUMERO, SERIE, MUNICIPIO_IBGE, UF, ' +
        ' INSCRICAO_MUNICIPAL, CODIGO_SERVICO, DESCRICAO_SERVICO, ' +
        ' VALOR_SERVICO, DESCONTO, ALIQUOTA_ISS, VALOR_ISS, ' +
        ' TIPO_RETENCAO_ISS, VALOR_RET_PIS, VALOR_RET_COFINS, ' +
        ' VALOR_RET_INSS, PROVEDOR, ID_DPS, SITUACAO, USUARIO_ID) ' +
        'VALUES (:EMP, :PES, :NUM, :SER, :MUN, :UF, :IM, :CSERV, :DESC, ' +
        ' :VAL, :DESCVAL, :ALIQ, :VALISS, :TPRET, :PIS, :COFINS, :INSS, ' +
        ' :PROV, :IDDPS, ''GERADA'', :USR) RETURNING ID';
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      if APessoaId > 0 then
        LQuery.ParamByName('PES').AsLargeInt := APessoaId
      else
        LQuery.ParamByName('PES').Clear;
      LQuery.ParamByName('NUM').AsInteger := LNumero;
      LQuery.ParamByName('SER').AsString := LSerie;
      LQuery.ParamByName('MUN').AsString := LMun;
      LQuery.ParamByName('UF').AsString := LUF;
      LQuery.ParamByName('IM').AsString := LIM;
      LQuery.ParamByName('CSERV').AsString := SoDigitosService(ACodigoServico);
      LQuery.ParamByName('DESC').AsString := Trim(ADescricaoServico);
      LQuery.ParamByName('VAL').AsFloat := AValorServico;
      LQuery.ParamByName('DESCVAL').AsFloat := ADesconto;
      LQuery.ParamByName('ALIQ').AsFloat := AAliquotaISS;
      LQuery.ParamByName('VALISS').AsFloat :=
        (AValorServico - ADesconto) * AAliquotaISS / 100;
      LQuery.ParamByName('TPRET').AsString := ATipoRetencaoISS;
      LQuery.ParamByName('PIS').AsFloat := AValorRetPIS;
      LQuery.ParamByName('COFINS').AsFloat := AValorRetCOFINS;
      LQuery.ParamByName('INSS').AsFloat := AValorRetINSS;
      LQuery.ParamByName('PROV').AsString := LProvedor;
      LQuery.ParamByName('IDDPS').AsString := LIdDps;
      LQuery.ParamByName('USR').AsLargeInt := TSessao.GetInstance.UsuarioId;
      LQuery.Open;
      Result := LQuery.FieldByName('ID').AsLargeInt;
      LQuery.Close;

      Auditar(Result, 'GERAR', 'SITUACAO=GERADA; SERIE=' + LSerie +
        '; NUMERO=' + IntToStr(LNumero));
      FConexao.Confirmar;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNotaSaidaServicoService.Carregar(AId: Int64;
  out ADados: TNFSeDados): Boolean;
var
  LQuery: TSQLQuery;
begin
  ADados := Default(TNFSeDados);
  Result := False;
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT N.ID, N.NUMERO, N.SERIE, N.DATA_EMISSAO, N.DATA_COMPETENCIA, ' +
      '  N.MUNICIPIO_IBGE, N.UF, N.INSCRICAO_MUNICIPAL, N.CODIGO_SERVICO, ' +
      '  N.DESCRICAO_SERVICO, N.VALOR_SERVICO, N.DESCONTO, N.ALIQUOTA_ISS, ' +
      '  N.TIPO_RETENCAO_ISS, N.VALOR_RET_PIS, N.VALOR_RET_COFINS, ' +
      '  N.VALOR_RET_INSS, N.SITUACAO, ' +
      '  COALESCE(P.CPF_CNPJ, '''') AS DOC, COALESCE(P.NOME, '''') AS NOME ' +
      'FROM NOTA_SAIDA_SERVICO N LEFT JOIN PESSOA P ON P.ID = N.PESSOA_ID ' +
      'WHERE N.ID = :ID AND N.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      Exit;

    ADados.Numero := LQuery.FieldByName('NUMERO').AsInteger;
    ADados.Serie := Trim(LQuery.FieldByName('SERIE').AsString);
    ADados.DataEmissao := LQuery.FieldByName('DATA_EMISSAO').AsDateTime;
    ADados.DataCompetencia := LQuery.FieldByName('DATA_COMPETENCIA').AsDateTime;
    ADados.MunicipioIBGE := Trim(LQuery.FieldByName('MUNICIPIO_IBGE').AsString);
    ADados.UF := Trim(LQuery.FieldByName('UF').AsString);
    ADados.InscricaoMunicipal := Trim(LQuery.FieldByName('INSCRICAO_MUNICIPAL').AsString);
    ADados.CodigoServico := Trim(LQuery.FieldByName('CODIGO_SERVICO').AsString);
    ADados.DescricaoServico := Trim(LQuery.FieldByName('DESCRICAO_SERVICO').AsString);
    ADados.ValorServico := LQuery.FieldByName('VALOR_SERVICO').AsFloat;
    ADados.Desconto := LQuery.FieldByName('DESCONTO').AsFloat;
    ADados.AliquotaISS := LQuery.FieldByName('ALIQUOTA_ISS').AsFloat;
    ADados.TipoRetencaoISS := Trim(LQuery.FieldByName('TIPO_RETENCAO_ISS').AsString);
    ADados.ValorRetPIS := LQuery.FieldByName('VALOR_RET_PIS').AsFloat;
    ADados.ValorRetCOFINS := LQuery.FieldByName('VALOR_RET_COFINS').AsFloat;
    ADados.ValorRetINSS := LQuery.FieldByName('VALOR_RET_INSS').AsFloat;
    ADados.TomadorDocumento := SoDigitosService(LQuery.FieldByName('DOC').AsString);
    ADados.TomadorNome := Trim(LQuery.FieldByName('NOME').AsString);
    Result := True;
  finally
    LQuery.Free;
  end;
end;

procedure TNotaSaidaServicoService.GravarArquivo(const ACaminho,
  AXml: string);
var
  LStream: TFileStream;
begin
  ForceDirectories(ExtractFilePath(ACaminho));
  LStream := TFileStream.Create(ACaminho, fmCreate);
  try
    if AXml <> '' then
      LStream.WriteBuffer(AXml[1], Length(AXml));
  finally
    LStream.Free;
  end;
end;

procedure TNotaSaidaServicoService.Auditar(AId: Int64;
  const AOperacao, AResumo: string);
begin
  RegistrarAuditoria(TABELA_AUDITORIA, AOperacao, AId, '', AResumo);
end;

function TNotaSaidaServicoService.GerarXML(AId: Int64;
  const ASenhaCertificado: string; out AXml, ACaminhoArquivo,
  AMensagem: string): Boolean;
var
  LHelper: TNFSeHelper;
  LQuery: TSQLQuery;
  LDados: TNFSeDados;
  LSituacao, LIdDps, LNomeArquivo, LResumo: string;
begin
  Result := False;
  AXml := '';
  ACaminhoArquivo := '';
  AMensagem := '';

  if AId <= 0 then
    raise ENotaSaidaServico.Create('Nota de serviço: ID inválido.');
  if not Carregar(AId, LDados) then
    raise ENotaSaidaServico.Create('Nota de serviço não encontrada para a empresa.');

  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT SITUACAO FROM NOTA_SAIDA_SERVICO ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise ENotaSaidaServico.Create('Nota de serviço não encontrada.');
    LSituacao := Trim(LQuery.FieldByName('SITUACAO').AsString);
  finally
    LQuery.Free;
  end;

  if LSituacao = 'CANCELADA' then
    raise ENotaSaidaServico.Create('Nota cancelada não pode gerar XML.');
  if (LSituacao = 'EMITIDA') and (not NFSeXmlDisponivel) then
    raise ENotaSaidaServico.Create('Nota já emitida não pode ser regenerada.');

  { Dedupe explícito antes de gerar: a unique index já protege o banco. }
  LQuery := NovaConsulta;
  try
    LQuery.SQL.Text :=
      'SELECT COUNT(*) AS QTD FROM NOTA_SAIDA_SERVICO ' +
      'WHERE EMPRESA_ID = :EMP AND SERIE = :SER AND NUMERO = :NUM ' +
      '  AND ID <> :ID';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.ParamByName('SER').AsString := LDados.Serie;
    LQuery.ParamByName('NUM').AsInteger := LDados.Numero;
    LQuery.ParamByName('ID').AsLargeInt := AId;
    LQuery.Open;
    if LQuery.FieldByName('QTD').AsInteger > 0 then
      raise ENotaSaidaServico.Create(
        'Duplicidade de série/número da nota de serviço.');
  finally
    LQuery.Free;
  end;

  LHelper := TNFSeHelper.Create;
  try
    if not LHelper.GerarDPS(LDados, ASenhaCertificado, AXml, AMensagem) then
      Exit;

    if LHelper.Modo = 'REAL' then
      LSituacao := 'ASSINADA'
    else
      LSituacao := 'VALIDADA';

    LHelper.CarregarConfiguracao;
    LIdDps := LHelper.GerarIdDPS(LDados);
    { GerarIdDPS depende de PrestadorCnpj resolvido; quando o chamador
      passou o record cru, recarrega a empresa via uma nova DPS. }
    if Pos('DPS', LIdDps) <> 1 then
      LIdDps := '';

    LNomeArquivo := 'nfse_' +
      IntToStr(TSessao.GetInstance.EmpresaId) + '_' +
      StringReplace(LDados.Serie, '\', '', [rfReplaceAll]) + '_' +
      IntToStr(LDados.Numero) + '.xml';
    ACaminhoArquivo := ExtractFilePath(ParamStr(0)) + 'xml\nfse\' + LNomeArquivo;
    GravarArquivo(ACaminhoArquivo, AXml);

    LQuery := NovaConsulta;
    try
      FConexao.IniciarTransacao;
      try
        LQuery.SQL.Text :=
          'UPDATE NOTA_SAIDA_SERVICO SET ID_DPS = :IDDPS, ' +
          '  XML_ARQUIVO = :ARQ, SITUACAO = :SIT, OBSERVACAO = :OBS ' +
          'WHERE ID = :ID AND EMPRESA_ID = :EMP';
        if LIdDps <> '' then
          LQuery.ParamByName('IDDPS').AsString := LIdDps
        else
          LQuery.ParamByName('IDDPS').Clear;
        LQuery.ParamByName('ARQ').AsString := ACaminhoArquivo;
        LQuery.ParamByName('SIT').AsString := LSituacao;
        LQuery.ParamByName('OBS').AsString := AMensagem;
        LQuery.ParamByName('ID').AsLargeInt := AId;
        LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
        LQuery.ExecSQL;

        LResumo := 'PROVEDOR=' + LHelper.Provedor + '; AMBIENTE=' +
          LHelper.Ambiente + '; ID_DPS=' + LIdDps + '; RPS=' +
          LDados.Serie + '/' + IntToStr(LDados.Numero) + '; RESULTADO=' +
          LSituacao;
        Auditar(AId, 'GERAR', LResumo);
        FConexao.Confirmar;
      except
        FConexao.Cancelar;
        raise;
      end;
    finally
      LQuery.Free;
    end;
  finally
    LHelper.Free;
  end;

  Result := True;
end;

function TNotaSaidaServicoService.Cancelar(AId: Int64;
  const AMotivo: string): Boolean;
var
  LQuery: TSQLQuery;
  LAfetados: Integer;
begin
  if AId <= 0 then
    raise ENotaSaidaServico.Create('Nota de serviço: ID inválido.');
  if Trim(AMotivo) = '' then
    raise ENotaSaidaServico.Create('Motivo do cancelamento é obrigatório.');

  LQuery := NovaConsulta;
  try
    FConexao.IniciarTransacao;
    try
      LQuery.SQL.Text :=
        'UPDATE NOTA_SAIDA_SERVICO SET SITUACAO = ''CANCELADA'', ' +
        '  OBSERVACAO = :OBS WHERE ID = :ID AND EMPRESA_ID = :EMP ' +
        '  AND SITUACAO <> ''CANCELADA''';
      LQuery.ParamByName('OBS').AsString := Copy('CANCELADO: ' + Trim(AMotivo), 1, 500);
      LQuery.ParamByName('ID').AsLargeInt := AId;
      LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
      LQuery.ExecSQL;
      LAfetados := LQuery.RowsAffected;
      if LAfetados > 0 then
        Auditar(AId, 'CANCELAR', 'SITUACAO=CANCELADA');
      FConexao.Confirmar;
      Result := LAfetados > 0;
    except
      FConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

end.
