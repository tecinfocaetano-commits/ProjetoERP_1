# ============================================================
# ERP 2026 - Teste do pool de conexoes da API
# Sobe a API com ERP_API_POOL pequeno (3) e dispara requisicoes
# concorrentes (40 com 20 simultaneas) numa rota protegida.
# Esperado: todas respondem 200 - o pool atende cada thread com a
# sua propria conexao, esperando vaga quando necessario, e NUNCA
# compartilha conexao entre threads.
# ============================================================
$ErrorActionPreference = 'Stop'
$raiz = 'C:\Users\Charles\Documents\ProjetoERP_1'
$api  = Join-Path $raiz 'API\bin\ERP2026API.exe'
$log  = Join-Path $env:TEMP 'erp_api_pool.out.log'
$errf = Join-Path $env:TEMP 'erp_api_pool.err.log'
$url  = 'http://localhost:9000'

# pool pequeno de proposito: 3 conexoes para 20 requisicoes simultaneas
$env:ERP_API_POOL = '3'

$proc = Start-Process -FilePath $api -RedirectStandardOutput $log `
  -RedirectStandardError $errf -PassThru -WindowStyle Hidden

$corpo = '{"login":"admin","senha":"admin123"}'
$subiu = $false
for ($i = 0; $i -lt 60; $i++) {
  Start-Sleep -Milliseconds 500
  try {
    Invoke-RestMethod -Uri ($url + '/api/login') -Method Post -Body $corpo `
      -ContentType 'application/json' -TimeoutSec 5 | Out-Null
    $subiu = $true
    break
  } catch { }
}
if (-not $subiu) {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  throw ('API nao subiu. stdout=' + $log + ' stderr=' + $errf)
}
Write-Host 'OK [api no ar na porta 9000]'

# mostra como o pool se inicializou
Get-Content $log | ForEach-Object { Write-Host ('   | ' + $_) }

$login = Invoke-RestMethod -Uri ($url + '/api/login') -Method Post -Body $corpo `
  -ContentType 'application/json'
$token = $login.token
if (-not $token) {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  throw 'token nao veio no login'
}
Write-Host ('OK [login] token=' + $token.Substring(0, [Math]::Min(24, $token.Length)) + '...')

Add-Type -TypeDefinition @'
using System;
using System.Net;
using System.Threading.Tasks;

public static class CargaApi {
  public static string Rodar(string url, string token, int total, int simultaneas,
    bool manterViva) {
    ServicePointManager.DefaultConnectionLimit = 128;
    ServicePointManager.Expect100Continue = false;
    int ok = 0, naoAutorizado = 0, outro = 0, excecoes = 0;
    object l = new object();
    Parallel.For(0, total,
      new ParallelOptions { MaxDegreeOfParallelism = simultaneas }, i => {
        int codigo = 0;
        try {
          HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
          req.Method = "GET";
          req.Headers.Add("Authorization", "Bearer " + token);
          req.Timeout = 90000;
          // manterViva=false => TCP nova por requisicao: o servidor cria uma
          // thread nova por request, o que obriga o pool a reciclar as vagas
          // das threads que morrem
          req.KeepAlive = manterViva;
          using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse()) {
            codigo = (int)resp.StatusCode;
            using (System.IO.Stream s = resp.GetResponseStream()) {
              byte[] b = new byte[4096];
              while (s.Read(b, 0, b.Length) > 0) { }
            }
          }
        } catch (WebException we) {
          HttpWebResponse r = we.Response as HttpWebResponse;
          if (r != null) { codigo = (int)r.StatusCode; }
          else { System.Threading.Interlocked.Increment(ref excecoes); }
        } catch (Exception) {
          System.Threading.Interlocked.Increment(ref excecoes);
        }
        lock (l) {
          if (codigo == 200) { ok++; }
          else if (codigo == 401) { naoAutorizado++; }
          else { outro++; }
        }
      });
    return "200=" + ok + " 401=" + naoAutorizado + " outros=" + outro
      + " excecoes=" + excecoes;
  }
}
'@

$res = [CargaApi]::Rodar($url + '/api/clientes', $token, 40, 20, $true)
Write-Host ('OK [carga 1: keep-alive, 40 req / 20 simultaneas] ' + $res)

if ($res -notlike '200=40*') {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  throw ('carga 1 falhou: ' + $res)
}

# fase 2: uma TCP nova por requisicao -> no servidor cada request roda numa
# thread nova. Com apenas 3 conexoes no pool, as 40 requisicoes so passam se
# o pool reciclar as vagas das threads que morrem (LiberarThreadsMortas).
$res2 = [CargaApi]::Rodar($url + '/api/clientes', $token, 40, 20, $false)
Write-Host ('OK [carga 2: TCP nova por req = thread nova, 40 req / 20 simultaneas] ' + $res2)

if ($res2 -notlike '200=40*') {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  throw ('carga 2 falhou: ' + $res2)
}

# sem token tambem continua negando (o pool nao quebra a seguranca)
$semToken = 0
try {
  Invoke-RestMethod -Uri ($url + '/api/clientes') -TimeoutSec 10 | Out-Null
  $semToken = 1
} catch {
  $semToken = 0
}
if ($semToken -eq 1) {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  throw 'rota protegida respondeu sem token'
}
Write-Host 'OK [sem token segue negando: 401]'

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Write-Host 'OK [api encerrada]'
Write-Host 'POOL-TEST CONCLUIDO'
