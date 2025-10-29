# Docker 端口保护脚本使用手册

## 概述

`port-protect.sh` 是一个增强版的 Docker Host 模式端口保护脚本，提供了完整的 iptables 规则管理功能，包括添加、移除、备份和恢复端口防护规则。

## 功能特性

- ✅ **端口保护**: 为指定端口添加速率限制和访问控制
- ✅ **RDP优化模式**: 专为RDP等长连接协议优化的保护模式
- ✅ **白名单模式**: 仅允许可信IP访问的严格访问控制
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

1. 创建符号链接 (可选):

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
| `list-ports` | 列出已受保护端口 | `./port-protect.sh list-ports` |
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
| `--limit` | `-l` | 5/min | 速率限制 (例: 5/min, 5/sec) |
| `--burst` | `-b` | 10 | 突发请求限制数量 |
| `--trust` | `-t` | 无 | 可信IP (可多次使用) |
| `--chain` | `-c` | DOCKER-HOST-PROTECT | 自定义链名称 |
| `--rdp` | `-r` | 无 | RDP协议优化模式 |
| `--whitelist-only` | `-w` | 无 | 仅允许可信IP访问 |

### 2. 移除端口保护

基本用法:

```bash
# 移除TCP端口（默认）
sudo ./port-protect.sh remove 8080

# 移除UDP端口
sudo ./port-protect.sh remove 8080 --protocol udp

# 移除指定链名称的端口
sudo ./port-protect.sh remove 8080 --chain MY_CUSTOM_CHAIN
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

### 场景2: 保护RDP远程桌面服务

```bash
# 方式1: RDP优化模式 (推荐)
sudo ./port-protect.sh add 19099 \
  --rdp \
  --trust 192.168.1.100 \
  --trust 10.0.0.0/24

# 方式2: 仅白名单模式 (最安全)
sudo ./port-protect.sh add 19099 \
  --whitelist-only \
  --trust 192.168.1.100 \
  --trust 192.168.1.101

# 备份配置
sudo ./port-protect.sh backup rdp_protection

# 保存规则
sudo ./port-protect.sh save
```

### 场景2.1: 多个RDP端口同时防护

自 2025-09 起，脚本默认为每个端口创建独立链 `DOCKER-HOST-PROTECT-<port>`，互不影响，适合多实例 RDP。

```bash
# 添加多个 RDP 端口
for p in 19099 19100 19101; do
  sudo ./port-protect.sh add $p --rdp --trust 192.168.1.100
done

# 查看受保护端口汇总
sudo ./port-protect.sh list-ports

# 移除其中一个端口
sudo ./port-protect.sh remove 19100
```

如果需要统一策略并集中维护，可显式指定同一个共享链（注意：共享链中 flush 行为不会自动触发，需手动维护）：

```bash
sudo ./port-protect.sh add 19099 --rdp --chain DOCKER-HOST-PROTECT --trust 192.168.1.100
sudo ./port-protect.sh add 19100 --rdp --chain DOCKER-HOST-PROTECT --trust 192.168.1.100
```

> 安全提示：共享链模式下可信 IP 规则仍绑定端口 (--dport)，不会意外放宽其它端口。

### 场景3: 保护SSH服务

```bash
# SSH服务使用白名单模式最安全
sudo ./port-protect.sh add 22 \
  --whitelist-only \
  --trust 192.168.1.0/24 \
  --trust 203.0.113.100

# 或者使用严格的速率限制
sudo ./port-protect.sh add 22 \
  --protocol tcp \
  --limit 2/min \
  --burst 5 \
  --trust 192.168.1.0/24
```

### 场景4: 保护API服务

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

### 场景5: 临时保护和恢复

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

### 链策略变更说明 (2025-09)

旧版本：所有端口复用单一链 `DOCKER-HOST-PROTECT`，每次添加新端口会 flush 影响已有端口规则。

新版本：默认为每个端口创建独立链 `DOCKER-HOST-PROTECT-<port>`；只有在显式使用 `--chain <name>` 时才共享。

迁移：原先已存在的 `DOCKER-HOST-PROTECT` 输入引用仍能正常工作，移除端口会自动检测对应链，不需手动迁移。建议为关键端口重新执行 add 命令获得独立链隔离。

### 默认参数说明 (2025-10 更新)

脚本支持三种模式，每种有不同的默认参数：

- **标准模式**: 速率限制 `5/min`，突发 `10`
- **RDP模式** (`--rdp`): 速率限制 `30/min`，突发 `50`
- **严格模式** (`--strict`): 速率限制 `2/min`，突发 `3`

用户可以通过 `-l` 和 `-b` 参数覆盖任何模式的默认值，参数位置不影响结果：

```bash
# 使用RDP模式但自定义限制
sudo ./port-protect.sh add 19099 --rdp -l 20/min -b 25 -t 1.2.3.4

