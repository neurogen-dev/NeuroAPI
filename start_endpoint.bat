@echo off

call update.bat
REM строка выше производит обновление каждый раз, при каждом запуске

call venv\Scripts\activate.bat
python endpoint.py --enable_proxy
pause

:: Упаковано и собрано телеграм каналом Neutogen News: https://t.me/neurogen_news
