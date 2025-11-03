# RDP 端口保护使用指南

## RDP爆破攻击防护能力

### ✅ 脚本可以有效防止公网RDP爆破密码请求

**防护机制：**
1. **速率限制**: 限制新连接频率，阻止高频爆破
2. **白名单模式**: 完全阻止非授权IP访问
3. **连接状态跟踪**: 不影响正常RDP会话

**对不同攻击的有效性：**
- ✅ **高频爆破攻击**: 非常有效
- ✅ **分布式爆破攻击**: 配合白名单完全阻止  
- ✅ **慢速爆破攻击**: 有效（30/min的限制使爆破变得不现实）

## 推荐防护配置

### 🔒 最安全配置（白名单模式）
```bash
# 仅允许指定IP访问，完全阻止爆破攻击
sudo ./port-protect.sh add 13389 --whitelist-only -t 你的公网IP -t 你的办公网段
```

### 🛡️ 平衡配置（RDP优化模式）  
```bash
# 允许有限的公网访问，但有效防止爆破
sudo ./port-protect.sh add 13389 --rdp -t 你的常用IP
```

### 🔐 严格配置（自定义限制）
```bash
# 覆写 RDP 默认 (30/min 50) 为更低速率，进一步降低爆破成功率
sudo ./port-protect.sh add 13389 --rdp -l 15/min -b 25 -t 你的IP
```

## 问题分析

你的13389端口RDP协议在旧版本脚本添加防护规则后攻击请求限制未生效的原因：

1. **旧版本设计缺陷**：攻击者可以建立多个TCP连接，在每个连接上进行密码爆破
2. **RDP爆破特性**：攻击者同时打开多个连接（超过速率限制），每个连接都可以尝试认证
3. **缺少并发连接限制**：旧版本只限制新连接速率，不限制单IP的并发连接数

**v3.1.1 修复说明**：
- ✅ 新增 **connlimit 并发连接数限制**（单IP最多3个并发连接）
- ✅ 保持已建立连接的正常通过（**不影响已登录用户的正常使用**）
- ✅ 结合速率限制 + 并发限制，双重防护密码爆破
- ✅ 白名单IP优先放行，不受任何限制影响

## 解决方案

### 1. 移除现有规则
```bash
sudo ./port-protect.sh remove 13389
```

### 2. 使用RDP优化模式重新添加
```bash
# 方式1: RDP优化模式 + 可信IP
sudo ./port-protect.sh add 13389 --rdp -t 你的IP地址

# 方式2: 仅白名单模式（最安全）
sudo ./port-protect.sh add 13389 --whitelist-only -t 你的IP地址

# 方式3: 自定义参数的RDP模式 (参数需写在 --rdp 之后，否则会被预设覆盖)
sudo ./port-protect.sh add 13389 --rdp -l 50/min -b 100 -t 你的IP地址

# 方式4: 多端口批量（每端口独立链）
for p in 13389 13390 13391; do sudo ./port-protect.sh add $p --rdp -t 你的IP地址; done
```

### 3. 检查规则状态

```bash
sudo ./port-protect.sh status
```

### 4. 保存规则（重启后生效）

```bash
sudo ./port-protect.sh save
```

## 新增功能说明

### RDP优化模式 (`--rdp`)

- 自动调整速率限制为 `30/min`，突发为 `50`
- **双重防护**：速率限制 + 并发连接数限制（单IP最多3个并发）
- 已建立连接正常通过，**不影响已登录用户的正常使用**
- 白名单IP不受任何限制影响

### 白名单模式 (`--whitelist-only`)

- 仅允许指定的可信IP访问
- 不添加速率限制，直接拒绝非白名单IP
- 最安全的访问控制方式

## 使用建议

1. **生产环境RDP**: 建议使用白名单模式
2. **开发环境RDP**: 可以使用RDP优化模式
3. **备份规则**: 每次修改前先备份当前规则
4. **测试连接**: 修改规则后立即测试RDP连接

## 示例命令

```bash
# 备份当前规则
sudo ./port-protect.sh backup before_rdp_fix

# 移除有问题的规则
sudo ./port-protect.sh remove 13389

# 添加优化的RDP规则（替换为你的实际IP）
sudo ./port-protect.sh add 13389 --rdp -t 192.168.1.100 -t 10.0.0.0/24

# 保存规则
sudo ./port-protect.sh save

# 如果有问题，可以恢复备份
sudo ./port-protect.sh restore before_rdp_fix
```

## 故障排查

如果RDP仍然无法连接：

1. 检查iptables规则：`sudo iptables -L DOCKER-HOST-PROTECT -n --line-numbers`
2. 查看连接状态：`sudo netstat -tulpn | grep 13389`
3. 检查Docker端口映射：`docker ps`
4. 临时测试（移除所有防护）：`sudo ./port-protect.sh remove 13389`

## 防护效果验证

### 测试爆破防护

```bash
# 测试速率限制是否生效（从另一台机器执行）
for i in {1..50}; do
    echo "尝试 $i"; 
    timeout 2 telnet 目标IP 13389 2>/dev/null; 
    sleep 1; 
done
```

### 监控防护日志

```bash
# 实时监控被阻止的连接
sudo iptables -L DOCKER-HOST-PROTECT -v -n --line-numbers

# 查看DROP的数据包统计
sudo iptables -L INPUT -v -n | grep DROP
```

### 建议的额外安全措施

1. **更改默认端口**: 将RDP从3389改为非标准端口
2. **启用账户锁定**: 在Windows上配置账户锁定策略
3. **强密码策略**: 确保使用复杂密码
4. **VPN访问**: 考虑通过VPN访问RDP服务
5. **证书认证**: 启用网络级身份验证(NLA)

## 安全等级对比

| 配置模式 | 安全等级 | 可用性 | 适用场景 |
|---------|---------|--------|----------|
| 白名单模式 | 🔒🔒🔒🔒🔒 | ⭐⭐ | 生产环境、高安全要求 |
| RDP优化模式 | 🔒🔒🔒🔒 | ⭐⭐⭐⭐ | 一般生产环境 |
| 自定义严格限制 | 🔒🔒🔒🔒⭐ | ⭐⭐⭐ | 平衡安全性和可用性 |
| 无防护 | 🔒 | ⭐⭐⭐⭐⭐ | 仅内网环境 |
