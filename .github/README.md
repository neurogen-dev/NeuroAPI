<div align="center">
<a href="https://t.me/neurogen_news">
  <img src="https://readme-typing-svg.herokuapp.com?font=Inconsolata&weight=700&size=30&duration=4000&pause=1000&color=1BED29&center=true&width=435&lines=NeuroGPT+by+Neurogen...;Opening..." alt="NeuroGPT" />
</a>

<strong> Русский | English </strong>

<p> NeuroGPT позволяет бесплатно пользоваться gpt-3.5, gpt-4 и другими языковыми моделями без VPN и регистрации аккаунта. Работает через API Reverse Engineering.

Проект основан на модифицированных версиях <a href="https://github.com/xtekky/gpt4free">gpt4free</a> и <a href="https://github.com/GaiZhenbiao/ChuanhuChatGPT">ChuanhuChatGPT</a></p>
Благодарность авторам.

<a href="https://github.com/Em1tSan/NeuroGPT/blob/main/LICENSE">
  <img src="https://img.shields.io/badge/license-GPL_3.0-indigo.svg" alt="license"/>
</a>
<a href="https://github.com/Em1tSan/NeuroGPT/commits/main">
  <img src="https://img.shields.io/badge/latest-v1.3.1_beta-indigo.svg" alt="latest"/>
</a>

<br> Инструкции по установке: <br/>

<a href="https://github.com/Em1tSan/NeuroGPT#windows">
  <img src="https://img.shields.io/badge/-Windows-1371c3?logo=windows" alt="windows"/>
</a>
<a href="https://github.com/Em1tSan/NeuroGPT#linux">
  <img src="https://img.shields.io/badge/-Linux-F1502F?logo=linux" alt="linux"/>
</a>
<a href="https://github.com/Em1tSan/NeuroGPT#macos">
  <img src="https://img.shields.io/badge/-MacOS-C0BFC0?logo=apple" alt="macos"/>
</a> </p>
<a href="https://github.com/Em1tSan/NeuroGPT#%D0%BF%D0%BE%D1%80%D1%82%D0%B0%D1%82%D0%B8%D0%B2%D0%BD%D0%B0%D1%8F-%D0%B2%D0%B5%D1%80%D1%81%D0%B8%D1%8F">
  <img src="https://img.shields.io/badge/-Портативная версия-008000?logo=portable" alt="portable"/>
</a>

<br> Новости и обратная связь: <br/>

<a href="https://t.me/neurogen_news">
  <img src="https://img.shields.io/badge/-Telegram канал-0088CC?logo=telegram" alt="telegram"/>
</a>
<a href="https://t.me/neurogen_chat">
  <img src="https://img.shields.io/badge/-Telegram чат-0088CC?logo=telegram" alt="telegram_chat"/>
</a>

<br> Поддержать проект: <br/>

<a href="https://boosty.to/neurogen">
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/Boosty_logo.svg/512px-Boosty_logo.svg.png?20230209172145" alt="neurogen_boosty" width="20%">
</a>

</div>

## Дисклеймер:

Поскольку данный проект функционирует не через официальное API, а благодаря доступу, полученному путем обратной инженерии, то API провайдеры могут падать, а различные модели отключаться. Пожалуйста, учтите это. Если вам необходима высокая стабильность для работы, то стоит обойти этот проект стороной. Также важно помнить, что поддержка осуществляется на чистом энтузиазме.

## Возможности:

- Веб-поиск
- Встроенные шаблоны промптов под разные задачи
- Встроенные джейлбрейки для снятия цензуры
- Контекст беседы
- Режим endpoint для работы с API
- Тонкая настройка модели
- Сохранение и загрузка истории диалогов

<div align="center">
  <img src="https://github.com/NealBelov/screenshots/blob/main/img_01.png?raw=true" width="70%">
</div>

## Список моделей:

- gpt-3.5-turbo-16k
- gpt-3.5-turbo
- gpt-4
- gpt-4-32k
- gpt-4-0613
- llama-2-70b-chat
- claude-2
- text-davinci-003

# Установка и запуск

### Портативная версия

Запуск и автообновление в один клик. Не требует установки зависимостей.
Распаковать архив в папку без кириллицы в пути. Нажать `start_portable_webui`

<a href="https://github.com/Em1tSan/NeuroGPT/releases/download/v1.3.0/NeuroGPT-Portable.v1.3.7z">Скачать</a>

---

### [Инструкция по получению API ключей ChimeraAI и Chatty](https://github.com/Em1tSan/NeuroGPT/wiki/%D0%98%D0%BD%D1%81%D1%82%D1%80%D1%83%D0%BA%D1%86%D0%B8%D1%8F-%D0%BF%D0%BE-%D0%BF%D0%BE%D0%BB%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D1%8E-API-%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%B9-ChimeraAI-%D0%B8-Chatty)

---

## Windows
Данный проект поддерживает исколючительно версию языка Python не выше 3.10. То есть, с Python 3.11 и выше он **НЕ СОВМЕСТИМ**. Кроме того, работа на Python 3.9, 3.8 не гарантируется. 
В данной инструкции рассматриваются только х64-битные версии Windows 10 и 11.

#### 1. Установите Git For Windows
* [Скачайте](https://git-scm.com/download/win) и начните установку git.
  
  ![Screenshot](/.github/img/git-01.png)
* Если вы не знаете что отмечать, то оставьте настройки по умолчанию
 
  ![Screenshot](/.github/img/git-02.png)
* В окне прописывания в PATH - лучше выбрать среднюю опцию, чтобы команды гита можно было вызывать из любого терминала.

  ![Screenshot](/.github/img/git-03.png)
#### 2. Установите Visual Studio Community
* [Скачайте](https://visualstudio.microsoft.com/ru/downloads/) и установите Visual Studio Community.
* Ничего сложного, подойдут предлагаемые настройки по умолчанию.
#### 3. Установите Python 3.10.x Windows
* [Скачайте](https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe) и начните установку Python [3.10.11](https://www.python.org/downloads/release/python-31011/).

  ![Screenshot](/.github/img/py-01.png)
* Обязательно добавьте в переменные окружения (в PATH).

  ![Screenshot](/.github/img/py-02.png)

#### 4. Скачайте репозиторий. Для этого откройте командную строку в папке, где хотите разместить NeuroGPT и напишите команду:
`git clone https://github.com/Em1tSan/NeuroGPT.git`
* Откройте папку `NeuroGPT` и запустите файл `start.bat`. Он создаст виртуальную среду, установит зависимости и запустит программу.
  * Проверка обновлений происходит автоматически при каждом запуске.
### Запуск Endpoint'а 
* Откройте папку `NeuroGPT` и запустите файл `start_endpoint.bat`. 
  * Проверка обновлений происходит автоматически при каждом запуске.
* Endpoint будет доступен по адресу: `http://127.0.0.1:1337/`


## Linux

## MacOS
