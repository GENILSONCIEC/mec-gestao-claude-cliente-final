<#
  gerar_relatorio.ps1 - Gera relatorio em PDF no padrao visual Mec Gestao (cabecalho da FILIAL,
  faixa de titulo, tabela, graficos e rodape com paginacao) usando o Microsoft Edge.

  Uso:
    powershell -NoProfile -File gerar_relatorio.ps1 -Spec relatorio.json

  A especificacao (JSON, UTF-8) - veja references/relatorio-pdf.md para todos os campos:
  {
    "titulo": "PRODUTOS MAIS VENDIDOS",
    "filial": 1,
    "filtro": "Filtrado por Data: 01/09/2026 ate o dia 30/09/2026",
    "orientacao": "retrato",
    "sql": "SELECT ...",                (ou "dados": "arquivo.json", ou "linhas": [ ... ])
    "colunas": [ {"campo":"PRODUTO","titulo":"Produto","tipo":"texto"},
                 {"campo":"VALOR","titulo":"Valor","tipo":"moeda","total":true} ],
    "totais": true,
    "resumo": [ {"rotulo":"Total vendido","valor":12345.6,"tipo":"moeda"} ],
    "graficos": [ {"tipo":"barras","titulo":"Top 10 por valor","rotulo":"PRODUTO","valores":["VALOR"],"limite":10,"formato":"moeda"} ],
    "saida": "C:\\caminho\\arquivo.pdf"
  }
  Todas as consultas passam por fbquery.ps1 (somente leitura).
#>
param([Parameter(Mandatory = $true)][string]$Spec)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$fbquery = Join-Path $here 'fbquery.ps1'
$pt = [Globalization.CultureInfo]::GetCultureInfo('pt-BR')
$inv = [Globalization.CultureInfo]::InvariantCulture

function Fail([string]$m) { [Console]::Error.WriteLine($m); exit 2 }
function Esc([object]$s) { if ($null -eq $s) { return '' }; return [Net.WebUtility]::HtmlEncode([string]$s) }
function Num([object]$v) {
  if ($null -eq $v -or "$v" -eq '') { return $null }
  if ($v -is [string]) { $d = 0.0; if ([double]::TryParse($v, [Globalization.NumberStyles]::Any, $inv, [ref]$d)) { return $d }; return $null }
  return [double]$v
}
function Fmt([object]$v, [string]$tipo, $dec) {
  if ($null -eq $v -or "$v" -eq '') { return '' }
  switch ($tipo) {
    'moeda'      { $n = Num $v; if ($null -eq $n) { return Esc $v }; $d = 2; if ($null -ne $dec) { $d = [int]$dec }; return $n.ToString("N$d", $pt) }
    'numero'     { $n = Num $v; if ($null -eq $n) { return Esc $v }; $d = 2; if ($null -ne $dec) { $d = [int]$dec }; return $n.ToString("N$d", $pt) }
    'inteiro'    { $n = Num $v; if ($null -eq $n) { return Esc $v }; return $n.ToString('N0', $pt) }
    'percentual' { $n = Num $v; if ($null -eq $n) { return Esc $v }; $d = 2; if ($null -ne $dec) { $d = [int]$dec }; return $n.ToString("N$d", $pt) }
    'data'       {
      $s = "$v"; if ($s -match '^1899-12-30') { return '' }
      $dt = [datetime]::MinValue
      if ([datetime]::TryParse($s, $inv, [Globalization.DateTimeStyles]::None, [ref]$dt)) { return $dt.ToString('dd/MM/yyyy') }
      return Esc $s }
    default      { return Esc ("$v".Trim()) }
  }
}
function Compact([double]$n, [string]$fmt) {
  $a = [math]::Abs($n); $p = ''; if ($fmt -eq 'moeda') { $p = 'R$ ' }
  if ($a -ge 1e9) { return $p + ($n / 1e9).ToString('0.#', $pt) + ' bi' }
  if ($a -ge 1e6) { return $p + ($n / 1e6).ToString('0.#', $pt) + ' mi' }
  if ($a -ge 1e3) { return $p + ($n / 1e3).ToString('0.#', $pt) + ' mil' }
  if ($fmt -eq 'moeda') { return $p + $n.ToString('N2', $pt) }
  return $n.ToString('0.##', $pt)
}
function FmtVal([double]$n, [string]$fmt) {
  switch ($fmt) { 'moeda' { return 'R$ ' + $n.ToString('N2', $pt) } 'percentual' { return $n.ToString('N2', $pt) + '%' } 'inteiro' { return $n.ToString('N0', $pt) } default { return $n.ToString('N2', $pt) } }
}
function NiceMax([double]$m) {
  if ($m -le 0) { return 1 }
  $e = [math]::Pow(10, [math]::Floor([math]::Log10($m))); $f = $m / $e
  foreach ($s in 1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10) { if ($f -le $s) { return $s * $e } }
  return 10 * $e
}
function Get-Prop($o, [string]$n) { if ($null -eq $o) { return $null }; $p = $o.PSObject.Properties[$n]; if ($p) { return $p.Value }; return $null }
function Read-JsonRows([string]$path) {
  $j = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  $list = New-Object System.Collections.ArrayList
  foreach ($x in $j) { foreach ($y in @($x)) { [void]$list.Add($y) } }
  return ,$list.ToArray()
}
function Run-Query([string]$sql) {
  $tmpSql = Join-Path $env:TEMP ("rel_{0}.sql" -f [guid]::NewGuid().ToString('N'))
  $tmpJson = [IO.Path]::ChangeExtension($tmpSql, '.json')
  [IO.File]::WriteAllText($tmpSql, $sql, [Text.Encoding]::GetEncoding(1252))
  $ErrorActionPreference = 'Continue'
  $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $fbquery -File $tmpSql -Json $tmpJson 2>&1 | ForEach-Object { "$_" }
  $ErrorActionPreference = 'Stop'
  Remove-Item $tmpSql -ErrorAction SilentlyContinue
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmpJson)) { Fail ("Erro na consulta:`n" + ($o -join "`n")) }
  $d = Get-Content $tmpJson -Raw -Encoding UTF8 | ConvertFrom-Json
  Remove-Item $tmpJson -ErrorAction SilentlyContinue
  return @($d)
}

