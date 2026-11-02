# ============================================================
# ERP 2026 - Teste de banco NOVO pelo fluxo consolidado
#
# Reproduz o que faz Scripts\executar_banco.bat, num .fdb descartavel:
#   1) schema_canonico.sql   -> banco + estrutura completa
#   2) 007_initial_data.sql  -> sementes (admin/admin123, permissoes)
#   3) DumpSchema vs DADOS.FDB real  -> diff de schema
#   4) conferencia das sementes obrigatorias
#
# O banco de teste e apagado ao final. Nunca toca no DADOS.FDB.
# ============================================================
$ErrorActionPreference = 'Stop'
$root  = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$banco = Join-Path $root 'Banco'
$bin   = Join-Path $root 'Desktop\bin'
$isql  = 'C:\Program Files\Firebird\Firebird_5_0\isql.exe'
$guid  = [guid]::NewGuid().ToString('N')
$scratch = Join-Path $env:TEMP ("erp_banco_fresco_" + $guid + '.fdb')
$tmpSql  = Join-Path $env:TEMP ("erp_banco_fresco_" + $guid + '.sql')

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

function Invoke-Iql($db, $script) {
  if ($db) { & $isql $db -user SYSDBA -password masterkey -i $script -q }
  else     { & $isql      -user SYSDBA -password masterkey -i $script -q }
}

function Query-One($db, $sql) {
  $f = Join-Path $env:TEMP ("erp_q_" + [guid]::NewGuid().ToString('N') + '.sql')
  Set-Content $f -Value $sql -Encoding ASCII
  try {
    $lines = @(& $isql $db -user SYSDBA -password masterkey -i $f -q)
    # isql imprime: cabecalho / linha de "====" / valor
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^\s*=+\s*$') {
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
          if ($lines[$j].Trim() -ne '') { return $lines[$j].Trim() }
        }
      }
    }
    return $null
  }
  finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

try {
  Step 'Compilando ferramentas'
  & (Join-Path $root 'Scripts\gerar_schema.bat') | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar GerarSchema' }
  & (Join-Path $root 'Scripts\build_dump_schema.bat') | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar DumpSchema' }

  Step "Gerando estrutura para banco descartavel"
  & (Join-Path $bin 'GerarSchema.exe') $tmpSql $scratch
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar schema_canonico' }

  Step '[1/3] schema_canonico.sql (cria banco + estrutura)'
  Invoke-Iql $null $tmpSql
  if (-not (Test-Path $scratch)) { throw 'Banco nao foi criado' }

  Step '[2/3] 007_initial_data.sql (sementes)'
  Invoke-Iql $scratch (Join-Path $banco '007_initial_data.sql')

  Step '[3/3] Conferindo estrutura x banco real'
  $novo = @(& (Join-Path $bin 'DumpSchema.exe') $scratch | Where-Object { $_ -and $_.Trim() })
  $real = @(& (Join-Path $bin 'DumpSchema.exe')          | Where-Object { $_ -and $_.Trim() })
  Write-Host ("campos: novo={0}  real={1}" -f $novo.Count, $real.Count)
  if ($novo.Count -eq 0) { throw 'Dump do banco novo veio vazio' }

  $soNovo = Compare-Object $novo $real -SyncWindow 0 | Where-Object { $_.SideIndicator -eq '<=' }
  $soReal = Compare-Object $novo $real -SyncWindow 0 | Where-Object { $_.SideIndicator -eq '=>' }
  if ($soNovo -or $soReal) {
    Write-Host "!!! DIVERGENCIA de schema !!!" -ForegroundColor Red
    @($soNovo) + @($soReal) | ForEach-Object { Write-Host ("  " + $_.InputObject) }
    exit 1
  }

  Step 'Conferindo sementes'
  $falhas = @()

  $qtdTabelas = Query-One $scratch 'SELECT COUNT(*) FROM RDB$RELATIONS WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 AND RDB$VIEW_BLR IS NULL ;'
  if ($qtdTabelas -ne '49') { $falhas += "tabelas esperado 49, veio '$qtdTabelas'" }

  $qtdGen = Query-One $scratch 'SELECT COUNT(*) FROM RDB$GENERATORS WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ;'
  if ($qtdGen -ne '49') { $falhas += "generators esperado 49, veio '$qtdGen'" }

  $admin = Query-One $scratch "SELECT LOGIN FROM USUARIO WHERE LOGIN = 'admin' ;"
  if ($admin -ne 'admin') { $falhas += "usuario admin ausente (veio '$admin')" }

  $empresa = Query-One $scratch 'SELECT COUNT(*) FROM EMPRESA ;'
  if ([int]$empresa -lt 1) { $falhas += "empresa seed ausente" }

  $perm = Query-One $scratch 'SELECT COUNT(*) FROM PERMISSAO ;'
  if ([int]$perm -lt 1) { $falhas += "permissoes seed ausentes" }

  $pais = Query-One $scratch "SELECT COUNT(*) FROM PAIS WHERE CODIGO = 'BRA' ;"
  if ([int]$pais -ne 1) { $falhas += "seed do Brasil ausente (PAIS=$pais)" }

  $ufs = Query-One $scratch 'SELECT COUNT(*) FROM ESTADO ;'
  if ([int]$ufs -ne 27) { $falhas += "27 UFs esperadas, vieram '$ufs'" }

  $grade = Query-One $scratch "SELECT COUNT(*) FROM CONFIGURACAO WHERE CHAVE = 'USA_GRADE' ;"
  if ([int]$grade -lt 1) { $falhas += "preferencia USA_GRADE ausente" }

  if ($falhas.Count) {
    Write-Host "!!! SEMENTES INCOMPLETAS !!!" -ForegroundColor Red
    $falhas | ForEach-Object { Write-Host ("  - " + $_) }
    exit 1
  }

  Write-Host ""
  Write-Host ("OK: banco novo pelo fluxo consolidado = " + $real.Count +
              " campos (diff vazio), 49 tabelas, 49 generators, admin/permissoes," +
              " Brasil + 27 UFs e USA_GRADE presentes.") -ForegroundColor Green
  exit 0
}
finally {
  foreach ($p in @($scratch, $tmpSql)) {
    if ($p -and (Test-Path $p)) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
  }
}
