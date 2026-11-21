# ============================================================
# ERP 2026 - smoke F6: paginacao opcional nas listagens da API
# Verifica:
#   1) sem parametros -> array de ate 100 (contrato atual do app);
#   2) com pagina/por_pagina -> total, total_paginas e fatia correta;
#   3) pagina alem do fim -> 0 itens, total preservado;
#   4) parametros invalidos normalizados (sem 500);
#   5) total ignora registro de outra empresa.
# So cria um pedido fantasma temporario (empresa 2), limpo no finally.
# ============================================================
param(
  [string]$BaseUrl = 'http://127.0.0.1:9000'
)
$ErrorActionPreference = 'Stop'
$Db = 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\DADOS.FDB'
$Isql = 'C:\Program Files\Firebird\Firebird_5_0\isql.exe'
$Stamp = Get-Date -Format 'yyyyMMddHHmmss'
$Token = ''
$FantasmaId = 0

function Chamada([string]$Caminho) {
    $r = Invoke-WebRequest -Method GET -Uri ($BaseUrl + $Caminho) `
        -Headers @{ 'Authorization' = "Bearer $Token" } -UseBasicParsing -TimeoutSec 30
    return [pscustomobject]@{ Status=[int]$r.StatusCode; Body=[string]$r.Content }
}

function Login {
    $body = "{`"login`":`"admin`",`"senha`":`"admin123`",`"empresa_id`":1}"
    $r = Invoke-WebRequest -Method POST -Uri ($BaseUrl + '/api/login') `
        -Body $body -Headers @{ 'Content-Type' = 'application/json' } -UseBasicParsing -TimeoutSec 30
    $script:Token = (($r.Content | ConvertFrom-Json).token)
    if ([string]::IsNullOrEmpty($script:Token)) { throw 'login nao devolveu token' }
}

function Verificar([bool]$Condicao, [string]$Mensagem) {
    if (-not $Condicao) { throw $Mensagem }
}

function Sql([string[]]$Comandos) {
    $script = ($Comandos -join "`n") + "`n"
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return ($script | & $Isql -q -user SYSDBA -password masterkey $Db 2>&1 | Out-String)
    } finally { $ErrorActionPreference = $anterior }
}

function UltimoNumero([string]$Texto) {
    $nums = @([regex]::Matches($Texto, '(?m)^\s*(\d+)\s*$') | ForEach-Object { [int64]$_.Groups[1].Value })
    if ($nums.Count -eq 0) { throw "SQL nao devolveu numero: $Texto" }
    return $nums[$nums.Count - 1]
}

function Contar([string]$Tabela, [string]$Extra = '') {
    return [int](UltimoNumero (Sql @("SELECT COUNT(*) FROM $Tabela WHERE EMPRESA_ID = 1 $Extra;")))
}

function TotalPaginas([int]$Total, [int]$PorPagina) {
    if ($Total -le 0) { return 0 }
    return [int][math]::Ceiling($Total / [double]$PorPagina)
}

function TestarLista([string]$Rota, [int]$Total, [string]$ChaveId) {
    # Contrato antigo: array (sem parametros)
    $r = Chamada $Rota
    Verificar ($r.Status -eq 200) "GET $Rota falhou: $($r.Status) $($r.Body)"
    $jsonArray = ConvertFrom-Json -InputObject $r.Body
    $array = @($jsonArray)
    Verificar ($r.Body.TrimStart().StartsWith('[')) "$Rota sem parametros nao devolveu array"
    $esperado = [math]::Min($Total, 100)
    Verificar ($array.Count -eq $esperado) "$Rota sem parametros: $($array.Count) itens, esperado $esperado"
    Write-Host "$Rota sem parametros: array com $($array.Count) itens (contrato mantido)"

    # Pagina 1
    $r = Chamada "${Rota}?pagina=1&por_pagina=2"
    Verificar ($r.Status -eq 200) "GET paginado falhou: $($r.Status) $($r.Body)"
    $p1 = ConvertFrom-Json -InputObject $r.Body
    Verificar ([int]$p1.total -eq $Total) "$Rota total=$($p1.total), esperado $Total"
    Verificar ([int]$p1.pagina -eq 1) "$Rota pagina=$($p1.pagina)"
    Verificar ([int]$p1.por_pagina -eq 2) "$Rota por_pagina=$($p1.por_pagina)"
    Verificar ([int]$p1.total_paginas -eq (TotalPaginas $Total 2)) "$Rota total_paginas=$($p1.total_paginas)"
    Verificar (@($p1.itens).Count -eq [math]::Min(2, $Total)) "$Rota pagina 1 com $(@($p1.itens).Count) itens"
    Write-Host "$Rota pagina 1/2: total=$($p1.total), paginas=$($p1.total_paginas), itens=$(@($p1.itens).Count)"

    # Pagina 2 (quando houver)
    if ($Total -gt 2) {
        $r = Chamada "${Rota}?pagina=2&por_pagina=2"
        $p2 = ConvertFrom-Json -InputObject $r.Body
        $esperado2 = [math]::Min(2, [math]::Max(0, $Total - 2))
        Verificar (@($p2.itens).Count -eq $esperado2) "$Rota pagina 2 com $(@($p2.itens).Count) itens, esperado $esperado2"
        $id1 = if ($ChaveId) { @($p1.itens)[0].$ChaveId } else { @($p1.itens)[0].numero }
        $id2 = if ($ChaveId) { @($p2.itens)[0].$ChaveId } else { @($p2.itens)[0].numero }
        Verificar ("$id1" -ne "$id2") "$Rota paginas 1 e 2 repetiram o primeiro item"
        Write-Host "$Rota pagina 2/2: itens=$(@($p2.itens).Count), primeiro item diferente da pagina 1"
    }

    # Pagina muito alem do fim
    $r = Chamada "${Rota}?pagina=999999&por_pagina=2"
    $pfim = ConvertFrom-Json -InputObject $r.Body
    Verificar (@($pfim.itens).Count -eq 0) "$Rota pagina 999999 nao veio vazia"
    Verificar ([int]$pfim.total -eq $Total) "$Rota perdeu o total na pagina 999999"
    Write-Host "$Rota pagina 999999: 0 itens, total preservado=$($pfim.total)"

    # Parametros invalidos: normalizar, nunca 500
    $r = Chamada "${Rota}?pagina=0&por_pagina=999999"
    Verificar ($r.Status -eq 200) "$Rota com parametros invalidos deu $($r.Status)"
    $pinv = ConvertFrom-Json -InputObject $r.Body
    Verificar ([int]$pinv.pagina -eq 1) "$Rota nao normalizou pagina=0"
    Verificar ([int]$pinv.por_pagina -eq 200) "$Rota nao limitou por_pagina a 200 (veio $($pinv.por_pagina))"
    Write-Host "$Rota parametros invalidos: pagina=1, por_pagina=200 (200 OK)"
}

try {
    Login

    $vendas = Contar 'PEDIDO_VENDA'
    $receber = Contar 'CONTA_RECEBER' "AND STATUS = 'A'"
    $pagar = Contar 'CONTA_PAGAR' "AND STATUS = 'A'"

    TestarLista '/api/vendas' $vendas 'id'
    Write-Host ''
    TestarLista '/api/financeiro/receber' $receber 'id'
    Write-Host ''
    TestarLista '/api/financeiro/pagar' $pagar 'id'

    # Isolamento: pedido da empresa 2 nao entra no total da empresa 1
    $insert = "INSERT INTO PEDIDO_VENDA (ID, EMPRESA_ID, CLIENTE_ID, NUMERO, STATUS, TOTAL, OBSERVACOES) VALUES (GEN_ID(GEN_PEDIDO_VENDA_ID,1), 2, 1, 'F6-$Stamp', 'P', 0, 'F6-FANTASMA-$Stamp');"
    $saida = Sql @($insert, 'COMMIT;')
    Verificar ($saida -notmatch 'Statement failed') "insert fantasma falhou: $saida"
    $FantasmaId = UltimoNumero (Sql @('SELECT GEN_ID(GEN_PEDIDO_VENDA_ID,0) FROM RDB$DATABASE;'))
    $r = Chamada '/api/vendas?pagina=1&por_pagina=2'
    $depois = [int]((ConvertFrom-Json -InputObject $r.Body).total)
    Verificar ($depois -eq $vendas) "total da empresa 1 mudou com pedido da empresa 2: $vendas -> $depois"
    Write-Host "Isolamento por empresa: total da empresa 1 continuou $depois"

    Write-Host 'API-PAGINACAO CONCLUIDO: contrato legado mantido, total/paginas corretos e isolamento por empresa OK.'
    exit 0
} catch {
    Write-Host "API-PAGINACAO FALHOU: $($_.Exception.Message)"
    exit 1
} finally {
    if ($FantasmaId -gt 0) {
        $null = Sql @("DELETE FROM PEDIDO_VENDA WHERE ID = $FantasmaId;", 'COMMIT;')
    }
}