# ---------- cores (padrao Mec Gestao; paleta de graficos validada p/ daltonismo) ----------
$SERIES = @('#0087ad', '#f09a2c', '#4a3aa7', '#e34948', '#008300', '#e87ba4')
$BRAND = '#10869f'; $BRAND_DARK = '#0b6d82'; $ORANGE = '#f09a2c'

# ---------- especificacao ----------
$cfg = Get-Content $Spec -Raw -Encoding UTF8 | ConvertFrom-Json
$titulo = [string](Get-Prop $cfg 'titulo'); if (-not $titulo) { Fail 'Spec sem "titulo".' }
$cols = @(Get-Prop $cfg 'colunas')
$linhas = @()
if (Get-Prop $cfg 'sql') { $linhas = @(Run-Query ([string](Get-Prop $cfg 'sql'))) }
elseif (Get-Prop $cfg 'dados') { $linhas = @(Read-JsonRows ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([string](Get-Prop $cfg 'dados')))) }
elseif (Get-Prop $cfg 'linhas') { $linhas = @(Get-Prop $cfg 'linhas') }
if ($cols.Count -eq 0 -and $linhas.Count -gt 0) {
  $cols = @($linhas[0].PSObject.Properties | Where-Object { $_.Name -ne '_estilo' } | ForEach-Object { [pscustomobject]@{ campo = $_.Name; titulo = $_.Name; tipo = $(if ($_.Value -is [decimal] -or $_.Value -is [double] -or $_.Value -is [int]) { 'numero' } else { 'texto' }) } })
}

