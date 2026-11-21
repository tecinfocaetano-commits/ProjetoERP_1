# ERP 2026 - Roda todos os smokes da API contra a instancia ja ativa na 9000.
# Nao inicia nem reinicia a API: isso deve ser feito pelo operador, com aviso
# previo no canal de agentes quando houver trabalho paralelo.
$ErrorActionPreference = 'Stop'

$base = 'http://127.0.0.1:9000'
try {
    $health = Invoke-RestMethod -Uri "$base/api/health" -TimeoutSec 10
} catch {
    throw "API nao respondeu em $base/api/health: $($_.Exception.Message)"
}
if ($health.status -ne 'ok') {
    throw "API /api/health devolveu status '$($health.status)'."
}
Write-Host "API health: ok (pool=$($health.pool))"

$scripts = @(
    'api_clientes_crud.ps1',
    'api_auditoria.ps1',
    'api_estoque_service.ps1',
    'api_numeracao_empresa.ps1',
    'api_paginacao.ps1',
    'api_f1.ps1'
)

foreach ($script in $scripts) {
    $path = Join-Path $PSScriptRoot $script
    Write-Host "==> $script"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $path
    if ($LASTEXITCODE -ne 0) {
        throw "Falha no smoke $script (exit $LASTEXITCODE)."
    }
}

Write-Host 'API-TODOS CONCLUIDO: 6 smokes OK.'
