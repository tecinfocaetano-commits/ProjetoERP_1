# ============================================================
# ERP 2026 - Teste de UI das telas de administracao (30/10/2026)
# Abre pelo MENU PRINCIPAL as 4 telas novas (Financeiro > Caixa,
# Sistema > Configuracoes, Sistema > Permissoes, Relatorios >
# Central de Relatorios), confere que cada uma abriu (janela com
# botoes), tira evidencia e fecha a tela.
#
# O ID do comando vem da leitura do menu Win32 POR CAPTION
# (GetMenu/GetSubMenu/GetMenuItemID), entao o teste nao depende
# de numero fixo e continua valido quando o menu ganha itens.
#
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\testes\telas_adm_ui.ps1
# Esperado: TELAS-ADM-UI CONCLUIDO
# ============================================================
. "$PSScriptRoot\fase5lib.ps1"
$ErrorActionPreference = 'Stop'

if (-not ('ERPADM' -as [type])) {
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class ERPADM {
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr h, int nPos);
  [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetMenuItemID(IntPtr h, int nPos);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetMenuString(IntPtr h, uint uItem, StringBuilder s, int nMaxCount, uint uFlag);
}
'@
}

# remove acentos e '&' -> chave ASCII estavel
# (mesma ideia do Scripts\dump_menu_ids.ps1)
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

function Add-MenuRows([IntPtr]$h, $rows) {
  $n = [ERPADM]::GetMenuItemCount($h)
  for ($i = 0; $i -lt $n; $i++) {
    $sub = [ERPADM]::GetSubMenu($h, $i)
    if ($sub -ne [IntPtr]::Zero) {
      Add-MenuRows $sub $rows
    } else {
      $sb = New-Object Text.StringBuilder 256
      [void][ERPADM]::GetMenuString($h, [uint32]$i, $sb, 256, 0x400)  # MF_BYPOSITION
      [void]$rows.Add([pscustomobject]@{ Text = $sb.ToString(); Id = [ERPADM]::GetMenuItemID($h, $i) })
    }
  }
}

function Get-MenuItemId([IntPtr]$hMain, [string]$captionFolded) {
  $hMenu = [ERPADM]::GetMenu($hMain)
  if ($hMenu -eq [IntPtr]::Zero) { throw 'janela principal sem menu' }
  $rows = New-Object System.Collections.ArrayList
  Add-MenuRows $hMenu $rows
  foreach ($r in $rows) {
    if ((Fold $r.Text) -eq $captionFolded) { return $r.Id }
  }
  $nomes = ($rows | ForEach-Object { Fold $_.Text }) -join ' | '
  throw "item de menu nao encontrado: '$captionFolded'. itens: $nomes"
}

# ============ 1. app + login ============
$hMain = Start-ERPApp
"OK [app logado]"

# ============ 2. abre cada tela nova pelo menu ============
# legenda da janela: prefixo SEM acento (Wait-Window faz substring)
$alvos = @(
  @{ Menu = 'caixa';                    Janela = 'Caixa';            Nome = '01_caixa' },
  @{ Menu = 'configuracoes';            Janela = 'Configura';        Nome = '02_configuracoes' },
  @{ Menu = 'permissoes';               Janela = 'Permiss';          Nome = '03_permissoes' },
  @{ Menu = 'central de relatorios...'; Janela = 'Central de Relat'; Nome = '04_central_relatorios' }
)

foreach ($a in $alvos) {
  $id = Get-MenuItemId $hMain $a.Menu
  if ($id -le 0) { throw ("item de menu sem ID (inerte?): '" + $a.Menu + "' -> id=" + $id) }
  "OK [id do menu '" + $a.Menu + "' = $id]"

  [ERPUI]::PostMessage($hMain, 0x0111, [IntPtr]$id, [IntPtr]0) | Out-Null   # WM_COMMAND
  $hForm = Wait-Window $a.Janela 12
  if ($hForm -eq [IntPtr]::Zero) { throw ("a tela '" + $a.Janela + "' nao abriu (cmd " + $id + ")") }
  Start-Sleep -Milliseconds 900

  Force-Foreground $hForm
  Start-Sleep -Milliseconds 400
  $fc = Get-FormControls $hForm
  if (@($fc.Buttons).Count -eq 0) { throw ("tela '" + $a.Janela + "' abriu sem botoes: janela errada") }
  "OK [tela " + $a.Nome + " aberta: " + (@($fc.Buttons).Count) + " botoes]"

  Shot-Win $hForm ("$EV\telas_adm_" + $a.Nome + ".png")

  # fecha a tela (WM_CLOSE)
  [ERPUI]::PostMessage($hForm, 0x0010, [IntPtr]0, [IntPtr]0) | Out-Null
  Start-Sleep -Milliseconds 900
}

# ============ 3. fecha o app ============
[ERPUI]::PostMessage($hMain, 0x0010, [IntPtr]0, [IntPtr]0) | Out-Null
Start-Sleep -Seconds 2
$pLeft = Get-ERPProcess
if ($pLeft) { $pLeft | Stop-Process -Force -ErrorAction SilentlyContinue }

''
'TELAS-ADM-UI CONCLUIDO'
