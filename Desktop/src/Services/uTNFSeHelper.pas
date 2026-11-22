unit uTNFSeHelper;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - TNFSeHelper (marco 3.92)
  ------------------------------------------------------------
  Geração da DPS (Declaração de Prestação de Serviços) do padrão
  nacional da NFS-e, versão 1.01, SEM envio à prefeitura/SEFAZ.

  Modos (preferência NFSE_MODO, lida de CONFIGURACAO):
    - SIMULADO (padrão): gera e valida o XML localmente, sem
      certificado e sem assinatura. É o "modo de teste" do
      desenvolvedor;
    - REAL: exige certificado A1 configurado (NFSE_CERTIFICADO)
      e senha passada pelo chamador, assina SHA256 e valida o
      XSD oficial. Nunca grava senha/token no banco.

  A validação XSD completa só acontece quando o app foi compilado
  com -dACBr. Mesmo sem ACBr (Tests.lpi) a DPS passa por validação
  estrutural: versão, namespace, Id de 45 posições, campos
  obrigatórios e fechamento das tags.

  Nenhuma baixa de estoque, financeiro ou NF-e é feita aqui.
  ============================================================ }

interface

uses
  Classes, SysUtils, SQLDB, uConexao, uConfiguracaoService;

type
  TNFSeDados = record
    Numero: Integer;
    Serie: string;
    DataEmissao: TDateTime;
    DataCompetencia: TDate;
    MunicipioIBGE: string;
    UF: string;
    InscricaoMunicipal: string;
    CodigoServico: string;
    DescricaoServico: string;
    ValorServico: Double;
    Desconto: Double;
    AliquotaISS: Double;
    ValorISS: Double;
    TipoRetencaoISS: string;
    ValorRetPIS: Double;
    ValorRetCOFINS: Double;
    ValorRetINSS: Double;
    TomadorNome: string;
    TomadorDocumento: string;
    { Preenchidos pelo helper a partir de EMPRESA/CONFIGURACAO }
    PrestadorCnpj: string;
    PrestadorNome: string;
    OpSimpNac: string;
    RegEspTrib: string;
  end;

  TNFSeHelper = class
  private
    FCfg: TConfiguracaoService;
    FConexao: TConexao;
    FProvedor: string;
    FMunicipio: string;
    FInscricaoMunicipal: string;
    FAmbiente: string;
    FModo: string;
    FSerie: string;
    FSequencia: string;
    FOpsimpNac: string;
    FRegEspTrib: string;
    FCaminhoCertificado: string;
    FCaminhoSchema: string;
    FVersao: string;
    FVerAplic: string;
    FEmpresaCnpj: string;
    FEmpresaNome: string;
    FEmpresaIM: string;
    FEmpresaUF: string;
    FEmpresaCRT: Integer;
    function LerConfig(const AChave, ADefault: string): string;
    procedure CarregarEmpresa;
    function Resolver(const ADados: TNFSeDados; out ARes: TNFSeDados): string;
    function ValidarDados(const ADados: TNFSeDados): string;
    function MontarXML(const ADados: TNFSeDados): string;
  public
    constructor Create;
    destructor Destroy; override;

    { Recarrega as preferências NFSE_* da empresa da sessão. }
    procedure CarregarConfiguracao;

    { Gera a DPS. Em SIMULADO não assina e não envia. Em REAL assina
      e valida contra o XSD oficial. Levanta Exception quando a
      configuração ou os dados fiscais estão incompletos; devolve
      False + AMensagem quando a validação do XML falha. }
    function GerarDPS(const ADados: TNFSeDados;
      const ASenhaCertificado: string; out AXml, AMensagem: string): Boolean;

    { Validação loca da DPS (estrutural sempre; XSD quando disponível). }
    function ValidarDPS(const AXml: string; out AMensagem: string): Boolean;

    { Identificador no padrão DPS + 42 dígitos do XSD nacional. }
    function GerarIdDPS(const ADados: TNFSeDados): string;

    property Provedor: string read FProvedor;
    property MunicipioIBGE: string read FMunicipio;
    property InscricaoMunicipal: string read FInscricaoMunicipal;
    property Ambiente: string read FAmbiente;
    property Modo: string read FModo;
    property Serie: string read FSerie;
    property Sequencia: string read FSequencia;
    property CaminhoCertificado: string read FCaminhoCertificado;
    property CaminhoSchema: string read FCaminhoSchema;
    property Versao: string read FVersao;
  end;

implementation

