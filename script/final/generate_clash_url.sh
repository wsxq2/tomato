#!/bin/bash
#
# 根据服务端 json 配置文件生成 clash 订阅
#

# 当命令返回非 0 或使用未设置变量时强行退出
set -eu

# 调试开关（显示执行的命令）
set -x


declare -A IP_PORTS=(
["sub.wsxq2.xyz"]="26635"
["gj.wsxq2.xyz"]="26635"
)
declare -A IP_CONFIG_FILES=(
["sub.wsxq2.xyz"]="/usr/local/etc/v2ray/config.json"
["gj.wsxq2.xyz"]="/usr/local/etc/v2ray/config.json"
)


function urlencode(){
    python -c "import urllib.parse; print(urllib.parse.quote('''$1''', safe=''))"
}

echo -n > urls.txt
i=0
for ip in ${!IP_PORTS[@]}; do
    scp -P${IP_PORTS[$ip]} "root@$ip:${IP_CONFIG_FILES[$ip]}" $ip.json
    [[ i -eq 0 ]] && pipechar='' || pipechar='|'
    echo -n "$pipechar$(./json2link.py -t v2ray -j $ip.json)" >> urls.txt
    (( ++i ))
done
url=$(urlencode "`cat urls.txt`")

wget -O clash.yml "http://127.0.0.1:25500/sub?target=clash&url=$url"

scp -P26635 clash.yml root@sub.wsxq2.xyz:/usr/share/nginx/html/

rm -rf urls.txt *.json clash.yml

