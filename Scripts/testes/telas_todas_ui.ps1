# ============================================================
# ERP 2026 - Smoke de UI em TODAS as telas do desktop
#
# Abre o app (login admin/admin123), percorre TODO item do menu
# principal (lendo o menu Win32, sem IDs fixos), aciona o item por
# WM_COMMAND, confere que a tela abriu com controles, tira
# evidencia e fecha. Dialogos de aviso (#32770) sao lidos e
# fechados; a tela por tras continua sendo validada.
#
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_todas_ui.ps1
# Esperado: TELAS-DESKTOP-UI CONCLUIDO (0 falhas)
# Relatorio: Documentacao\TESTE_TELAS_DESKTOP.md
# Evidencias: Documentacao\evidencias\telas_<id>_<slug>.png (ignoradas pelo git)
# ============================================================
param(
  [int]$TimeoutAbrirSeg = 15,
  [string]$ApenasId = '',
  [switch]$SemEvidencia
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\fase5lib.ps1"

$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$doc  = Join-Path $raiz 'Documentacao'
$ev   = Join-Path $doc 'evidencias'
if (-not (Test-Path $ev)) { New-Item -ItemType Directory -Path $ev | Out-Null }

if (-not ('ERPTELAS' -as [type])) {
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class ERPTELAS {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr h, int nPos);
  [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetMenuItemID(IntPtr h, int nPos);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetMenuString(IntPtr h, uint uItem, StringBuilder s, int n, uint f);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);

  public static string List(uint pid) {
    var sb = new StringBuilder();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var t = new StringBuilder(512); GetWindowText(h, t, 512);
        var c = new StringBuilder(128); GetClassName(h, c, 128);
        RECT r; GetWindowRect(h, out r);
        sb.AppendLine(h.ToInt64().ToString("X") + "\t" + c + "\t" + t + "\t" +
                      r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
      }
      return true;
    }, IntPtr.Zero);
    return sb.ToString();
  }
}
'@
}

function Get-TopWindows {
  $p = Get-Process ERP2026 -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $p) { return @() }
  $out = @()
  foreach ($l in ([ERPTELAS]::List([uint32]$p.Id) -split "`r?`n")) {
    if (-not $l) { continue }
    $f = $l -split "`t"
    if ($f.Count -lt 4) { continue }
    $out += [pscustomobject]@{
      Hwnd = [IntPtr]([Convert]::ToInt64($f[0], 16)); Classe = $f[1]
      Titulo = $f[2]; Rect = $f[3]
    }
  }
  return $out
}

function Fold([string]$s) {
  if (-not $s) { return '' }
  $n = $s.Replace('&', '').Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($ch in $n.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne
        [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($ch) }
  }
  return ($sb.ToString().Normalize([Text.NormalizationForm]::FormC)).ToLowerInvariant().Trim()
}

function Get-MenuItens([IntPtr]$hMain) {
  $rows = New-Object System.Collections.ArrayList
  function Walk([IntPtr]$h, [string]$path) {
    $n = [ERPTELAS]::GetMenuItemCount($h)
    for ($i = 0; $i -lt $n; $i++) {
      $sb = New-Object Text.StringBuilder 256
      [void][ERPTELAS]::GetMenuString($h, [uint32]$i, $sb, 256, 0x400)
      $txt = $sb.ToString()
      $sub = [ERPTELAS]::GetSubMenu($h, $i)
      if ($sub -ne [IntPtr]::Zero) { Walk $sub ($path + ' > ' + $txt.Replace('&','')) }
      else {
        $id = [ERPTELAS]::GetMenuItemID($h, $i)
        [void]$rows.Add([pscustomobject]@{
          Id = $id; Texto = $txt.Replace('&','')
          Caminho = (($path + ' > ' + $txt.Replace('&','')).Trim(' ','>'))
        })
      }
    }
  }
  Walk ([ERPTELAS]::GetMenu($hMain)) ''
  return @($rows)
}

# WM_CLOSE + espera a janela sumir; devolve $true se fechou
function Fecha-Janela([IntPtr]$h, [int]$timeoutMs = 6000) {
  [ERPTELAS]::PostMessage($h, 0x0010, [IntPtr]0, [IntPtr]0) | Out-Null
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalMilliseconds -lt $timeoutMs) {
    $still = @(Get-TopWindows | Where-Object { $_.Hwnd -eq $h })
    if ($still.Count -eq 0) { return $true }
    Start-Sleep -Milliseconds 200
  }
  return $false
}

