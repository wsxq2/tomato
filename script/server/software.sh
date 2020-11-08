#!/usr/bin/env bash
#
# 安装各种软件，主要包括 ss, ssr, v2ray
#
# 作者: wsxq2, wsxq2@qq.com
# 上次修改时间: 2020-11-08 14:58:17 +0800

# 调试选项
## 当命令返回非 0 时停止执行
set -e
## 当使用未定义变量时停止执行
set -u
## 显示执行的命令
set -x


SSH_PUBLICKEY_FILE='authorized_keys'
V2RAY_CONFIG_FILE='config.json.web'
CRONTAB_FILE='crontab.web'

SSH_PORT=26635
TO_BE_OPENED_PORTS=($SSH_PORT 443)

SHADOWSOCKS_ALL_URL="https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-all.sh"
declare -A SS_METHOD=(
["aes-256-gcm"]=1
["aes-192-gcm"]=2
["aes-128-gcm"]=3
["aes-256-ctr"]=4
["aes-192-ctr"]=5
["aes-128-ctr"]=6
["aes-256-cfb"]=7
["aes-192-cfb"]=8
["aes-128-cfb"]=9
["camellia-128-cfb"]=10
["camellia-192-cfb"]=11
["camellia-256-cfb"]=12
["xchacha20-ietf-poly1305"]=13
["chacha20-ietf-poly1305"]=14
["chacha20-ietf"]=15
["chacha20"]=16
["salsa20"]=17
["rc4-md5"]=18)
declare -A SS_SIMPLE_OBFS_OPTS=(["http"]=1 ["tls"]=2)

declare -A SSR_METHOD=(
["none"]=1
["aes-256-cfb"]=2
["aes-192-cfb"]=3
["aes-128-cfb"]=4
["aes-256-cfb8"]=5
["aes-192-cfb8"]=6
["aes-128-cfb8"]=7
["aes-256-ctr"]=8
["aes-192-ctr"]=9
["aes-128-ctr"]=10
["chacha20-ietf"]=11
["chacha20"]=12
["salsa20"]=13
["xchacha20"]=14
["xsalsa20"]=15
["rc4-md5"]=16
)
declare -A SSR_PROTOCOL=(
["origin"]=1
["verify_deflate"]=2
["auth_sha1_v4"]=3
["auth_sha1_v4_compatible"]=4
["auth_aes128_md5"]=5
["auth_aes128_sha1"]=6
["auth_chain_a"]=7
["auth_chain_b"]=8
["auth_chain_c"]=9
["auth_chain_d"]=10
["auth_chain_e"]=11
["auth_chain_f"]=12
)
declare -A SSR_OBFS=(
["plain"]=1
["http_simple"]=2
["http_simple_compatible"]=3
["http_post"]=4
["http_post_compatible"]=5
["tls1.2_ticket_auth"]=6
["tls1.2_ticket_auth_compatible"]=7
["tls1.2_ticket_fastauth"]=8
["tls1.2_ticket_fastauth_compatible"]=9
)

V2RAY_SS_METHOD='aes-256-gcm'

random_string()
{
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}

get_uuid(){
cat '/proc/sys/kernel/random/uuid'
}

random_port(){
    port=`echo -n $(( ( RANDOM % 40000 )  + 10000 ))`
    while [[ -n `ss -tuln | grep $port` ]]; do
        port=`echo -n $(( ( RANDOM % 40000 )  + 10000 ))`
    done
    TO_BE_OPENED_PORTS+=($port)
    echo -n "$port"
}

config_ssh(){
    cp "$SSH_PUBLICKEY_FILE" ~/.ssh/authorized_keys
    sed -i -r "s/^#?Port [0-9]+/Port $SSH_PORT/" /etc/ssh/sshd_config
    systemctl restart sshd
}

apply_my_profile(){
    yum install git -y
    local OLD_DIR=$PWD
    cd ~ && git clone https://github.com/wsxq2/MyProfile.git && cd .MyProfile && ./deploy.sh
    cd $OLD_DIR
}

v2ray(){
    case "$1" in
        install )
            [[ ! -f go.sh ]] && curl -L -s https://install.direct/go.sh -O 
            bash go.sh
            if [[ $V2RAY_CONFIG_FILE = *.web ]];then
                sed -r -e "s/0f9cf274-705c-46d3-ad7a-823ec8747220/`get_uuid`/;" -e "s/awesomepath/`random_string 10`/;" $V2RAY_CONFIG_FILE > /etc/v2ray/config.json
            else
                sed -r -e "s/16834/`random_port`/;s/aes-256-gcm/${V2RAY_SS_METHOD:-aes-256-gcm}/;s/OUM2Dj4kTshkzaMEVQ6vFt1uEkhOh8eN/`random_string 32`/;" -e "s/16833/`random_port`/;s/b22cdf53-195a-4f75-bf06-4c57435df72f/`get_uuid`/;" -e "s/ba68b904-0f86-434e-ade7-c707e55a0259/`get_uuid`/;" -e "s/eeeff816-dd44-4a31-aa51-6d1bd737b9d9/`get_uuid`/;" $V2RAY_CONFIG_FILE > /etc/v2ray/config.json
            fi
            systemctl restart v2ray
            ;;
        uninstall)
            [[ ! -f go.sh ]] && curl -L -s https://install.direct/go.sh -O 
            bash go.sh --remove
            ;;
    esac
}

