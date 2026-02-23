@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -STA -File ".\chunky-pregen-guard.ps1"
pause
