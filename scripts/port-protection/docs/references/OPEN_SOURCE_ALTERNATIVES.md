# 开源端口保护项目推荐 - 可直接部署

## 🔥 推荐项目对比

### 1. Fail2Ban ⭐⭐⭐⭐⭐ (最流行)

**项目地址**: https://github.com/fail2ban/fail2ban

**适用系统**: Linux (Debian/Ubuntu/CentOS/RHEL)

**主要功能**:
- ✅ SSH、RDP、FTP等多种协议保护
- ✅ 自动分析日志文件
- ✅ 基于iptables/firewalld自动封禁
- ✅ 灵活的过滤器和动作配置
- ✅ 邮件通知

**优点**:
- 成熟稳定，使用最广泛
- 配置简单，文档完善
- 支持几乎所有服务
- 资源占用低

**缺点**:
- 不支持Windows原生
- 单机运行，无集群功能
- 需要手动配置各种服务

**快速安装**:
```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install fail2ban

# 启动服务
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 查看状态
sudo fail2ban-client status
```

**基础配置** (`/etc/fail2ban/jail.local`):
```ini
[DEFAULT]
bantime  = 3600        # 封禁1小时
findtime = 600         # 10分钟内
maxretry = 5           # 失败5次

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log

[rdp]
enabled  = true
port     = 3389
logpath  = /var/log/syslog
maxretry = 3
```

**推荐指数**: ⭐⭐⭐⭐⭐
**难度**: ⭐⭐ (简单)
**适用场景**: Linux服务器SSH/RDP保护

---

### 2. CrowdSec ⭐⭐⭐⭐⭐ (最现代化)

**项目地址**: https://github.com/crowdsecurity/crowdsec

**适用系统**: Linux, Docker, Kubernetes

**主要功能**:
- ✅ 众包威胁情报（共享恶意IP）
- ✅ 机器学习检测异常行为
- ✅ 分布式架构（检测和执行分离）
- ✅ 现代化API和Web界面
- ✅ 云原生支持（Docker/K8s）

**优点**:
- 现代化架构，性能优秀
- 全球威胁情报共享
- 支持多种bouncer（执行器）
- 可视化控制台
- 活跃的社区

**缺点**:
- 相对较新（2020年）
- 配置稍复杂
- 资源占用比Fail2Ban稍高

**快速安装**:
```bash
# 自动安装脚本
curl -s https://install.crowdsec.net | sudo sh

# 安装collections（场景包）
sudo cscli collections install crowdsecurity/linux
sudo cscli collections install crowdsecurity/sshd
sudo cscli collections install crowdsecurity/rdp

# 安装bouncer（iptables执行器）
sudo apt install crowdsec-firewall-bouncer-iptables

# 查看状态
sudo cscli metrics
sudo cscli decisions list
```

**配置示例**:
```yaml
# /etc/crowdsec/config.yaml
api:
  server:
    enable: true
    listen_uri: 127.0.0.1:8080

# 添加场景
acquisitions:
  - source: file
    filenames:
      - /var/log/auth.log
    labels:
      type: syslog
```

**推荐指数**: ⭐⭐⭐⭐⭐
**难度**: ⭐⭐⭐ (中等)
**适用场景**: 需要现代化方案和威胁情报共享

---

### 3. SSHGuard ⭐⭐⭐⭐

**项目地址**: https://www.sshguard.net/

**适用系统**: Linux, FreeBSD, macOS

**主要功能**:
- ✅ 专注SSH保护
- ✅ 多种防火墙支持
- ✅ 轻量级
- ✅ 实时监控

**优点**:
- 非常轻量
- 配置极简
- 专注SSH，性能好

**缺点**:
- 功能单一（主要是SSH）
- 不支持RDP等其他服务

**快速安装**:
```bash
# Ubuntu/Debian
sudo apt-get install sshguard

# 配置 /etc/sshguard/sshguard.conf
BACKEND="/usr/libexec/sshguard/sshg-fw-iptables"
LOGREADER="LANG=C /usr/bin/journalctl -afb -p info -n1 -t sshd -o cat"

# 启动
sudo systemctl enable sshguard
sudo systemctl start sshguard
```

