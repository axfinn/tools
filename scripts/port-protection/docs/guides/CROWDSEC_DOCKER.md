# CrowdSec Docker 完整部署指南

## 🐳 概述

CrowdSec 完全支持 Docker 部署，这是官方推荐的方式之一。Docker 部署有以下优势：

- ✅ 隔离环境，不影响宿主机
- ✅ 易于更新和回滚
- ✅ 可与其他容器服务集成
- ✅ 适合云原生架构

---

## 🏗️ 架构说明

### CrowdSec Docker 架构

```
┌─────────────────────────────────────────┐
│         Docker Host (宿主机)            │
│                                         │
│  ┌────────────────┐  ┌───────────────┐ │
│  │  CrowdSec      │  │  Firewall     │ │
│  │  Container     │←→│  Bouncer      │ │
│  │  (检测引擎)     │  │  (原生安装)   │ │
│  └────────────────┘  └───────────────┘ │
│         ↓                    ↓          │
│  ┌────────────────┐  ┌───────────────┐ │
│  │  日志文件       │  │  iptables     │ │
│  │  (Volumes)     │  │  (封禁执行)   │ │
│  └────────────────┘  └───────────────┘ │
└─────────────────────────────────────────┘
```

**重要说明：**
- CrowdSec Agent 运行在 Docker 容器中
- Firewall Bouncer 需要安装在宿主机上（不能容器化）
- 原因：Bouncer 需要直接操作宿主机的 iptables/nftables

---

## 📋 方案1: Docker Compose（推荐）

### 1. 创建目录结构

```bash
mkdir -p ~/crowdsec
cd ~/crowdsec

# 创建数据目录
mkdir -p data
mkdir -p config
```

### 2. 创建 docker-compose.yml

```yaml
version: '3.8'

services:
  crowdsec:
    image: crowdsecurity/crowdsec:latest
    container_name: crowdsec
    restart: unless-stopped

    # 环境变量
    environment:
      # 自动安装的集合（场景包）
      COLLECTIONS: >
        crowdsecurity/linux
        crowdsecurity/sshd
        crowdsecurity/rdp

      # 时区
      TZ: Asia/Shanghai

      # API配置
      BOUNCER_KEY_FIREWALL: ${BOUNCER_KEY_FIREWALL:-changeme}

    # 数据卷映射
    volumes:
      # CrowdSec配置和数据
      - ./config:/etc/crowdsec:rw
      - ./data:/var/lib/crowdsec/data:rw

      # 日志文件（需要读取）
      - /var/log/auth.log:/var/log/auth.log:ro
      - /var/log/syslog:/var/log/syslog:ro
      - /var/log/kern.log:/var/log/kern.log:ro

      # Docker socket（如果需要监控Docker容器）
      # - /var/run/docker.sock:/var/run/docker.sock:ro

    # 网络配置
    networks:
      - crowdsec-network

    # 端口映射（API端口）
    ports:
      - "8080:8080"  # Local API
      - "6060:6060"  # Prometheus metrics (可选)

    # 健康检查
    healthcheck:
      test: ["CMD", "cscli", "version"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  crowdsec-network:
    driver: bridge
```

### 3. 创建环境变量文件 .env

```bash
# .env 文件
BOUNCER_KEY_FIREWALL=your-secure-random-key-here
```

生成安全的 Bouncer Key：
```bash
openssl rand -hex 32
```

### 4. 启动 CrowdSec

```bash
# 启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f crowdsec

# 检查状态
docker-compose exec crowdsec cscli metrics
```

---

## 🔥 方案2: 安装 Firewall Bouncer（宿主机）

### 1. 在宿主机安装 Bouncer

**Debian/Ubuntu:**
```bash
# 添加CrowdSec仓库
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash

# 安装Firewall Bouncer
sudo apt-get install crowdsec-firewall-bouncer-iptables

# 或使用nftables版本
# sudo apt-get install crowdsec-firewall-bouncer-nftables
```

### 2. 生成 Bouncer API Key

在 Docker 容器中生成：
```bash
# 进入容器
docker-compose exec crowdsec sh

# 生成bouncer key
cscli bouncers add firewall-bouncer

# 输出示例：
# Api key for 'firewall-bouncer':
#    1234567890abcdef1234567890abcdef

# 退出容器
exit
```

### 3. 配置 Bouncer

编辑配置文件：
```bash
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

修改配置：
```yaml
# API URL（指向Docker容器）
api_url: http://localhost:8080
api_key: 1234567890abcdef1234567890abcdef  # 替换为上面生成的key

# 封禁模式
mode: iptables  # 或 nftables

# Docker支持（重要！）
iptables_chains:
  - INPUT
  - DOCKER-USER  # 重要：保护Docker容器

# 封禁时间
deny_action: DROP
deny_log: true

# 日志
log_mode: file
log_dir: /var/log/
log_level: info

# 更新间隔
update_frequency: 10s

# 缓存路径
cache_retention_duration: 1h
```

### 4. 启动 Bouncer

```bash
# 启动服务
sudo systemctl enable crowdsec-firewall-bouncer
sudo systemctl start crowdsec-firewall-bouncer