uses
  DateUtils, uSessao, uNFSeXmlCrypto;

const
  NAMESPACE_NFSE = 'http://www.sped.fazenda.gov.br/nfse';

function SoDigitos(const AValor: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValor) do
    if AValor[I] in ['0'..'9'] then
      Result := Result + AValor[I];
end;

function EscapeXml(const AValor: string): string;
begin
  Result := StringReplace(AValor, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

function XmlNum(const AValor: Double): string;
var
  LFS: TFormatSettings;
begin
  LFS := DefaultFormatSettings;
  LFS.DecimalSeparator := '.';
  Result := FloatToStrF(AValor, ffFixed, 15, 2, LFS);
end;

function DataIso(const AData: TDate): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', AData);
end;

{ O XSD exige TZD com offset numérico (+/-hh:00), não "Z". }
function OffsetTZD(const AData: TDateTime): string;
var
  LMin: Integer;
  LSinal: string;
begin
  LMin := Round((AData - UnixToDateTime(DateTimeToUnix(AData))) * 24 * 60);
  if LMin < 0 then
  begin
    LSinal := '-';
    LMin := -LMin;
  end
  else
    LSinal := '+';
  Result := Format('%s%.2d:00', [LSinal, LMin div 60]);
end;

{ Preenche com zeros à esquerda, sem depender de StrUtils.PadLeft. }
function Zeros(const AValor: string; ATamanho: Integer): string;
var
  LNum: string;
begin
  LNum := SoDigitos(AValor);
  if LNum = '' then
    LNum := '0';
  if Length(LNum) >= ATamanho then
    Result := Copy(LNum, Length(LNum) - ATamanho + 1, ATamanho)
  else
    Result := StringOfChar('0', ATamanho - Length(LNum)) + LNum;
end;

constructor TNFSeHelper.Create;
begin
  inherited Create;
  FConexao := TConexao.GetInstance;
  FCfg := TConfiguracaoService.Create;
  CarregarConfiguracao;
  CarregarEmpresa;
end;

destructor TNFSeHelper.Destroy;
begin
  FCfg.Free;
  inherited Destroy;
end;

function TNFSeHelper.LerConfig(const AChave, ADefault: string): string;
var
  LValor: string;
begin
  LValor := Trim(FCfg.LerValor(AChave));
  if LValor = '' then
    Result := ADefault
  else
    Result := LValor;
end;

procedure TNFSeHelper.CarregarConfiguracao;
begin
  FProvedor := LerConfig('NFSE_PROVEDOR', 'NACIONAL');
  FMunicipio := SoDigitos(LerConfig('NFSE_MUNICIPIO_IBGE', ''));
  FInscricaoMunicipal := Trim(LerConfig('NFSE_INSCRICAO_MUNICIPAL', ''));
  FAmbiente := LerConfig('NFSE_AMBIENTE', '2');
  FModo := UpperCase(LerConfig('NFSE_MODO', 'SIMULADO'));
  FSerie := Copy(SoDigitos(LerConfig('NFSE_SERIE', '1')), 1, 5);
  if FSerie = '' then
    FSerie := '1';
  FSequencia := LerConfig('NFSE_RPS_SEQUENCIA', '1');
  FOpsimpNac := LerConfig('NFSE_OPSIMPNAS', '');
  FRegEspTrib := LerConfig('NFSE_REGESPTRIB', '0');
  FCaminhoCertificado := Trim(LerConfig('NFSE_CERTIFICADO', ''));
  FVersao := LerConfig('NFSE_VERSAO', '1.01');
  FVerAplic := LerConfig('NFSE_VERAPLIC', 'ERP2026-3.92');
  FCaminhoSchema := Trim(LerConfig('NFSE_SCHEMA', ''));
  if FCaminhoSchema = '' then
    FCaminhoSchema := ExtractFilePath(ParamStr(0)) +
      'schemas\nfse\1.01\DPS_v1.01.xsd';
end;

procedure TNFSeHelper.CarregarEmpresa;
var
  LQuery: TSQLQuery;
begin
  FEmpresaCnpj := '';
  FEmpresaNome := '';
  FEmpresaIM := '';
  FEmpresaUF := '';
  FEmpresaCRT := 1;

  LQuery := TSQLQuery.Create(nil);
  try
    LQuery.DataBase := FConexao.Connection;
    LQuery.Transaction := FConexao.Transaction;
    LQuery.SQL.Text :=
      'SELECT COALESCE(CNPJ, '''') AS CNPJ, ' +
      '       COALESCE(RAZAO_SOCIAL, '''') AS RAZAO, ' +
      '       COALESCE(IM, '''') AS IM, ' +
      '       COALESCE(UF, '''') AS UF, ' +
      '       COALESCE(CRT, 1) AS CRT ' +
      'FROM EMPRESA WHERE ID = :EMP';
    LQuery.ParamByName('EMP').AsLargeInt := TSessao.GetInstance.EmpresaId;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      FEmpresaCnpj := SoDigitos(LQuery.FieldByName('CNPJ').AsString);
      FEmpresaNome := Trim(LQuery.FieldByName('RAZAO').AsString);
      FEmpresaIM := Trim(LQuery.FieldByName('IM').AsString);
      FEmpresaUF := UpperCase(Trim(LQuery.FieldByName('UF').AsString));
      FEmpresaCRT := LQuery.FieldByName('CRT').AsInteger;
    end;
  finally
    LQuery.Free;
  end;
end;

function TNFSeHelper.Resolver(const ADados: TNFSeDados;
  out ARes: TNFSeDados): string;
var
  LOp: string;
begin
  ARes := ADados;
  CarregarConfiguracao;
  CarregarEmpresa;

  if ARes.MunicipioIBGE = '' then
    ARes.MunicipioIBGE := FMunicipio;
  ARes.MunicipioIBGE := SoDigitos(ARes.MunicipioIBGE);

  if ARes.InscricaoMunicipal = '' then
    ARes.InscricaoMunicipal := FInscricaoMunicipal;
  if ARes.InscricaoMunicipal = '' then
    ARes.InscricaoMunicipal := FEmpresaIM;

  if ARes.UF = '' then
    ARes.UF := FEmpresaUF;

  if ARes.Serie = '' then
    ARes.Serie := FSerie;
  ARes.Serie := Copy(SoDigitos(ARes.Serie), 1, 5);
  if ARes.Serie = '' then
    ARes.Serie := '1';

  if ARes.DataEmissao = 0 then
    ARes.DataEmissao := Now;
  if ARes.DataCompetencia = 0 then
    ARes.DataCompetencia := DateOf(ARes.DataEmissao);

  ARes.PrestadorCnpj := FEmpresaCnpj;
  ARes.PrestadorNome := FEmpresaNome;

  { CRT 1 = Simples Nacional -> opSimpNac 3 (ME/EPP);
    CRT 2 (excesso) e 3 (normal) -> opSimpNac 1. A preferência
    NFSE_OPSIMPNAS sempre tem prioridade sobre a inferência. }
  LOp := FOpsimpNac;
  if LOp = '' then
  begin
    if FEmpresaCRT = 1 then
      LOp := '3'
    else
      LOp := '1';
  end;
  ARes.OpSimpNac := LOp;
  ARes.RegEspTrib := FRegEspTrib;
  Result := '';
end;

function TNFSeHelper.ValidarDados(const ADados: TNFSeDados): string;
begin
  Result := '';
  if (FModo <> 'SIMULADO') and (FModo <> 'REAL') then
    Exit('NFSE_MODO inválido (use SIMULADO ou REAL).');
  if (FAmbiente <> '1') and (FAmbiente <> '2') then
    Exit('NFSE_AMBIENTE inválido (use 1 ou 2).');
  if FVersao <> '1.01' then
    Exit('NFSE_VERSAO inválida (use 1.01).');

  if Length(ADados.PrestadorCnpj) <> 14 then
    Exit('CNPJ do prestador (EMPRESA.CNPJ) deve ter 14 dígitos.');
  if ADados.PrestadorNome = '' then
    Exit('Razão social do prestador não cadastrada.');
  if Length(ADados.MunicipioIBGE) <> 7 then
    Exit('Município IBGE do prestador deve ter 7 dígitos (NFSE_MUNICIPIO_IBGE).');
  if ADados.InscricaoMunicipal = '' then
    Exit('Inscrição municipal obrigatória (NFSE_INSCRICAO_MUNICIPAL).');
  if Length(ADados.CodigoServico) <> 6 then
    Exit('Código de serviço (LC 116) deve ter 6 dígitos.');

  if ADados.DescricaoServico = '' then
    Exit('Descrição do serviço é obrigatória.');
  if (ADados.ValorServico - ADados.Desconto) <= 0 then
    Exit('Valor do serviço após desconto deve ser maior que zero.');
  if (ADados.AliquotaISS < 0) or (ADados.AliquotaISS > 9.99) then
    Exit('Alíquota de ISS deve estar entre 0 e 9,99.');
  if (ADados.TipoRetencaoISS <> '1') and
     (ADados.TipoRetencaoISS <> '2') and
     (ADados.TipoRetencaoISS <> '3') then
    Exit('Tipo de retenção de ISS inválido (1, 2 ou 3).');

  if (ADados.OpSimpNac <> '1') and (ADados.OpSimpNac <> '2') and
     (ADados.OpSimpNac <> '3') then
    Exit('Regime do Simples Nacional inválido (NFSE_OPSIMPNAS).');
  if (ADados.RegEspTrib <> '0') and (ADados.RegEspTrib <> '1') and
     (ADados.RegEspTrib <> '2') and (ADados.RegEspTrib <> '3') and
     (ADados.RegEspTrib <> '4') and (ADados.RegEspTrib <> '5') and
     (ADados.RegEspTrib <> '6') and (ADados.RegEspTrib <> '9') then
    Exit('Regime especial de tributação inválido (NFSE_REGESPTRIB).');

  if ADados.Numero <= 0 then
    Exit('Número da DPS inválido.');
  if Length(ADados.Serie) > 5 then
    Exit('Série da DPS deve ter no máximo 5 dígitos.');
  if ADados.DataCompetencia = 0 then
    Exit('Data de competência é obrigatória.');

  if ADados.TomadorDocumento <> '' then
    if not (Length(ADados.TomadorDocumento) in [11, 14]) then
      Exit('Documento do tomador deve ter 11 (CPF) ou 14 (CNPJ) dígitos.');
  if (ADados.TomadorDocumento <> '') and (ADados.TomadorNome = '') then
    Exit('Nome do tomador é obrigatório quando há CPF/CNPJ.');

  if FModo = 'REAL' then
  begin
    if not NFSeXmlDisponivel then
      Exit('NFSE_MODO=REAL exige compilação com -dACBr (ERP2026.lpi).');
    if FCaminhoCertificado = '' then
      Exit('NFSE_MODO=REAL exige NFSE_CERTIFICADO (caminho do PFX).');
    if not FileExists(FCaminhoCertificado) then
      Exit('Certificado PFX não encontrado: ' + FCaminhoCertificado);
  end;
end;

function TNFSeHelper.GerarIdDPS(const ADados: TNFSeDados): string;
var
  LCnpj: string;
begin
  LCnpj := ADados.PrestadorCnpj;
  if LCnpj = '' then
    LCnpj := FEmpresaCnpj;
  Result := 'DPS' +
    Zeros(ADados.MunicipioIBGE, 7) +       // código do município
    '1' +                                  // tipo de inscrição federal: CNPJ
    Zeros(LCnpj, 14) +                     // inscrição federal
    Zeros(ADados.Serie, 5) +               // série da DPS
    Zeros(IntToStr(ADados.Numero), 15);    // número da DPS
end;

function TNFSeHelper.MontarXML(const ADados: TNFSeDados): string;
var
  L: TStringList;
  LTotal: Double;
begin
  L := TStringList.Create;
  try
    L.Add('<?xml version="1.0" encoding="UTF-8"?>');
    L.Add('<DPS xmlns="' + NAMESPACE_NFSE + '" versao="' + FVersao + '">');
    L.Add('  <infDPS Id="' + GerarIdDPS(ADados) + '">');
    L.Add('    <tpAmb>' + FAmbiente + '</tpAmb>');
    L.Add('    <dhEmi>' + FormatDateTime('yyyy-mm-dd"T"hh:mm:ss',
      ADados.DataEmissao) + OffsetTZD(ADados.DataEmissao) + '</dhEmi>');
    L.Add('    <verAplic>' + EscapeXml(FVerAplic) + '</verAplic>');
    L.Add('    <serie>' + EscapeXml(ADados.Serie) + '</serie>');
    L.Add('    <nDPS>' + IntToStr(ADados.Numero) + '</nDPS>');
    L.Add('    <dCompet>' + DataIso(ADados.DataCompetencia) + '</dCompet>');
    L.Add('    <tpEmit>1</tpEmit>');
    L.Add('    <cLocEmi>' + EscapeXml(ADados.MunicipioIBGE) + '</cLocEmi>');

    L.Add('    <prest>');
    L.Add('      <CNPJ>' + EscapeXml(ADados.PrestadorCnpj) + '</CNPJ>');
    if ADados.InscricaoMunicipal <> '' then
      L.Add('      <IM>' + EscapeXml(ADados.InscricaoMunicipal) + '</IM>');
    if ADados.PrestadorNome <> '' then
      L.Add('      <xNome>' + EscapeXml(ADados.PrestadorNome) + '</xNome>');
    L.Add('      <regTrib>');
    L.Add('        <opSimpNac>' + ADados.OpSimpNac + '</opSimpNac>');
    L.Add('        <regEspTrib>' + ADados.RegEspTrib + '</regEspTrib>');
    L.Add('      </regTrib>');
    L.Add('    </prest>');

    if ADados.TomadorDocumento <> '' then
    begin
      L.Add('    <toma>');
      if Length(ADados.TomadorDocumento) = 14 then
        L.Add('      <CNPJ>' + EscapeXml(ADados.TomadorDocumento) + '</CNPJ>')
      else
        L.Add('      <CPF>' + EscapeXml(ADados.TomadorDocumento) + '</CPF>');
      L.Add('      <xNome>' + EscapeXml(ADados.TomadorNome) + '</xNome>');
      L.Add('    </toma>');
    end;

    L.Add('    <serv>');
    L.Add('      <locPrest>');
    L.Add('        <cLocPrestacao>' + EscapeXml(ADados.MunicipioIBGE) +
      '</cLocPrestacao>');
    L.Add('      </locPrest>');
    L.Add('      <cServ>');
    L.Add('        <cTribNac>' + EscapeXml(ADados.CodigoServico) + '</cTribNac>');
    L.Add('        <xDescServ>' + EscapeXml(ADados.DescricaoServico) +
      '</xDescServ>');
    L.Add('      </cServ>');
    L.Add('    </serv>');

    LTotal := ADados.ValorServico - ADados.Desconto;
    L.Add('    <valores>');
    L.Add('      <vServPrest>');
    L.Add('        <vServ>' + XmlNum(LTotal) + '</vServ>');
    L.Add('      </vServPrest>');
    if ADados.Desconto > 0 then
    begin
      L.Add('      <vDescCondIncond>');
      L.Add('        <vDescIncond>' + XmlNum(ADados.Desconto) + '</vDescIncond>');
      L.Add('      </vDescCondIncond>');
    end;
    L.Add('      <trib>');
    L.Add('        <tribMun>');
    L.Add('          <tribISSQN>1</tribISSQN>');
    L.Add('          <tpRetISSQN>' + ADados.TipoRetencaoISS + '</tpRetISSQN>');
    if ADados.AliquotaISS > 0 then
      L.Add('          <pAliq>' + XmlNum(ADados.AliquotaISS) + '</pAliq>');
    L.Add('        </tribMun>');
    if (ADados.ValorRetPIS > 0) or (ADados.ValorRetCOFINS > 0) or
       (ADados.ValorRetINSS > 0) then
    begin
      L.Add('        <tribFed>');
      if (ADados.ValorRetPIS > 0) or (ADados.ValorRetCOFINS > 0) then
      begin
        L.Add('          <piscofins>');
        L.Add('            <CST>00</CST>');
        L.Add('            <vBCPisCofins>' + XmlNum(LTotal) + '</vBCPisCofins>');
        if ADados.ValorRetPIS > 0 then
          L.Add('            <vPis>' + XmlNum(ADados.ValorRetPIS) + '</vPis>');
        if ADados.ValorRetCOFINS > 0 then
          L.Add('            <vCofins>' + XmlNum(ADados.ValorRetCOFINS) +
            '</vCofins>');
        L.Add('            <tpRetPisCofins>1</tpRetPisCofins>');
        L.Add('          </piscofins>');
      end;
      if ADados.ValorRetINSS > 0 then
        L.Add('          <vRetCP>' + XmlNum(ADados.ValorRetINSS) + '</vRetCP>');
      L.Add('        </tribFed>');
    end;
    L.Add('        <totTrib>');
    L.Add('          <indTotTrib>0</indTotTrib>');
    L.Add('        </totTrib>');
    L.Add('      </trib>');
    L.Add('    </valores>');
    L.Add('  </infDPS>');
    L.Add('</DPS>');

    Result := L.Text;
  finally
    L.Free;
  end;
end;

function TNFSeHelper.ValidarDPS(const AXml: string;
  out AMensagem: string): Boolean;
var
  LId: string;
  procedure Falhar(const ATexto: string);
  begin
    AMensagem := ATexto;
    Result := False;
  end;
begin
  AMensagem := '';
  Result := True;
  if Pos('<?xml version="1.0" encoding="UTF-8"?>', AXml) <> 1 then
  begin
    Falhar('XML deve começar com declaração UTF-8.');
    Exit;
  end;
  if Pos('<DPS xmlns="' + NAMESPACE_NFSE + '" versao="1.01">', AXml) = 0 then
  begin
    Falhar('Elemento DPS ou versão 1.01 ausente.');
    Exit;
  end;
  if Pos('<infDPS Id="DPS', AXml) = 0 then
  begin
    Falhar('Atributo Id do infDPS ausente ou inválido.');
    Exit;
  end;
  LId := Copy(AXml, Pos('<infDPS Id="', AXml) + 12, 45);
  if (Length(LId) <> 45) or (Copy(LId, 1, 3) <> 'DPS') or
     (Length(SoDigitos(Copy(LId, 4, 42))) <> 42) then
  begin
    Falhar('Id da DPS deve ter DPS + 42 dígitos (45 posições).');
    Exit;
  end;
  if Pos('</infDPS>', AXml) = 0 then
  begin
    Falhar('Tag infDPS não foi fechada.');
    Exit;
  end;
  if Pos('</DPS>', AXml) = 0 then
  begin
    Falhar('Tag DPS não foi fechada.');
    Exit;
  end;

  if Pos('<tpAmb>', AXml) = 0 then Falhar('tpAmb ausente.');
  if Pos('<dhEmi>', AXml) = 0 then Falhar('dhEmi ausente.');
  if Pos('<verAplic>', AXml) = 0 then Falhar('verAplic ausente.');
  if Pos('<serie>', AXml) = 0 then Falhar('serie ausente.');
  if Pos('<nDPS>', AXml) = 0 then Falhar('nDPS ausente.');
  if Pos('<dCompet>', AXml) = 0 then Falhar('dCompet ausente.');
  if Pos('<tpEmit>', AXml) = 0 then Falhar('tpEmit ausente.');
  if Pos('<cLocEmi>', AXml) = 0 then Falhar('cLocEmi ausente.');
  if Pos('<prest>', AXml) = 0 then Falhar('prest ausente.');
  if Pos('<cTribNac>', AXml) = 0 then Falhar('código de serviço ausente.');
  if Pos('<xDescServ>', AXml) = 0 then Falhar('descrição do serviço ausente.');
  if Pos('<vServ>', AXml) = 0 then Falhar('valor do serviço ausente.');
  if Pos('<tpRetISSQN>', AXml) = 0 then Falhar('tpRetISSQN ausente.');
  if Pos('<indTotTrib>0</indTotTrib>', AXml) = 0 then
    Falhar('totTrib/indTotTrib ausente.');

  if (not Result) then
    Exit;

  { Com ACBr, completa a validação com o XSD oficial. Sem ACBr
    (suíte de testes) a validação estrutural acima já é exigida. }
  if NFSeXmlDisponivel and FileExists(FCaminhoSchema) then
  begin
    if not ValidarXmlNFSe(AXml, FCaminhoSchema, AMensagem) then
    begin
      AMensagem := 'XSD: ' + AMensagem;
      Result := False;
    end;
  end;
end;

function TNFSeHelper.GerarDPS(const ADados: TNFSeDados;
  const ASenhaCertificado: string; out AXml, AMensagem: string): Boolean;
var
  LRes: TNFSeDados;
  LErro: string;
  LAssinado: string;
begin
  Result := False;
  AXml := '';
  AMensagem := '';

  LErro := Resolver(ADados, LRes);
  if LErro <> '' then
    raise Exception.Create(LErro);

  LErro := ValidarDados(LRes);
  if LErro <> '' then
    raise Exception.Create(LErro);

  AXml := MontarXML(LRes);
  if not ValidarDPS(AXml, AMensagem) then
    Exit;

  if FModo = 'REAL' then
  begin
    LAssinado := AssinarXmlNFSe(AXml, 'DPS', 'infDPS', 'Id',
      FCaminhoCertificado, ASenhaCertificado);
    if not ValidarDPS(LAssinado, AMensagem) then
      Exit;
    if not VerificarAssinaturaXmlNFSe(LAssinado, 'infDPS', 'Id', AMensagem) then
    begin
      AMensagem := 'Assinatura inválida: ' + AMensagem;
      Exit;
    end;
    AXml := LAssinado;
  end;

  Result := True;
  AMensagem := 'DPS gerada em modo ' + FModo + '.';
end;

end.
