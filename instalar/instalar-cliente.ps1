<#
  Instalador COMPLETO do plugin Mec Gestão (Relatórios) para o aplicativo Claude / Claude Code.
  Executar UMA vez em cada máquina do cliente, com o usuário do Windows que usa o Claude.

  O que faz, sozinho:
    1. Verifica o aplicativo Claude e o Microsoft Edge (usado para gerar os PDFs).
    2. Instala o Git, se faltar (winget ou instalador oficial). O Claude usa o Git para baixar e atualizar o plugin.
    3. Garante o isql.exe do Firebird 2.5. Se não houver, baixa o pacote ZIP oficial do Firebird 2.5.9 e extrai em
       %LOCALAPPDATA%\MecGestao\Firebird25. Não instala serviço e não altera o Firebird existente.
    4. Localiza os bancos do MEC, pede usuário e senha, testa a conexão em modo somente leitura e salva as variáveis.
    5. Registra o marketplace da Mec Gestão com ATUALIZAÇÃO AUTOMÁTICA e ativa o plugin
       (%USERPROFILE%\.claude\settings.json, preservando o que já existe e com backup).
#>
param([string]$Repo = 'GENILSONCIEC/mec-gestao-claude-cliente-final')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$MARKETPLACE = 'mec-gestao-plugins'
$PLUGIN = 'mec-gestao'
$FB_ZIP64 = 'https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/Firebird-2.5.9.27139-0_x64.zip'
$FB_ZIP32 = 'https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/Firebird-2.5.9.27139-0_Win32.zip'
$FB_LOCAL = Join-Path $env:LOCALAPPDATA 'MecGestao\Firebird25'

function Titulo($t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }
function Ok($t) { Write-Host "  [OK] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Erro($t) { Write-Host "  [X]  $t" -ForegroundColor Red }
function Sair($code) { Write-Host ''; Read-Host 'Pressione ENTER para sair' | Out-Null; exit $code }
function Run-Claude($exe, [string[]]$argv, [int]$seg = 180) {
  $o = Join-Path $env:TEMP 'mec_cl_out.txt'; $e = Join-Path $env:TEMP 'mec_cl_err.txt'
  foreach ($x in $o, $e) { if (Test-Path $x) { [IO.File]::Delete($x) } }
  $p = Start-Process -FilePath $exe -ArgumentList $argv -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
  if (-not $p.WaitForExit($seg * 1000)) { try { $p.Kill() } catch {}; return @("(sem resposta em $seg s)") }
  return @((Get-Content $o -ErrorAction SilentlyContinue) + (Get-Content $e -ErrorAction SilentlyContinue))
}function Atualiza-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

Clear-Host
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host '   Mec Gestão - Relatórios para o Claude (instalação)' -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host "  Usuário do Windows: $env:USERNAME"

# ---------- 1. Claude e Edge ----------
Titulo '1. Aplicativo Claude e Microsoft Edge'
$claude = @(
  (Join-Path $env:LOCALAPPDATA 'AnthropicClaude'),
  (Join-Path $env:LOCALAPPDATA 'Programs\Claude'),
  (Join-Path $env:USERPROFILE '.claude')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
$claudePkg = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($claude -or $claudePkg) { Ok 'Claude encontrado.' }
else { Aviso 'Aplicativo Claude não encontrado. Instale depois por https://claude.ai/download (a configuração já fica pronta).' }
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($edge) { Ok 'Microsoft Edge (geração de PDF).' } else { Aviso 'Microsoft Edge não encontrado: os relatórios em PDF não funcionarão até instalá-lo.' }

# ---------- 2. Git ----------
Titulo '2. Git'
Atualiza-Path
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host '  Git não encontrado. Instalando (pode aparecer uma confirmação do Windows)...'
  $instalado = $false
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    $ErrorActionPreference = 'Continue'
    & winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
    Atualiza-Path
    $instalado = [bool](Get-Command git -ErrorAction SilentlyContinue)
  }
  if (-not $instalado) {
    try {
      $rel = Invoke-RestMethod -UseBasicParsing 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers @{ 'User-Agent' = 'mec-instalador' }
      $pad = if ([Environment]::Is64BitOperatingSystem) { '64-bit\.exe$' } else { '32-bit\.exe$' }
      $asset = $rel.assets | Where-Object { $_.name -match "^Git-[\d.]+-$pad" } | Select-Object -First 1
      $exe = Join-Path $env:TEMP $asset.name
      Write-Host "  Baixando $($asset.name)..."
      Invoke-WebRequest -UseBasicParsing $asset.browser_download_url -OutFile $exe
      Start-Process $exe -ArgumentList '/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', '/SUPPRESSMSGBOXES' -Wait -Verb RunAs
      Remove-Item $exe -ErrorAction SilentlyContinue
      Atualiza-Path
      if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $g = @("$env:ProgramFiles\Git\cmd", "${env:ProgramFiles(x86)}\Git\cmd") | Where-Object { Test-Path "$_\git.exe" } | Select-Object -First 1
        if ($g) { $env:Path += ";$g" }
      }
      $instalado = [bool](Get-Command git -ErrorAction SilentlyContinue)
    } catch { $instalado = $false }
  }
  if (-not $instalado) {
    Erro 'Não foi possível instalar o Git automaticamente.'
    Write-Host '      Instale manualmente por https://git-scm.com/download/win e execute este instalador de novo.'
    Sair 1
  }
}
Ok ("Git: " + (& git --version))

