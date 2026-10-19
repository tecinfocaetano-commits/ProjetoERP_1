# Lib compartilhada dos testes da FASE 5 (Produção)
. "$PSScriptRoot\erpui.ps1"
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

if (-not ('ERPCombo' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public class ERPCombo {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
  [DllImport("user32.dll", EntryPoint = "GetWindowLong")] private static extern int GetWindowLong32(IntPtr h, int i);
  // CB_SETCURSEL + CBN_SELCHANGE (WM_COMMAND) para o LCL atualizar ItemIndex e disparar OnChange
  public static bool SetSel(IntPtr combo, int idx) {
    SendMessage(combo, 0x014E, (IntPtr)idx, IntPtr.Zero);
    IntPtr parent = GetParent(combo);
    int id = GetWindowLong32(combo, -6);           // GWL_ID
    int wp = (1 << 16) | (id & 0xFFFF);            // MAKEWPARAM(id, CBN_SELCHANGE=1)
    return PostMessage(parent, 0x0111, (IntPtr)wp, combo);
  }
}
'@
}

$Global:EV = "C:\Users\Charles\Documents\ProjetoERP_1\Documentacao\evidencias"

# Traz a janela para frente de verdade (vence o foreground-lock: AttachThreadInput)
if (-not ('ERPF' -as [type])) {
  Add-Type @'
using System; using System.Runtime.InteropServices;
public class ERPF {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
}
'@
}
function Force-Foreground([IntPtr]$h) {
  $fg = [ERPF]::GetForegroundWindow()
  $tidFg = [ERPF]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
  $tidOurs = [ERPF]::GetCurrentThreadId()
  [ERPF]::AttachThreadInput($tidOurs, $tidFg, $true) | Out-Null
  try {
    [ERPF]::BringWindowToTop($h) | Out-Null
    [ERPF]::SetForegroundWindow($h) | Out-Null
  } finally {
    [ERPF]::AttachThreadInput($tidOurs, $tidFg, $false) | Out-Null
  }
  Start-Sleep -Milliseconds 300
}

function Start-ERPApp {
  Get-Process ERP2026 -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 1
  Start-Process "C:\Users\Charles\Documents\ProjetoERP_1\Desktop\bin\ERP2026.exe"
  Start-Sleep -Seconds 4
  $hLogin = Find-ERPWindow "Login"
  if ($hLogin -eq [IntPtr]::Zero) { throw "janela de login nao abriu" }
  $fc = Get-FormControls $hLogin
  $edits = @($fc.Edits | Sort-Object Y)
  [ERPUI]::SetText($edits[0].Hwnd, "admin") | Out-Null
  [ERPUI]::SetText($edits[1].Hwnd, "admin123") | Out-Null
  $btnEntrar = @($fc.Buttons | Sort-Object X) | Select-Object -First 1
  [ERPUI]::ClickHwnd($btnEntrar.Hwnd) | Out-Null
  Start-Sleep -Seconds 3
  $hMain = Find-ERPWindow "Sistema de Gest"
  if ($hMain -eq [IntPtr]::Zero) { throw "tela principal nao abriu apos login" }
  return $hMain
}

function Get-FormControls([IntPtr]$hForm) {
  $edits = @(); $btns = @(); $combos = @(); $all = @()
  foreach ($k in ([ERPUI]::Kids($hForm) -split "`r?`n")) {
    if ($k -match "^([0-9A-F]+) \| (\S+) \| '([^']*)' \| \((\d+),(\d+)\)-\((\d+),(\d+)\)") {
      $c = [pscustomobject]@{
        Hwnd = [IntPtr]([Convert]::ToInt64($Matches[1], 16)); Classe = $Matches[2]
        Text = $Matches[3]; X = [int]$Matches[4]; Y = [int]$Matches[5]
        X2 = [int]$Matches[6]; Y2 = [int]$Matches[7]
      }
      $all += $c
      switch -Regex ($c.Classe) {
        '^Edit$'   { $edits += $c }
        '^Button$' { $btns += $c }
        'ombo'     { $combos += $c }
      }
    }
  }
  return [pscustomobject]@{
    Edits = @($edits); Buttons = @($btns); Combos = @($combos); All = @($all)
  }
}

function Get-Button([IntPtr]$hForm, [string]$caption) {
  $fc = Get-FormControls $hForm
  $btns = @($fc.Buttons)
  $m = $btns | Where-Object { $_.Text -eq $caption } | Select-Object -First 1
  if (-not $m) { $m = $btns | Where-Object { $_.Text -replace '&','' -eq $caption } | Select-Object -First 1 }
  if (-not $m) { $m = $btns | Where-Object { $_.Text -like "*$caption*" } | Select-Object -First 1 }
  if (-not $m) { throw "botao '$caption' nao encontrado. Botões: " + (($btns | ForEach-Object { $_.Text }) -join ', ') }
  return $m
}

function Click-Button([IntPtr]$hForm, [string]$caption) {
  $b = Get-Button $hForm $caption
  [ERPUI]::ClickHwnd($b.Hwnd) | Out-Null
}

function Shot-Win([IntPtr]$hwnd, [string]$file) {
  $r = [ERPUI]::Rect($hwnd)
  $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  $g.Dispose(); $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  "evidencia: $file"
}

# espera um diálogo (#32770) e devolve hwnd; opcionalmente casa por texto dos botões
function Wait-ErpDialog([int]$timeoutSec = 8) {
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt $timeoutSec) {
    $d = Get-ERPDialogs | Select-Object -First 1
    if ($d) { return $d.Hwnd }
    Start-Sleep -Milliseconds 250
  }
  return [IntPtr]::Zero
}

