# Port Protection - 快速开始指南

## 2025-10-28 更新版本

---

## 🚀 快速验证

### 1. 检查脚本语法（无需 root）

```bash
cd /path/to/scripts/port-protection
bash -n port-protect.sh
bash -n rdp-reconfig.sh
bash -n test-port-protect.sh
```

所有脚本应该无语法错误。

### 2. 查看帮助（无需 root）

```bash
./port-protect.sh help
```

### 3. 运行完整测试（需要 root）

```bash
sudo ./test-port-protect.sh
```

这将测试所有功能并自动清理。

---

## 📋 常用命令速查

### 添加端口保护

```bash
# 标准模式（速率限制 5/min）
sudo ./port-protect.sh add 8080 -t 192.168.1.100

# RDP 优化模式（速率限制 30/min，适合远程桌面）
sudo ./port-protect.sh add 19099 --rdp -t 192.168.1.100

# 白名单模式（只允许指定IP，无速率限制）
sudo ./port-protect.sh add 22 --whitelist-only -t 192.168.1.0/24

# 严格模式（速率限制 2/min，高安全）
sudo ./port-protect.sh add 3306 --strict -t 192.168.1.100

# UDP 端口
sudo ./port-protect.sh add 53 --protocol udp -t 192.168.1.100

# 自定义参数（覆盖模式默认值）
sudo ./port-protect.sh add 19099 --rdp -l 20/min -b 25 -t 192.168.1.100
```

### 移除端口保护

```bash
# 移除 TCP 端口（默认）
sudo ./port-protect.sh remove 8080

# 移除 UDP 端口
sudo ./port-protect.sh remove 53 --protocol udp

# 移除指定链的端口
sudo ./port-protect.sh remove 8080 --chain MY_CUSTOM_CHAIN
```

### 查看状态

```bash
# 查看所有防护链和端口
sudo ./port-protect.sh status

# 只列出受保护的端口
sudo ./port-protect.sh list-ports
```

### 备份和恢复

```bash
# 创建备份
sudo ./port-protect.sh backup production

# 查看所有备份
sudo ./port-protect.sh list-backups

# 恢复备份
sudo ./port-protect.sh restore production

# 恢复最近的备份
sudo ./port-protect.sh restore
```

### 持久化规则

```bash
# 保存规则（重启后仍有效）
sudo ./port-protect.sh save
```

---

## 🛡️ RDP 端口快速配置

使用 `rdp-reconfig.sh` 脚本快速配置 RDP 端口：

```bash
# 单个可信IP
sudo ./rdp-reconfig.sh 19099 192.168.1.100

# 多个可信IP
sudo ./rdp-reconfig.sh 19099 192.168.1.100 10.0.0.5 172.16.0.10
```

---

## 🎯 使用场景示例

### 场景 1: 保护多个 RDP 端口

```bash
# 为三个 RDP 端口添加保护（每个端口独立链，互不影响）
for port in 19099 19100 19101; do
    sudo ./port-protect.sh add $port --rdp -t 192.168.1.100
done

# 查看所有受保护端口
sudo ./port-protect.sh list-ports

# 移除其中一个端口（不影响其他端口）
sudo ./port-protect.sh remove 19100
```

### 场景 2: 保护 Web 服务器

```bash
# 添加保护
sudo ./port-protect.sh add 80 -l 30/min -b 50 -t 192.168.1.0/24
sudo ./port-protect.sh add 443 -l 30/min -b 50 -t 192.168.1.0/24

# 备份配置
sudo ./port-protect.sh backup web_server

# 保存规则
sudo ./port-protect.sh save
```

### 场景 3: 保护 SSH 服务

```bash
# 使用白名单模式（最安全）
sudo ./port-protect.sh add 22 --whitelist-only \
    -t 192.168.1.0/24 \
    -t 203.0.113.100

# 或使用严格模式（带速率限制）
sudo ./port-protect.sh add 22 --strict \
    -t 192.168.1.0/24 \
    -t 203.0.113.100
```

---

## 📊 验证规则

### 查看 iptables 规则

```bash
# 查看特定链
sudo iptables -L DOCKER-HOST-PROTECT-19099 -n --line-numbers

# 查看 INPUT 链引用
sudo iptables -L INPUT -n --line-numbers | grep DOCKER-HOST-PROTECT

# 查看所有规则
sudo iptables -L -n -v
```

### 测试端口访问

```bash
# 从远程机器测试（会触发速率限制）
for i in {1..20}; do nc -zv <服务器IP> 19099; sleep 1; done

# 检查系统日志
sudo tail -f /var/log/syslog | grep -i drop
```

---

## 🔧 故障排除

### 问题 1: 规则重启后消失

```bash
# 保存规则到持久存储
sudo ./port-protect.sh save

# 验证保存
ls -l /etc/iptables/rules.v4  # Debian/Ubuntu
ls -l /etc/sysconfig/iptables  # CentOS/RHEL
```

### 问题 2: 误删规则需要恢复