# ---------- cabecalho: FILIAL (somente colunas publicas) ----------
$fil = Get-Prop $cfg 'filial'
$where = if ($null -ne $fil -and "$fil" -ne '') { "WHERE FIL_CODIGO = $([int]$fil)" } else { 'ORDER BY FIL_CODIGO' }
$fq = @(Run-Query "SELECT FIRST 1 FIL_CODIGO, TRIM(FIL_RAZAO) AS RAZAO, TRIM(FIL_FANTA) AS FANTASIA, TRIM(FIL_CNPJ) AS CNPJ, TRIM(FIL_IESTADUAL) AS IE, TRIM(FIL_ENDERECO) AS ENDERECO, TRIM(FIL_NUMERO) AS NUMERO, TRIM(FIL_BAIRRO) AS BAIRRO, TRIM(FIL_CIDADE) AS CIDADE, TRIM(FIL_ESTADO) AS UF, TRIM(FIL_CEP) AS CEP, TRIM(FIL_FONE) AS FONE, TRIM(FIL_EMAIL) AS EMAIL FROM FILIAL $where")
$F = if ($fq.Count) { $fq[0] } else { $null }
$razao = Get-Prop $F 'RAZAO'; $cnpj = Get-Prop $F 'CNPJ'
$end = (@((Get-Prop $F 'ENDERECO'), (Get-Prop $F 'NUMERO')) | Where-Object { $_ }) -join ', '
$end2 = (@((Get-Prop $F 'BAIRRO'), ((@((Get-Prop $F 'CIDADE'), (Get-Prop $F 'UF')) | Where-Object { $_ }) -join '/'), $(if (Get-Prop $F 'CEP') { 'CEP ' + (Get-Prop $F 'CEP') })) | Where-Object { $_ }) -join ' - '
if ($end2) { $end = (@($end, $end2) | Where-Object { $_ }) -join ' - ' }

$agora = Get-Date
$emitido = $agora.ToString('dd/MM/yyyy - HH:mm:ss')

# ---------- graficos SVG ----------
function Svg-Bars($g, $rows) {
  $lab = [string](Get-Prop $g 'rotulo'); $vals = @(Get-Prop $g 'valores'); $fmt = [string](Get-Prop $g 'formato')
  $nomes = @(Get-Prop $g 'series'); if ($nomes.Count -lt $vals.Count) { $nomes = $vals }
  $W = 700; $labW = 230; $valW = 100; $plotW = $W - $labW - $valW
  $nS = $vals.Count; $barH = if ($nS -gt 1) { 11 } else { 16 }; $gap = 2; $rowH = $nS * $barH + ($nS - 1) * $gap + 12
  $max = 0.0; foreach ($r in $rows) { foreach ($v in $vals) { $n = Num (Get-Prop $r $v); if ($n -gt $max) { $max = $n } } }
  $nice = NiceMax $max
  $legH = if ($nS -gt 1) { 24 } else { 0 }
  $H = $legH + $rows.Count * $rowH + 26
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<svg viewBox='0 0 $W $H' width='100%' xmlns='http://www.w3.org/2000/svg' font-family='Arial, sans-serif' role='img'>")
  if ($nS -gt 1) { $x = $labW; for ($i = 0; $i -lt $nS; $i++) { [void]$sb.Append("<rect x='$x' y='4' width='12' height='12' rx='2' fill='$($SERIES[$i])'/><text x='$($x+17)' y='14' font-size='11' fill='#333'>$(Esc $nomes[$i])</text>"); $x += 30 + 7 * ([string]$nomes[$i]).Length } }
  $top = $legH; $bottom = $top + $rows.Count * $rowH
  for ($t = 0; $t -le 4; $t++) { $xv = $labW + $plotW * $t / 4; $tv = $nice * $t / 4
    [void]$sb.Append("<line x1='$xv' y1='$top' x2='$xv' y2='$bottom' stroke='#e3e3e3' stroke-width='1'/><text x='$xv' y='$($bottom+15)' font-size='10' fill='#777' text-anchor='middle'>$(Esc (Compact $tv $fmt))</text>") }
  [void]$sb.Append("<line x1='$labW' y1='$top' x2='$labW' y2='$bottom' stroke='#9a9a9a' stroke-width='1'/>")
  $y = $top + 6
  foreach ($r in $rows) {
    $txt = [string](Get-Prop $r $lab); $txt = $txt.Trim(); if ($txt.Length -gt 30) { $txt = $txt.Substring(0, 29) + '…' }
    [void]$sb.Append("<text x='$($labW-8)' y='$($y + ($rowH-12)/2 + 4)' font-size='10' fill='#222' text-anchor='end'>$(Esc $txt)</text>")
    for ($i = 0; $i -lt $nS; $i++) {
      $n = Num (Get-Prop $r $vals[$i]); if ($null -eq $n) { $n = 0 }
      $w = [math]::Max(0, $plotW * $n / $nice); $by = $y + $i * ($barH + $gap)
      if ($w -gt 4) { [void]$sb.Append("<path d='M$labW,$by h$($w-4) a4,4 0 0 1 4,4 v$($barH-8) a4,4 0 0 1 -4,4 h-$($w-4) z' fill='$($SERIES[$i])'/>") }
      elseif ($w -gt 0) { [void]$sb.Append("<rect x='$labW' y='$by' width='$w' height='$barH' fill='$($SERIES[$i])'/>") }
      [void]$sb.Append("<text x='$($labW + $w + 5)' y='$($by + $barH/2 + 4)' font-size='10' fill='#333'>$(Esc (FmtVal $n $fmt))</text>")
    }
    $y += $rowH
  }
  [void]$sb.Append('</svg>'); return $sb.ToString()
}

