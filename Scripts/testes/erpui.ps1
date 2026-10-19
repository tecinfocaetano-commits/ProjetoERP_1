# Helper de automação de UI do ERP2026 (LCL/Win32) - testes FASE 3
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class ERPUI {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, StringBuilder s);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetMenuItemInfo(IntPtr m, uint pos, bool byPos, ref MENUITEMINFO info);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)]
  public struct MENUITEMINFO {
    public uint cbSize; public uint fMask; public uint fType; public uint fState; public uint wID;
    public IntPtr hSubMenu; public IntPtr hbmpChecked; public IntPtr hbmpItem; public IntPtr dwItemData;
    public IntPtr dwTypeData; public uint cch;
  }
  public delegate bool EnumProc(IntPtr h, IntPtr l);

  public static IntPtr FindWin(uint pid, string part) {
    IntPtr f = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var t = new StringBuilder(256); GetWindowText(h, t, 256);
        if (t.ToString().IndexOf(part, StringComparison.OrdinalIgnoreCase) >= 0) { f = h; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return f;
  }
  public static string WinTitle(IntPtr h) { var t = new StringBuilder(256); GetWindowText(h, t, 256); return t.ToString(); }
  public static string WinClass(IntPtr h) { var c = new StringBuilder(128); GetClassName(h, c, 128); return c.ToString(); }
  public static RECT Rect(IntPtr h) { RECT r; GetWindowRect(h, out r); return r; }
  public static RECT Client(IntPtr h) { RECT r; GetClientRect(h, out r); return r; }
  public static string Kids(IntPtr p) {
    var sb = new StringBuilder();
    EnumChildWindows(p, delegate(IntPtr h, IntPtr l) {
      var t = new StringBuilder(256); GetWindowText(h, t, 256);
      var c = new StringBuilder(128); GetClassName(h, c, 128);
      RECT r; GetWindowRect(h, out r);
      sb.AppendLine(h.ToInt64().ToString("X") + " | " + c + " | '" + t + "' | (" + r.Left + "," + r.Top + ")-(" + r.Right + "," + r.Bottom + ")");
      return true;
    }, IntPtr.Zero);
    return sb.ToString();
  }
  public static void ClickHwnd(IntPtr h) { PostMessage(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); } // BM_CLICK async (evita deadlock com diálogos modais)
  public static void SetText(IntPtr h, string t) { SendMessage(h, 0x000C, IntPtr.Zero, new StringBuilder(t)); }
  public static string GetText(IntPtr h) { var sb = new StringBuilder(256); SendMessage(h, 0x000D, (IntPtr)sb.Capacity, sb); return sb.ToString(); }
  public static void ClickXY(int x, int y) {
    SetForegroundWindow(GetAncestor0());
    SetCursorPos(x, y);
    mouse_event(0x0002, 0, 0, 0, IntPtr.Zero); // LEFTDOWN
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero); // LEFTUP
  }
  static IntPtr _fg;
  public static void RememberFg(IntPtr h) { _fg = h; }
  static IntPtr GetAncestor0() { return _fg; }
}
'@

