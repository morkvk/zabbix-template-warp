#!/bin/bash
# Проверяет статус warp-cli с использованием sudo и возвращает текстовый статус
STATUS=$(sudo /usr/bin/warp-cli status | grep -o "Connected\|Disconnected" || echo "Unk>
echo "$STATUS"