# fecha dialogos pendentes do processo (ex.: "Deseja salvar?") pela opcao
# que NAO salva e NAO confirma exclusao
function Fecha-DialogosPendentes {
  for ($i = 0; $i -lt 3; $i++) {
    $dlg = @(Get-TopWindows | Where-Object { $_.Classe -eq '#32770' } | Select-Object -First 1)
    if ($dlg.Count -eq 0) { return }
    $btns = Get-DialogButtons $dlg[0].Hwnd
    $alvo = $btns | Where-Object { ($_.Text -replace '&','') -match '^(Nao|No|Cancelar|Cancel|Fechar|Close)' } |
            Select-Object -First 1
    if (-not $alvo) { $alvo = $btns | Select-Object -First 1 }
    if (-not $alvo) { [void](Fecha-Janela $dlg[0].Hwnd 1000); continue }
    [ERPUI]::ClickHwnd($alvo.Hwnd) | Out-Null
    Start-Sleep -Milliseconds 600
  }
}

function Slug([string]$s) {
  $f = Fold $s
  $f = $f -replace '[^a-z0-9]+', '_'
  return $f.Trim('_')
}

# ---------------- execucao ----------------
$hMain = Start-ERPApp
"OK [app logado]"
$itens = @(Get-MenuItens $hMain | Where-Object {
  $_.Id -gt 0 -and $_.Texto -ne '-' -and $_.Texto -notmatch '^Sair$'
})
if (-not [string]::IsNullOrWhiteSpace($ApenasId)) {
  $idsFiltro = @($ApenasId -split ',' | ForEach-Object { [int]$_.Trim() })
  $itens = @($itens | Where-Object { $idsFiltro -contains $_.Id })
}
"OK [menu lido: $($itens.Count) telas]"

$resultados = New-Object System.Collections.ArrayList
$i = 0
foreach ($it in $itens) {
  $i++
  $antes = @(Get-TopWindows | Where-Object { $_.Hwnd -ne $hMain })
  $idsAntes = @($antes | ForEach-Object { $_.Hwnd.ToString('X') })

  "`n[$i/$($itens.Count)] $($it.Caminho)  (id $($it.Id))"
  [ERPTELAS]::PostMessage($hMain, 0x0111, [IntPtr]$it.Id, [IntPtr]0) | Out-Null

  $t0 = Get-Date
  $janela = $null
  $avisos = New-Object System.Collections.ArrayList
  while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutAbrirSeg) {
    $tops = @(Get-TopWindows | Where-Object { $_.Hwnd -ne $hMain })
    $novas = @($tops | Where-Object { $idsAntes -notcontains $_.Hwnd.ToString('X') })
    $dlg = @($novas | Where-Object { $_.Classe -eq '#32770' } | Select-Object -First 1)
    if ($dlg.Count -gt 0) {
      $txtDlg = Get-DialogText $dlg[0].Hwnd
      "   aviso: $txtDlg"
      [void]$avisos.Add($txtDlg)
      [void](Fecha-Janela $dlg[0].Hwnd 2000)
      $idsAntes += $dlg[0].Hwnd.ToString('X')
      Start-Sleep -Milliseconds 300
      continue
    }
    $jan = @($novas | Where-Object { $_.Classe -ne '#32770' -and $_.Titulo } | Select-Object -First 1)
    if ($jan.Count -gt 0) { $janela = $jan[0]; break }
    Start-Sleep -Milliseconds 250
  }

  if (-not $janela) {
    $obs = if ($avisos.Count -gt 0) { ($avisos -join ' / ') } else { 'sem janela' }
    [void]$resultados.Add([pscustomobject]@{
      Caminho = $it.Caminho; Id = $it.Id; Janela = '(nao abriu)'; Classe = '-'
      Controles = 0; Status = 'FALHA'; Obs = $obs; Evidencia = '-'
    })
    "   FALHA: tela nao abriu ($obs)"
    Fecha-DialogosPendentes
    continue
  }

  Start-Sleep -Milliseconds 700
  $fc = Get-FormControls $janela.Hwnd
  $qtd = @($fc.All).Count
  $titulo = $janela.Titulo

  $arquivo = '-'
  if (-not $SemEvidencia) {
    $nome = ('telas_{0:D2}_{1}.png' -f $it.Id, (Slug $titulo))
    $arquivo = Join-Path $ev $nome
    try { Force-Foreground $janela.Hwnd; Shot-Win $janela.Hwnd $arquivo }
    catch {
      try { Shot-Win $janela.Hwnd $arquivo } catch { $arquivo = '-' }
    }
  }

  $status = 'OK'; $obs = ''
  if ($qtd -lt 1) { $status = 'AVISO'; $obs = 'janela sem controles visiveis' }
  if ($avisos.Count -gt 0) { $obs = (($obs + ' aviso: ' + ($avisos -join ' / ')).Trim()) }
  $erroAviso = @($avisos | Where-Object {
    $_ -match 'Access violation|SQL error|Dynamic SQL|Token unknown|invalid integer|Exception'
  })
  if ($erroAviso.Count -gt 0) {
    $status = 'FALHA'
    if (-not $obs) { $obs = 'erro ao abrir' }
  }

  "   janela: '$titulo' ($($janela.Classe)) controles=$qtd -> $status"
  [void]$resultados.Add([pscustomobject]@{
    Caminho = $it.Caminho; Id = $it.Id; Janela = $titulo; Classe = $janela.Classe
    Controles = $qtd; Status = $status; Obs = $obs
    Evidencia = $(if ($arquivo -eq '-') { '-' } else { 'evidencias/' + (Split-Path $arquivo -Leaf) })
  })

  $fechou = Fecha-Janela $janela.Hwnd 6000
  if (-not $fechou) {
    "   AVISO: janela nao fechou com WM_CLOSE"
    $resultados[$resultados.Count - 1].Obs = (($resultados[$resultados.Count - 1].Obs + ' / nao fechou').Trim())
  }
  Fecha-DialogosPendentes
}

