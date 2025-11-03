# Port Protection - Docker 端口保护工具集

[![Version](https://img.shields.io/badge/version-3.1.1-blue.svg)](changelogs/v3.1.1.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> 🛡️ 企业级 Docker 端口保护解决方案，支持速率限制、白名单、黑名单、动态IP、RDP优化等功能

## 📖 目录结构

```
port-protection/
├── README.md                   # 本文档
├── CHANGELOG.md               # 完整版本历史
│
├── scripts/                   # 🔧 核心脚本
│   ├── port-protect.sh       # ⭐ 主要脚本：端口保护管理
│   ├── quick-whitelist.sh    # 快速白名单管理（多地点访问）
│   ├── rdp-emergency.sh      # RDP 紧急保护
│   ├── auto-ban.sh           # 自动封禁脚本
│   ├── blacklist-manager.sh  # 黑名单管理
│   ├── dynamic-ip-whitelist.sh # 动态IP白名单
│   ├── install-fail2ban.sh   # fail2ban 安装工具
│   ├── deploy-crowdsec-docker.sh # CrowdSec 部署
│   ├── rdp-reconfig.sh       # RDP 重配置
│   └── test-port-protect.sh  # 测试脚本
│
├── config/                    # ⚙️ 配置文件
│   ├── port-protect.logrotate
│   └── docker-compose-crowdsec.yml
│
├── docs/                      # 📚 文档
│   ├── quick-start/          # 快速开始
│   │   ├── QUICK_START.md
│   │   ├── DEBIAN_UBUNTU.md
│   │   └── CENTOS_RHEL.md
│   ├── guides/               # 详细指南
│   │   ├── RDP_USAGE.md
│   │   ├── RDP_EMERGENCY.md
│   │   ├── DYNAMIC_IP.md
│   │   └── CROWDSEC_DOCKER.md
│   ├── references/           # 参考文档
│   └── archive/              # 归档文档
│
└── changelogs/                # 📋 版本日志
    ├── v3.0.0.md
    ├── v3.1.0.md
    └── v3.1.1.md
```

---

## 🚀 快速开始

### 1. 基本端口保护

```bash
# 保护8080端口，允许任意IP但有速率限制
sudo ./scripts/port-protect.sh add 8080 -t 你的IP地址

# 保存规则
sudo ./scripts/port-protect.sh save
```

### 2. RDP 端口保护（推荐配置）

```bash
# RDP 优化模式（双重防护：速率限制 + 并发连接限制）
sudo ./scripts/port-protect.sh add 19099 --rdp -t 你的IP --enable-log

# 保存规则
sudo ./scripts/port-protect.sh save
```

**v3.1.1 重要更新**：
- ✅ 修复了 RDP 端口防护绕过漏洞
- ✅ 新增并发连接数限制（单IP最多3个并发连接）
- ✅ 结合速率限制（30/min）实现双重防护
- ✅ 不影响已登录用户的正常使用

### 3. 多地点访问（新功能）

如果你需要从不同地点（不同IP）登录：

```bash
# 1. SSH登录服务器后，添加当前IP到白名单（2小时有效）
sudo ./scripts/quick-whitelist.sh add-current

# 2. 然后就可以从当前IP RDP登录了
```

📖 详细说明：[快速开始指南](docs/quick-start/QUICK_START.md)

---

## ⭐ 核心功能

### 🛡️ port-protect.sh - 主要脚本

端口保护管理工具，支持：

- ✅ 速率限制（防止暴力破解）
- ✅ 并发连接限制（v3.1.1新增）
- ✅ 白名单模式（仅允许指定IP）
- ✅ RDP优化模式（专为RDP设计）
- ✅ 独立链管理（每个端口独立规则）
- ✅ 规则备份与恢复

**常用命令：**
```bash
sudo ./scripts/port-protect.sh add <端口> [选项]      # 添加保护
sudo ./scripts/port-protect.sh remove <端口>         # 移除保护
sudo ./scripts/port-protect.sh status               # 查看状态
sudo ./scripts/port-protect.sh list-ports           # 列出受保护端口
sudo ./scripts/port-protect.sh save                 # 保存规则
```

📖 详细文档：[RDP使用指南](docs/guides/RDP_USAGE.md)

---

### 🌍 quick-whitelist.sh - 快速白名单（新增）

多地点访问的临时白名单管理：

```bash
sudo ./scripts/quick-whitelist.sh add-current        # 添加当前IP（2小时）
sudo ./scripts/quick-whitelist.sh add 1.2.3.4 1d    # 添加IP（1天）
sudo ./scripts/quick-whitelist.sh list              # 查看白名单
sudo ./scripts/quick-whitelist.sh remove 1.2.3.4    # 移除IP
```

**适用场景：**
- 📱 需要从不同地点访问（办公室、家里、咖啡厅）
- 🌐 动态IP环境
- 🚫 不能使用VPN方案

---

### 🚨 rdp-emergency.sh - RDP 紧急保护

RDP被爆破攻击时的紧急处理：

```bash
sudo ./scripts/rdp-emergency.sh emergency-lock    # 立即锁定RDP
sudo ./scripts/rdp-emergency.sh add-my-ip        # 添加当前IP到白名单
sudo ./scripts/rdp-emergency.sh unlock           # 解除锁定
sudo ./scripts/rdp-emergency.sh quick-protect    # 一键快速保护
```

📖 详细文档：[RDP紧急处理指南](docs/guides/RDP_EMERGENCY.md)

---

### 🔒 blacklist-manager.sh - 黑名单管理

IP黑名单管理工具：

```bash
sudo ./scripts/blacklist-manager.sh ban <IP>          # 封禁IP
sudo ./scripts/blacklist-manager.sh unban <IP>        # 解封IP
sudo ./scripts/blacklist-manager.sh list              # 查看黑名单
sudo ./scripts/blacklist-manager.sh auto-import       # 导入威胁情报
```

---

### 🤖 auto-ban.sh - 自动封禁

基于日志自动封禁攻击IP：

```bash
sudo ./scripts/auto-ban.sh start                 # 启动自动封禁
sudo ./scripts/auto-ban.sh status                # 查看状态
sudo ./scripts/auto-ban.sh stop                  # 停止服务
```

---

## 🎯 使用场景

### 场景1：保护 RDP 端口（最常见）

```bash
# 步骤1：添加RDP保护
sudo ./scripts/port-protect.sh add 19099 --rdp -t 你的IP --enable-log

# 步骤2：安装fail2ban（自动封禁攻击者）
sudo ./scripts/install-fail2ban.sh

# 步骤3：保存规则
sudo ./scripts/port-protect.sh save

# 步骤4：查看状态
sudo ./scripts/port-protect.sh status
```

📊 **防护效果**：
- 单IP最多3个并发连接
- 新连接速率限制：30/min（可调整）
- 5次失败尝试后自动封禁24小时（fail2ban）

---

### 场景2：多地点访问

```bash
# 方案A：RDP模式 + 快速白名单
sudo ./scripts/port-protect.sh add 19099 --rdp --enable-log
sudo ./scripts/quick-whitelist.sh add-current  # 每次切换地点时执行

# 方案B：动态IP白名单服务
sudo ./scripts/dynamic-ip-whitelist.sh setup
sudo ./scripts/dynamic-ip-whitelist.sh start
```

📖 详细文档：[动态IP解决方案](docs/guides/DYNAMIC_IP.md)

---

### 场景3：白名单模式（最安全）

```bash
# 只允许指定IP访问
sudo ./scripts/port-protect.sh add 22 --whitelist-only \
  -t 192.168.1.0/24 \
  -t 10.0.0.0/8

# 保存规则
sudo ./scripts/port-protect.sh save
```

---

## 📊 版本历史

### v3.1.1 (2025-11-03) - 🔴 关键安全修复

**修复RDP端口防护绕过漏洞：**
- ✅ 新增并发连接数限制（单IP最多3个并发连接）
- ✅ 防止攻击者通过多个连接绕过速率限制
- ✅ 保持已建立连接的正常通过（不影响正常使用）
- ✅ 新增 `quick-whitelist.sh` 脚本支持多地点访问

📖 完整日志：[v3.1.1 变更日志](changelogs/v3.1.1.md)

### v3.1.0 (2025-10-29)

**全面支持 CentOS/RHEL：**
- ✅ 自动系统检测（Debian/Ubuntu vs CentOS/RHEL）
- ✅ 自动包管理器选择（apt vs yum/dnf）
- ✅ 自动防火墙检测（iptables vs firewalld）

📖 完整日志：[v3.1.0 变更日志](changelogs/v3.1.0.md)

### v3.0.0 (2025-09)

**重大重构：**
- ✅ 每个端口使用独立链（DOCKER-HOST-PROTECT-<port>）
- ✅ 新增RDP优化模式（`--rdp`）
- ✅ 新增白名单模式（`--whitelist-only`）
- ✅ RDP紧急保护脚本

📖 完整日志：[v3.0.0 变更日志](changelogs/v3.0.0.md)

**查看所有版本**：[CHANGELOG.md](CHANGELOG.md)

---

## 🔧 系统要求

**操作系统：**
- ✅ Debian 9+ / Ubuntu 18.04+
- ✅ CentOS 7+ / RHEL 7+ / Rocky Linux / AlmaLinux
- ✅ Fedora 30+

**依赖项：**
- `iptables`
- `iptables-save` / `iptables-restore`
- `ipset` (可选，用于大规模IP管理)
- `fail2ban` (推荐，用于自动封禁)

### 安装依赖

**Debian/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install iptables-persistent ipset fail2ban
```

**CentOS/RHEL:**
```bash
sudo yum install iptables-services ipset fail2ban
sudo systemctl enable iptables
sudo systemctl start iptables
```

---

## 📚 文档索引

### 快速开始
- [通用快速开始](docs/quick-start/QUICK_START.md)
- [Debian/Ubuntu 快速开始](docs/quick-start/DEBIAN_UBUNTU.md)
- [CentOS/RHEL 快速开始](docs/quick-start/CENTOS_RHEL.md)

### 详细指南
- [RDP 使用指南](docs/guides/RDP_USAGE.md) - RDP端口保护详解
- [RDP 紧急处理](docs/guides/RDP_EMERGENCY.md) - 被攻击时的应急措施
- [动态IP解决方案](docs/guides/DYNAMIC_IP.md) - 多地点访问方案
- [CrowdSec Docker 部署](docs/guides/CROWDSEC_DOCKER.md) - 协同防御

### 参考文档
- [CentOS 注意事项](docs/references/CENTOS_NOTES.md)
- [开源替代方案](docs/references/OPEN_SOURCE_ALTERNATIVES.md)
- [改进总结](docs/references/IMPROVEMENTS_SUMMARY.md)

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📄 许可证

MIT License

---

## 💡 常见问题

### Q1: RDP端口仍然被攻击怎么办？

**A:** 按以下顺序尝试：
1. 确认使用最新版本（v3.1.1）
2. 启用日志并配合fail2ban：`--enable-log`
3. 切换到白名单模式：`--whitelist-only`
4. 更改RDP端口到非标准端口

### Q2: 我需要从多个地点访问怎么办？

**A:** 使用 `quick-whitelist.sh` 脚本：
```bash
ssh server
sudo ./scripts/quick-whitelist.sh add-current
# 然后RDP登录
```

### Q3: 速率限制会影响正常使用吗？

**A:** 不会。RDP模式的限制是：
- 单IP最多3个并发连接（足够正常使用）
- 新连接限制30/min（只影响建立新连接，不影响已登录）
- 白名单IP完全不受限制

### Q4: 如何验证防护是否生效？

**A:** 查看规则：
```bash
sudo ./scripts/port-protect.sh status
sudo iptables -L DOCKER-HOST-PROTECT-端口 -n -v --line-numbers
```

### Q5: 重启后规则会丢失吗？

**A:** 执行 `sudo ./scripts/port-protect.sh save` 保存规则到持久存储。

---

## 📧 联系方式

如有问题或建议，请提交 Issue。

---

**最后更新**: 2025-11-03
**当前版本**: v3.1.1
