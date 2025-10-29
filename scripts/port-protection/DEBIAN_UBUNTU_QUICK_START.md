# Port Protection - Debian/Ubuntu 快速开始指南

> 针对 Debian/Ubuntu 系统优化的端口保护系统快速部署指南

## 系统要求

- **操作系统**: Debian 10+, Ubuntu 18.04+ 或衍生版本 (Linux Mint, Pop!_OS 等)
- **内核版本**: 支持 ipset 和 netfilter (大部分现代内核都支持)
- **权限**: root 或 sudo 权限
- **网络**: 需要配置防火墙规则

## 快速安装

### 1. 安装依赖 (自动)

脚本会自动检查并提示安装缺失的依赖：

```bash
cd /path/to/port-protection
sudo ./blacklist-manager.sh install-deps
```

这将自动安装：
- `ipset` - IP集合管理工具
- `iptables` - 防火墙规则
- `iptables-persistent` - 规则持久化
- `ipset-persistent` - ipset 持久化 (如果可用)

### 2. 初始化系统

```bash
sudo ./blacklist-manager.sh init
```

初始化将自动：
- ✓ 创建 ipset 集合
- ✓ 配置 iptables 规则
- ✓ 创建日志文件
- ✓ 保存配置以便重启后恢复

### 3. 验证安装

```bash
sudo ./blacklist-manager.sh status
```

您应该看到所有组件都显示为"运行中"或"已配置"。

## 基础使用

### 封禁 IP

```bash
# 封禁 IP（默认 30 天）
sudo ./blacklist-manager.sh ban 1.2.3.4

# 指定原因和时长（24小时）
sudo ./blacklist-manager.sh ban 1.2.3.4 "SSH 爆破攻击" 86400

# 永久封禁
sudo ./blacklist-manager.sh ban 1.2.3.4 "恶意扫描" 0
```

### 解封 IP

```bash
sudo ./blacklist-manager.sh unban 1.2.3.4
```

### 查看黑名单

```bash
# 查看当前封禁列表
sudo ./blacklist-manager.sh list

# 查看封禁历史
sudo ./blacklist-manager.sh history

# 查看特定IP的历史
sudo ./blacklist-manager.sh history 1.2.3.4
```

### 检查 IP 状态

```bash
sudo ./blacklist-manager.sh check 1.2.3.4
```

## 高级功能

### 诊断系统问题

如果遇到"无法创建ipset"或其他错误：

```bash
sudo ./blacklist-manager.sh diagnose
```

这将检查：
- 操作系统版本
- 依赖包安装状态
- 内核模块加载情况
- ipset 和 iptables 配置
- 日志文件状态

### 持久化配置

```bash
# 手动保存 ipset（init 命令会自动保存）
sudo ./blacklist-manager.sh save

# 从文件恢复 ipset
sudo ./blacklist-manager.sh restore
```

### 日志管理

#### 安装 logrotate 配置

```bash
# 安装日志轮转配置
sudo cp port-protect.logrotate /etc/logrotate.d/port-protect

# 测试配置
sudo logrotate -d /etc/logrotate.d/port-protect

# 手动执行轮转
sudo logrotate -f /etc/logrotate.d/port-protect
```

#### 查看日志

```bash
# 查看封禁日志
sudo tail -f /var/log/port-protect-ban.log

# 查看历史记录
sudo tail -f /var/log/port-protect-ban-history.log
```

#### 清理旧日志

```bash
# 清理 30 天前的备份日志
sudo ./blacklist-manager.sh cleanup
```

## 开机自动恢复

### 方法 1: 使用 netfilter-persistent (推荐)

```bash
# 安装 netfilter-persistent（install-deps 已包含）
sudo apt-get install iptables-persistent

# 保存规则
sudo netfilter-persistent save

# 规则将在重启后自动恢复
```

### 方法 2: 使用 systemd 服务

创建 `/etc/systemd/system/port-protect-restore.service`:

```ini
[Unit]
Description=Restore Port Protection IPSet
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/blacklist-manager.sh restore
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable port-protect-restore.service
sudo systemctl start port-protect-restore.service
```

## 故障排除

### 问题: "无法创建ipset"

**解决方案:**

1. 检查内核模块:
```bash
sudo modprobe ip_set
sudo modprobe ip_set_hash_ip
lsmod | grep ip_set
```

2. 运行诊断:
```bash
sudo ./blacklist-manager.sh diagnose
```

3. 确认安装了所有依赖:
```bash
sudo ./blacklist-manager.sh install-deps
```

### 问题: 重启后规则丢失

**解决方案:**

1. 确认 netfilter-persistent 已安装:
```bash
dpkg -l | grep netfilter-persistent
```

2. 保存规则:
```bash
sudo ./blacklist-manager.sh save
sudo netfilter-persistent save
```

3. 或设置 systemd 服务（见上文）

### 问题: 日志文件权限错误

**解决方案:**

```bash
sudo chmod 600 /var/log/port-protect-*.log
sudo chown root:root /var/log/port-protect-*.log
```

### 问题: ipset 命令不存在

**解决方案:**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install ipset iptables

# 或使用脚本自动安装
sudo ./blacklist-manager.sh install-deps
```

## 调试模式

启用详细调试输出：

```bash
DEBUG=1 sudo ./blacklist-manager.sh diagnose
```

## 配置文件位置

- **ipset 保存文件**: `/etc/iptables/ipsets`
- **封禁日志**: `/var/log/port-protect-ban.log`
- **历史记录**: `/var/log/port-protect-ban-history.log`
- **配置文件**: `/etc/port-protect-autoban.conf`
- **logrotate 配置**: `/etc/logrotate.d/port-protect`

## 版本信息

- **脚本版本**: 3.0.0
- **优化系统**: Debian/Ubuntu
- **更新日期**: 2025-10-29

## 完整命令参考

```bash
# 查看帮助
sudo ./blacklist-manager.sh help

# 安装依赖
sudo ./blacklist-manager.sh install-deps

# 初始化系统
sudo ./blacklist-manager.sh init

# IP 管理
sudo ./blacklist-manager.sh ban <IP> [原因] [时长]
sudo ./blacklist-manager.sh unban <IP>
sudo ./blacklist-manager.sh check <IP>

# 查看信息
sudo ./blacklist-manager.sh list
sudo ./blacklist-manager.sh history [IP]
sudo ./blacklist-manager.sh status

# 维护
sudo ./blacklist-manager.sh save
sudo ./blacklist-manager.sh restore
sudo ./blacklist-manager.sh cleanup
sudo ./blacklist-manager.sh flush

# 诊断
sudo ./blacklist-manager.sh diagnose
```

## 下一步

配置自动监控和封禁：查看 `auto-ban.sh` 脚本文档

## 获取帮助

如果遇到问题：

1. 运行诊断: `sudo ./blacklist-manager.sh diagnose`
2. 查看日志: `sudo tail -f /var/log/port-protect-*.log`
3. 启用调试: `DEBUG=1 sudo ./blacklist-manager.sh <命令>`
4. 检查系统兼容性: 确认使用 Debian/Ubuntu 系统
