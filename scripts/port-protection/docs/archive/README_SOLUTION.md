# 🆘 紧急RDP保护 - 完整解决方案总结

## 你的问题

1. ❌ **RDP 3389端口被恶意爆破**
2. ❌ **频繁密码尝试导致账户锁定**
3. ❌ **你自己也无法登录**
4. ❌ **IP是动态的，不能固定加白名单**

## 📦 我为你创建的工具

### 1. `rdp-emergency.sh` - RDP紧急保护脚本
**用途：** 立即保护RDP，阻止恶意攻击

**核心功能：**
- 🚨 紧急锁定RDP（一键停止所有攻击）
- ✅ RDP白名单管理（只允许你的IP）
- 🔧 修改RDP端口（避免扫描）
- 📊 状态查看

### 2. `dynamic-ip-whitelist.sh` - 动态IP白名单管理
**用途：** 解决动态IP无法固定加白名单的问题

**核心功能：**
- 🔄 自动检测当前IP并添加到白名单
- 🔑 生成认证令牌供远程更新
- ⏰ 自动过期管理
- 📋 白名单查看和管理

### 3. `blacklist-manager.sh` - 黑名单管理（已优化）
**用途：** 管理被封禁的恶意IP

**新增功能：**
- 🔧 自动安装依赖
- 🔍 系统诊断
- 💾 配置持久化
- 📝 详细日志

---

## ⚡ 立即执行（3种方案）

### 方案A: 一键快速保护（最简单）✨

```bash
# 如果你还能SSH登录
sudo ./rdp-emergency.sh quick-protect
```

**这会自动：**
1. ✅ 创建RDP白名单
2. ✅ 添加你的当前IP
3. ✅ 阻止所有其他IP
4. ✅ 提示修改RDP端口

---

### 方案B: 分步紧急处理（更可控）

```bash
# 步骤1: 紧急锁定（停止攻击）
sudo ./rdp-emergency.sh emergency-lock

# 步骤2: 添加你的IP
sudo ./rdp-emergency.sh add-my-ip

# 步骤3: 解除锁定（只允许白名单）
sudo ./rdp-emergency.sh unlock

# 步骤4: 修改端口（长期防护）
sudo ./rdp-emergency.sh change-port 19099
```

---

### 方案C: 动态IP完整方案（最佳）

```bash
# 1. 初始化所有系统
sudo ./blacklist-manager.sh init
sudo ./dynamic-ip-whitelist.sh init
sudo ./rdp-emergency.sh quick-protect

# 2. 当IP变化时
sudo ./dynamic-ip-whitelist.sh add-current

# 3. 或设置自动更新（可选）
sudo ./dynamic-ip-whitelist.sh generate-token
# 然后在客户端定时执行更新
```

---

## 🔧 Windows端配置

### 1. 修改RDP端口（强烈推荐）

**注册表修改：**
1. Win+R → `regedit`
2. 定位到：
   ```
   HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\
   Terminal Server\WinStations\RDP-Tcp
   ```
3. 修改 `PortNumber` 为新端口（十进制，如：19099）
4. 重启服务器

**PowerShell（管理员）：**
```powershell
# 方法1: 直接修改注册表
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name PortNumber -Value 19099

# 方法2: 重启终端服务
Restart-Service TermService -Force

# 方法3: 添加防火墙规则
New-NetFirewallRule -DisplayName "RDP New Port" -Direction Inbound -Protocol TCP -LocalPort 19099 -Action Allow
```

### 2. 解除账户锁定

```powershell
# 查看账户状态
net user 你的用户名

# 解锁账户
net user 你的用户名 /active:yes

# 临时禁用锁定策略（不推荐长期使用）
net accounts /lockoutthreshold:0
```

### 3. 调整账户锁定策略

1. Win+R → `secpol.msc`
2. 安全设置 → 账户策略 → 账户锁定策略
3. 设置：
   - 账户锁定阈值：10次（而不是5次）
   - 账户锁定时间：30分钟
   - 重置计数器：30分钟

---

## 📊 完整工作流程

### 第一次设置（服务器端）

```bash
# 1. 进入脚本目录
cd /home/hejiahao01/code/tools/scripts/port-protection

# 2. 赋予执行权限（如果需要）
chmod +x *.sh

# 3. 快速保护RDP
sudo ./rdp-emergency.sh quick-protect

# 4. 初始化动态白名单
sudo ./dynamic-ip-whitelist.sh init
sudo ./dynamic-ip-whitelist.sh add-current

# 5. 查看状态
sudo ./rdp-emergency.sh status
sudo ./dynamic-ip-whitelist.sh status
```

### 日常使用

```bash
# 当IP变化后
sudo ./dynamic-ip-whitelist.sh add-current

# 查看白名单
sudo ./rdp-emergency.sh list-whitelist
sudo ./dynamic-ip-whitelist.sh list

# 查看系统状态
sudo ./rdp-emergency.sh status

# 查看被封禁的IP
sudo ./blacklist-manager.sh list
```

---

## 🆘 紧急情况处理

### 如果现在无法访问服务器

**选项1: 通过云服务商控制台/VNC登录**
```bash
# 登录后执行
sudo ./rdp-emergency.sh add-whitelist $(curl -s ifconfig.me)
sudo ./rdp-emergency.sh unlock
```

