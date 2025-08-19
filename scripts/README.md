# Docker 端口保护脚本使用手册

## 概述

`port-protect.sh` 是一个增强版的 Docker Host 模式端口保护脚本，提供了完整的 iptables 规则管理功能，包括添加、移除、备份和恢复端口防护规则。

## 功能特性

- ✅ **端口保护**: 为指定端口添加速率限制和访问控制
- ✅ **可信IP管理**: 支持添加多个可信IP地址白名单
- ✅ **规则备份**: 自动备份和恢复 iptables 规则
- ✅ **持久化保存**: 支持将规则保存到系统配置，重启后自动加载
- ✅ **状态监控**: 查看当前防护状态和规则详情
- ✅ **错误处理**: 完善的参数验证和错误处理机制

## 系统要求

- **操作系统**: Linux (支持 iptables)
- **权限**: root 用户权限
- **依赖**: iptables, iptables-save, iptables-restore

### 安装依赖

```bash
# Debian/Ubuntu
sudo apt-get install iptables-persistent

# CentOS/RHEL
sudo yum install iptables-services
```

## 安装说明

1. 下载脚本到系统目录:
```bash
sudo cp port-protect.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/port-protect.sh
```

2. 创建符号链接 (可选):
```bash
sudo ln -s /usr/local/bin/port-protect.sh /usr/local/bin/port-protect
```

## 基本用法

### 命令格式
```bash
./port-protect.sh [命令] [参数]
```

### 可用命令

| 命令 | 描述 | 示例 |
|------|------|------|
| `add` | 添加端口保护规则 | `./port-protect.sh add 8080` |
| `remove` | 移除端口保护规则 | `./port-protect.sh remove 8080` |
| `backup` | 备份当前iptables规则 | `./port-protect.sh backup prod_backup` |
| `restore` | 从备份恢复规则 | `./port-protect.sh restore prod_backup` |
| `list-backups` | 列出所有备份 | `./port-protect.sh list-backups` |
| `save` | 保存规则到持久存储 | `./port-protect.sh save` |
| `status` | 查看当前保护状态 | `./port-protect.sh status` |
| `help` | 显示帮助信息 | `./port-protect.sh help` |

## 详细功能说明

### 1. 添加端口保护

基本用法:
```bash
sudo ./port-protect.sh add 8080
```

高级用法:
```bash
sudo ./port-protect.sh add 8080 \
  --protocol tcp \
  --limit 20/min \
  --burst 30 \
  --trust 192.168.1.100 \
  --trust 10.0.0.0/24 \
  --chain MY_CUSTOM_CHAIN
```

#### 参数说明

| 参数 | 简写 | 默认值 | 描述 |
|------|------|--------|------|
| `--protocol` | `-p` | tcp | 协议类型 (tcp/udp) |
| `--limit` | `-l` | 10/min | 速率限制 (例: 10/min, 5/sec) |
| `--burst` | `-b` | 20 | 突发请求限制数量 |
| `--trust` | `-t` | 无 | 可信IP (可多次使用) |
| `--chain` | `-c` | DOCKER-HOST-PROTECT | 自定义链名称 |

### 2. 移除端口保护

```bash
sudo ./port-protect.sh remove 8080
```

### 3. 备份管理

#### 创建备份
```bash
# 创建带标签的备份
sudo ./port-protect.sh backup production

# 创建自动时间戳备份
sudo ./port-protect.sh backup
```

#### 恢复备份
```bash
# 从标签恢复
sudo ./port-protect.sh restore production

# 从文件路径恢复
sudo ./port-protect.sh restore /var/backups/iptables/iptables_20240101_120000.rules

# 恢复最近的备份
sudo ./port-protect.sh restore
```

#### 查看备份列表
```bash
sudo ./port-protect.sh list-backups
```

### 4. 规则持久化

保存当前规则到系统配置:
```bash
sudo ./port-protect.sh save
```

### 5. 状态查看

