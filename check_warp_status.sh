#!/bin/bash
# Проверяет статус warp-cli с использованием sudo и возвращает текстовый статус
if ! command -v warp-cli &>/dev/null; then
    echo "Unknown: warp-cli not found"
    exit 1
fi

STATUS=$(sudo /usr/bin/warp-cli status 2>/dev/null | grep -o "Connected\|Disconnected" || echo "Unknown")
echo "$STATUS"
