# ============================================================
# ERP 2026 - Validação round-trip do schema_canonico.sql
#
# 1) Compila GerarSchema e DumpSchema
# 2) Gera schema_canonico.sql apontando para um .fdb descartável
# 3) Executa o script no isql (cria o banco do zero)
# 4) DumpSchema no banco novo vs. DumpSchema no DADOS.FDB real
# 5) Diff: se idêntico, o script canônico reproduz o schema real
#
# O banco de teste é apagado ao final. Nunca toca no DADOS.FDB.
# ============================================================
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$isql = 'C:\Program Files\Firebird\Firebird_5_0\isql.exe'
$scratch = Join-Path $env:TEMP ("erp_schema_roundtrip_" + [guid]::NewGuid().ToString('N') + '.fdb')
$tmpSql  = Join-Path $env:TEMP ("erp_schema_roundtrip_" + [guid]::NewGuid().ToString('N') + '.sql')

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

try {
  Step 'Compilando ferramentas'
  & (Join-Path $root 'Scripts\gerar_schema.bat') | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar GerarSchema' }
  & (Join-Path $root 'Scripts\build_dump_schema.bat') | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar DumpSchema' }

  Step "Gerando script apontando para banco descartável"
  & (Join-Path $root 'Desktop\bin\GerarSchema.exe') $tmpSql $scratch
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar schema_canonico' }

  Step 'Criando banco do zero com o script canônico'
  & $isql -user SYSDBA -password masterkey -i $tmpSql -q
  if ($LASTEXITCODE -ne 0) { throw 'isql falhou ao executar o script canônico' }
  if (-not (Test-Path $scratch)) { throw 'Banco de teste não foi criado' }

  Step 'Dump do schema novo (round-trip)'
  $novo = & (Join-Path $root 'Desktop\bin\DumpSchema.exe') $scratch
  Step 'Dump do schema real (DADOS.FDB)'
  $real = & (Join-Path $root 'Desktop\bin\DumpSchema.exe')

  $novoS = @($novo | Where-Object { $_ -and $_.Trim() -ne '' })
  $realS = @($real | Where-Object { $_ -and $_.Trim() -ne '' })

  Write-Host ""
  Write-Host ("campos: novo={0}  real={1}" -f $novoS.Count, $realS.Count)

  $soNovo = Compare-Object $novoS $realS -SyncWindow 0 |
            Where-Object { $_.SideIndicator -eq '<=' }
  $soReal = Compare-Object $novoS $realS -SyncWindow 0 |
            Where-Object { $_.SideIndicator -eq '=>' }

  if ($novoS.Count -eq 0) { throw 'Dump do banco novo veio vazio' }

  if ($soNovo -or $soReal) {
    Write-Host "`n!!! DIVERGENCIA entre schema canonico e banco real !!!" -ForegroundColor Red
    if ($soNovo) {
      Write-Host "`n-- Só no banco novo (round-trip):" -ForegroundColor Yellow
      $soNovo | ForEach-Object { Write-Host ("  " + $_.InputObject) }
    }
    if ($soReal) {
      Write-Host "`n-- Só no banco real (faltou no round-trip):" -ForegroundColor Yellow
      $soReal | ForEach-Object { Write-Host ("  " + $_.InputObject) }
    }
    exit 1
  }

  Write-Host "`nOK: schema_canonico.sql reproduz o schema real ($($realS.Count) campos, diff vazio)." -ForegroundColor Green
  exit 0
}
finally {
  if (Test-Path $scratch) { Remove-Item $scratch -Force -ErrorAction SilentlyContinue }
  if (Test-Path $tmpSql)  { Remove-Item $tmpSql  -Force -ErrorAction SilentlyContinue }
}