查看当前防护状态:
```bash
sudo ./port-protect.sh status
```

## 使用示例

### 场景1: 保护Web服务器

```bash
# 为Web服务器添加保护，允许内网访问
sudo ./port-protect.sh add 80 \
  --protocol tcp \
  --limit 30/min \
  --burst 50 \
  --trust 192.168.1.0/24

sudo ./port-protect.sh add 443 \
  --protocol tcp \
  --limit 30/min \
  --burst 50 \
  --trust 192.168.1.0/24

# 备份配置
sudo ./port-protect.sh backup web_server_protection

# 保存规则
sudo ./port-protect.sh save
```

### 场景2: 保护API服务

```bash
# 为API服务添加严格限制
sudo ./port-protect.sh add 8080 \
  --protocol tcp \
  --limit 5/min \
  --burst 10 \
  --trust 192.168.1.100 \
  --trust 192.168.1.101

# 检查状态
sudo ./port-protect.sh status
```

### 场景3: 临时保护和恢复

```bash
# 备份当前状态
sudo ./port-protect.sh backup before_emergency

# 添加紧急保护
sudo ./port-protect.sh add 22 \
  --protocol tcp \
  --limit 2/min \
  --burst 5 \
  --trust 192.168.1.0/24

# 如果需要回滚
sudo ./port-protect.sh restore before_emergency
```

## 配置文件

脚本使用以下配置文件和目录:

- **备份目录**: `/var/backups/iptables/`
- **当前备份**: `/var/backups/iptables/current.rules`
- **配置文件**: `/etc/port-protect.conf`
- **默认链名**: `DOCKER-HOST-PROTECT`

## 错误处理

脚本包含完善的错误处理机制:

1. **权限检查**: 自动检测是否具有root权限
2. **依赖检查**: 验证必要的系统工具是否安装
3. **参数验证**: 验证端口号、IP地址等参数格式
4. **操作前备份**: 重要操作前自动创建备份
5. **错误回滚**: 操作失败时提供恢复机制

## 常见问题

### Q1: 脚本运行提示权限不足
```bash
# 确保使用root权限运行
sudo ./port-protect.sh status
```

### Q2: 提示缺少依赖项
```bash
# Debian/Ubuntu
sudo apt-get install iptables-persistent

# CentOS/RHEL
sudo yum install iptables-services
```

### Q3: 规则重启后消失
```bash
# 保存规则到持久存储
sudo ./port-protect.sh save
```

### Q4: 误删规则如何恢复
```bash
# 查看可用备份
sudo ./port-protect.sh list-backups

# 恢复最近的备份
sudo ./port-protect.sh restore
```

### Q5: 如何查看当前生效的规则
```bash
# 查看脚本管理的规则
sudo ./port-protect.sh status

# 查看所有iptables规则
sudo iptables -L -n --line-numbers
```

## 安全建议

1. **测试环境**: 在生产环境使用前，先在测试环境验证
2. **备份习惯**: 重要变更前始终创建备份
3. **访问控制**: 确保脚本文件权限设置正确 (755)
4. **日志监控**: 监控系统日志以发现异常访问
5. **定期检查**: 定期检查规则状态和备份完整性

## 高级技巧

### 1. 批量操作
```bash
# 为多个端口添加相同规则
for port in 8080 8081 8082; do
    sudo ./port-protect.sh add $port --trust 192.168.1.0/24
done
```

### 2. 配合定时任务
```bash
# 添加到crontab，每天备份规则
0 2 * * * /usr/local/bin/port-protect.sh backup daily_$(date +\%Y\%m\%d)
```

### 3. 监控脚本
```bash
#!/bin/bash
# 检查端口保护状态
if ! /usr/local/bin/port-protect.sh status | grep -q "DOCKER-HOST-PROTECT"; then
    echo "WARNING: Port protection not active!" | mail -s "Security Alert" admin@example.com
fi
```

## 更新日志

参见项目根目录的 CHANGELOG.md 文件。