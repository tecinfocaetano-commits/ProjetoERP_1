unit uACBrHelper;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 6 - ACBr Helper
  Descrição: Wrapper para integração com ACBr (NF-e, NFC-e)

  O modo simulado (padrão) é usado pelos testes e não depende
  do ACBr. O modo real só é compilado quando o aplicativo define
  ACBR (ERP2026.lpi) e exige certificado, schemas e dados
  fiscais completos no banco.
  ============================================================ }

interface

uses
  Classes, SysUtils
{$IFDEF ACBR}
  , ACBrNFe, ACBrNFeNotasFiscais, ACBrNFe.Classes,
  ACBrDFeConfiguracoes, ACBrDFeSSL, ACBrDFeUtil,
  pcnConversao, pcnConversaoNFe
{$ENDIF}
  ;

type
  TACBrStatusNFe = (ansNenhum, ansPendente, ansAutorizada, ansCancelada, ansDenegada);

  TACBrDadosNFe = record
    Numero: Integer;
    Serie: Integer;
    NaturezaOperacao: string;
    CFOP: string;
    ChaveAcesso: string;
    Status: TACBrStatusNFe;
    Protocolo: string;
    XML: string;
    cStat: Integer;
    Motivo: string;
    { F2: nota de saída materializada depois da autorização (0 = nenhuma,
      como na emissão simulada) }
    NotaSaidaId: Int64;
  end;

  { TACBrHelper }
  TACBrHelper = class
  private
    FCaminhoSchemas: string;
    FCaminhoSalvar: string;
    FCaminhoCertificado: string;
    FSenhaCertificado: string;
    FAmbiente: Integer; // 1=Produção, 2=Homologação
    FUF: string;
    FModoSimulado: Boolean;
    FIdCSC: string;
    FCSC: string;
{$IFDEF ACBR}
    FACBrNFe: TACBrNFe;
{$ENDIF}
    procedure ValidarConfiguracao;
    function GerarSimulada(APedidoId: Int64; const ANatureza: string): TACBrDadosNFe;
{$IFDEF ACBR}
    function GetACBrNFe: TACBrNFe;
    procedure ConfigurarACBr(AExigirCertificado: Boolean = True);
    function EmitirReal(APedidoId: Int64; const ANatureza: string;
      AModelo: Integer; ASomenteValidar: Boolean = False): TACBrDadosNFe;
    function ConsultarReal(const AChave: string): TACBrDadosNFe;
    function CancelarReal(const AChave, AJustificativa: string): Boolean;
    function ManifestarReal(const AChave: string;
      ATipoManifestacao: Integer): Boolean;
{$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;

    procedure Configurar(const ACaminhoCert, ASenha, AUF: string;
      AAmbiente: Integer);

    function GerarNFe(APedidoId: Int64): TACBrDadosNFe;
    function GerarNFCe(APedidoId: Int64): TACBrDadosNFe;
    { Monta o XML e valida contra os schemas sem enviar à SEFAZ. Com
      certificado configurado, assina e valida o XML completo; sem
      certificado, confere apenas os dados fiscais. Útil antes da
      emissão real. }
    function ValidarNFe(APedidoId: Int64): TACBrDadosNFe;
    function ConsultarNFe(const AChave: string): TACBrDadosNFe;
    function CancelarNFe(const AChave, AJustificativa: string): Boolean;
    function ImportarXML(const ACaminhoXML: string): Int64;
    function ManifestarNFe(const AChave: string;
      ATipoManifestacao: Integer): Boolean;

    property CaminhoSchemas: string read FCaminhoSchemas write FCaminhoSchemas;
    property CaminhoSalvar: string read FCaminhoSalvar write FCaminhoSalvar;
    property CaminhoCertificado: string read FCaminhoCertificado;
    property SenhaCertificado: string read FSenhaCertificado
      write FSenhaCertificado;
    property Ambiente: Integer read FAmbiente;
    property UF: string read FUF;
    property ModoSimulado: Boolean read FModoSimulado write FModoSimulado;
    property IdCSC: string read FIdCSC write FIdCSC;
    property CSC: string read FCSC write FCSC;
  end;

implementation

uses
  uConexao, SQLDB, uAuditoria, uSessao, uNFeXmlService, uNotaSaidaService;

{$IFDEF ACBR}
{ ------------------------------------------------------------------
  Funções auxiliares do modo real
  ------------------------------------------------------------------ }

function SomenteDigitos(const AValor: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValor) do
    if AValor[I] in ['0'..'9'] then
      Result := Result + AValor[I];
end;

function EANValido(const AValor: string): Boolean;
var
  LDigitos: string;
begin
  LDigitos := SomenteDigitos(AValor);
  Result := Length(LDigitos) in [8, 12, 13, 14];
end;

function StatusPorCStat(ACStat: Integer): TACBrStatusNFe;
begin
  case ACStat of
    100, 150:
      Result := ansAutorizada;
    101, 135, 151, 155:
      Result := ansCancelada;
    110, 301, 302, 303:
      Result := ansDenegada;
  else
    Result := ansPendente;
  end;
end;

function FormaPagamentoPorTipo(const ATipo: string): TpcnFormaPagamento;
begin
  if ATipo = 'DI' then
    Result := fpDinheiro
  else if ATipo = 'CC' then
    Result := fpCartaoCredito
  else if ATipo = 'CD' then
    Result := fpCartaoDebito
  else if ATipo = 'PI' then
    Result := fpPagamentoInstantaneo
  else if ATipo = 'BO' then
    Result := fpBoletoBancario
  else if ATipo = 'CH' then
    Result := fpCheque
  else if ATipo = 'TR' then
    Result := fpTransfBancario
  else
    Result := fpOutro;
end;

function TipoEventoManifestacao(ACodigo: Integer): TpcnTpEvento;
begin
  case ACodigo of
    210200:
      Result := teManifDestConfirmacao;
    210210:
      Result := teManifDestCiencia;
    210220:
      Result := teManifDestDesconhecimento;
    210240:
      Result := teManifDestOperNaoRealizada;
  else
    raise Exception.CreateFmt('Tipo de manifestação inválido: %d', [ACodigo]);
  end;
end;

{ Resolve o código IBGE e a UF de uma cidade. Se ACidadeId > 0 usa
  o vínculo direto; caso contrário procura pelo nome + UF. }
procedure ResolverCidade(AQuery: TSQLQuery; ACidadeId: Int64;
  const ACidade, AUF: string; out ACodigoIBGE: Integer;
  out AUFResolvida: string);
begin
  ACodigoIBGE := 0;
  AUFResolvida := AUF;

  AQuery.Close;
  if ACidadeId > 0 then
  begin
    AQuery.SQL.Text :=
      'SELECT C.CODIGO_IBGE, E.UF FROM CIDADE C ' +
      'JOIN ESTADO E ON E.ID = C.ESTADO_ID WHERE C.ID = :ID';
    AQuery.ParamByName('ID').AsLargeInt := ACidadeId;
  end
  else
  begin
    AQuery.SQL.Text :=
      'SELECT C.CODIGO_IBGE, E.UF FROM CIDADE C ' +
      'JOIN ESTADO E ON E.ID = C.ESTADO_ID ' +
      'WHERE C.NOME = :NOME AND E.UF = :UF';
    AQuery.ParamByName('NOME').AsString := ACidade;
    AQuery.ParamByName('UF').AsString := AUF;
  end;
  AQuery.Open;

  if AQuery.IsEmpty then
    raise Exception.CreateFmt(
      'Cidade não encontrada no cadastro: %s/%s', [ACidade, AUF]);

  ACodigoIBGE := StrToIntDef(
    Trim(AQuery.FieldByName('CODIGO_IBGE').AsString), 0);
  AUFResolvida := Trim(AQuery.FieldByName('UF').AsString);
  AQuery.Close;

  if ACodigoIBGE = 0 then
    raise Exception.CreateFmt(
      'Cidade sem código IBGE: %s/%s', [ACidade, AUF]);
end;
{$ENDIF}

constructor TACBrHelper.Create;
begin
  inherited Create;
  FAmbiente := 2; // Homologação por padrão
  FUF := 'SP';
  FModoSimulado := True;
  FCaminhoSchemas := IncludeTrailingPathDelimiter(
    ExtractFilePath(ParamStr(0))) + 'schemas';
  FCaminhoSalvar := IncludeTrailingPathDelimiter(
    ExtractFilePath(ParamStr(0))) + 'nfe';
end;

destructor TACBrHelper.Destroy;
begin
{$IFDEF ACBR}
  FreeAndNil(FACBrNFe);
{$ENDIF}
  inherited Destroy;
end;

procedure TACBrHelper.Configurar(const ACaminhoCert, ASenha, AUF: string;
  AAmbiente: Integer);
begin
  FCaminhoCertificado := ACaminhoCert;
  FSenhaCertificado := ASenha;
  FUF := AUF;
  FAmbiente := AAmbiente;
end;

procedure TACBrHelper.ValidarConfiguracao;
begin
  if FCaminhoCertificado = '' then
    raise Exception.Create('Certificado digital não configurado.');
  if FSenhaCertificado = '' then
    raise Exception.Create('Senha do certificado não informada.');
end;

{ ------------------------------------------------------------------
  Emissão simulada (usada pelos testes e pelo modo simulado da tela)
  ------------------------------------------------------------------ }
function TACBrHelper.GerarSimulada(APedidoId: Int64;
  const ANatureza: string): TACBrDadosNFe;
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
begin
  ValidarConfiguracao;
  LConexao := TConexao.GetInstance;
  Result.Status := ansPendente;
  Result.cStat := 0;
  Result.Motivo := '';
  Result.NotaSaidaId := 0;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;

    // Carregar dados do pedido
    LQuery.SQL.Text :=
      'SELECT PV.*, C.NOME, C.CPF_CNPJ, C.ENDERECO, C.NUMERO, C.BAIRRO, ' +
      'C.CIDADE, C.UF, C.CEP, E.RAZAO_SOCIAL AS EMPRESA_RAZAO, ' +
      'E.CNPJ AS EMPRESA_CNPJ ' +
      'FROM PEDIDO_VENDA PV ' +
      'JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
      '  AND C.EMPRESA_ID = PV.EMPRESA_ID ' +
      'JOIN EMPRESA E ON E.ID = PV.EMPRESA_ID ' +
      'WHERE PV.ID = :ID AND PV.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;

    if LQuery.IsEmpty then
      raise Exception.Create('Pedido não encontrado.');

    // Gerar próximo número
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COALESCE(MAX(NUMERO_NFE), 0) + 1 FROM PEDIDO_VENDA ' +
      'WHERE NUMERO_NFE IS NOT NULL AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    Result.Numero := LQuery.Fields[0].AsInteger;
    Result.Serie := 1;
    Result.NaturezaOperacao := ANatureza;
    Result.CFOP := '5102';

    Result.ChaveAcesso := Format('%s%s%s%s',
      [FormatDateTime('yymm', Now),
       IntToStr(Result.Numero),
       IntToStr(Random(999999)),
       IntToStr(Random(999999))]);
    Result.Protocolo := 'SIM' + IntToStr(Random(9999999));
    Result.Status := ansPendente;
    Result.XML := '<nfeProc><!-- XML será gerado pelo ACBr --></nfeProc>';

    // Atualizar pedido com dados da NF-e (transação + auditoria)
    LQuery.Close;
    LQuery.SQL.Text :=
      'UPDATE PEDIDO_VENDA SET NUMERO_NFE = :NUM, CHAVE_NFE = :CHAVE ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('NUM').AsInteger := Result.Numero;
    LQuery.ParamByName('CHAVE').AsString := Result.ChaveAcesso;
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LConexao.IniciarTransacao;
    try
      LQuery.ExecSQL;
      RegistrarAuditoria('PEDIDO_VENDA', 'NFE', APedidoId, '',
        ResumoAuditoria(['NUMERO_NFE=' + IntToStr(Result.Numero),
          'CHAVE=' + Result.ChaveAcesso]));
      LConexao.Confirmar;
    except
      LConexao.Cancelar;
      raise;
    end;
  finally
    LQuery.Free;
  end;
end;

function TACBrHelper.GerarNFe(APedidoId: Int64): TACBrDadosNFe;
begin
  if FModoSimulado then
    Result := GerarSimulada(APedidoId, 'VENDA')
  else
  begin
{$IFDEF ACBR}
    Result := EmitirReal(APedidoId, 'VENDA', 55);
{$ELSE}
    raise Exception.Create(
      'Emissão real indisponível: recompile o aplicativo com o ACBr (-dACBR).');
{$ENDIF}
  end;
end;

function TACBrHelper.GerarNFCe(APedidoId: Int64): TACBrDadosNFe;
begin
  if FModoSimulado then
    Result := GerarSimulada(APedidoId, 'VENDA AO CONSUMIDOR')
  else
  begin
{$IFDEF ACBR}
    Result := EmitirReal(APedidoId, 'VENDA AO CONSUMIDOR', 65);
{$ELSE}
    raise Exception.Create(
      'Emissão real indisponível: recompile o aplicativo com o ACBr (-dACBR).');
{$ENDIF}
  end;
end;

function TACBrHelper.ValidarNFe(APedidoId: Int64): TACBrDadosNFe;
begin
{$IFDEF ACBR}
  { não envia nada e não exige certificado: só monta o XML e valida
    contra os schemas da NF-e }
  Result := EmitirReal(APedidoId, 'VENDA', 55, True);
{$ELSE}
  raise Exception.Create(
    'Validação local indisponível: recompile o aplicativo com o ACBr (-dACBR).');
{$ENDIF}
end;

function TACBrHelper.ConsultarNFe(const AChave: string): TACBrDadosNFe;
begin
  ValidarConfiguracao;
  Result.ChaveAcesso := AChave;
  Result.Status := ansPendente;
  Result.cStat := 0;
  Result.Motivo := '';

  if FModoSimulado then
    Exit;

{$IFDEF ACBR}
  Result := ConsultarReal(AChave);
{$ELSE}
  raise Exception.Create(
    'Consulta real indisponível: recompile o aplicativo com o ACBr (-dACBR).');
{$ENDIF}
end;

function TACBrHelper.CancelarNFe(const AChave, AJustificativa: string): Boolean;
begin
  ValidarConfiguracao;
  Result := False;

  if Length(AJustificativa) < 15 then
    raise Exception.Create('Justificativa deve ter no mínimo 15 caracteres.');

  if FModoSimulado then
    Exit;

{$IFDEF ACBR}
  Result := CancelarReal(AChave, AJustificativa);
{$ELSE}
  raise Exception.Create(
    'Cancelamento real indisponível: recompile o aplicativo com o ACBr (-dACBR).');
{$ENDIF}
end;

function TACBrHelper.ImportarXML(const ACaminhoXML: string): Int64;
var
  LIncluidos, LSemProduto: Integer;
begin
  { a importação real vive em uNFeXmlService (parser + nota de entrada);
    aqui mantemos só a fachada usada pela tela de NF-e }
  Result := 0;
  if not TNFeImportService.Importar(ACaminhoXML, Result,
    LIncluidos, LSemProduto) then
    Result := 0;
end;

function TACBrHelper.ManifestarNFe(const AChave: string;
  ATipoManifestacao: Integer): Boolean;
begin
  ValidarConfiguracao;
  Result := False;

  if FModoSimulado then
    Exit;

{$IFDEF ACBR}
  Result := ManifestarReal(AChave, ATipoManifestacao);
{$ELSE}
  raise Exception.Create(
    'Manifestação real indisponível: recompile o aplicativo com o ACBr (-dACBR).');
{$ENDIF}
end;

{$IFDEF ACBR}
{ ------------------------------------------------------------------
  Modo real (ACBr)
  ------------------------------------------------------------------ }

function TACBrHelper.GetACBrNFe: TACBrNFe;
begin
  if FACBrNFe = nil then
    FACBrNFe := TACBrNFe.Create(nil);
  Result := FACBrNFe;
end;

procedure TACBrHelper.ConfigurarACBr(AExigirCertificado: Boolean);
var
  LNFe: TACBrNFe;
begin
  if not DirectoryExists(FCaminhoSchemas) then
    raise Exception.Create(
      'Pasta de schemas da NF-e não encontrada: ' + FCaminhoSchemas +
      '. Execute Scripts\preparar_acbr.bat.');

  if AExigirCertificado and (not FileExists(FCaminhoCertificado)) then
    raise Exception.Create(
      'Certificado digital não encontrado: ' + FCaminhoCertificado);

  ForceDirectories(FCaminhoSalvar);

  LNFe := GetACBrNFe;
  LNFe.Configuracoes.Geral.SSLLib := libOpenSSL;
  LNFe.Configuracoes.Geral.SSLCryptLib := cryOpenSSL;
  LNFe.Configuracoes.Geral.SSLHttpLib := httpWinHttp;
  LNFe.Configuracoes.Geral.SSLXmlSignLib := xsLibXml2;
  LNFe.Configuracoes.Geral.Salvar := True;
  LNFe.Configuracoes.Geral.FormaEmissao := teNormal;
  LNFe.Configuracoes.Geral.VersaoDF := ve400;
  LNFe.Configuracoes.Arquivos.PathSchemas := FCaminhoSchemas;
  LNFe.Configuracoes.Arquivos.PathSalvar := FCaminhoSalvar;
  LNFe.Configuracoes.Certificados.ArquivoPFX := FCaminhoCertificado;
  LNFe.Configuracoes.Certificados.Senha := FSenhaCertificado;
  LNFe.Configuracoes.WebServices.UF := FUF;
  LNFe.Configuracoes.WebServices.Salvar := True;
  if FAmbiente = 1 then
    LNFe.Configuracoes.WebServices.Ambiente := taProducao
  else
    LNFe.Configuracoes.WebServices.Ambiente := taHomologacao;
end;

function TACBrHelper.EmitirReal(APedidoId: Int64; const ANatureza: string;
  AModelo: Integer; ASomenteValidar: Boolean): TACBrDadosNFe;
var
  LConexao: TConexao;
  LQuery, LItens, LCidade: TSQLQuery;
  LNFe: TACBrNFe;
  LNota: NotaFiscal;
  LDet: TDetCollectionItem;

  LEmpRazao, LEmpFantasia, LEmpCNPJ, LEmpIE, LEmpIM: string;
  LEmpLogradouro, LEmpNumero, LEmpComplemento, LEmpBairro: string;
  LEmpCidade, LEmpUF, LEmpCEP, LEmpTelefone: string;
  LEmpCRT: TpcnCRT;
  LEmpCodMun: Integer;
  LEmpUFResolvida: string;

  LCliNome, LCliDoc, LCliIE: string;
  LCliLogradouro, LCliNumero, LCliComplemento, LCliBairro: string;
  LCliCidade, LCliUF, LCliCEP, LCliTelefone, LCliEmail: string;
  LCliTipoPessoa: string;
  LCliCidadeId: Int64;
  LCliCodMun: Integer;
  LCliUFResolvida: string;

  LFormaTipo: string;
  LParcelas: Integer;
  LFormaPagamento: TpcnFormaPagamento;
  LIndPag: TpcnIndicadorPagamento;

  LNumero, LSerie: Integer;
  LPedidoNumero: string;
  LFaltando: string;

  LCodigo, LDescricao, LNCM, LCEST, LCFOP, LCSTICMS: string;
  LCSTPIS, LCSTCOFINS, LUnidade, LEAN: string;
  LQtd, LPreco, LValorProd, LValorDesc, LBaseICMS: Double;
  LAliqICMS, LAliqPIS, LAliqCOFINS: Double;
  LValorICMS, LValorPIS, LValorCOFINS: Double;
  LPesoL, LPesoB: Double;
  LItem: Integer;
  LOk: Boolean;
  LUsaCSOSN: Boolean;

  LTotalProd, LTotalDesc, LTotalICMS, LTotalPIS, LTotalCOFINS: Double;
  LBaseICMSTotal: Double;
  LValorNF: Double;
  LCStat: Integer;
  LMotivo: string;

  { F2: materialização da nota de saída após a autorização }
  LNotaSaida: TNotaSaidaService;
  LArquivoXml, LFaltandoDesc: string;
  LLista: TStringList;
  LSaldoDisp, LSaldoSol: Double;
begin
  if not ASomenteValidar then
    ValidarConfiguracao;
  ConfigurarACBr(not ASomenteValidar);
  LNFe := GetACBrNFe;

  LConexao := TConexao.GetInstance;
  Result := Default(TACBrDadosNFe);
  Result.NaturezaOperacao := ANatureza;
  Result.Serie := 1;
  Result.Status := ansPendente;
  Result.NotaSaidaId := 0;

  LQuery := TSQLQuery.Create(nil);
  LItens := TSQLQuery.Create(nil);
  LCidade := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LItens.DataBase := LConexao.Connection;
    LItens.Transaction := LConexao.Transaction;
    LCidade.DataBase := LConexao.Connection;
    LCidade.Transaction := LConexao.Transaction;

    // ---------------- Emitente ----------------
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, IE, IM, ' +
      '  ENDERECO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, CEP, ' +
      '  TELEFONE, CRT ' +
      'FROM EMPRESA WHERE ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Empresa da sessão não encontrada.');

    LEmpRazao := Trim(LQuery.FieldByName('RAZAO_SOCIAL').AsString);
    LEmpFantasia := Trim(LQuery.FieldByName('NOME_FANTASIA').AsString);
    LEmpCNPJ := SomenteDigitos(LQuery.FieldByName('CNPJ').AsString);
    LEmpIE := Trim(LQuery.FieldByName('IE').AsString);
    LEmpIM := Trim(LQuery.FieldByName('IM').AsString);
    LEmpLogradouro := Trim(LQuery.FieldByName('ENDERECO').AsString);
    LEmpNumero := Trim(LQuery.FieldByName('NUMERO').AsString);
    LEmpComplemento := Trim(LQuery.FieldByName('COMPLEMENTO').AsString);
    LEmpBairro := Trim(LQuery.FieldByName('BAIRRO').AsString);
    LEmpCidade := Trim(LQuery.FieldByName('CIDADE').AsString);
    LEmpUF := Trim(LQuery.FieldByName('UF').AsString);
    LEmpCEP := SomenteDigitos(LQuery.FieldByName('CEP').AsString);
    LEmpTelefone := SomenteDigitos(LQuery.FieldByName('TELEFONE').AsString);
    LOk := False;
    if not LQuery.FieldByName('CRT').IsNull then
      LEmpCRT := StrToCRT(LOk,
        IntToStr(LQuery.FieldByName('CRT').AsInteger));
    LQuery.Close;

    LFaltando := '';
    if LEmpRazao = '' then
      LFaltando := LFaltando + 'RAZAO_SOCIAL; ';
    if Length(LEmpCNPJ) <> 14 then
      LFaltando := LFaltando + 'CNPJ (14 dígitos); ';
    if LEmpIE = '' then
      LFaltando := LFaltando + 'IE; ';
    if LEmpLogradouro = '' then
      LFaltando := LFaltando + 'ENDERECO; ';
    if LEmpNumero = '' then
      LFaltando := LFaltando + 'NUMERO; ';
    if LEmpBairro = '' then
      LFaltando := LFaltando + 'BAIRRO; ';
    if LEmpCidade = '' then
      LFaltando := LFaltando + 'CIDADE; ';
    if LEmpUF = '' then
      LFaltando := LFaltando + 'UF; ';
    if Length(LEmpCEP) <> 8 then
      LFaltando := LFaltando + 'CEP (8 dígitos); ';
    if not LOk then
      LFaltando := LFaltando + 'CRT; ';
    if LFaltando <> '' then
      raise Exception.Create(
        'Dados fiscais da empresa incompletos: ' + LFaltando);

    LEmpUF := UpperCase(LEmpUF);
    if UFtoCUF(LEmpUF) = 0 then
      raise Exception.Create('UF da empresa inválida: ' + LEmpUF);
    ResolverCidade(LCidade, 0, LEmpCidade, LEmpUF, LEmpCodMun,
      LEmpUFResolvida);

    LUsaCSOSN := LEmpCRT in [crtSimplesNacional, crtMEI];

    // ---------------- Pedido / destinatário ----------------
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT PV.NUMERO AS PEDIDO_NUMERO, PV.FORMA_PAGAMENTO_ID, ' +
      '  PV.CONDICAO_PAGAMENTO_ID, ' +
      '  C.NOME, C.TIPO_PESSOA, C.CPF_CNPJ, C.RG_IE, C.ENDERECO, ' +
      '  C.NUMERO AS CLIENTE_NUMERO, C.COMPLEMENTO, C.BAIRRO, ' +
      '  C.CIDADE, C.CIDADE_ID, C.UF, C.CEP, C.TELEFONE, C.EMAIL ' +
      'FROM PEDIDO_VENDA PV ' +
      'JOIN PESSOA C ON C.ID = PV.CLIENTE_ID AND C.TIPO = ''C'' ' +
      '  AND C.EMPRESA_ID = PV.EMPRESA_ID ' +
      'WHERE PV.ID = :ID AND PV.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Pedido não encontrado.');

    LPedidoNumero := Trim(LQuery.FieldByName('PEDIDO_NUMERO').AsString);
    LCliNome := Trim(LQuery.FieldByName('NOME').AsString);
    LCliTipoPessoa := Trim(LQuery.FieldByName('TIPO_PESSOA').AsString);
    LCliDoc := SomenteDigitos(LQuery.FieldByName('CPF_CNPJ').AsString);
    LCliIE := Trim(LQuery.FieldByName('RG_IE').AsString);
    LCliLogradouro := Trim(LQuery.FieldByName('ENDERECO').AsString);
    LCliNumero := Trim(LQuery.FieldByName('CLIENTE_NUMERO').AsString);
    LCliComplemento := Trim(LQuery.FieldByName('COMPLEMENTO').AsString);
    LCliBairro := Trim(LQuery.FieldByName('BAIRRO').AsString);
    LCliCidade := Trim(LQuery.FieldByName('CIDADE').AsString);
    LCliCidadeId := LQuery.FieldByName('CIDADE_ID').AsLargeInt;
    LCliUF := Trim(LQuery.FieldByName('UF').AsString);
    LCliCEP := SomenteDigitos(LQuery.FieldByName('CEP').AsString);
    LCliTelefone := SomenteDigitos(LQuery.FieldByName('TELEFONE').AsString);
    LCliEmail := Trim(LQuery.FieldByName('EMAIL').AsString);
    LParcelas := 1;
    LQuery.Close;

    LFaltando := '';
    if LCliNome = '' then
      LFaltando := LFaltando + 'NOME; ';
    if not (Length(LCliDoc) in [11, 14]) then
      LFaltando := LFaltando + 'CPF/CNPJ; ';
    if LCliLogradouro = '' then
      LFaltando := LFaltando + 'ENDERECO; ';
    if LCliNumero = '' then
      LFaltando := LFaltando + 'NUMERO; ';
    if LCliBairro = '' then
      LFaltando := LFaltando + 'BAIRRO; ';
    if LCliCidade = '' then
      LFaltando := LFaltando + 'CIDADE; ';
    if LCliUF = '' then
      LFaltando := LFaltando + 'UF; ';
    if Length(LCliCEP) <> 8 then
      LFaltando := LFaltando + 'CEP (8 dígitos); ';
    if LFaltando <> '' then
      raise Exception.Create(
        'Dados do destinatário incompletos: ' + LFaltando);

    LCliUF := UpperCase(LCliUF);
    if UFtoCUF(LCliUF) = 0 then
      raise Exception.Create('UF do destinatário inválida: ' + LCliUF);
    ResolverCidade(LCidade, LCliCidadeId, LCliCidade, LCliUF,
      LCliCodMun, LCliUFResolvida);

    // Forma de pagamento e condição
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT F.TIPO, COALESCE(C.PARCELAS, 1) AS PARCELAS ' +
      'FROM PEDIDO_VENDA PV ' +
      'LEFT JOIN FORMA_PAGAMENTO F ON F.ID = PV.FORMA_PAGAMENTO_ID ' +
      'LEFT JOIN CONDICAO_PAGAMENTO C ON C.ID = PV.CONDICAO_PAGAMENTO_ID ' +
      'WHERE PV.ID = :ID AND PV.EMPRESA_ID = :EMP';
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      LFormaTipo := Trim(LQuery.FieldByName('TIPO').AsString);
      LParcelas := LQuery.FieldByName('PARCELAS').AsInteger;
    end;
    LQuery.Close;
    if LParcelas < 1 then
      LParcelas := 1;
    LFormaPagamento := FormaPagamentoPorTipo(LFormaTipo);
    if LParcelas > 1 then
      LIndPag := ipPrazo
    else
      LIndPag := ipVista;

    // ---------------- Numeração ----------------
    LQuery.Close;
    LQuery.SQL.Text :=
      'SELECT COALESCE(MAX(NUMERO_NFE), 0) + 1 FROM PEDIDO_VENDA ' +
      'WHERE NUMERO_NFE IS NOT NULL AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    LNumero := LQuery.Fields[0].AsInteger;
    LQuery.Close;
    LSerie := 1;
    Result.Numero := LNumero;
    Result.Serie := LSerie;
    Result.CFOP := '5102';

    // ---------------- Itens ----------------
    LItens.Close;
    LItens.SQL.Text :=
      'SELECT I.QUANTIDADE, I.PRECO_UNITARIO, I.VALOR_TOTAL, I.DESCONTO, ' +
      '  COALESCE(I.CFOP, PF.CFOP_VENDA, P.CFOP_VENDA, P.CFOP, ' +
      '    ''5102'') AS CFOP, ' +
      '  COALESCE(I.CST_ICMS, PF.CST_ICMS, P.CST_ICMS) AS CST_ICMS, ' +
      '  COALESCE(I.ALIQ_ICMS, PF.ALIQ_ICMS, P.ALIQ_ICMS, 0) AS ALIQ_ICMS, ' +
      '  COALESCE(I.VALOR_ICMS, 0) AS VALOR_ICMS, ' +
      '  P.CODIGO, P.CODIGO_BARRAS, P.DESCRICAO, ' +
      '  COALESCE(PF.NCM, P.NCM) AS NCM, ' +
      '  COALESCE(PF.CEST, P.CEST) AS CEST, ' +
      '  COALESCE(PF.CST_PIS, P.CST_PIS) AS CST_PIS, ' +
      '  COALESCE(PF.CST_COFINS, P.CST_COFINS) AS CST_COFINS, ' +
      '  COALESCE(PF.ALIQ_PIS, P.ALIQ_PIS, 0) AS ALIQ_PIS, ' +
      '  COALESCE(PF.ALIQ_COFINS, P.ALIQ_COFINS, 0) AS ALIQ_COFINS, ' +
      '  COALESCE(PF.PESO_LIQUIDO, P.PESO_LIQUIDO, 0) AS PESO_LIQUIDO, ' +
      '  COALESCE(PF.PESO_BRUTO, P.PESO_BRUTO, 0) AS PESO_BRUTO, ' +
      '  COALESCE(U.SIGLA, U.ABREVIATURA, ''UN'') AS UNIDADE ' +
      'FROM ITEM_PEDIDO I ' +
      'JOIN PRODUTO P ON P.ID = I.PRODUTO_ID ' +
      'LEFT JOIN PRODUTO_FISCAL PF ON PF.ID = P.PRODUTO_FISCAL_ID ' +
      'LEFT JOIN UNIDADE U ON U.ID = P.UNIDADE_ID ' +
      'WHERE I.PEDIDO_VENDA_ID = :ID ORDER BY I.ID';
    LItens.ParamByName('ID').AsLargeInt := APedidoId;
    LItens.Open;
    if LItens.IsEmpty then
      raise Exception.Create('Pedido sem itens para emitir a NF-e.');

    LNFe.NotasFiscais.Clear;
    LNota := LNFe.NotasFiscais.Add;

    // ---------------- Identificação ----------------
    with LNota.NFe.Ide do
    begin
      cUF := UFtoCUF(LEmpUF);
      cNF := GerarCodigoDFe(LNumero);
      natOp := ANatureza;
      indPag := LIndPag;
      modelo := AModelo;
      serie := LSerie;
      nNF := LNumero;
      dEmi := Now;
      tpNF := tnSaida;
      if LCliUF = LEmpUF then
        idDest := doInterna
      else
        idDest := doInterestadual;
      cMunFG := LEmpCodMun;
      if AModelo = 65 then
        tpImp := tiNFCe
      else
        tpImp := tiRetrato;
      tpEmis := teNormal;
      tpAmb := LNFe.Configuracoes.WebServices.Ambiente;
      finNFe := fnNormal;
      if (AModelo = 65) or (LCliTipoPessoa = 'F') then
        indFinal := cfConsumidorFinal
      else
        indFinal := cfNao;
      if AModelo = 65 then
        indPres := pcPresencial
      else
        indPres := pcNao;
      procEmi := peAplicativoContribuinte;
      verProc := 'ERP2026';
    end;

    // ---------------- Emitente ----------------
    with LNota.NFe.Emit do
    begin
      CNPJCPF := LEmpCNPJ;
      xNome := Copy(LEmpRazao, 1, 60);
      if LEmpFantasia = '' then
        xFant := Copy(LEmpRazao, 1, 60)
      else
        xFant := Copy(LEmpFantasia, 1, 60);
      IE := SomenteDigitos(LEmpIE);
      if IE = '' then
        IE := LEmpIE;
      IM := Copy(LEmpIM, 1, 15);
      CRT := LEmpCRT;
      with EnderEmit do
      begin
        xLgr := Copy(LEmpLogradouro, 1, 60);
        nro := Copy(LEmpNumero, 1, 60);
        xCpl := Copy(LEmpComplemento, 1, 60);
        xBairro := Copy(LEmpBairro, 1, 60);
        cMun := LEmpCodMun;
        xMun := Copy(LEmpCidade, 1, 60);
        UF := LEmpUF;
        CEP := StrToIntDef(LEmpCEP, 0);
        cPais := 1058;
        xPais := 'BRASIL';
        fone := Copy(LEmpTelefone, 1, 14);
      end;
    end;

    // ---------------- Destinatário ----------------
    with LNota.NFe.Dest do
    begin
      CNPJCPF := LCliDoc;
      xNome := Copy(LCliNome, 1, 60);
      if LCliIE = '' then
      begin
        indIEDest := inNaoContribuinte;
        IE := '';
      end
      else if UpperCase(LCliIE) = 'ISENTO' then
      begin
        indIEDest := inIsento;
        IE := 'ISENTO';
      end
      else
      begin
        indIEDest := inContribuinte;
        IE := SomenteDigitos(LCliIE);
        if IE = '' then
          IE := LCliIE;
      end;
      Email := Copy(LCliEmail, 1, 60);
      with EnderDest do
      begin
        xLgr := Copy(LCliLogradouro, 1, 60);
        nro := Copy(LCliNumero, 1, 60);
        xCpl := Copy(LCliComplemento, 1, 60);
        xBairro := Copy(LCliBairro, 1, 60);
        cMun := LCliCodMun;
        xMun := Copy(LCliCidade, 1, 60);
        UF := LCliUF;
        CEP := StrToIntDef(LCliCEP, 0);
        cPais := 1058;
        xPais := 'BRASIL';
        fone := Copy(LCliTelefone, 1, 14);
      end;
    end;

    // ---------------- Itens, impostos e totais ----------------
    LTotalProd := 0;
    LTotalDesc := 0;
    LTotalICMS := 0;
    LTotalPIS := 0;
    LTotalCOFINS := 0;
    LBaseICMSTotal := 0;
    LPesoL := 0;
    LPesoB := 0;
    LItem := 0;

    while not LItens.EOF do
    begin
      Inc(LItem);
      LCodigo := Trim(LItens.FieldByName('CODIGO').AsString);
      if LCodigo = '' then
        LCodigo := IntToStr(LItem);
      LDescricao := Trim(LItens.FieldByName('DESCRICAO').AsString);
      LNCM := SomenteDigitos(LItens.FieldByName('NCM').AsString);
      LCEST := SomenteDigitos(LItens.FieldByName('CEST').AsString);
      LCFOP := SomenteDigitos(LItens.FieldByName('CFOP').AsString);
      LCSTICMS := Trim(LItens.FieldByName('CST_ICMS').AsString);
      LCSTPIS := Trim(LItens.FieldByName('CST_PIS').AsString);
      LCSTCOFINS := Trim(LItens.FieldByName('CST_COFINS').AsString);
      LUnidade := Trim(LItens.FieldByName('UNIDADE').AsString);
      LEAN := Trim(LItens.FieldByName('CODIGO_BARRAS').AsString);
      LQtd := LItens.FieldByName('QUANTIDADE').AsFloat;
      LPreco := LItens.FieldByName('PRECO_UNITARIO').AsFloat;
      { ITEM_PEDIDO.VALOR_TOTAL já é líquido (qtd * preço - desconto).
        A NF-e exige vProd bruto e vDesc separado, então reconstruímos
        o bruto para não descontar duas vezes nos totais. }
      LValorDesc := LItens.FieldByName('DESCONTO').AsFloat;
      if LValorDesc < 0 then
        LValorDesc := 0;
      LValorProd := LItens.FieldByName('VALOR_TOTAL').AsFloat + LValorDesc;
      LAliqICMS := LItens.FieldByName('ALIQ_ICMS').AsFloat;
      LAliqPIS := LItens.FieldByName('ALIQ_PIS').AsFloat;
      LAliqCOFINS := LItens.FieldByName('ALIQ_COFINS').AsFloat;
      LPesoL := LPesoL + LItens.FieldByName('PESO_LIQUIDO').AsFloat * LQtd;
      LPesoB := LPesoB + LItens.FieldByName('PESO_BRUTO').AsFloat * LQtd;

      if LQtd <= 0 then
        raise Exception.CreateFmt(
          'Produto %s: quantidade inválida (%s).', [LCodigo,
          FloatToStr(LQtd)]);
      if LPreco <= 0 then
        raise Exception.CreateFmt(
          'Produto %s: preço unitário inválido (%s).', [LCodigo,
          FloatToStr(LPreco)]);
      if LValorProd <= 0 then
        LValorProd := LQtd * LPreco;
      if LValorDesc > LValorProd then
        LValorDesc := LValorProd;
      if Length(LNCM) <> 8 then
        raise Exception.CreateFmt(
          'Produto %s: NCM inválido (%s). Informe 8 dígitos.',
          [LCodigo, LNCM]);
      if Length(LCFOP) <> 4 then
        raise Exception.CreateFmt(
          'Produto %s: CFOP inválido (%s). Informe 4 dígitos.',
          [LCodigo, LCFOP]);
      if LCSTICMS = '' then
        raise Exception.CreateFmt(
          'Produto %s: CST/CSOSN de ICMS não informado.', [LCodigo]);
      if LCSTPIS = '' then
        raise Exception.CreateFmt(
          'Produto %s: CST de PIS não informado.', [LCodigo]);
      if LCSTCOFINS = '' then
        raise Exception.CreateFmt(
          'Produto %s: CST de COFINS não informado.', [LCodigo]);

      LBaseICMS := LValorProd - LValorDesc;
      if LBaseICMS < 0 then
        LBaseICMS := 0;
      LValorICMS := LItens.FieldByName('VALOR_ICMS').AsFloat;
      if LValorICMS <= 0 then
        LValorICMS := LBaseICMS * LAliqICMS / 100;

      LDet := LNota.NFe.Det.New;
      with LDet.Prod do
      begin
        nItem := LItem;
        cProd := Copy(LCodigo, 1, 60);
        if EANValido(LEAN) then
        begin
          cEAN := SomenteDigitos(LEAN);
          cEANTrib := SomenteDigitos(LEAN);
        end
        else
        begin
          cEAN := 'SEM GTIN';
          cEANTrib := 'SEM GTIN';
        end;
        xProd := Copy(LDescricao, 1, 120);
        NCM := LNCM;
        if Length(LCEST) = 7 then
          CEST := LCEST;
        CFOP := LCFOP;
        uCom := Copy(LUnidade, 1, 6);
        qCom := LQtd;
        vUnCom := LPreco;
        vProd := LValorProd;
        uTrib := Copy(LUnidade, 1, 6);
        qTrib := LQtd;
        vUnTrib := LPreco;
        vFrete := 0;
        vSeg := 0;
        vDesc := LValorDesc;
        vOutro := 0;
        IndTot := itSomaTotalNFe;
      end;

      with LDet.Imposto do
      begin
        vTotTrib := 0;
        with ICMS do
        begin
          orig := oeNacional;
          if LUsaCSOSN then
          begin
            LOk := False;
            CSOSN := StrToCSOSNIcms(LOk, LCSTICMS);
            if not LOk then
              raise Exception.CreateFmt(
                'Produto %s: CSOSN inválido (%s). Simples Nacional exige ' +
                '3 dígitos (ex.: 102).', [LCodigo, LCSTICMS]);
            if CSOSN in [csosn101, csosn201, csosn202, csosn203, csosn900] then
            begin
              modBC := dbiValorOperacao;
              vBC := LBaseICMS;
              pICMS := LAliqICMS;
              vICMS := LBaseICMS * LAliqICMS / 100;
            end
            else
            begin
              vBC := 0;
              pICMS := 0;
              vICMS := 0;
            end;
            if CSOSN in [csosn101, csosn201] then
            begin
              pCredSN := 0;
              vCredICMSSN := 0;
            end;
            if CSOSN = csosn500 then
            begin
              vBCSTRet := 0;
              vICMSSTRet := 0;
            end;
          end
          else
          begin
            LOk := False;
            CST := StrToCSTICMS(LOk, LCSTICMS);
            if not LOk then
              raise Exception.CreateFmt(
                'Produto %s: CST de ICMS inválido (%s). Regime Normal exige ' +
                '2 dígitos (ex.: 00).', [LCodigo, LCSTICMS]);
            if CST in [cst00, cst10, cst20, cst70, cst90] then
            begin
              modBC := dbiValorOperacao;
              vBC := LBaseICMS;
              pICMS := LAliqICMS;
              vICMS := LBaseICMS * LAliqICMS / 100;
            end
            else
            begin
              vBC := 0;
              pICMS := 0;
              vICMS := 0;
            end;
            if CST in [cst10, cst70, cst90] then
            begin
              modBCST := dbisMargemValorAgregado;
              pMVAST := 0;
              pRedBCST := 0;
              vBCST := 0;
              pICMSST := 0;
              vICMSST := 0;
            end;
          end;
        end;

        with PIS do
        begin
          LOk := False;
          CST := StrToCSTPIS(LOk, LCSTPIS);
          if not LOk then
            raise Exception.CreateFmt(
              'Produto %s: CST de PIS inválido (%s).', [LCodigo, LCSTPIS]);
          case CST of
            pis01, pis02:
              begin
                vBC := LBaseICMS;
                pPIS := LAliqPIS;
                vPIS := LBaseICMS * LAliqPIS / 100;
              end;
          else
            begin
              vBC := 0;
              pPIS := 0;
              vPIS := 0;
            end;
          end;
        end;

        with COFINS do
        begin
          LOk := False;
          CST := StrToCSTCOFINS(LOk, LCSTCOFINS);
          if not LOk then
            raise Exception.CreateFmt(
              'Produto %s: CST de COFINS inválido (%s).',
              [LCodigo, LCSTCOFINS]);
          case CST of
            cof01, cof02:
              begin
                vBC := LBaseICMS;
                pCOFINS := LAliqCOFINS;
                vCOFINS := LBaseICMS * LAliqCOFINS / 100;
              end;
          else
            begin
              vBC := 0;
              pCOFINS := 0;
              vCOFINS := 0;
            end;
          end;
        end;
      end;

      LValorICMS := LDet.Imposto.ICMS.vICMS;
      LValorPIS := LDet.Imposto.PIS.vPIS;
      LValorCOFINS := LDet.Imposto.COFINS.vCOFINS;
      LBaseICMSTotal := LBaseICMSTotal + LDet.Imposto.ICMS.vBC;
      LTotalICMS := LTotalICMS + LValorICMS;
      LTotalPIS := LTotalPIS + LValorPIS;
      LTotalCOFINS := LTotalCOFINS + LValorCOFINS;
      LTotalProd := LTotalProd + LValorProd;
      LTotalDesc := LTotalDesc + LValorDesc;

      LItens.Next;
    end;
    LItens.Close;

    if LItem = 0 then
      raise Exception.Create('Pedido sem itens para emitir a NF-e.');

    LValorNF := LTotalProd - LTotalDesc;
    if LValorNF < 0 then
      LValorNF := 0;

    with LNota.NFe.Total.ICMSTot do
    begin
      vBC := LBaseICMSTotal;
      vICMS := LTotalICMS;
      vBCST := 0;
      vST := 0;
      vProd := LTotalProd;
      vFrete := 0;
      vSeg := 0;
      vDesc := LTotalDesc;
      vII := 0;
      vIPI := 0;
      vPIS := LTotalPIS;
      vCOFINS := LTotalCOFINS;
      vOutro := 0;
      vNF := LValorNF;
      vTotTrib := 0;
    end;

    LNota.NFe.Transp.modFrete := mfSemFrete;
    if (LPesoL > 0) or (LPesoB > 0) then
    begin
      with LNota.NFe.Transp.Vol.New do
      begin
        esp := 'VOLUME';
        pesoL := LPesoL;
        pesoB := LPesoB;
      end;
    end;

    with LNota.NFe.pag.New do
    begin
      indPag := LIndPag;
      tPag := LFormaPagamento;
      if LFormaPagamento = fpOutro then
        xPag := 'Não informado';
      vPag := LValorNF;
    end;

    if LPedidoNumero <> '' then
      LNota.NFe.InfAdic.infCpl := 'Pedido de venda ' + LPedidoNumero;

    // NFC-e exige CSC/IdCSC
    if AModelo = 65 then
    begin
      if (FIdCSC = '') or (FCSC = '') then
        raise Exception.Create(
          'NFC-e exige IdCSC e CSC configurados (Configuracoes.Geral).');
      LNFe.Configuracoes.Geral.ModeloDF := moNFCe;
      LNFe.Configuracoes.Geral.IdCSC := FIdCSC;
      LNFe.Configuracoes.Geral.CSC := FCSC;
    end
    else
      LNFe.Configuracoes.Geral.ModeloDF := moNFe;

    LNFe.Configuracoes.WebServices.UF := LEmpUF;

    // ---------------- Validação local (sem SEFAZ) ----------------
    // O schema da NF-e 4.00 exige a tag Signature; sem um certificado
    // (mesmo autoassinado de teste) só é possível conferir os dados,
    // não o XML completo.
    if ASomenteValidar then
    begin
      LNota.GerarXML;

      if (FCaminhoCertificado <> '') and
         FileExists(FCaminhoCertificado) and
         (FSenhaCertificado <> '') then
      begin
        try
          LNota.Assinar;
          LNota.Validar;
        except
          on E: Exception do
            raise Exception.Create('XML da NF-e inválido: ' + E.Message);
        end;

        Result.XML := LNota.XMLAssinado;
        Result.Motivo :=
          'XML assinado e validado localmente (não enviado à SEFAZ)';
      end
      else
      begin
        try
          LNota.Validar;
        except
          on E: Exception do
            raise Exception.Create(
              'Dados fiscais conferidos, mas o XML não pôde ser validado: ' +
              'o schema exige assinatura. Informe um certificado ' +
              '(pode ser autoassinado de teste) para validar o XML completo. ' +
              E.Message);
        end;

        Result.XML := LNota.XMLOriginal;
        Result.Motivo :=
          'Dados fiscais conferidos; XML sem assinatura não validado no schema';
      end;

      Result.ChaveAcesso := LNota.NumID;
      Result.Protocolo := '';
      Result.cStat := 0;
      Result.Status := ansPendente;
      Exit;
    end;

    // ---------------- Conferência de estoque (F2) ----------------
    // Feita antes de transmitir: sem saldo, nada é autorizado e nenhuma
    // nota de saída parcial fica para trás.
    LNotaSaida := TNotaSaidaService.Create;
    try
      if not LNotaSaida.VerificarSaldoPedido(APedidoId, LFaltandoDesc,
        LSaldoDisp, LSaldoSol) then
        raise Exception.CreateFmt(
          'Estoque insuficiente para "%s" (disponível: %s, solicitado: %s). ' +
          'Nada foi enviado à SEFAZ.',
          [LFaltandoDesc, FormatFloat('#,##0.####', LSaldoDisp),
           FormatFloat('#,##0.####', LSaldoSol)]);
    finally
      LNotaSaida.Free;
    end;

    // ---------------- Envio ----------------
    try
      if not LNFe.Enviar(1, False, True) then
      begin
        LMotivo := Trim(LNFe.WebServices.Retorno.xMotivo);
        if LMotivo = '' then
          LMotivo := 'sem retorno da SEFAZ';
        raise Exception.CreateFmt('Falha no envio da NF-e: %s', [LMotivo]);
      end;
    except
      on E: Exception do
        raise Exception.Create('Erro ao enviar a NF-e: ' + E.Message);
    end;

    if LNFe.NotasFiscais.Count = 0 then
      raise Exception.Create('A SEFAZ não retornou a NF-e processada.');

    LNota := LNFe.NotasFiscais.Items[0];
    Result.ChaveAcesso := Trim(LNota.NFe.procNFe.chNFe);
    if Result.ChaveAcesso = '' then
      Result.ChaveAcesso := LNota.NumID;
    Result.Protocolo := Trim(LNota.NFe.procNFe.nProt);
    Result.cStat := LNota.NFe.procNFe.cStat;
    Result.Motivo := Trim(LNota.NFe.procNFe.xMotivo);
    Result.XML := LNota.XMLOriginal;

    if not LNFe.CstatConfirmada(Result.cStat) then
    begin
      Result.Status := StatusPorCStat(Result.cStat);
      raise Exception.CreateFmt(
        'NF-e não autorizada (cStat %d): %s',
        [Result.cStat, Result.Motivo]);
    end;

    Result.Status := ansAutorizada;

    // ---------------- Materialização da nota de saída (F2) ----------------
    // A NF-e autorizada vira NOTA_SAIDA: grava número/série/modelo/chave/
    // protocolo, salva o XML em CaminhoSalvar, baixa o estoque e gera as
    // contas a receber (TNotaSaidaService.Faturar).
    LArquivoXml := '';
    if Trim(Result.XML) <> '' then
    begin
      ForceDirectories(FCaminhoSalvar);
      LArquivoXml := IncludeTrailingPathDelimiter(FCaminhoSalvar) +
        Result.ChaveAcesso + '.xml';
      LLista := TStringList.Create;
      try
        LLista.Text := Result.XML;
        LLista.SaveToFile(LArquivoXml);
      finally
        LLista.Free;
      end;
    end;

    LNotaSaida := TNotaSaidaService.Create;
    try
      try
        Result.NotaSaidaId := LNotaSaida.MaterializarAutorizada(APedidoId,
          LNumero, LSerie, AModelo, ANatureza, Result.CFOP,
          Result.ChaveAcesso, Result.Protocolo,
          ExtractFileName(LArquivoXml));
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'NF-e autorizada (chave %s), mas a nota de saída não foi ' +
            'materializada: %s A chave e o XML foram salvos; regularize e ' +
            'fature a nota manualmente.',
            [Result.ChaveAcesso, E.Message]);
      end;
    finally
      LNotaSaida.Free;
    end;

    // ---------------- Persistência + auditoria ----------------
    LQuery.Close;
    LQuery.SQL.Text :=
      'UPDATE PEDIDO_VENDA SET NUMERO_NFE = :NUM, CHAVE_NFE = :CHAVE ' +
      'WHERE ID = :ID AND EMPRESA_ID = :EMP';
    LQuery.ParamByName('NUM').AsInteger := LNumero;
    LQuery.ParamByName('CHAVE').AsString := Result.ChaveAcesso;
    LQuery.ParamByName('ID').AsLargeInt := APedidoId;
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LConexao.IniciarTransacao;
    try
      LQuery.ExecSQL;
      RegistrarAuditoria('PEDIDO_VENDA', 'NFE', APedidoId, '',
        ResumoAuditoria(['NUMERO_NFE=' + IntToStr(LNumero),
          'CHAVE=' + Result.ChaveAcesso,
          'PROTOCOLO=' + Result.Protocolo,
          'CSTAT=' + IntToStr(Result.cStat)]));
      LConexao.Confirmar;
    except
      LConexao.Cancelar;
      raise;
    end;
  finally
    LItens.Free;
    LCidade.Free;
    LQuery.Free;
  end;
