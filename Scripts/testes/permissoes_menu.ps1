# ============================================================
# ERP 2026 - Teste das permissoes no menu (T1)
#
# Cria um grupo/usuario de teste com permissao de VISUALIZAR em
# apenas uma tela, entra no ERP com esse usuario e confere que:
#   - no menu, so os itens com permissao ficam habilitados;
#   - um item bloqueado nao abre a tela e mostra o aviso;
#   - uma tela liberada abre normalmente.
# Depois remove o grupo, o usuario e a permissao do banco.
#
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\permissoes_menu.ps1
# Esperado: PERMISSOES-MENU CONCLUIDO (0 falhas)
# ============================================================
param(
  [int]$TimeoutAbrirSeg = 10
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\fase5lib.ps1"

$raiz   = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$exe    = Join-Path $raiz 'Desktop\bin\ERP2026.exe'
$isql   = 'C:\Program Files\Firebird\Firebird_5_0\isql.exe'
$banco  = Join-Path $raiz 'Banco\dados.fdb'
$grupo  = 'TESTE_PERM_MENU'
$usuario= 'perm_menu'
$senha  = 'admin123'

$falhas = 0
function Falha([string]$msg) {
  $script:falhas++
  Write-Host "   FALHA: $msg"
}
function Ok([string]$msg) { Write-Host "   OK: $msg" }

if (-not (Test-Path $exe)) { throw "Desktop\bin\ERP2026.exe nao existe (rode build_desktop.bat)" }
if (-not (Test-Path $isql)) { throw "isql nao encontrado em $isql" }

# ---------------- prepara o grupo/usuario de teste ----------------
$sqlPre = @"
SET ECHO OFF;
DELETE FROM PERMISSAO WHERE GRUPO_ID IN (SELECT ID FROM GRUPO WHERE NOME = '$grupo');
DELETE FROM USUARIO WHERE LOGIN = '$usuario';
DELETE FROM GRUPO WHERE NOME = '$grupo';
COMMIT;
INSERT INTO GRUPO (NOME, DESCRICAO, ATIVO) VALUES ('$grupo', 'grupo do teste de permissoes', 'A');
COMMIT;
INSERT INTO PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_VISUALIZAR, PODE_INSERIR, PODE_EDITAR, PODE_EXCLUIR, PODE_IMPRIMIR)
  SELECT g.ID, 'CADASTROS', 'PESSOAS', 'S', 'S', 'N', 'N', 'N' FROM GRUPO g WHERE g.NOME = '$grupo';
COMMIT;
INSERT INTO USUARIO (EMPRESA_ID, GRUPO_ID, NOME, LOGIN, SENHA, ADMINISTRADOR, ATIVO)
  SELECT 1, g.ID, 'Usuario Permissoes', '$usuario',
    '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'N', 'A'
  FROM GRUPO g WHERE g.NOME = '$grupo';
COMMIT;
"@
$sqlPre | & $isql -q -u SYSDBA -p masterkey $banco | Out-Null

function Remove-Usuario {
  $sqlDel = @"
SET ECHO OFF;
DELETE FROM PERMISSAO WHERE GRUPO_ID IN (SELECT ID FROM GRUPO WHERE NOME = '$grupo');
DELETE FROM USUARIO WHERE LOGIN = '$usuario';
DELETE FROM GRUPO WHERE NOME = '$grupo';
COMMIT;
"@
  $sqlDel | & $isql -q -u SYSDBA -p masterkey $banco | Out-Null
}

# ---------------- helpers de UI ----------------
if (-not ('ERPMENU' -as [type])) {
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class ERPMENU {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr h, int nPos);
  [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr h, int nPos);
  [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr h, uint uId, uint uFlags);
  [StructLayout(LayoutKind.Sequential)]
  public struct MENUITEMINFO {
    public int cbSize; public int fMask; public int fType; public int fState;
    public int wID; public IntPtr hSubMenu; public IntPtr hbmpChecked;
    public IntPtr hbmpUnchecked; public IntPtr dwItemData; public IntPtr dwTypeData;
    public int cch; public IntPtr hbmpItem;
  }
  [DllImport("user32.dll")]
  public static extern bool GetMenuItemInfo(IntPtr hMenu, uint uItem, bool fByPosition, ref MENUITEMINFO lpmii);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetMenuString(IntPtr h, uint uItem, StringBuilder s, int n, uint f);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public static string List(uint pid) {
    var sb = new StringBuilder();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var t = new StringBuilder(512); GetWindowText(h, t, 512);
        var c = new StringBuilder(128); GetClassName(h, c, 128);
        sb.AppendLine(h.ToInt64().ToString("X") + "\t" + c + "\t" + t);
      }
      return true;
    }, IntPtr.Zero);
    return sb.ToString();
  }
}
'@
}

