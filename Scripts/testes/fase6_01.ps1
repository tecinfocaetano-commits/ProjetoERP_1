. "$PSScriptRoot\fase5lib.ps1"
$ErrorActionPreference = 'Stop'

function Confirm-Contains([string]$txt, [string]$esperado, [string]$onde) {
  if ($txt -notlike "*$esperado*") { throw "ASSERT em ${onde}: esperado '$esperado'. Veio: $txt" }
  "OK [$onde]: $esperado"
}

if (-not ('ERPM6' -as [type])) {
  Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public class ERPM6 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetMenuString(IntPtr h, uint id, StringBuilder s, int n, int flags);
  [DllImport("user32.dll")] public static extern bool GetMenuItemRect(IntPtr h, uint pos, out RECT r);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public static IntPtr FindClass(uint pid, string cls) {
    IntPtr f = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var c = new StringBuilder(128); GetClassName(h, c, 128);
        if (c.ToString() == cls) { f = h; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return f;
  }
  public static string List(uint pid) {
    var sb = new StringBuilder();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var t = new StringBuilder(512); GetWindowText(h, t, 512);
        sb.AppendLine(h.ToInt64().ToString("X") + "|" + t.ToString());
      }
      return true;
    }, IntPtr.Zero);
    return sb.ToString();
  }
}
'@
}

function Get-TopHwnds([uint32]$p) {
  $set = @{}
  foreach ($l in ([ERPM6]::List($p) -split "`r?`n")) {
    if ($l -match '^([0-9A-F]+)\|') { $set[[Convert]::ToInt64($Matches[1], 16)] = $true }
  }
  return $set
}

function Find-NewWindow([uint32]$p, $antes) {
  foreach ($l in ([ERPM6]::List($p) -split "`r?`n")) {
    if ($l -match '^([0-9A-F]+)\|(.*)$') {
      $hx = [Convert]::ToInt64($Matches[1], 16)
      if (-not $antes.ContainsKey($hx)) { return [IntPtr]$hx }
    }
  }
  return [IntPtr]::Zero
}

function Get-DropMenuButton([IntPtr]$hForm) {
  # botão "▼" = largura fixa 30 (btnRelatorioMenu.Width=30; sem texto legível
  # cross-process, então identificamos pela geometria)
  $fc = Get-FormControls $hForm
  $cand = @($fc.Buttons | Where-Object { ($_.X2 - $_.X) -eq 30 })
  if ($cand.Count -eq 1) { return $cand[0] }
  if ($cand.Count -gt 1) {
    $cand = @($cand | Sort-Object Y -Descending)
    return $cand[0]
  }
  throw ("botao do menu (w=30) nao encontrado. Larguras: " +
    (($fc.Buttons | ForEach-Object { $_.X2 - $_.X }) -join ', '))
}

function Open-RelMenu([IntPtr]$hForm) {
  $btn = Get-DropMenuButton $hForm
  [ERPUI]::ClickHwnd($btn.Hwnd) | Out-Null
  Start-Sleep -Seconds 1
  $p = [uint32](Get-ERPProcess).Id
  $hMenu = [ERPM6]::FindClass($p, '#32768')
  if ($hMenu -eq [IntPtr]::Zero) { throw "menu popup nao abriu" }
  return $hMenu
}

if (-not ('ERPMSAA' -as [type])) {
  Add-Type @'
using System; using System.Runtime.InteropServices;
public class ERPMSAA {
  [DllImport("oleacc.dll")]
  public static extern int AccessibleObjectFromWindow(IntPtr hwnd, uint id, ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object acc);
  public static object Get(IntPtr hwnd, uint objid) {
    Guid iid = new Guid("618736e0-3c3d-11cf-810c-00aa00389b71");
    object o; int hr = AccessibleObjectFromWindow(hwnd, objid, ref iid, out o);
    if (hr != 0) return null;
    return o;
  }
}
'@
}

