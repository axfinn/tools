# 自动封禁功能 - 完整使用指南

## 📚 目录

1. [功能概述](#功能概述)
2. [快速开始](#快速开始)
3. [详细配置](#详细配置)
4. [使用示例](#使用示例)
5. [日志管理](#日志管理)
6. [故障排除](#故障排除)
7. [进阶使用](#进阶使用)

---

## 功能概述

自动封禁系统监控被port-protect拦截的IP地址，当某个IP在指定时间窗口内触发防护规则超过阈值次数时，自动将其加入黑名单封禁。

### 🎯 核心特性

- ✅ **自动监控**: 实时监控系统日志，检测异常IP
- ✅ **智能封禁**: 基于阈值自动封禁，30天后自动解封
- ✅ **白名单保护**: 可信IP永不封禁
- ✅ **滚动日志**: 完整记录封禁历史，支持日志轮转
- ✅ **高效管理**: 使用ipset，O(1)查询复杂度
- ✅ **灵活配置**: 可自定义阈值、时长、白名单

### 📋 组件说明

| 组件 | 功能 | 文件 |
|------|------|------|
| **port-protect.sh** | 端口保护（增强） | 添加 `--enable-log` 选项 |
| **blacklist-manager.sh** | 黑名单管理 | 封禁/解封/查看/历史 |
| **auto-ban.sh** | 自动监控 | 监控日志、自动封禁 |

---

## 快速开始

### 第一步：初始化黑名单系统

```bash
cd /path/to/scripts/port-protection

# 初始化黑名单系统（创建ipset和iptables规则）
sudo ./blacklist-manager.sh init
```

**输出示例**:
```
初始化黑名单系统...
✓ 已创建ipset: port-protect-blacklist
✓ 已添加iptables规则
✓ 黑名单系统初始化完成

提示:
  - ipset集合: port-protect-blacklist
  - 默认封禁时长: 2592000 秒 (30天)
  - 日志文件: /var/log/port-protect-ban.log
  - 历史记录: /var/log/port-protect-ban-history.log
```

### 第二步：生成配置文件

```bash
# 创建自动封禁配置文件
sudo ./auto-ban.sh init
```

**输出示例**:
```
已创建配置文件: /etc/port-protect-autoban.conf

请编辑配置文件，添加你的可信IP到白名单
编辑命令: nano /etc/port-protect-autoban.conf
```

### 第三步：配置白名单

编辑配置文件，添加你的可信IP：

```bash
sudo nano /etc/port-protect-autoban.conf
```

**配置示例**:
```bash
# 白名单配置
WHITELIST=(
    "127.0.0.1"
    "::1"
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
    # 添加你的办公室IP
    "1.2.3.4"
    # 添加你的VPN网段
    "5.6.7.0/24"
)

# 封禁配置
BAN_THRESHOLD=10        # 10次触发后封禁
TIME_WINDOW=600         # 10分钟时间窗口
BAN_DURATION=2592000    # 封禁30天
```

### 第四步：启用日志并添加端口保护

```bash
# 添加端口保护，启用日志记录
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 192.168.1.0/24
sudo ./port-protect.sh add 3389 --rdp --enable-log -t 192.168.1.100
sudo ./port-protect.sh add 8080 --enable-log -t 192.168.1.0/24
```

**重要**: 必须添加 `--enable-log` 选项才能记录被拦截的IP！

### 第五步：启动自动监控

```bash
# 启动监控服务（后台运行）
sudo ./auto-ban.sh start
```

**输出示例**:
```
[2025-10-28 20:00:00] [INFO] 启动监控服务...
[2025-10-28 20:00:00] [SUCCESS] 监控服务已启动 (PID: 12345)

查看日志: tail -f /var/log/port-protect-autoban.log
查看状态: ./auto-ban.sh status
停止服务: ./auto-ban.sh stop
```

### 第六步：查看运行状态

```bash
# 查看监控状态
sudo ./auto-ban.sh status

# 查看黑名单
sudo ./blacklist-manager.sh list

# 查看封禁历史
sudo ./blacklist-manager.sh history
```

---

## 详细配置

### 配置文件详解

**文件位置**: `/etc/port-protect-autoban.conf`

```bash
# ===== 封禁阈值 =====
# 触发次数：在时间窗口内触发多少次后封禁
BAN_THRESHOLD=10

# 时间窗口（秒）：统计时间范围
# 600秒 = 10分钟
TIME_WINDOW=600

# 封禁时长（秒）：封禁持续时间
# 2592000秒 = 30天
# 0 = 永久封禁
BAN_DURATION=2592000

# 自动封禁开关
# true=启用自动封禁  false=只监控不封禁
AUTO_BAN_ENABLED=true
```

### 阈值配置建议

| 场景 | 阈值 | 时间窗口 | 封禁时长 |
|------|------|----------|----------|
| SSH保护 | 5次 | 5分钟 | 30天 |
| Web服务 | 20次 | 10分钟 | 7天 |
| API服务 | 50次 | 30分钟 | 24小时 |
| RDP保护 | 10次 | 10分钟 | 30天 |
| 严格模式 | 3次 | 5分钟 | 永久 |

### 白名单配置

**支持格式**:
- 单个IP: `192.168.1.100`
- CIDR网段: `192.168.1.0/24`
- IPv6: `::1`

**示例**:
```bash
WHITELIST=(
    # 本地回环
    "127.0.0.1"
    "::1"

    # 内网IP段
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"

    # 办公室公网IP
    "1.2.3.4"
    "5.6.7.8"

    # VPN网段
    "10.8.0.0/24"

    # 合作伙伴IP
    "203.0.113.0/24"
)
```

---

## 使用示例

### 场景1：保护SSH服务（推荐）

```bash
# 1. 添加SSH端口保护（白名单+日志）
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 192.168.1.0/24

# 2. 启动自动监控
sudo ./auto-ban.sh start

# 3. 查看日志
sudo tail -f /var/log/port-protect-autoban.log
```

### 场景2：保护多个RDP端口

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

### 场景3：保护Web应用

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

### 场景4：测试模式（不实际封禁）

```bash
# 测试模式：查看会封禁哪些IP，但不实际封禁
sudo ./auto-ban.sh test

# 输出会显示：
# [WARN] 检测到异常IP: 1.2.3.4 (端口22触发12次防护规则)
# [INFO] 自动封禁已禁用，跳过封禁
```

---

## 日志管理

### 日志文件

| 日志文件 | 说明 | 位置 |
|----------|------|------|
| 系统日志 | iptables DROP记录 | /var/log/syslog |
| 监控日志 | 监控运行日志 | /var/log/port-protect-autoban.log |
| 封禁日志 | 当前封禁记录 | /var/log/port-protect-ban.log |
| 历史记录 | 完整封禁历史 | /var/log/port-protect-ban-history.log |

### 查看日志

```bash
# 查看监控日志（实时）
sudo tail -f /var/log/port-protect-autoban.log

# 查看封禁日志
sudo tail -f /var/log/port-protect-ban.log

# 查看系统日志中的DROP记录
sudo tail -f /var/log/syslog | grep PORT-PROTECT-DROP

# 查看封禁历史
sudo ./blacklist-manager.sh history

# 查看特定IP的历史
sudo ./blacklist-manager.sh history 1.2.3.4
```

### 日志格式

**监控日志格式**:
```
[2025-10-28 20:15:30] [INFO] 开始监控系统日志: /var/log/syslog
[2025-10-28 20:16:45] [WARN] 检测到异常IP: 1.2.3.4 (端口22触发10次防护规则)
[2025-10-28 20:16:45] [SUCCESS] 已封禁IP: 1.2.3.4
[2025-10-28 20:16:45] BANNED: IP=1.2.3.4 PORT=22 COUNT=10 EXPIRE=2025-11-27 20:16:45
```

**封禁历史格式**:
```
时间戳               | 操作  | IP地址         | 原因                     | 时长    | 过期时间
2025-10-28 20:16:45 | BAN   | 1.2.3.4        | 端口22触发10次防护规则    | 2592000 | 2025-11-27 20:16:45
2025-10-28 21:00:00 | UNBAN | 1.2.3.4        | Manual unban             | 0       |
```

### 日志轮转

**自动轮转**: 当封禁日志超过10MB时自动轮转

**手动清理**:
```bash
# 清理30天前的备份日志
sudo ./blacklist-manager.sh cleanup
```

**配置logrotate**（可选）:
```bash
sudo nano /etc/logrotate.d/port-protect
```

```
/var/log/port-protect-*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 600 root root
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
```

---

## 故障排除

### 问题1：监控服务无法启动

**症状**: `./auto-ban.sh start` 报错

**检查步骤**:
```bash
# 1. 检查日志文件权限
ls -l /var/log/port-protect-*.log

# 2. 检查黑名单系统状态
sudo ./blacklist-manager.sh status

# 3. 检查系统日志是否存在
ls -l /var/log/syslog

# 4. 检查依赖
which ipset iptables
```

**解决方案**:
```bash
# 安装依赖
sudo apt-get install ipset iptables  # Debian/Ubuntu
sudo yum install ipset iptables       # CentOS/RHEL

# 重新初始化
sudo ./blacklist-manager.sh init
sudo ./auto-ban.sh start
```

### 问题2：没有检测到被拦截的IP

**可能原因**:
1. 未启用 `--enable-log` 选项
2. 日志文件路径不正确

**检查**:
```bash
# 1. 检查端口保护是否启用日志
sudo ./port-protect.sh status

# 2. 手动触发一次拦截，查看系统日志
curl http://localhost:端口  # 多次触发速率限制

# 3. 检查系统日志
sudo tail /var/log/syslog | grep PORT-PROTECT-DROP
```

**解决方案**:
```bash
# 重新添加端口保护，确保启用日志
sudo ./port-protect.sh remove 22
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 你的IP
```

### 问题3：白名单IP被封禁

**检查**:
```bash
# 查看配置文件中的白名单
sudo cat /etc/port-protect-autoban.conf | grep -A 20 WHITELIST

# 检查IP是否在白名单中
sudo ./auto-ban.sh test  # 测试模式下观察
```

**解决方案**:
```bash
# 1. 解封IP
sudo ./blacklist-manager.sh unban 你的IP

# 2. 添加到白名单
sudo nano /etc/port-protect-autoban.conf
# 在WHITELIST数组中添加IP

# 3. 重新加载配置
sudo ./auto-ban.sh reload
```

### 问题4：封禁未自动解除

**检查**:
```bash
# 查看IP的剩余封禁时间
sudo ./blacklist-manager.sh check 1.2.3.4

# 查看ipset超时配置
sudo ipset list port-protect-blacklist | grep timeout
```

**手动解封**:
```bash
sudo ./blacklist-manager.sh unban 1.2.3.4
```

---

## 进阶使用

### 永久封禁恶意IP

```bash
# 封禁时长设置为0表示永久
sudo ./blacklist-manager.sh ban 1.2.3.4 "恶意扫描" 0
```

### 批量封禁IP段

```bash
# 封禁整个C类网段
sudo ./blacklist-manager.sh ban 1.2.3.0/24 "攻击来源" 2592000
```

### 查看实时攻击

```bash
# 监控实时攻击
sudo tail -f /var/log/syslog | grep PORT-PROTECT-DROP | while read line; do
    ip=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
    port=$(echo "$line" | grep -oP 'PORT-PROTECT-DROP-\K[0-9]+')
    echo "[$(date)] 端口 $port 被 $ip 攻击"
done
```

### 导出封禁列表

```bash
# 导出所有被封禁的IP
sudo ./blacklist-manager.sh list > banned-ips.txt

# 导出封禁历史
sudo ./blacklist-manager.sh history > ban-history.txt
```

### 集成到系统服务

创建 systemd 服务文件:

```bash
sudo nano /etc/systemd/system/port-protect-autoban.service
```

```ini
[Unit]
Description=Port Protection Auto-Ban Service
After=network.target iptables.service

[Service]
Type=forking
ExecStart=/path/to/scripts/port-protection/auto-ban.sh start
ExecStop=/path/to/scripts/port-protection/auto-ban.sh stop
PIDFile=/var/run/port-protect-autoban.pid
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
```

```bash
# 启用服务
sudo systemctl daemon-reload
sudo systemctl enable port-protect-autoban
sudo systemctl start port-protect-autoban

# 查看状态
sudo systemctl status port-protect-autoban
```

### 通知集成（示例）

在 `auto-ban.sh` 的 `ban_ip()` 函数后添加通知：

```bash
# 邮件通知
if [ -n "$NOTIFY_EMAIL" ]; then
    echo "IP $ip 已被封禁: $reason" | mail -s "安全警报" "$NOTIFY_EMAIL"
fi

# Webhook通知
if [ -n "$NOTIFY_WEBHOOK" ]; then
    curl -X POST "$NOTIFY_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"ip\":\"$ip\",\"reason\":\"$reason\",\"time\":\"$(date)\"}"
fi
```

---

## 常用命令速查

### 监控管理

```bash
sudo ./auto-ban.sh start          # 启动监控
sudo ./auto-ban.sh stop           # 停止监控
sudo ./auto-ban.sh status         # 查看状态
sudo ./auto-ban.sh test           # 测试模式
sudo ./auto-ban.sh reload         # 重新加载配置
```

### 黑名单管理

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

### 端口保护

```bash
sudo ./port-protect.sh add <端口> --enable-log -t <IP>    # 添加保护（启用日志）
sudo ./port-protect.sh remove <端口>                       # 移除保护
sudo ./port-protect.sh status                              # 查看状态
sudo ./port-protect.sh list-ports                          # 列出端口
```

---

## 总结

✅ **完整流程**:
1. 初始化黑名单系统
2. 创建并配置白名单
3. 添加端口保护（启用日志）
4. 启动自动监控
5. 定期查看日志和封禁列表

✅ **关键点**:
- 必须使用 `--enable-log` 选项
- 正确配置白名单避免自锁
- 合理设置封禁阈值
- 定期查看日志和历史记录

✅ **优势**:
- 自动化防护，无需人工干预
- 滚动日志记录，完整追溯
- 30天自动解封，避免永久封禁
- 高效ipset实现，性能优异

---

**维护者**: Claude Code
**最后更新**: 2025-10-28
**版本**: 1.0.0
