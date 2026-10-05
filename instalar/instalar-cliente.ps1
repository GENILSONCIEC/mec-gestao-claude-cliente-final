<#
  Instalador do plugin Mec Gestão (Relatórios) para o Claude Code / app Claude.
  Executar UMA vez em cada máquina do cliente (pelo instalar-cliente.bat).

  O que faz:
    1. Verifica Git, Firebird 2.5 (isql.exe) e Microsoft Edge.
    2. Configura as variáveis do banco: MEC_FB_DATABASE, ISC_USER, ISC_PASSWORD (e MEC_FB_ISQL se preciso).
    3. Testa a conexão com o banco.
    4. Registra o marketplace da Mec Gestão no Claude com ATUALIZAÇÃO AUTOMÁTICA e ativa o plugin
       (em %USERPROFILE%\.claude\settings.json, preservando as configurações existentes).
#>
param([string]$Repo = 'GENILSONCIEC/mec-gestao-claude-cliente-final')
$ErrorActionPreference = 'Stop'
$MARKETPLACE = 'mec-gestao-plugins'
$PLUGIN = 'mec-gestao'

function Titulo($t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }
function Ok($t) { Write-Host "  [OK] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Erro($t) { Write-Host "  [X]  $t" -ForegroundColor Red }

Write-Host 'Instalador Mec Gestão - Relatórios para Claude' -ForegroundColor Cyan

# ---------- 1. pré-requisitos ----------
Titulo '1. Verificando pré-requisitos'
if (Get-Command git -ErrorAction SilentlyContinue) { Ok ("Git: " + (git --version)) }
else {
  Erro 'Git não encontrado. Ele é necessário para o Claude baixar e atualizar o plugin.'
  Write-Host '      Instale com:  winget install --id Git.Git -e   (ou https://git-scm.com/download/win)'
  Write-Host '      Depois execute este instalador novamente.'
  Read-Host 'Pressione ENTER para sair'; exit 1
}
$isql = [Environment]::GetEnvironmentVariable('MEC_FB_ISQL', 'User')
if (-not $isql) {
  $cands = @('C:\Program Files\Firebird\Firebird_2_5\bin\isql.exe', 'C:\Program Files (x86)\Firebird\Firebird_2_5\bin\isql.exe')
  $isql = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
}
while (-not $isql -or -not (Test-Path $isql)) {
  Aviso 'isql.exe do Firebird 2.5 não encontrado no caminho padrão.'
  $isql = Read-Host '      Informe o caminho completo do isql.exe do Firebird 2.5'
}
Ok "Firebird isql: $isql"
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($edge) { Ok 'Microsoft Edge (geração de PDF)' } else { Aviso 'Microsoft Edge não encontrado: os relatórios em PDF não funcionarão.' }

# ---------- 2. banco de dados ----------
Titulo '2. Banco de dados'
$dbAtual = [Environment]::GetEnvironmentVariable('MEC_FB_DATABASE', 'User')
Write-Host '  Formato: servidor/porta:caminho do banco   ex.: localhost/3050:C:\MEC\DBS\EMPRESA\DBCIECF.FDB'
$db = Read-Host "  Banco [$dbAtual]"
if (-not $db) { $db = $dbAtual }
while (-not $db) { $db = Read-Host '  Banco' }
$userAtual = [Environment]::GetEnvironmentVariable('ISC_USER', 'User'); if (-not $userAtual) { $userAtual = 'CONSULTA' }
Write-Host '  Recomendado: usuário do Firebird com permissão SOMENTE de leitura (veja o README).'
$usr = Read-Host "  Usuário do Firebird [$userAtual]"; if (-not $usr) { $usr = $userAtual }
if ($usr.ToUpper() -eq 'SYSDBA') { Aviso 'SYSDBA tem acesso total. Prefira um usuário somente leitura.' }
$sec = Read-Host '  Senha do Firebird' -AsSecureString
$senhaTxt = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

Titulo '3. Testando conexão'
$env:ISC_USER = $usr; $env:ISC_PASSWORD = $senhaTxt
$tmp = Join-Path $env:TEMP 'mec_teste_conexao.sql'
[IO.File]::WriteAllText($tmp, "SET TRANSACTION READ ONLY;`nSELECT 'CONEXAO_OK' FROM RDB`$DATABASE;`nROLLBACK;`n", [Text.Encoding]::ASCII)
$ErrorActionPreference = 'Continue'
$out = & $isql -q -i $tmp $db 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = 'Stop'
Remove-Item $tmp -ErrorAction SilentlyContinue
if (($out -join "`n") -match 'CONEXAO_OK') { Ok 'Conexão com o banco funcionando.' }
else {
  Erro 'Não foi possível conectar:'; $out | Select-Object -First 6 | ForEach-Object { Write-Host "      $_" }
  $r = Read-Host '  Salvar a configuração mesmo assim? (s/N)'; if ($r -notmatch '^[sS]') { exit 1 }
}
[Environment]::SetEnvironmentVariable('MEC_FB_DATABASE', $db, 'User')
[Environment]::SetEnvironmentVariable('ISC_USER', $usr, 'User')
[Environment]::SetEnvironmentVariable('ISC_PASSWORD', $senhaTxt, 'User')
if ($isql -ne 'C:\Program Files\Firebird\Firebird_2_5\bin\isql.exe') { [Environment]::SetEnvironmentVariable('MEC_FB_ISQL', $isql, 'User') }
$senhaTxt = $null
Ok 'Variáveis do banco salvas para este usuário do Windows.'

# ---------- 4. plugin no Claude ----------
Titulo '4. Registrando o plugin no Claude'
if ($Repo -notmatch '^[\w.-]+/[\w.-]+$') { Erro 'Repositório inválido no instalador.'; exit 1 }
$dir = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$path = Join-Path $dir 'settings.json'
if (Test-Path $path) {
  $raw = [IO.File]::ReadAllText($path)
  Copy-Item $path "$path.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  try { $cfg = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { New-Object PSObject } }
  catch { Erro "O arquivo $path não é um JSON válido. Corrija-o e execute novamente."; exit 1 }
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
Ok "Marketplace '$MARKETPLACE' ($Repo) registrado com atualização automática."
Ok "Plugin '$key' ativado."

Titulo 'Concluído'
Write-Host '  Feche e abra novamente o aplicativo Claude. Na primeira sessão o plugin é baixado automaticamente.'
Write-Host '  Teste pedindo, por exemplo: "relatório dos 10 produtos mais vendidos no mês passado".'
Read-Host 'Pressione ENTER para sair'