function Get-MenuItems([IntPtr]$hMenu) {
  # itens de menu via MSAA (OBJID_CLIENT): menus têm provedor de sistema;
  # HMENU e processo-local e a UIA nao expoe o popup neste contexto.
  # emite 1 objeto por item (pipeline sempre achata; sem return de array)
  $acc = [ERPMSAA]::Get($hMenu, 4294967292)   # OBJID_CLIENT = -4
  if (-not $acc) { return }
  $cc = $acc.accChildCount
  for ($i = 1; $i -le $cc; $i++) {
    $nm = ''
    try { $nm = $acc.accName($i) } catch { $nm = '' }
    $x = 0; $y = 0; $w = 0; $h = 0
    try { $acc.accLocation([ref]$x, [ref]$y, [ref]$w, [ref]$h, $i) | Out-Null } catch { }
    [pscustomobject]@{
      Name = [string]$nm
      Cx = [int]($x + $w / 2); Cy = [int]($y + $h / 2)
    }
  }
}

function Flatten-Items($raw) {
  # achata ate 2 niveis: protege contra retorno aninhado (Object[] de Object[]);
  # emite item a item (nunca retorna array agregado)
  foreach ($u in @($raw)) {
    if ($u -is [Array]) {
      foreach ($v in @($u)) {
        if ($v -is [Array]) { foreach ($z in @($v)) { $z } } else { $v }
      }
    } else { $u }
  }
}

function Click-MenuItem([IntPtr]$hMenu, [string]$part) {
  $items = @(Flatten-Items (Get-MenuItems $hMenu))
  $alvo = $items | Where-Object { $_.Name -like "*$part*" } | Select-Object -First 1
  if (-not $alvo) {
    $nomes = ($items | ForEach-Object { "'$($_.Name)'" }) -join ' / '
    if (-not $nomes) { $nomes = '(MSAA nao expôs nenhum item!)' }
    throw "item de menu nao encontrado: $part | itens: $nomes"
  }
  if ($alvo -is [Array] -or $alvo.Cx -is [Array]) {
    throw "DEBUG alvoTipo=$($alvo.GetType().Name) count=$($alvo.Count) " +
      "cxTipo=$($alvo.Cx.GetType().Name) itemsCount=$($items.Count) " +
      "nomes=$(($items | ForEach-Object { $_.Name }) -join ';')"
  }
  [ERPUI]::ClickXY([int]$alvo.Cx, [int]$alvo.Cy)
  return [string]$alvo.Name
}

function Save-PdfViaDialog([string]$pasta, [string]$onde) {
  $hDlg = Wait-Window 'Exportar relat' 8
  if ($hDlg -eq [IntPtr]::Zero) { $hDlg = (Get-ERPDialogs | Select-Object -First 1).Hwnd }
  if (-not $hDlg -or $hDlg -eq [IntPtr]::Zero) { throw "SaveDialog nao abriu ($onde)" }
  Start-Sleep -Milliseconds 800

  $ed = $null
  foreach ($k in ([ERPUI]::Kids($hDlg) -split "`r?`n")) {
    if ($k -match '^([0-9A-F]+) \| Edit ') { $ed = [IntPtr]([Convert]::ToInt64($Matches[1], 16)); break }
  }
  if (-not $ed) { throw "edit do SaveDialog nao encontrado ($onde)" }
  # nao reescrever o nome: o SaveDialog do Windows (estilo Vista/IFileDialog)
  # ignora WM_SETTEXT no edit e confirmaria com o nome proprio — confirmar com
  # o nome sugerido pelo dialogo e o fluxo real do usuario
  $sugerido = [ERPUI]::GetText($ed)
  "  [$onde] nome sugerido pelo dialogo: '$sugerido'"
  $btns = @(Get-DialogButtons $hDlg | Sort-Object X)
  # texto nativo vem com acelerador (ex.: 'Sa&lvar'): remover '&' antes de comparar
  $salvar = $btns | Where-Object { ($_.Text -replace '&','') -match '^(Salvar|Save)' } | Select-Object -First 1
  if (-not $salvar) {
    # sem texto: descartar Ajuda/Cancelar — confirmar e o botao que sobrar
    $salvar = $btns | Where-Object { ($_.Text -replace '&','') -notmatch 'Ajuda|Help|Cancelar|Cancel|Close' } | Select-Object -First 1
  }
  if (-not $salvar) { $salvar = $btns | Select-Object -First 1 }
  if (-not $salvar) { throw "botao Salvar nao encontrado ($onde)" }
  [ERPUI]::ClickHwnd($salvar.Hwnd)
  Start-Sleep -Seconds 2
  if ((Find-ERPWindow 'Exportar relat') -ne [IntPtr]::Zero) {
    throw "SaveDialog ainda aberto apos Salvar ($onde): o clique nao confirmou"
  }

  # espera o diálogo LCL de sucesso (o SaveDialog some ao confirmar)
  $d = $null; $txt = ''
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt 8) {
    foreach ($cand in @(Get-ERPDialogs)) {
      $t = ''
      try { $t = Get-DialogText $cand.Hwnd } catch { }
      if ($t -match 'PDF gerado com sucesso') { $d = $cand; $txt = $t; break }
      if ($t) { $txt = $t }   # ultimo texto visto (diagnostico)
    }
    if ($d) { break }
    Start-Sleep -Milliseconds 400
  }
  if (-not $d) { throw "dialogo de sucesso nao apareceu ($onde). ultimo texto: $txt" }
  Force-Foreground $d.Hwnd
  Start-Sleep -Milliseconds 400
  Confirm-Contains $txt 'PDF gerado com sucesso' $onde
  Shot-Win $d.Hwnd "$EV\$onde.png"
  # fecha: texto 'OK' se vier, senão primeiro botão (TaskDialog tem só OK)
  $ok = Get-DialogButtons $d.Hwnd | Where-Object { ($_.Text -replace '&','') -match '^OK' } | Select-Object -First 1
  if (-not $ok) { $ok = @(Get-DialogButtons $d.Hwnd | Sort-Object X) | Select-Object -First 1 }
  if ($ok) { [ERPUI]::ClickHwnd($ok.Hwnd); Start-Sleep -Seconds 1 }
}

