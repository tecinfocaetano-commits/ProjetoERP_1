# ============================================================
# ERP 2026 - smoke F5: numeracao de orcamento por empresa
# Cria cliente/produto, grava orcamento na empresa 1, insere um
# pedido "fantasma" da empresa 2 com NUMERO alto e confirma que o
# proximo orcamento da empresa 1 continua na sequencia dele.
# Limpeza explicita de tudo no finally.
# ============================================================
param(
  [string]$BaseUrl = 'http://127.0.0.1:9000'
)
$ErrorActionPreference = 'Stop'
$Db = 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\DADOS.FDB'
$Isql = 'C:\Program Files\Firebird\Firebird_5_0\isql.exe'
$Stamp = Get-Date -Format 'yyyyMMddHHmmss'
$Token = ''
$ClienteId = 0
$ProdutoId = 0
$Orc1Id = 0
$Orc2Id = 0
$FantasmaId = 0
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

function NovoOrcamento([int64]$Cliente, [int64]$Produto, [string]$Obs) {
    $body = @{
        cliente_id = $Cliente; observacoes = $Obs;
        itens = @(@{ produto_id = $Produto; quantidade = 1 })
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/orcamentos' $body $Token
    Verificar ($r.Status -eq 201) "POST orcamento falhou: $($r.Status) $($r.Body)"
    return ($r.Body | ConvertFrom-Json)
}

try {
    $login = Chamada 'POST' '/api/login' "{`"login`":`"admin`",`"senha`":`"admin123`",`"empresa_id`":1}" ''
    Verificar ($login.Status -eq 200) "login falhou: $($login.Status) $($login.Body)"
    $Token = (($login.Body | ConvertFrom-Json).token)
    Verificar (-not [string]::IsNullOrEmpty($Token)) 'login nao devolveu token'

    $cliente = @{
        nome = "F5 Cliente $Stamp"; cpf_cnpj = ('8' + $Stamp);
        email = "f5$Stamp@exemplo.com"; telefone = '11999990000'
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/clientes' $cliente $Token
    Verificar ($r.Status -eq 201) "POST cliente falhou: $($r.Status) $($r.Body)"
    $ClienteId = [int64](($r.Body | ConvertFrom-Json).id)

    $produto = @{
        codigo = "F5-$Stamp"; descricao = "Produto F5 $Stamp";
        preco_venda = 10; preco_custo = 5
    } | ConvertTo-Json -Compress
    $r = Chamada 'POST' '/api/produtos' $produto $Token
    Verificar ($r.Status -eq 201) "POST produto falhou: $($r.Status) $($r.Body)"
    $ProdutoId = UltimoNumero (Sql @('SELECT GEN_ID(GEN_PRODUTO_ID,0) FROM RDB$DATABASE;'))

    # 1) primeiro orçamento da empresa 1
    $orc1 = NovoOrcamento $ClienteId $ProdutoId "F5-A $Stamp"
    $Orc1Id = [int64]$orc1.id
    $Num1 = [int]$orc1.numero
    Write-Host "Orcamento 1 (empresa 1): id=$Orc1Id numero=$Num1"

    # 2) pedido fantasma da empresa 2 com numero muito maior
    $insert = "INSERT INTO PEDIDO_VENDA (ID, EMPRESA_ID, CLIENTE_ID, NUMERO, STATUS, TOTAL, OBSERVACOES) VALUES (GEN_ID(GEN_PEDIDO_VENDA_ID,1), 2, $ClienteId, '990000', 'P', 0, 'F5-FANTASMA-$Stamp');"
    $saida = Sql @($insert, 'COMMIT;')
    Verificar ($saida -notmatch 'Statement failed') "insert fantasma falhou: $saida"
    $FantasmaId = UltimoNumero (Sql @('SELECT GEN_ID(GEN_PEDIDO_VENDA_ID,0) FROM RDB$DATABASE;'))
    Write-Host "Pedido fantasma (empresa 2): id=$FantasmaId numero=990000"

    # 3) segundo orçamento da empresa 1: nao pode herdar 990000
    $orc2 = NovoOrcamento $ClienteId $ProdutoId "F5-B $Stamp"
    $Orc2Id = [int64]$orc2.id
    $Num2 = [int]$orc2.numero
    Write-Host "Orcamento 2 (empresa 1): id=$Orc2Id numero=$Num2"

    Verificar ($Num2 -eq ($Num1 + 1)) "sequencia por empresa quebrada: $Num1 -> $Num2 (esperado $($Num1+1))"
    Verificar ($Num2 -lt 990000) "orcamento da empresa 1 herdou o numero da empresa 2: $Num2"

    Write-Host 'API-NUMERACAO-EMPRESA CONCLUIDO: 990000 da empresa 2 nao interferiu na sequencia da empresa 1.'
    exit 0
} catch {
    Write-Host "API-NUMERACAO-EMPRESA FALHOU: $($_.Exception.Message)"
    exit 1
} finally {
    $limpeza = @()
    foreach ($id in @($Orc1Id, $Orc2Id)) {
        if ($id -gt 0) {
            $limpeza += "DELETE FROM ITEM_PEDIDO WHERE PEDIDO_VENDA_ID = $id;"
            $limpeza += "DELETE FROM LOG_SISTEMA WHERE TABELA = 'PEDIDO_VENDA' AND REGISTRO_ID = $id;"
            $limpeza += "DELETE FROM PEDIDO_VENDA WHERE ID = $id;"
        }
    }
    if ($FantasmaId -gt 0) { $limpeza += "DELETE FROM PEDIDO_VENDA WHERE ID = $FantasmaId;" }
    if ($ProdutoId -gt 0) { $limpeza += "DELETE FROM PRODUTO WHERE ID = $ProdutoId;" }
    if ($ClienteId -gt 0) { $limpeza += "DELETE FROM PESSOA WHERE ID = $ClienteId;" }
    if ($limpeza.Count -gt 0) {
        $limpeza += 'COMMIT;'
        $null = Sql $limpeza
    }
}