function Svg-Columns($g, $rows, [bool]$line) {
  $lab = [string](Get-Prop $g 'rotulo'); $vals = @(Get-Prop $g 'valores'); $fmt = [string](Get-Prop $g 'formato')
  $nomes = @(Get-Prop $g 'series'); if ($nomes.Count -lt $vals.Count) { $nomes = $vals }
  $W = 700; $H = 300; $mL = 64; $mR = 16; $mT = 30; $mB = 48
  $pw = $W - $mL - $mR; $ph = $H - $mT - $mB; $n = $rows.Count; if ($n -eq 0) { return '' }
  $nS = $vals.Count
  $max = 0.0; $min = 0.0
  foreach ($r in $rows) { foreach ($v in $vals) { $x = Num (Get-Prop $r $v); if ($x -gt $max) { $max = $x }; if ($x -lt $min) { $min = $x } } }
  $nice = NiceMax $max; $lo = if ($min -lt 0) { - (NiceMax (-$min)) } else { 0 }
  $span = $nice - $lo
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<svg viewBox='0 0 $W $H' width='100%' xmlns='http://www.w3.org/2000/svg' font-family='Arial, sans-serif' role='img'>")
  if ($nS -gt 1) { $x = $mL; for ($i = 0; $i -lt $nS; $i++) { [void]$sb.Append("<rect x='$x' y='6' width='12' height='12' rx='2' fill='$($SERIES[$i])'/><text x='$($x+17)' y='16' font-size='11' fill='#333'>$(Esc $nomes[$i])</text>"); $x += 30 + 7 * ([string]$nomes[$i]).Length } }
  for ($t = 0; $t -le 4; $t++) { $tv = $lo + $span * $t / 4; $yv = $mT + $ph - $ph * ($tv - $lo) / $span
    [void]$sb.Append("<line x1='$mL' y1='$yv' x2='$($W-$mR)' y2='$yv' stroke='#e3e3e3' stroke-width='1'/><text x='$($mL-6)' y='$($yv+3.5)' font-size='10' fill='#777' text-anchor='end'>$(Esc (Compact $tv $fmt))</text>") }
  $y0 = $mT + $ph - $ph * (0 - $lo) / $span
  [void]$sb.Append("<line x1='$mL' y1='$y0' x2='$($W-$mR)' y2='$y0' stroke='#9a9a9a' stroke-width='1'/>")
  $step = $pw / $n
  $every = [math]::Max(1, [math]::Ceiling($n / 14))
  for ($k = 0; $k -lt $n; $k++) {
    if ($k % $every -eq 0 -or $k -eq $n - 1) {
      $txt = [string](Get-Prop $rows[$k] $lab); $txt = $txt.Trim()
      if ($txt -match '^\d{4}-\d{2}-\d{2}') { $txt = ([datetime]::Parse($txt.Substring(0, 10), $inv)).ToString('dd/MM') }
      if ($txt.Length -gt 12) { $txt = $txt.Substring(0, 11) + '…' }
      [void]$sb.Append("<text x='$($mL + $step*$k + $step/2)' y='$($mT+$ph+16)' font-size='10' fill='#555' text-anchor='middle'>$(Esc $txt)</text>")
    }
  }
  $showAll = ($n * $nS -le 12)
  for ($i = 0; $i -lt $nS; $i++) {
    $pts = @(); $vs = @()
    for ($k = 0; $k -lt $n; $k++) { $v = Num (Get-Prop $rows[$k] $vals[$i]); if ($null -eq $v) { $v = 0 }; $vs += $v }
    $imax = 0; for ($k = 1; $k -lt $n; $k++) { if ($vs[$k] -gt $vs[$imax]) { $imax = $k } }
    for ($k = 0; $k -lt $n; $k++) {
      $v = $vs[$k]; $yv = $mT + $ph - $ph * ($v - $lo) / $span
      if ($line) {
        $cx = $mL + $step * $k + $step / 2; $pts += ('{0},{1}' -f $cx.ToString($inv), $yv.ToString($inv))
      } else {
        $gw = $step * 0.72; $bw = ($gw - ($nS - 1) * 2) / $nS; $bx = $mL + $step * $k + ($step - $gw) / 2 + $i * ($bw + 2)
        $top = [math]::Min($yv, $y0); $hh = [math]::Abs($y0 - $yv)
        if ($hh -gt 4 -and $v -ge 0) { [void]$sb.Append("<path d='M$bx,$y0 v-$($hh-4) a4,4 0 0 1 4,-4 h$($bw-8) a4,4 0 0 1 4,4 v$($hh-4) z' fill='$($SERIES[$i])'/>") }
        elseif ($hh -gt 0) { [void]$sb.Append("<rect x='$bx' y='$top' width='$bw' height='$hh' fill='$($SERIES[$i])'/>") }
        if ($showAll -or $k -eq $imax -or $k -eq $n - 1) { [void]$sb.Append("<text x='$($bx + $bw/2)' y='$($top - 4)' font-size='9.5' fill='#333' text-anchor='middle'>$(Esc (Compact $v $fmt))</text>") }
      }
    }
    if ($line) {
      [void]$sb.Append("<polyline points='$($pts -join ' ')' fill='none' stroke='$($SERIES[$i])' stroke-width='2' stroke-linejoin='round'/>")
      $marcar = @($imax); if ($i -eq 0 -and ($n - 1) -ne $imax) { $marcar += ($n - 1) }
      foreach ($k in $marcar) { if ($vs[$k] -eq 0) { continue }
        $p = $pts[$k] -split ','; [void]$sb.Append("<circle cx='$($p[0])' cy='$($p[1])' r='4' fill='$($SERIES[$i])' stroke='#fff' stroke-width='2'/><text x='$($p[0])' y='$([double]::Parse($p[1],$inv) - 9)' font-size='9.5' fill='#333' text-anchor='middle'>$(Esc (Compact $vs[$k] $fmt))</text>")
      }
    }
  }
  [void]$sb.Append('</svg>'); return $sb.ToString()
}