# 参数顺序不影响结果（以下两种写法等效）
sudo ./port-protect.sh add 19099 -l 20/min --rdp -t 1.2.3.4
sudo ./port-protect.sh add 19099 --rdp -l 20/min -t 1.2.3.4
```

优先级规则：用户指定的 `-l` 和 `-b` 参数 > 模式默认值 > 全局默认值

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

### Q6: RDP连接添加规则后无法使用

```bash
# 先移除有问题的规则
sudo ./port-protect.sh remove 19099

# 使用RDP优化模式重新添加
sudo ./port-protect.sh add 19099 --rdp -t 你的IP地址

# 或使用白名单模式（最安全）
sudo ./port-protect.sh add 19099 --whitelist-only -t 你的IP地址
```

### Q7: 如何为特定协议选择合适的保护模式

- **RDP/VNC等远程桌面**: 推荐使用 `--rdp` 模式或 `--whitelist-only` 模式
- **SSH**: 推荐使用 `--whitelist-only` 模式，限制特定IP访问
- **Web服务**: 使用默认模式，适当调整 `--limit` 和 `--burst` 参数
- **API服务**: 使用较严格的速率限制或白名单模式

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

# 为多个RDP端口添加优化保护
for port in 3389 19099 19100; do
    sudo ./port-protect.sh add $port --rdp --trust 192.168.1.0/24
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

## 新功能详解

### RDP优化模式 (`--rdp`)

RDP优化模式专为远程桌面协议设计，解决了传统速率限制对长连接协议的影响：

**特性：**

- 自动调整速率限制为 `30/min`，突发限制为 `50`
- 允许已建立的连接（`ESTABLISHED,RELATED` 状态）无限制通过
- 针对RDP协议的连接特性进行优化

**适用场景：**

- Windows远程桌面连接
- VNC连接
- 其他需要保持长连接的远程管理协议

### 白名单模式 (`--whitelist-only`)

白名单模式提供最严格的访问控制，仅允许指定的IP地址访问：

**特性：**

- 不使用速率限制，直接基于IP地址进行访问控制
- 必须配合 `--trust` 参数使用
- 提供最高级别的安全保护

**适用场景：**

- SSH管理端口
- 数据库连接端口
- 内部管理接口
- 高安全性要求的服务

## 自动封禁功能

### 功能概述

自动封禁系统可以监控被端口保护规则拦截的IP地址，当某个IP在指定时间窗口内触发防护规则超过阈值次数时，自动将其加入黑名单封禁30天。

**核心特性**:
- ✅ 自动监控: 实时监控系统日志，检测异常IP
- ✅ 智能封禁: 基于阈值自动封禁，30天后自动解封
- ✅ 白名单保护: 可信IP永不封禁
- ✅ 滚动日志: 完整记录封禁历史，支持日志轮转
- ✅ 高效管理: 使用ipset，O(1)查询复杂度

**组件说明**:
- `port-protect.sh`: 端口保护（支持 `--enable-log` 选项）
- `blacklist-manager.sh`: 黑名单管理（封禁/解封/查看）
- `auto-ban.sh`: 自动监控服务

### 快速部署（5分钟）

#### 1. 初始化黑名单系统
```bash
cd /path/to/scripts/port-protection

# 初始化黑名单系统
sudo ./blacklist-manager.sh init

# 创建配置文件
sudo ./auto-ban.sh init
```

#### 2. 配置白名单
编辑配置文件，添加可信IP：
```bash
sudo nano /etc/port-protect-autoban.conf
```

配置示例：
```bash
# 白名单配置
WHITELIST=(
    "127.0.0.1"
    "192.168.0.0/16"
    "10.0.0.0/8"
    "你的办公室IP"  # 改为实际IP
)

# 封禁配置
BAN_THRESHOLD=10        # 10次触发后封禁
TIME_WINDOW=600         # 10分钟时间窗口
BAN_DURATION=2592000    # 封禁30天
```

#### 3. 添加端口保护并启用日志
```bash
# 重要：必须添加 --enable-log 选项！

# 保护SSH
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 192.168.1.0/24

# 保护RDP
sudo ./port-protect.sh add 3389 --rdp --enable-log -t 192.168.1.100

# 保护其他端口
sudo ./port-protect.sh add 8080 --enable-log -t 192.168.1.0/24
```

#### 4. 启动自动监控
```bash
# 启动监控服务（后台运行）
sudo ./auto-ban.sh start

# 查看状态
sudo ./auto-ban.sh status

