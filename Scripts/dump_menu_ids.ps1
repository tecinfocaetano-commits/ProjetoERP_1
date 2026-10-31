# ============================================================
# ERP 2026 - Dump empirico dos IDs de menu (WM_COMMAND)
# Gera Documentacao\MAPA_IDS_MENU.md lendo o menu Win32 da
# janela principal apos login (admin/admin123).
#
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\dump_menu_ids.ps1
#
# O script mata instancias do ERP2026, abre o exe, loga, le o menu
# (GetMenu/GetSubMenu/GetMenuItemID/GetMenuString), grava o .md e
# fecha o programa. Textos estaticos em ASCII (os caption acentuados
# vem dos runtime e sao gravados em UTF-8).
# ============================================================
$ErrorActionPreference = 'Stop'

if (-not ('ERPDUMP' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class ERPDUMP {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, StringBuilder s);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr h, int nPos);
  [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetMenuItemID(IntPtr h, int nPos);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetMenuString(IntPtr h, uint uItem, StringBuilder s, int nMaxCount, uint uFlag);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
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
  public static void ClickHwnd(IntPtr h) { PostMessage(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); } // BM_CLICK
  public static void SetText(IntPtr h, string t) { SendMessage(h, 0x000C, IntPtr.Zero, new StringBuilder(t)); }
}
'@
}

function Get-ERPProcess { Get-Process ERP2026 -ErrorAction SilentlyContinue | Select-Object -First 1 }
function Wait-Window([string]$part, [int]$timeoutSec = 10) {
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt $timeoutSec) {
    $p = Get-ERPProcess
    if ($p) {
      $h = [ERPDUMP]::FindWin([uint32]$p.Id, $part)
      if ($h -ne [IntPtr]::Zero) { return $h }
    }
    Start-Sleep -Milliseconds 300
  }
  return [IntPtr]::Zero
}

function Start-ERPApp {
  Get-Process ERP2026 -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 1
  $exe = Join-Path $PSScriptRoot '..\Desktop\bin\ERP2026.exe'
  if (-not (Test-Path $exe)) { throw "exe nao encontrado: $exe" }
  Start-Process $exe
  Start-Sleep -Seconds 4
  $hLogin = Wait-Window 'Login' 10
  if ($hLogin -eq [IntPtr]::Zero) { throw 'janela de login nao abriu' }
  $kids = @([ERPDUMP]::Kids($hLogin) -split "`r?`n" | Where-Object { $_ })
  $edits = @()
  foreach ($k in $kids) {
    if ($k -match '^([0-9A-F]+) \| Edit \| ''(.*)'' \| \((\d+),(\d+)\)-\((\d+),(\d+)\)') {
      $edits += [pscustomobject]@{ Hwnd = [IntPtr]([Convert]::ToInt64($Matches[1], 16)); Y = [int]$Matches[4] }
    }
  }
  $edits = @($edits | Sort-Object Y)
  if ($edits.Count -lt 2) { throw 'edits do login nao encontrados' }
  [ERPDUMP]::SetText($edits[0].Hwnd, 'admin') | Out-Null
  [ERPDUMP]::SetText($edits[1].Hwnd, 'admin123') | Out-Null
  $btns = @()
  foreach ($k in $kids) {
    if ($k -match '^([0-9A-F]+) \| Button \| ''(.*)'' \| \((\d+),(\d+)\)-\((\d+),(\d+)\)') {
      $btns += [pscustomobject]@{ Hwnd = [IntPtr]([Convert]::ToInt64($Matches[1], 16)); X = [int]$Matches[3] }
    }
  }
  $btns = @($btns | Sort-Object X)
  if ($btns.Count -eq 0) { throw 'botao de login nao encontrado' }
  [ERPDUMP]::ClickHwnd($btns[0].Hwnd)
  Start-Sleep -Seconds 3
  $hMain = Wait-Window 'Sistema de Gest' 10
  if ($hMain -eq [IntPtr]::Zero) { throw 'tela principal nao abriu apos login' }
  return $hMain
}

# remove acentos e '&' -> chave ASCII estavel entre builds/languages
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

