<#
  ERP 2026 - Gera um certificado autoassinado de teste (.pfx)
  -----------------------------------------------------------
  Serve APENAS para validar o XML da NF-e localmente
  (ERP2026.exe --validar-nfe=<pedido>). NAO vale para a SEFAZ.

  Uso:
    powershell -ExecutionPolicy Bypass -File Scripts\gerar_certificado_teste.ps1
    powershell ... -Cnpj 00000000000191 -Senha teste123 -Caminho C:\certificados\teste.pfx
#>
param(
  [string]$Cnpj = '00000000000191',
  [string]$Senha = 'teste123',
  [string]$Caminho = 'C:\certificados\teste.pfx'
)

$ErrorActionPreference = 'Stop'

$Cnpj = ($Cnpj -replace '\D', '')
if ($Cnpj.Length -ne 14) {
  throw 'CNPJ deve ter 14 digitos.'
}

$pasta = Split-Path -Parent $Caminho
if (-not [string]::IsNullOrWhiteSpace($pasta)) {
  New-Item -ItemType Directory -Force -Path $pasta | Out-Null
}
if (Test-Path $Caminho) {
  Remove-Item $Caminho -Force
}

$subject = "CN=Empresa Demo:$Cnpj, OU=Teste, O=Empresa Demo, L=Sao Paulo, S=SP, C=BR"
$secure = ConvertTo-SecureString -String $Senha -Force -AsPlainText

$cert = New-SelfSignedCertificate `
  -Type Custom `
  -Subject $subject `
  -KeySpec Signature `
  -KeyExportPolicy Exportable `
  -KeyAlgorithm RSA `
  -KeyLength 2048 `
  -HashAlgorithm SHA256 `
  -CertStoreLocation 'Cert:\CurrentUser\My' `
  -NotAfter (Get-Date).AddYears(1)

try {
  Export-PfxCertificate -Cert $cert -FilePath $Caminho -Password $secure | Out-Null
}
finally {
  # Remove do repositorio do usuario; o PFX ja contem a chave privada.
  Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue
}

Write-Host "Certificado gerado: $Caminho"
Write-Host "CNPJ no subject: $Cnpj"
Write-Host "Senha: $Senha"
Write-Host ""
Write-Host "Valide a NF-e com:"
Write-Host "  Desktop\bin\ERP2026.exe --validar-nfe=1003 --cert=$Caminho --senha=$Senha"
