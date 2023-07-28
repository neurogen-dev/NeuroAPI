git checkout main
git fetch --all
git reset --hard origin/main
git pull
call venv\Scripts\activate.bat
python -m pip install -r requirements.txt