function Get-Windows {
  $p = Get-Process ERP2026 -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $p) { return @() }
  $out = @()
  foreach ($l in ([ERPMENU]::List([uint32]$p.Id) -split "`r?`n")) {
    if (-not $l) { continue }
    $f = $l -split "`t"
    if ($f.Count -lt 3) { continue }
    $out += [pscustomobject]@{
      Hwnd = [IntPtr]([Convert]::ToInt64($f[0], 16)); Classe = $f[1]; Titulo = $f[2]
    }
  }
  return $out
}

function Get-MenuItens([IntPtr]$hMain) {
  $rows = New-Object System.Collections.ArrayList
  function Walk([IntPtr]$h, [string]$path) {
    $n = [ERPMENU]::GetMenuItemCount($h)
    for ($i = 0; $i -lt $n; $i++) {
      $sb = New-Object Text.StringBuilder 256
      [void][ERPMENU]::GetMenuString($h, [uint32]$i, $sb, 256, 0x400)
      $txt = $sb.ToString()
      $sub = [ERPMENU]::GetSubMenu($h, $i)
      if ($sub -ne [IntPtr]::Zero) { Walk $sub ($path + ' > ' + $txt.Replace('&','')) }
      else {
        $id = [ERPMENU]::GetMenuItemID($h, $i)
        $mii = New-Object ERPMENU+MENUITEMINFO
        $mii.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type]'ERPMENU+MENUITEMINFO')
        $mii.fMask = 0x1   # MIIM_STATE
        $estado = 0
        # GetMenuItemInfo usa sempre a POSICAO do item (fByPosition = true)
        if ([ERPMENU]::GetMenuItemInfo($h, [uint32]$i, $true, [ref]$mii)) {
          $estado = $mii.fState
        }
        [void]$rows.Add([pscustomobject]@{
          Id = $id; Texto = $txt.Replace('&','')
          Caminho = (($path + ' > ' + $txt.Replace('&','')).Trim(' ','>'))
          # MFS_DISABLED = 3 (MF_GRAYED | MF_DISABLED); MFS_ENABLED = 0
          Habilitado = (($estado -band 3) -eq 0)
        })
      }
    }
  }
  Walk ([ERPMENU]::GetMenu($hMain)) ''
  return @($rows)
}

