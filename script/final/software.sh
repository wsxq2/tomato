#!/usr/bin/env bash
#
# 终极方案
#
# 作者: wsxq2, wsxq2@qq.com
# 上次修改时间: 2022-04-25

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
    pushd ~
    git clone https://github.com/wsxq2/MyProfile.git .MyProfile && cd .MyProfile && ./deploy.sh
    popd
}

v2ray(){
    case "$1" in
        install )
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
            sed -r -e "s/0f9cf274-705c-46d3-ad7a-823ec8747220/`get_uuid`/;" -e "s/awesomepath/`random_string 10`/;" $V2RAY_CONFIG_FILE > /etc/v2ray/config.json
            systemctl restart v2ray
            ;;
        uninstall)
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
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

config_crontab(){
    cp "$CRONTAB_FILE" /etc/crontab
}

install_certbot(){
    yum install epel-release -y
    yum install certbot -y
    #certbot certonly --standalone
}

function main_() {
    local action=${1:-'install'}
    local actions=('install' 'uninstall')

    if [[ ! " ${actions[@]} " =~ " $action " ]]; then
        echo "Usage: `basename $0` install|uninstall"
        exit -1
    fi

    [[ ! -f ~/.inputrc ]] &&  apply_my_profile

    grep $SSH_PORT /etc/ssh/sshd_config &> /dev/null || config_ssh

    install_i_like

    v2ray $action

    config_firewall

    config_crontab
    rm -rf shadowsocks-all.sh go.sh
    install_certbot
}

get_github_ver(){
    echo -n "$(wget --no-check-certificate -qO- https://api.github.com/repos/${1:-tindy2013/subconverter}/releases/latest | grep 'tag_name' | cut -d\" -f4)"
}


function install_subconverter() {
    [[ "$1" = update ]] && systemctl stop subconverter
    local subconverter_url="tindy2013/subconverter"
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


main_ ${1:-'install'}