function Close-DialogOk([IntPtr]$hDlg) {
  $btns = Get-DialogButtons $hDlg
  $ok = $btns | Where-Object { $_.Text -replace '&','' -match '^(OK|Sim|Yes|Continuar)' } | Select-Object -First 1
  if (-not $ok) { $ok = $btns | Select-Object -First 1 }
  [ERPUI]::ClickHwnd($ok.Hwnd) | Out-Null
  Start-Sleep -Milliseconds 600
}

function Close-DialogNo([IntPtr]$hDlg) {
  $btns = Get-DialogButtons $hDlg
  $no = $btns | Where-Object { ($_.Text -replace '&','') -match '^(N|Nao|Não|No|Cancel)' } | Select-Object -First 1
  if (-not $no) { throw "botao Nao/Cancelar nao encontrado" }
  [ERPUI]::ClickHwnd($no.Hwnd) | Out-Null
  Start-Sleep -Milliseconds 600
}

# texto do diálogo via UIA (funciona com TaskDialog do LCL e diálogos comuns)
function Get-DialogText([IntPtr]$hDlg) {
  Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
  try {
    $el = [System.Windows.Automation.AutomationElement]::FromHandle($hDlg)
    $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $out = ''
    $seen = @{}
    foreach ($e in $all) {
      $n = $e.Current.Name
      if ($n -and -not $seen[$n]) { $seen[$n] = $true; $out += $n + ' | ' }
    }
    return $out
  } catch {
    # fallback: texto Win32 dos filhos
    $out = ''
    foreach ($k in ([ERPUI]::Kids($hDlg) -split "`r?`n")) {
      if ($k -match "'([^']+)'") { if ($Matches[1]) { $out += $Matches[1] + ' | ' } }
    }
    return $out
  }
}

# ---- InputQuery (LCL): espera pelo título e preenche o edit ----
function Wait-InputQuery([string]$titlePart, [int]$timeoutSec = 8) {
  return (Wait-Window $titlePart $timeoutSec)
}
function Set-InputQuery([IntPtr]$hDlg, [string]$text) {
  $fc = Get-FormControls $hDlg
  $ed = @($fc.Edits) | Sort-Object Y | Select-Object -First 1
  if (-not $ed) { throw "edit do InputQuery nao encontrado" }
  [ERPUI]::SetText($ed.Hwnd, $text) | Out-Null
  Start-Sleep -Milliseconds 250
}
# botões do InputQuery do LCL chegam SEM texto: OK = esquerdo, Cancelar = direito
function Click-InputOk([IntPtr]$hDlg) {
  $fc = Get-FormControls $hDlg
  $btn = @($fc.Buttons | Sort-Object X) | Select-Object -First 1
  if (-not $btn) { throw "botoes do InputQuery nao encontrados" }
  [ERPUI]::ClickHwnd($btn.Hwnd) | Out-Null
  Start-Sleep -Milliseconds 500
}

