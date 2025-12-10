@echo off
setlocal
set SCRIPT=%~dp0tools\curl2ps.ps1
chcp 65001 > nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
endlocal

