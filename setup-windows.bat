@echo off
setlocal EnableExtensions
title NeuroAPI setup for Codex CLI and Claude Code

set "PSModulePath="
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\setup.ps1"
set "NEUROAPI_EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%NEUROAPI_EXIT_CODE%"=="0" (
  echo NeuroAPI setup failed. Review the message above; no plaintext key was written.
)
pause
exit /b %NEUROAPI_EXIT_CODE%
