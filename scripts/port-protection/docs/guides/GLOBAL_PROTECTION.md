# 全端口防护使用指南

> 🛡️ 保护所有端口，记录所有连接请求，辅助防护决策

## 📖 概述

`global-protect.sh` 是一个全端口防护脚本，可以：
- ✅ 保护所有端口（不需要一个一个添加）
- ✅ 全局速率限制（防止端口扫描）
- ✅ 记录所有新连接请求
- ✅ 日志滚动保存（避免占满磁盘）
- ✅ 可信IP和端口白名单
- ✅ 实时日志分析和攻击模式识别

---

## 🚀 快速开始

### 1. 基本使用

```bash
# 启用全端口防护（使用默认配置）
sudo ./scripts/global-protect.sh enable

# 查看状态
sudo ./scripts/global-protect.sh status

# 查看日志
sudo ./scripts/global-protect.sh logs

# 禁用防护
sudo ./scripts/global-protect.sh disable
```

### 2. 推荐配置

```bash
# 启用并添加你的IP到白名单（推荐）
sudo ./scripts/global-protect.sh enable -t 你的公网IP

# 或者启用时自定义配置
sudo ./scripts/global-protect.sh enable \
  -l 50/min \                    # 速率限制: 50次/分钟
  -b 100 \                       # 突发限制: 100
  -t 192.168.1.100 \            # 可信IP
  -t 10.0.0.0/24 \              # 可信IP段
  -p 22,80,443,3389             # 白名单端口（不受限制）
```

---

## 🔧 工作原理

### 防护规则顺序

```
INPUT链
  ↓
GLOBAL-PORT-PROTECT链
  ↓
1. 可信IP直接放行 ✅
  ↓
2. 白名单端口放行 ✅
  ↓
3. 已建立连接放行 ✅
  ↓
4. 新连接速率限制 (100/min, burst 200)
  ↓
  允许 ✅  或  拒绝并记录 ❌
```

### 默认配置

- **速率限制**: 100次/分钟
- **突发限制**: 200
- **白名单端口**: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- **日志文件**: `/var/log/global-port-protect.log`

---

## 📊 日志分析

### 1. 查看日志

```bash
# 查看最近100条日志
sudo ./scripts/global-protect.sh logs -n 100

# 实时监控日志
sudo ./scripts/global-protect.sh logs -f

# 查看统计信息
sudo ./scripts/global-protect.sh stats

# 显示连接最多的IP（Top 20）
sudo ./scripts/global-protect.sh top-ips -n 20
```

### 2. 高级分析

使用 `log-analyzer.sh` 进行深度分析：

```bash
# 生成综合报告
sudo ./scripts/log-analyzer.sh report

# 最近24小时的报告
sudo ./scripts/log-analyzer.sh report -h 24

# 实时监控（彩色输出）
sudo ./scripts/log-analyzer.sh realtime

# 时间线分析（每小时统计）
sudo ./scripts/log-analyzer.sh timeline

# 攻击模式识别
sudo ./scripts/log-analyzer.sh attack-pattern

# 导出数据
sudo ./scripts/log-analyzer.sh export -f json > report.json
sudo ./scripts/log-analyzer.sh export -f csv > report.csv
```

### 3. 分析可疑IP

```bash
# 自动分析并建议封禁
sudo ./scripts/global-protect.sh analyze

# 输出示例：
# 可疑IP分析（阈值: 50 次）
# ========================================
# 发现以下可疑IP：
#
#   1.2.3.4         : 150 次
#   5.6.7.8         : 89 次
#
# ========================================
# 建议操作：
#
#   # 封禁 1.2.3.4 (连接 150 次)
#   sudo ./blacklist-manager.sh ban 1.2.3.4 --reason "High connection rate: 150" --duration 7d
```

---

## 🎯 使用场景

### 场景1：基础全端口保护

**需求**：保护服务器所有端口，防止端口扫描

```bash
# 1. 启用全端口防护
sudo ./scripts/global-protect.sh enable -t 你的IP

# 2. 配置日志轮转
sudo cp config/global-port-protect.logrotate /etc/logrotate.d/global-port-protect

# 3. 保存规则
sudo iptables-save > /etc/iptables/rules.v4

# 4. 定期查看日志
sudo ./scripts/global-protect.sh stats
```