**推荐指数**: ⭐⭐⭐⭐
**难度**: ⭐ (非常简单)
**适用场景**: 只需要SSH保护

---

### 4. IPBan ⭐⭐⭐⭐⭐ (Windows最佳)

**项目地址**: https://github.com/DigitalRuby/IPBan

**适用系统**: Windows, Linux (跨平台)

**主要功能**:
- ✅ 支持Windows和Linux
- ✅ RDP、SSH、SMTP、MySQL等
- ✅ Windows Event Log集成
- ✅ 防火墙自动管理
- ✅ 完全免费开源

**优点**:
- Windows原生支持
- 配置文件简单
- 性能优秀
- 支持多种服务

**缺点**:
- 文档相对较少
- 社区不如Fail2Ban大

**Windows快速安装**:
```powershell
# 下载最新版本
# https://github.com/DigitalRuby/IPBan/releases

# 解压到 C:\IPBan
# 编辑 ipban.config

# 安装为Windows服务
.\IPBan.exe install

# 启动服务
Start-Service IPBan
```

**配置示例** (`ipban.config`):
```xml
<appSettings>
  <!-- RDP保护 -->
  <add key="ProcessInternalIPAddresses" value="false" />
  <add key="BanTime" value="01:00:00:00" /> <!-- 1天 -->
  <add key="ExpireTime" value="30.00:00:00" /> <!-- 30天 -->

  <!-- Windows事件日志 -->
  <add key="EventViewer" value="
    Security,4625,ipaddress
    Application,18456,ipaddress
  " />
</appSettings>
```

**推荐指数**: ⭐⭐⭐⭐⭐ (Windows)
**难度**: ⭐⭐ (简单)
**适用场景**: Windows服务器RDP保护

---

### 5. Fail2Ban4Win ⭐⭐⭐⭐

**项目地址**: https://github.com/Aldaviva/Fail2Ban4Win

**适用系统**: Windows

**主要功能**:
- ✅ Fail2Ban的Windows版本
- ✅ 自动封禁RDP/SSH失败尝试
- ✅ 基于Windows Event Log
- ✅ Windows防火墙集成

**优点**:
- 接近Fail2Ban的体验
- 开源免费
- 轻量级

**缺点**:
- 相对较新
- 功能不如IPBan丰富

**快速安装**:
```powershell
# 下载发布版本
# https://github.com/Aldaviva/Fail2Ban4Win/releases

# 安装为Windows服务
.\Fail2Ban4Win.exe install

# 启动
Start-Service Fail2Ban4Win
```

**推荐指数**: ⭐⭐⭐⭐
**难度**: ⭐⭐ (简单)
**适用场景**: Windows RDP保护（简单需求）

---

### 6. OSSEC ⭐⭐⭐⭐

**项目地址**: https://www.ossec.net/

**适用系统**: Linux, Windows, macOS

**主要功能**:
- ✅ 完整的HIDS（入侵检测系统）
- ✅ 日志分析
- ✅ 文件完整性检查
- ✅ Rootkit检测
- ✅ 主动响应

**优点**:
- 功能强大全面
- 跨平台支持
- 企业级功能

**缺点**:
- 配置复杂
- 资源占用较高
- 学习曲线陡峭

**推荐指数**: ⭐⭐⭐
**难度**: ⭐⭐⭐⭐ (复杂)
**适用场景**: 企业级安全需求

---

## 🎯 项目选择指南

### 按操作系统选择

| 操作系统 | 推荐项目 | 备选项目 |
|---------|---------|---------|
| **Linux (Debian/Ubuntu)** | Fail2Ban | CrowdSec, SSHGuard |
| **Linux (现代化需求)** | CrowdSec | Fail2Ban |
| **Windows** | IPBan | Fail2Ban4Win, RdpGuard(付费) |
| **跨平台** | IPBan | CrowdSec |
| **Docker/K8s** | CrowdSec | - |

