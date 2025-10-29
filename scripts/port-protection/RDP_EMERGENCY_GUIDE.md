# RDP被爆破紧急解决方案 🆘

## 🔴 紧急情况说明

**你的问题：**
- RDP 3389端口被恶意爆破攻击
- 频繁的密码尝试触发Windows账户锁定策略
- **你自己也被锁定，无法登录！**
- IP是动态的，无法固定加白名单

## ⚡ 立即执行（3步解决）

### 如果你还能SSH登录服务器

```bash
# 步骤1: 一键快速保护（推荐）
sudo ./rdp-emergency.sh quick-protect

# 这会自动：
# ✓ 创建RDP白名单
# ✓ 添加你的当前IP
# ✓ 阻止所有其他IP
# ✓ 提示修改RDP端口
```

**或者分步执行：**

```bash
# 步骤1: 紧急锁定RDP（停止所有攻击）
sudo ./rdp-emergency.sh emergency-lock

# 步骤2: 添加你的IP到白名单
sudo ./rdp-emergency.sh add-my-ip
# 或手动指定: sudo ./rdp-emergency.sh add-whitelist 你的IP

# 步骤3: 解除锁定（只允许白名单IP）
sudo ./rdp-emergency.sh unlock
```

### 如果你无法SSH登录

通过云服务商控制台或VNC登录后：

```bash
# 获取你的公网IP
curl ifconfig.me

# 添加到白名单
sudo ./rdp-emergency.sh add-whitelist <你的IP>

# 启用保护
sudo ./rdp-emergency.sh unlock
```

---

## 🛡️ 完整解决方案

### 方案1: RDP白名单模式（立即生效）

```bash
# 一键保护
sudo ./rdp-emergency.sh quick-protect
```

**这个方案会：**
1. ✅ 创建专门的RDP白名单
2. ✅ 只允许你的IP访问RDP
3. ✅ 阻止所有恶意IP
4. ✅ 保护你不被锁定

**适用于：** 需要立即解决问题

---

### 方案2: 修改RDP端口（长期有效）

```bash
# 修改到非标准端口
sudo ./rdp-emergency.sh change-port 19099
```

**Windows端配置：**

1. 打开注册表编辑器（Win+R，输入`regedit`）

2. 定位到：
   ```
   HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp
   ```

3. 修改`PortNumber`的值：
   - 双击`PortNumber`
   - 选择"十进制"
   - 输入新端口（如：19099）
   - 点击确定

4. 重启服务器或重启终端服务：
   ```powershell
   # PowerShell（管理员）
   Restart-Service TermService -Force
   ```

5. 防火墙配置（Windows防火墙）：
   ```powershell
   # 添加新端口规则
   New-NetFirewallRule -DisplayName "RDP New Port" -Direction Inbound -Protocol TCP -LocalPort 19099 -Action Allow
   ```

**连接方式：**
```
mstsc /v:服务器IP:19099
```

**优点：**
- 🔒 避免自动化扫描
- 🔒 大幅减少攻击
- 🔒 长期有效

---

### 方案3: 结合动态IP白名单（最佳）

```bash
# 1. 初始化动态白名单
sudo ./dynamic-ip-whitelist.sh init

# 2. 快速保护RDP
sudo ./rdp-emergency.sh quick-protect

# 3. 当IP变化时自动更新
sudo ./dynamic-ip-whitelist.sh add-current
```

---

## 🔧 Windows系统配置（防止账户锁定）

### 临时解除账户锁定

```powershell
# PowerShell（管理员）
# 查看被锁定的账户
net user 你的用户名

# 解锁账户
net user 你的用户名 /active:yes

# 或者禁用账户锁定策略（不推荐）
net accounts /lockoutthreshold:0
```

### 调整账户锁定策略

1. **打开本地安全策略**
   - Win+R → `secpol.msc`

2. **导航到：**
   ```
   安全设置 → 账户策略 → 账户锁定策略
   ```

3. **调整设置：**
   ```
   账户锁定阈值: 10次失败尝试（默认5次）
   账户锁定时间: 30分钟
   重置账户锁定计数器: 30分钟
   ```

4. **应用并重启**

### 配置Windows防火墙（白名单模式）

```powershell
# PowerShell（管理员）

# 删除默认RDP规则
Remove-NetFirewallRule -DisplayName "Remote Desktop*"

# 添加白名单规则（只允许特定IP）
New-NetFirewallRule -DisplayName "RDP Whitelist" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 3389 `
    -RemoteAddress 你的公网IP `
    -Action Allow
```

---

## 📊 命令速查表

| 命令 | 用途 | 何时使用 |
|------|------|----------|
| `quick-protect` | 一键快速保护 | 第一次设置 |
| `emergency-lock` | 紧急锁定RDP | 正在被攻击 |
| `add-my-ip` | 添加当前IP | 紧急锁定后 |
| `unlock` | 解除锁定 | 添加IP后 |
| `change-port` | 修改RDP端口 | 长期防护 |
| `status` | 查看状态 | 检查配置 |

---

## 🎯 推荐配置流程

### 最佳实践（按顺序执行）

