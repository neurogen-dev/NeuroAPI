# Модель безопасности установщиков

## Цель

Установщики снижают риск случайно положить API-ключ NeuroAPI в Git, `.env`, TOML, JSON, историю shell или аргументы процесса. Они не превращают скомпрометированный компьютер в доверенную среду.

## Поток ключа

Windows:

1. `Read-Host -AsSecureString` получает ключ без обычной строки в setup-скрипте.
2. `ConvertFrom-SecureString` без `-Key` создаёт DPAPI-ciphertext для текущего пользователя и компьютера.
3. Codex/Claude вызывают короткий helper.
4. Helper расшифровывает значение в своём процессе, печатает только токен в stdout и очищает BSTR.

macOS:

1. Перед записью setup отказывается перезаписывать совпавший Keychain item без
   installer-owned marker.
2. Setup вызывает `/usr/bin/security add-generic-password ... -w`, причём `-w` стоит последним.
3. Штатная утилита Keychain сама показывает prompt; shell-скрипт не получает ключ в переменную и не передаёт его аргументом.
4. Helper выполняет `security find-generic-password ... -w`, которое печатает только password value.

## Что защищено

- случайный commit или upload конфигурации;
- чтение секретов из обычных JSON/TOML/.env файлов;
- история команд с ключом;
- просмотр аргументов setup-процесса;
- перезапись существующего профиля Codex или launcher без ownership-маркера;
- широкое удаление чужих файлов uninstall-скриптом.

## Что не защищено

- вредоносный процесс с правами того же пользователя;
- захват памяти процесса helper, Codex CLI или Claude Code;
- подмена самих бинарников `codex` или `claude` в `PATH`;
- компрометация ОС, браузера, GitHub-аккаунта или NeuroAPI-аккаунта;
- утечка данных, которые пользователь сам отправляет модели в запросе;
- уязвимости сторонних Codex CLI, Claude Code, PowerShell, Keychain или DPAPI.

Любой API-клиент должен получить plaintext-токен перед HTTP-запросом. Защищённое хранилище уменьшает время и места постоянного хранения, но не устраняет этот runtime boundary.

## Сетевое поведение

Setup и uninstall не вызывают NeuroAPI и не валидируют ключ по сети. После установки запросы отправляют официальные клиенты:

- Codex custom provider: `https://neuroapi.host/v1`;
- Claude Code gateway: `https://neuroapi.host`.

## Границы файлов

Windows удаляет рекурсивно только точный `%LOCALAPPDATA%\NeuroAPIAgents`, если внутри есть корректный marker. Профиль в `%USERPROFILE%\.codex` удаляется отдельно и только со своим sibling-marker.

macOS удаляет рекурсивно только точный `~/.local/share/neuroapi-agents` с корректным marker. Профиль и два launcher удаляются отдельно, каждый только при наличии своего marker. Keychain item удаляется только при наличии отдельного marker внутри installer-owned state.

Custom paths доступны только test mode и не используются публичными wrappers.

## Почему используются helpers

- Codex официально поддерживает `[model_providers.<id>.auth]` с командой, печатающей bearer token в stdout.
- Claude Code официально поддерживает `apiKeyHelper`.
- Поэтому секрет не требуется сохранять в user/project config.

## Проверка исходников

Перед запуском:

1. скачайте ZIP именно из `neurogen-dev/NeuroAPI`;
2. изучите root wrapper и файлы в `scripts/windows` или `scripts/macos`;
3. проверьте GitHub Actions для нужного commit;
4. не запускайте копию из неизвестного mirror.

Для сообщения об уязвимости используйте [SECURITY.md](../SECURITY.md).