function Svg-Pie($g, $rows) {
  $lab = [string](Get-Prop $g 'rotulo'); $val = [string](@(Get-Prop $g 'valores')[0]); $fmt = [string](Get-Prop $g 'formato')
  $items = @($rows | ForEach-Object { [pscustomobject]@{ l = ([string](Get-Prop $_ $lab)).Trim(); v = [double](Num (Get-Prop $_ $val)) } } | Where-Object { $_.v -gt 0 } | Sort-Object v -Descending)
  if ($items.Count -gt 6) { $rest = ($items[5..($items.Count - 1)] | Measure-Object v -Sum).Sum; $items = @($items[0..4]) + [pscustomobject]@{ l = 'Outros'; v = $rest } }
  $tot = ($items | Measure-Object v -Sum).Sum; if (-not $tot) { return '' }
  $W = 700; $H = 240; $cx = 130; $cy = 120; $R = 100; $r0 = 58
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<svg viewBox='0 0 $W $H' width='100%' xmlns='http://www.w3.org/2000/svg' font-family='Arial, sans-serif' role='img'>")
  $a = -[math]::PI / 2
  for ($i = 0; $i -lt $items.Count; $i++) {
    $fr = $items[$i].v / $tot; $a2 = $a + 2 * [math]::PI * $fr; $large = if ($fr -gt 0.5) { 1 } else { 0 }
    $c = if ($items[$i].l -eq 'Outros') { '#9a9a9a' } else { $SERIES[$i] }
    if ($fr -ge 0.9999) { [void]$sb.Append("<circle cx='$cx' cy='$cy' r='$(($R+$r0)/2)' fill='none' stroke='$c' stroke-width='$($R-$r0)'/>") }
    else {
      $p = @(($cx + $R * [math]::Cos($a)), ($cy + $R * [math]::Sin($a)), ($cx + $R * [math]::Cos($a2)), ($cy + $R * [math]::Sin($a2)), ($cx + $r0 * [math]::Cos($a2)), ($cy + $r0 * [math]::Sin($a2)), ($cx + $r0 * [math]::Cos($a)), ($cy + $r0 * [math]::Sin($a))) | ForEach-Object { ([double]$_).ToString('0.##', $inv) }
      [void]$sb.Append("<path d='M$($p[0]),$($p[1]) A$R,$R 0 $large 1 $($p[2]),$($p[3]) L$($p[4]),$($p[5]) A$r0,$r0 0 $large 0 $($p[6]),$($p[7]) Z' fill='$c' stroke='#fff' stroke-width='2'/>")
    }
    $ly = 30 + $i * 30
    [void]$sb.Append("<rect x='270' y='$($ly-10)' width='12' height='12' rx='2' fill='$c'/><text x='290' y='$ly' font-size='11.5' fill='#222'>$(Esc $(if ($items[$i].l.Length -gt 38) { $items[$i].l.Substring(0,37) + '…' } else { $items[$i].l }))</text><text x='690' y='$ly' font-size='11.5' fill='#333' text-anchor='end'>$(Esc (FmtVal $items[$i].v $fmt))   $(($fr*100).ToString('N1',$pt))%</text>")
    $a = $a2
  }
  [void]$sb.Append("<text x='$cx' y='$($cy-2)' font-size='10' fill='#777' text-anchor='middle'>Total</text><text x='$cx' y='$($cy+14)' font-size='12' font-weight='bold' fill='#222' text-anchor='middle'>$(Esc (Compact $tot $fmt))</text>")
  [void]$sb.Append('</svg>'); return $sb.ToString()
}

