# NeuroAPI: Codex CLI и Claude Code через российский AI API

[![Проверка установщиков](https://github.com/neurogen-dev/NeuroAPI/actions/workflows/validate.yml/badge.svg?branch=agents)](https://github.com/neurogen-dev/NeuroAPI/actions/workflows/validate.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-22c55e.svg)](LICENSE)
[![NeuroAPI](https://img.shields.io/badge/NeuroAPI-neuroapi.host-06b6d4.svg)](https://neuroapi.host)

Открытые установщики для подключения [Codex CLI](https://developers.openai.com/codex/cli/) и [Claude Code](https://code.claude.com/docs/en/overview) к [NeuroAPI](https://neuroapi.host) на Windows и macOS.

Пакет настраивает **клиенты в терминале** через команды `codex-neuroapi` и `claude-neuroapi`. При отдельном согласии он также подключает **Codex Desktop** через пользовательский `~/.codex/config.toml`. Claude Desktop настраивается в самом приложении по [отдельной инструкции](https://neuroapi.host/docs/claude-desktop).

NeuroAPI — российский AI API-сервис: единый доступ к моделям OpenAI, Anthropic Claude, Google Gemini, DeepSeek, генерации изображений и видео с оплатой в рублях. Проект работает от российского ООО, инфраструктура сервиса размещена в РФ. Актуальные модели и цены всегда проверяйте в [живом каталоге](https://neuroapi.host/price).

[English version](README.en.md)

## Совместимость версии

Эта версия создаёт профиль Codex с `https://neuroapi.host/v1/codex` и `supports_websockets = true`, а профиль Claude Code — с `https://neuroapi.host/v1/claude-code`. Codex-профиль отключает hosted web search, multi-agent, goals, apps и browser use: эти инструменты новейший клиент отправляет даже в простых задачах, а NeuroAPI пока не гарантирует их провайдерское исполнение. Локальные команды, чтение и редактирование файлов работают. Установщик проверяет доступ ключа к обоим каталогам без платной генерации. Генерацию через HTTP/WebSocket Responses и Claude Messages/count_tokens проверяйте после серверного релиза.

Уже заданный `CODEX_HOME` учитывается для профиля и не изменяется; сохраняйте одинаковое значение при установке, запуске и удалении.

Нужен актуальный Codex с отдельными profile-файлами: `codex --help` должен описывать `--profile` как загрузку `<name>.config.toml`. Старые версии с `[profiles.name]` в общем конфиге обновите перед установкой. Для диагностики WebSocket можно временно поставить `supports_websockets = false` в созданном профиле, сохранив `/v1/codex` и credential helper. Подробнее — [решение проблем](docs/troubleshooting.md).

## Установка в один запуск

Создайте API-ключ в [кабинете NeuroAPI](https://neuroapi.host/login?redirect=/dashboard/tokens). Если Codex CLI или Claude Code отсутствуют либо устарели, установщик загрузит актуальные версии из [официального источника Codex](https://developers.openai.com/codex/cli/) и [официального источника Claude Code](https://code.claude.com/docs/en/setup).

Ссылка на ZIP ведёт в опубликованную ветку `agents`. Изменения открытого PR появятся в этом архиве только после слияния в `agents`.

### Windows

1. [Скачайте ZIP с установщиками](https://github.com/neurogen-dev/NeuroAPI/archive/refs/heads/agents.zip) и распакуйте его.
2. Дважды щёлкните `setup-windows.bat`.
3. Вставьте API-ключ в скрытый запрос PowerShell.
4. Если используете Codex Desktop, ответьте «да» на отдельный вопрос установщика и перезапустите приложение. Установщик создаст резервную копию вашего пользовательского конфига.
5. Откройте новый терминал и запустите:

```powershell
codex-neuroapi
claude-neuroapi
```

Права администратора не нужны. BAT-файл не принимает ключ через аргументы командной строки.

### macOS

1. [Скачайте ZIP с установщиками](https://github.com/neurogen-dev/NeuroAPI/archive/refs/heads/agents.zip) и распакуйте его.
2. Откройте Terminal в распакованной папке.
3. Запустите одну команду:

```bash
bash setup-macos.command
```

4. Вставьте API-ключ в защищённый запрос macOS Keychain.
5. Если используете Codex Desktop, ответьте «да» на отдельный вопрос установщика и перезапустите приложение. Установщик создаст резервную копию вашего пользовательского конфига.
6. Запустите:

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
| Codex Desktop по согласию | пользовательский `config.toml`, DPAPI helper, каталог доступных моделей | пользовательский `config.toml`, Keychain helper, каталог доступных моделей |
| Существующий `config.toml` | резервная копия и атомарное изменение только по согласию; конфликт останавливает установку | резервная копия и атомарное изменение только по согласию; конфликт останавливает установку |

Установщик отправляет ключ только в NeuroAPI для проверки доступных моделей; платной генерации при настройке нет. При запуске `codex-neuroapi` или `claude-neuroapi` запускатель вновь получает актуальный каталог с `https://neuroapi.host`, затем клиент использует API при ваших запросах.

## Почему ключ не лежит в конфиге

- ключ не принимается аргументом BAT/shell-команды;
- ключ не сохраняется в `.env`, TOML, JSON или репозитории;
- Windows шифрует значение через DPAPI без отдельного сохранённого master key;
- macOS сохраняет значение штатной командой Keychain с интерактивным `-w`;
- helpers печатают только токен в stdout по запросу launcher или клиента.

Это защищает от случайной публикации ключа, но не от вредоносной программы, уже работающей от имени того же пользователя. Полная модель угроз: [docs/security.md](docs/security.md).

## Что будет создано

Windows:

- `%LOCALAPPDATA%\NeuroAPIAgents\` — helper, Claude settings, DPAPI-ciphertext и launchers;
- `%USERPROFILE%\.codex\neuroapi-host.config.toml` — отдельный профиль Codex;
- `%USERPROFILE%\.codex\config.toml` — только при согласии на Codex Desktop; исходный файл хранится в installer-owned каталоге;
- `%LOCALAPPDATA%\NeuroAPIAgents\bin` — одна запись в пользовательском `PATH`.

macOS:

- `~/.local/share/neuroapi-agents/` — helper и Claude settings;
- `~/.codex/neuroapi-host.config.toml` — отдельный профиль Codex;
- `~/.codex/config.toml` — только при согласии на Codex Desktop; исходный файл хранится в installer-owned каталоге;
- `~/.local/bin/codex-neuroapi` и `~/.local/bin/claude-neuroapi`;
- Keychain item `host.neuroapi.agents.api-key`.

Каждый удаляемый файл имеет узкий ownership-маркер. Если путь уже занят чужим файлом, установка завершится с ошибкой вместо перезаписи.

## Проверка подключения

Codex CLI:

1. Запустите `codex-neuroapi`.
2. Выполните `/debug-config`.
3. Проверьте профиль `neuroapi-host`, provider `neuroapi` и `https://neuroapi.host/v1/codex`.

Claude Code:

1. Запустите `claude-neuroapi`.
2. Выполните `/status`.
3. Проверьте base URL `https://neuroapi.host/v1/claude-code` и credential source `apiKeyHelper`.

При каждом запуске launcher получает актуальный список для вашего обычного ключа NeuroAPI. Codex использует отдельный каталог, Claude Code — настроенное меню; фиксированных моделей в установщике нет. Проверенные минимумы: Codex 0.158.0 и Claude Code 2.1.284. Для Claude Code установщик задаёт начальный лимит вывода 4096 токенов, чтобы запросы с большим стандартным лимитом не резервировали избыточную квоту. При ошибке обновления или пустом списке запуск останавливается, не возвращаясь к старым моделям. Подробности и ограничения managed-политик: [ручная настройка](docs/manual-setup.md).

Рекомендуемый серверный набор: Codex — GPT-6 Sol, Astra и Luna; Claude Code — **Opus 5.5** (`claude-opus-5-5`, приоритетный), Sonnet 5.5, Sonnet 5 и Fable 5.1. Модель появляется в меню только после публикации на сервисе и появления совместимого маршрута для тарифа и ключа. Если администратор сохранил собственный список, он имеет приоритет над рекомендуемым набором.

Claude Code обращается к alias `haiku` и в фоновых задачах. Если доступной рекомендованной Haiku нет, сервер назначает для этого alias доступную Sonnet или основную модель. Такие запросы тарифицируются по фактически выбранной модели; фоновая работа может стоить дороже Haiku.

## Удаление и замена ключа

- Чтобы заменить ключ, повторно запустите setup-файл — защищённое значение обновится.
- Windows: `uninstall-windows.bat`.
- macOS: `./uninstall-macos.command`.

Uninstaller удаляет только installer-owned файлы и локально сохранённый ключ. Удалённый ключ через этот пакет восстановить нельзя.
Если после установки вы изменили `~/.codex/config.toml`, удаление остановится до удаления helper и ключа: это сохраняет работоспособность вашей конфигурации. Сначала вручную разберите изменения и повторите удаление.

## Документация

- [Модель безопасности](docs/security.md)
- [Ручная настройка и созданные файлы](docs/manual-setup.md)
- [Решение проблем](docs/troubleshooting.md)
- [Codex через NeuroAPI](https://neuroapi.host/codex-api)
- [Claude Code через NeuroAPI](https://neuroapi.host/claude-code)
- [Codex Desktop](https://neuroapi.host/docs/codex-desktop)
- [Claude Desktop Code](https://neuroapi.host/docs/claude-desktop)
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
