#!/bin/bash

# ==============================================================================
# RustDesk Server (Open Source) 一键部署脚本
# 适用系统: Ubuntu 22.04 (arm64/amd64)
# 默认域名: rustdesk.bobocai.win
# ==============================================================================

set -e

DOMAIN="rustdesk.bobocai.win"
PORTS_TCP=(21115 21116 21117)
PORTS_UDP=(21116)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 欢迎使用 RustDesk Server 一键部署脚本 ===${NC}"

echo "1. 安装/更新 RustDesk Server"
echo "2. 卸载 RustDesk Server"
read -p "请选择操作 [默认: 1]: " action_choice

if [[ "$action_choice" == "2" ]]; then
    echo -e "\n${YELLOW}>>> 正在卸载 RustDesk Server...${NC}"
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 卸载需要 root 权限，请使用 sudo 运行此脚本。${NC}"
        exit 1
    fi
    INSTALL_DIR="/opt/rustdesk"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        if command -v docker > /dev/null && docker compose version > /dev/null 2>&1; then
            docker compose down -v || true
        fi
        cd /
        read -p "是否删除所有配置文件和数据? (y/n, 默认y): " del_data
        if [[ "$del_data" != "n" && "$del_data" != "N" ]]; then
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}RustDesk Server 已成功卸载，相关数据已被完全清除。${NC}"
        else
            echo -e "${GREEN}RustDesk Server 容器已移除，但保留了数据目录 $INSTALL_DIR。${NC}"
        fi
    else
        echo -e "${YELLOW}未检测到 RustDesk 安装目录 ($INSTALL_DIR)，无需卸载。${NC}"
    fi
    exit 0
fi

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}提示: 请使用 root 权限或 sudo 运行此脚本。${NC}"
  echo "例如: sudo bash $0"
  exit 1
fi

# 2. 环境检查: 操作系统和架构
echo -e "\n${GREEN}>>> 正在进行环境检查...${NC}"
OS=$(source /etc/os-release && echo "$ID")
VERSION_ID=$(source /etc/os-release && echo "$VERSION_ID")
ARCH=$(uname -m)

if [ "$OS" != "ubuntu" ] || [ "$VERSION_ID" != "22.04" ]; then
    echo -e "${YELLOW}警告: 此脚本推荐在 Ubuntu 22.04 上运行，当前系统为 $OS $VERSION_ID。${NC}"
    read -p "是否继续? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消部署。"
        exit 1
    fi
else
    echo "系统版本检查通过: Ubuntu 22.04 ($ARCH)"
fi

if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    echo -e "${RED}错误: 不支持的架构 $ARCH，仅支持 amd64 (x86_64) 和 arm64 (aarch64)。${NC}"
    exit 1
fi

# 3. 检查端口占用
echo -e "\n${GREEN}>>> 正在检查端口占用情况...${NC}"
PORT_OCCUPIED=false
for port in "${PORTS_TCP[@]}"; do
    if ss -tuln | grep -q ":$port " ; then
        echo -e "${RED}警告: TCP 端口 $port 已被占用。${NC}"
        PORT_OCCUPIED=true
    fi
done

for port in "${PORTS_UDP[@]}"; do
    if ss -uuln | grep -q ":$port " ; then
        echo -e "${RED}警告: UDP 端口 $port 已被占用。${NC}"
        PORT_OCCUPIED=true
    fi
done

if [ "$PORT_OCCUPIED" = true ]; then
    echo -e "${YELLOW}部分所需端口被占用，可能会导致 RustDesk 无法正常工作。${NC}"
    read -p "是否继续? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消部署。"
        exit 1
    fi
else
    echo "端口检查通过，无冲突。"
fi

# 4. 检查防火墙
echo -e "\n${GREEN}>>> 正在检查 UFW 防火墙状态...${NC}"
if command -v ufw > /dev/null; then
    UFW_STATUS=$(ufw status | grep "Status" | awk '{print $2}')
    if [ "$UFW_STATUS" = "active" ]; then
        echo -e "${YELLOW}检测到 UFW 防火墙已开启。RustDesk 需要放行以下端口:${NC}"
        echo "- TCP: 21115, 21116, 21117"
        echo "- UDP: 21116"
        read -p "是否自动在 UFW 中开放这些端口? (y/n): " open_ports
        if [[ "$open_ports" == "y" || "$open_ports" == "Y" ]]; then
            ufw allow 21115/tcp
            ufw allow 21116/tcp
            ufw allow 21116/udp
            ufw allow 21117/tcp
            echo -e "${GREEN}UFW 端口已开放。${NC}"
        else
            echo "跳过 UFW 端口配置，请确保稍后手动开放。"
        fi
    else
        echo "UFW 未开启，无需配置。请确保您的云服务商安全组已放行相关端口。"
    fi
