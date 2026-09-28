# Что настраивают установщики

Эта страница нужна для аудита и ручного восстановления. Рекомендуемый путь — root setup-файл для вашей ОС.

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
base_url = "https://neuroapi.host/v1/codex"
wire_api = "responses"
supports_websockets = true

[model_providers.neuroapi.auth]
command = "/absolute/path/to/installer-owned-helper"
timeout_ms = 5000
refresh_interval_ms = 300000
```

На Windows `command` — `powershell.exe`, а helper и DPAPI secret передаются отдельными элементами `args`.

Codex 0.158.0 по умолчанию добавляет к каждому запросу hosted `web_search` и namespace-инструмент для multi-agent, даже при локальном чтении файла. NeuroAPI не объявляет эти инструменты как поддерживаемые для Codex-профиля: они требуют отдельного провайдерского контракта и тарификации. Профиль отключает только эти возможности, а чтение, правка и запуск команд остаются доступны. Возвращать их вручную в профиле можно лишь после отдельной проверки поддержки сервером.

Запуск: `codex-neuroapi`. Перед каждым запуском launcher получает `/v1/codex/models` с обычным ключом NeuroAPI, проверяет ответ и передаёт приватный файл через `model_catalog_json` вместе с доступной моделью по умолчанию. Файл удаляется после завершения клиента. Проверка: `/debug-config` и `/model`.

Прямой `codex --profile neuroapi-host` пропускает этот механизм: command-auth discovery может подмешать встроенные модели. При ручной настройке без launcher можно задать собственный проверенный `model_catalog_json`; поддерживать его актуальность тогда нужно самостоятельно.

Project `.codex/config.toml` не подходит для provider/auth redirect: актуальный Codex игнорирует там `model_provider` и `model_providers` по соображениям безопасности.

## HTTP/SSE для диагностики

Если соединение WebSocket блокируется вашей сетью, в секции `[model_providers.neuroapi]` созданного профиля замените `supports_websockets = true` на `supports_websockets = false`. Base URL остаётся `https://neuroapi.host/v1/codex`, auth helper и key storage не меняются. При повторном запуске setup управляемый профиль снова получит настройку по умолчанию `true`.

Если сервер ещё не предоставляет `/v1/codex`, не распространяйте эту версию установщика: сначала требуется согласованный серверный выпуск. Возврат к общему `/v1` не решает несовпадение формата каталога при command-backed auth.

## Claude Code

Нужен Claude Code 2.1.284 или новее. Существующий `~/.claude/settings.json` не меняется. Launcher получает `/v1/claude-code/client-settings`, проверяет разрешённые поля данных, добавляет локальный `apiKeyHelper` и передаёт приватный JSON через `claude --settings <file>`.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "apiKeyHelper": "/absolute/path/to/installer-owned-helper",
  "env": {
    "ANTHROPIC_BASE_URL": "https://neuroapi.host/v1/claude-code"
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

Setup добавляет только launcher directory в пользовательский `PATH`.

## Пути macOS

- state: `~/.local/share/neuroapi-agents`;
- helper: `~/.local/share/neuroapi-agents/bin/get-neuroapi-key.sh`;
- Claude settings: `~/.local/share/neuroapi-agents/config/claude-settings.json`;
- launchers: `~/.local/bin/codex-neuroapi`, `~/.local/bin/claude-neuroapi`;
- Codex profile: `~/.codex/neuroapi-host.config.toml`;
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
