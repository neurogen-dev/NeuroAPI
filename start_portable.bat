@echo off
echo Opening NeurogenGPT...

REM Open powershell via bat
set HIDE_LOCAL_MODELS=true

call venv\Scripts\activate.bat

start python endpoint.py && python webui.py
pause