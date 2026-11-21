# ============================================================
# ERP 2026 - smoke da API de clientes (F4/D9)
# Sobe contra uma API ja rodando, cria/edita/le/apaga um cliente
# com dados timestamp e limpa tudo no finally.
# ============================================================
$ErrorActionPreference = 'Stop'
$BaseUrl = 'http://127.0.0.1:9000'
$Stamp = Get-Date -Format 'yyyyMMddHHmmss'
$Nome = "Cliente API CRUD $Stamp"
$Cpf = '9' + $Stamp          # 15 digitos, unico por execucao
$Token = ''
$IdCriado = 0

function Chamada([string]$Metodo, [string]$Caminho, [string]$Body, [string]$Bearer) {
    $headers = @{ 'Content-Type' = 'application/json' }
    if ($Bearer) { $headers['Authorization'] = "Bearer $Bearer" }
    $args = @{
        Method = $Metodo
        Uri = $BaseUrl + $Caminho
        Headers = $headers
        UseBasicParsing = $true
    }
    if ($Body) { $args['Body'] = $Body }
    try {
        $r = Invoke-WebRequest @args
        return [pscustomobject]@{ Status = [int]$r.StatusCode; Body = [string]$r.Content }
    } catch {
        $resp = $_.Exception.Response
        $status = 0
        $conteudo = ''
        if ($resp) {
            $status = [int]$resp.StatusCode
            $stream = $resp.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $conteudo = $reader.ReadToEnd()
            }
        }
        return [pscustomobject]@{ Status = $status; Body = $conteudo }
    }
}

function Verificar([bool]$Condicao, [string]$Mensagem) {
    if (-not $Condicao) { throw $Mensagem }
}

try {
    $login = Chamada 'POST' '/api/login' "{`"login`":`"admin`",`"senha`":`"admin123`",`"empresa_id`":1}" ''
    Verificar ($login.Status -eq 200) "login falhou: $($login.Status) $($login.Body)"
    $Token = (($login.Body | ConvertFrom-Json).token)
    Verificar (-not [string]::IsNullOrEmpty($Token)) 'login nao devolveu token'

    $body = @{
        nome = $Nome
        cpf_cnpj = $Cpf
        email = "crud$Stamp@exemplo.com"
        telefone = '11999990000'
        cidade = 'Sao Paulo'
        uf = 'SP'
    } | ConvertTo-Json -Compress

    $post = Chamada 'POST' '/api/clientes' $body $Token
    Verificar ($post.Status -eq 201) "POST falhou: $($post.Status) $($post.Body)"
    $json = $post.Body | ConvertFrom-Json
    $IdCriado = [int64]$json.id
    Verificar ($IdCriado -gt 0) "POST nao devolveu id: $($post.Body)"

    $get = Chamada 'GET' "/api/clientes/$IdCriado" '' $Token
    Verificar ($get.Status -eq 200) "GET falhou: $($get.Status) $($get.Body)"
    Verificar (((($get.Body | ConvertFrom-Json).nome) -eq $Nome)) 'GET devolveu nome diferente'

    $putBody = @{ nome = "$Nome EDITADO"; telefone = '11888880000' } | ConvertTo-Json -Compress
    $put = Chamada 'PUT' "/api/clientes/$IdCriado" $putBody $Token
    Verificar ($put.Status -eq 200) "PUT falhou: $($put.Status) $($put.Body)"

    $get2 = Chamada 'GET' "/api/clientes/$IdCriado" '' $Token
    Verificar ($get2.Status -eq 200) "GET apos PUT falhou: $($get2.Status)"
    $editado = $get2.Body | ConvertFrom-Json
    Verificar ($editado.nome -eq "$Nome EDITADO") 'PUT nao persistiu o nome'
    Verificar ($editado.telefone -eq '11888880000') "PUT nao persistiu o telefone: $($get2.Body)"

    $dup = Chamada 'POST' '/api/clientes' $body $Token
    Verificar ($dup.Status -eq 400) "CPF duplicado deveria dar 400, veio $($dup.Status)"

    Write-Host 'API-CRUD CONCLUIDO: POST devolveu id, GET/PUT OK, duplicata bloqueada.'
    exit 0
} catch {
    Write-Host "API-CRUD FALHOU: $($_.Exception.Message)"
    exit 1
} finally {
    if ($IdCriado -gt 0 -and $Token) {
        $null = Chamada 'DELETE' "/api/clientes/$IdCriado" '' $Token
    }
}