function Get-MenuText([IntPtr]$h, [int]$pos) {
  $sb = New-Object Text.StringBuilder 256
  [void][ERPDUMP]::GetMenuString($h, [uint32]$pos, $sb, 256, 0x400)  # MF_BYPOSITION
  return $sb.ToString()
}

# caption (folded) -> @(componente, tela/acao) — anotado a partir de
# uFrmPrincipal.lfm / uFrmPrincipal.pas (handlers OnClick)
$mapa = @{
  'clientes'             = @('mnuCadClientes', 'TfrmClientes')
  'fornecedores'         = @('mnuCadFornecedores', 'TfrmFornecedores')
  'produtos'             = @('mnuCadProdutos', 'TfrmProdutos')
  'categorias'           = @('mnuCadCategorias', 'TfrmCategorias')
  'usuarios'             = @('mnuCadUsuarios', 'TfrmUsuarios')
  'movimentacao'         = @('mnuEstMovimentacao', 'TfrmMovEstoque')
  'inventario'           = @('mnuEstInventario', 'TfrmInventario')
  'kardex'               = @('mnuEstKardex', 'TfrmKardex')
  'nota de entrada'      = @('mnuComNotaEntrada', 'TfrmNotaEntrada')
  'novo pedido'          = @('mnuVenPedidos', 'TfrmPedidoVenda')
  'novo orcamento'       = @('mnuVenOrcamentos', 'TfrmOrcamento')
  'lista de pedidos'     = @('mnuVenListaPedidos', 'TfrmListaPedidos')
  'nota de saida'        = @('mnuVenNotaSaida', 'TfrmNotaSaida')
  'mapa de producao'     = @('mnuProMapaProducao', 'TfrmMapaProducao (permissao MAPA_PRODUCAO)')
  'bipagem de taloes'    = @('mnuProBipagem', 'TfrmBipagem (permissao BIPAGEM)')
  'ficha tecnica'        = @('mnuProFichaTecnica', 'TfrmFichaTecnica (permissao FICHA_TECNICA)')
  'consumo de materiais' = @('mnuProConsumo', 'TfrmConsumoMaterial (permissao CONSUMO)')
  'abrir pdv'            = @('mnuPDVAbrirPDV', 'TfrmPDV')
  'contas a receber'     = @('mnuFinContasReceber', 'TfrmContasReceber')
  'contas a pagar'       = @('mnuFinContasPagar', 'TfrmContasPagar')
  'caixa'                = @('mnuFinCaixa', 'TfrmCaixa (consulta de caixas e movimentos)')
  'nf-e / nfc-e'        = @('mnuFisNFe', 'TfrmNFe')
  'central de relatorios...' = @('mnuRelCentral', 'TfrmCentralRelatorios (caminhos/.lrf, modelo ativo, atalho p/ tela do Mapa)')
  'abrir copiloto erp'   = @('mnuIACopiloto', 'TfrmCopiloto')
  'configuracoes'        = @('mnuSisConfiguracoes', 'TfrmConfiguracoes (editor da CONFIGURACAO da empresa)')
  'permissoes'           = @('mnuSisPermissoes', 'TfrmPermissoes (editor da matriz PERMISSAO)')
  'sair'                 = @('mnuSisSair', 'Close do formulario principal')
}

# percorre um nivel do menu emitindo linhas em $rows (ArrayList do escopo script)
function Add-MenuRows([IntPtr]$h, [string]$path) {
  $n = [ERPDUMP]::GetMenuItemCount($h)
  for ($i = 0; $i -lt $n; $i++) {
    $txt = Get-MenuText $h $i
    $sub = [ERPDUMP]::GetSubMenu($h, $i)
    if ($sub -ne [IntPtr]::Zero) {
      Add-MenuRows $sub ($path + ' > ' + $txt.Replace('&', ''))
    } else {
      $id = [ERPDUMP]::GetMenuItemID($h, $i)
      [void]$rows.Add([pscustomobject]@{ Path = $path; Text = $txt; Id = $id })
    }
  }
}

# ---------- execucao ----------
$hMain = Start-ERPApp
$hMenu = [ERPDUMP]::GetMenu($hMain)
if ($hMenu -eq [IntPtr]::Zero) { throw 'janela principal sem menu' }