function Get-ERPProcess { Get-Process ERP2026 -ErrorAction SilentlyContinue | Select-Object -First 1 }
function Find-ERPWindow([string]$part) {
  $pidERP = (Get-ERPProcess).Id
  [ERPUI]::FindWin([uint32]$pidERP, $part)
}
function Shot-Window([IntPtr]$hwnd, [string]$file) {
  Add-Type -AssemblyName System.Drawing, System.Windows.Forms
  if (-not ('PWShot' -as [type])) {
    Add-Type @'
using System; using System.Runtime.InteropServices;
public class PWShot {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
  }
  [PWShot]::SetForegroundWindow($hwnd) | Out-Null
  Start-Sleep -Milliseconds 200
  $r = [ERPUI]::Rect($hwnd)
  $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
  if ($w -le 0 -or $h -le 0) { throw "janela inválida" }
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $g.GetHdc()
  $ok = [PWShot]::PrintWindow($hwnd, $hdc, 2)   # PW_RENDERFULLCONTENT
  $g.ReleaseHdc($hdc)
  $g.Dispose()
  if (-not $ok) { $bmp.Dispose(); throw "PrintWindow falhou" }
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  "salvo: $file ($w x $h)"
}
function Wait-Window([string]$part, [int]$timeoutSec = 10) {
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt $timeoutSec) {
    $h = Find-ERPWindow $part
    if ($h -ne [IntPtr]::Zero) { return $h }
    Start-Sleep -Milliseconds 300
  }
  return [IntPtr]::Zero
}
function Get-DialogButtons([IntPtr]$hDlg) {
  $kids = [ERPUI]::Kids($hDlg) -split "`r?`n" | Where-Object { $_ -match '\| Button \|' }
  $list = @()
  foreach ($k in $kids) {
    if ($k -match '^([0-9A-F]+) \| Button \| ''(.*)'' \| \((\d+),(\d+)\)-') {
      $list += [pscustomobject]@{ Hwnd = [IntPtr]([Convert]::ToInt64($Matches[1],16)); Text = $Matches[2]; X = [int]$Matches[3]; Y = [int]$Matches[4] }
    }
  }
  $list | Sort-Object X
}
function Click-DialogYesOk([IntPtr]$hDlg) {
  # Yes/Sim/OK/Confirmar: primeiro botão da esquerda (padrão do LCL)
  $btns = Get-DialogButtons $hDlg
  if ($btns.Count -eq 0) { throw "sem botões no diálogo" }
  $alvo = $btns | Where-Object { $_.Text -match '^(Yes|Sim|OK|Confirmar|Continuar)' } | Select-Object -First 1
  if (-not $alvo) { $alvo = $btns[0] }
  "clicando botão: '" + $alvo.Text + "' hwnd=" + $alvo.Hwnd
  [ERPUI]::ClickHwnd($alvo.Hwnd)
}
function Get-ERPDialogs {
  $pidERP = (Get-ERPProcess).Id
  if (-not ('ERPDlg' -as [type])) {
  Add-Type @'
using System; using System.Runtime.InteropServices; using System.Text;
public class ERPDlg {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public static string List(uint pid) {
    var sb = new StringBuilder();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var c = new StringBuilder(128); GetClassName(h, c, 128);
        if (c.ToString() == "#32770") {
          var t = new StringBuilder(256); GetWindowText(h, t, 256);
          RECT r; GetWindowRect(h, out r);
          sb.AppendLine(h.ToInt64().ToString("X") + " | '" + t + "' | (" + r.Left + "," + r.Top + ")-(" + r.Right + "," + r.Bottom + ")");
        }
      }
      return true;
    }, IntPtr.Zero);
    return sb.ToString();
  }
}
'@
  }
  $out = [ERPDlg]::List([uint32]$pidERP) -split "`r?`n" | Where-Object { $_ }
  $res = @()
  foreach ($l in $out) {
    if ($l -match '^([0-9A-F]+) \| ''(.*)'' \|') {
      $res += [pscustomobject]@{ Hwnd = [IntPtr]([Convert]::ToInt64($Matches[1],16)); Title = $Matches[2] }
    }
  }
  $res
}
function Wait-Dialog([string]$notHwndPattern = '', [int]$timeoutSec = 8) {
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt $timeoutSec) {
    $d = Get-ERPDialogs | Where-Object { $_.Hwnd.ToString("X") -notmatch $notHwndPattern } | Select-Object -First 1
    if ($d) { return $d.Hwnd }
    Start-Sleep -Milliseconds 300
  }
  return [IntPtr]::Zero
}
function Get-ButtonAt([IntPtr]$hForm, [int]$cx, [int]$cy, [int]$tol = 8) {
  # botão (classe Button) cujo centro está perto de (cx,cy) em coords de tela
  $kids = [ERPUI]::Kids($hForm) -split "`r?`n" | Where-Object { $_ -match '\| Button \|' }
  foreach ($k in $kids) {
    if ($k -match '^([0-9A-F]+) \| Button \| ''(.*)'' \| \((\d+),(\d+)\)-\((\d+),(\d+)\)') {
      $x1=[int]$Matches[3]; $y1=[int]$Matches[4]; $x2=[int]$Matches[5]; $y2=[int]$Matches[6]
      $mx=($x1+$x2)/2; $my=($y1+$y2)/2
      if ([Math]::Abs($mx-$cx) -le $tol -and [Math]::Abs($my-$cy) -le $tol) {
        return [pscustomobject]@{ Hwnd=[IntPtr]([Convert]::ToInt64($Matches[1],16)); Text=$Matches[2] }
      }
    }
  }
  return $null
}
function Wait-NoWindow([string]$part, [int]$timeoutSec = 10) {
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt $timeoutSec) {
    $h = Find-ERPWindow $part
    if ($h -eq [IntPtr]::Zero) { return $true }
    Start-Sleep -Milliseconds 300
  }
  return $false
}