**选项2: 临时禁用所有规则**
```bash
# 清空INPUT链（谨慎使用！）
sudo iptables -F INPUT

# 立即添加保护
sudo ./rdp-emergency.sh quick-protect
```

### 如果账户被锁定

**Windows端（本地或VNC）：**
```powershell
# 解锁账户
net user Administrator /active:yes

# 临时禁用锁定
net accounts /lockoutthreshold:0
```

**Linux端：**
```bash
# 解除IP封禁
sudo ./blacklist-manager.sh unban 你的IP

# 添加到白名单
sudo ./rdp-emergency.sh add-my-ip
```

---

## 📁 文件清单

已创建的文件：

### 核心脚本
1. **rdp-emergency.sh** - RDP紧急保护脚本
2. **dynamic-ip-whitelist.sh** - 动态IP白名单管理
3. **blacklist-manager.sh** - 黑名单管理（v3.0.0）

### 配置文件
4. **port-protect.logrotate** - 日志轮转配置

### 文档
5. **RDP_EMERGENCY_GUIDE.md** - RDP紧急处理指南
6. **DYNAMIC_IP_SOLUTION.md** - 动态IP完整解决方案
7. **DEBIAN_UBUNTU_QUICK_START.md** - Debian/Ubuntu快速开始
8. **IMPROVEMENTS_SUMMARY.md** - 改进总结
9. **CHANGELOG-v3.md** - 更新日志

---

## 🎯 推荐配置（最佳实践）

```bash
# 1. 立即保护RDP
sudo ./rdp-emergency.sh quick-protect

# 2. 修改RDP端口（Windows+Linux）
# Windows: 修改注册表 PortNumber = 19099
# Linux:
sudo ./rdp-emergency.sh change-port 19099

# 3. 设置动态白名单
sudo ./dynamic-ip-whitelist.sh init
sudo ./dynamic-ip-whitelist.sh add-current

# 4. 安装logrotate配置
sudo cp port-protect.logrotate /etc/logrotate.d/port-protect

# 5. 保存所有配置
sudo iptables-save > /etc/iptables/rules.v4
sudo ipset save > /etc/iptables/ipsets
```

---

## 🔍 检查清单

完成设置后，确认：

**Linux端：**
- [ ] RDP白名单已创建
- [ ] 你的IP已添加到白名单
- [ ] 只有白名单IP可以访问RDP
- [ ] 防火墙规则已保存
- [ ] 动态白名单系统已初始化

**Windows端：**
- [ ] RDP端口已修改（推荐）
- [ ] 账户已解锁
- [ ] 账户锁定策略已调整
- [ ] Windows防火墙已配置新端口
- [ ] 终端服务已重启

**测试：**
- [ ] 能够通过新端口RDP连接
- [ ] 恶意IP被阻止
- [ ] 日志正常记录

---

## 💡 关键命令速查

```bash
# === RDP紧急保护 ===
sudo ./rdp-emergency.sh quick-protect      # 一键保护
sudo ./rdp-emergency.sh status             # 查看状态
sudo ./rdp-emergency.sh add-my-ip          # 添加当前IP

# === 动态IP管理 ===
sudo ./dynamic-ip-whitelist.sh add-current # 添加当前IP
sudo ./dynamic-ip-whitelist.sh list        # 查看白名单
sudo ./dynamic-ip-whitelist.sh status      # 查看状态

# === 黑名单管理 ===
sudo ./blacklist-manager.sh unban <IP>     # 解除封禁
sudo ./blacklist-manager.sh list           # 查看黑名单
sudo ./blacklist-manager.sh diagnose       # 系统诊断

# === Windows端 ===
net user Administrator /active:yes         # 解锁账户
net accounts /lockoutthreshold:0           # 禁用锁定策略
Restart-Service TermService -Force         # 重启RDP服务
```

---

## 🎓 预防建议

**短期（立即执行）：**
1. ✅ 使用 `rdp-emergency.sh quick-protect`
2. ✅ 修改RDP端口到非标准端口

**中期（本周完成）：**
1. ✅ 设置动态IP自动更新
2. ✅ 调整Windows账户锁定策略
3. ✅ 启用Windows防火墙白名单

**长期（持续维护）：**
1. ✅ 定期检查白名单和黑名单
2. ✅ 监控登录日志
3. ✅ 使用强密码（16位以上）
4. ✅ 考虑使用VPN访问RDP
5. ✅ 启用双因素认证

---

## 📞 获取帮助

```bash
# 查看完整帮助
sudo ./rdp-emergency.sh help
sudo ./dynamic-ip-whitelist.sh help
sudo ./blacklist-manager.sh help

# 查看文档
cat RDP_EMERGENCY_GUIDE.md
cat DYNAMIC_IP_SOLUTION.md
cat DEBIAN_UBUNTU_QUICK_START.md
```

---

## ✅ 总结

**你现在有完整的RDP保护方案：**

1. **紧急保护**：`rdp-emergency.sh` 立即阻止攻击
2. **动态IP**：`dynamic-ip-whitelist.sh` 自动管理你的IP
3. **黑名单**：`blacklist-manager.sh` 管理恶意IP
4. **完整文档**：详细的使用和故障排除指南

**立即执行：**
```bash
sudo ./rdp-emergency.sh quick-protect
```

**问题解决！** 🎉

---

**版本：** 3.0.0
**日期：** 2025-10-29
**状态：** 生产就绪 ✅
