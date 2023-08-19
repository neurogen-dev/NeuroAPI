@echo off

echo Opening NeuroGPT...

set HIDE_LOCAL_MODELS=true 

REM Проверяем наличие папки python
if not exist python (

  echo Python folder not found, downloading...
  
  curl -L -o python.zip https://github.com/Em1tSan/NeuroGPT/releases/download/v1.2.1/python.zip

  echo Unpacking python folder...
  Expand-Archive python.zip
  del python.zip /q
)

echo Checking for updates...

REM Создаем временную копию файла config.json
copy /Y config.json config_temp.json

git checkout portable
git fetch --all
git reset --hard origin/portable
git pull

REM Восстанавливаем оригинальный файл config.json 
copy /Y config_temp.json config.json
del config_temp.json

python -m venv venv
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -U setuptools 
python -m pip install -r requirements.txt

echo Completed.

echo Running NeuroGPT...
python webui.py

pause