# ---- grade (TStringGrid): localiza a janela interna (a menor janela
#      grande; o painel que a contém é maior e fica de fora) ----
function Get-GridWindow([IntPtr]$hForm) {
  $fc = Get-FormControls $hForm
  $ign = @('Edit', 'Button', 'Static', 'ComboBox', 'SysHeader32', 'ScrollBar', 'LCLComboBox')
  $g = @($fc.All | Where-Object {
      ($ign -notcontains $_.Classe) -and (($_.X2 - $_.X) -gt 300) -and (($_.Y2 - $_.Y) -gt 100)
    } | Sort-Object { ($_.X2 - $_.X) * ($_.Y2 - $_.Y) })
  if (-not $g -or $g.Count -eq 0) {
    throw "grid nao encontrado. Classes: " + (($fc.All | ForEach-Object { $_.Classe + '(' + ($_.X2 - $_.X) + 'x' + ($_.Y2 - $_.Y) + ')' }) -join ', ')
  }
  return $g[0]
}

# Edita uma celula POSTANDO mensagens ao hwnd da grade (imune a janela por cima,
# nao depende de foco/foreground). cx/cy = coordenadas CLIENTES do centro da celula.
function Set-GridCellEdit([IntPtr]$hGrid, [int]$cx, [int]$cy, [int]$expX1, [int]$expX2, [string]$value) {
  function Get-VisibleEdit {
    $fc0 = Get-FormControls $hGrid
    return @($fc0.Edits | Where-Object { [ERPF]::IsWindowVisible($_.Hwnd) }) | Select-Object -First 1
  }
  $lp = [IntPtr](($cy -shl 16) -bor ($cx -band 0xFFFF))
  [ERPUI]::PostMessage($hGrid, 0x0201, [IntPtr]1, $lp) | Out-Null  # WM_LBUTTONDOWN
  [ERPUI]::PostMessage($hGrid, 0x0202, [IntPtr]0, $lp) | Out-Null  # WM_LBUTTONUP
  Start-Sleep -Milliseconds 400
  [ERPUI]::PostMessage($hGrid, 0x0102, [IntPtr]0x30, [IntPtr]0x000B0001) | Out-Null  # WM_CHAR '0'
  Start-Sleep -Milliseconds 600
  $ed = Get-VisibleEdit
  if (-not $ed) { throw "editor da celula nao abriu (msgs postadas)" }
  if (($ed.X -lt $expX1) -or ($ed.X -gt $expX2)) {
    throw "editor abriu na coluna errada: x=$($ed.X) esperado [$expX1..$expX2]"
  }
  [ERPUI]::SetText($ed.Hwnd, $value) | Out-Null
  Start-Sleep -Milliseconds 250
  $txt = [ERPUI]::GetText($ed.Hwnd)
  if ($txt -ne $value) { throw "SetText nao pegou: texto do editor='$txt'" }
  # commit do editor: WM_CHAR #13 (LCL: EditorKeyPress ^M -> ResetEditor -> EditorGetValue)
  [ERPUI]::PostMessage($ed.Hwnd, 0x0102, [IntPtr]13, [IntPtr]0x00010001) | Out-Null
  Start-Sleep -Milliseconds 500
  if (Get-VisibleEdit) {
    # fallback: Enter real (exige janela em primeiro plano)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Milliseconds 600
    if (Get-VisibleEdit) { throw "edicao da celula nao confirmou (WM_CHAR #13 nem Enter)" }
  }
}