function Assert-Pdf([string]$path, [string]$onde) {
  if (-not (Test-Path $path)) { throw "PDF nao foi criado ($onde): $path" }
  $fs = [System.IO.File]::OpenRead($path)
  try {
    $b = New-Object byte[] 4
    [void]$fs.Read($b, 0, 4)
    $magic = [System.Text.Encoding]::ASCII.GetString($b)
  } finally { $fs.Dispose() }
  if ($magic -ne '%PDF') { throw "arquivo nao e PDF ($onde): magic='$magic'" }
  $len = (Get-Item $path).Length
  if ($len -lt 1000) { throw "PDF suspeito, apenas $len bytes ($onde)" }
  "OK [$onde]: $(Split-Path $path -Leaf) ($len bytes, cabecalho %PDF)"
}

function Get-NovoPdf([string]$pasta, [datetime]$inicio, [string]$onde) {
  $novo = Get-ChildItem $pasta -Filter *.pdf -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $inicio } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $novo) { throw "nenhum PDF novo em $pasta ($onde)" }
  return $novo.FullName
}

# ============ 1. app + login + tela Mapa ============
$hMain = Start-ERPApp
[ERPUI]::PostMessage($hMain, 0x0111, [IntPtr]21, [IntPtr]0) | Out-Null
$hMapa = Wait-Window 'Mapa de Produ' 10
if ($hMapa -eq [IntPtr]::Zero) { throw 'Mapa de Producao nao abriu (cmd 21)' }
Start-Sleep -Seconds 3
Force-Foreground $hMapa

# ============ 2. tela aberta (detalhe do mapa: TLabel nao tem hwnd,
#                 entao a auto-selecao e comprovada pelo PREVIEW no passo 4) ============
$fc = Get-FormControls $hMapa
if (@($fc.Buttons).Count -eq 0) { throw 'formulário sem botões: janela errada' }
Force-Foreground $hMapa
Start-Sleep -Milliseconds 400
Shot-Win $hMapa "$EV\fase6_01_mapa_lista.png"
"OK [tela mapa aberta: $(@($fc.Buttons).Count) botoes]"