# 查看状态
sudo systemctl status crowdsec-firewall-bouncer

# 查看日志
sudo tail -f /var/log/crowdsec-firewall-bouncer.log
```

---

## 🎯 完整部署示例（RDP + SSH保护）

### 1. 完整的 docker-compose.yml

```yaml
version: '3.8'

services:
  # CrowdSec 主服务
  crowdsec:
    image: crowdsecurity/crowdsec:latest
    container_name: crowdsec
    restart: unless-stopped

    environment:
      # 场景集合
      COLLECTIONS: >
        crowdsecurity/linux
        crowdsecurity/sshd
        crowdsecurity/rdp
        crowdsecurity/http-cve

      # 时区
      TZ: Asia/Shanghai

      # 启用普罗米修斯指标
      METRICS_ENABLED: "true"

    volumes:
      # 配置和数据
      - ./crowdsec/config:/etc/crowdsec:rw
      - ./crowdsec/data:/var/lib/crowdsec/data:rw

      # 系统日志
      - /var/log/auth.log:/logs/auth.log:ro
      - /var/log/syslog:/logs/syslog:ro

      # 如果有自定义应用日志
      # - /path/to/app/logs:/logs/app:ro

    networks:
      - crowdsec-network

    ports:
      - "127.0.0.1:8080:8080"  # Local API（仅本地访问）
      - "127.0.0.1:6060:6060"  # Metrics

    # 资源限制
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M

  # CrowdSec Dashboard（可选）
  dashboard:
    image: crowdsecurity/crowdsec-dashboard:latest
    container_name: crowdsec-dashboard
    restart: unless-stopped

    environment:
      CROWDSEC_URL: http://crowdsec:8080

    ports:
      - "3000:3000"  # Dashboard端口

    networks:
      - crowdsec-network

    depends_on:
      - crowdsec

networks:
  crowdsec-network:
    driver: bridge
```

### 2. 创建采集配置

创建文件 `./crowdsec/config/acquis.yaml`:

```yaml
---
# 系统认证日志（SSH等）
filenames:
  - /logs/auth.log
labels:
  type: syslog

---
# 系统日志（RDP等）
filenames:
  - /logs/syslog
labels:
  type: syslog

---
# 内核日志
filenames:
  - /var/log/kern.log
labels:
  type: syslog
```

### 3. 部署脚本

创建 `deploy.sh`:

```bash
#!/bin/bash

set -e

echo "=== CrowdSec Docker 部署脚本 ==="

# 1. 创建目录
echo "创建目录..."
mkdir -p crowdsec/config crowdsec/data

# 2. 启动容器
echo "启动 CrowdSec 容器..."
docker-compose up -d

# 3. 等待容器启动
echo "等待容器启动..."
sleep 10

# 4. 生成Bouncer Key
echo "生成 Bouncer API Key..."
BOUNCER_KEY=$(docker-compose exec -T crowdsec cscli bouncers add firewall-bouncer -o raw)
echo "Bouncer Key: $BOUNCER_KEY"

# 5. 保存到文件
echo "$BOUNCER_KEY" > bouncer-key.txt
chmod 600 bouncer-key.txt

echo ""
echo "=== 部署完成 ==="
echo ""
echo "下一步："
echo "1. 在宿主机安装 Firewall Bouncer"
echo "2. 使用生成的 Key 配置 Bouncer"
echo "3. 查看 Dashboard: http://localhost:3000"
echo ""
echo "Bouncer Key 已保存到: bouncer-key.txt"
```

### 4. 执行部署

```bash
chmod +x deploy.sh
./deploy.sh
```

---

## 🔧 配置和管理

### 查看状态

```bash
# 查看CrowdSec指标
docker-compose exec crowdsec cscli metrics

# 查看决策（封禁列表）
docker-compose exec crowdsec cscli decisions list

# 查看警报
docker-compose exec crowdsec cscli alerts list
```

### 管理场景

```bash
# 进入容器
docker-compose exec crowdsec sh

# 列出已安装的集合
cscli collections list

# 安装新集合
cscli collections install crowdsecurity/nginx

# 列出可用场景
cscli scenarios list

# 升级所有集合
cscli hub update
cscli hub upgrade
```

### 管理封禁

```bash
# 手动封禁IP
docker-compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 4h --reason "Manual ban"

# 解封IP
docker-compose exec crowdsec cscli decisions delete --ip 1.2.3.4

# 添加到白名单
docker-compose exec crowdsec cscli decisions add --ip 1.2.3.4 --type whitelist

# 查看特定IP
docker-compose exec crowdsec cscli decisions list --ip 1.2.3.4
```

---

## 📊 监控和可视化

### 1. 使用内置 Dashboard

访问: http://localhost:3000

默认凭据：
- Username: `admin`
- Password: 查看容器日志获取

### 2. Prometheus 指标

CrowdSec 暴露 Prometheus 指标在端口 6060:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'crowdsec'
    static_configs:
      - targets: ['localhost:6060']
```

