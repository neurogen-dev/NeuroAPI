# Решение проблем

Терминальные launchers и графические приложения читают разные настройки. Codex Desktop можно подключить отдельным согласием в установщике или [вручную](https://neuroapi.host/docs/codex-desktop); Claude Desktop настраивается в [официальной форме приложения](https://neuroapi.host/docs/claude-desktop).

## Codex Desktop обращается к `chatgpt.com`

Проверьте пользовательский `~/.codex/config.toml`: `model_provider = "neuroapi_agents"`, `base_url = "https://codex.neuroapi.host/v1"`, `supports_websockets = false`. Перезапустите приложение и создайте **новую локальную** задачу. Старые задачи и облачные функции могут сохранять прежний маршрут. Если вы пропустили предложение установщика, запустите setup заново и согласитесь на подключение Desktop.

Если удаление останавливается из-за изменения `config.toml`, сначала сравните текущий файл с резервной копией в каталоге установщика. Это защищает ваши правки и сохраняет key helper до ручного разбора.

## `codex-neuroapi` или `claude-neuroapi` не найдены

Windows: откройте новый терминал после установки. Проверьте наличие `%LOCALAPPDATA%\NeuroAPIAgents\bin` в пользовательском `PATH`.

macOS: используйте полный путь `~/.local/bin/codex-neuroapi`. Установщик намеренно не редактирует shell profile.

## Codex не видит provider

Запустите именно `codex-neuroapi`, затем `/debug-config`. Проверьте:

- profile `neuroapi-host`;
- provider `neuroapi`;
- base URL `https://codex.neuroapi.host/v1`;
- `wire_api = "responses"`;
- `supports_websockets = true` (или `false` для диагностики HTTP/SSE).
- `web_search = "disabled"` и `[features]` с `multi_agent = false`, `goals = false`, `apps = false`, `browser_use = false`: без них Codex 0.158.0 может включить неподдерживаемые hosted/namespace-инструменты в обычный запрос к файлу и получить `effective_request_unsupported`.

Если `~/.codex/neuroapi-host.config.toml` существовал до установки без ownership-marker, setup должен отказать, а не перезаписать его.

## WebSocket не подключается

В `[model_providers.neuroapi]` файла `neuroapi-host.config.toml` временно установите `supports_websockets = false`, оставив base URL `/v1/codex`. Перезапустите `codex-neuroapi` и проверьте короткий запрос по HTTP/SSE. Не переносите ключ в TOML и не меняйте helper. Повторная установка восстановит `true`.

`404` на `/v1/codex/models` или `/v1/codex/responses` может означать, что серверное обновление ещё не опубликовано. Эта версия установщика должна распространяться только после проверки обоих адресов и WebSocket на сервере. Один fallback на HTTP не создаёт отсутствующий endpoint.

## Codex сообщает, что профиль не найден

Обновите Codex CLI. В `codex --help` описание `--profile` должно указывать на отдельный `<name>.config.toml`, а не на старую таблицу `[profiles.name]`. Проверьте профиль и ownership-marker в путях из [ручной настройки](manual-setup.md). Если у вас задан `CODEX_HOME`, установщик и uninstaller используют его для Codex-профиля, не меняя переменную. Запускайте setup, launcher и uninstall с одинаковым значением: изменение переменной не переносит ранее установленный профиль.

## Claude Code использует другой URL или credential

Запустите именно `claude-neuroapi`, затем `/status`. Launcher передаёт isolated settings через `--settings`, имеющий приоритет над user/project settings для совпадающих ключей.

## `401` или неверный ключ

Повторно запустите setup-файл и введите новый ключ. Не вставляйте ключ в issue или screenshot.

Windows DPAPI-ciphertext можно расшифровать только в подходящем user/machine context. После переноса на другой компьютер запустите setup заново.

macOS может показать системный запрос доступа к Keychain. Проверьте, что запускается `/usr/bin/security`, и подтвердите доступ только для ожидаемого локального процесса.

## `model not found`

Перезапустите launcher: он получает свежий список, доступный ключу. Проверьте явный `--model` и сохранённую модель старой сессии. Если список пуст или серверные endpoints ещё не опубликованы, launcher остановится; это не повод подставлять случайный ID. Codex дополнительно требует Responses-совместимость.

## Каталог не загружается или список пуст

Проверьте ключ, соединение и ограничения моделей/тарифа. Для этой версии нужны `/v1/codex/models` и `/v1/claude-code/client-settings`; обновление установщика само по себе не создаёт их на сервере. Ответы `401`, `403`, redirects, слишком большой/неправильный JSON и пустой список не заменяются локальным старым каталогом. Серверное обновление должно быть выпущено до распространения установщика.

## В меню всё ещё есть другие модели

Запуск напрямую через `codex`/`claude` обходит managed launcher. Обычное discovery может дополнять встроенный список. Даже в управляемом режиме Claude сохраняет строки Default/текущей модели, а корпоративные настройки и явные CLI-переопределения могут иметь приоритет. Launcher не обходит host-managed provider mode: для него нужна настройка со стороны управляющего приложения.

## macOS блокирует `.command`

Убедитесь, что файл скачан из `neurogen-dev/NeuroAPI`. Выполните:

```bash
bash setup-macos.command
```

Если Gatekeeper всё ещё блокирует запуск, откройте файл через Finder → правый клик → Open. Не отключайте Gatekeeper глобально.

## Установка отказывается перезаписывать файл

Это защитный механизм. Переместите или переименуйте конфликтующий user-owned файл вручную после проверки. Не создавайте ownership-marker самостоятельно.

## Удаление отменено

Windows и macOS требуют точное подтверждение `DELETE`. Это предотвращает случайное удаление локально сохранённого ключа.

## Сообщить об ошибке

Обычные ошибки можно описать в GitHub Issues без API-ключа. Уязвимости и credential-handling проблемы отправляйте по [SECURITY.md](../SECURITY.md).
