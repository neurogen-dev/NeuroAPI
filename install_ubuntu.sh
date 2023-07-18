#!/bin/bash
sudo apt update
sudo apt install python3-full git

python3 --version
git --version

python3 -m venv venv
source venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install -U setuptools
python3 -m pip install -r requirements.txt