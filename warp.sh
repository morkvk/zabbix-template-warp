#!/bin/bash

# Выход при любой ошибке
set -e

# Функция для проверки существования команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Функция для получения IP-адреса
get_ip_address() {
    local ip
    ip=$(ip -4 addr show | grep inet | awk '{print $2}' | cut -d'/' -f1 | grep -v '127.0.0.1' | head -n 1)
    if [ -z "$ip" ]; then
        echo "Ошибка: не удалось определить IP-адрес сервера" >&2
        exit 1
    fi
    echo "$ip"
}

# Функция для проверки правил nftables и определения inbound
get_inbound_suffix() {
    if ! command_exists nft; then
        echo "Ошибка: команда nft не найдена, невозможно определить inbound-суффикс" >&2
        exit 1
    fi
    local nft_rule
    nft_rule=$(nft list ruleset 2>/dev/null | grep -E 'tcp dport \{?\s*(7891|7892|7893|7894|7895|7901|7601|7701)\s*\}? accept' || true)
    if [[ $nft_rule =~ "tcp dport 7891 accept" || $nft_rule =~ "tcp dport { 7891" ]]; then
        echo "inbound1"
    elif [[ $nft_rule =~ "tcp dport 7892 accept" || $nft_rule =~ "tcp dport { 7892" ]]; then
        echo "inbound2"
    elif [[ $nft_rule =~ "tcp dport 7893 accept" || $nft_rule =~ "tcp dport { 7893" ]]; then
        echo "inbound3"
    elif [[ $nft_rule =~ "tcp dport 7894 accept" || $nft_rule =~ "tcp dport { 7894" ]]; then
        echo "inbound4"
    elif [[ $nft_rule =~ "tcp dport 7895 accept" || $nft_rule =~ "tcp dport { 7895" ]]; then
        echo "inbound5"
    elif [[ $nft_rule =~ "tcp dport 7901 accept" || $nft_rule =~ "tcp dport { 7901" ]]; then
        echo "inbound_usa"
    elif [[ $nft_rule =~ "tcp dport 7601 accept" || $nft_rule =~ "tcp dport { 7601" ]]; then
        echo "inbound_de"
    elif [[ $nft_rule =~ "tcp dport 7701 accept" || $nft_rule =~ "tcp dport { 7701" ]]; then
        echo "inbound_ru"
    else
        echo "Ошибка: не найдено подходящих правил nftables для портов 7891, 7892, 7893, 7894, 7901, 7601 или 7701" >&2
        exit 1
    fi
}

# Формирование HOST_ALIAS
echo "Определяем IP-адрес и inbound-суффикс..."
IP_ADDRESS=$(get_ip_address)
INBOUND_SUFFIX=$(get_inbound_suffix)
HOST_ALIAS="${IP_ADDRESS}_${INBOUND_SUFFIX}"
echo "HOST_ALIAS установлен как: $HOST_ALIAS"

# Переменные
ZABBIX_DEB_URL="https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian12_all.deb"
ZABBIX_DEB_PATH="/tmp/zabbix-release_latest+debian12_all.deb"
ZABBIX_CONF="/etc/zabbix/zabbix_agent2.conf"
ZABBIX_WARP_CONF="/etc/zabbix/zabbix_agent2.d/warp.conf"
ZABBIX_SCRIPT="/etc/zabbix/scripts/check_warp_status.sh"
SUDOERS_FILE="/etc/sudoers.d/zabbix_warp"

# Скачиваем пакет Zabbix, если он ещё не скачан
if [ ! -f "$ZABBIX_DEB_PATH" ]; then
    echo "Скачиваем пакет Zabbix..."
    wget "$ZABBIX_DEB_URL" -O "$ZABBIX_DEB_PATH"
fi

# Устанавливаем скачанный пакет
echo "Устанавливаем пакет Zabbix..."
dpkg -i "$ZABBIX_DEB_PATH"

# Обновляем кэш apt
echo "Обновляем кэш apt..."
apt-get update

# Устанавливаем Zabbix Agent 2 и плагины
echo "Устанавливаем Zabbix Agent 2 и плагины..."
apt-get install -y zabbix-agent2 zabbix-agent2-plugin-*

# Проверяем существование группы docker, создаём, если отсутствует
echo "Создаём группу docker, если не существует..."
groupadd -f docker

# Добавляем пользователя zabbix в группу docker
echo "Добавляем пользователя zabbix в группу docker..."
usermod -aG docker zabbix
USER_MOD_CHANGED=$?  # Сохраняем статус изменения

