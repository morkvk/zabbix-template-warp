curl -sL https://raw.githubusercontent.com/morkvk/zabbix-template-warp/refs/heads/main/warp.sh | bash

---------------------------------------------------------------

warp.conf -> /etc/zabbix/zabbix_agent2.d/warp.conf

check_warp_status.sh /etc/zabbix/scripts/check_warp_status.sh:

---------------------------------------------------------------


/etc/zabbix/zabbix_agent2.d/warp.conf:

      UserParameter=warp.status,/etc/zabbix/scripts/check_warp_status.sh


---------------------------------------------------------------
Обязательно:

sudo mkdir -p /var/log/zabbix

sudo chown -R zabbix:zabbix /var/log/zabbix

sudo chmod 750 /var/log/zabbix

sudo -u zabbix touch /var/log/zabbix/warp_status.log

sudo chown zabbix:zabbix /var/log/zabbix/warp_status.log

sudo chmod 640 /var/log/zabbix/warp_status.log
