#!/bin/bash
git pull

python3 -m venv venv
source venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install -U setuptools
python3 -m pip install -r requirements.txt

echo Opening NeurogenGPT...

export HIDE_LOCAL_MODELS=true

source venv/bin/activate

python3 webui.py