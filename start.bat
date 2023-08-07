@echo off
echo Opening NeuroGPT...

set HIDE_LOCAL_MODELS=true

echo Checking for updates...
REM Создаем временную копию файла config.json
copy /Y config.json config_temp.json
git checkout main
git fetch --all
git reset --hard origin/main
git pull
REM Восстанавливаем оригинальный файл config.json
copy /Y config_temp.json config.json
del config_temp.json

python -m venv venv
python -m pip install --upgrade pip
python -m pip install -U setuptools
call venv\Scripts\activate.bat
python -m pip install -r requirements.txt

echo Completed.
echo Running NeuroGPT...

python webui.py
pause

:: Упаковано и собрано telegram каналом Neurogen News: https://t.me/neurogen_news
