<#
  Diagnóstico do plugin Mec Gestão no Claude. Não altera nada; só mostra a situação.
  Gera também o arquivo "diagnostico-mec-claude.txt" na Área de Trabalho para enviar ao suporte.
  Não mostra senhas.
#>
$ErrorActionPreference = 'Continue'
$out = New-Object System.Collections.ArrayList
function L($t) { [void]$out.Add([string]$t); Write-Host $t }
function Run-Claude($exe, [string[]]$argv, [int]$seg = 120) {
  $o = Join-Path $env:TEMP 'mec_diag_out.txt'; $e = Join-Path $env:TEMP 'mec_diag_err.txt'
  $p = Start-Process -FilePath $exe -ArgumentList $argv -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
  if (-not $p.WaitForExit($seg * 1000)) { try { $p.Kill() } catch {}; return @("(sem resposta em $seg s - processo encerrado)") }
  return @((Get-Content $o -ErrorAction SilentlyContinue) + (Get-Content $e -ErrorAction SilentlyContinue))
}

L "=== Diagnóstico Mec Gestão / Claude - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') ==="
L "Usuário Windows: $env:USERNAME   Perfil: $env:USERPROFILE"
L "Windows: $([Environment]::OSVersion.VersionString)  64 bits: $([Environment]::Is64BitOperatingSystem)"
L "CLAUDE_CONFIG_DIR: $([Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User'))$([Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','Machine'))"

L ''; L '--- Variáveis do banco ---'
foreach ($n in 'MEC_FB_DATABASE', 'MEC_FB_ISQL', 'ISC_USER') { L ("{0} = {1}" -f $n, [Environment]::GetEnvironmentVariable($n, 'User')) }
L ("ISC_PASSWORD definida: " + [bool][Environment]::GetEnvironmentVariable('ISC_PASSWORD', 'User'))

L ''; L '--- Git ---'
$g = Get-Command git -ErrorAction SilentlyContinue; if ($g) { L ("git: " + (& git --version) + "  ($($g.Source))") } else { L 'git: NÃO ENCONTRADO no PATH' }

$cdir = Join-Path $env:USERPROFILE '.claude'
L ''; L "--- $cdir\settings.json (trechos do plugin) ---"
$sp = Join-Path $cdir 'settings.json'
if (Test-Path $sp) {
  try { $s = Get-Content $sp -Raw | ConvertFrom-Json
    L ("extraKnownMarketplaces: " + ($s.extraKnownMarketplaces | ConvertTo-Json -Depth 6 -Compress))
    L ("enabledPlugins: " + ($s.enabledPlugins | ConvertTo-Json -Depth 4 -Compress)) } catch { L "settings.json INVÁLIDO: $($_.Exception.Message)" }
} else { L 'settings.json NÃO EXISTE' }

L ''; L "--- $cdir\plugins ---"
$pd = Join-Path $cdir 'plugins'
foreach ($f in 'known_marketplaces.json', 'installed_plugins.json') {
  $fp = Join-Path $pd $f
  if (Test-Path $fp) { L "$f :"; (Get-Content $fp -Raw) -split "`n" | Select-Object -First 40 | ForEach-Object { L "  $_" } } else { L "$f : não existe" }
}
$sk = Get-ChildItem $pd -Recurse -Filter SKILL.md -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'mec-gestao' }
if ($sk) { $sk | ForEach-Object { L "SKILL.md: $($_.FullName)" } } else { L 'SKILL.md do plugin: NÃO ENCONTRADO' }
$old = Join-Path $cdir 'skills'
if (Test-Path $old) { Get-ChildItem $old -Directory | ForEach-Object { L "skill pessoal: $($_.Name)" } }

L ''; L '--- Claude Code (claude.exe) ---'
$cands = @()
$cmd = Get-Command claude -ErrorAction SilentlyContinue; if ($cmd) { $cands += Get-Item $cmd.Source }
$cands += Get-ChildItem (Join-Path $env:APPDATA 'Claude\claude-code') -Recurse -Filter claude.exe -Depth 3 -ErrorAction SilentlyContinue
$cands += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue |
  ForEach-Object { Get-ChildItem (Join-Path $_.FullName 'LocalCache\Roaming\Claude\claude-code') -Recurse -Filter claude.exe -Depth 3 -ErrorAction SilentlyContinue }
$cands += Get-ChildItem (Join-Path $env:USERPROFILE '.local\bin') -Filter claude.exe -ErrorAction SilentlyContinue
$cands = @($cands | Where-Object { $_ } | Sort-Object LastWriteTime -Descending)
$cands | ForEach-Object { L "encontrado: $($_.FullName)  ($($_.LastWriteTime))" }
if ($cands.Count) {
  $exe = $cands[0].FullName
  L ''; L '> claude --version'; Run-Claude $exe @('--version') 60 | ForEach-Object { L "  $_" }
  L '> claude plugin marketplace list'; Run-Claude $exe @('plugin', 'marketplace', 'list') | ForEach-Object { L "  $_" }
  L '> claude plugin list'; Run-Claude $exe @('plugin', 'list') | ForEach-Object { L "  $_" }
} else { L 'claude.exe NÃO ENCONTRADO (abra a aba Code do aplicativo Claude ao menos uma vez)' }