```bash
# 查看可用备份
sudo ./port-protect.sh list-backups

# 恢复最近的备份
sudo ./port-protect.sh restore

# 或恢复特定备份
sudo ./port-protect.sh restore production
```

### 问题 3: 端口访问异常

```bash
# 查看当前状态
sudo ./port-protect.sh status

# 查看具体链规则
sudo iptables -L DOCKER-HOST-PROTECT-<端口号> -n -v

# 临时移除保护测试
sudo ./port-protect.sh remove <端口号>

# 重新添加（如果需要）
sudo ./port-protect.sh add <端口号> --rdp -t <你的IP>
```

---

## 📝 重要说明

### 链命名规则（2025-09 更新）

- **新版本（默认）**: 每个端口使用独立链 `DOCKER-HOST-PROTECT-<port>`
  - 优点：端口之间互不影响，可以独立管理
  - 适用：大多数场景，特别是多端口保护

- **旧版本（兼容）**: 所有端口共享链 `DOCKER-HOST-PROTECT`
  - 使用方式：`--chain DOCKER-HOST-PROTECT`
  - 适用：需要统一管理多个端口的场景

### 参数优先级（2025-10 更新）

参数优先级规则：**用户指定 > 模式默认 > 全局默认**

示例：
```bash
# 用户指定的 -l 20/min 会覆盖 RDP 模式的默认值 30/min
sudo ./port-protect.sh add 19099 --rdp -l 20/min -t 192.168.1.100

# 参数位置不影响结果（以下两种写法等效）
sudo ./port-protect.sh add 19099 -l 20/min --rdp -t 1.2.3.4
sudo ./port-protect.sh add 19099 --rdp -l 20/min -t 1.2.3.4
```

### 模式默认值

| 模式 | 速率限制 | 突发限制 | 适用场景 |
|------|----------|----------|----------|
| 标准模式 | 5/min | 10 | 普通服务 |
| RDP模式 (`--rdp`) | 30/min | 50 | 远程桌面、VNC |
| 严格模式 (`--strict`) | 2/min | 3 | 高安全环境 |
| 白名单模式 (`--whitelist-only`) | 无 | 无 | SSH、数据库 |

---

## ✅ 已修复的问题（2025-10-28）

1. ✓ rdp-reconfig.sh 占位符问题
2. ✓ remove 命令协议参数支持
3. ✓ status 命令显示独立链
4. ✓ RDP 模式参数覆盖逻辑
5. ✓ 备份文件权限设置（600）
6. ✓ 文档和帮助信息更新

---

## 🚀 自动封禁快速部署

自动封禁功能可以监控被端口保护规则拦截的IP，自动封禁异常IP。

### 1. 初始化系统（1分钟）

```bash
# 初始化黑名单系统
sudo ./blacklist-manager.sh init

# 创建配置文件
sudo ./auto-ban.sh init
```

### 2. 配置白名单（1分钟）

```bash
# 编辑配置文件
sudo nano /etc/port-protect-autoban.conf

# 添加你的可信IP到WHITELIST数组
WHITELIST=(
    "127.0.0.1"
    "192.168.0.0/16"
    "10.0.0.0/8"
    "你的办公室IP"  # 改为实际IP
)

# 保存并退出 (Ctrl+X, Y, Enter)
```

### 3. 启用日志并添加端口保护（1分钟）

```bash
# 重要：必须添加 --enable-log 选项！

# 保护SSH
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 192.168.1.0/24

# 保护RDP
sudo ./port-protect.sh add 3389 --rdp --enable-log -t 192.168.1.100
```

### 4. 启动监控服务（30秒）

```bash
# 启动自动监控服务
sudo ./auto-ban.sh start

# 查看状态
sudo ./auto-ban.sh status

# 查看实时日志
sudo tail -f /var/log/port-protect-autoban.log
```

### 5. 常用命令

```bash
# 监控管理
sudo ./auto-ban.sh start|stop|status|test

# 黑名单管理
sudo ./blacklist-manager.sh list            # 查看黑名单
sudo ./blacklist-manager.sh history         # 查看封禁历史
sudo ./blacklist-manager.sh ban <IP>        # 手动封禁IP
sudo ./blacklist-manager.sh unban <IP>      # 解封IP
```

### 6. 验证运行

```bash
# 查看黑名单
sudo ./blacklist-manager.sh list

# 查看封禁历史
sudo ./blacklist-manager.sh history

# 查看系统日志中的拦截记录
sudo tail -f /var/log/syslog | grep PORT-PROTECT-DROP
```

---

## 📚 更多文档

- **README.md** - 完整使用手册（包含自动封禁详细说明）
- **RDP-USAGE.md** - RDP 专用指南

---

## 🆘 获取帮助

```bash
# 查看内置帮助
./port-protect.sh help

# 查看版本和更新信息
head -20 port-protect.sh | grep -E "^#"

# 运行测试验证功能
sudo ./test-port-protect.sh
```

---

**维护者**: Claude Code
**最后更新**: 2025-10-28
**版本**: 2.2.0 (修复版)
