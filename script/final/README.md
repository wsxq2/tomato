## 终极方案使用方法
先在各个服务器上执行以下命令：
```bash
git clone https://github.com/wsxq2/tomato.git
cd tomato/script/final/
./deploy_one_server.sh <hostdomain> [sshport]
```

再在本地虚机中执行以下命令：
```bash
./install_subconverter.sh
./generate_clash_url.sh
```

完!
