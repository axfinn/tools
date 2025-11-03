# 动态IP用户完整解决方案

## 问题分析

你遇到的问题：
1. ❌ 公网端口被恶意探测
2. ❌ 触发了防护阈值，导致你自己也被封禁
3. ❌ 你的IP是动态的，每次变化都需要更新白名单

## 完整解决方案

我为你提供了**三种方案**，按复杂度和安全性递增：

---

## 🚀 方案1：手动更新白名单（最简单）

### 适用场景
- IP变化不频繁（每周或每月）
- 可以通过SSH或控制台登录服务器

### 快速开始

```bash
# 1. 初始化动态白名单系统
sudo ./dynamic-ip-whitelist.sh init

# 2. 添加当前IP到白名单（自动检测）
sudo ./dynamic-ip-whitelist.sh add-current

# 3. 或手动指定IP
sudo ./dynamic-ip-whitelist.sh add 你的公网IP
```

### 工作原理
- 创建独立的白名单ipset（`port-protect-whitelist`）
- 白名单规则优先于黑名单规则
- IP过期时间30天，自动清理

### 如果已经被锁定
```bash
# 方法1: 通过服务器控制台/VNC登录
sudo ./dynamic-ip-whitelist.sh add 你的IP

# 方法2: 先解除黑名单
sudo ./blacklist-manager.sh unban 你的IP

# 方法3: 然后添加到白名单
sudo ./dynamic-ip-whitelist.sh add-current
```

---

## 🔐 方案2：认证令牌自动更新（推荐）

### 适用场景
- IP经常变化（每天或每周）
- 可以在客户端设置定时任务
- 不想每次手动SSH登录

### 设置步骤

#### 服务器端（一次性设置）

```bash
# 1. 初始化系统
sudo ./dynamic-ip-whitelist.sh init

# 2. 生成认证令牌
sudo ./dynamic-ip-whitelist.sh generate-token

# 输出类似：
# 令牌: 1a2b3c4d5e6f7g8h9i0j...
# 创建时间: 2025-10-29T14:00:00
# 过期时间: 2025-11-29T14:00:00
```

#### 创建Web接口（简单PHP脚本）

创建文件 `/var/www/html/update-whitelist.php`:

```php
<?php
// 简单的白名单更新接口
$valid_tokens = [
    '你生成的令牌' => true
];

$token = $_GET['token'] ?? '';
if (!isset($valid_tokens[$token])) {
    http_response_code(403);
    die('Invalid token');
}

// 获取客户端IP
$client_ip = $_SERVER['REMOTE_ADDR'];
if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
    $client_ip = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
}

// 执行白名单添加
$output = shell_exec("sudo /path/to/dynamic-ip-whitelist.sh add $client_ip 'Auto-updated' 2>&1");

echo json_encode([
    'success' => true,
    'ip' => $client_ip,
    'time' => date('Y-m-d H:i:s'),
    'output' => $output
]);
?>
```

配置sudo权限 (`/etc/sudoers.d/whitelist-update`):
```
www-data ALL=(ALL) NOPASSWD: /path/to/dynamic-ip-whitelist.sh add *
```

#### 客户端（你的电脑）

```bash
# 创建更新脚本
cat > ~/update-my-whitelist.sh << 'EOF'
#!/bin/bash
TOKEN="你的令牌"
SERVER="你的服务器IP"
curl -s "http://$SERVER/update-whitelist.php?token=$TOKEN"
EOF

chmod +x ~/update-my-whitelist.sh

# 添加到crontab（每30分钟更新一次）
crontab -e
# 添加：
*/30 * * * * ~/update-my-whitelist.sh
```

---

## 🛡️ 方案3：端口敲门（Port Knocking）- 最安全

### 适用场景
- 需要最高安全性
- IP频繁变化
- 不想暴露任何Web接口

### 安装和配置

```bash
# 1. 安装knockd
sudo apt-get install knockd

# 2. 配置 /etc/knockd.conf
sudo tee /etc/knockd.conf << 'EOF'
[options]
    UseSyslog

[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 5
    command     = /usr/local/bin/add-to-whitelist.sh %IP%
    tcpflags    = syn

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 5
    command     = /usr/local/bin/remove-from-whitelist.sh %IP%
    tcpflags    = syn
EOF

# 3. 创建添加脚本 /usr/local/bin/add-to-whitelist.sh
sudo tee /usr/local/bin/add-to-whitelist.sh << 'EOF'
#!/bin/bash
/path/to/dynamic-ip-whitelist.sh add "$1" "Port knock" 1
# 1天后自动过期
EOF
sudo chmod +x /usr/local/bin/add-to-whitelist.sh

# 4. 启动knockd
sudo systemctl enable knockd
sudo systemctl start knockd
```

### 客户端使用

