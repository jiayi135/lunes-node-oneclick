#!/bin/bash

# 颜色定义
RED=\'\\033[0;31m\'
GREEN=\'\\033[0;32m\'
YELLOW=\'\\033[0;33m\'
CYAN=\'\\033[0;36m\'
NC=\'\\033[0m\'

echo -e "${GREEN}开始执行 lunes.host 一键全自动节点安装脚本...${NC}"

# 1. 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 请以 root 用户运行此脚本。${NC}"
    exit 1
fi

# 2. 设置默认值或使用环境变量
DOMAIN=${DOMAIN:-$(hostname -f)}
PORT=${PORT:-$(shuf -i 10000-65535 -n 1)}
UUID=${UUID:-$(uuidgen)}
HY2_PASSWORD=${HY2_PASSWORD:-$(head /dev/urandom | tr -dc A-Za-z0-9_ | head -c 16)}

# 3. 安装基础环境
echo -e "${YELLOW}正在安装基础环境 (Node.js, PM2, Xray, Hysteria2)...${NC}"
apt update && apt install -y curl git uuid-runtime wget ca-certificates -y

# 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs
npm install -g pm2

# 安装 Xray 核心
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 安装 Hysteria2
HY2_VERSION=$(curl -s "https://api.github.com/repos/apernet/hysteria/releases/latest" | grep -Po \'"tag_name": "v\\K[0-9.]+\' | head -n 1)
wget -O hysteria-linux-amd64 "https://github.com/apernet/hysteria/releases/download/v${HY2_VERSION}/hysteria-linux-amd64"
chmod +x hysteria-linux-amd64
mv hysteria-linux-amd64 /usr/local/bin/hysteria

# 4. 自动生成 Xray 配置
echo -e "${YELLOW}正在生成 Xray 节点配置...${NC}"
mkdir -p /usr/local/etc/xray

cat <<EOF > /usr/local/etc/xray/config.json
{
    "inbounds": [
        {
            "port": $PORT,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "level": 0
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/lunes"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF

# 5. 自动生成 Hysteria2 配置
echo -e "${YELLOW}正在生成 Hysteria2 节点配置...${NC}"
cat <<EOF > /etc/hysteria/config.yaml
listen: :$((PORT + 1))
password: $HY2_PASSWORD
EOF

# 创建 Hysteria2 systemd 服务
cat <<EOF > /etc/systemd/system/hysteria.service
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动服务
echo -e "${YELLOW}正在启动服务...${NC}"
systemctl daemon-reload
systemctl restart xray
systemctl enable xray
systemctl restart hysteria
systemctl enable hysteria

# 7. 获取公网 IP 并生成链接
IP=$(curl -s https://api64.ipify.org)

VLESS_LINK="vless://$UUID@$IP:$PORT?encryption=none&security=none&type=ws&path=/lunes#lunes_node"
HY2_LINK="hysteria2://$IP:$((PORT + 1))?password=$HY2_PASSWORD#lunes_hy2"

# 8. 输出结果
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装完成！你的节点信息如下：${NC}"
echo -e "${YELLOW}Xray (VLESS + WS) 节点信息:${NC}"
echo -e "  地址: $IP"
echo -e "  端口: $PORT"
echo -e "  UUID: $UUID"
echo -e "  路径: /lunes"
echo -e "  ${CYAN}链接: $VLESS_LINK${NC}"
echo -e "\n${YELLOW}Hysteria2 节点信息:${NC}"
echo -e "  地址: $IP"
echo -e "  端口: $((PORT + 1))"
echo -e "  密码: $HY2_PASSWORD"
echo -e "  ${CYAN}链接: $HY2_LINK${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "你可以使用 \'systemctl status xray\' 和 \'systemctl status hysteria\' 查看运行状态。"
