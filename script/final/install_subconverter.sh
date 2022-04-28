set -exu
get_github_ver(){
    echo -n "$(wget --no-check-certificate -qO- https://api.github.com/repos/${1:-tindy2013/subconverter}/releases/latest | grep 'tag_name' | cut -d\" -f4)"
}

install_subconverter() {
    local action="${1:-install}"
    local subconverter_url="tindy2013/subconverter"
    local ver=`get_github_ver $subconverter_url`

    [[ "$1" = update ]] && systemctl stop subconverter
    [[ -f subconverter.tar.gz ]] || wget -O subconverter.tar.gz "https://github.com/$subconverter_url/releases/download/$ver/subconverter_linux64.tar.gz"
    tar xf subconverter.tar.gz -C /usr/local/
    sed -r -e '/^listen=.*$/s//listen=127.0.0.1/' /usr/local/subconverter/pref.example.ini > /usr/local/subconverter/pref.ini
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
install_subconverter install