L ''; L '--- Atualização ---'
try {
  $gh = (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/GENILSONCIEC/mec-gestao-claude-cliente-final/main/.claude-plugin/plugin.json' -TimeoutSec 30).Content | ConvertFrom-Json
  L "Versão mais nova no GitHub: $($gh.version)"
} catch { L "Não foi possível consultar o GitHub: $($_.Exception.Message)" }
$tk = Get-ScheduledTask -TaskName 'MecGestao - Atualizar plugin Claude' -ErrorAction SilentlyContinue
if ($tk) { $ti = $tk | Get-ScheduledTaskInfo; L "Tarefa agendada: $($tk.State)  última execução: $($ti.LastRunTime)  resultado: $($ti.LastTaskResult)  próxima: $($ti.NextRunTime)" }
else { L 'Tarefa agendada: NÃO EXISTE (rode o instalador novamente para criá-la)' }
$ulog = Join-Path $env:LOCALAPPDATA 'MecGestao\atualizacao.log'
if (Test-Path $ulog) { L 'Últimas atualizações:'; Get-Content $ulog -Encoding UTF8 -Tail 5 | ForEach-Object { L "  $_" } }

# ---------- testes reais: conexão (somente leitura) e geração de PDF ----------
function Run-Ps([string]$script, [string[]]$argv, [int]$seg = 180) {
  $o = Join-Path $env:TEMP 'mec_diag_ps_out.txt'; $e = Join-Path $env:TEMP 'mec_diag_ps_err.txt'
  $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"") + $argv
  $t0 = Get-Date
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $all -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
  if (-not $p.WaitForExit($seg * 1000)) { try { $p.Kill() } catch {}; return @("(sem resposta em $seg s - processo encerrado)") }
  $p.WaitForExit(); $sec = ((Get-Date) - $t0).TotalSeconds
  return @((Get-Content $o -Encoding UTF8 -ErrorAction SilentlyContinue) + (Get-Content $e -Encoding UTF8 -ErrorAction SilentlyContinue) + ("(tempo: {0:N1} s, código de saída: {1})" -f $sec, $p.ExitCode))
}
$plug = $null
try {
  $ip = Get-Content (Join-Path $pd 'installed_plugins.json') -Raw | ConvertFrom-Json
  $plug = @($ip.plugins.'mec-gestao@mec-gestao-plugins')[0].installPath
} catch {}
$scr = if ($plug) { Join-Path $plug 'skills\firebird-mec-cliente-final\scripts' } else { $null }
L ''; L '--- Teste 1: conexão com o banco (somente leitura) ---'
if ($scr -and (Test-Path (Join-Path $scr 'fbquery.ps1'))) {
  Run-Ps (Join-Path $scr 'fbquery.ps1') @('-Sql', '"SELECT FIRST 1 FIL_CODIGO, TRIM(FIL_RAZAO) AS RAZAO FROM FILIAL"') 120 | ForEach-Object { L "  $_" }
  L '--- Teste 2: geração de PDF de teste ---'
  $spec = Join-Path $env:TEMP 'mec_diag_spec.json'; $pdf = Join-Path $env:TEMP 'mec_diag_teste.pdf'
  $js = @{ titulo = 'Teste de diagnostico'; filtro = 'Teste'; linhas = @(@{ ITEM = 'A'; VALOR = 10 }, @{ ITEM = 'B'; VALOR = 20 });
           colunas = @(@{ campo = 'ITEM'; titulo = 'Item'; tipo = 'texto' }, @{ campo = 'VALOR'; titulo = 'Valor'; tipo = 'moeda'; total = $true });
           totais = $true; graficos = @(@{ tipo = 'barras'; titulo = 'Teste'; rotulo = 'ITEM'; valores = @('VALOR'); formato = 'moeda' }); saida = $pdf } | ConvertTo-Json -Depth 6
  [IO.File]::WriteAllText($spec, $js, (New-Object Text.UTF8Encoding($false)))
  Run-Ps (Join-Path $scr 'gerar_relatorio.ps1') @('-Spec', "`"$spec`"") 180 | ForEach-Object { L "  $_" }
  L ("  PDF de teste criado: " + (Test-Path $pdf))
  foreach ($x in $spec, $pdf) { if (Test-Path $x) { [IO.File]::Delete($x) } }
} else { L '  scripts do plugin não encontrados - testes não executados' }

$desk = [Environment]::GetFolderPath('Desktop'); if (-not $desk -or -not (Test-Path $desk)) { $desk = $env:TEMP }; $arq = Join-Path $desk 'diagnostico-mec-claude.txt'
[IO.File]::WriteAllLines($arq, $out, (New-Object Text.UTF8Encoding($true)))
Write-Host ''; Write-Host "Arquivo salvo em: $arq" -ForegroundColor Cyan