$graficosHtml = ''
foreach ($g in @(Get-Prop $cfg 'graficos')) {
  if (-not $g) { continue }
  $rows = $linhas | Where-Object { -not (Get-Prop $_ '_estilo') -or (Get-Prop $_ '_estilo') -eq 'normal' }
  $lim = Get-Prop $g 'limite'; if ($lim) { $rows = @($rows | Select-Object -First ([int]$lim)) } else { $rows = @($rows) }
  $tipo = [string](Get-Prop $g 'tipo')
  $svg = switch ($tipo) { 'barras' { Svg-Bars $g $rows } 'colunas' { Svg-Columns $g $rows $false } 'linha' { Svg-Columns $g $rows $true } 'pizza' { Svg-Pie $g $rows } default { Fail "Tipo de grafico invalido: $tipo" } }
  $graficosHtml += "<div class='chart'><div class='chart-t'>$(Esc (Get-Prop $g 'titulo'))</div>$svg</div>"
}

# ---------- resumo (cartoes) ----------
$resumoHtml = ''
$res = @(Get-Prop $cfg 'resumo')
if ($res.Count -and $res[0]) {
  $resumoHtml = "<div class='kpis'>" + (($res | ForEach-Object { $n = Num (Get-Prop $_ 'valor'); $t = [string](Get-Prop $_ 'tipo'); $vtxt = if ($null -ne $n) { FmtVal $n $t } else { [string](Get-Prop $_ 'valor') }; "<div class='kpi'><div class='kpi-l'>$(Esc (Get-Prop $_ 'rotulo'))</div><div class='kpi-v'>$(Esc $vtxt)</div></div>" }) -join '') + "</div>"
}

