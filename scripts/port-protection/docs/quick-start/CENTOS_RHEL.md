# CentOS/RHEL 快速部署指南

> Port Protection v3.1.0 - 专为 CentOS/RHEL 7/8/9 优化

## 🔴 CentOS 系统说明

你的系统是 **CentOS**，与 Debian/Ubuntu 有重要区别：

| 特性 | CentOS/RHEL | Debian/Ubuntu |
|------|-------------|---------------|
| 包管理器 | yum/dnf | apt/apt-get |
| 防火墙 | firewalld | ufw/iptables |
| SELinux | 启用 | 通常禁用 |
| 日志位置 | /var/log/secure | /var/log/auth.log |
| 服务管理 | systemd | systemd |

---

## ⚡ 快速开始（CentOS 版本）

### 1. 系统要求

- **操作系统**: CentOS 7/8/9, RHEL 7/8/9, Rocky Linux, AlmaLinux
- **内核**: 3.10+ (CentOS 7+)
- **权限**: root 或 sudo
- **网络**: 需要配置防火墙

---

### 2. 安装依赖（自动）

```bash
# 方式1: 使用脚本自动安装（推荐）
sudo ./blacklist-manager.sh install-deps

# 方式2: 手动安装
sudo yum install -y epel-release  # EPEL 仓库
sudo yum install -y ipset iptables iptables-services

# CentOS 8+ 使用 dnf
sudo dnf install -y ipset iptables iptables-services
```

---

### 3. 初始化系统

```bash
# 初始化黑名单系统
sudo ./blacklist-manager.sh init
```

---

## 🔥 CentOS 防火墙配置

### firewalld vs iptables

CentOS 7+ 默认使用 **firewalld**，但我们的脚本使用 **iptables**。

#### 选项A: 使用 iptables（推荐）

```bash
# 1. 停止 firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 2. 安装 iptables-services
sudo yum install -y iptables-services

# 3. 启动 iptables
sudo systemctl enable iptables
sudo systemctl start iptables

# 4. 保存规则
sudo service iptables save
```

#### 选项B: 使用 firewalld

如果你想继续使用 firewalld，使用 `firewall-cmd` 命令：

```bash
# 查看 firewalld 状态
sudo firewall-cmd --state

# 封禁 IP
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="1.2.3.4" drop'
sudo firewall-cmd --reload

# 解封 IP
sudo firewall-cmd --permanent --remove-rich-rule='rule family="ipv4" source address="1.2.3.4" drop'
sudo firewall-cmd --reload

# 查看规则
sudo firewall-cmd --list-all
```

---

## 🛡️ SELinux 配置

CentOS 默认启用 SELinux，可能需要调整：

### 检查 SELinux 状态

```bash
# 查看状态
getenforce

# 查看详细信息
sestatus
```

### 配置 SELinux（如果遇到问题）

```bash
# 方式1: 临时禁用（测试用）
sudo setenforce 0

# 方式2: 永久禁用（不推荐）
sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
# 需要重启生效

# 方式3: 允许端口保护脚本（推荐）
sudo setsebool -P httpd_can_network_connect 1
sudo semanage permissive -a iptables_t  # 如果需要
```

### SELinux 上下文

```bash
# 设置正确的上下文
sudo chcon -t bin_t /path/to/*.sh
sudo restorecon -v /path/to/*.sh
```

---

## 📦 RDP 紧急保护（CentOS 版本）

### 快速保护

```bash
# 一键保护
sudo ./rdp-emergency.sh quick-protect
```

### CentOS 特定步骤

```bash
# 1. 确保使用 iptables
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo yum install -y iptables-services
sudo systemctl enable iptables
sudo systemctl start iptables

# 2. 运行紧急保护
sudo ./rdp-emergency.sh quick-protect

# 3. 保存规则
sudo service iptables save

# 4. 配置开机自动恢复
sudo systemctl enable iptables
```

---

## 🔧 Fail2Ban 安装（CentOS）

### 快速安装

