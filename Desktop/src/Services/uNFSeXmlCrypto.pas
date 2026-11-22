unit uNFSeXmlCrypto;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Assinatura/validação XML da NFS-e Nacional
  ------------------------------------------------------------
  Marco 3.92. Esta unit é a ÚNICA porta de entrada para o ACBr
  no caminho da NFS-e. Toda a API pública usa String/Boolean,
  sem tipos do ACBr na interface, para que Tests.lpi continue
  compilando sem -dACBr e sem OpenSSL/libxml2.

  No app (ERP2026.lpi, com -dACBr) a implementação real usa
  TDFeSSL. Nos testes, as funções devolvem mensagem explicativa
  e o TNFSeHelper cai para a validação estrutural do DPS.

  Nenhuma função desta unit faz HTTP: Assinar, Validar e
  VerificarAssinatura são operações locais.
  ============================================================ }

interface

uses
  Classes, SysUtils;

{ True quando a unit foi compilada com -dACBr (app). }
function NFSeXmlDisponivel: Boolean;

{ Assina o DPS. ACBrDFeSSL.Assinar é local: não envia a XML. }
function AssinarXmlNFSe(const AXml, ADocElement, AInfElement, AIdAttr,
  AArquivoPFX, ASenhaPFX: string): string;

{ Valida o XML contra o XSD informado (path completo). }
function ValidarXmlNFSe(const AXml, AArqXSD: string;
  out AMsgErro: string): Boolean;

{ Confere a assinatura já presente no XML. Não precisa de PFX:
  a chave pública vem do próprio XML assinado. }
function VerificarAssinaturaXmlNFSe(const AXml, AInfElement, AIdAttr: string;
  out AMsgErro: string): Boolean;

implementation

{$IFDEF ACBR}
uses
  ACBrDFeSSL, ACBrUtil.XMLHTML;
{$ENDIF}

function SemACBr(const AOperacao: string): string;
begin
  Result := AOperacao + ' da NFS-e desabilitada: recompile com -dACBr ' +
    'e com o pacote ACBr_NFe/ACBrDFeComum (app ERP2026.lpi).';
end;

function NFSeXmlDisponivel: Boolean;
begin
  {$IFDEF ACBR}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

{$IFDEF ACBR}
function CriarSSL: TDFeSSL;
begin
  Result := TDFeSSL.Create;
  try
    { PFX local, sem HTTP (URLPFX fica vazio) e assinatura libxml2. }
    Result.SSLCryptLib   := cryOpenSSL;
    Result.SSLHttpLib    := httpNone;
    Result.SSLXmlSignLib := xsLibXml2;
    { TDFeSSL.Create usa SHA1 por padrão; o padrão nacional exige SHA256. }
    Result.SSLDgst       := dgstSHA256;
  except
    Result.Free;
    raise;
  end;
end;
{$ENDIF}

function AssinarXmlNFSe(const AXml, ADocElement, AInfElement, AIdAttr,
  AArquivoPFX, ASenhaPFX: string): string;
{$IFDEF ACBR}
var
  LSSL: TDFeSSL;
  LXmlUTF8: string;
begin
  if AArquivoPFX = '' then
    raise Exception.Create('Caminho do certificado PFX não informado.');
  if not FileExists(AArquivoPFX) then
    raise Exception.Create('Certificado PFX não encontrado: ' + AArquivoPFX);

  LXmlUTF8 := ConverteXMLtoUTF8(AXml);
  LSSL := CriarSSL;
  try
    LSSL.ArquivoPFX := AArquivoPFX;
    LSSL.Senha := ASenhaPFX;
    LSSL.CarregarCertificado;
    Result := LSSL.Assinar(LXmlUTF8, ADocElement, AInfElement,
      '', '', '', AIdAttr);
  finally
    LSSL.Free;
  end;
end;
{$ELSE}
begin
  Result := '';
  raise Exception.Create(SemACBr('Assinatura'));
end;
{$ENDIF}

function ValidarXmlNFSe(const AXml, AArqXSD: string;
  out AMsgErro: string): Boolean;
{$IFDEF ACBR}
var
  LSSL: TDFeSSL;
begin
  AMsgErro := '';
  if Trim(AArqXSD) = '' then
    raise Exception.Create('XSD da NFS-e não informado.');
  if not FileExists(AArqXSD) then
    raise Exception.Create('XSD da NFS-e não encontrado: ' + AArqXSD);

  LSSL := CriarSSL;
  try
    Result := LSSL.Validar(ConverteXMLtoUTF8(AXml), AArqXSD, AMsgErro);
  finally
    LSSL.Free;
  end;
end;
{$ELSE}
begin
  AMsgErro := SemACBr('Validação XSD');
  Result := False;
end;
{$ENDIF}

function VerificarAssinaturaXmlNFSe(const AXml, AInfElement, AIdAttr: string;
  out AMsgErro: string): Boolean;
{$IFDEF ACBR}
var
  LSSL: TDFeSSL;
begin
  AMsgErro := '';
  LSSL := CriarSSL;
  try
    Result := LSSL.VerificarAssinatura(AXml, AMsgErro, AInfElement,
      '', '', '', AIdAttr);
  finally
    LSSL.Free;
  end;
end;
{$ELSE}
begin
  AMsgErro := SemACBr('Verificação de assinatura');
  Result := False;
end;
{$ENDIF}

end.
