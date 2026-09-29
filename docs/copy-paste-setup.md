# Ручное подключение: какие файлы открыть и что вставить

Эта альтернатива нужна, если вы хотите настроить клиенты сами. Для автоматического пути скачайте [установщик](../README.md#установка-в-один-запуск). Если уже пробовали подключение, сначала сохраните конфиги и пройдите [проверку старых настроек](reconnect-after-update.md). Команды ниже не записывают ключ в историю команд, TOML или JSON: его вводят скрыто в текущем терминале либо хранят через helper установщика.

## Что заменить в шаблонах

1. Создайте или откройте ключ на [странице API-ключей](https://neuroapi.host/login?redirect=/dashboard/tokens). Вводите **всю** строку, включая `sk-`, без слова `Bearer`. Не вставляйте настоящий ключ в примеры конфигов ниже.
2. Узнайте **точный ID** доступной ключу модели в [каталоге](https://neuroapi.host/price) или в ответе своего `/v1/models`. `gpt-6-sol` и `claude-sonnet-5-5` ниже — примеры, доступность которых зависит от вашего ключа и тарифа. Меняйте только значение `model` на фактически доступный ID.
3. Адрес Codex: `https://codex.neuroapi.host/v1`; адрес Claude: `https://claude.neuroapi.host`. Не дописывайте `/responses` или `/v1/messages` к **базовому** адресу клиента.

| Клиент | Файл или экран | Что меняется |
|---|---|---|
| Codex CLI | `~/.codex/neuroapi-manual.config.toml` или `%USERPROFILE%\.codex\neuroapi-manual.config.toml` | `model`, `model_provider`, `base_url`, `env_key` |
| Codex Desktop | `~/.codex/config.toml` или `%USERPROFILE%\.codex\config.toml` | root `model`/`model_provider` и секция провайдера; нужен защищённый helper |
| Claude Code | отдельный `~/.claude/neuroapi-manual-settings.json` или `%USERPROFILE%\.claude\neuroapi-manual-settings.json` | `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`; ключ только в терминале |
| Claude Desktop | `Developer → Configure Third-Party Inference` | Gateway URL, ключ и схема авторизации в форме приложения |

Если задан `CODEX_HOME`, профиль **CLI** кладите в `<CODEX_HOME>`. Обычный GUI Codex Desktop настраивается в пользовательском `~/.codex/config.toml` (`%USERPROFILE%\.codex\config.toml` на Windows). Не создавайте для Codex provider только в проектном `.codex/config.toml`: текущий клиент игнорирует там эти параметры по соображениям безопасности.

## Codex CLI без установщика

### 1. Введите ключ скрыто

macOS, Terminal (ключ вставляется **после** запуска команды и не попадает в историю):

```bash
printf 'Ключ NeuroAPI: '
read -r -s NEUROAPI_API_KEY
printf '\n'
export NEUROAPI_API_KEY
```

Windows, PowerShell:

```powershell
$secret = Read-Host 'Ключ NeuroAPI' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try { $env:NEUROAPI_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
Remove-Variable secret, ptr
```

Переменная существует только в этом терминале и его дочерних процессах. Не записывайте строку ключа через `export ...="sk-..."`, `setx` или в файл настроек.

### 2. Создайте отдельный профиль

macOS: `mkdir -p ~/.codex && nano ~/.codex/neuroapi-manual.config.toml`. Windows: `New-Item -ItemType Directory -Force "$HOME\.codex" | Out-Null; notepad "$HOME\.codex\neuroapi-manual.config.toml"`. Если установлен `CODEX_HOME`, откройте файл в нём. Вставьте весь блок:

```toml
model = "gpt-6-sol" # замените только ID модели, если вашему ключу доступна другая
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

Сохраните файл и **из того же терминала** запустите `codex --profile neuroapi-manual`. В клиенте проверьте `/debug-config`, затем поручите короткую файловую задачу. При проблеме с WebSocket замените только `supports_websockets = true` на `false`, перезапустите CLI и повторите задачу по HTTP/SSE. При ручном профиле меню Codex может содержать модели, которых нет у вашего ключа; используйте точный ID из каталога. После работы закройте терминал либо выполните `unset NEUROAPI_API_KEY` (macOS) / `Remove-Item Env:NEUROAPI_API_KEY` (PowerShell).

## Claude Code без установщика

В **том же терминале**, где временно введён `NEUROAPI_API_KEY`, создайте отдельный файл настроек. macOS: `mkdir -p ~/.claude && nano ~/.claude/neuroapi-manual-settings.json`. Windows: `New-Item -ItemType Directory -Force "$HOME\.claude" | Out-Null; notepad "$HOME\.claude\neuroapi-manual-settings.json"`. Вставьте:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://claude.neuroapi.host",
    "ANTHROPIC_MODEL": "claude-sonnet-5-5"
  }
}
```

Замените `claude-sonnet-5-5` точным доступным ID. Для запуска передайте ключ клиенту **только в текущей сессии**:

macOS:

```bash
export ANTHROPIC_API_KEY="$NEUROAPI_API_KEY"
claude --settings "$HOME/.claude/neuroapi-manual-settings.json"
```

Windows PowerShell:

```powershell
$env:ANTHROPIC_API_KEY = $env:NEUROAPI_API_KEY
claude --settings "$HOME\.claude\neuroapi-manual-settings.json"
```

В Claude Code проверьте `/status`: `Anthropic base URL` должен быть `https://claude.neuroapi.host`, источник credential — `ANTHROPIC_API_KEY`. Если вывод показывает другой URL, `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper` или claude.ai login, найдите старое переопределение в `~/.claude/settings.json`, переменных среды или политике организации; не удаляйте весь файл. После работы удалите переменные `ANTHROPIC_API_KEY` и `NEUROAPI_API_KEY` из терминала или закройте его. Для постоянного безопасного доступа используйте helper установщика: простое копирование ключа в `settings.json` оставляет его открытым текстом.

## Codex Desktop вручную с уже сохранённым ключом

Для обычного запуска Desktop из Dock/Start временная переменная терминала не подходит. Ниже — ручное редактирование **после** запуска setup-файла без опции Codex Desktop: setup уже сохранил ключ в Keychain/DPAPI и создал helper. Если setup уже настроил Desktop, повторно вставлять блок не нужно. Если установщика вообще не было, сперва используйте его для защищённого сохранения ключа или подготовьте собственный credential helper; запись ключа прямо в `config.toml` здесь не предлагается.

1. Полностью закройте Codex Desktop. Скопируйте существующий `config.toml` в резервную копию с датой. macOS: `cp -p ~/.codex/config.toml ~/.codex/config.toml.before-neuroapi-$(date +%Y%m%d-%H%M%S)` (если файла ещё нет, пропустите). Windows PowerShell: `Copy-Item "$HOME\.codex\config.toml" "$HOME\.codex\config.toml.before-neuroapi-$(Get-Date -Format yyyyMMdd-HHmmss)"` (если файл существует).
2. Проверьте наличие helper: macOS — `~/.local/share/neuroapi-agents/bin/get-neuroapi-key.sh`; Windows — `%LOCALAPPDATA%\NeuroAPIAgents\bin\get-neuroapi-key.ps1` и `%LOCALAPPDATA%\NeuroAPIAgents\secret\api-key.dpapi`. Не запускайте helper для диагностики с выводом на экран: он печатает секрет.
3. Откройте `~/.codex/config.toml` (Windows: `%USERPROFILE%\.codex\config.toml`). Если файл пустой, вставьте соответствующий блок ниже целиком. Если уже содержит настройки, **замените** существующие root `model` и `model_provider`, добавьте `web_search = "disabled"` в root, а секцию `[model_providers.neuroapi_manual_desktop]` с auth добавьте один раз в конец. Не создавайте второй `[features]`: обновите указанные поля внутри существующей секции. Не удаляйте другие провайдеры.

macOS: в `command` замените `ИМЯ_ПОЛЬЗОВАТЕЛЯ` на имя домашней папки из `echo "$HOME"` (например, `roman`):

```toml
model = "gpt-6-sol"
model_provider = "neuroapi_manual_desktop"
web_search = "disabled"

[features]
multi_agent = false
goals = false
apps = false
browser_use = false

[model_providers.neuroapi_manual_desktop]
name = "NeuroAPI"
base_url = "https://codex.neuroapi.host/v1"
wire_api = "responses"
supports_websockets = false

[model_providers.neuroapi_manual_desktop.auth]
command = "/Users/ИМЯ_ПОЛЬЗОВАТЕЛЯ/.local/share/neuroapi-agents/bin/get-neuroapi-key.sh"
timeout_ms = 5000
refresh_interval_ms = 300000
```

Windows: сначала выполните `$env:LOCALAPPDATA` в PowerShell. Подставьте **выведенный абсолютный путь** вместо `C:/Users/ИМЯ/AppData/Local` в обоих аргументах. В TOML удобно писать прямые слэши `/`; строку `%LOCALAPPDATA%` буквально вставлять нельзя:

```toml
model = "gpt-6-sol"
model_provider = "neuroapi_manual_desktop"
web_search = "disabled"

[features]
multi_agent = false
goals = false
apps = false
browser_use = false

[model_providers.neuroapi_manual_desktop]
name = "NeuroAPI"
base_url = "https://codex.neuroapi.host/v1"
wire_api = "responses"
supports_websockets = false

[model_providers.neuroapi_manual_desktop.auth]
command = "powershell.exe"
args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "C:/Users/ИМЯ/AppData/Local/NeuroAPIAgents/bin/get-neuroapi-key.ps1", "-SecretPath", "C:/Users/ИМЯ/AppData/Local/NeuroAPIAgents/secret/api-key.dpapi"]
timeout_ms = 5000
refresh_interval_ms = 300000
```

Также замените `model` на доступный ключу ID. Этот **ручной** Desktop-вариант не создаёт управляемый `model_catalog_json`, поэтому встроенный список моделей может содержать посторонние варианты. Перезапустите приложение, создайте **новую локальную** задачу и проверьте её в [истории NeuroAPI](https://neuroapi.host/dashboard/logs). Не удаляйте helper/ключ через uninstaller, пока Desktop-config ссылается на него. Если захотите перейти на автоматическое управление Desktop, сначала уберите ручную секцию и верните прежние root-настройки из сохранённой копии, затем повторите setup с опцией Desktop: иначе последующее удаление установщика может восстановить конфиг, который всё ещё ссылается на удаляемый helper.

## Claude Desktop вручную

Откройте приложение → `Developer` → `Configure Third-Party Inference`. В форме выберите inference provider `Gateway`, credential kind `Static API key`, укажите gateway base URL `https://claude.neuroapi.host`, вставьте **полный ключ** NeuroAPI в поле Gateway API key и выберите auth scheme `Bearer`. Сохраните, начните новый локальный чат и проверьте запрос в [истории NeuroAPI](https://neuroapi.host/dashboard/logs). Настройка Claude Code CLI на Desktop не переносится. Не редактируйте `claude_desktop_config.json`: это файл подключений MCP, а не настройки inference gateway. Подробности и актуальный вид формы: [наша инструкция](https://neuroapi.host/docs/claude-desktop) и [официальная инструкция Anthropic](https://claude.com/docs/third-party/claude-desktop/gateway).

## После любой ручной настройки

Проверьте реальную задачу и запись в [истории запросов NeuroAPI](https://neuroapi.host/dashboard/logs). Если запроса нет, клиент обращается к другому URL или использует другое удостоверение; проверьте `/debug-config` в Codex и `/status` в Claude Code. Если запрос есть, но завершился ошибкой, используйте [решение проблем](troubleshooting.md). Не публикуйте ключ, дамп полного конфига с секретами или raw HTTP-лог в issue.

Имена полей сверены с [официальным справочником Codex](https://learn.chatgpt.com/docs/config-file/config-reference), [инструкцией Anthropic для Claude Code gateway](https://code.claude.com/docs/en/llm-gateway-connect) и [инструкцией Anthropic для Claude Desktop gateway](https://claude.com/docs/third-party/claude-desktop/gateway).