# ============ 3. menu Relatorio: mostra os itens novos ============
$hMenu = Open-RelMenu $hMapa
$items = @(Flatten-Items (Get-MenuItems $hMenu))
$menu = ($items | ForEach-Object { $_.Name }) -join ' | '
if (-not $menu) { throw 'MSAA nao expôs itens do menu popup' }
"menu: $menu"
Confirm-Contains $menu 'Exportar talões em PDF' 'item menu PDF taloes'
Confirm-Contains $menu 'Relatório do mapa (visualizar)' 'item menu preview mapa'
Confirm-Contains $menu 'Relatório do mapa (exportar PDF)' 'item menu PDF mapa'
# sem nenhum SetForegroundWindow aqui: o menu e topmost e tem captura do mouse
# (forcar foreground cancela o rastreamento do TrackPopupMenu)
Start-Sleep -Milliseconds 300
$mrect = [ERPUI]::Rect($hMenu)
$mw = $mrect.Right - $mrect.Left; $mh = $mrect.Bottom - $mrect.Top
if ($mw -le 0 -or $mh -le 0) { throw "menu sumiu antes da captura (rect $mw x $mh)" }
Shot-Win $hMenu "$EV\fase6_02_menu_relatorio.png"
# fecha o menu sem escolher item: ESC e validado (se nao fechar, o teste quebra)
$p = [uint32](Get-ERPProcess).Id
[ERPUI]::PostMessage($hMenu, 0x0100, [IntPtr]0x1B, [IntPtr]0) | Out-Null  # WM_KEYDOWN VK_ESCAPE
Start-Sleep -Milliseconds 800
if ([ERPM6]::FindClass([uint32]$p, '#32768') -ne [IntPtr]::Zero) {
  [ERPUI]::PostMessage($hMenu, 0x0100, [IntPtr]0x1B, [IntPtr]0) | Out-Null
  Start-Sleep -Milliseconds 800
}
if ([ERPM6]::FindClass([uint32]$p, '#32768') -ne [IntPtr]::Zero) {
  # fallback: clique fora fecha o menu (ponto vazio da barra de ferramentas)
  [ERPUI]::ClickXY(400, 210)
  Start-Sleep -Milliseconds 800
}
if ([ERPM6]::FindClass([uint32]$p, '#32768') -ne [IntPtr]::Zero) { throw 'menu nao fechou (ESC/clique fora)' }
'OK [menu fechado]'

# ============ 4. Relatorio do mapa - PREVIEW ============
$p = [uint32](Get-ERPProcess).Id
$antes = Get-TopHwnds $p
$hMenu = Open-RelMenu $hMapa
[void](Click-MenuItem $hMenu '(visualizar)')
Start-Sleep -Seconds 3
$hPrev = Find-NewWindow $p $antes
if ($hPrev -eq [IntPtr]::Zero) { throw 'janela nova nao abriu apos o clique no menu' }
if ([ERPUI]::WinClass($hPrev) -eq '#32770') {
  # abriu um diagnostico em vez do preview (ex.: mapa sem selecao)
  $t = ''
  try { $t = Get-DialogText $hPrev } catch { }
  throw "preview NAO abriu; dialogo exibido: $t"
}
Start-Sleep -Milliseconds 1200
Force-Foreground $hPrev
Start-Sleep -Milliseconds 500
Shot-Win $hPrev "$EV\fase6_03_relatorio_mapa_preview.png"
"OK [preview]: hwnd=$($hPrev.ToInt64().ToString('X'))"
[ERPUI]::PostMessage($hPrev, 0x0010, [IntPtr]0, [IntPtr]0) | Out-Null
Start-Sleep -Seconds 1

# ============ 5. Exportar TALOES em PDF ============
$reldir = 'C:\Users\Charles\Documents\ProjetoERP_1\Desktop\bin\relatorios'
# limpa PDFs anteriores: evita prompt de sobrescrita no dialogo e arquivo velho
Get-ChildItem $reldir -Filter *.pdf -File -ErrorAction SilentlyContinue | Remove-Item -Force
$inicio = Get-Date
$hMenu = Open-RelMenu $hMapa
[void](Click-MenuItem $hMenu 'Exportar talões')
Save-PdfViaDialog $reldir 'fase6_04_pdf_taloes'
Assert-Pdf (Get-NovoPdf $reldir $inicio 'taloes') 'pdf taloes'