### 按保护目标选择

| 保护目标 | 推荐项目 | 理由 |
|---------|---------|------|
| **SSH** | Fail2Ban / SSHGuard | 成熟稳定 |
| **RDP (Windows)** | IPBan | 原生支持Windows |
| **RDP (Linux)** | Fail2Ban / CrowdSec | 配置灵活 |
| **Web服务** | CrowdSec | 现代化，威胁情报 |
| **多种服务** | Fail2Ban / IPBan | 全面支持 |

### 按复杂度选择

| 难度 | 项目 | 适合人群 |
|------|------|---------|
| ⭐ 简单 | SSHGuard | 新手，只需SSH保护 |
| ⭐⭐ 简单 | Fail2Ban, IPBan | 有基础Linux/Windows知识 |
| ⭐⭐⭐ 中等 | CrowdSec | 熟悉容器化和现代架构 |
| ⭐⭐⭐⭐ 复杂 | OSSEC | 企业级安全团队 |

---

## 📊 功能对比表

| 功能 | Fail2Ban | CrowdSec | IPBan | SSHGuard | OSSEC |
|------|----------|----------|-------|----------|-------|
| SSH保护 | ✅ | ✅ | ✅ | ✅ | ✅ |
| RDP保护 | ✅ | ✅ | ✅ | ❌ | ✅ |
| Windows原生 | ❌ | ❌ | ✅ | ❌ | ✅ |
| 威胁情报 | ❌ | ✅ | ❌ | ❌ | ❌ |
| Web界面 | ❌ | ✅ | ❌ | ❌ | ⚠️ |
| 集群支持 | ❌ | ✅ | ❌ | ❌ | ✅ |
| 配置难度 | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐⭐ |
| 资源占用 | 低 | 中 | 低 | 很低 | 中 |
| 社区活跃度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🚀 针对你的情况推荐

### 如果你是Linux服务器（Debian/Ubuntu）

**方案1: Fail2Ban（最简单）**
```bash
# 安装
sudo apt-get install fail2ban

# 配置RDP保护
sudo nano /etc/fail2ban/jail.local
```

添加配置：
```ini
[rdp]
enabled  = true
port     = 3389
filter   = rdp
logpath  = /var/log/syslog
maxretry = 3
bantime  = 86400
findtime = 600
```

创建过滤器 `/etc/fail2ban/filter.d/rdp.conf`:
```ini
[Definition]
failregex = ^.*Failed password.*from <HOST>.*$
            ^.*Connection reset by.*<HOST>.*$
ignoreregex =
```

重启服务：
```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status rdp
```

**方案2: CrowdSec（最现代）**
```bash
# 安装
curl -s https://install.crowdsec.net | sudo sh

# 安装场景包
sudo cscli collections install crowdsecurity/rdp
sudo cscli collections install crowdsecurity/sshd

# 安装防火墙bouncer
sudo apt install crowdsec-firewall-bouncer-iptables

# 查看效果
sudo cscli decisions list
```

---

### 如果你是Windows服务器

**推荐: IPBan**

1. 下载: https://github.com/DigitalRuby/IPBan/releases
2. 解压到 `C:\IPBan`
3. 编辑 `ipban.config`:

```xml
<configuration>
  <appSettings>
    <!-- 封禁时间：1天 -->
    <add key="BanTime" value="01:00:00:00" />

    <!-- 失败次数：3次 -->
    <add key="FailedLoginAttemptsBeforeBan" value="3" />

    <!-- 时间窗口：10分钟 -->
    <add key="FailedLoginAttemptsBeforeBanUserNameWhitelist" value="10" />

    <!-- 监控RDP登录失败 -->
    <add key="EventViewer" value="Security,4625,ipaddress" />

    <!-- 白名单 -->
    <add key="Whitelist" value="127.0.0.1,你的IP地址" />
  </appSettings>
</configuration>
```