```bash
# 1. 立即保护RDP
sudo ./rdp-emergency.sh quick-protect

# 2. 修改RDP端口
sudo ./rdp-emergency.sh change-port 19099

# 3. 设置动态IP管理
sudo ./dynamic-ip-whitelist.sh init
sudo ./dynamic-ip-whitelist.sh add-current

# 4. 配置自动更新（可选）
sudo ./dynamic-ip-whitelist.sh generate-token
```

### Windows端配置

1. **修改RDP端口**（注册表）
2. **调整账户锁定策略**（本地安全策略）
3. **配置Windows防火墙**（白名单模式）
4. **启用网络级别身份验证（NLA）**

---

## 🆘 故障排除

### 问题1: 执行emergency-lock后无法连接RDP

**原因：** 所有IP都被阻止了

**解决：**
```bash
# 添加你的IP
sudo ./rdp-emergency.sh add-my-ip

# 解除锁定
sudo ./rdp-emergency.sh unlock
```

### 问题2: 账户仍然被锁定

**Windows端操作：**
```powershell
# PowerShell（管理员）
net user 你的用户名 /active:yes
net accounts /lockoutthreshold:0  # 临时禁用锁定
```

**Linux端操作：**
```bash
# 清空黑名单
sudo ./blacklist-manager.sh flush

# 添加到白名单
sudo ./rdp-emergency.sh add-my-ip
```

### 问题3: IP变化后无法连接

**快速解决：**
```bash
# 方法1: 通过SSH登录添加新IP
sudo ./rdp-emergency.sh add-whitelist <新IP>

# 方法2: 使用动态白名单
sudo ./dynamic-ip-whitelist.sh add-current
```

### 问题4: 修改端口后无法连接

**检查清单：**
1. ✅ Windows注册表已修改
2. ✅ 终端服务已重启
3. ✅ Linux防火墙已更新
4. ✅ Windows防火墙已添加新端口规则
5. ✅ 云服务商安全组已开放新端口

**连接命令：**
```
mstsc /v:服务器IP:新端口
```

---

## 🔐 高级防护（可选）

### 1. 使用端口敲门

```bash
# 安装knockd
sudo apt-get install knockd

# 配置文件 /etc/knockd.conf
[openRDP]
    sequence    = 7000,8000,9000
    seq_timeout = 5
    command     = /usr/local/bin/open-rdp.sh %IP%
    tcpflags    = syn

[closeRDP]
    sequence    = 9000,8000,7000
    seq_timeout = 5
    command     = /usr/local/bin/close-rdp.sh %IP%
    tcpflags    = syn
```

创建脚本：
```bash
# /usr/local/bin/open-rdp.sh
#!/bin/bash
/path/to/rdp-emergency.sh add-whitelist "$1"

# /usr/local/bin/close-rdp.sh
#!/bin/bash
/path/to/rdp-emergency.sh remove-whitelist "$1"
```

### 2. 启用双因素认证

在Windows上安装并配置：
- Microsoft Authenticator
- Google Authenticator
- Duo Security

### 3. 使用VPN访问

```bash
# 只允许VPN网段访问RDP
sudo ./rdp-emergency.sh add-whitelist 10.8.0.0/24
```

---

## 📝 检查清单

完成配置后，检查：

- [ ] RDP白名单已启用
- [ ] 你的IP已添加到白名单
- [ ] RDP端口已修改（推荐）
- [ ] Windows账户锁定策略已调整
- [ ] Windows防火墙已配置
- [ ] Linux防火墙规则已保存
- [ ] 能够正常RDP连接
- [ ] 动态IP管理已配置（如果需要）

---

## 🎓 预防措施

### 长期安全建议

1. **修改默认端口** - 避免3389
2. **使用强密码** - 16位以上，包含大小写字母、数字、符号
3. **启用NLA** - 网络级别身份验证
4. **定期更新** - Windows更新和安全补丁
5. **监控日志** - 查看失败登录尝试
6. **使用VPN** - 通过VPN访问RDP更安全
7. **双因素认证** - 增加额外安全层

### 监控脚本

```bash
# 查看RDP状态
sudo ./rdp-emergency.sh status

# 查看白名单
sudo ./rdp-emergency.sh list-whitelist

# 查看黑名单
sudo ./blacklist-manager.sh list

# 查看日志
sudo tail -f /var/log/port-protect-*.log
```

---

## 💡 总结

**立即执行（紧急）：**
```bash
sudo ./rdp-emergency.sh quick-protect
```

**长期防护（推荐）：**
```bash
# 1. 快速保护
sudo ./rdp-emergency.sh quick-protect

# 2. 修改端口
sudo ./rdp-emergency.sh change-port 19099

# 3. 动态IP管理
sudo ./dynamic-ip-whitelist.sh init
```

**检查状态：**
```bash
sudo ./rdp-emergency.sh status
```

---

需要帮助？查看：
- `sudo ./rdp-emergency.sh help` - 完整帮助
- `DYNAMIC_IP_SOLUTION.md` - 动态IP解决方案
- `DEBIAN_UBUNTU_QUICK_START.md` - 系统配置指南

🔒 **记住：安全第一！**
