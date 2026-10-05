@echo off
chcp 65001 >nul
title Diagnostico Mec Gestao - Claude
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}; $f = Join-Path $env:TEMP 'diagnostico-mec-claude.ps1'; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/GENILSONCIEC/mec-gestao-claude-cliente-final/main/instalar/diagnostico.ps1' -OutFile $f; & powershell -NoProfile -ExecutionPolicy Bypass -File $f"
echo.
pause
