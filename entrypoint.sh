#!/bin/bash
LANG_VALUE="$LANG"

if [[ "$LANG_VALUE" == "en" ]]; then
    echo "Running $LANG version"
    python backend/webui_en.py
elif [[ "$LANG_VALUE" == "ru" ]]; then
    echo "Запускается $LANG версия"
    python backend/webui_ru.py
else
    echo "Недопустимое значение переменной окружения LANG. Поддерживаемые значения: en, ru"
    exit 1
fi
