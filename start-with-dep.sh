#!/usr/bin/bash


export HIDE_LOCAL_MODELS=true

cp  config.json config_temp.json
git checkout main
git fetch --all
git reset --hard origin/main
git pull
# Восстанавливаем оригинальный файл config.json
cp  config_temp.json config.json
rm config_temp.json

python -m venv venv
. venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -U setuptools
python -m pip install -r requirements.txt
python -m spacy download en_core_web_sm
python -m spacy download zh_core_web_sm
python -m spacy download ru_core_news_sm


python webui_ru.py

