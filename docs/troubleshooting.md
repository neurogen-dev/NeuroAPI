# Решение проблем

## `codex-neuroapi` или `claude-neuroapi` не найдены

Windows: откройте новый терминал после установки. Проверьте наличие `%LOCALAPPDATA%\NeuroAPIAgents\bin` в пользовательском `PATH`.

macOS: используйте полный путь `~/.local/bin/codex-neuroapi`. Установщик намеренно не редактирует shell profile.

## Codex не видит provider

Запустите именно `codex-neuroapi`, затем `/debug-config`. Проверьте:

- profile `neuroapi-host`;
- provider `neuroapi`;
- base URL `https://neuroapi.host/v1`;
- `wire_api = "responses"`.

Если `~/.codex/neuroapi-host.config.toml` существовал до установки без ownership-marker, setup должен отказать, а не перезаписать его.

## Claude Code использует другой URL или credential

Запустите именно `claude-neuroapi`, затем `/status`. Launcher передаёт isolated settings через `--settings`, имеющий приоритет над user/project settings для совпадающих ключей.

## `401` или неверный ключ

Повторно запустите setup-файл и введите новый ключ. Не вставляйте ключ в issue или screenshot.

Windows DPAPI-ciphertext можно расшифровать только в подходящем user/machine context. После переноса на другой компьютер запустите setup заново.

macOS может показать системный запрос доступа к Keychain. Проверьте, что запускается `/usr/bin/security`, и подтвердите доступ только для ожидаемого локального процесса.

## `model not found`

Defaults установщика могут отстать от живого каталога. Проверьте [модели и цены](https://neuroapi.host/price) либо `GET /v1/models`, затем обновите репозиторий. Не заменяйте модель на случайное имя: Codex дополнительно требует Responses-совместимость.

## macOS блокирует `.command`

Убедитесь, что файл скачан из `neurogen-dev/NeuroAPI`. Выполните:

```bash
chmod +x setup-macos.command
./setup-macos.command
```

Если Gatekeeper всё ещё блокирует запуск, откройте файл через Finder → правый клик → Open. Не отключайте Gatekeeper глобально.

## Установка отказывается перезаписывать файл

Это защитный механизм. Переместите или переименуйте конфликтующий user-owned файл вручную после проверки. Не создавайте ownership-marker самостоятельно.

## Удаление отменено

Windows и macOS требуют точное подтверждение `DELETE`. Это предотвращает случайное удаление локально сохранённого ключа.

## Сообщить об ошибке

Обычные ошибки можно описать в GitHub Issues без API-ключа. Уязвимости и credential-handling проблемы отправляйте по [SECURITY.md](../SECURITY.md).
