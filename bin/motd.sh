#!/bin/sh

upseconds=$(/usr/bin/cut -d. -f1 /proc/uptime)
read one five fifteen rest < /proc/loadavg
echo "
$(figlet ${SERVER_NAME-$(hostname)})

$(date +"%A, %e %B %Y, %r")
Uptime...........: uptime=$(printf "%d days, %02dh%02dm%02ds" "$(($upseconds/86400))" "$(($upseconds/3600%24))" "$(($upseconds/60%60))" "$(($upseconds%60))")
Memory...........: $(cat /proc/meminfo | grep MemFree | awk {'print $2'})kB (Free) / $(cat /proc/meminfo | grep MemTotal | awk {'print $2'})kB (Total)
Load Averages....: $one, $five, $fifteen (1, 5, 15 min)
IP Addresses.....: $(ip a | grep glo | awk '{print $2}' | head -1 | cut -f1 -d/)
"