install_i_like(){
    yum install -y epel-release
    yum install tcpdump nload tree ntpdate curl wget vim iproute python3 -y
}

config_firewall(){
    systemctl status firewalld > /dev/null 2>&1
    echo "${TO_BE_OPENED_PORTS[@]}"
    if [ $? -eq 0 ]; then
        for port in "${TO_BE_OPENED_PORTS[@]}"; do
            firewall-cmd --permanent --zone=public --add-port=${port}/tcp
            #firewall-cmd --permanent --zone=public --add-port=${port}/udp
        done
        firewall-cmd --reload
    else
        echo -e "firewalld looks like not running or not installed, please enable port manually if necessary."
    fi
}

shadowsocks_all(){
    wget "$SHADOWSOCKS_ALL_URL" -O shadowsocks-all.sh
    sed -i -r 's/^([ \t]+)(char=`get_char`)/\1#\2/' shadowsocks-all.sh
}

config_crontab(){
    cp "$CRONTAB_FILE" /etc/crontab
}

install_certbot(){
    yum install epel-release -y
    yum install certbot -y
    #certbot certonly --standalone
}

shadowsocks_libev(){
    echo -en "4\n`random_string 32`\n`random_port`\n${SS_METHOD[${2:-'aes-256-gcm'}]}\ny\n${SS_SIMPLE_OBFS_OPTS[${3:-'http'}]}\n" | bash shadowsocks-all.sh "$1"
}

shadowsocks_r(){
    echo -en "2\n`random_string`\n`random_port`\n${SSR_METHOD[${2:-'none'}]}\n${SSR_PROTOCOL[${3:-'auth_chain_a'}]}\n${SSR_OBFS[${4:-'plain'}]}\n" | bash shadowsocks-all.sh "$1"
}

function main_() {
    local action=${1:-'install'}
    local software=${2:-'v2ray'}
    local actions=('install' 'uninstall')
    local softwares=('ss' 'ssr' 'v2ray' 'all')

    if [[ ! " ${actions[@]} " =~ " $action " ]] || [[ ! " ${softwares[@]} " =~ " $software " ]]; then
        echo "Usage: `basename $0` install|uninstall ss|ssr|v2ray|all"
        exit -1
    fi

    [[ ! -f /root/.inputrc ]] &&  apply_my_profile

    grep $SSH_PORT /etc/ssh/sshd_config > /dev/null || config_ssh

    install_i_like

    case "$software" in
        "ss" )
            [[ ! -f shadowsocks-all.sh ]] && shadowsocks_all
            shadowsocks_libev $action
            ;;
        "ssr")
            [[ ! -f shadowsocks-all.sh ]] && shadowsocks_all
            shadowsocks_r $action
            ;;
        "v2ray")
            v2ray $action
            ;;
        "all")
            [[ ! -f shadowsocks-all.sh ]] && shadowsocks_all
            shadowsocks_libev $action
            shadowsocks_r $action
            v2ray $action
    esac

    config_firewall

    config_crontab
    rm -rf shadowsocks-all.sh go.sh
    install_certbot
}

function test_() {
    echo ${1:-'abc'}
}

get_github_ver(){
    echo -n "$(wget --no-check-certificate -qO- https://api.github.com/repos/${1:-tindy2013/subconverter}/releases/latest | grep 'tag_name' | cut -d\" -f4)"
}


function install_subconverter() {
    [[ "$1" = update ]] && systemctl stop subconverter
    local subconverter_url=tindy2013/subconverter
    local ver=`get_github_ver $subconverter_url`
    wget -O subconverter.tar.gz "https://github.com/$subconverter_url/releases/download/$ver/subconverter_linux64.tar.gz"
    tar xf subconverter.tar.gz -C /usr/local/
    sed -i -r -e '/^listen=.*$/s//listen=127.0.0.1/' /usr/local/subconverter/pref.ini
    [[ "$1" != update ]] && cat <<-'EOF' > /etc/systemd/system/subconverter.service
    [Unit]
    Description=Utility to convert between various subscription format
    After=network-online.target

    [Service]
    #Type=simple
    WorkingDirectory=/usr/local/subconverter
    ExecStart=/usr/local/subconverter/subconverter
    Restart=always

    [Install]
    WantedBy=multi-user.target
EOF
    [[ "$1" != update ]] && systemctl daemon-reload
    systemctl start subconverter
    [[ "$1" != update ]] && systemctl enable subconverter

}


main_ ${1:-'install'} ${2:-'v2ray'}
#test_ $software