# ---------- 3. Firebird 2.5 (isql) ----------
Titulo '3. Firebird 2.5 (ferramenta de consulta isql)'
$isql = [Environment]::GetEnvironmentVariable('MEC_FB_ISQL', 'User')
if (-not $isql -or -not (Test-Path $isql)) {
  $isql = @('C:\Program Files\Firebird\Firebird_2_5\bin\isql.exe', 'C:\Program Files (x86)\Firebird\Firebird_2_5\bin\isql.exe', (Join-Path $FB_LOCAL 'bin\isql.exe')) |
    Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $isql) {
  Write-Host '  isql do Firebird 2.5 não encontrado. Baixando o pacote oficial do Firebird 2.5.9 (cerca de 10 MB)...'
  $url = if ([Environment]::Is64BitOperatingSystem) { $FB_ZIP64 } else { $FB_ZIP32 }
  $zip = Join-Path $env:TEMP 'firebird25_kit.zip'
  try {
    Invoke-WebRequest -UseBasicParsing $url -OutFile $zip
    if (Test-Path $FB_LOCAL) { Remove-Item -Recurse -Force $FB_LOCAL }
    New-Item -ItemType Directory -Force $FB_LOCAL | Out-Null
    Expand-Archive -Path $zip -DestinationPath $FB_LOCAL -Force
    Remove-Item $zip -ErrorAction SilentlyContinue
    $isql = Join-Path $FB_LOCAL 'bin\isql.exe'
    if (-not (Test-Path $isql)) { throw 'isql.exe não encontrado no pacote' }
  } catch {
    Erro "Falha ao obter o Firebird 2.5: $($_.Exception.Message)"
    $isql = Read-Host '  Informe o caminho completo do isql.exe do Firebird 2.5 (ou ENTER para sair)'
    if (-not $isql -or -not (Test-Path $isql)) { Sair 1 }
  }
}
Ok "isql: $isql"

# ---------- 4. Banco de dados ----------
Titulo '4. Banco de dados do MEC'
$dbAtual = [Environment]::GetEnvironmentVariable('MEC_FB_DATABASE', 'User')
$achados = @()
foreach ($raiz in 'C:\MEC\DBS', 'D:\MEC\DBS', 'C:\MEC', 'D:\MEC') {
  if (Test-Path $raiz) { $achados += Get-ChildItem $raiz -Recurse -Depth 3 -Include *.FDB, *.GDB -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 1MB } }
  if ($achados.Count) { break }
}
$achados = @($achados | Sort-Object Length -Descending | Select-Object -First 9)
$db = $null
if ($dbAtual) { Write-Host "  Configuração atual: $dbAtual" }
if ($achados.Count) {
  Write-Host '  Bancos encontrados neste computador:'
  for ($i = 0; $i -lt $achados.Count; $i++) { Write-Host ("   [{0}] {1}  ({2:N0} MB)" -f ($i + 1), $achados[$i].FullName, ($achados[$i].Length / 1MB)) }
  Write-Host '   [0] Outro (banco em servidor ou caminho diferente)'
  $op = Read-Host '  Escolha o número do banco (ENTER mantém a configuração atual)'
  if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $achados.Count) {
    $porta = Read-Host '  Porta do Firebird 2.5 [3050]'; if (-not $porta) { $porta = '3050' }
    $db = "localhost/$($porta):" + $achados[[int]$op - 1].FullName
  } elseif (-not $op -and $dbAtual) { $db = $dbAtual }
}
while (-not $db) {
  Write-Host '  Formato: servidor/porta:caminho do banco no servidor'
  Write-Host '  Ex.: localhost/3050:C:\MEC\DBS\EMPRESA\DBCIECF.FDB   ou   192.168.0.10/3050:C:\MEC\DBS\EMPRESA\DBCIECF.FDB'
  $db = Read-Host '  Banco'
  if (-not $db -and $dbAtual) { $db = $dbAtual }
}
Ok "Banco: $db"

