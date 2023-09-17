#!/usr/bin/bash
export HIDE_LOCAL_MODELS=true
git fetch --all
git switch main
git pull
. venv/bin/activate
python webui_ru.py


