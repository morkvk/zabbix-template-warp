#!/bin/bash
# Exit on any error
set -e

# Define Zabbix configuration file path (if not set, define a default)
ZABBIX_CONF=${ZABBIX_CONF:-/etc/zabbix/zabbix_agent2.conf}

####################### Удалить контейнер

# Проверяем, существует ли контейнер с именем warp
if docker ps -a --format '{{.Names}}' | grep -q "^warp$"; then
    # Останавливаем контейнер
    docker stop warp
    # Удаляем контейнер
    docker rm warp
    echo "Контейнер warp успешно удален"
else
    echo "Контейнер warp не найден"
fi

#######################

# Update package lists
apt update

# Install required packages
apt install gpg gnupg sudo curl -y

# Install Zabbix agent to create zabbix user and group
echo "Installing Zabbix agent..."
DEBIAN_FRONTEND=noninteractive apt install zabbix-agent2 -y

# Add Cloudflare WARP GPG key
curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

# Add Cloudflare WARP repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ bookworm main" | tee /etc/apt/sources.list.d/cloudflare-client.list

# Update package lists again
apt update

# Install Cloudflare WARP non-interactively
DEBIAN_FRONTEND=noninteractive apt install cloudflare-warp -y

# Ensure WARP service is running
echo "Starting WARP service..."
systemctl enable warp-svc
systemctl start warp-svc

# Wait for WARP service to be fully up (avoid IPC timeout)
for i in {1..5}; do
    if systemctl is-active --quiet warp-svc; then
        echo "WARP service is running"
        break
    else
        echo "Waiting for WARP service to start... ($i/5)"
        sleep 2
    fi
done

# Check if WARP service is running, fail if not
if ! systemctl is-active --quiet warp-svc; then
    echo "Error: WARP service failed to start. Check logs with 'journalctl -u warp-svc'."
    exit 1
fi

# Delete old WARP registration if it exists
echo "Removing old WARP registration if it exists..."
echo "y" | warp-cli registration delete || {
    echo "No old registration found or deletion failed, proceeding..."
}

# Register WARP client with automatic TOS acceptance
echo "Registering WARP client..."
echo "y" | warp-cli --accept-tos registration new || {
    echo "Error during WARP registration. Retrying..."
    sleep 2
    echo "y" | warp-cli --accept-tos registration new || {
        echo "Error: WARP registration failed after retry. Check logs."
        exit 1
    }
}

# Set WARP to proxy mode with automatic confirmation
echo "Setting WARP to proxy mode..."
echo "y" | warp-cli mode proxy || {
    echo "Failed to set proxy mode, but proceeding..."
}

# Set proxy port to 40000
warp-cli proxy port 40000

# Connect WARP
warp-cli connect

# Set permissions for Zabbix configuration file
if id "zabbix" >/dev/null 2>&1; then
    chown zabbix:zabbix "$ZABBIX_CONF"
    chmod 644 "$ZABBIX_CONF"
else
    echo "Warning: User 'zabbix' does not exist. Skipping chown for $ZABBIX_CONF."
    chmod 644 "$ZABBIX_CONF"
fi

# Restart Zabbix agent if installed
if systemctl is-active --quiet zabbix-agent2.service; then
    systemctl restart zabbix-agent2.service
else
    echo "Warning: Zabbix agent2 service not found. Skipping restart."
fi

# Verify script execution
echo "Cloudflare WARP installation, configuration, and Zabbix integration completed."