$userAtual = [Environment]::GetEnvironmentVariable('ISC_USER', 'User'); if (-not $userAtual) { $userAtual = 'CONSULTA' }
Write-Host '  Recomendado: usuário do Firebird com permissão SOMENTE de leitura (não use o SYSDBA).'
$usr = Read-Host "  Usuário do Firebird [$userAtual]"; if (-not $usr) { $usr = $userAtual }
if ($usr.ToUpper() -eq 'SYSDBA') { Aviso 'SYSDBA tem acesso total ao banco. Prefira um usuário somente leitura.' }

$conectou = $false
for ($tent = 1; $tent -le 3 -and -not $conectou; $tent++) {
  $sec = Read-Host '  Senha do Firebird' -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  $senhaTxt = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  Write-Host '  Testando conexão (somente leitura)...'
  $env:ISC_USER = $usr; $env:ISC_PASSWORD = $senhaTxt
  $tmp = Join-Path $env:TEMP 'mec_teste_conexao.sql'
  [IO.File]::WriteAllText($tmp, "SET TRANSACTION READ ONLY;`nSELECT 'CONEXAO_OK' FROM RDB`$DATABASE;`nROLLBACK;`n", [Text.Encoding]::ASCII)
  $ErrorActionPreference = 'Continue'
  $out = & $isql -q -i $tmp $db 2>&1 | ForEach-Object { "$_" }
  $ErrorActionPreference = 'Stop'
  Remove-Item $tmp -ErrorAction SilentlyContinue
  if (($out -join "`n") -match 'CONEXAO_OK') { $conectou = $true; Ok 'Conexão com o banco funcionando.' }
  else {
    Erro 'Não foi possível conectar:'
    $out | Where-Object { $_ -and $_ -ne 'Rolling back work.' } | Select-Object -First 4 | ForEach-Object { Write-Host "      $_" }
    if ($tent -lt 3) { Write-Host '  Tente novamente.' }
  }
}
if (-not $conectou) {
  $r = Read-Host '  Salvar a configuração mesmo assim? (s/N)'
  if ($r -notmatch '^[sS]') { Sair 1 }
}
[Environment]::SetEnvironmentVariable('MEC_FB_DATABASE', $db, 'User')
[Environment]::SetEnvironmentVariable('ISC_USER', $usr, 'User')
[Environment]::SetEnvironmentVariable('ISC_PASSWORD', $senhaTxt, 'User')
[Environment]::SetEnvironmentVariable('MEC_FB_ISQL', $isql, 'User')
$senhaTxt = $null; $env:ISC_PASSWORD = $null
Ok 'Configuração do banco salva para este usuário do Windows.'

# ---------- 5. Plugin no Claude ----------
Titulo '5. Plugin Mec Gestão no Claude'
if ($Repo -notmatch '^[\w.-]+/[\w.-]+$') { Erro 'Repositório inválido no instalador.'; Sair 1 }
$dir = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$path = Join-Path $dir 'settings.json'
if (Test-Path $path) {
  $raw = [IO.File]::ReadAllText($path)
  Copy-Item $path "$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  try { $cfg = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { New-Object PSObject } }
  catch { Erro "O arquivo $path não é um JSON válido. Corrija-o e execute novamente."; Sair 1 }
} else { $cfg = New-Object PSObject }

if (-not $cfg.PSObject.Properties['extraKnownMarketplaces']) { $cfg | Add-Member -NotePropertyName extraKnownMarketplaces -NotePropertyValue (New-Object PSObject) }
$mk = [pscustomobject]@{ source = [pscustomobject]@{ source = 'github'; repo = $Repo }; autoUpdate = $true }
if ($cfg.extraKnownMarketplaces.PSObject.Properties[$MARKETPLACE]) { $cfg.extraKnownMarketplaces.$MARKETPLACE = $mk }
else { $cfg.extraKnownMarketplaces | Add-Member -NotePropertyName $MARKETPLACE -NotePropertyValue $mk }

