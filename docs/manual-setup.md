# Что настраивают установщики

Эта страница нужна для аудита и ручного восстановления. Рекомендуемый путь — root setup-файл для вашей ОС.

## Codex CLI

Создаётся отдельный user-level profile:

- Windows: `%USERPROFILE%\.codex\neuroapi-host.config.toml`;
- macOS: `~/.codex/neuroapi-host.config.toml`.

Основная конфигурация:

```toml
model = "gpt-5.6-sol"
model_provider = "neuroapi"

[model_providers.neuroapi]
name = "NeuroAPI"
base_url = "https://neuroapi.host/v1"
wire_api = "responses"

[model_providers.neuroapi.auth]
command = "/absolute/path/to/installer-owned-helper"
timeout_ms = 5000
refresh_interval_ms = 300000
```

На Windows `command` — `powershell.exe`, а helper и DPAPI secret передаются отдельными элементами `args`.

Запуск: `codex --profile neuroapi-host`. Проверка: `/debug-config`.

Project `.codex/config.toml` не подходит для provider/auth redirect: актуальный Codex игнорирует там `model_provider` и `model_providers` по соображениям безопасности.

## Claude Code

Существующий `~/.claude/settings.json` не меняется. Launcher передаёт отдельный installer-owned JSON через `claude --settings <file>`.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "apiKeyHelper": "/absolute/path/to/installer-owned-helper",
  "env": {
    "ANTHROPIC_BASE_URL": "https://neuroapi.host",
    "ANTHROPIC_MODEL": "claude-sonnet-4-5"
  }
}
```

Проверка: `/status`.

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

`gpt-5.6-sol` и `claude-sonnet-4-5` — текущие defaults этого репозитория, а не бессрочная гарантия каталога. Точный доступ зависит от опубликованных моделей и вашего ключа. Проверяйте [каталог](https://neuroapi.host/price) или `GET https://neuroapi.host/v1/models` со своим ключом.

## Официальные контракты

- [Codex custom model providers](https://developers.openai.com/codex/config-advanced/#custom-model-providers)
- [Codex configuration reference](https://developers.openai.com/codex/config-reference/)
- [Claude Code gateway connection](https://code.claude.com/docs/en/llm-gateway-connect)
- [Claude Code settings](https://code.claude.com/docs/en/settings)