# Проверяем существование конфигурационного файла
echo "Проверяем наличие конфигурационного файла Zabbix..."
if [ -f "$ZABBIX_CONF" ]; then
    # Обновляем параметр Server
    echo "Обновляем параметр Server в конфигурации..."
    sed -i 's/^Server=.*/Server=77.238.245.21/' "$ZABBIX_CONF" || \
        echo "Server=77.238.245.21" >> "$ZABBIX_CONF"

    # Обновляем параметр ListenPort
    echo "Обновляем параметр ListenPort в конфигурации..."
    sed -i 's/^#\s*ListenPort=.*/ListenPort=10077/' "$ZABBIX_CONF" || \
        echo "ListenPort=10077" >> "$ZABBIX_CONF"

    # Обновляем параметр ServerActive
    echo "Обновляем параметр ServerActive в конфигурации..."
    sed -i 's/^ServerActive=.*/ServerActive=77.238.245.21:10051/' "$ZABBIX_CONF" || \
        echo "ServerActive=77.238.245.21:10051" >> "$ZABBIX_CONF"

    # Устанавливаем Hostname
    echo "Устанавливаем Hostname в конфигурации..."
    if grep -q "^#*Hostname=" "$ZABBIX_CONF"; then
        sed -i "s/^#*Hostname=.*/Hostname=$HOST_ALIAS/" "$ZABBIX_CONF"
    else
        echo "Hostname=$HOST_ALIAS" >> "$ZABBIX_CONF"
    fi

    # Устанавливаем HostMetadata
    echo "Устанавливаем HostMetadata в конфигурации..."
    if grep -q "^#*HostMetadata=" "$ZABBIX_CONF"; then
        sed -i "s/^#*HostMetadata=.*/HostMetadata=c1d7a08/" "$ZABBIX_CONF"
    else
        echo "HostMetadata=c1d7a08" >> "$ZABBIX_CONF"
    fi
fi

# Проверяем наличие warp-cli
echo "Проверяем наличие команды warp-cli..."
if ! command_exists warp-cli; then
    echo "Ошибка: команда warp-cli не найдена. Установите warp-cli перед продолжением." >&2
    exit 1
fi

# Настраиваем sudo для warp-cli
echo "Настраиваем sudo для выполнения warp-cli пользователем zabbix..."
cat << EOF > "$SUDOERS_FILE"
zabbix ALL=(ALL) NOPASSWD: /usr/bin/warp-cli status
EOF
chmod 440 "$SUDOERS_FILE"
chown root:root "$SUDOERS_FILE"

# Создаём директорию для скриптов Zabbix
echo "Создаём директорию для скриптов Zabbix..."
mkdir -p "$(dirname "$ZABBIX_SCRIPT")"

# Создаём или перезаписываем скрипт check_warp_status.sh
echo "Создаём или перезаписываем скрипт check_warp_status.sh..."
cat << 'EOF' > "$ZABBIX_SCRIPT"
#!/bin/bash
# Проверяет статус warp-cli с использованием sudo и возвращает текстовый статус
if ! command -v warp-cli &>/dev/null; then
    echo "Unknown: warp-cli not found"
    exit 1
fi

STATUS=$(sudo /usr/bin/warp-cli status 2>/dev/null | grep -o "Connected\|Disconnected" || echo "Unknown")
echo "$STATUS"
EOF

# Устанавливаем права доступа для скрипта
echo "Устанавливаем права доступа для скрипта..."
chown zabbix:zabbix "$ZABBIX_SCRIPT"
chmod 755 "$ZABBIX_SCRIPT"

# Создаём директорию для дополнительных конфигураций
echo "Создаём директорию для дополнительных конфигураций Zabbix..."
mkdir -p "$(dirname "$ZABBIX_WARP_CONF")"

# Добавляем UserParameter в отдельный файл конфигурации
echo "Создаём конфигурационный файл для UserParameter..."
cat << 'EOF' > "$ZABBIX_WARP_CONF"
UserParameter=warp.status,/etc/zabbix/scripts/check_warp_status.sh
EOF

# Устанавливаем правильные права доступа для файла конфигурации
echo "Устанавливаем права доступа для конфигурационного файла..."
chown zabbix:zabbix "$ZABBIX_WARP_CONF"
chmod 644 "$ZABBIX_WARP_CONF"

# Проверяем и добавляем директорию конфигураций в zabbix_agent2.conf
echo "Проверяем включение директории конфигураций в zabbix_agent2.conf..."
if ! grep -q "^Include=/etc/zabbix/zabbix_agent2.d/" "$ZABBIX_CONF"; then
    echo "Добавляем Include для директории конфигураций..."
    echo "Include=/etc/zabbix/zabbix_agent2.d/*.conf" >> "$ZABBIX_CONF"
fi

# Устанавливаем права доступа для основного конфигурационного файла
echo "Устанавливаем права доступа для основного конфигурационного файла..."
if id "zabbix" >/dev/null 2>&1; then
    chown zabbix:zabbix "$ZABBIX_CONF"
    chmod 644 "$ZABBIX_CONF"
else
    echo "Warning: User 'zabbix' does not exist. Skipping chown for $ZABBIX_CONF."
    chmod 644 "$ZABBIX_CONF"
fi

# Перезапускаем Zabbix Agent, если он установлен
echo "Проверяем и перезапускаем Zabbix Agent..."
if systemctl is-active --quiet zabbix-agent2.service; then
    systemctl restart zabbix-agent2.service
else
    echo "Warning: Zabbix agent2 service not found. Skipping restart."
fi

# Включаем и запускаем службу Zabbix Agent 2
echo "Включаем и запускаем службу Zabbix Agent 2..."
systemctl enable zabbix-agent2
systemctl start zabbix-agent2

# Проверяем выполнение скрипта
echo "Проверяем выполнение скрипта check_warp_status.sh..."
if sudo -u zabbix "$ZABBIX_SCRIPT" >/dev/null 2>&1; then
    echo "Скрипт check_warp_status.sh успешно выполнен."
else
    echo "Ошибка: скрипт check_warp_status.sh не удалось выполнить." >&2
    exit 1
fi

echo "Установка и настройка Zabbix Agent 2 завершена!"
