<#
  fbquery.ps1 - Executa consultas SOMENTE LEITURA no banco Firebird 2.5 do sistema MEC.

  Protecoes:
    1. So aceita comandos que comecam com SELECT ou WITH.
    2. Bloqueia palavras que alteram dados/estrutura (INSERT, UPDATE, DELETE, ALTER, DROP,
       EXECUTE, GEN_ID, NEXT VALUE FOR, comandos do isql etc.).
    3. Roda tudo dentro de SET TRANSACTION READ ONLY: mesmo uma procedure que tente gravar falha.

  Uso:
    powershell -File fbquery.ps1 -Sql "SELECT FIRST 10 * FROM CLIENTE"
    powershell -File fbquery.ps1 -File consulta.sql [-Plan] [-Stats] [-Database caminho]
    powershell -File fbquery.ps1 -File consulta.sql -Json saida.json   (grava as linhas em JSON, UTF-8)

  Configuracao (variaveis de ambiente do usuario Windows):
    ISC_USER, ISC_PASSWORD  - usuario/senha do Firebird (o ideal e um usuario so com SELECT)
    MEC_FB_DATABASE         - ex.: localhost/3050:C:\MEC\DBS\EMPRESA\DBCIECF.FDB
    MEC_FB_ISQL (opcional)  - caminho do isql.exe do Firebird 2.5
#>
param(
  [string]$Sql,
  [string]$File,
  [string]$Database,
  [switch]$Plan,
  [switch]$Stats,
  [string]$Json
)
$ErrorActionPreference = 'Stop'
function Fail([string]$msg, [int]$code) { [Console]::Error.WriteLine($msg); exit $code }

function Get-Cfg([string]$name) {
  $v = [Environment]::GetEnvironmentVariable($name, 'Process')
  if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, 'User') }
  if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, 'Machine') }
  return $v
}

# ---------- entrada ----------
if ($File) { $Sql = [IO.File]::ReadAllText((Resolve-Path $File), [Text.Encoding]::GetEncoding(1252)) }
if (-not $Sql -or -not $Sql.Trim()) { Fail 'Informe -Sql ou -File.' 2 }

# ---------- validacao somente leitura ----------
# Remove comentarios e literais de texto antes de procurar palavras proibidas.
$clean = [regex]::Replace($Sql, '/\*.*?\*/', ' ', 'Singleline')
$clean = [regex]::Replace($clean, '--[^\r\n]*', ' ')
$clean = [regex]::Replace($clean, "'(?:[^']|'')*'", "''")
$clean = [regex]::Replace($clean, '"(?:[^"]|"")*"', '"x"')

$proibidas = 'INSERT|UPDATE|DELETE|MERGE|UPSERT|ALTER|CREATE|RECREATE|DROP|TRUNCATE|EXECUTE|EXEC|GRANT|REVOKE|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|SET|DECLARE|COMMENT|CONNECT|DISCONNECT|SHELL|INPUT|OUTPUT|EDIT|GEN_ID|NEXT\s+VALUE|GENERATOR|SEQUENCE|RDB\$SET_CONTEXT|POST_EVENT|IN\s+AUTONOMOUS|WITH\s+LOCK|FOR\s+UPDATE|BLOCK|SUSPEND|TERM'
$m = [regex]::Match($clean, "(?i)\b($proibidas)\b")
if ($m.Success) {
  Fail "BLOQUEADO: este skill e somente leitura. Palavra nao permitida: '$($m.Value.ToUpper())'." 3
}
$stmts = $clean -split ';' | Where-Object { $_.Trim() }
foreach ($s in $stmts) {
  if ($s.Trim() -notmatch '(?i)^\(?\s*(SELECT|WITH)\b') {
    $ini = ($s.Trim() -split '\s+')[0]
    Fail "BLOQUEADO: so sao permitidos comandos SELECT/WITH. Encontrado: '$ini'." 3
  }
}
if ($Json -and @($stmts).Count -ne 1) { Fail 'Com -Json envie exatamente uma consulta.' 2 }