end;

function TACBrHelper.ConsultarReal(const AChave: string): TACBrDadosNFe;
var
  LNFe: TACBrNFe;
  LChave: string;
begin
  LChave := SomenteDigitos(AChave);
  if Length(LChave) <> 44 then
    raise Exception.Create(
      'Chave da NF-e inválida: informe os 44 dígitos.');

  LNFe := GetACBrNFe;
  ConfigurarACBr;
  if Copy(LChave, 21, 2) = '65' then
    LNFe.Configuracoes.Geral.ModeloDF := moNFCe
  else
    LNFe.Configuracoes.Geral.ModeloDF := moNFe;

  if not LNFe.Consultar(LChave) then
    raise Exception.Create('Consulta à SEFAZ falhou: ' +
      Trim(LNFe.WebServices.Consulta.Msg));

  Result := Default(TACBrDadosNFe);
  Result.ChaveAcesso := Trim(LNFe.WebServices.Consulta.NFeChave);
  if Result.ChaveAcesso = '' then
    Result.ChaveAcesso := LChave;
  Result.Protocolo := Trim(LNFe.WebServices.Consulta.Protocolo);
  Result.cStat := LNFe.WebServices.Consulta.cStat;
  Result.Motivo := Trim(LNFe.WebServices.Consulta.XMotivo);
  Result.Status := StatusPorCStat(Result.cStat);
  Result.XML := '';