```bash
# 安装knock客户端
sudo apt-get install knockd

# 敲门序列（按顺序访问端口）
knock 你的服务器IP 7000 8000 9000

# 然后可以SSH连接
ssh user@你的服务器IP

# 完成后关闭访问
knock 你的服务器IP 9000 8000 7000
```

---

## 📊 方案对比

| 方案 | 复杂度 | 安全性 | 自动化 | 适用场景 |
|------|--------|--------|--------|----------|
| 手动更新 | ⭐ | ⭐⭐⭐ | ❌ | IP偶尔变化 |
| 认证令牌 | ⭐⭐ | ⭐⭐⭐⭐ | ✅ | IP频繁变化 |
| 端口敲门 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | 最高安全需求 |

---

## 🔧 立即解决当前问题

### 如果你现在无法访问服务器

**选项A: 通过服务器控制台/VNC**
```bash
# 登录后执行
sudo ./dynamic-ip-whitelist.sh add $(curl -s ifconfig.me)
```

**选项B: 临时禁用防护**
```bash
# 登录后执行
sudo ./port-protect.sh remove 你的端口
# 添加白名单后重新启用
sudo ./port-protect.sh add 你的端口 --whitelist-only -t $(curl -s ifconfig.me)
```

### 如果可以SSH登录

```bash
# 1. 添加当前IP到白名单
sudo ./dynamic-ip-whitelist.sh add-current

# 2. 查看状态
sudo ./dynamic-ip-whitelist.sh status

# 3. 检查是否在白名单中
sudo ./dynamic-ip-whitelist.sh list
```

---

## 📝 完整工作流程示例

### 第一次设置（服务器端）

```bash
# 1. 进入脚本目录
cd /path/to/port-protection

# 2. 初始化黑名单系统
sudo ./blacklist-manager.sh init

# 3. 初始化动态白名单系统
sudo ./dynamic-ip-whitelist.sh init

# 4. 添加当前IP到白名单
sudo ./dynamic-ip-whitelist.sh add-current

# 5. 配置端口保护（使用白名单模式）
sudo ./port-protect.sh add 22 --whitelist-only -t $(curl -s ifconfig.me)

# 6. 启动自动监控
sudo ./auto-ban.sh start

# 7. 查看状态
sudo ./dynamic-ip-whitelist.sh status
sudo ./blacklist-manager.sh status
```

### 日常维护

```bash
# 当IP变化后
sudo ./dynamic-ip-whitelist.sh add-current

# 查看白名单
sudo ./dynamic-ip-whitelist.sh list

# 清理过期条目
sudo ./dynamic-ip-whitelist.sh cleanup

# 查看被封禁的IP
sudo ./blacklist-manager.sh list

# 查看系统状态
sudo ./dynamic-ip-whitelist.sh status
```

---

## 🎯 推荐配置（综合方案）

我建议你使用以下组合：

```bash
# 1. 基础保护 + 动态白名单
sudo ./blacklist-manager.sh init
sudo ./dynamic-ip-whitelist.sh init
sudo ./dynamic-ip-whitelist.sh add-current

# 2. 配置端口保护（使用白名单模式）
# 这样只有白名单IP可以访问，其他IP直接拒绝
sudo ./port-protect.sh add 22 --whitelist-only -t 你的IP

# 3. 启动自动封禁
sudo ./auto-ban.sh start

# 4. （可选）设置客户端自动更新
# 使用方案2的认证令牌或方案3的端口敲门
```

---

## 🆘 紧急情况处理

### 被锁定无法登录

```bash
# 方法1: 通过云服务商控制台登录
# 然后运行:
sudo iptables -F INPUT  # 清空所有规则（临时）
sudo ./dynamic-ip-whitelist.sh add 你的IP
sudo ./port-protect.sh add 22 --whitelist-only -t 你的IP

# 方法2: 重启服务器（规则会丢失）
# 然后立即添加白名单
```

### 检查配置

```bash
# 查看白名单
sudo ipset list port-protect-whitelist

# 查看黑名单
sudo ipset list port-protect-blacklist

# 查看iptables规则
sudo iptables -L INPUT -n --line-numbers

# 查看日志
sudo tail -f /var/log/port-protect-*.log
```

---

## 📚 相关文件

- `dynamic-ip-whitelist.sh` - 动态IP白名单管理脚本（新建）
- `blacklist-manager.sh` - 黑名单管理脚本
- `port-protect.sh` - 端口保护主脚本
- `auto-ban.sh` - 自动封禁脚本

---

## ✅ 总结

对于你的情况（动态IP + 被恶意探测），我推荐：

1. **立即**: 使用方案1添加当前IP到白名单
2. **短期**: 配置白名单模式端口保护
3. **长期**: 实施方案2（认证令牌自动更新）

这样可以确保：
- ✅ 你的IP永远不会被封禁
- ✅ 恶意IP无法访问
- ✅ IP变化后自动更新
- ✅ 最小化维护工作量

需要帮助实施任何方案，随时告诉我！