# 查看实时日志
sudo tail -f /var/log/port-protect-autoban.log
```

### 配置说明

**配置文件**: `/etc/port-protect-autoban.conf`

**主要参数**:
```bash
BAN_THRESHOLD=10        # 触发次数：在时间窗口内触发多少次后封禁
TIME_WINDOW=600         # 时间窗口（秒）：600秒 = 10分钟
BAN_DURATION=2592000    # 封禁时长（秒）：2592000秒 = 30天，0 = 永久
AUTO_BAN_ENABLED=true   # 自动封禁开关：true启用，false只监控不封禁
```

**阈值配置建议**:

| 场景 | 阈值 | 时间窗口 | 封禁时长 |
|------|------|----------|----------|
| SSH保护 | 5次 | 5分钟 | 30天 |
| Web服务 | 20次 | 10分钟 | 7天 |
| API服务 | 50次 | 30分钟 | 24小时 |
| RDP保护 | 10次 | 10分钟 | 30天 |

### 使用示例

#### 场景1：保护SSH服务
```bash
# 1. 添加SSH端口保护（白名单+日志）
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 192.168.1.0/24

# 2. 启动自动监控
sudo ./auto-ban.sh start

# 3. 查看日志
sudo tail -f /var/log/port-protect-autoban.log
```

#### 场景2：保护多个RDP端口
```bash
# 1. 批量添加RDP端口（启用日志）
for port in 3389 19099 19100; do
    sudo ./port-protect.sh add $port --rdp --enable-log -t 192.168.1.100
done

# 2. 启动监控
sudo ./auto-ban.sh start

# 3. 查看受保护端口
sudo ./port-protect.sh list-ports
```

#### 场景3：保护Web应用
```bash
# 1. 添加Web端口保护
sudo ./port-protect.sh add 80 -l 30/min -b 50 --enable-log
sudo ./port-protect.sh add 443 -l 30/min -b 50 --enable-log

# 2. 配置较宽松的阈值（Web应用流量大）
sudo nano /etc/port-protect-autoban.conf
# 设置: BAN_THRESHOLD=50, TIME_WINDOW=600

# 3. 启动监控
sudo ./auto-ban.sh start
```

### 日志管理

**日志文件**:

| 日志文件 | 说明 | 位置 |
|----------|------|------|
| 系统日志 | iptables DROP记录 | /var/log/syslog |
| 监控日志 | 监控运行日志 | /var/log/port-protect-autoban.log |
| 封禁日志 | 当前封禁记录 | /var/log/port-protect-ban.log |
| 历史记录 | 完整封禁历史 | /var/log/port-protect-ban-history.log |

**查看日志**:
```bash
# 查看监控日志（实时）
sudo tail -f /var/log/port-protect-autoban.log

# 查看封禁日志
sudo tail -f /var/log/port-protect-ban.log

# 查看系统日志中的DROP记录
sudo tail -f /var/log/syslog | grep PORT-PROTECT-DROP

# 查看封禁历史
sudo ./blacklist-manager.sh history
```

### 常用命令速查

**监控管理**:
```bash
sudo ./auto-ban.sh start          # 启动监控
sudo ./auto-ban.sh stop           # 停止监控
sudo ./auto-ban.sh status         # 查看状态
sudo ./auto-ban.sh test           # 测试模式（不实际封禁）
sudo ./auto-ban.sh reload         # 重新加载配置
```

**黑名单管理**:
```bash
sudo ./blacklist-manager.sh init                    # 初始化系统
sudo ./blacklist-manager.sh ban 1.2.3.4            # 封禁IP（30天）
sudo ./blacklist-manager.sh ban 1.2.3.4 "原因" 0    # 永久封禁
sudo ./blacklist-manager.sh unban 1.2.3.4          # 解封IP
sudo ./blacklist-manager.sh check 1.2.3.4          # 检查IP
sudo ./blacklist-manager.sh list                   # 列出黑名单
sudo ./blacklist-manager.sh history                # 查看历史
sudo ./blacklist-manager.sh flush                  # 清空黑名单
sudo ./blacklist-manager.sh status                 # 查看状态
```

### 常见问题

**Q: 监控服务无法启动**

检查依赖和初始化：
```bash
# 安装依赖
sudo apt-get install ipset iptables  # Debian/Ubuntu
sudo yum install ipset iptables       # CentOS/RHEL

# 重新初始化
sudo ./blacklist-manager.sh init
sudo ./auto-ban.sh start
```

**Q: 没有检测到被拦截的IP**

可能未启用日志记录：
```bash
# 检查端口保护是否启用日志
sudo ./port-protect.sh status

# 检查系统日志
sudo tail /var/log/syslog | grep PORT-PROTECT-DROP

# 重新添加端口保护，确保启用日志
sudo ./port-protect.sh remove 22
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 你的IP
```

**Q: 白名单IP被封禁**

解封并添加到白名单：
```bash
# 1. 解封IP
sudo ./blacklist-manager.sh unban 你的IP

# 2. 添加到白名单
sudo nano /etc/port-protect-autoban.conf
# 在WHITELIST数组中添加IP

# 3. 重新加载配置
sudo ./auto-ban.sh reload
```

**Q: 如何设置永久封禁**

```bash
# 封禁时长设置为0表示永久
sudo ./blacklist-manager.sh ban 1.2.3.4 "恶意扫描" 0
```

## 更新日志

参见项目根目录的 CHANGELOG.md 文件。