# fecha o app
Fecha-DialogosPendentes
[void](Fecha-Janela $hMain 3000)
$pLeft = Get-Process ERP2026 -ErrorAction SilentlyContinue
if ($pLeft) { $pLeft | Stop-Process -Force -ErrorAction SilentlyContinue }

# ---------------- relatorio ----------------
$ok = @($resultados | Where-Object { $_.Status -eq 'OK' }).Count
$aviso = @($resultados | Where-Object { $_.Status -eq 'AVISO' }).Count
$falha = @($resultados | Where-Object { $_.Status -eq 'FALHA' }).Count
$head = (& git -C $raiz rev-parse --short HEAD 2>$null)
$quando = Get-Date -Format 'dd/MM/yyyy HH:mm'

$md = @()
$md += '# Teste de UI em todas as telas do desktop'
$md += ''
$md += ('Gerado por `Scripts\testes\telas_todas_ui.ps1` em ' + $quando + ' (HEAD `' + $head + '`).')
$md += ''
$md += ('**Resultado: ' + $ok + ' OK, ' + $aviso + ' aviso(s), ' + $falha + ' falha(s)** - ' + $resultados.Count + ' telas do menu.')
$md += ''
$md += 'Criterio: o item de menu foi acionado por `WM_COMMAND`; a tela precisa abrir uma'
$md += 'janela visivel com pelo menos um controle. Avisos de negocio (ex.: caixa fechado)'
$md += 'sao lidos e fechados, e a tela por tras continua sendo validada.'
$md += ''
$md += '| # | ID | Tela (menu) | Janela | Controles | Status | Evidencia |'
$md += '|---:|---:|---|---|---:|---|---|'
$n = 0
foreach ($r in $resultados) {
  $n++
  $linha = '| ' + $n + ' | ' + $r.Id + ' | ' + $r.Caminho + ' | ' + ($r.Janela -replace '\|','/') +
           ' | ' + $r.Controles + ' | **' + $r.Status + '**'
  if ($r.Obs) { $linha += ' - ' + ($r.Obs -replace '\|','/') }
  $linha += ' | ' + $r.Evidencia + ' |'
  $md += $linha
}
$md += ''
$md += 'Telas fora do menu cobertas em outros testes: **Login** (fluxo do `Start-ERPApp`),'
$md += 'dialogos `uFrmCoresProduto` e `uFrmGradeQuantidades` (abertos por botao nas telas'
$md += 'de Produto Producao e Grades) e `uFrmCadastroBase` (classe base, nao instanciavel).'
$md | Out-File -FilePath (Join-Path $doc 'TESTE_TELAS_DESKTOP.md') -Encoding utf8

"`n========================================"
"Telas: $($resultados.Count) | OK: $ok | Aviso: $aviso | Falha: $falha"
"Relatorio: Documentacao\TESTE_TELAS_DESKTOP.md"
"========================================"
if ($falha -gt 0) {
  $resultados | Where-Object { $_.Status -eq 'FALHA' } | ForEach-Object { "FALHA: $($_.Caminho)" }
  exit 1
}
'TELAS-DESKTOP-UI CONCLUIDO'
