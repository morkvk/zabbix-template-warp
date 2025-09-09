curl -sL https://raw.githubusercontent.com/morkvk/zabbix-template-warp/refs/heads/main/warp.sh | bash

---------------------------------------------------------------

warp.conf -> /etc/zabbix/zabbix_agent2.d/warp.conf

check_warp_status.sh /etc/zabbix/scripts/check_warp_status.sh:

---------------------------------------------------------------

check_warp_status.sh /etc/zabbix/scripts/check_warp_status.sh:

      #!/bin/bash
      
      if ! command -v warp-cli &>/dev/null; then
          echo "Unknown: warp-cli not found"
          exit 1
      fi
      
      STATUS=$(sudo /usr/bin/warp-cli status 2>/dev/null | grep -o "Connected\|Disconnected" || echo "Unknown")
      echo "$STATUS"

---------------------------------------------------------------

/etc/zabbix/zabbix_agent2.d/warp.conf:

      UserParameter=warp.status,/etc/zabbix/scripts/check_warp_status.sh
