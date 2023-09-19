#!/bin/bash

# Обновить систему
sudo apt-get update -y

# Установить python3, pip, git и зависимости
sudo apt-get install -y python3-full python3-venv python3-pip python-is-python3 git build-essential libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev

# Клонировать репозиторий
git clone https://github.com/Em1tSan/NeuroGPT.git
cd NeuroGPT

# Обновить репозиторий
git checkout main
git fetch --all
git reset --hard origin/main
git pull

# Проверка версии Python
version=$(python3 --version)
version=${version:7}
if [[ "$version" < "3.9.0" ]]; then
    echo "Your version of Python ${version} is not supported. Please install Python 3.10.X"
    exit 1
elif [[ "$version" > "3.11.14" ]]; then
    echo "Your version of Python ${version} is not supported. Please install Python 3.10.X"
    exit 1
fi

# Создание и активация виртуальной среды
python3 -m venv venv
. venv/bin/activate

# Установка необходимых пакетов
python3 -m pip install --upgrade pip
python3 -m pip install -U setuptools
python3 -m pip install -r requirements.txt

# Проверка и загрузка моделей Spacy при необходимости
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

# Определение языка операционной системы и запуск соответствующего скрипта
language=$(locale | grep LANG= | cut -d "=" -f2 | cut -d "_" -f1)
if [ "$language" = "ru" ]; then
  python3 webui_ru.py
else
  python3 webui_en.py
fi