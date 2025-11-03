# Port Protection - 版本更新日志

> 📋 完整的版本历史和变更记录

---

## [v3.1.1] - 2025-11-03 🔴 关键安全修复

### 🔒 安全修复

**修复 RDP 端口防护绕过漏洞**

**问题描述：**
- 攻击者可以通过建立多个并发连接绕过速率限制
- 旧版本只限制新连接速率（30/min），不限制并发连接数
- 攻击者同时打开10个连接，每个连接尝试认证，速率限制失效

**修复内容：**
- ✅ 新增 `connlimit` 并发连接数限制（单IP最多3个并发连接）
- ✅ 结合速率限制（30/min）实现双重防护
- ✅ 保持已建立连接的正常通过（不影响已登录用户）
- ✅ 白名单IP不受任何限制影响

### ✨ 新增功能

**quick-whitelist.sh - 快速白名单管理脚本**
- 支持从不同地点（不同IP）访问RDP
- 临时白名单机制（默认2小时自动过期）
- 自动检测当前SSH连接IP
- 支持cron定时清理过期IP

**命令示例：**
```bash
sudo ./scripts/quick-whitelist.sh add-current        # 添加当前IP
sudo ./scripts/quick-whitelist.sh add 1.2.3.4 1d    # 添加IP（1天）
sudo ./scripts/quick-whitelist.sh list              # 查看白名单
```

### 📝 修改的文件

- `scripts/port-protect.sh`: 新增connlimit限制规则（line 458-466）
- `scripts/quick-whitelist.sh`: 新增快速白名单管理脚本
- `docs/guides/RDP_USAGE.md`: 更新问题分析和防护机制说明
- `changelogs/v3.1.1.md`: 新增完整变更日志

### 📊 防护效果对比

| 场景 | v3.1.0（旧版本） | v3.1.1（新版本） |
|------|-----------------|-----------------|
| 攻击者打开10个并发连接 | ✅ 允许（绕过防护） | ❌ 拒绝（只允许3个） |
| 攻击者1分钟尝试100次 | ⚠️ 部分拦截 | ✅ 完全拦截 |
| 正常用户已登录使用 | ✅ 不影响 | ✅ 不影响 |
| 多地点切换 | ⚠️ 需要手动 | ✅ 快速白名单 |

### 🔄 升级建议

如果已使用 RDP 保护，建议立即升级：
```bash
sudo ./scripts/port-protect.sh remove 端口
sudo ./scripts/port-protect.sh add 端口 --rdp -t 你的IP
sudo ./scripts/port-protect.sh save
```

📖 详细文档: [changelogs/v3.1.1.md](changelogs/v3.1.1.md)

---

## [v3.1.0] - 2025-10-29

### 🎯 主要更新

**全面支持 CentOS/RHEL 系统**

本次更新将所有脚本从 Debian/Ubuntu 专用版本升级为多系统通用版本。

### ✅ 支持的系统

- Debian 9+ / Ubuntu 18.04+ / Linux Mint / Pop!_OS
- CentOS 7+ / RHEL 7+ / Rocky Linux / AlmaLinux / Fedora 30+

### 🔧 脚本更新

#### blacklist-manager.sh (v3.0.0 → v3.1.0)

**新增功能：**
- 自动操作系统检测（RHEL vs Debian）
- 自动包管理器选择（yum/dnf vs apt）
- 自动防火墙检测（firewalld vs iptables）
- EPEL 仓库自动安装（CentOS专用）
- 包安装状态检查（rpm vs dpkg）

#### install-fail2ban.sh (v1.0.0 → v2.0.0)

**新增功能：**
- 多系统支持（自动检测并安装）
- 系统服务管理器检测（systemd vs init）
- 自动配置防火墙后端（firewalld vs iptables）

#### auto-ban.sh (v2.0.0 → v2.1.0)

**新增功能：**
- 日志路径自动检测（/var/log/messages vs /var/log/syslog）
- 多系统兼容的日志格式解析

#### deploy-crowdsec-docker.sh (v1.0.0 → v1.1.0)

**新增功能：**
- 自动检测并配置防火墙类型
- 多系统Docker安装支持

### 📚 新增文档

- `docs/quick-start/CENTOS_RHEL.md`: CentOS/RHEL 快速开始指南
- `docs/references/CENTOS_NOTES.md`: CentOS/RHEL 注意事项
- `changelogs/v3.1.0.md`: 完整变更日志

📖 详细文档: [changelogs/v3.1.0.md](changelogs/v3.1.0.md)

---

## [v3.0.0] - 2025-09

### 🔥 重大重构

**独立链架构**

