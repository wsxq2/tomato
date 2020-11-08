#!/usr/bin/env bash
#set -uo pipefail
IFS=$'\n\t'

#set -x

tcp_port=(`ss -ntl | awk -F' ' '{print $4;}'|grep -v 'Local\|127\.0\.0\.1\|::1'|awk -F: '{print $NF}'|sort |uniq`)
udp_port=(`ss -nul | awk -F' ' '{print $4;}'|grep -v 'Local\|127\.0\.0\.1\|::1'|awk -F: '{print $NF}'|sort |uniq`)
#tcp_port=(443 26635)
#udp_port=()


echo "${tcp_port[@]}"
echo "${udp_port[@]}"
systemctl status firewalld > /dev/null 2>&1
if [ $? -eq 0 ]; then
    for port in "${tcp_port[@]}"; do
        firewall-cmd --permanent --zone=public --add-port=${port}/tcp
    done
    for port in "${udp_port[@]}"; do
        firewall-cmd --permanent --zone=public --add-port=${port}/udp
    done
    firewall-cmd --reload

else
    echo -e "firewalld looks like not running or not installed, please enable port manually if necessary."
fi
