@echo off
echo Opening NeuroGPT endpoint...

python -m venv venv
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -U setuptools
python -m pip install -U g4f

echo Completed.
echo Running NeuroGPT...

g4f api
pause