# ============ 6. Exportar RELATORIO DO MAPA em PDF ============
$inicio = Get-Date
$hMenu = Open-RelMenu $hMapa
[void](Click-MenuItem $hMenu 'mapa (exportar PDF)')
Save-PdfViaDialog $reldir 'fase6_05_pdf_mapa'
Assert-Pdf (Get-NovoPdf $reldir $inicio 'mapa') 'pdf mapa'

# ============ 7. Editor do relatorio de taloes (unit lr_desgn) ============
# o editor exige a unit lr_desgn linkada: sem ela ProcedureInitDesigner
# fica nil e DesignReport volta em silencio sem abrir janela nenhuma
$hashesAntes = @{}
Get-ChildItem $reldir -Filter *.lrf -File | ForEach-Object {
  $hashesAntes[$_.FullName] = (Get-FileHash $_.FullName).Hash
}

function Find-NewWinEx([uint32]$p, $antes) {
  # primeira janela nova do processo que NAO seja o popup do menu (#32768)
  foreach ($l in ([ERPM6]::List($p) -split "`r?`n")) {
    if ($l -match '^([0-9A-F]+)\|') {
      $hx = [Convert]::ToInt64($Matches[1], 16)
      if (-not $antes.ContainsKey($hx)) {
        $h = [IntPtr]$hx
        if ([ERPUI]::WinClass($h) -ne '#32768') { return $h }
      }
    }
  }
  return [IntPtr]::Zero
}

function Abrir-Editor([string]$onde) {
  $p = [uint32](Get-ERPProcess).Id
  $antes = Get-TopHwnds $p
  $hMenu = Open-RelMenu $hMapa
  [void](Click-MenuItem $hMenu 'abrir editor')
  $hEd = [IntPtr]::Zero
  $t0 = Get-Date
  while (((Get-Date) - $t0).TotalSeconds -lt 12) {
    $hEd = Find-NewWinEx $p $antes
    if ($hEd -ne [IntPtr]::Zero) { break }
    Start-Sleep -Milliseconds 400
  }
  if ($hEd -eq [IntPtr]::Zero) { throw "editor nao abriu ($onde)" }
  if ([ERPUI]::WinClass($hEd) -eq '#32770') {
    $t = ''
    try { $t = Get-DialogText $hEd } catch { }
    throw "editor NAO abriu ($onde); dialogo exibido: $t"
  }
  return $hEd
}

$hEd = Abrir-Editor '1a abertura'
$titulo = [ERPUI]::WinTitle($hEd)
"  editor: hwnd=$($hEd.ToInt64().ToString('X')) titulo='$titulo'"
if ($titulo -notmatch 'Designer') { throw "janela nova nao e o designer: '$titulo'" }
Start-Sleep -Milliseconds 1500
Force-Foreground $hEd
Start-Sleep -Milliseconds 500
Shot-Win $hEd "$EV\fase6_06_editor_talao.png"
"OK [editor do talao aberto]: $titulo"
[ERPUI]::PostMessage($hEd, 0x0010, [IntPtr]0, [IntPtr]0) | Out-Null
Start-Sleep -Seconds 2
if ([ERPUI]::IsWindowVisible($hEd)) { throw 'editor nao fechou com WM_CLOSE' }
'OK [editor fechado]'

# 2a abertura: garante que frDesigner segue valido apos fechar
# (o form some com caHide, nao e destruido — reabrir deve reaparecer)
$hEd2 = Abrir-Editor '2a abertura'
"  editor (reabertura): hwnd=$($hEd2.ToInt64().ToString('X'))"
[ERPUI]::PostMessage($hEd2, 0x0010, [IntPtr]0, [IntPtr]0) | Out-Null
Start-Sleep -Seconds 2
if ([ERPUI]::IsWindowVisible($hEd2)) { throw 'editor (2a abertura) nao fechou com WM_CLOSE' }
'OK [editor reaberto e fechado]'

# abrir/fechar sem editar nao pode tocar nos .lrf
Get-ChildItem $reldir -Filter *.lrf -File | ForEach-Object {
  $agora = (Get-FileHash $_.FullName).Hash
  if ($hashesAntes[$_.FullName] -ne $agora) {
    throw "o editor alterou $($_.Name) sem pedido do usuario"
  }
}
'OK [.lrf intocados apos abrir/fechar o editor]'

"FASE6-01 CONCLUIDO"