```bash
# 使用我们的脚本（已优化 CentOS）
sudo ./install-fail2ban.sh

# 或手动安装
sudo yum install -y epel-release
sudo yum install -y fail2ban fail2ban-systemd
```

### CentOS 专用配置

创建 `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
# 白名单
ignoreip = 127.0.0.1/8 ::1 你的IP地址

# 封禁时间
bantime  = 3600
findtime = 600
maxretry = 5

# 使用 firewalld（如果你用）
banaction = firewallcmd-rich-rules
# 或使用 iptables
# banaction = iptables-multiport

[sshd]
enabled  = true
port     = ssh
# CentOS 使用 secure 日志
logpath  = /var/log/secure
maxretry = 5

[rdp]
enabled  = true
port     = 3389
# 自定义过滤器
filter   = rdp
logpath  = /var/log/messages
maxretry = 3
```

创建过滤器 `/etc/fail2ban/filter.d/rdp.conf`:

```ini
[Definition]
failregex = ^.*Failed password.*from <HOST>.*$
            ^.*Connection reset by.*<HOST>.*$
ignoreregex =
```

启动服务：

```bash
# 启动 Fail2Ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 查看状态
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

---

## 🐳 CrowdSec Docker（CentOS）

### 前提条件

```bash
# 安装 Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动 Docker
sudo systemctl enable docker
sudo systemctl start docker

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 部署 CrowdSec

```bash
# 使用部署脚本
sudo ./deploy-crowdsec-docker.sh
```

### CentOS 防火墙配置

```bash
# 如果使用 firewalld
sudo firewall-cmd --permanent --add-port=8080/tcp  # CrowdSec API
sudo firewall-cmd --permanent --add-port=3000/tcp  # Dashboard
sudo firewall-cmd --reload

# 如果使用 iptables
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo service iptables save
```

---

## 📝 CentOS 日志位置

| 服务 | CentOS 日志 | Debian/Ubuntu 日志 |
|------|-------------|-------------------|
| SSH | /var/log/secure | /var/log/auth.log |
| 系统消息 | /var/log/messages | /var/log/syslog |
| 内核 | /var/log/dmesg | /var/log/kern.log |
| Fail2Ban | /var/log/fail2ban.log | 相同 |

### 配置日志监控

```bash
# 修改 acquis.yaml（CrowdSec）
cat > crowdsec/config/acquis.yaml << 'EOF'
---
filenames:
  - /logs/secure
labels:
  type: syslog

---
filenames:
  - /logs/messages
labels:
  type: syslog
EOF

# 修改 docker-compose.yml 挂载
volumes:
  - /var/log/secure:/logs/secure:ro
  - /var/log/messages:/logs/messages:ro
```

---

## 🔄 系统服务管理（CentOS）

### 启用服务开机自启

```bash
# iptables
sudo systemctl enable iptables

# Fail2Ban
sudo systemctl enable fail2ban

# Docker
sudo systemctl enable docker

# CrowdSec Bouncer
sudo systemctl enable crowdsec-firewall-bouncer
```

### 查看服务状态

```bash
# 查看所有相关服务
sudo systemctl status iptables
sudo systemctl status fail2ban
sudo systemctl status crowdsec-firewall-bouncer
```

### 重启服务

```bash
# 重启防火墙
sudo systemctl restart iptables

# 重启 Fail2Ban
sudo systemctl restart fail2ban
```

---

## 🚨 故障排除（CentOS 专用）

### 问题1: "Cannot create ipset"

**原因**: 内核模块未加载

**解决**:
```bash
# 加载内核模块
sudo modprobe ip_set
sudo modprobe ip_set_hash_ip
sudo modprobe ip_set_hash_net

# 验证
lsmod | grep ip_set

# 开机自动加载
echo "ip_set" | sudo tee -a /etc/modules-load.d/ipset.conf
echo "ip_set_hash_ip" | sudo tee -a /etc/modules-load.d/ipset.conf
```

### 问题2: SELinux 阻止脚本运行

**症状**: Permission denied

