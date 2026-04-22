# RustDesk Server 一键部署脚本

这是一个用于在 Ubuntu 22.04 (arm64/amd64) 上一键部署 RustDesk Server (开源版) 的交互式脚本。

## 快速开始

您可以通过以下任一方式直接获取并运行脚本：

### 使用 wget
```bash
wget -O deploy_rustdesk.sh https://raw.githubusercontent.com/gray0128/rustdesk-sh/main/deploy_rustdesk.sh && sudo bash deploy_rustdesk.sh
```

### 使用 curl
```bash
curl -fsSL https://raw.githubusercontent.com/gray0128/rustdesk-sh/main/deploy_rustdesk.sh -o deploy_rustdesk.sh && sudo bash deploy_rustdesk.sh
```

## 主要功能

- **多架构支持**：支持 Ubuntu 22.04 的 amd64 和 arm64 架构。
- **环境检查**：自动验证系统环境、检查端口占用情况。
- **防火墙管理**：检测并支持自动配置 UFW 防火墙端口。
- **依赖自动安装**：自动安装 Docker 及 Docker Compose 插件。
- **交互式部署**：引导式配置域名和通信密钥 (Key)。
- **一键导入配置**：安装成功后自动生成客户端 Base64 配置字符串，方便一键导入。

## 系统要求

- **操作系统**：Ubuntu 22.04
- **硬件架构**：amd64 (x86_64) 或 arm64 (aarch64)
- **权限**：需要 root 或 sudo 权限

## 端口说明

脚本将配置并运行以下服务端口：
- `21115/TCP`: NAT 类型测试
- `21116/TCP`: TCP 打洞和连接
- `21116/UDP`: ID 注册和心跳
- `21117/TCP`: 中继服务

*注：本脚本默认不开放 21118/21119 网页版端口。*