# ---------- tabela ----------
$tabelaHtml = ''
if ($cols.Count -and (Get-Prop $cfg 'tabela') -ne $false) {
  $sb = New-Object Text.StringBuilder
  [void]$sb.Append("<table class='dados'><thead><tr>")
  foreach ($c in $cols) { $al = if ((Get-Prop $c 'tipo') -in 'moeda', 'numero', 'inteiro', 'percentual') { 'r' } elseif ((Get-Prop $c 'tipo') -eq 'data') { 'c' } else { '' }; $w = Get-Prop $c 'largura'; $ws = if ($w) { " style='width:$w'" } else { '' }; [void]$sb.Append("<th class='$al'$ws>$(Esc (Get-Prop $c 'titulo'))</th>") }
  [void]$sb.Append('</tr></thead><tbody>')
  $sum = @{}
  foreach ($r in $linhas) {
    $est = [string](Get-Prop $r '_estilo'); $cls = if ($est -in 'grupo', 'subgrupo', 'total') { " class='$est'" } else { '' }
    [void]$sb.Append("<tr$cls>")
    foreach ($c in $cols) {
      $tp = [string](Get-Prop $c 'tipo'); $v = Get-Prop $r (Get-Prop $c 'campo')
      $al = if ($tp -in 'moeda', 'numero', 'inteiro', 'percentual') { 'r' } elseif ($tp -eq 'data') { 'c' } else { '' }
      [void]$sb.Append("<td class='$al'>$(Fmt $v $tp (Get-Prop $c 'decimais'))</td>")
      if ((Get-Prop $c 'total') -and (-not $est -or $est -eq 'normal')) { $n = Num $v; if ($null -ne $n) { $sum[(Get-Prop $c 'campo')] = [double]$sum[(Get-Prop $c 'campo')] + $n } }
    }
    [void]$sb.Append('</tr>')
  }
  [void]$sb.Append('</tbody>')
  if ((Get-Prop $cfg 'totais') -and $linhas.Count) {
    [void]$sb.Append("<tfoot><tr>")
    $first = $true
    foreach ($c in $cols) {
      $tp = [string](Get-Prop $c 'tipo')
      if ((Get-Prop $c 'total')) { [void]$sb.Append("<td class='r'>$(Fmt $sum[(Get-Prop $c 'campo')] $tp (Get-Prop $c 'decimais'))</td>") }
      elseif ($first) { [void]$sb.Append("<td>TOTAL ($($linhas.Count))</td>") }
      else { [void]$sb.Append('<td></td>') }
      $first = $false
    }
    [void]$sb.Append('</tr></tfoot>')
  }
  [void]$sb.Append('</table>')
  $tabelaHtml = $sb.ToString()
}
$semDados = if ($linhas.Count -eq 0) { "<p class='vazio'>Nenhum registro encontrado para os filtros informados.</p>" } else { '' }