end;

function TACBrHelper.CancelarReal(const AChave,
  AJustificativa: string): Boolean;
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LNFe: TACBrNFe;
  LChave, LCNPJ, LProtocolo: string;
  LCStat: Integer;
  LMotivo: string;
begin
  LChave := SomenteDigitos(AChave);
  if Length(LChave) <> 44 then
    raise Exception.Create(
      'Chave da NF-e inválida: informe os 44 dígitos.');

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text := 'SELECT CNPJ FROM EMPRESA WHERE ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Empresa da sessão não encontrada.');
    LCNPJ := SomenteDigitos(LQuery.FieldByName('CNPJ').AsString);
    LQuery.Close;
  finally
    LQuery.Free;
  end;

  if Length(LCNPJ) <> 14 then
    raise Exception.Create('CNPJ da empresa inválido para o cancelamento.');

  LNFe := GetACBrNFe;
  ConfigurarACBr;
  if Copy(LChave, 21, 2) = '65' then
    LNFe.Configuracoes.Geral.ModeloDF := moNFCe
  else
    LNFe.Configuracoes.Geral.ModeloDF := moNFe;

  // O protocolo de autorização é obrigatório no evento de cancelamento.
  if not LNFe.Consultar(LChave) then
    raise Exception.Create('Não foi possível consultar a NF-e antes do ' +
      'cancelamento: ' + Trim(LNFe.WebServices.Consulta.Msg));
  LProtocolo := Trim(LNFe.WebServices.Consulta.Protocolo);
  if LProtocolo = '' then
    raise Exception.Create(
      'Protocolo de autorização não encontrado para a chave ' + LChave + '.');

  LNFe.EventoNFe.Evento.Clear;
  with LNFe.EventoNFe.Evento.New do
  begin
    infEvento.CNPJ := LCNPJ;
    infEvento.cOrgao := StrToIntDef(Copy(LChave, 1, 2), 0);
    infEvento.dhEvento := Now;
    infEvento.tpEvento := teCancelamento;
    infEvento.chNFe := LChave;
    infEvento.detEvento.nProt := LProtocolo;
    infEvento.detEvento.xJust := AJustificativa;
  end;

  if not LNFe.EnviarEvento(1) then
    raise Exception.Create('Cancelamento não enviado: ' +
      Trim(LNFe.WebServices.EnvEvento.xMotivo));

  LCStat := LNFe.WebServices.EnvEvento.EventoRetorno.cStat;
  LMotivo := Trim(LNFe.WebServices.EnvEvento.EventoRetorno.xMotivo);
  if LNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Count > 0 then
  begin
    LCStat := LNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0]
      .RetInfEvento.cStat;
    LMotivo := Trim(LNFe.WebServices.EnvEvento.EventoRetorno.retEvento
      .Items[0].RetInfEvento.xMotivo);
  end;

  Result := LCStat in [135, 155];
  if not Result then
    raise Exception.CreateFmt(
      'Cancelamento rejeitado (cStat %d): %s', [LCStat, LMotivo]);
