# 自动封禁功能 - 快速开始

## 🚀 5分钟快速部署

### 1. 初始化系统（30秒）

```bash
cd /path/to/scripts/port-protection

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
    "你的办公室IP"  # <- 改为实际IP
)

# 保存并退出 (Ctrl+X, Y, Enter)
```

### 3. 添加端口保护（2分钟）

```bash
# 重要：必须添加 --enable-log 选项！

# 保护SSH（推荐使用白名单模式）
sudo ./port-protect.sh add 22 --whitelist-only --enable-log -t 192.168.1.0/24

# 保护RDP
sudo ./port-protect.sh add 3389 --rdp --enable-log -t 192.168.1.100

# 保护其他端口
sudo ./port-protect.sh add 8080 --enable-log -t 192.168.1.0/24
```

### 4. 启动监控（30秒）

```bash
# 启动自动监控服务
sudo ./auto-ban.sh start

# 查看状态
sudo ./auto-ban.sh status
```

### 5. 验证运行（1分钟）

```bash
# 查看监控日志（实时）
sudo tail -f /var/log/port-protect-autoban.log

# 查看黑名单（另一个终端）
sudo ./blacklist-manager.sh list

# 查看系统日志中的拦截记录
sudo tail -f /var/log/syslog | grep PORT-PROTECT-DROP
```

---

## ✅ 验证清单

- [ ] 黑名单系统已初始化（`blacklist-manager.sh init`）
- [ ] 配置文件已创建（`/etc/port-protect-autoban.conf`）
- [ ] 白名单已配置（包含你的IP）
- [ ] 端口保护已添加（带 `--enable-log`）
- [ ] 监控服务已启动（`auto-ban.sh start`）
- [ ] 日志正常输出

---

## 📋 默认配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 封禁阈值 | 10次 | 时间窗口内触发次数 |
| 时间窗口 | 10分钟 | 统计时间范围 |
| 封禁时长 | 30天 | 自动解封时间 |
| 日志轮转 | 10MB | 超过自动轮转 |

---

## 🎯 测试功能

### 触发封禁测试（可选）

```bash
# 从另一台机器快速连接端口（触发速率限制）
for i in {1..15}; do nc -zv 服务器IP 端口; sleep 1; done

# 查看监控日志，应该看到：
# [WARN] 检测到异常IP: x.x.x.x
# [SUCCESS] 已封禁IP: x.x.x.x

# 查看黑名单
sudo ./blacklist-manager.sh list
```

### 解封测试IP

```bash
sudo ./blacklist-manager.sh unban 测试IP
```

---

## 📖 常用命令

```bash
# 监控管理
sudo ./auto-ban.sh start|stop|status|test

# 黑名单管理
sudo ./blacklist-manager.sh list|history|status
sudo ./blacklist-manager.sh ban <IP> [原因] [时长]
sudo ./blacklist-manager.sh unban <IP>

# 端口保护
sudo ./port-protect.sh add <端口> --enable-log [其他选项]
sudo ./port-protect.sh status
sudo ./port-protect.sh list-ports
```

---

## ⚠️ 注意事项

1. **必须启用日志**: 添加端口保护时必须使用 `--enable-log`
2. **配置白名单**: 务必将你的IP添加到白名单，避免自锁
3. **测试模式**: 首次使用建议用测试模式验证 (`auto-ban.sh test`)
4. **日志路径**: 确认 `/var/log/syslog` 存在（某些系统可能是 `/var/log/messages`）

---

## 🆘 快速故障排除

### 问题：监控服务启动失败

```bash
# 检查依赖
sudo apt-get install ipset iptables  # Debian/Ubuntu

# 重新初始化
sudo ./blacklist-manager.sh init
```

### 问题：没有检测到被拦截的IP

```bash
# 检查是否启用了日志
sudo ./port-protect.sh status

# 检查系统日志
sudo tail /var/log/syslog | grep PORT-PROTECT-DROP
```

### 问题：自己被封禁了

```bash
# 从其他机器或使用控制台登录
sudo ./blacklist-manager.sh unban 你的IP

# 添加到白名单
sudo nano /etc/port-protect-autoban.conf
```

---

## 📚 完整文档

- **详细指南**: `AUTO_BAN_GUIDE.md`
- **设计文档**: `AUTO_BAN_DESIGN.md`
- **使用手册**: `README.md`

---

**准备完成！** 🎉

系统现在会自动监控和封禁异常IP，封禁记录会保存30天，30天后自动解封。

查看实时监控：
```bash
sudo tail -f /var/log/port-protect-autoban.log
```
