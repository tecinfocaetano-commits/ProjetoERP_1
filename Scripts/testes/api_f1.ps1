# ============================================================
# ERP 2026 - smoke F1: CRUD completo na API
# Sobe contra uma API ja rodando (padrao 9000). Cria cliente/produto,
# edita e exclui produto, edita e exclui orcamento, cria venda e
# confere as escritas em LOG_SISTEMA. Dados com timestamp e limpeza
# explicita no finally.
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
$Ids = @{ Cliente=0; Produto=0; Orcamento=0; Venda=0 }
$LogIds = @()
$ProdutoExcluido = $false
$OrcamentoExcluido = $false

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

function Obj([string]$Texto) {
    $valor = $Texto | ConvertFrom-Json
    return $valor
}

try {
    $Topo = UltimoNumero (Sql @('SELECT MAX(ID) FROM LOG_SISTEMA;'))

    $login = Chamada 'POST' '/api/login' '{ "login":"admin", "senha":"admin123", "empresa_id":1 }' ''
    Verificar ($login.Status -eq 200) "login falhou: $($login.Status) $($login.Body)"
    $Token = (Obj $login.Body).token
    Verificar (-not [string]::IsNullOrEmpty($Token)) 'login nao devolveu token'

    # Base: cliente ativo e produto da empresa 1
    $cliente = @{
        nome = "F1 Cliente $Stamp"; cpf_cnpj = ('6' + $Stamp); email = "f1$Stamp@exemplo.com";
        telefone = '11988880000'; cidade = 'Sao Paulo'; uf = 'SP'
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/clientes' $cliente $Token
    Verificar ($r.Status -eq 201) "POST clientes falhou: $($r.Status) $($r.Body)"
    $Ids.Cliente = [int64]((Obj $r.Body).id)

    $produto = @{
        codigo = "F1-$Stamp"; descricao = "Produto F1 $Stamp";
        preco_venda = 25.5; preco_custo = 10; ncm = '00000000'
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/produtos' $produto $Token
    Verificar ($r.Status -eq 201) "POST produtos falhou: $($r.Status) $($r.Body)"
    $Ids.Produto = UltimoNumero (Sql @('SELECT GEN_ID(GEN_PRODUTO_ID,0) FROM RDB$DATABASE;'))

    # 1) PUT produto
    $edicao = @{
        descricao = "Produto F1 editado $Stamp"; preco_venda = 33; preco_custo = 12;
        ncm = '12345678'; observacoes = "Edicao F1 $Stamp"
    } | ConvertTo-Json -Compress
    $r = Chamada 'PUT' "/api/produtos/$($Ids.Produto)" $edicao $Token
    Verificar ($r.Status -eq 200) "PUT produtos falhou: $($r.Status) $($r.Body)"
    $r = Chamada 'GET' "/api/produtos/$($Ids.Produto)" '' $Token
    Verificar ($r.Status -eq 200) "GET produto editado falhou: $($r.Status) $($r.Body)"
    $editado = Obj $r.Body
    Verificar ($editado.descricao -eq "Produto F1 editado $Stamp") "descricao nao foi editada: $($r.Body)"
    Verificar ([double]$editado.preco_venda -eq 33) "preco nao foi editado: $($r.Body)"

    # 2) POST orcamento e 3) PUT orcamento
    $orc = @{
        cliente_id = $Ids.Cliente; observacoes = "Orcamento F1 $Stamp";
        itens = @(@{ produto_id = $Ids.Produto; quantidade = 2 })
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/orcamentos' $orc $Token
    Verificar ($r.Status -eq 201) "POST orcamentos falhou: $($r.Status) $($r.Body)"
    $Ids.Orcamento = [int64]((Obj $r.Body).id)

    $orcEditado = @{
        cliente_id = $Ids.Cliente; desconto = 1.5; observacoes = "Orcamento F1 editado $Stamp";
        itens = @(@{ produto_id = $Ids.Produto; quantidade = 3; desconto = 0 })
    } | ConvertTo-Json -Compress
    $r = Chamada 'PUT' "/api/orcamentos/$($Ids.Orcamento)" $orcEditado $Token
    Verificar ($r.Status -eq 200) "PUT orcamentos falhou: $($r.Status) $($r.Body)"
    $r = Chamada 'GET' "/api/orcamentos/$($Ids.Orcamento)" '' $Token
    Verificar ($r.Status -eq 200) "GET orcamento editado falhou: $($r.Status) $($r.Body)"
    $orcLido = Obj $r.Body
    $itensOrc = @($orcLido.itens)
    Verificar ($itensOrc.Count -eq 1) "itens do orcamento nao foram substituidos: $($r.Body)"
    Verificar ([double]$itensOrc[0].quantidade -eq 3) "quantidade do orcamento nao foi editada: $($r.Body)"
    Verificar ([double]$orcLido.total -eq 97.5) "total do orcamento errado: $($r.Body)"

    # 4) POST venda (STATUS 'P' pelo Service)
    $venda = @{
        cliente_id = $Ids.Cliente; desconto = 3; observacoes = "Venda F1 $Stamp";
        itens = @(@{ produto_id = $Ids.Produto; quantidade = 2; cfop = '5102' })
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/vendas' $venda $Token
    Verificar ($r.Status -eq 201) "POST vendas falhou: $($r.Status) $($r.Body)"
    $vendaCriada = Obj $r.Body
    $Ids.Venda = [int64]$vendaCriada.id
    Verificar ($Ids.Venda -gt 0) "POST vendas nao devolveu id: $($r.Body)"
    Verificar (-not [string]::IsNullOrEmpty([string]$vendaCriada.numero)) "POST vendas nao devolveu numero: $($r.Body)"
    Verificar ([double]$vendaCriada.total -eq 63) "total da venda errado: $($r.Body)"
    $r = Chamada 'GET' "/api/vendas/$($Ids.Venda)" '' $Token
    Verificar ($r.Status -eq 200) "GET venda falhou: $($r.Status) $($r.Body)"
    $vendaLida = Obj $r.Body
    $itensVenda = @($vendaLida.itens)
    Verificar ($itensVenda.Count -eq 1) "venda nao gravou itens: $($r.Body)"
    Verificar ([double]$vendaLida.total -eq 63) "total da venda no GET errado: $($r.Body)"

    # 5) DELETE orcamento (so aberto) e 6) DELETE produto
    $r = Chamada 'DELETE' "/api/orcamentos/$($Ids.Orcamento)" '' $Token
    Verificar ($r.Status -eq 200) "DELETE orcamento falhou: $($r.Status) $($r.Body)"
    $OrcamentoExcluido = $true
    $r = Chamada 'GET' "/api/orcamentos/$($Ids.Orcamento)" '' $Token
    Verificar ($r.Status -eq 404) "orcamento excluido ainda aparece: $($r.Status) $($r.Body)"

    $r = Chamada 'DELETE' "/api/produtos/$($Ids.Produto)" '' $Token
    Verificar ($r.Status -eq 200) "DELETE produto falhou: $($r.Status) $($r.Body)"
    $ProdutoExcluido = $true
    $r = Chamada 'GET' "/api/produtos/$($Ids.Produto)" '' $Token
    Verificar ($r.Status -eq 404) "produto excluido ainda aparece: $($r.Status) $($r.Body)"

    # Auditoria: operacoes dos Services na mesma empresa/usuario do JWT
    $filtro = "ID > $Topo AND ((TABELA = 'PRODUTO' AND REGISTRO_ID = $($Ids.Produto)) OR " +
              "(TABELA = 'PEDIDO_VENDA' AND REGISTRO_ID IN ($($Ids.Orcamento), $($Ids.Venda))))"
    $out = Sql @("SELECT CAST(ID AS VARCHAR(20)) || '|' || TABELA || '|' || OPERACAO || '|' || CAST(REGISTRO_ID AS VARCHAR(20)) FROM LOG_SISTEMA WHERE $filtro ORDER BY ID;")
    $linhas = @($out -split "`r?`n" | Where-Object { $_ -match '\|' -and $_ -match 'PRODUTO|PEDIDO_VENDA' })
    $encontradas = @{}
    foreach ($linha in $linhas) {
        $p = $linha -split '\|'
        $LogIds += [int64]$p[0].Trim()
        $chave = $p[1].Trim() + '|' + $p[2].Trim() + '|' + $p[3].Trim()
        $encontradas[$chave] = $true
        Write-Host "LOG: $chave"
    }

    $esperadas = @(
        "PRODUTO|I|$($Ids.Produto)",
        "PRODUTO|U|$($Ids.Produto)",
        "PRODUTO|D|$($Ids.Produto)",
        "PEDIDO_VENDA|I|$($Ids.Orcamento)",
        "PEDIDO_VENDA|U|$($Ids.Orcamento)",
        "PEDIDO_VENDA|D|$($Ids.Orcamento)",
        "PEDIDO_VENDA|INSERT|$($Ids.Venda)"
    )
    foreach ($e in $esperadas) { Verificar ($encontradas.ContainsKey($e)) "log ausente: $e" }

    Write-Host 'API-F1 CONCLUIDO: PUT/DELETE produto, PUT/DELETE orcamento, POST venda e auditorias OK.'
    exit 0
} catch {
    Write-Host "API-F1 FALHOU: $($_.Exception.Message)"
    exit 1
} finally {
    $limpeza = @()
    if ($Ids.Venda -gt 0) {
        $limpeza += "DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = $($Ids.Venda);"
        $limpeza += "DELETE FROM PEDIDO_VENDA WHERE ID = $($Ids.Venda);"
    }
    if ($Ids.Orcamento -gt 0 -and -not $OrcamentoExcluido) {
        $limpeza += "DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = $($Ids.Orcamento);"
        $limpeza += "DELETE FROM PEDIDO_VENDA WHERE ID = $($Ids.Orcamento);"
    }
    if ($Ids.Produto -gt 0 -and -not $ProdutoExcluido) {
        $limpeza += "DELETE FROM PRODUTO WHERE ID = $($Ids.Produto);"
    }
    if ($Ids.Cliente -gt 0) { $limpeza += "DELETE FROM PESSOA WHERE ID = $($Ids.Cliente);" }
    foreach ($id in $LogIds) { $limpeza += "DELETE FROM LOG_SISTEMA WHERE ID = $id;" }
    if ($limpeza.Count -gt 0) {
        $limpeza += 'COMMIT;'
        $null = Sql $limpeza
    }
}
