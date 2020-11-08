#!/bin/sh
#
# 简要说明
#
# 作者: wsxq2, wsxq2@qq.com
# 上次修改时间: 2020-11-08 12:08:16 +0800

# 调试选项
## 当命令返回非 0 时停止执行
set -e
## 当使用未定义变量时停止执行
set -u
## 显示执行的命令
set -x


#!/usr/bin/env bash
set -eu
IFS=$'\n\t'

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'


set -xv

get_libev_ver(){
    libev_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -n "${libev_ver}" ] || (echo -e "[${red}Error${plain}] Get shadowsocks-libev latest version failed" && exit 1)
}

download() {
    local filename=$(basename $1)
    if [ -f ${1} ]; then
        echo "${filename} [found]"
    else
        echo "${filename} not found, download now..."
        wget --no-check-certificate -c -t3 -T60 -O ${1} ${2}
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Download ${filename} failed."
            exit 1
        fi
    fi
}

disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

install_dependencies(){
    yum install epel-release -y #安装额外的软件源（shadowsocks-libev的依赖 libsodium 和 mbedtls 要用）
    yum install wget gcc gettext autoconf libtool automake make pcre-devel c-ares-devel libev-devel libsodium-devel mbedtls-devel -y #安装依赖
}

download_files(){
    get_libev_ver
    shadowsocks_libev_file="shadowsocks-libev-$(echo ${libev_ver} | sed -e 's/^[a-zA-Z]//g')"
    shadowsocks_libev_url="https://github.com/shadowsocks/shadowsocks-libev/releases/download/${libev_ver}/${shadowsocks_libev_file}.tar.gz"

    download "${shadowsocks_libev_file}.tar.gz" "${shadowsocks_libev_url}"
}

install_shadowsocks_libev(){
    echo "Installing shadowsocks-libev..."
    tar xf ${shadowsocks_libev_file}.tar.gz
    cd ${shadowsocks_libev_file}
    ./configure --disable-documentation && make && make install
    echo "Installing shadowsocks-libev finished!"
}

random_string()
{
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}

random_port(){
    echo -n $(( ( RANDOM % 40000 )  + 10000 ))
}

config_shadowsocks(){
    echo 'start config_shadowsocks'
    CONFIG_FILE=/etc/shadowsocks-libev/config.json
    SERVICE_FILE=/etc/systemd/system/shadowsocks-libev-server@.service

    SS_PASSWORD="$(random_string 32)"
    SS_PORT=$(random_port)
    SS_METHOD=aes-256-cfb

    SS_IP=`ip route get 1 | awk '{print $NF;exit}'`

# create shadowsocks-libev config
local config_dir=$(dirname $CONFIG_FILE)
if [ ! -d $config_dir ]; then
    mkdir $config_dir
fi

cat <<EOF | sudo tee ${CONFIG_FILE}
{
  "server": "0.0.0.0",
  "server_port": ${SS_PORT},
  "password": "${SS_PASSWORD}",
  "method": "${SS_METHOD}",
  "mode": "tcp_and_udp"
}
EOF

# create service
cat <<EOF | sudo tee ${SERVICE_FILE}
[Unit]
Description=Shadowsocks-Libev Custom Server Service for %I
Documentation=man:ss-server(1)
After=network-online.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/ss-server -c $CONFIG_FILE
User=nobody
Group=nobody
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
EOF

    # start service
    systemctl enable shadowsocks-libev-server@config.service
    systemctl restart shadowsocks-libev-server@config.service

    # view service status
    sleep 1
    systemctl status shadowsocks-libev-server@config.service -l

    echo "================================"
    echo ""
    echo "Congratulations! Shadowsocks has been installed on your system."
    echo "You shadowsocks connection info:"
    echo "--------------------------------"
    echo "server:      ${SS_IP}"
    echo "server_port: ${SS_PORT}"
    echo "password:    ${SS_PASSWORD}"
    echo "method:      ${SS_METHOD}"
    echo "--------------------------------"
}

config_firewall(){
    systemctl status firewalld > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        firewall-cmd --permanent --zone=public --add-port=${SS_PORT}/tcp
        firewall-cmd --permanent --zone=public --add-port=${SS_PORT}/udp
        firewall-cmd --reload
    else
        echo -e "[${yellow}Warning${plain}] firewalld looks like not running or not installed, please enable port ${shadowsocksport} manually if necessary."
    fi
}

main(){
disable_selinux
install_dependencies
download_files
install_shadowsocks_libev
config_shadowsocks
config_firewall
}

test_(){
    #echo $(random_string 32)
    #config_shadowsocks
    #uri_generate_libev 
    #get_ip
    random_string
}

before_all(){
    yum install git vim -y
    git clone https://github.com/wsxq2/MyProfile.git
    cd MyProfile
    ./start.sh b put
    cd ~
}

get_ip() {
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

install_shadowsocks_libev_obfs() {
    if [ "${libev_obfs}" == "y" ] || [ "${libev_obfs}" == "Y" ]; then
        cd ${cur_dir}
        git clone https://github.com/shadowsocks/simple-obfs.git
        cd simple-obfs
        git submodule update --init --recursive
        ./autogen.sh
        ./configure --disable-documentation
        make
        make install
        if [ ! "$(command -v obfs-server)" ]; then
            echo -e "[${red}Error${plain}] simple-obfs for ${software[${selected}-1]} install failed."
            echo "Please visit: https://teddysun.com/486.html and contact."
            install_cleanup
            exit 1
        fi
        [ -f /usr/local/bin/obfs-server ] && ln -s /usr/local/bin/obfs-server /usr/bin
    fi
}

uri_generate_libev() {
    #local SS_METHOD="aes-256-cfb"
    #local SS_PASSWORD="Xi0WXfb8hRibYda3SXEgDWPjkFr7bPrD"
    #local SS_PORT="38027"
    #local SS_IP="64.64.228.229"
    #local SS_TAG="bwg2"

    local SS_METHOD="aes-256-cfb"
    local SS_PASSWORD="eAhy9AGe0uFzhWU3A3S8qh1Xigu5lYoH"
    local SS_PORT="33954"
    local SS_IP="172.104.96.145"
    local SS_TAG="linode"

    local tmp=$(echo -n "${SS_METHOD}:${SS_PASSWORD}" | base64 -w0)
    local qr_code="ss://${tmp}@${SS_IP}:${SS_PORT}#$SS_TAG"
    echo
    echo -e "${green} ${qr_code} ${plain}"
}

install_i_like(){
    yum install tcpdump nload
}
test_
#before_all
#main
