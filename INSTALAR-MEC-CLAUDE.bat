@echo off
chcp 65001 >nul
title Instalador Mec Gestao - Relatorios para o Claude
echo.
echo  Baixando a versao mais recente do instalador Mec Gestao...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}; $f = Join-Path $env:TEMP 'instalar-mec-claude.ps1'; try { Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/GENILSONCIEC/mec-gestao-claude-cliente-final/main/instalar/instalar-cliente.ps1' -OutFile $f } catch { Write-Host 'Nao foi possivel baixar o instalador. Verifique a internet.' -ForegroundColor Red; Read-Host 'ENTER para sair'; exit 1 }; & powershell -NoProfile -ExecutionPolicy Bypass -File $f"