旧版本设计缺陷：
- ❌ 所有端口共享一个链（DOCKER-HOST-PROTECT）
- ❌ 添加第二个端口时会清空第一个端口的规则
- ❌ 可信IP规则未限定端口，放大了权限

新版本设计：
- ✅ 每个端口使用独立链（DOCKER-HOST-PROTECT-<port>）
- ✅ 可信IP规则限定端口（`-p tcp --dport <port>`）
- ✅ 支持用户显式指定共享链（`--chain`）

### ✨ 新增功能

#### RDP 优化模式 (`--rdp`)

```bash
sudo ./scripts/port-protect.sh add 19099 --rdp -t 你的IP
```

**特性：**
- 速率限制: 30/min（突发: 50）
- 允许已建立连接正常通过
- 专为 RDP 长连接优化

#### 白名单模式 (`--whitelist-only`)

```bash
sudo ./scripts/port-protect.sh add 22 --whitelist-only -t 192.168.1.0/24
```

**特性：**
- 仅允许指定IP访问
- 不添加速率限制
- 最安全的访问控制方式

#### 严格模式 (`--strict`)

```bash
sudo ./scripts/port-protect.sh add 8080 --strict
```

**特性：**
- 速率限制: 2/min（突发: 3）
- 适合高安全要求环境

#### 日志记录 (`--enable-log`)

```bash
sudo ./scripts/port-protect.sh add 8080 --rdp --enable-log
```

**特性：**
- 记录被拒绝的连接到syslog
- 速率限制的日志（1/min）
- 配合 fail2ban 使用

### 🆕 新增脚本

#### rdp-emergency.sh - RDP 紧急保护脚本

**用途：** RDP被爆破攻击时的紧急处理

```bash
sudo ./scripts/rdp-emergency.sh emergency-lock    # 立即锁定
sudo ./scripts/rdp-emergency.sh add-my-ip        # 添加当前IP
sudo ./scripts/rdp-emergency.sh unlock           # 解除锁定
sudo ./scripts/rdp-emergency.sh quick-protect    # 一键保护
```

#### rdp-reconfig.sh - RDP 重配置脚本

**用途：** 快速重新配置RDP端口保护

```bash
sudo ./scripts/rdp-reconfig.sh 19099 192.168.1.100
```

### 📝 修改的文件

- `scripts/port-protect.sh`: 重构链管理逻辑（line 388-411）
- `scripts/port-protect.sh`: 新增RDP/白名单/严格模式（line 349-363）
- `scripts/port-protect.sh`: 新增日志功能（line 361-362）
- `scripts/rdp-emergency.sh`: 新增RDP紧急保护
- `scripts/rdp-reconfig.sh`: 新增RDP重配置
- `docs/guides/RDP_USAGE.md`: 新增RDP使用指南

### 📊 向后兼容性

- ✅ 旧命令完全兼容
- ✅ 可以通过 `--chain DOCKER-HOST-PROTECT` 使用旧的共享链模式
- ⚠️ 建议重新配置以使用独立链

📖 详细文档: [changelogs/v3.0.0.md](changelogs/v3.0.0.md)

---

## [v2.3.0] - 2024-XX-XX

### ✨ 新增功能

- 自动IP封禁系统（auto-ban.sh）
- 基于日志的自动封禁
- 威胁IP导入功能

---

## [v2.2.0] - 2024-XX-XX

### 🐛 Bug修复

- 修复多个端口规则冲突问题
- 修复备份恢复功能
- 改进错误处理

---

## [v2.1.0] - 2024-XX-XX

### ✨ 新增功能

- 动态IP白名单（dynamic-ip-whitelist.sh）
- 黑名单管理器（blacklist-manager.sh）
- CrowdSec Docker 部署支持

---

## [v2.0.0] - 2024-XX-XX

### 🔥 重大更新

- 重写核心逻辑
- 支持多端口管理
- 新增规则备份/恢复功能

---

## [v1.0.0] - 2024-XX-XX

### 🎉 首次发布

- 基本端口保护功能
- 速率限制支持
- 可信IP白名单

---

## 图例

- 🔴 关键安全修复
- 🔥 重大更新/重构
- ✨ 新增功能
- 🐛 Bug修复
- 📝 文档更新
- 🔧 配置/工具更新
- ⚠️ 弃用警告
- 🔄 升级建议

---

## 版本号说明

版本号格式：`主版本号.次版本号.修订号` (MAJOR.MINOR.PATCH)

- **主版本号（MAJOR）**：不兼容的API修改
- **次版本号（MINOR）**：向后兼容的功能性新增
- **修订号（PATCH）**：向后兼容的Bug修复

---

**最后更新**: 2025-11-03
