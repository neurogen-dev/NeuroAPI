# Что настраивают установщики

Эта страница объясняет, как выполнить настройку вручную и какие файлы создаёт автоматический установщик. Самый простой путь — [setup-файл для вашей ОС](../README.md#установка-в-один-запуск). Если старая настройка уже не работала, начните с [пошагового восстановления](reconnect-after-update.md). Для самостоятельного копирования файлов и замены конкретных значений есть [пошаговые шаблоны](copy-paste-setup.md).

## Адреса и ключ

Используйте обычный API-ключ из [кабинета NeuroAPI](https://neuroapi.host/login?redirect=/dashboard/tokens). Скопируйте его целиком, включая префикс `sk-`; не добавляйте `Bearer ` в поле ключа. Отдельный ключ для Codex и Claude не нужен; доступные модели зависят от ключа, тарифа и текущих маршрутов.

| Клиент | Базовый адрес |
|---|---|
| Codex CLI и Codex Desktop (Responses API) | `https://codex.neuroapi.host/v1` |
| Claude Code и Claude Desktop (Anthropic API) | `https://claude.neuroapi.host` |
| Другие OpenAI-совместимые приложения | `https://neuroapi.host/v1` |

Не добавляйте `/responses` к базовому адресу Codex или `/v1/messages` к базовому адресу Claude: клиенты добавляют путь запроса сами. Уточните точный ID модели в [каталоге](https://neuroapi.host/price); название в старой сохранённой сессии может устареть.

## Вручную без установщика: временный ключ в терминале

Ниже приведён способ проверить подключение без изменения постоянных настроек ОС. Переменная среды доступна только этому терминалу и запущенным из него программам; не записывайте ключ в TOML, JSON, shell profile или историю команд. После закрытия терминала ввод потребуется повторить. Для постоянной настройки с защищённым хранением ключа используйте установщик или собственный credential helper.

macOS (Terminal):

```bash
printf 'Вставьте ключ NeuroAPI и нажмите Enter: '
read -r -s NEUROAPI_API_KEY
printf '\n'
export NEUROAPI_API_KEY
```

Windows (PowerShell):

```powershell
$secure = Read-Host 'Ключ NeuroAPI' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $env:NEUROAPI_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
Remove-Variable secure, ptr
```

Для Codex создайте файл `~/.codex/neuroapi-manual.config.toml` (Windows: `%USERPROFILE%\.codex\neuroapi-manual.config.toml`):

```toml
model = "gpt-6-sol" # замените на модель, доступную вашему ключу
model_provider = "neuroapi_manual"
web_search = "disabled"

[features]
multi_agent = false
goals = false
apps = false
browser_use = false

[model_providers.neuroapi_manual]
name = "NeuroAPI"
base_url = "https://codex.neuroapi.host/v1"
wire_api = "responses"
supports_websockets = true
env_key = "NEUROAPI_API_KEY"
```

Запустите `codex --profile neuroapi-manual`, проверьте `/debug-config` и выполните короткую задачу. Этот ручной профиль не получает управляемый каталог: встроенное меню Codex может содержать недоступные модели. Выбирайте проверенный ID явно. Файл профиля должен находиться в том же `CODEX_HOME`, с которым вы запускаете Codex; проектный `.codex/config.toml` не заменяет его.

Для Claude Code в том же терминале задайте адрес и модель, затем запустите `claude`:

```bash
export ANTHROPIC_API_KEY="$NEUROAPI_API_KEY"
export ANTHROPIC_BASE_URL="https://claude.neuroapi.host"
export ANTHROPIC_MODEL="claude-sonnet-5-5" # замените на доступную модель
claude
```

В PowerShell эквивалентные команды — `$env:ANTHROPIC_API_KEY = $env:NEUROAPI_API_KEY`, `$env:ANTHROPIC_BASE_URL = 'https://claude.neuroapi.host'`, `$env:ANTHROPIC_MODEL = 'claude-sonnet-5-5'`, затем `claude`. Проверьте `/status` и `/model`. Старые `ANTHROPIC_AUTH_TOKEN`, Bedrock/Vertex/Foundry overrides и пользовательские settings могут иметь иной приоритет; [порядок восстановления](reconnect-after-update.md) помогает найти конфликт. При выходе из тестового терминала удалите временный ключ (`unset NEUROAPI_API_KEY ANTHROPIC_API_KEY` на macOS; `Remove-Item Env:NEUROAPI_API_KEY, Env:ANTHROPIC_API_KEY` в PowerShell) или просто закройте окно.

Codex Desktop не наследует переменную из терминала при обычном запуске через GUI. Для постоянной настройки Desktop нужен credential helper, доступный приложению без терминала: безопасный готовый helper создаёт установщик. Точные пути и пример ручного `config.toml` после установки helper приведены в [пошаговых шаблонах](copy-paste-setup.md#codex-desktop-вручную-с-уже-сохранённым-ключом). Claude Desktop настраивается только в [официальной форме приложения](https://neuroapi.host/docs/claude-desktop).

## Codex CLI

Нужен Codex 0.158.0 или новее с profile-v2. Создаётся отдельный user-level profile:

- Windows: `%USERPROFILE%\.codex\neuroapi-host.config.toml`;
- macOS: `~/.codex/neuroapi-host.config.toml`.

Если `CODEX_HOME` уже задан, обе платформы используют `<CODEX_HOME>/neuroapi-host.config.toml` вместо стандартного пути. Setup не изменяет `CODEX_HOME`; используйте одинаковое значение при установке, запуске и удалении. Доступ к ключу по-прежнему идёт через прежний helper.

Основная конфигурация:

```toml
model_provider = "neuroapi"
web_search = "disabled"

[features]
multi_agent = false
goals = false
apps = false
browser_use = false

[model_providers.neuroapi]
name = "NeuroAPI"
base_url = "https://codex.neuroapi.host/v1"
wire_api = "responses"
supports_websockets = true

[model_providers.neuroapi.auth]
command = "/absolute/path/to/installer-owned-helper"
timeout_ms = 5000
refresh_interval_ms = 300000
```

На Windows `command` — `powershell.exe`, а helper и DPAPI secret передаются отдельными элементами `args`.

Codex 0.158.0 по умолчанию добавляет к каждому запросу hosted `web_search` и namespace-инструмент для multi-agent, даже при локальном чтении файла. NeuroAPI не объявляет эти инструменты как поддерживаемые для Codex-профиля: они требуют отдельного провайдерского контракта и тарификации. Профиль отключает только эти возможности, а чтение, правка и запуск команд остаются доступны. Возвращать их вручную в профиле можно лишь после отдельной проверки поддержки сервером.

Запуск: `codex-neuroapi`. Перед каждым запуском launcher получает `https://codex.neuroapi.host/v1/models` с обычным ключом NeuroAPI, проверяет ответ и передаёт приватный файл через `model_catalog_json` вместе с доступной моделью по умолчанию. Файл удаляется после завершения клиента. Проверка: `/debug-config` и `/model`.

Прямой `codex --profile neuroapi-host` пропускает этот механизм: command-auth discovery может подмешать встроенные модели. При ручной настройке без launcher можно задать собственный проверенный `model_catalog_json`; поддерживать его актуальность тогда нужно самостоятельно.

Project `.codex/config.toml` не подходит для provider/auth redirect: актуальный Codex игнорирует там `model_provider` и `model_providers` по соображениям безопасности.

## Codex Desktop (по отдельному согласию)

Установщик предлагает включить пользовательский Codex Desktop. В этом случае он сохраняет точную исходную копию `~/.codex/config.toml`, затем устанавливает в нём `model_provider = "neuroapi_agents"`, `model_catalog_json` с моделями, доступными введённому ключу, и подходящую модель по умолчанию. Провайдер использует `https://codex.neuroapi.host/v1`, Responses API, HTTP/SSE (`supports_websockets = false`) и тот же защищённый DPAPI/Keychain helper. Отдельный профиль CLI остаётся независимым.

Если в исходном файле есть конфликтующий провайдер, необычная форма root-настроек, неверный TOML либо файл изменился во время установки, setup останавливается без перезаписи. Повторная установка сохраняет первоначальную копию. При удалении проверяется хеш конфигурации: если пользователь изменил файл после setup, uninstaller не удаляет helper и ключ, чтобы не сломать действующую настройку. После установки перезапустите Codex Desktop и проверьте новую локальную задачу; полная инструкция: [Codex Desktop](https://neuroapi.host/docs/codex-desktop).

## HTTP/SSE для диагностики

Если соединение WebSocket блокируется вашей сетью, в секции `[model_providers.neuroapi]` созданного профиля замените `supports_websockets = true` на `supports_websockets = false`. Base URL остаётся `https://codex.neuroapi.host/v1`, auth helper и key storage не меняются. При повторном запуске setup управляемый профиль снова получит настройку по умолчанию `true`.

Если `https://codex.neuroapi.host/v1/models` или `/v1/responses` недоступны, проверьте DNS, сеть, ключ и [доступность сайта](https://neuroapi.host); локальное изменение `supports_websockets` не исправит ошибку `404` на endpoint. Общий `/v1` использует иной каталог и не заменяет выделенный адрес Codex для управляемого профиля.

## Claude Code

Нужен Claude Code 2.1.284 или новее. Существующий `~/.claude/settings.json` не меняется. Launcher получает `https://claude.neuroapi.host/client-settings`, проверяет разрешённые поля данных, добавляет локальный `apiKeyHelper` и передаёт приватный JSON через `claude --settings <file>`.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "apiKeyHelper": "/absolute/path/to/installer-owned-helper",
  "env": {
    "ANTHROPIC_BASE_URL": "https://claude.neuroapi.host"
  }
}
```

Это локальная основа настроек, а не полный runtime-файл. Сервер добавляет доступную `model`, `availableModels`, семейные defaults, пустой `fallbackModel` и `modelPicker.options` с `replaceBuiltInOptions: true`. Совместимые fallback-модели могут быть разрешены отдельно от меню. Проверка: `/status` и `/model`.

Настройки организации могут иметь более высокий приоритет; режим host-managed provider для этих launchers не поддерживается. Явные пользовательские аргументы остаются явными переопределениями. Меню не заменяет серверные ограничения ключа.

## Пути Windows

- state: `%LOCALAPPDATA%\NeuroAPIAgents`;
- ciphertext: `%LOCALAPPDATA%\NeuroAPIAgents\secret\api-key.dpapi`;
- helper: `%LOCALAPPDATA%\NeuroAPIAgents\bin\get-neuroapi-key.ps1`;
- Claude settings: `%LOCALAPPDATA%\NeuroAPIAgents\config\claude-settings.json`;
- launchers: `%LOCALAPPDATA%\NeuroAPIAgents\bin`;
- Codex profile: `%USERPROFILE%\.codex\neuroapi-host.config.toml`.
- Codex Desktop (опционально): `%USERPROFILE%\.codex\config.toml`, резервная копия и каталог в `%LOCALAPPDATA%\NeuroAPIAgents\config`.

Setup добавляет только launcher directory в пользовательский `PATH`.

## Пути macOS

- state: `~/.local/share/neuroapi-agents`;
- helper: `~/.local/share/neuroapi-agents/bin/get-neuroapi-key.sh`;
- Claude settings: `~/.local/share/neuroapi-agents/config/claude-settings.json`;
- launchers: `~/.local/bin/codex-neuroapi`, `~/.local/bin/claude-neuroapi`;
- Codex profile: `~/.codex/neuroapi-host.config.toml`;
- Codex Desktop (опционально): `~/.codex/config.toml`, резервная копия и каталог в `~/.local/share/neuroapi-agents/config`;
- Keychain service: `host.neuroapi.agents.api-key`.

Setup не меняет `.zprofile`, `.zshrc`, `.bash_profile` или системный `PATH`.

## Модели

Конкретные IDs выбирает сервер из опубликованных моделей с учётом ключа, тарифа и совместимости протокола. В установщике больше нет фиксированной основной модели. Ошибка загрузки, пустой список, неподходящая версия клиента или неверная схема останавливают запуск с понятным сообщением: старый список не используется.

Рекомендуемый серверный порядок: `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-sonnet-5`, `claude-fable-5-1`; для Codex — `gpt-6-sol`, `gpt-6-astra`, `gpt-6-luna`. Список зависит от опубликованных моделей, совместимого маршрута и прав ключа. Сохранённая администратором настройка каталога имеет приоритет над этим порядком.

`ANTHROPIC_DEFAULT_HAIKU_MODEL` используется Claude Code также для фоновых запросов. При отсутствии рекомендованной Haiku сервер назначает доступную модель Sonnet либо основную модель из меню; установщик принимает такое назначение только внутри опубликованного allowlist и рекомендованного меню. Списание идёт по фактической модели и может быть выше стоимости Haiku.

Специальный ключ не нужен. Можно подключаться вручную через обычный API: сервер распознаёт известные заголовки Codex/Claude на `/v1/models`. Однако клиент должен сам запросить каталог, а встроенные варианты могут сохраниться. Управляемые launchers — дополнительный способ получить заданное меню, а не условие доступа к API.

## Официальные контракты

- [Codex custom model providers](https://developers.openai.com/codex/config-advanced/#custom-model-providers)
- [Codex configuration reference](https://developers.openai.com/codex/config-reference/)
- [Claude Code gateway connection](https://code.claude.com/docs/en/llm-gateway-connect)
- [Claude Code settings](https://code.claude.com/docs/en/settings)