# ---------------- execucao ----------------
try {
  Get-Process ERP2026 -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 1
  Start-Process $exe
  Start-Sleep -Seconds 4

  $hLogin = @((Get-Windows) | Where-Object { $_.Titulo -match 'Login' } | Select-Object -First 1)
  if ($hLogin.Count -eq 0) { throw "janela de login nao abriu" }
  $fc = Get-FormControls $hLogin[0].Hwnd
  $edits = @($fc.Edits | Sort-Object Y)
  [ERPUI]::SetText($edits[0].Hwnd, $usuario) | Out-Null
  [ERPUI]::SetText($edits[1].Hwnd, $senha) | Out-Null
  $btnEntrar = @($fc.Buttons | Sort-Object X) | Select-Object -First 1
  [ERPUI]::ClickHwnd($btnEntrar.Hwnd) | Out-Null
  Start-Sleep -Seconds 4

  $hMain = @((Get-Windows) | Where-Object { $_.Titulo -match 'Sistema de Gest' } | Select-Object -First 1)
  if ($hMain.Count -eq 0) { throw "tela principal nao abriu apos login" }
  $hMain = $hMain[0].Hwnd
  Write-Host "OK [app logado como $usuario]"

  $itens = @(Get-MenuItens $hMain | Where-Object { $_.Id -gt 0 -and $_.Texto -ne '-' -and $_.Texto -notmatch '^Sair$' })
  Write-Host "OK [menu lido: $($itens.Count) telas]"
  Write-Host "   --- estado de cada item ---"
  foreach ($it in $itens) {
    Write-Host ("   {0,-45} {1}" -f $it.Caminho, $(if ($it.Habilitado) { 'HABILITADO' } else { 'bloqueado' }))
  }

  $pessoas = $itens | Where-Object { $_.Caminho -match 'Pessoas' } | Select-Object -First 1
  $pedidos = $itens | Where-Object { $_.Caminho -match 'Novo Pedido' } | Select-Object -First 1
  if (-not $pessoas) { Falha 'item de menu Pessoas nao encontrado' }
  if (-not $pedidos) { Falha 'item de menu Novo Pedido nao encontrado' }

  if ($pessoas) {
    if ($pessoas.Habilitado) { Ok 'menu: Cadastros > Pessoas liberado (tem permissao)' }
    else { Falha 'menu: Cadastros > Pessoas deveria estar liberado' }
  }
  if ($pedidos) {
    if (-not $pedidos.Habilitado) { Ok 'menu: Producao > Novo Pedido bloqueado (sem permissao)' }
    else { Falha 'menu: Producao > Novo Pedido deveria estar bloqueado' }
  }

  # tentar abrir a tela bloqueada: nao pode abrir
  if ($pedidos) {
    $antes = @(Get-Windows | ForEach-Object { $_.Hwnd.ToString('X') })
    [ERPMENU]::PostMessage($hMain, 0x0111, [IntPtr]$pedidos.Id, [IntPtr]0) | Out-Null
    $dlg = $null; $abriu = $false
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutAbrirSeg) {
      $tops = @(Get-Windows)
      $novas = @($tops | Where-Object { $antes -notcontains $_.Hwnd.ToString('X') })
      $d = @($novas | Where-Object { $_.Classe -eq '#32770' } | Select-Object -First 1)
      if ($d.Count -gt 0) { $dlg = $d[0]; break }
      $jan = @($novas | Where-Object { $_.Classe -ne '#32770' -and $_.Titulo } | Select-Object -First 1)
      if ($jan.Count -gt 0) { $abriu = $true; break }
      Start-Sleep -Milliseconds 250
    }
    if ($dlg) {
      $txt = Get-DialogText $dlg.Hwnd
      if ($txt -match 'permiss') { Ok "tela bloqueada avisou: $txt" }
      else { Falha "tela bloqueada avisou algo inesperado: $txt" }
      [void](Fecha-Janela $dlg.Hwnd 2000)
    } elseif ($abriu) {
      Falha 'a tela bloqueada abriu mesmo sem permissao'
    } else {
      Ok 'tela bloqueada nao abriu (item desabilitado no menu)'
    }
  }

  # abrir a tela liberada: deve abrir
  if ($pessoas) {
    $antes = @(Get-Windows | ForEach-Object { $_.Hwnd.ToString('X') })
    [ERPMENU]::PostMessage($hMain, 0x0111, [IntPtr]$pessoas.Id, [IntPtr]0) | Out-Null
    $abriu = $false
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutAbrirSeg) {
      $tops = @(Get-Windows)
      $novas = @($tops | Where-Object { $antes -notcontains $_.Hwnd.ToString('X') })
      $jan = @($novas | Where-Object { $_.Classe -ne '#32770' -and $_.Titulo -match 'Pessoas' } | Select-Object -First 1)
      if ($jan.Count -gt 0) { $abriu = $true; break }
      Start-Sleep -Milliseconds 250
    }
    if ($abriu) { Ok 'tela liberada abriu normalmente' }
    else { Falha 'a tela liberada nao abriu' }
  }
}
finally {
  Get-Process ERP2026 -ErrorAction SilentlyContinue | Stop-Process -Force
  Remove-Usuario
}

Write-Host ""
Write-Host "========================================"
if ($falhas -eq 0) {
  Write-Host "PERMISSOES-MENU CONCLUIDO (0 falhas)"
  exit 0
} else {
  Write-Host "PERMISSOES-MENU COM $falhas FALHA(S)"
  exit 1
}