4. 安装为服务：
```powershell
.\IPBan.exe install
Start-Service IPBan
```

5. 查看日志：
```powershell
Get-EventLog -LogName Application -Source IPBan -Newest 20
```

---

## 💡 混合方案（最佳实践）

### Linux + RDP + 动态IP

```bash
# 1. 安装Fail2Ban
sudo apt-get install fail2ban

# 2. 配置RDP保护
sudo tee /etc/fail2ban/jail.d/rdp.conf << 'EOF'
[rdp]
enabled  = true
port     = 3389
filter   = rdp
logpath  = /var/log/syslog
maxretry = 3
bantime  = 86400
findtime = 600

# 白名单（你的IP段）
ignoreip = 127.0.0.1/8 ::1
EOF

# 3. 创建过滤器
sudo tee /etc/fail2ban/filter.d/rdp.conf << 'EOF'
[Definition]
failregex = ^.*Failed password.*from <HOST>.*$
ignoreregex =
EOF

# 4. 启动
sudo systemctl restart fail2ban

# 5. 查看状态
sudo fail2ban-client status rdp
sudo fail2ban-client get rdp actionban
```

### 同时使用Fail2Ban + CrowdSec

```bash
# Fail2Ban负责本地快速响应
# CrowdSec负责全球威胁情报

# 1. 安装两者
sudo apt-get install fail2ban
curl -s https://install.crowdsec.net | sudo sh

# 2. Fail2Ban配置快速封禁（SSH）
# /etc/fail2ban/jail.local
[sshd]
enabled = true
bantime = 3600
maxretry = 3

# 3. CrowdSec配置长期防护（RDP等）
sudo cscli collections install crowdsecurity/rdp
sudo apt install crowdsec-firewall-bouncer-iptables

# 4. 两者协同工作
# - Fail2Ban: 快速本地响应
# - CrowdSec: 利用全球情报预防
```

---

## 📋 对比总结

### 你的需求匹配度

**需求**: RDP保护 + 动态IP + Debian/Ubuntu

| 方案 | 匹配度 | 推荐 |
|------|-------|------|
| **自己的脚本** | ⭐⭐⭐⭐ | 高度定制化 |
| **Fail2Ban** | ⭐⭐⭐⭐⭐ | 最简单成熟 |
| **CrowdSec** | ⭐⭐⭐⭐⭐ | 最现代强大 |
| **IPBan** | ⭐⭐⭐ | Windows更好 |

### 最终推荐

**方案1: 使用自己的脚本（已优化）**
- ✅ 完全符合你的需求
- ✅ 高度定制化
- ✅ 动态IP完美支持
- ✅ RDP专项保护

**方案2: 使用Fail2Ban（企业级成熟方案）**
- ✅ 久经考验
- ✅ 社区支持强大
- ✅ 配置灵活
- ⚠️ 需要配置动态IP（可结合你的脚本）

**方案3: 使用CrowdSec（现代化方案）**
- ✅ 最新技术
- ✅ 威胁情报共享
- ✅ 性能优秀
- ⚠️ 配置稍复杂

**混合方案（推荐）:**
```bash
# 使用Fail2Ban作为基础防护
sudo apt-get install fail2ban

# 使用你的脚本管理动态IP白名单
sudo ./dynamic-ip-whitelist.sh init
sudo ./rdp-emergency.sh quick-protect

# 两者配合使用
```

---

## 🎯 行动建议

**立即可用的方案:**

1. **最快速**: 使用你自己的脚本
   ```bash
   sudo ./rdp-emergency.sh quick-protect
   ```

2. **最稳定**: 安装Fail2Ban
   ```bash
   sudo apt-get install fail2ban
   # 配置后启动
   ```

3. **最现代**: 安装CrowdSec
   ```bash
   curl -s https://install.crowdsec.net | sudo sh
   ```

**我的建议**: 先用你自己的脚本立即解决问题，然后再考虑迁移到Fail2Ban或CrowdSec作为长期方案。

需要帮你安装配置任何一个开源项目吗？
