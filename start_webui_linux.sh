#!/usr/bin/bash

export HIDE_OTHER_PROVIDERS=false
export SHOW_ALL_PROVIDERS=false
cp  config.json config_temp.json
git checkout main
git fetch --all
git reset --hard origin/main
git pull
# Восстанавливаем оригинальный файл config.json
cp  config_temp.json config.json
rm config_temp.json

python3 -m venv venv
source venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install -U setuptools
python3 -m pip install -r requirements.txt

python3 -m spacy download en_core_web_sm
python3 -m spacy download zh_core_web_sm
python3 -m spacy download ru_core_news_sm


python3 webui_ru.py

