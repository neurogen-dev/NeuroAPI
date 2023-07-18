@echo off
call update.bat
REM строка выше производит обновление каждый раз, при каждом запуске
echo Opening NeurogenGPT...

REM Open powershell via bat
set HIDE_LOCAL_MODELS=true

call venv\Scripts\activate.bat

python webui.py
pause
