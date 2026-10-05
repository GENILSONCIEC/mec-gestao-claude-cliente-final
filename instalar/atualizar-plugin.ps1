<#
  Atualização silenciosa do plugin Mec Gestão no Claude.
  Executado pela tarefa agendada "MecGestao - Atualizar plugin Claude" (ao entrar no Windows e a cada 4 horas).
  Usa o Claude Code que acompanha o aplicativo Claude para buscar a versão mais nova no GitHub.
  Registro: %LOCALAPPDATA%\MecGestao\atualizacao.log
#>
$ErrorActionPreference = 'Continue'
$MARKETPLACE = 'mec-gestao-plugins'
$KEY = 'mec-gestao@mec-gestao-plugins'
$REPO = 'GENILSONCIEC/mec-gestao-claude-cliente-final'
$dir = Join-Path $env:LOCALAPPDATA 'MecGestao'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$log = Join-Path $dir 'atualizacao.log'
function Log($t) { Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'), $t) -Encoding UTF8 }
function Run-Claude($exe, [string[]]$argv, [int]$seg = 180) {
  $o = Join-Path $env:TEMP 'mec_upd_out.txt'; $e = Join-Path $env:TEMP 'mec_upd_err.txt'
  foreach ($x in $o, $e) { if (Test-Path $x) { [IO.File]::Delete($x) } }
  $p = Start-Process -FilePath $exe -ArgumentList $argv -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
  if (-not $p.WaitForExit($seg * 1000)) { try { $p.Kill() } catch {}; return "(sem resposta em $seg s)" }
  return ((@(Get-Content $o -Encoding UTF8 -ErrorAction SilentlyContinue) + @(Get-Content $e -Encoding UTF8 -ErrorAction SilentlyContinue)) -join ' ').Trim()
}

# mantém o log pequeno
if ((Test-Path $log) -and (Get-Item $log).Length -gt 200KB) { Get-Content $log -Tail 300 | Set-Content $log -Encoding UTF8 }

$cands = @()
$cmd = Get-Command claude -ErrorAction SilentlyContinue; if ($cmd) { $cands += Get-Item $cmd.Source }
$cands += Get-ChildItem (Join-Path $env:APPDATA 'Claude\claude-code') -Recurse -Filter claude.exe -Depth 3 -ErrorAction SilentlyContinue
$cands += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue |
  ForEach-Object { Get-ChildItem (Join-Path $_.FullName 'LocalCache\Roaming\Claude\claude-code') -Recurse -Filter claude.exe -Depth 3 -ErrorAction SilentlyContinue }
$cands += Get-ChildItem (Join-Path $env:USERPROFILE '.local\bin') -Filter claude.exe -ErrorAction SilentlyContinue
$exe = $cands | Where-Object { $_ } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { Log 'claude.exe não encontrado - nada a fazer'; exit 0 }
$exe = $exe.FullName

$antes = Run-Claude $exe @('plugin', 'list') 60
$r1 = Run-Claude $exe @('plugin', 'marketplace', 'update', $MARKETPLACE)
if ($r1 -match 'not found|não encontrad|No marketplace') { $r1 += ' | ' + (Run-Claude $exe @('plugin', 'marketplace', 'add', $REPO)) }
if ($antes -notmatch [regex]::Escape($KEY)) { $r2 = Run-Claude $exe @('plugin', 'install', $KEY) }
else { $r2 = Run-Claude $exe @('plugin', 'update', $KEY) }
$depois = Run-Claude $exe @('plugin', 'list') 60
$vA = [regex]::Match($antes, 'Version:\s*([\d.]+)').Groups[1].Value
$vD = [regex]::Match($depois, 'Version:\s*([\d.]+)').Groups[1].Value
Log ("versão antes: {0}  depois: {1}  | marketplace: {2} | plugin: {3}" -f $vA, $vD, $r1, $r2)

# o comando do marketplace pode regravar a configuração sem o autoUpdate: religa
try {
  $path = Join-Path $env:USERPROFILE '.claude\settings.json'
  if (Test-Path $path) {
    $cfg = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    $ent = $cfg.extraKnownMarketplaces.$MARKETPLACE
    if ($ent -and -not $ent.autoUpdate) {
      if ($ent.PSObject.Properties['autoUpdate']) { $ent.autoUpdate = $true } else { $ent | Add-Member -NotePropertyName autoUpdate -NotePropertyValue $true }
      [IO.File]::WriteAllText($path, ($cfg | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
      Log 'autoUpdate religado no settings.json'
    }
  }
} catch { Log "erro ao conferir autoUpdate: $($_.Exception.Message)" }
exit 0
