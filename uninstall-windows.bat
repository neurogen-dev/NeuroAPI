@echo off
setlocal EnableExtensions
title Remove NeuroAPI setup for Codex CLI and Claude Code

set "PSModulePath="
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\uninstall.ps1"
set "NEUROAPI_EXIT_CODE=%ERRORLEVEL%"

echo.
pause
exit /b %NEUROAPI_EXIT_CODE%