if (-not $cfg.PSObject.Properties['enabledPlugins']) { $cfg | Add-Member -NotePropertyName enabledPlugins -NotePropertyValue (New-Object PSObject) }
$key = "$PLUGIN@$MARKETPLACE"
if ($cfg.enabledPlugins.PSObject.Properties[$key]) { $cfg.enabledPlugins.$key = $true }
else { $cfg.enabledPlugins | Add-Member -NotePropertyName $key -NotePropertyValue $true }

[IO.File]::WriteAllText($path, ($cfg | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
Ok "Marketplace '$MARKETPLACE' ($Repo) configurado com atualização automática."

# Baixa e instala o plugin agora, usando o Claude Code que acompanha o aplicativo Claude
$cands = @()
$cmd = Get-Command claude -ErrorAction SilentlyContinue; if ($cmd) { $cands += Get-Item $cmd.Source }
$cands += Get-ChildItem (Join-Path $env:APPDATA 'Claude\claude-code') -Recurse -Filter claude.exe -Depth 3 -ErrorAction SilentlyContinue
$cands += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue |
  ForEach-Object { Get-ChildItem (Join-Path $_.FullName 'LocalCache\Roaming\Claude\claude-code') -Recurse -Filter claude.exe -Depth 3 -ErrorAction SilentlyContinue }
$cands += Get-ChildItem (Join-Path $env:USERPROFILE '.local\bin') -Filter claude.exe -ErrorAction SilentlyContinue
$claudeExe = $cands | Where-Object { $_ } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$instalouPlugin = $false
if ($claudeExe) {
  Write-Host "  Baixando o plugin do GitHub com o Claude Code ($($claudeExe.FullName))..."
  Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
  $ErrorActionPreference = 'Continue'
  $o1 = Run-Claude $claudeExe.FullName @('plugin', 'marketplace', 'add', $Repo)
  if (($o1 -join ' ') -notmatch 'Successfully') { $o1 += Run-Claude $claudeExe.FullName @('plugin', 'marketplace', 'update', $MARKETPLACE) }
  $o2 = Run-Claude $claudeExe.FullName @('plugin', 'install', $key)
  $o3 = Run-Claude $claudeExe.FullName @('plugin', 'list') 60
  $ErrorActionPreference = 'Stop'
  if (($o3 -join "`n") -match [regex]::Escape($key)) { $instalouPlugin = $true; Ok "Plugin '$key' instalado e ativado." }
  else {
    Erro 'O Claude Code não conseguiu instalar o plugin:'
    ($o1 + $o2 + $o3) | Where-Object { $_ } | Select-Object -Last 12 | ForEach-Object { Write-Host "      $_" }
  }
}
# O "plugin marketplace add" regrava a entrada no settings.json sem o autoUpdate: religa a atualização automática
try {
  $cfg2 = [IO.File]::ReadAllText($path) | ConvertFrom-Json
  $ent = $cfg2.extraKnownMarketplaces.$MARKETPLACE
  if ($ent) {
    if ($ent.PSObject.Properties['autoUpdate']) { $ent.autoUpdate = $true } else { $ent | Add-Member -NotePropertyName autoUpdate -NotePropertyValue $true }
    [IO.File]::WriteAllText($path, ($cfg2 | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
    Ok 'Atualização automática ligada.'
  }
} catch { Aviso "Não foi possível ligar a atualização automática: $($_.Exception.Message)" }
if (-not $instalouPlugin) {
  Aviso 'Plugin não instalado automaticamente. Abra o aplicativo Claude, entre na aba "Code" e digite:'
  Write-Host "      /plugin marketplace add $Repo"
  Write-Host "      /plugin install $key"
  Write-Host '  (ou execute este instalador de novo depois de abrir a aba Code do Claude uma vez)'
}

Titulo 'Concluído'
Write-Host '  1. Feche COMPLETAMENTE o aplicativo Claude (inclusive pelo ícone perto do relógio) e abra de novo.' -ForegroundColor White
Write-Host '  2. Na primeira sessão o plugin é baixado automaticamente do GitHub.' -ForegroundColor White
Write-Host '  3. Teste pedindo: "relatório dos 10 produtos mais vendidos no mês passado".' -ForegroundColor White
Sair 0