else
    echo -e "${YELLOW}未检测到 UFW。请确保您的云服务商安全组或系统级防火墙已放行相关端口。${NC}"
fi

# 5. 检查并安装 Docker 和 Docker Compose
echo -e "\n${GREEN}>>> 正在检查 Docker 环境...${NC}"
if ! command -v docker > /dev/null; then
    echo -e "${YELLOW}未检测到 Docker，正在自动安装...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo -e "${GREEN}Docker 安装完成。${NC}"
else
    echo "Docker 已安装。"
fi

if ! docker compose version > /dev/null 2>&1; then
    echo -e "${RED}错误: 未检测到 Docker Compose 插件。请先安装 Docker Compose 后重试。${NC}"
    exit 1
else
    echo "Docker Compose 检查通过。"
fi

# 6. 获取用户配置
echo -e "\n${GREEN}=== 配置 RustDesk Server ===${NC}"
read -p "请输入您的服务器域名或 IP [默认: ${DOMAIN}]: " input_domain
if [ -n "$input_domain" ]; then
    DOMAIN="$input_domain"
fi

while true; do
    read -p "请输入您要设置的通信密钥 (Key)，如果不输入将由系统随机生成: " USER_KEY
    if [ -n "$USER_KEY" ]; then
        echo "已记录您输入的密钥。"
        break
    else
        echo "未输入密钥，将使用系统自动生成。"
        break
    fi
done

# 7. 创建部署目录和文件
INSTALL_DIR="/opt/rustdesk"
echo -e "\n${GREEN}>>> 正在生成部署文件...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 准备加密密钥环境变量
if [ -n "$USER_KEY" ]; then
    COMMAND_ARGS_HBBS="-r ${DOMAIN} -k \"$USER_KEY\""
    COMMAND_ARGS_HBBR="-k \"$USER_KEY\""
else
    COMMAND_ARGS_HBBS="-r ${DOMAIN}"
    COMMAND_ARGS_HBBR=""
fi

# 不暴露 21118 和 21119 网页端端口，使用手动映射的方式
cat > compose.yml <<EOF
services:
  hbbs:
    container_name: hbbs
    image: rustdesk/rustdesk-server:latest
    command: hbbs ${COMMAND_ARGS_HBBS}
    volumes:
      - ./data:/root
    ports:
      - "21115:21115/tcp"
      - "21116:21116/tcp"
      - "21116:21116/udp"
    depends_on:
      - hbbr
    restart: unless-stopped

  hbbr:
    container_name: hbbr
    image: rustdesk/rustdesk-server:latest
    command: hbbr ${COMMAND_ARGS_HBBR}
    volumes:
      - ./data:/root
    ports:
      - "21117:21117/tcp"
    restart: unless-stopped
EOF

echo "compose.yml 已生成到 $INSTALL_DIR 目录。"

# 8. 启动服务
echo -e "\n${GREEN}>>> 正在启动 RustDesk 服务...${NC}"
docker compose pull
docker compose up -d

echo -e "\n${GREEN}>>> 服务已启动，正在等待容器初始化...${NC}"
sleep 5

# 如果用户未输入 key，尝试从文件读取
if [ -z "$USER_KEY" ]; then
    if [ -f "$INSTALL_DIR/data/id_ed25519.pub" ]; then
        USER_KEY=$(cat "$INSTALL_DIR/data/id_ed25519.pub")
    else
        echo -e "${YELLOW}未能读取到自动生成的公钥，您可能需要手动查看 $INSTALL_DIR/data/id_ed25519.pub。${NC}"
    fi
fi

# 9. 输出客户端配置信息
echo -e "\n=========================================================================="
echo -e "${GREEN}RustDesk Server 部署完成！${NC}"
echo -e "=========================================================================="
echo -e "服务器地址 (ID Server): ${DOMAIN}"
echo -e "中继服务器 (Relay Server): ${DOMAIN}"
echo -e "通信密钥 (Key): ${USER_KEY}"
echo -e "--------------------------------------------------------------------------"

# 生成 base64 的一键导入配置字符串
CONFIG_JSON="{\"host\":\"${DOMAIN}\",\"relay\":\"${DOMAIN}\",\"key\":\"${USER_KEY}\"}"
BASE64_CONFIG=$(echo -n "$CONFIG_JSON" | base64 -w 0)

echo -e "${GREEN}一键导入配置字符串 (请在客户端复制后导入):${NC}"
echo -e "${BASE64_CONFIG}"
echo -e "=========================================================================="