**解决**:
```bash
# 查看 SELinux 日志
sudo grep denied /var/log/audit/audit.log | tail

# 临时禁用测试
sudo setenforce 0

# 如果可以运行，添加策略
sudo audit2allow -a -M port-protect
sudo semodule -i port-protect.pp

# 恢复 SELinux
sudo setenforce 1
```

### 问题3: firewalld 与 iptables 冲突

**症状**: 规则不生效

**解决**:
```bash
# 方案1: 禁用 firewalld，使用 iptables
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl mask firewalld
sudo yum install -y iptables-services
sudo systemctl enable iptables
sudo systemctl start iptables

# 方案2: 使用 firewalld
# 修改脚本使用 firewall-cmd
```

### 问题4: EPEL 仓库问题

**症状**: 无法安装某些包

**解决**:
```bash
# 安装 EPEL
sudo yum install -y epel-release

# 如果失败，手动添加
# CentOS 7
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# CentOS 8
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
```

---

## 🎯 完整部署示例（CentOS 7）

```bash
# 1. 系统准备
sudo yum update -y
sudo yum install -y epel-release

# 2. 安装依赖
sudo yum install -y ipset iptables iptables-services

# 3. 配置防火墙
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl enable iptables
sudo systemctl start iptables

# 4. 初始化黑名单系统
cd /path/to/port-protection
sudo ./blacklist-manager.sh install-deps
sudo ./blacklist-manager.sh init

# 5. RDP 紧急保护
sudo ./rdp-emergency.sh quick-protect

# 6. 动态 IP 管理
sudo ./dynamic-ip-whitelist.sh init
sudo ./dynamic-ip-whitelist.sh add-current

# 7. 保存规则
sudo service iptables save

# 8. 验证
sudo ./blacklist-manager.sh status
sudo iptables -L -n
```

---

## 🎯 完整部署示例（CentOS 8/9）

```bash
# 1. 系统准备
sudo dnf update -y
sudo dnf install -y epel-release

# 2. 安装依赖
sudo dnf install -y ipset iptables iptables-services

# 3. 配置防火墙（同 CentOS 7）
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl enable iptables
sudo systemctl start iptables

# 4-8. 同 CentOS 7
```

---

## 📊 CentOS vs Debian 命令对照表

| 操作 | CentOS | Debian/Ubuntu |
|------|--------|---------------|
| 安装包 | yum/dnf install | apt-get install |
| 搜索包 | yum search | apt-cache search |
| 更新列表 | yum check-update | apt-get update |
| 升级系统 | yum update | apt-get upgrade |
| 删除包 | yum remove | apt-get remove |
| 查看已安装 | rpm -qa | dpkg -l |
| 查看日志 | /var/log/secure | /var/log/auth.log |
| 防火墙 | firewalld/iptables | ufw/iptables |
| SELinux | getenforce | N/A |

---

## ✅ CentOS 部署检查清单

完成部署后检查：

- [ ] EPEL 仓库已安装
- [ ] ipset, iptables 已安装
- [ ] firewalld 已停止（如果使用 iptables）
- [ ] iptables 服务已启用
- [ ] SELinux 配置正确（或临时禁用）
- [ ] 黑名单系统已初始化
- [ ] 你的 IP 已加入白名单
- [ ] iptables 规则已保存
- [ ] 服务开机自启已配置
- [ ] 可以正常 RDP/SSH 连接

---

## 🔗 相关文档

- `README_SOLUTION.md` - 完整解决方案总结
- `RDP_EMERGENCY_GUIDE.md` - RDP 紧急保护指南
- `DYNAMIC_IP_SOLUTION.md` - 动态 IP 解决方案
- `OPEN_SOURCE_ALTERNATIVES.md` - 开源项目对比

---

## 💡 推荐方案（CentOS）

**最简单**:
```bash
sudo ./rdp-emergency.sh quick-protect
```

**企业级**:
```bash
sudo ./install-fail2ban.sh
```

**现代化**:
```bash
sudo ./deploy-crowdsec-docker.sh
```

需要帮助？运行诊断：
```bash
sudo ./blacklist-manager.sh diagnose
```

🎉 **祝你部署顺利！**
