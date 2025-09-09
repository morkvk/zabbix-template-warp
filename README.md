curl -sL https://raw.githubusercontent.com/morkvk/zabbix-template-warp/refs/heads/main/warp.sh | bash

---------------------------------------------------------------

warp.conf -> /etc/zabbix/zabbix_agent2.d/warp.conf

check_warp_status.sh /etc/zabbix/scripts/check_warp_status.sh:

---------------------------------------------------------------

check_warp_status.sh /etc/zabbix/scripts/check_warp_status.sh:

      #!/bin/bash
      # Проверяет статус WARP через curl с использованием прокси на порту 40000 и возвращает текстовый статус для Zabbix
      
      # Проверка наличия curl
      if ! command -v curl &>/dev/null; then
          echo "Unknown: curl not found"
          exit 1
      fi
      
      # Проверка наличия warp-cli
      if ! command -v warp-cli &>/dev/null; then
          echo "Unknown: warp-cli not found"
          exit 1
      fi
      
      # Проверка статуса WARP через curl с прокси на порту 40000 и таймаутом 5 секунд
      CURL_OUTPUT=$(curl --proxy http://127.0.0.1:40000 --connect-timeout 5 --max-time 10 https://www.cloudflare.com/cdn-cgi/trace/ 2>>/var/log/zabbix/warp_status.log)
      if [[ $? -ne 0 ]]; then
          echo "Disconnected: curl failed to connect through proxy"
          exit 1
      fi
      
      WARP_STATUS=$(echo "$CURL_OUTPUT" | grep -o "warp=on\|warp=off" || echo "Unknown")
      if [[ "$WARP_STATUS" == "warp=on" ]]; then
          echo "Connected"
      elif [[ "$WARP_STATUS" == "warp=off" ]]; then
          echo "Disconnected: warp is off"
      else
          echo "Unknown: unable to parse warp status"
      fi

---------------------------------------------------------------

/etc/zabbix/zabbix_agent2.d/warp.conf:

      UserParameter=warp.status,/etc/zabbix/scripts/check_warp_status.sh