---

### 场景2：结合单端口保护

**需求**：全端口基础保护 + RDP端口强化保护

```bash
# 1. 全端口基础保护（速率限制）
sudo ./scripts/global-protect.sh enable -t 你的IP

# 2. RDP端口额外保护（更严格的限制）
sudo ./scripts/port-protect.sh add 19099 --rdp -t 你的IP --enable-log

# 3. 查看综合状态
sudo ./scripts/global-protect.sh status
sudo ./scripts/port-protect.sh status
```

**规则优先级**：
```
INPUT链规则顺序（从上到下）：
1. GLOBAL-PORT-PROTECT (全端口保护)
2. DOCKER-HOST-PROTECT-19099 (RDP专用保护)
3. 其他规则
```

---

### 场景3：日志分析和自动封禁

**需求**：记录所有连接，自动识别并封禁攻击者

```bash
# 1. 启用全端口防护（开启日志）
sudo ./scripts/global-protect.sh enable -t 你的IP

# 2. 定时分析日志（cron任务）
# 编辑 crontab
sudo crontab -e

# 添加以下任务（每小时分析一次）
0 * * * * /path/to/scripts/global-protect.sh analyze | grep "sudo.*ban" | bash

# 3. 手动查看分析报告
sudo ./scripts/log-analyzer.sh report

# 4. 查看攻击模式
sudo ./scripts/log-analyzer.sh attack-pattern
```

---

### 场景4：多地点访问 + 全端口保护

**需求**：需要从不同地点访问，同时保护所有端口

```bash
# 1. 启用全端口防护（不添加固定IP）
sudo ./scripts/global-protect.sh enable

# 2. 每次从新地点访问时，添加当前IP
ssh server
sudo ./scripts/quick-whitelist.sh add-current

# 3. 或者直接添加到全端口防护白名单
sudo ./scripts/global-protect.sh add-whitelist-ip $(curl -s ifconfig.me)

# 4. 查看白名单
sudo ./scripts/global-protect.sh list-whitelist-ips
```

---

## ⚙️ 配置管理

### 白名单IP管理

```bash
# 添加可信IP
sudo ./scripts/global-protect.sh add-whitelist-ip 1.2.3.4

# 移除可信IP
sudo ./scripts/global-protect.sh remove-whitelist-ip 1.2.3.4

# 列出所有可信IP
sudo ./scripts/global-protect.sh list-whitelist-ips
```

### 白名单端口管理

```bash
# 添加白名单端口（不受速率限制）
sudo ./scripts/global-protect.sh add-whitelist-port 3389

# 移除白名单端口
sudo ./scripts/global-protect.sh remove-whitelist-port 3389

# 列出所有白名单端口
sudo ./scripts/global-protect.sh list-whitelist-ports

# 注意：修改端口白名单后需要重新启用防护
sudo ./scripts/global-protect.sh disable
sudo ./scripts/global-protect.sh enable
```

### 速率限制调整

```bash
# 设置速率限制
sudo ./scripts/global-protect.sh set-limit 50/min

# 设置突发限制
sudo ./scripts/global-protect.sh set-burst 100

# 重新启用防护以应用新配置
sudo ./scripts/global-protect.sh disable
sudo ./scripts/global-protect.sh enable
```

---

## 📋 日志轮转配置

防止日志文件占满磁盘：

```bash
# 1. 复制日志轮转配置
sudo cp config/global-port-protect.logrotate /etc/logrotate.d/global-port-protect

# 2. 测试配置
sudo logrotate -d /etc/logrotate.d/global-port-protect

# 3. 手动触发轮转
sudo logrotate -f /etc/logrotate.d/global-port-protect

# 4. 查看日志文件大小
ls -lh /var/log/global-port-protect*.log
```

**日志轮转策略**：
- 每天轮转或文件超过100M时轮转
- 保留30天的日志
- 自动压缩旧日志
- 使用日期作为文件名后缀

---

## 📊 日志分析报告示例

### 综合报告

