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
  # D8: forcar UTF8 no cliente tambem (SET NAMES no seed so nao basta
  # se o isql abrir a conexao com WIN1252, por exemplo).
  if ($db) { & $isql $db -user SYSDBA -password masterkey -ch UTF8 -i $script -q }
  else     { & $isql      -user SYSDBA -password masterkey -ch UTF8 -i $script -q }
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
  # D7: o script_completo.sql precisa apontar para o fluxo canonico
  # e nao pode prender o repositorio a um caminho absoluto.
  Step 'Conferindo script_completo.sql (D7)'
  $legado = [IO.File]::ReadAllText((Join-Path $banco 'script_completo.sql'))
  if ($legado -notmatch "INPUT\s+'schema_canonico\.sql'") { throw 'script_completo.sql nao inclui schema_canonico.sql' }
  if ($legado -notmatch "INPUT\s+'007_initial_data\.sql'") { throw 'script_completo.sql nao inclui 007_initial_data.sql' }
  if ($legado -match '(?i)C:\\|/Users/|/home/') { throw 'script_completo.sql ainda tem caminho absoluto' }
  $inputs = @($legado -split "`r?`n" | Where-Object { $_ -match '^\s*INPUT\s+' })
  if ($inputs.Count -ne 2) { throw "script_completo.sql deve ter exatamente 2 INPUTs (veio $($inputs.Count))" }
  $foraDoFluxo = @($inputs | Where-Object { $_ -notmatch "'(schema_canonico|007_initial_data)\.sql'" })
  if ($foraDoFluxo.Count) { throw 'script_completo.sql ainda referencia migrations legacy 002..008' }

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

  # D3 fundiu CLIENTE+FORNECEDOR em PESSOA: GEN_CLIENTE_ID e
  # GEN_FORNECEDOR_ID viraram GEN_PESSOA_ID (49 -> 48).
  $qtdGen = Query-One $scratch 'SELECT COUNT(*) FROM RDB$GENERATORS WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ;'
  if ($qtdGen -ne '48') { $falhas += "generators esperado 48, veio '$qtdGen'" }

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

  # D8: 'Peça' em UTF-8 = 4 caracteres / 5 bytes. Com dupla codificacao
  # (cliente WIN1252 lendo arquivo UTF-8) vira 5 caracteres / 7 bytes.
  $caracteres = Query-One $scratch "SELECT CHAR_LENGTH(DESCRICAO) FROM UNIDADE WHERE SIGLA = 'PC' ;"
  $bytes = Query-One $scratch "SELECT OCTET_LENGTH(DESCRICAO) FROM UNIDADE WHERE SIGLA = 'PC' ;"
  if (($caracteres -ne '4') -or ($bytes -ne '5')) {
    $falhas += "acento da seed UNIDADE.PC corrompido (chars='$caracteres', bytes='$bytes'; esperado 4/5)"
  }

  if ($falhas.Count) {
    Write-Host "!!! SEMENTES INCOMPLETAS !!!" -ForegroundColor Red
    $falhas | ForEach-Object { Write-Host ("  - " + $_) }
    exit 1
  }

  Write-Host ""
  Write-Host ("OK: banco novo pelo fluxo consolidado = " + $real.Count +
              " campos (diff vazio), 49 tabelas, 48 generators, admin/permissoes," +
              " Brasil + 27 UFs, USA_GRADE, acentos UTF-8 e script_completo canonico.") -ForegroundColor Green
  exit 0
}
finally {
  foreach ($p in @($scratch, $tmpSql)) {
    if ($p -and (Test-Path $p)) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
  }
}