### 3. 日志查看

```bash
# CrowdSec日志
docker-compose logs -f crowdsec

# Bouncer日志（宿主机）
sudo tail -f /var/log/crowdsec-firewall-bouncer.log

# 查看封禁事件
docker-compose exec crowdsec tail -f /var/log/crowdsec.log
```

---

## 🛠️ 故障排除

### 问题1: Bouncer 无法连接到 API

**检查：**
```bash
# 测试API连接
curl http://localhost:8080/v1/heartbeat

# 检查防火墙
sudo iptables -L -n | grep 8080

# 检查Docker网络
docker network ls
docker network inspect crowdsec_crowdsec-network
```

**解决：**
```yaml
# 确保端口映射正确
ports:
  - "127.0.0.1:8080:8080"  # 或 "0.0.0.0:8080:8080"
```

### 问题2: 日志文件无法访问

**检查：**
```bash
# 检查文件权限
ls -la /var/log/auth.log

# 测试容器内访问
docker-compose exec crowdsec cat /logs/auth.log
```

**解决：**
```bash
# 添加读取权限
sudo chmod 644 /var/log/auth.log
sudo chmod 644 /var/log/syslog
```

### 问题3: Bouncer 不封禁

**检查：**
```bash
# 查看Bouncer状态
sudo systemctl status crowdsec-firewall-bouncer

# 查看iptables规则
sudo iptables -L crowdsec-chain -n

# 检查API Key
sudo cat /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

**测试：**
```bash
# 手动触发封禁
docker-compose exec crowdsec cscli decisions add --ip 1.2.3.4

# 检查是否在iptables中
sudo iptables -L crowdsec-chain -n | grep 1.2.3.4
```

---

## 🚀 高级配置

### 1. 多容器监控

```yaml
# docker-compose.yml
services:
  crowdsec:
    # ... 基础配置 ...
    volumes:
      # 监控Nginx容器
      - nginx-logs:/logs/nginx:ro
      # 监控其他应用
      - app-logs:/logs/app:ro

  nginx:
    volumes:
      - nginx-logs:/var/log/nginx

volumes:
  nginx-logs:
  app-logs:
```

### 2. 集群模式

```yaml
# crowdsec-agent.yml（多个agent节点）
services:
  crowdsec-agent:
    image: crowdsecurity/crowdsec:latest
    environment:
      LAPI_URL: http://crowdsec-lapi:8080
      AGENT_USERNAME: agent1
      AGENT_PASSWORD: ${AGENT_PASSWORD}
    volumes:
      - /var/log:/logs:ro

# crowdsec-lapi.yml（中央API服务器）
services:
  crowdsec-lapi:
    image: crowdsecurity/crowdsec:latest
    environment:
      DISABLE_AGENT: "true"
    ports:
      - "8080:8080"
```

### 3. 自动更新

```bash
# 使用 Watchtower 自动更新容器
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --interval 86400 \
  crowdsec
```

---

## 📋 完整部署检查清单

部署完成后，检查：

- [ ] CrowdSec 容器运行正常
- [ ] 日志文件可以被读取
- [ ] Firewall Bouncer 已安装并运行
- [ ] Bouncer 可以连接到 API
- [ ] iptables 规则已创建
- [ ] 测试封禁功能正常
- [ ] Dashboard 可以访问（如果启用）
- [ ] 场景集合已安装
- [ ] 日志轮转配置正常

---

## 🎯 与你现有脚本整合

### 结合使用方案

```bash
# 1. 使用CrowdSec作为主要防护
docker-compose up -d crowdsec
sudo systemctl start crowdsec-firewall-bouncer

# 2. 使用自研脚本管理动态IP白名单
sudo ./dynamic-ip-whitelist.sh init
sudo ./dynamic-ip-whitelist.sh add-current

# 3. 使用RDP紧急保护作为补充
sudo ./rdp-emergency.sh quick-protect
```

### 白名单同步脚本

创建 `sync-whitelist.sh`:

```bash
#!/bin/bash

# 从自研脚本同步白名单到CrowdSec

# 读取白名单
while read -r ip rest; do
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        docker-compose exec -T crowdsec cscli decisions add \
            --ip "$ip" \
            --type whitelist \
            --duration 720h \
            --reason "Dynamic whitelist"
    fi
done < /etc/port-protect/dynamic-whitelist.conf
```

---

## 💡 总结

### CrowdSec Docker 优势

✅ 隔离运行，不污染宿主机
✅ 易于更新和维护
✅ 与现代容器栈集成
✅ 众包威胁情报
✅ 可视化管理界面

### 推荐配置

**小型部署：**
- CrowdSec Container + Firewall Bouncer
- 监控 SSH + RDP

**中型部署：**
- CrowdSec Container + Dashboard
- Firewall Bouncer + 多种 Bouncers
- 监控多种服务

**大型部署：**
- 集群模式（LAPI + Agents）
- 多个 Bouncers
- Prometheus 监控
- 高可用配置

需要帮你部署或配置任何部分吗？
