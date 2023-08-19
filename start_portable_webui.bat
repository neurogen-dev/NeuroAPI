@echo off
echo Opening NeuroGPT...

set HIDE_LOCAL_MODELS=true

echo Checking for updates...
REM Создаем временную копию файла config.json
copy /Y config.json config_temp.json
git checkout portable
git fetch --all
git reset --hard origin/portable
git pull
REM Восстанавливаем оригинальный файл config.json
copy /Y config_temp.json config.json
del config_temp.json

REM Check if python folder exists
if not exist python\ (
  REM Download python.zip from GitHub
  echo Downloading python.zip...
  powershell.exe -nologo -noprofile -command "& { (New-Object Net.WebClient).DownloadFile ('[https://github.com/Em1tSan/NeuroGPT/releases/download/v1.2.1/python.zip]', 'python.zip') }"
  REM Unzip python.zip to current folder
  echo Unzipping python.zip...
  powershell.exe -nologo -noprofile -command "& { $shell = New-Object -COM Shell.Application; $target = $shell.NameSpace ('%cd%'); $zip = $shell.NameSpace ('%cd%\python.zip'); $target.CopyHere ($zip.Items (), 16); }"
  REM Delete python.zip
  del python.zip
)

python -m venv venv
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -U setuptools
python -m pip install -r requirements.txt

echo Completed.
echo Running NeuroGPT...

python webui.py
pause
