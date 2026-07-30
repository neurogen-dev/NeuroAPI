# NeuroAPI: Codex CLI и Claude Code через российский AI API

[![Проверка установщиков](https://github.com/neurogen-dev/NeuroAPI/actions/workflows/validate.yml/badge.svg?branch=agents)](https://github.com/neurogen-dev/NeuroAPI/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-22c55e.svg)](LICENSE)
[![NeuroAPI](https://img.shields.io/badge/NeuroAPI-neuroapi.host-06b6d4.svg)](https://neuroapi.host)

Открытые установщики для подключения [Codex CLI](https://developers.openai.com/codex/cli/) и [Claude Code](https://code.claude.com/docs/en/overview) к [NeuroAPI](https://neuroapi.host) на Windows и macOS.

NeuroAPI — российский AI API-сервис: единый доступ к моделям OpenAI, Anthropic Claude, Google Gemini, DeepSeek, генерации изображений и видео с оплатой в рублях. Проект работает от российского ООО, инфраструктура сервиса размещена в РФ. Актуальные модели и цены всегда проверяйте в [живом каталоге](https://neuroapi.host/price).

[English version](README.en.md)

## Установка в один запуск

Сначала установите сам [Codex CLI](https://developers.openai.com/codex/cli/) и/или [Claude Code](https://code.claude.com/docs/en/installation), затем создайте API-ключ в [кабинете NeuroAPI](https://neuroapi.host/login?redirect=/dashboard/tokens).

### Windows

1. [Скачайте ZIP с установщиками](https://github.com/neurogen-dev/NeuroAPI/archive/refs/heads/agents.zip) и распакуйте его.
2. Дважды щёлкните `setup-windows.bat`.
3. Вставьте API-ключ в скрытый запрос PowerShell.
4. Откройте новый терминал и запустите:

```powershell
codex-neuroapi
claude-neuroapi
```

Права администратора не нужны. BAT-файл не принимает ключ через аргументы командной строки.

### macOS

1. [Скачайте ZIP с установщиками](https://github.com/neurogen-dev/NeuroAPI/archive/refs/heads/agents.zip) и распакуйте его.
2. Откройте Terminal в распакованной папке.
3. Запустите:

```bash
chmod +x setup-macos.command
./setup-macos.command
```

4. Вставьте API-ключ в защищённый запрос macOS Keychain.
5. Запустите:

```bash
~/.local/bin/codex-neuroapi
~/.local/bin/claude-neuroapi
```

Скрипт не использует `sudo` и не редактирует shell profile. Если `~/.local/bin` уже входит в `PATH`, достаточно команд `codex-neuroapi` и `claude-neuroapi`.

## Что именно делает установщик

| Действие | Windows | macOS |
|---|---|---|
| Запрашивает ключ | `Read-Host -AsSecureString` | защищённый prompt `/usr/bin/security` |
| Хранит ключ | DPAPI, текущий пользователь и компьютер | login Keychain текущего пользователя |
| Codex | отдельный `~/.codex/neuroapi-host.config.toml` | отдельный `~/.codex/neuroapi-host.config.toml` |
| Claude Code | отдельный installer-owned JSON через `--settings` | отдельный installer-owned JSON через `--settings` |
| Получает ключ | command-backed auth helper | `apiKeyHelper` / Keychain helper |
| Существующие конфиги | не перезаписываются | не перезаписываются |

Установщик не вызывает API и не отправляет ключ в сеть. Сеть используется уже Codex CLI или Claude Code при ваших запросах к `https://neuroapi.host`.

## Почему ключ не лежит в конфиге

- ключ не принимается аргументом BAT/shell-команды;
- ключ не сохраняется в `.env`, TOML, JSON или репозитории;
- Windows шифрует значение через DPAPI без отдельного сохранённого master key;
- macOS сохраняет значение штатной командой Keychain с интерактивным `-w`;
- helpers печатают только токен в stdout в момент, когда его запрашивает клиент.

Это защищает от случайной публикации ключа, но не от вредоносной программы, уже работающей от имени того же пользователя. Полная модель угроз: [docs/security.md](docs/security.md).

## Что будет создано

Windows:

- `%LOCALAPPDATA%\NeuroAPIAgents\` — helper, Claude settings, DPAPI-ciphertext и launchers;
- `%USERPROFILE%\.codex\neuroapi-host.config.toml` — отдельный профиль Codex;
- `%LOCALAPPDATA%\NeuroAPIAgents\bin` — одна запись в пользовательском `PATH`.

macOS:

- `~/.local/share/neuroapi-agents/` — helper и Claude settings;
- `~/.codex/neuroapi-host.config.toml` — отдельный профиль Codex;
- `~/.local/bin/codex-neuroapi` и `~/.local/bin/claude-neuroapi`;
- Keychain item `host.neuroapi.agents.api-key`.

Каждый удаляемый файл имеет узкий ownership-маркер. Если путь уже занят чужим файлом, установка завершится с ошибкой вместо перезаписи.

## Проверка подключения

Codex CLI:

1. Запустите `codex-neuroapi`.
2. Выполните `/debug-config`.
3. Проверьте профиль `neuroapi-host`, provider `neuroapi` и `https://neuroapi.host/v1`.

Claude Code:

1. Запустите `claude-neuroapi`.
2. Выполните `/status`.
3. Проверьте base URL `https://neuroapi.host` и credential source `apiKeyHelper`.

Примеры используют `gpt-5.6-sol` и `claude-sonnet-4-5`. ID моделей меняются: при `model not found` возьмите точное имя из [каталога NeuroAPI](https://neuroapi.host/price) или `GET /v1/models`.

## Удаление и замена ключа

- Чтобы заменить ключ, повторно запустите setup-файл — защищённое значение обновится.
- Windows: `uninstall-windows.bat`.
- macOS: `./uninstall-macos.command`.

Uninstaller удаляет только installer-owned файлы и локально сохранённый ключ. Удалённый ключ через этот пакет восстановить нельзя.

## Документация

- [Модель безопасности](docs/security.md)
- [Ручная настройка и созданные файлы](docs/manual-setup.md)
- [Решение проблем](docs/troubleshooting.md)
- [Codex через NeuroAPI](https://neuroapi.host/codex-api)
- [Claude Code через NeuroAPI](https://neuroapi.host/claude-code)
- [OpenAI-совместимый API](https://neuroapi.host/openai-compatible-api)
- [Модели и цены](https://neuroapi.host/price)

## Проверяемость

GitHub Actions выполняет:

- PowerShell syntax + Windows DPAPI smoke test с тестовым токеном;
- Bash syntax + macOS smoke test с mock Keychain;
- ShellCheck;
- JSON/TOML parse checks;
- поиск случайно добавленных секретов и небезопасных способов передачи ключа.

Реальный пользовательский ключ никогда не нужен CI.
