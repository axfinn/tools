# ⚠️ CentOS 系统重要说明

## 系统差异总结

你的服务器是 **CentOS**，与之前文档中的 Debian/Ubuntu 有重要区别。

---

## 🔑 关键区别

| 特性 | CentOS/RHEL | Debian/Ubuntu | 影响 |
|------|-------------|---------------|------|
| **包管理器** | yum/dnf | apt | 安装命令不同 |
| **防火墙** | firewalld | ufw/iptables | 配置方式不同 |
| **SELinux** | 默认启用 | 默认禁用 | 可能阻止脚本运行 |
| **日志位置** | /var/log/secure | /var/log/auth.log | 监控位置不同 |
| **包格式** | RPM (.rpm) | DEB (.deb) | 安装包不同 |
| **EPEL** | 需要 | 不需要 | 某些包需要 EPEL 仓库 |

---

## ✅ 好消息

**所有脚本已经优化，支持 CentOS！**

blacklist-manager.sh v3.1.0 现在：
- ✅ 自动检测 CentOS/RHEL
- ✅ 使用 yum/dnf 安装依赖
- ✅ 自动安装 EPEL 仓库
- ✅ 处理 SELinux 问题
- ✅ 支持 firewalld 和 iptables

---

## 🚀 CentOS 快速开始

### 第一步：查看 CentOS 专用文档

```bash
cat CENTOS_QUICK_START.md
```

### 第二步：安装依赖

```bash
# 脚本会自动检测 CentOS 并使用 yum/dnf
sudo ./blacklist-manager.sh install-deps
```

### 第三步：初始化系统

```bash
sudo ./blacklist-manager.sh init
```

---

## 🔧 CentOS 特有配置

### 1. 防火墙选择

**选项A: 使用 iptables（推荐，脚本默认）**

```bash
# 停止 firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 安装 iptables-services
sudo yum install -y iptables-services

# 启动 iptables
sudo systemctl enable iptables
sudo systemctl start iptables
```

**选项B: 继续使用 firewalld**

需要手动使用 `firewall-cmd` 命令管理规则。

### 2. SELinux 处理

**检查状态:**
```bash
getenforce
```

**如果遇到 Permission denied:**
```bash
# 临时禁用（测试）
sudo setenforce 0

# 或添加策略（生产环境推荐）
sudo setsebool -P httpd_can_network_connect 1
```

### 3. EPEL 仓库

某些包需要 EPEL：

```bash
# 脚本会自动安装，或手动安装：
sudo yum install -y epel-release
```

---

## 📚 CentOS 专用文档

创建的 CentOS 专用文档：

1. **CENTOS_QUICK_START.md** - CentOS 快速开始指南
   - 防火墙配置
   - SELinux 处理
   - 日志位置
   - 完整部署示例

2. **blacklist-manager.sh v3.1.0** - 已更新支持 CentOS
   - 自动检测系统类型
   - yum/dnf 包管理
   - EPEL 仓库集成

---

## 🎯 推荐部署流程（CentOS）

```bash
# 1. 安装依赖（自动检测 CentOS）
sudo ./blacklist-manager.sh install-deps

# 2. 配置防火墙（选择 iptables）
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo yum install -y iptables-services
sudo systemctl enable iptables
sudo systemctl start iptables

# 3. 初始化系统
sudo ./blacklist-manager.sh init

# 4. RDP 紧急保护
sudo ./rdp-emergency.sh quick-protect

# 5. 动态 IP 管理
sudo ./dynamic-ip-whitelist.sh init
sudo ./dynamic-ip-whitelist.sh add-current

# 6. 保存规则
sudo service iptables save

# 7. 配置开机自启
sudo systemctl enable iptables
```

---

## 🆘 常见问题（CentOS 专用）

### Q: "Cannot create ipset"

**A**: 加载内核模块
```bash
sudo modprobe ip_set
sudo modprobe ip_set_hash_ip
lsmod | grep ip_set
```

### Q: SELinux 阻止脚本运行

**A**: 临时禁用或配置策略
```bash
sudo setenforce 0  # 临时
# 或
sudo audit2allow -a -M port-protect
sudo semodule -i port-protect.pp
```

### Q: yum/dnf 找不到包

**A**: 安装 EPEL
```bash
sudo yum install -y epel-release
```

### Q: firewalld 与 iptables 冲突

**A**: 选择一个使用
```bash
# 禁用 firewalld，使用 iptables
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl mask firewalld
```

---

## 📊 版本更新

- **v3.0.0** - Debian/Ubuntu 优化版
- **v3.1.0** - 添加 CentOS/RHEL 完整支持 ⬅️ 当前版本

---

## ✅ 验证部署

```bash
# 运行诊断
sudo ./blacklist-manager.sh diagnose

# 应该显示：
# ✓ 操作系统: CentOS/RHEL
# ✓ ipset 已安装
# ✓ iptables 已安装
# ✓ ipset 已创建
# ✓ iptables 规则已配置
```

---

## 💡 需要帮助？

查看详细文档：
```bash
cat CENTOS_QUICK_START.md        # CentOS 专用指南
cat README_SOLUTION.md            # 完整解决方案
cat RDP_EMERGENCY_GUIDE.md        # RDP 保护指南
```

运行诊断：
```bash
sudo ./blacklist-manager.sh diagnose
```

---

**重要提示**: 所有脚本现在都支持 CentOS，但推荐阅读 `CENTOS_QUICK_START.md` 了解 CentOS 特有的配置和注意事项！

🎉 **脚本已针对 CentOS 优化，可以直接使用！**
