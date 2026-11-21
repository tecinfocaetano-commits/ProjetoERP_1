# ============================================================
# ERP 2026 - smoke D5: movimento de estoque pelo TEstoqueService
# Sobe contra uma API ja rodando (padrao porta 9000) e verifica:
#   1) movimento valido -> 201 com id, saldo atualizado pela trigger;
#   2) exatamente 1 log MOVIMENTO_ESTOQUE/INSERT na transacao;
#   3) produto de outra empresa -> 400 (validacao por empresa);
#   4) quantidade zero -> 400 (validacao do Service).
# Dados com timestamp e limpeza explicita no finally.
# ============================================================
param(
  [string]$BaseUrl = 'http://127.0.0.1:9000'
)
$ErrorActionPreference = 'Stop'
$Db = 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\DADOS.FDB'
$Isql = 'C:\Program Files\Firebird\Firebird_5_0\isql.exe'
$Stamp = Get-Date -Format 'yyyyMMddHHmmss'
$Token = ''
$Topo = 0
$ProdutoId = 0
$ProdutoOutraEmpresaId = 0
$MovimentoId = 0
$LogIds = @()

function Chamada([string]$Metodo, [string]$Caminho, [string]$Body, [string]$Bearer) {
    $headers = @{ 'Content-Type' = 'application/json' }
    if ($Bearer) { $headers['Authorization'] = "Bearer $Bearer" }
    $args = @{ Method=$Metodo; Uri=($BaseUrl + $Caminho); Headers=$headers; UseBasicParsing=$true; TimeoutSec=30 }
    if ($Body) { $args['Body'] = $Body }
    try {
        $r = Invoke-WebRequest @args
        return [pscustomobject]@{ Status=[int]$r.StatusCode; Body=[string]$r.Content }
    } catch {
        $resp = $_.Exception.Response
        $status = 0; $conteudo = ''
        if ($resp) {
            $status = [int]$resp.StatusCode
            $stream = $resp.GetResponseStream()
            if ($stream) {
                if ($stream.CanSeek) { $stream.Position = 0 }
                $reader = New-Object System.IO.StreamReader($stream)
                $conteudo = $reader.ReadToEnd()
            }
        }
        return [pscustomobject]@{ Status=$status; Body=$conteudo }
    }
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

function UltimoDecimal([string]$Texto) {
    $m = @([regex]::Matches($Texto, '(?m)^\s*(-?\d+(?:\.\d+)?)\s*$'))
    if ($m.Count -eq 0) { throw "SQL nao devolveu decimal: $Texto" }
    return [double]::Parse($m[$m.Count - 1].Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

function CriarProduto([string]$Codigo) {
    $body = @{
        codigo = $Codigo; descricao = "Produto D5 $Codigo";
        preco_venda = 25.5; preco_custo = 10
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/produtos' $body $Token
    Verificar ($r.Status -eq 201) "POST produtos falhou: $($r.Status) $($r.Body)"
    $id = 0
    try { $id = [int64](($r.Body | ConvertFrom-Json).id) } catch { $id = 0 }
    if ($id -le 0) { $id = UltimoNumero (Sql @('SELECT GEN_ID(GEN_PRODUTO_ID,0) FROM RDB$DATABASE;')) }
    return $id
}

try {
    $Topo = UltimoNumero (Sql @('SELECT MAX(ID) FROM LOG_SISTEMA;'))

    $login = Chamada 'POST' '/api/login' "{`"login`":`"admin`",`"senha`":`"admin123`",`"empresa_id`":1}" ''
    Verificar ($login.Status -eq 200) "login falhou: $($login.Status) $($login.Body)"
    $Token = (($login.Body | ConvertFrom-Json).token)
    Verificar (-not [string]::IsNullOrEmpty($Token)) 'login nao devolveu token'

    $ProdutoId = CriarProduto "D5-$Stamp"
    $SaldoAntes = UltimoDecimal (Sql @("SELECT CAST(COALESCE(SUM(QUANTIDADE),0) AS DOUBLE PRECISION) FROM ESTOQUE WHERE PRODUTO_ID = $ProdutoId;"))

    # 1) movimento valido
    $mov = @{
        produto_id = $ProdutoId; tipo = 'E'; quantidade = 3; custo_unitario = 10;
        documento = "D5-$Stamp"; observacao = "Smoke D5 $Stamp"
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/estoque/movimento' $mov $Token
    Verificar ($r.Status -eq 201) "POST movimento valido falhou: $($r.Status) $($r.Body)"
    $MovimentoId = [int64](($r.Body | ConvertFrom-Json).id)
    Verificar ($MovimentoId -gt 0) "POST movimento nao devolveu id: $($r.Body)"
    Write-Host "POST movimento valido: 201, id=$MovimentoId"

    $SaldoDepois = UltimoDecimal (Sql @("SELECT CAST(COALESCE(SUM(QUANTIDADE),0) AS DOUBLE PRECISION) FROM ESTOQUE WHERE PRODUTO_ID = $ProdutoId;"))
    Verificar ([math]::Abs(($SaldoDepois - $SaldoAntes) - 3) -lt 0.0001) "saldo nao atualizado: $SaldoAntes -> $SaldoDepois"
    Write-Host "Saldo pela trigger TRG_MOVEST_AI: $SaldoAntes -> $SaldoDepois"

    # 2) auditoria atomica do Service (uma unica entrada INSERT)
    $out = Sql @("SELECT CAST(ID AS VARCHAR(20)) || '|' || OPERACAO || '|' || COALESCE(DADOS_NOVOS,'') FROM LOG_SISTEMA WHERE ID > $Topo AND TABELA = 'MOVIMENTO_ESTOQUE' AND REGISTRO_ID = $MovimentoId ORDER BY ID;")
    $linhas = @($out -split "`r?`n" | Where-Object { $_ -match '\|INSERT\|' })
    Verificar ($linhas.Count -eq 1) "auditoria inesperada: $($linhas.Count) registros (esperado 1). $out"
    $LogIds += [int64](($linhas[0] -split '\|')[0].Trim())
    Write-Host ("LOG: {0}" -f $linhas[0].Trim())

    # 3) produto de outra empresa (UPDATE direto so para simular isolamento)
    $ProdutoOutraEmpresaId = CriarProduto "D5E-$Stamp"
    $null = Sql @("UPDATE PRODUTO SET EMPRESA_ID = 2 WHERE ID = $ProdutoOutraEmpresaId;", 'COMMIT;')
    $movOutra = @{
        produto_id = $ProdutoOutraEmpresaId; tipo = 'E'; quantidade = 1
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/estoque/movimento' $movOutra $Token
    Verificar ($r.Status -eq 400) "produto de outra empresa nao foi recusado: $($r.Status) $($r.Body)"
    Verificar ($r.Body -match 'Produto') "mensagem inesperada: $($r.Body)"
    Write-Host "Produto de outra empresa: 400 $($r.Body)"

    # 4) validacao de quantidade
    $movInvalido = @{
        produto_id = $ProdutoId; tipo = 'E'; quantidade = 0
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/estoque/movimento' $movInvalido $Token
    Verificar ($r.Status -eq 400) "quantidade zero nao foi recusada: $($r.Status) $($r.Body)"
    Write-Host "Quantidade zero: 400 $($r.Body)"

    Write-Host 'API-ESTOQUE-D5 CONCLUIDO: 201 atomico, saldo pela trigger, 1 log INSERT, 400 para outra empresa e quantidade invalida.'
    exit 0
} catch {
    Write-Host "API-ESTOQUE-D5 FALHOU: $($_.Exception.Message)"
    exit 1
} finally {
    $limpeza = @()
    foreach ($id in $LogIds) { $limpeza += "DELETE FROM LOG_SISTEMA WHERE ID = $id;" }
    if ($MovimentoId -gt 0) { $limpeza += "DELETE FROM MOVIMENTO_ESTOQUE WHERE ID = $MovimentoId;" }
    if ($ProdutoId -gt 0) {
        $limpeza += "DELETE FROM ESTOQUE WHERE PRODUTO_ID = $ProdutoId;"
        $limpeza += "DELETE FROM PRODUTO WHERE ID = $ProdutoId;"
    }
    if ($ProdutoOutraEmpresaId -gt 0) {
        $limpeza += "DELETE FROM ESTOQUE WHERE PRODUTO_ID = $ProdutoOutraEmpresaId;"
        $limpeza += "DELETE FROM PRODUTO WHERE ID = $ProdutoOutraEmpresaId;"
    }
    if ($limpeza.Count -gt 0) {
        $limpeza += 'COMMIT;'
        $null = Sql $limpeza
    }
}
