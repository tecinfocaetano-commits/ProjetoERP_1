$path = 'C:\Users\Charles\Documents\ProjetoERP_1\Desktop\bin\relatorios\mapa_1.pdf'
$bytes = [System.IO.File]::ReadAllBytes($path)
$txt = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)
"tamanho: $($bytes.Length) bytes"

function Show-Fr([string]$s, [string]$rotulo) {
  foreach ($busca in @('PRODU', 'Tal', 'Cria', 'Situa', 'C digo', 'oducao')) {
    $i = $s.IndexOf($busca)
    if ($i -ge 0) {
      $ini = [Math]::Max(0, $i - 30)
      $fatia = $s.Substring($ini, [Math]::Min(90, $s.Length - $ini))
      $vis = $fatia -replace '[\x00-\x1F]', '.'
      "[$rotulo] '$busca' em $i =>"
      "  vis: $vis"
      break
    }
  }
}

Show-Fr $txt 'raw'

# operadores de conteudo no cru (stream de pagina nao comprimido?)
foreach ($op in @('BT', 'Tf', 'Tj', 'Td')) {
  $i = $txt.IndexOf($op)
  if ($i -ge 0) {
    $ini = [Math]::Max(0, $i - 20)
    $fatia = $txt.Substring($ini, [Math]::Min(120, $txt.Length - $ini)) -replace '[\x00-\x1F]', '.'
    "[raw] operador '$op' em $i => $fatia"
  } else {
    "[raw] operador '$op' nao encontrado"
  }
}

# streams reais: dicionario >> seguido de stream; FlateDecode = zlib (2 bytes + deflate)
$rx = [regex]'(?s)<<(?<d>[^<>]*)>>\s*stream\r?\n'
$ms = New-Object System.IO.MemoryStream
$n = 0; $ok = 0
foreach ($m in $rx.Matches($txt)) {
  $dict = $m.Groups['d'].Value
  if ($dict -notmatch '/FlateDecode') { continue }
  if ($dict -notmatch '/Length\s+(\d+)') { continue }
  $len = [int]$Matches[1]
  $start = $m.Index + $m.Length
  $n++
  $ms2 = New-Object System.IO.MemoryStream
  $ms2.Write($bytes, $start, $len)
  $ms2.Position = 2   # pula cabecalho zlib (CMF/FLG)
  try {
    $out = New-Object System.IO.MemoryStream
    $df = New-Object System.IO.Compression.DeflateStream($ms2, [System.IO.Compression.CompressionMode]::Decompress)
    $df.CopyTo($out)
    $df.Dispose()
    $ok++
    $infl = [System.Text.Encoding]::GetEncoding(1252).GetString($out.ToArray())
    "--- stream #$n ($len -> $($out.Length) bytes) ---"
    if ($n -eq 1) {
      $cab = $infl.Substring(0, [Math]::Min(500, $infl.Length)) -replace '[\x00-\x1F]', '.'
      "  inicio: $cab"
    }
    if ($n -eq 2) {
      $cab = $infl.Substring(0, [Math]::Min(320, $infl.Length)) -replace '[\x00-\x1F]', '.'
      "  inicio: $cab"
    }
    Show-Fr $infl "s$n"
  } catch { "stream #${n}: falhou inflar ($($_.Exception.Message))" }
}
"streams flate: $n, inflados: $ok"