```bash
$ sudo ./scripts/log-analyzer.sh report

╔════════════════════════════════════════════════════════════════╗
║        全端口防护 - 综合分析报告                               ║
╚════════════════════════════════════════════════════════════════╝

报告时间: 2025-11-03 15:30:00

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【总体统计】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  总拒绝连接数: 15,234
  唯一源IP数:   89
  被扫描端口数: 156

【Top 10 攻击来源IP】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   1. 1.2.3.4          : 2,456 次
   2. 5.6.7.8          : 1,823 次
   3. 9.10.11.12       : 987 次
   ...

【Top 10 被扫描端口】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   1. 端口 22     (SSH)         : 3,456 次
   2. 端口 3389   (RDP)         : 2,134 次
   3. 端口 3306   (MySQL)       : 1,567 次
   ...

【高频攻击者（>100次）】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1.2.3.4         : 2,456 次
  5.6.7.8         : 1,823 次

  建议: 使用以下命令封禁这些IP
  sudo ./blacklist-manager.sh ban 1.2.3.4 --reason "High attack rate: 2456" --duration 30d
  sudo ./blacklist-manager.sh ban 5.6.7.8 --reason "High attack rate: 1823" --duration 30d
```

---

## 💡 最佳实践

### 1. 启用前

- ✅ 确保添加你的IP到白名单
- ✅ 确保SSH端口在白名单端口列表中
- ✅ 先测试速率限制设置是否合理

### 2. 启用后

- ✅ 配置日志轮转（避免磁盘满）
- ✅ 定期查看日志（`logs`/`stats`）
- ✅ 定期分析可疑IP（`analyze`）
- ✅ 保存iptables规则（重启后生效）

### 3. 监控建议

- ✅ 每天查看一次综合报告
- ✅ 设置cron任务自动分析和封禁
- ✅ 使用 `log-analyzer.sh realtime` 实时监控

---

## ⚠️ 注意事项

### 1. 与单端口保护的关系

- 全端口保护和单端口保护可以**同时使用**
- 规则优先级：INPUT链中的顺序决定
- 建议：全端口保护放在INPUT链最前面

### 2. 白名单端口

默认白名单端口（22,80,443）**不受速率限制**，如果需要保护这些端口：
- 方案A：从白名单移除，使用单端口保护
- 方案B：保持全端口保护，针对特定端口添加额外规则

### 3. 性能影响

- ✅ 日志记录有速率限制（10/min），性能影响极小
- ✅ iptables规则在内核层面执行，开销可忽略
- ⚠️ 日志文件可能增长较快，务必配置日志轮转

---

## 🔄 升级和维护

### 查看版本

```bash
./scripts/global-protect.sh --version
```

### 配置文件位置

- 配置文件: `/etc/global-port-protect.conf`
- 日志文件: `/var/log/global-port-protect.log`
- 日志轮转: `/etc/logrotate.d/global-port-protect`

### 备份和恢复

```bash
# 备份配置
sudo cp /etc/global-port-protect.conf /root/global-port-protect.conf.backup

# 备份iptables规则
sudo iptables-save > /root/iptables.backup

# 恢复
sudo iptables-restore < /root/iptables.backup
```

---

## 🆘 故障排查

### Q1: 启用后无法SSH登录

**原因**: SSH端口不在白名单中或IP未添加到白名单

**解决**:
```bash
# 通过云服务商控制台登录，然后：
sudo ./scripts/global-protect.sh add-whitelist-ip 你的IP
# 或者
sudo ./scripts/global-protect.sh add-whitelist-port 22
```

### Q2: 日志文件过大

**解决**:
```bash
# 立即配置日志轮转
sudo cp config/global-port-protect.logrotate /etc/logrotate.d/global-port-protect
sudo logrotate -f /etc/logrotate.d/global-port-protect

# 手动清理旧日志
sudo rm /var/log/global-port-protect.log.*.gz
```

### Q3: 查看不到日志

**原因**: 日志可能在系统日志中

**解决**:
```bash
# 查看系统日志
dmesg | grep GLOBAL-PORT-PROTECT

# 或者
sudo journalctl -k | grep GLOBAL-PORT-PROTECT
```

---

**版本**: 1.0.0
**最后更新**: 2025-11-03
