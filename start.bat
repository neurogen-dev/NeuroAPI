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
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -U setuptools
python -m pip install -r requirements.txt

REM checking for spacy language models and download if not exists
IF NOT EXIST venv\Lib\site-packages\en_core_web_sm (
    echo English language model not found, downloading...
    python -m spacy download en_core_web_sm
)

IF NOT EXIST venv\Lib\site-packages\zh_core_web_sm (
    echo Chinese language model not found, downloading...
    python -m spacy download zh_core_web_sm
)

IF NOT EXIST venv\Lib\site-packages\ru_core_news_sm (
    echo Russian language model not found, downloading...
    python -m spacy download ru_core_news_sm
)

echo Completed.
echo Running NeuroGPT...

REM Determine the language of the operating system
python -c "import locale; print(locale.getdefaultlocale()[0])" > lang.txt
set /p language=<lang.txt

IF "%language%"=="ru_RU" (
  python webui_ru.py
) ELSE (
  python webui_en.py
)

pause

:: Упаковано и собрано telegram каналом Neurogen News: https://t.me/neurogen_news
