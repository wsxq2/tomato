#!/bin/bash
#
# 使用 certbot 获取并配置证书
#

# 当命令返回非 0 或使用未设置变量时强行退出
set -eu

# 调试开关（显示执行的命令）
set -x


HOST="${1:-c.wsxq2.xyz}"

DATA_DIR='data'
V2RAY_CONFIG_FILE="$DATA_DIR/config.json"
NGINX_CONFIG_FILE="$DATA_DIR/nginx.conf"
NGINX_LNMP_CONFIG_FILE="$DATA_DIR/nginx.conf.lnmp"

MYSQL_ROOT_PASSWD=qwer

#SSH_PORT=26635
SSH_PORT=22
TO_BE_OPENED_PORTS=($SSH_PORT 443)

color_echo()
{
    local color
    color="$1"
    shift
    echo -e '\033['"$color"'m'"$@"'\033[0m'
}
green()
{
    color_echo '1;32' "$@"
}
blue()
{
    color_echo '0;36' "$@"
}
yellow()
{
    color_echo '1;33' "$@"
}
red()
{
    color_echo '1;31' "$@"
}


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
    #TO_BE_OPENED_PORTS+=($port)
    echo -n "$port"
}

config_ssh(){
    sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
    [[ -d ~/.ssh ]] || mkdir ~/.ssh && chmod 700 ~/.ssh
    grep -q 'rsa-key-20180602' ~/.ssh/authorized_keys || cat >> ~/.ssh/authorized_keys <<-'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEArWM+lwt05DEKKUwrAyFbW6CYocRAJot7hLA4RmQemIyzy5Dg1o+r8DdBfo8glZ3Ka54tKSmeDSCxpN1p3TOlfTODrCKxHYxp9OP0qHa7ZffMrfBq2gdGJF7rdv1yUflAkR2dd0VodpRqVRgQdrWAIMKvMg3R8Npurzku0djSGqmVU4Dht0qMnGE7l9iKhmiDkjDRpUK4fuQkhR8IcOYDtb0wcrg7o8qUI1eSxj5BrtfsJ22vut6dkNw/qrvGrJuJrG76zv1ZUtZEBQS6kC8JEbXHwtuZ3YKPlST7T5Jhy4jT+gyiQZ0f/kK1nQjcftURjjBoGZw4ViWhSp3YSEHFyQ== rsa-key-20180602
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+wQx4VeTn3EbawM9T552tO2cGuDRqIAG0BNDcIqX2v04mUzkUMpGww03gwV+OLSnIOPoyXPkiHKcCHOC4i8llBOrS6zeErRIldgZFJvWN0k+l94vzfAPcNeeWl5YuKqQG2LoeM1fJ8xV4oiSAJzTeppHRxYDBT5jq5K6zQIZ4c+xllHWr8v4j44QiY96iU1OKAaIUZm1M3JjD+F84KD+QS6/7i7VKyT6ACD6xvFFCXcFfkYUlZzxMH7Pwb7n9QsJsc1gdLMyN/LMy6OcF1CTuEkit3i3mhPcN2IoLe5zA+t2TWrAMkY4rbBJm/mKvrUa3fP5wWpo8CL8ByPsYKDVoeuHLfJ0WUYP3CDxXiksDO7XrAVHlx9zTrsZ4a7pFeBbhbjUZvdGV2KWS9wXxzFQz35kpekQI56cTEmKpd18LeGV3X8tIUJOpNkZja+9bLKtUL7pRldyIPgAA6YgxlaN5po4jbcA4xYF9VlXWBzJvnVzyJqgbiio9fkKS2yHXfTk= vagrant@archlinux
EOF
    chmod 600 ~/.ssh/authorized_keys

    systemctl restart sshd
}

