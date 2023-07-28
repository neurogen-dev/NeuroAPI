# Инструкция для linux, но на windows не сильно должно отличаться (мб кто дополнит)

### Клонируем репозиторий и переходим в папку проекта:

```bash
➜ ~/git/ git clone https://github.com/Em1tSan/NeuroGPT
Клонирование в «NeuroGPT»...
remote: Enumerating objects: 859, done.
remote: Counting objects: 100% (262/262), done.
remote: Compressing objects: 100% (207/207), done.
remote: Total 859 (delta 133), reused 125 (delta 55), pack-reused 597
Получение объектов: 100% (859/859), 1.33 МиБ | 5.67 МиБ/с, готово.
Определение изменений: 100% (473/473), готово.

➜ ~/git/ cd NeuroGPT
```

## ==Получаем ключ ChimeraApi по основной инструкции и вносим его в config.json.==

### Создаем venv и устанавливаем gradio:

```bash
➜ ~/git/NeuroGPT/ python -m venv venv
➜ ~/git/NeuroGPT/ source venv/bin/activate
(venv) ➜ ~/git/NeuroGPT/ [main*]  pip install gradio
```

* * *

## Деплой проекта на Huggingface:

Для этого регаемся на [huggingface](https://huggingface.co) и получаем токен по ссылке (нужен токен с правами write) [tokens](https://huggingface.co/settings/tokens)

Теперь можно запустить деплой проекта, нам понадобиться токен когда его спросят, все остальные поля либо оставляем как есть, либо заполняем своими данными. Важно: бесплатные мощности идут только на **cpu-basic**, поэтому его не меняем. 

==Деплой запускается командой **gradio deploy** в активированом venv в корне проекта.==

```bash
(venv) ➜  NeuroGPT git:(main) gradio deploy
Need 'write' access token to create a Spaces repo.

    _|    _|  _|    _|    _|_|_|    _|_|_|  _|_|_|  _|      _|    _|_|_|      _|_|_|_|    _|_|      _|_|_|  _|_|_|_|
    _|    _|  _|    _|  _|        _|          _|    _|_|    _|  _|            _|        _|    _|  _|        _|
    _|_|_|_|  _|    _|  _|  _|_|  _|  _|_|    _|    _|  _|  _|  _|  _|_|      _|_|_|    _|_|_|_|  _|        _|_|_|
    _|    _|  _|    _|  _|    _|  _|    _|    _|    _|    _|_|  _|    _|      _|        _|    _|  _|        _|
    _|    _|    _|_|      _|_|_|    _|_|_|  _|_|_|  _|      _|    _|_|_|      _|        _|    _|    _|_|_|  _|_|_|_|
    
    A token is already saved on your machine. Run `huggingface-cli whoami` to get more information or `huggingface-cli logout` if you want to log out.
    Setting a new token will erase the existing one.
    To login, `huggingface_hub` requires a token generated from https://huggingface.co/settings/tokens .
Token: 
Add token as git credential? (Y/n) Y
Token is valid (permission: write).
Cannot authenticate through git-credential as no helper is defined on your machine.
You might have to re-authenticate when pushing to the Hugging Face Hub.
Run the following command in your terminal in case you want to set the 'store' credential helper as default.

git config --global credential.helper store

Read https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage for more details.
Token has not been saved to git credential helper.
Your token has been saved to /root/.cache/huggingface/token
Login successful
Creating new Spaces Repo in '/root/git/NeuroGPT'. Collecting metadata, press Enter to accept default value.
Enter Spaces app title [NeuroGPT]: 
Enter Gradio app file [webui.py]: 
Enter Spaces hardware (cpu-basic, cpu-upgrade, t4-small, t4-medium, a10g-small, a10g-large, a100-large) [cpu-basic]: 
Any Spaces secrets (y/n) [n]: 
Create Github Action to automatically update Space on 'git push'? [n]:

Space available at https://huggingface.co/spaces/<ваш ник>/<имя проекта>
```

### Деплой займет какое-то время, после чего ссылка на проект будет в конце работы как на примере выше или проект можно найти по пути:

`https://huggingface.co/spaces/<ваш ник на huggingface>/<имя проекта заданное на этапе деплоя>`

### Для ограничения доступа к проекту надо сделать его приватным, для этого открываем страницу проекта и в правом верхнем углу нажимаем Settings, после чего листаем вниз и переключаем с public на private.

* * *

## Для обновления:

Переходим в каталог проекта, активируем venv, выполняем git pull и затем gradio deploy.
