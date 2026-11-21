# ============================================================
# ERP 2026 - smoke D4: auditoria LOG_SISTEMA nas rotas de escrita
# Sobe contra uma API ja rodando (padrao porta 9000), cria cliente,
# produto, movimento de estoque e orcamento, converte, exclui o
# cliente e confere os 6 registros em LOG_SISTEMA via isql.
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
$Ids = @{ Cliente=0; Produto=0; Movimento=0; Orcamento=0 }
$LogIds = @()
$ClienteExcluido = $false

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
            if ($stream) { $reader = New-Object System.IO.StreamReader($stream); $conteudo = $reader.ReadToEnd() }
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
    $nums = [regex]::Matches($Texto, '(?m)^\s*(\d+)\s*$') | ForEach-Object { [int64]$_.Groups[1].Value }
    if ($nums.Count -eq 0) { throw "SQL nao devolveu numero: $Texto" }
    return $nums[-1]
}

try {
    $Topo = UltimoNumero (Sql @('SELECT MAX(ID) FROM LOG_SISTEMA;'))

    $login = Chamada 'POST' '/api/login' "{`"login`":`"admin`",`"senha`":`"admin123`",`"empresa_id`":1}" ''
    Verificar ($login.Status -eq 200) "login falhou: $($login.Status) $($login.Body)"
    $Token = (($login.Body | ConvertFrom-Json).token)
    Verificar (-not [string]::IsNullOrEmpty($Token)) 'login nao devolveu token'

    # 1) cliente ( auditoria feita pelo TPessoaService, antes do commit )
    $cliente = @{
        nome = "D4 Cliente $Stamp"; cpf_cnpj = ('7' + $Stamp); email = "d4$Stamp@exemplo.com";
        telefone = '11999990000'; cidade = 'Sao Paulo'; uf = 'SP'
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/clientes' $cliente $Token
    Verificar ($r.Status -eq 201) "POST clientes falhou: $($r.Status) $($r.Body)"
    $Ids.Cliente = [int64](($r.Body | ConvertFrom-Json).id)
    Verificar ($Ids.Cliente -gt 0) "POST clientes nao devolveu id: $($r.Body)"

    # 2) produto
    $produto = @{
        codigo = "D4-$Stamp"; descricao = "Produto D4 $Stamp"; preco_venda = 25.5; preco_custo = 10
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/produtos' $produto $Token
    Verificar ($r.Status -eq 201) "POST produtos falhou: $($r.Status) $($r.Body)"
    $Ids.Produto = UltimoNumero (Sql @('SELECT GEN_ID(GEN_PRODUTO_ID,0) FROM RDB$DATABASE;'))

    # 3) movimento de estoque
    $mov = @{
        produto_id = $Ids.Produto; tipo = 'E'; quantidade = 3; custo_unitario = 10;
        documento = "D4-$Stamp"; observacao = "Smoke D4 $Stamp"
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/estoque/movimento' $mov $Token
    Verificar ($r.Status -eq 201) "POST estoque falhou: $($r.Status) $($r.Body)"
    $Ids.Movimento = UltimoNumero (Sql @('SELECT GEN_ID(GEN_MOVIMENTO_ESTOQUE_ID,0) FROM RDB$DATABASE;'))

    # 4) orcamento e 5) conversao
    $orc = @{
        cliente_id = $Ids.Cliente; observacoes = "Smoke D4 $Stamp";
        itens = @(@{ produto_id = $Ids.Produto; quantidade = 2 })
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/orcamentos' $orc $Token
    Verificar ($r.Status -eq 201) "POST orcamentos falhou: $($r.Status) $($r.Body)"
    $Ids.Orcamento = [int64](($r.Body | ConvertFrom-Json).id)

    $r = Chamada 'POST' "/api/orcamentos/$($Ids.Orcamento)/converter" '' $Token
    Verificar ($r.Status -eq 200) "POST converter falhou: $($r.Status) $($r.Body)"

    # 6) delete cliente (a ultima escrita auditada)
    $r = Chamada 'DELETE' "/api/clientes/$($Ids.Cliente)" '' $Token
    Verificar ($r.Status -eq 200) "DELETE cliente falhou: $($r.Status) $($r.Body)"
    $ClienteExcluido = $true

    $filtro = "ID > $Topo AND ((TABELA = 'PESSOA' AND REGISTRO_ID = $($Ids.Cliente)) OR " +
              "(TABELA = 'PRODUTO' AND REGISTRO_ID = $($Ids.Produto)) OR " +
              "(TABELA = 'MOVIMENTO_ESTOQUE' AND REGISTRO_ID = $($Ids.Movimento)) OR " +
              "(TABELA = 'PEDIDO_VENDA' AND REGISTRO_ID = $($Ids.Orcamento)))"
    $out = Sql @("SELECT CAST(ID AS VARCHAR(20)) || '|' || TABELA || '|' || OPERACAO || '|' || CAST(REGISTRO_ID AS VARCHAR(20)) || '|' || COALESCE(DADOS_NOVOS,'') FROM LOG_SISTEMA WHERE $filtro ORDER BY ID;")
    $linhas = @($out -split "`r?`n" | Where-Object { $_ -match '\|' -and $_ -match 'PESSOA|PRODUTO|MOVIMENTO_ESTOQUE|PEDIDO_VENDA' })
    foreach ($linha in $linhas) {
        $partes = $linha -split '\|'
        $LogIds += [int64]$partes[0].Trim()
        Write-Host ("LOG: {0} | {1} | {2} | reg={3} | {4}" -f $partes[0].Trim(), $partes[1].Trim(), $partes[2].Trim(), $partes[3].Trim(), $partes[4].Trim())
    }

    $tipos = @{}
    foreach ($linha in $linhas) {
        $p = $linha -split '\|'
        $tipos[$p[1].Trim() + '/' + $p[2].Trim()] = $true
    }
    $esperados = @('PESSOA/I', 'PESSOA/D', 'PRODUTO/I', 'MOVIMENTO_ESTOQUE/I', 'PEDIDO_VENDA/I', 'PEDIDO_VENDA/CONVERTER')
    foreach ($e in $esperados) { Verificar ($tipos.ContainsKey($e)) "log ausente: $e" }
    Verificar ($linhas.Count -eq 6) "quantidade de logs inesperada: $($linhas.Count) (esperado 6)"

    Write-Host 'API-AUDITORIA CONCLUIDO: 6 registros em LOG_SISTEMA (cliente I/D, produto I, estoque I, orcamento I/converter).'
    exit 0
} catch {
    Write-Host "API-AUDITORIA FALHOU: $($_.Exception.Message)"
    exit 1
} finally {
    $limpeza = @()
    if ($Ids.Orcamento -gt 0) {
        $limpeza += "DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = $($Ids.Orcamento);"
        $limpeza += "DELETE FROM PEDIDO_VENDA WHERE ID = $($Ids.Orcamento);"
    }
    if ($Ids.Movimento -gt 0) { $limpeza += "DELETE FROM MOVIMENTO_ESTOQUE WHERE ID = $($Ids.Movimento);" }
    if ($Ids.Produto -gt 0) { $limpeza += "DELETE FROM PRODUTO WHERE ID = $($Ids.Produto);" }
    if ($Ids.Cliente -gt 0 -and -not $ClienteExcluido) {
        $limpeza += "DELETE FROM PESSOA WHERE ID = $($Ids.Cliente);"
    }
    foreach ($id in $LogIds) { $limpeza += "DELETE FROM LOG_SISTEMA WHERE ID = $id;" }
    if ($limpeza.Count -gt 0) {
        $limpeza += 'COMMIT;'
        $null = Sql $limpeza
    }
}
