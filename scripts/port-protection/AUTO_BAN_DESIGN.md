# 自动封禁功能设计文档

## 功能概述

为 port-protection 添加自动封禁异常请求 IP 的功能，当某个 IP 频繁触发速率限制时，自动将其加入黑名单。

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    自动封禁系统架构                          │
└─────────────────────────────────────────────────────────────┘

1. port-protect.sh (增强)
   ├── 添加 --enable-log 选项
   ├── DROP 前记录日志（LOG target）
   └── 日志格式: PORT-PROTECT-DROP: SRC=x.x.x.x

2. auto-ban.sh (新增)
   ├── 监控系统日志 (/var/log/syslog)
   ├── 统计每个 IP 的 DROP 次数
   ├── 达到阈值自动封禁
   └── 定期清理过期封禁

3. blacklist-manager.sh (新增)
   ├── 管理黑名单 IP
   ├── 手动添加/删除
   ├── 查看封禁列表
   └── 清空黑名单

4. ipset (使用)
   ├── 高效存储 IP 集合
   ├── 支持超时自动解封
   └── O(1) 查询性能
```

## 核心功能

### 1. 日志记录（port-protect.sh 增强）

```bash
# 添加日志规则（在 DROP 之前）
iptables -A CHAIN -m limit --limit 1/min \
  -j LOG --log-prefix "PORT-PROTECT-DROP: " --log-level 4

# 然后再 DROP
iptables -A CHAIN -j DROP
```

### 2. 自动监控和封禁（auto-ban.sh）

**监控逻辑**：
```
1. tail -f /var/log/syslog
2. 提取 PORT-PROTECT-DROP 日志
3. 统计每个 IP 的触发次数
4. 时间窗口内超过阈值 → 封禁
```

**封禁策略**：
- 默认阈值: 10次/10分钟
- 默认封禁时长: 24小时
- 白名单保护（可信 IP 不封禁）
- 永久黑名单选项

### 3. 黑名单管理（blacklist-manager.sh）

**命令**：
```bash
# 查看黑名单
./blacklist-manager.sh list

# 手动封禁 IP
./blacklist-manager.sh ban <IP> [时长]

# 解封 IP
./blacklist-manager.sh unban <IP>

# 检查 IP 是否被封禁
./blacklist-manager.sh check <IP>

# 清空黑名单
./blacklist-manager.sh flush
```

## 技术实现

### ipset 使用

```bash
# 创建 ipset 集合（支持超时）
ipset create port-protect-blacklist hash:ip timeout 86400

# 添加 IP（24小时后自动删除）
ipset add port-protect-blacklist 1.2.3.4 timeout 86400

# 永久封禁（无超时）
ipset add port-protect-blacklist 1.2.3.4

# iptables 引用 ipset
iptables -I INPUT -m set --match-set port-protect-blacklist src -j DROP
```

### 配置文件

**位置**: `/etc/port-protect-autoban.conf`

```bash
# 监控配置
MONITOR_ENABLED=true
LOG_FILE=/var/log/syslog

# 封禁阈值
BAN_THRESHOLD=10          # 触发次数
TIME_WINDOW=600           # 时间窗口（秒）10分钟
BAN_DURATION=86400        # 封禁时长（秒）24小时

# 白名单（不会被自动封禁）
WHITELIST=(
    "127.0.0.1"
    "192.168.1.0/24"
    "10.0.0.0/8"
)

# 永久黑名单（手动添加，永不过期）
PERMANENT_BLACKLIST=(
    # "1.2.3.4"
)

# ipset 配置
IPSET_NAME="port-protect-blacklist"

# 日志配置
AUTO_BAN_LOG="/var/log/port-protect-autoban.log"
```

## 工作流程

```
1. 用户添加端口保护（带日志）
   └─> port-protect.sh add 8080 --enable-log

2. 启动自动监控服务
   └─> auto-ban.sh start

3. 当有请求被 DROP：
   ├─> 记录到系统日志
   ├─> auto-ban.sh 检测到
   ├─> 统计该 IP 的触发次数
   └─> 超过阈值 → 自动封禁

4. 查看被封禁的 IP
   └─> blacklist-manager.sh list

5. 手动解封（如果需要）
   └─> blacklist-manager.sh unban <IP>
```

## 优势

1. **高效**: 使用 ipset，O(1) 查询复杂度
2. **灵活**: 可配置阈值、时长、白名单
3. **自动**: 无需人工干预
4. **安全**: 白名单保护，避免误封
5. **可控**: 支持手动管理黑名单
6. **轻量**: 资源占用少

## 使用示例

```bash
# 1. 添加端口保护（启用日志）
sudo ./port-protect.sh add 22 --enable-log --whitelist-only -t 192.168.1.0/24

# 2. 启动自动监控（后台运行）
sudo ./auto-ban.sh start

# 3. 查看实时监控
sudo ./auto-ban.sh status

# 4. 查看黑名单
sudo ./blacklist-manager.sh list

# 5. 手动封禁某个 IP
sudo ./blacklist-manager.sh ban 1.2.3.4 3600

# 6. 解封 IP
sudo ./blacklist-manager.sh unban 1.2.3.4

# 7. 停止监控
sudo ./auto-ban.sh stop
```

## 注意事项

1. **系统日志**: 需要确保 rsyslog 或 systemd-journald 正常运行
2. **日志轮转**: 大量日志可能需要配置日志轮转
3. **性能影响**: LOG target 会增加少量性能开销
4. **白名单配置**: 务必正确配置白名单，避免锁定自己
5. **时间同步**: 确保系统时间准确（用于时间窗口计算）

## 后续扩展

1. **通知功能**: 封禁时发送邮件/webhook通知
2. **统计报表**: 生成攻击统计报告
3. **地理位置**: 集成 GeoIP 显示攻击来源国家
4. **机器学习**: 智能识别攻击模式
5. **集群同步**: 多服务器黑名单同步
