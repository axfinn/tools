# 紧急修复：RDP爆破防护配置

## 🚨 问题诊断

从你的iptables规则可以看出，当前配置是 `--limit 2/sec --limit-burst 2`，这意味着：
- 每秒允许2个新连接
- 突发限制为2
- **这对爆破攻击防护来说太宽松了！**

## 🛠️ 立即修复方案

### 1. 移除当前配置
```bash
sudo ./port-protect.sh remove 19099
```

### 2. 应用严格防护配置

#### 方案A: 白名单模式（推荐 - 最安全）
```bash
sudo ./port-protect.sh add 19099 --whitelist-only -t 你的IP地址
```

#### 方案B: 严格模式（新增功能）
```bash
sudo ./port-protect.sh add 19099 --strict -t 你的IP地址
```
- 限制：2/min（每分钟2次连接）
- 突发：3次
- 极难进行爆破攻击

#### 方案C: RDP优化模式（平衡）
```bash
sudo ./port-protect.sh add 19099 --rdp -t 你的IP地址
```
- 限制：10/min（每分钟10次连接）
- 突发：15次
- 允许已建立连接无限制

### 3. 保存配置
```bash
sudo ./port-protect.sh save
```

## 🔍 验证配置

### 检查规则
```bash
sudo ./port-protect.sh status
sudo iptables -L DOCKER-HOST-PROTECT -v -n --line-numbers
```

### 测试防护效果
```bash
# 从另一台机器快速测试（应该被阻止）
for i in {1..10}; do
    echo "尝试 $i"; 
    timeout 1 nc -zv 目标IP 19099; 
    sleep 1; 
done
```

## 📊 新的默认配置对比

| 模式 | 速率限制 | 突发限制 | 防护等级 | 适用场景 |
|------|---------|---------|----------|----------|
| 严格模式 | 2/min | 3 | 🔒🔒🔒🔒🔒 | 高风险环境 |
| 标准模式 | 5/min | 10 | 🔒🔒🔒🔒 | 一般环境 |
| RDP模式 | 10/min | 15 | 🔒🔒🔒 | RDP优化 |
| 白名单模式 | 无限制 | 无限制 | 🔒🔒🔒🔒🔒 | 仅限可信IP |

## ⚠️ 重要说明

1. **2/sec 配置不安全**: 攻击者每秒仍可尝试2次，容易被爆破
2. **建议使用 /min 而不是 /sec**: 分钟级限制更有效
3. **必须配合可信IP**: 确保自己的IP在白名单中

## 🎯 推荐最终配置

对于RDP服务，强烈推荐使用白名单模式：
```bash
sudo ./port-protect.sh remove 19099
sudo ./port-protect.sh add 19099 --whitelist-only -t 你的公网IP -t 你的办公网段
sudo ./port-protect.sh save
```

这样配置后，只有指定的IP才能访问，完全阻止爆破攻击。
