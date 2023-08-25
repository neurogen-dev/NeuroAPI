<div align="center">
<a href="https://t.me/neurogen_news">
  <img src="https://readme-typing-svg.herokuapp.com?font=Inconsolata&weight=700&size=30&duration=4000&pause=1000&color=1BED29&center=true&width=435&lines=NeuroGPT+by+Neurogen...;Opening..." alt="NeuroGPT" />
</a>

<strong> <a href="https://github.com/Em1tSan/NeuroGPT#readme">Русский</a> | English </strong>

<p> NeuroGPT allows free use of gpt-3.5, gpt-4, and other language models without VPN and account registration. It operates through API Reverse Engineering.

The project is based on modified versions of <a href="https://github.com/xtekky/gpt4free">gpt4free</a> and <a href="https://github.com/GaiZhenbiao/ChuanhuChatGPT">ChuanhuChatGPT</a></p>
We extend our gratitude to the authors.

<a href="https://github.com/Em1tSan/NeuroGPT/blob/main/LICENSE">
  <img src="https://img.shields.io/badge/license-GPL_3.0-indigo.svg" alt="license"/>
</a>
<a href="https://github.com/Em1tSan/NeuroGPT/commits/main">
  <img src="https://img.shields.io/badge/latest-v1.3.2-indigo.svg" alt="latest"/>
</a>

<br> Installation instructions: <br/>

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
  <img src="https://img.shields.io/badge/-Portable version-008000?logo=portable" alt="portable"/>
</a>

<br> News and feedback: <br/>

<a href="https://t.me/neurogen_news">
  <img src="https://img.shields.io/badge/-Telegram channel-0088CC?logo=telegram" alt="telegram"/>
</a>
<a href="https://t.me/neurogen_chat">
  <img src="https://img.shields.io/badge/-Telegram chat-0088CC?logo=telegram" alt="telegram_chat"/>
</a>

<br> Support the project: <br/>

<a href="https://boosty.to/neurogen">
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/Boosty_logo.svg/512px-Boosty_logo.svg.png?20230209172145" alt="neurogen_boosty" width="20%">
</a>

</div>

## Disclaimer:

Given that this project doesn't use an official API but relies on reverse-engineered method, there's a risk of API providers failing and certain models disconnecting. Consider this if you need high stability for your work. Remember, support is provided solely out of enthusiasm.

## Features:

- Web search
- Built-in prompt templates for various tasks
- Built-in jailbreaks for removing censorship
- Conversation context
- API endpoint
- Fine-tuning a model
- Saving and loading dialogue history

<div align="center">
  <img src="https://github.com/NealBelov/screenshots/blob/main/img_03.png?raw=true" width="100%">
</div>

## List of models:

- gpt-3.5-turbo-16k
- gpt-3.5-turbo
- gpt-4
- gpt-4-32k
- gpt-4-0613
- llama-2-70b-chat
- claude-2
- text-davinci-003

# Installing and Running

### Portable version

One-click program launch and auto-update. No dependencies installation required.
Unpack the archive into a folder whose path does not contain Cyrillic. Press `start_portable_webui`.


<a href="https://github.com/Em1tSan/NeuroGPT/releases/download/v1.3.0/NeuroGPT-Portable.v1.3.7z">Скачать</a>

---

### [Instructions for obtaining API keys for ChimeraAI, PurGPT, and Chatty](https://github.com/Em1tSan/NeuroGPT/wiki/%D0%98%D0%BD%D1%81%D1%82%D1%80%D1%83%D0%BA%D1%86%D0%B8%D1%8F-%D0%BF%D0%BE-%D0%BF%D0%BE%D0%BB%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D1%8E-API-%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%B9-ChimeraAI,-PurGPT-%D0%B8-Chatty)

---

## Windows
This project only supports Python language version up to 3.10. That is, it is **NOT COMPATIBLE** with Python 3.11 and above. Moreover, its operation is not guaranteed on Python 3.9 and 3.8".
This guide only considers x64-bit versions of Windows 10 and 11.

#### 1. Install Git For Windows
* [Download](https://git-scm.com/download/win) and start installing git.
  
  ![Screenshot](/.github/img/git-01.png)
* If unsure, choose default settings.
 
  ![Screenshot](/.github/img/git-02.png)
* In the PATH entry window, choose the middle option to call git commands from any terminal.

  ![Screenshot](/.github/img/git-03.png)
#### 2. Install Visual Studio Community
* [Download](https://visualstudio.microsoft.com/ru/downloads/) and install Visual Studio Community.
* Nothing complicated; default settings offered will suffice.
#### 3. Install Python 3.10.x Windows
* [Download](https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe) and start the Python installation. [3.10.11](https://www.python.org/downloads/release/python-31011/).

  ![Screenshot](/.github/img/py-01.png)
* Be sure to add it to the environment variables (in PATH).

  ![Screenshot](/.github/img/py-02.png)

#### 4. Download the repository by opening the command line in the folder where you want to place NeuroGPT and typing the following command:
`git clone https://github.com/Em1tSan/NeuroGPT.git`
* Open `NeuroGPT` folder and run `start` file. It will create a virtual environment, install dependencies, and launch the program.
  * The program automatically checks for updates with each launch
### Running API endpoint
* Open `NeuroGPT` folder and run `start_endpoint` file. 
  * The program automatically checks for updates with each launch
* API endpoint will be available at: `http://127.0.0.1:1337/`


## Linux

## MacOS

## Планы:
* Telegram bot
* Website
* English language interface