# ---------- configuracao ----------
if (-not $Database) { $Database = Get-Cfg 'MEC_FB_DATABASE' }
if (-not $Database) { Fail 'Banco nao configurado. Defina MEC_FB_DATABASE ou use -Database.' 2 }
$isql = Get-Cfg 'MEC_FB_ISQL'
if (-not $isql) { $isql = 'C:\Program Files\Firebird\Firebird_2_5\bin\isql.exe' }
if (-not (Test-Path $isql)) { Fail "isql.exe nao encontrado em '$isql'. Defina MEC_FB_ISQL." 2 }
foreach ($n in 'ISC_USER', 'ISC_PASSWORD') {
  $v = Get-Cfg $n
  if (-not $v) { Fail "Variavel $n nao definida. O usuario deve configura-la (setx $n ...)." 2 }
  Set-Item "env:$n" $v
}

# ---------- execucao em transacao READ ONLY ----------
$hdr = "SET TRANSACTION READ ONLY ISOLATION LEVEL READ COMMITTED RECORD_VERSION;`n"
if ($Json) { $hdr += "SET LIST ON;`nSET BLOB ALL;`n" }
else {
  if ($Plan)  { $hdr += "SET PLAN ON;`n" }
  if ($Stats) { $hdr += "SET STATS ON;`n" }
}
$body = ($Sql.TrimEnd().TrimEnd(';')) + "`n;`n"
$tmp = Join-Path $env:TEMP ("fbquery_{0}.sql" -f [guid]::NewGuid().ToString('N'))
$ErrorActionPreference = 'Continue'   # isql escreve avisos no stderr; nao interromper
$origEnc = [Console]::OutputEncoding
try {
  [IO.File]::WriteAllText($tmp, $hdr + $body + "ROLLBACK;`n", [Text.Encoding]::GetEncoding(1252))
  # isql devolve texto em WIN1252: decodificar como 1252 para manter os acentos
  [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(1252)
  $lines = @(& $isql -q -ch WIN1252 -i $tmp $Database 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -ne 'Rolling back work.' })
  $rc = $LASTEXITCODE
} finally {
  [Console]::OutputEncoding = $origEnc
  Remove-Item $tmp -ErrorAction SilentlyContinue
}

if (-not $Json -or $rc -ne 0) { $lines; exit $rc }

# ---------- conversao SET LIST -> JSON ----------
# Formato do isql: "NOME_COLUNA   valor" por linha, registros separados por linha em branco.
$rows = New-Object System.Collections.ArrayList
$cur = $null
foreach ($ln in $lines) {
  if (-not $ln.Trim()) { if ($cur) { [void]$rows.Add($cur); $cur = $null }; continue }
  $mm = [regex]::Match($ln, '^(\S+)\s+(.*)$')
  $col = if ($mm.Success) { $mm.Groups[1].Value } else { $ln.Trim() }
  $val = if ($mm.Success) { $mm.Groups[2].Value.TrimEnd() } else { '' }
  if (-not $cur) { $cur = [ordered]@{} }
  if ($val -eq '<null>') { $v = $null }
  elseif ($val -match '^-?\d+(\.\d+)?$' -and $val -notmatch '^0\d') { $v = [decimal]::Parse($val, [Globalization.CultureInfo]::InvariantCulture) }
  else { $v = $val }
  $cur[$col] = $v
}
if ($cur) { [void]$rows.Add($cur) }
$out = ConvertTo-Json -InputObject @($rows) -Depth 4
if ($rows.Count -eq 0) { $out = '[]' }
[IO.File]::WriteAllText($Json, $out, (New-Object Text.UTF8Encoding($false)))
"OK: $($rows.Count) linha(s) gravada(s) em $Json"
exit 0
