#!/bin/bash
echo "Opening NeuroGPT..."

export HIDE_OTHER_PROVIDERS=false
export SHOW_ALL_PROVIDERS=false

echo "Checking for updates..."
python -c "import json; import collections; config = json.load(open('config.json')); keys = list(config.keys()); keys.insert(2, keys.pop(keys.index('daku_api_key'))); config = collections.OrderedDict([(key, config[key]) for key in keys]); json.dump(config, open('config.json', 'w'), indent=4)"

# Создаем временную копию файла config.json
cp config.json config_temp.json
git checkout main
git fetch --all
git reset --hard origin/main
git pull

# Восстанавливаем оригинальный файл config.json
mv config_temp.json config.json

python3 -m venv venv
. venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install -U setuptools
python3 -m pip install -r requirements.txt

# Checking for spacy language models and download if not exists
if [ ! -d "venv/lib/python3.10/site-packages/en_core_web_sm" ]; then
    echo "English language model not found, downloading..."
    python3 -m spacy download en_core_web_sm
fi

if [ ! -d "venv/lib/python3.10/site-packages/zh_core_web_sm" ]; then
    echo "Chinese language model not found, downloading..."
    python3 -m spacy download zh_core_web_sm
fi

if [ ! -d "venv/lib/python3.10/site-packages/ru_core_news_sm" ]; then
    echo "Russian language model not found, downloading..."
    python3 -m spacy download ru_core_news_sm
fi

echo "Completed."
echo "Running NeuroGPT..."

# Determine the language of the operating system
language=$(locale | grep LANG= | cut -d "=" -f2 | cut -d "_" -f1)

if [ "$language" = "ru" ]; then
  python3 webui_ru.py
else
  python3 webui_en.py
fi