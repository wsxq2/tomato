#!/usr/bin/env bash

# 迁移主服务器的操作：
# 1. 修改 authorized_keys：用新的主服务器的公钥替换旧的
# 2. 迁移 subconverter:
#    1. 禁用旧的主服务器上的 subconverter 服务
#    2. 在新的主服务器上安装最新的 subconverter 服务
set -euo pipefail
IFS=$'\n\t'

#debug
set -x

ALL_LINK_FILE="all_link"
MAIN_SERVER="sub.wsxq2.xyz"
ALL_LINK_URL_ENCODED="https%3A%2F%2F$MAIN_SERVER%2Fall"
JSON2LINK_CMD="python3 /root/gfw/json2link.py -t all"
OUTPUT_PATH="/var/www/lighttpd"
declare -A IP_PORTS=(
["64.64.228.229"]=26635
["wsxq21.55555.io"]=26635
)

echo -n "">$ALL_LINK_FILE
for i in ${!IP_PORTS[@]}; do
    ssh -p${IP_PORTS[$i]} $i "$JSON2LINK_CMD"
    scp -P${IP_PORTS[$i]} "$i:/root/gfw/link" tmp
    cat tmp >> $ALL_LINK_FILE
done
rm -f tmp

sed -n -e '/^ss:/w ss.link' -e '/^ssr:/w ssr.link' -e '/^vmess:/w vmess.link' $ALL_LINK_FILE
base64 -w0 ss.link> ${OUTPUT_PATH}/ss
base64 -w0 ssr.link> ${OUTPUT_PATH}/ssr
base64 -w0 vmess.link> ${OUTPUT_PATH}/vmess
base64 -w0 $ALL_LINK_FILE > ${OUTPUT_PATH}/all
rm -f ss.link ssr.link vmess.link $ALL_LINK_FILE

wget -O ${OUTPUT_PATH}/clash.yml "http://127.0.0.1:25500/sub?target=clash&url=$ALL_LINK_URL_ENCODED"
wget -O ${OUTPUT_PATH}/surfboard.conf "http://127.0.0.1:25500/sub?target=surfboard&url=$ALL_LINK_URL_ENCODED"
sed -i -r -e "1,1{s/http[^ ]+/https:\/\/$MAIN_SERVER\/surfboard.conf/}" /var/www/lighttpd/surfboard.conf