end;

function TACBrHelper.ManifestarReal(const AChave: string;
  ATipoManifestacao: Integer): Boolean;
var
  LConexao: TConexao;
  LQuery: TSQLQuery;
  LNFe: TACBrNFe;
  LChave, LCNPJ: string;
  LTipoEvento: TpcnTpEvento;
  LCStat: Integer;
  LMotivo: string;
begin
  LChave := SomenteDigitos(AChave);
  if Length(LChave) <> 44 then
    raise Exception.Create(
      'Chave da NF-e inválida: informe os 44 dígitos.');

  LTipoEvento := TipoEventoManifestacao(ATipoManifestacao);

  LConexao := TConexao.GetInstance;
  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := LConexao.Connection;
    LQuery.Transaction := LConexao.Transaction;
    LQuery.SQL.Text := 'SELECT CNPJ FROM EMPRESA WHERE ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if LQuery.IsEmpty then
      raise Exception.Create('Empresa da sessão não encontrada.');
    LCNPJ := SomenteDigitos(LQuery.FieldByName('CNPJ').AsString);
    LQuery.Close;
  finally
    LQuery.Free;
  end;

  if Length(LCNPJ) <> 14 then
    raise Exception.Create('CNPJ da empresa inválido para a manifestação.');

  LNFe := GetACBrNFe;
  ConfigurarACBr;
  if Copy(LChave, 21, 2) = '65' then
    LNFe.Configuracoes.Geral.ModeloDF := moNFCe
  else
    LNFe.Configuracoes.Geral.ModeloDF := moNFe;

  LNFe.EventoNFe.Evento.Clear;
  with LNFe.EventoNFe.Evento.New do
  begin
    infEvento.CNPJ := LCNPJ;
    infEvento.cOrgao := StrToIntDef(Copy(LChave, 1, 2), 0);
    infEvento.dhEvento := Now;
    infEvento.tpEvento := LTipoEvento;
    infEvento.chNFe := LChave;
  end;

  if not LNFe.EnviarEvento(1) then
    raise Exception.Create('Manifestação não enviada: ' +
      Trim(LNFe.WebServices.EnvEvento.xMotivo));

  LCStat := LNFe.WebServices.EnvEvento.EventoRetorno.cStat;
  LMotivo := Trim(LNFe.WebServices.EnvEvento.EventoRetorno.xMotivo);
  if LNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Count > 0 then
  begin
    LCStat := LNFe.WebServices.EnvEvento.EventoRetorno.retEvento.Items[0]
      .RetInfEvento.cStat;
    LMotivo := Trim(LNFe.WebServices.EnvEvento.EventoRetorno.retEvento
      .Items[0].RetInfEvento.xMotivo);
  end;

  Result := LCStat in [128, 135, 136, 138];
  if not Result then
    raise Exception.CreateFmt(
      'Manifestação rejeitada (cStat %d): %s', [LCStat, LMotivo]);
end;
{$ENDIF}

end.