v2ray(){
    case "$1" in
        install )
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
            rs=`random_string 10`
            sed -r -e "s/0f9cf274-705c-46d3-ad7a-823ec8747220/`get_uuid`/;" -e "s/awesomepath/$rs/;s/sub.wsxq2.xyz/$HOST/g;" $V2RAY_CONFIG_FILE > /usr/local/etc/v2ray/config.json
            sed -re "s/awesomepath/$rs/g;s/sub.wsxq2.xyz/$HOST/g;"  $NGINX_CONFIG_FILE > /etc/nginx/nginx.conf
            systemctl restart v2ray nginx
            ;;
        uninstall)
            bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
            ;;
    esac
}

install_v2ray(){
    v2ray install
}

install_i_like(){
    yum install -y epel-release
    yum install tcpdump nload tree ntpdate curl wget vim iproute python3 -y
}

config_firewall(){
    echo "${TO_BE_OPENED_PORTS[@]}"
    systemctl restart firewalld &> /dev/null
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
    grep -q 'ntpdate' /etc/crontab || echo '*/1 * * * * root ntpdate pool.ntp.org >/dev/null 2>&1' >> /etc/crontab
}



get_github_ver(){
    echo -n "$(wget --no-check-certificate -qO- https://api.github.com/repos/${1:-tindy2013/subconverter}/releases/latest | grep 'tag_name' | cut -d\" -f4)"
}



# 安装并准备 snap
install_and_prepare_snap(){
    yum install snapd -y
    systemctl enable --now snapd.socket
    ln -sf /var/lib/snapd/snap /snap
    while ! snap install core;do
        sleep 1
    done
    snap refresh core
}

# 移除现有的 certbot
remove_old_certbot(){
    yum remove certbot -y
}

# 安装并配置 certbot 和 其插件 certbot-dns-cloudflare
install_certbot_and_plugin(){
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
    snap set certbot trust-plugin-with-root=ok
    snap install certbot-dns-cloudflare
}

# 获取并保存 cloudflare API Tokens
get_cloudflare_api_tokens(){
    [[ -d ~/.secrets/certbot/ ]] || mkdir -p ~/.secrets/certbot/
    cat <<EOF > ~/.secrets/certbot/cloudflare.ini
# Cloudflare API token used by Certbot
dns_cloudflare_api_token = bY82TmxqnwVNb1xB-psZD7412IG_rFhkFMUvJjHD
EOF
chmod -R 700 /root/.secrets
chmod 600 /root/.secrets/certbot/cloudflare.ini
}

# 获取证书
get_cert(){
    [[ -f /etc/letsencrypt/renewal/wsxq2.xyz.conf ]] || certbot certonly --non-interactive --dns-cloudflare   --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini   -d *.wsxq2.xyz -m wsxq222222@gmail.com -v
}

# 测试自动更新是否正常
test_renew(){
    certbot renew --dry-run
}

install_cert(){
    install_and_prepare_snap
    remove_old_certbot
    install_certbot_and_plugin
    get_cloudflare_api_tokens
    get_cert
    test_renew
}


disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

install_lnmp(){
    disable_selinux

    systemctl stop firewalld

    yum install wget git nginx mariadb mariadb-server php php-fpm php-pdo php-mysql -y

    pushd ~
    [[ -d BusSecurityManagement ]] || git clone https://github.com/wsxq2/BusSecurityManagement.git
    pushd BusSecurityManagement
    cp -fr front-end/web/* /usr/share/nginx/html/
    sed -i 's/your mysql root password/qwer/g' back-end/all.sh
    popd
    popd

    cp -f $NGINX_LNMP_CONFIG_FILE /etc/nginx/nginx.conf

    systemctl start mariadb nginx php-fpm

    if mysql -B -uroot <<<'show databases;' &>/dev/null; then
        mysql -sfu root<<EOF
UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PASSWD') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    fi

    if ! mysql -B -uwsxq -p658231 bus <<<'show tables;'|grep -q XianLu; then
        pushd ~/BusSecurityManagement/back-end
        bash all.sh
        popd
    fi

    systemctl enable nginx mariadb php-fpm
}


function main_() {
    config_ssh

    install_i_like

    install_lnmp
    install_cert
    install_v2ray

    config_firewall

    config_crontab

    green success
}

main_