$rows = New-Object System.Collections.ArrayList
$nTop = [ERPDUMP]::GetMenuItemCount($hMenu)
for ($g = 0; $g -lt $nTop; $g++) {
  $grupo = (Get-MenuText $hMenu $g).Replace('&', '')
  $subTop = [ERPDUMP]::GetSubMenu($hMenu, $g)
  if ($subTop -ne [IntPtr]::Zero) {
    Add-MenuRows $subTop $grupo
  } else {
    [void]$rows.Add([pscustomobject]@{ Path = $grupo; Text = '(grupo sem itens)'; Id = -1 })
  }
}

# fecha o programa
[ERPDUMP]::PostMessage($hMain, 0x0010, [IntPtr]0, [IntPtr]0) | Out-Null
Start-Sleep -Seconds 2
$pLeft = Get-ERPProcess
if ($pLeft) { $pLeft | Stop-Process -Force -ErrorAction SilentlyContinue }

# ---------- tabela ----------
$md = @()
$md += '# Mapa de IDs de menu (WM_COMMAND) - ERP 2026'
$md += ''
$md += 'Leitura empirica do menu Win32 da janela principal (login `admin` / `admin123`),'
$md += 'gerada por `Scripts\dump_menu_ids.ps1`. Regenerar apos qualquer mudanca de menu:'
$md += ''
$md += '```bat'
$md += 'powershell -NoProfile -ExecutionPolicy Bypass -File Scripts\dump_menu_ids.ps1'
$md += '```'
$md += ''
$md += 'Os IDs sao atribuidos pelo LCL na ordem de criacao dos itens do `.lfm` e sao'
$md += 'estaveis para o mesmo executavel. Uso em automacao de testes (cross-process):'
$md += ''
$md += '```pascal'
$md += 'PostMessage(hwndPrincipal, WM_COMMAND (0x0111), wParam=ID, lParam=0)'
$md += '```'
$md += ''
$md += 'Exemplo (tela Producao > Mapa de Producao, usada nos testes da Fase 6):'
$md += ''
$md += '```pascal'
$md += 'PostMessage(hMain, 0x0111, 21, 0);   // ID 21 = Mapa de Producao'
$md += '```'
$md += ''
$md += '## Tabela'
$md += ''
$md += '| ID | Menu | Item | Componente | Tela / acao |'
$md += '|---:|---|---|---|---|'

$mapaIdEsperado = $null
foreach ($r in $rows) {
  $key = Fold $r.Text
  if ($r.Text -eq '-' -or $key -eq '-') {
    $md += ("| - | {0} | (separador) | - | - |" -f $r.Path)
    continue
  }
  $comp = '?'; $tela = '?'
  if ($mapa.ContainsKey($key)) { $comp = $mapa[$key][0]; $tela = $mapa[$key][1] }
  $idTxt = if ($r.Id -lt 0) { '-' } else { [string]$r.Id }
  $md += ("| {0} | {1} | {2} | {3} | {4} |" -f $idTxt, $r.Path, $r.Text, $comp, $tela)
  if ($key -eq 'mapa de producao') { $mapaIdEsperado = $r.Id }
}

$md += ''
$md += 'Notas:'
$md += ''
$md += '- Nenhum item do menu principal e inerte (todos tem OnClick).'
$md += '- O grupo "Relatorios" tem o subitem "Central de Relatorios...".'
$md += '- Menus de popup das telas (ex.: botao "Relatorio" da tela do Mapa) nao sao menu de'
$md += '  janela: a automacao de testes le por MSAA e clica por coordenadas.'
$md += ''
if ($mapaIdEsperado -ne $null) {
  $md += ('Controle de sanidade: ID de "Mapa de Producao" = {0} (testes da Fase 6 usam 21).' -f $mapaIdEsperado)
} else {
  $md += 'Controle de sanidade: "Mapa de Producao" nao encontrado na leitura!'
}

$out = Join-Path $PSScriptRoot '..\Documentacao\MAPA_IDS_MENU.md'
$md | Out-File -FilePath $out -Encoding utf8
Write-Host ("linhas do menu: {0}" -f $rows.Count)
Write-Host ("gerado: {0}" -f (Resolve-Path $out))
if ($mapaIdEsperado -ne 21) {
  Write-Host ("AVISO: esperava ID 21 para 'Mapa de Producao', veio: {0}" -f $mapaIdEsperado)
}