# ---------- montagem HTML ----------
$orient = if ((Get-Prop $cfg 'orientacao') -eq 'paisagem') { 'A4 landscape' } else { 'A4 portrait' }
$conteudo = if ((Get-Prop $cfg 'grafico_depois')) { $resumoHtml + $tabelaHtml + $graficosHtml } else { $resumoHtml + $graficosHtml + $tabelaHtml }
$filtroTxt = [string](Get-Prop $cfg 'filtro')
$html = @"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>$(Esc $titulo)</title>
<style>
@page { size: $orient; margin: 10mm 9mm 16mm 9mm;
  @bottom-left { content: "$emitido"; font: bold 8.5pt Arial; color: #333; }
  @bottom-center { content: "Mec Gest\00E3o"; font: bold 8.5pt Arial; color: $BRAND_DARK; }
  @bottom-right { content: "P\00E1g. " counter(page) " / " counter(pages); font: 8.5pt Arial; color: #333; }
}
* { box-sizing: border-box; }
body { margin: 0; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; color: #111; background: #fff;
  -webkit-print-color-adjust: exact; print-color-adjust: exact; }
table.pagina { width: 100%; border-collapse: collapse; }
.cab { border-bottom: 3px solid $ORANGE; padding: 0 2px 6px; }
.cab .emp { font-size: 15pt; font-weight: bold; color: $BRAND_DARK; margin: 0 0 4px; }
.cab .emp span { color: #111; }
.cab .lin { display: flex; gap: 28px; font-size: 8.5pt; margin-top: 2px; }
.cab b { color: #111; }
.titulo { background: $BRAND; color: #fff; text-align: center; font-weight: bold; font-size: 12pt; padding: 5px 0; margin-top: 8px; letter-spacing: .3px; }
.filtro { display: flex; justify-content: space-between; font-size: 8.5pt; padding: 4px 2px 8px; }
.kpis { display: flex; gap: 8px; margin: 2px 0 10px; }
.kpi { flex: 1; border: 1px solid #cfdfe3; border-left: 4px solid $BRAND; padding: 6px 10px; }
.kpi-l { font-size: 8pt; color: #555; text-transform: uppercase; }
.kpi-v { font-size: 14pt; font-weight: bold; color: #111; margin-top: 2px; }
.chart { border: 1px solid #d6e2e5; padding: 8px 10px 4px; margin: 0 0 10px; break-inside: avoid; }
.chart-t { font-weight: bold; font-size: 10pt; color: $BRAND_DARK; margin-bottom: 4px; }
table.dados { width: 100%; border-collapse: collapse; font-size: 8.5pt; font-variant-numeric: tabular-nums; }
table.dados th { background: $BRAND; color: #fff; text-align: left; padding: 4px 5px; border: 1px solid $BRAND_DARK; font-weight: bold; }
table.dados td { padding: 2.5px 5px; border: 1px solid #b9c9cd; }
table.dados tr { break-inside: avoid; }
table.dados .r { text-align: right; } table.dados .c { text-align: center; }
table.dados tr.grupo td { background: #dcebef; font-weight: bold; font-size: 10pt; }
table.dados tr.subgrupo td { font-weight: bold; }
table.dados tr.total td, table.dados tfoot td { background: #fdf0de; font-weight: bold; border-top: 2px solid $ORANGE; }
table.dados tfoot { display: table-row-group; }
.vazio { text-align: center; padding: 30px; color: #666; }
</style></head><body>
<table class="pagina"><thead><tr><td>
  <div class="cab">
    <div class="emp">$(Esc $razao) <span>| $(Esc $cnpj)</span></div>
    <div class="lin"><div><b>Telefone.:</b> $(Esc (Get-Prop $F 'FONE'))</div><div><b>Email.:</b> $(Esc (Get-Prop $F 'EMAIL'))</div></div>
    <div class="lin"><div><b>Endere&ccedil;o.:</b> $(Esc $end)</div></div>
  </div>
  <div class="titulo">$(Esc $titulo.ToUpper())</div>
  <div class="filtro"><div>$(Esc $filtroTxt)</div><div><b>Emitido em:</b> $emitido</div></div>
</td></tr></thead>
<tbody><tr><td>
$conteudo
$semDados
</td></tr></tbody></table>
</body></html>
"@

# ---------- PDF ----------
$saida = [string](Get-Prop $cfg 'saida')
if (-not $saida) {
  $dir = [Environment]::GetEnvironmentVariable('MEC_RELATORIOS_DIR', 'User')
  if (-not $dir) { $dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Relatorios MEC' }
  $nome = ($titulo -replace '[\\/:*?"<>|]', '' -replace '\s+', '_')
  $saida = Join-Path $dir ("{0}_{1}.pdf" -f $nome, $agora.ToString('yyyyMMdd_HHmmss'))
}
$saida = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($saida)
$saidaDir = Split-Path -Parent $saida; if ($saidaDir -and -not (Test-Path $saidaDir)) { New-Item -ItemType Directory -Force $saidaDir | Out-Null }
$htmlPath = [IO.Path]::ChangeExtension($saida, '.html')
[IO.File]::WriteAllText($htmlPath, $html, (New-Object Text.UTF8Encoding($false)))

$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { Fail "Microsoft Edge nao encontrado. O HTML foi salvo em: $htmlPath" }
$prof = Join-Path $env:TEMP 'mec_relatorio_edge'
$uri = ([Uri]$htmlPath).AbsoluteUri
$ErrorActionPreference = 'Continue'
if (Test-Path $saida) { Remove-Item $saida -Force }
$edgeArgs = @('--headless', '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--disable-extensions',
  '--disable-background-networking', '--disable-component-update', '--disable-sync', '--no-pdf-header-footer',
  "`"--user-data-dir=$prof`"", "`"--print-to-pdf=$saida`"", "`"$uri`"")
$proc = Start-Process -FilePath $edge -ArgumentList $edgeArgs -PassThru -WindowStyle Hidden
# espera o PDF aparecer e estabilizar (no maximo 90 s); o Edge as vezes nao encerra sozinho
$ok = $false; $last = -1
for ($i = 0; $i -lt 180; $i++) {
  Start-Sleep -Milliseconds 500
  if (Test-Path $saida) { $len = (Get-Item $saida).Length; if ($len -gt 0 -and $len -eq $last) { $ok = $true; break }; $last = $len }
  elseif ($proc.HasExited) { break }
}
# encerra apenas os processos do Edge que usam o perfil temporario deste gerador
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like "*$prof*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if (-not $ok) { Fail "Falha ao gerar o PDF. HTML em: $htmlPath" }
if (-not (Get-Prop $cfg 'manter_html')) { Remove-Item $htmlPath -ErrorAction SilentlyContinue }
"PDF gerado: $saida"
"Linhas: $($linhas.Count)"
exit 0
