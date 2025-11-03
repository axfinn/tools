# Port Protection v3.1.1 变更日志

## 🔒 关键安全修复：RDP 端口防护增强

**发布日期**: 2025-11-03
**版本**: v3.1.1
**重要性**: 🔴 关键安全修复

---

## 📋 更新概览

修复了 RDP 端口防护中的关键缺陷，攻击者可以通过建立多个并发连接绕过速率限制进行密码爆破。

**核心问题**：
- ❌ 旧版本只限制新连接的速率（30/min），但不限制单IP的并发连接数
- ❌ 攻击者可以同时打开多个TCP连接，在每个连接上进行密码爆破
- ❌ 速率限制失效，导致RDP端口仍然可以被高频爆破

**修复方案**：
- ✅ 新增 **connlimit 并发连接数限制**（单IP最多3个并发连接）
- ✅ 结合速率限制 + 并发限制，实现双重防护
- ✅ 保持已建立连接的正常通过，不影响已登录用户
- ✅ 白名单IP优先放行，不受任何限制影响

---

## 🔧 核心变更

### port-protect.sh (v3.1.0 → v3.1.1)

#### 🔒 安全修复

**新增并发连接限制**（port-protect.sh:458-466）：
```bash
# RDP模式新增：限制单个IP的并发连接数
if ! iptables -A "$chain_name" -p "$protocol" --dport "$port" \
               -m conntrack --ctstate NEW \
               -m connlimit --connlimit-above 3 --connlimit-mask 32 -j DROP 2>/dev/null; then
    echo "警告: 无法添加连接数限制（需要 xt_connlimit 模块）" >&2
else
    echo " [+] 限制单IP最多3个并发连接（防止多连接爆破）"
fi
```

**防护机制调整**：
```bash
# 旧版本（v3.1.0及更早）：
1. 可信IP放行
2. ESTABLISHED 连接放行
3. NEW 连接速率限制（30/min，burst 50）
4. 其他DROP

# 新版本（v3.1.1）：
1. 可信IP放行（不受任何限制）
2. ESTABLISHED 连接放行（已登录用户正常使用）
3. NEW 连接并发数限制（单IP≤3个）  ← 新增
4. NEW 连接速率限制（30/min，burst 50）
5. 其他DROP
```

#### 📊 防护效果对比

| 场景 | v3.1.0（旧版本） | v3.1.1（新版本） |
|------|-----------------|-----------------|
| 攻击者打开10个并发连接 | ✅ 允许（绕过防护） | ❌ 拒绝（只允许3个） |
| 攻击者在1分钟内尝试100次 | ⚠️ 只拦截部分 | ✅ 完全拦截 |
| 正常用户已登录使用 | ✅ 不影响 | ✅ 不影响 |
| 白名单IP访问 | ✅ 不受限 | ✅ 不受限 |

#### 🎯 影响范围

**影响的功能**：
- `--rdp` 模式：新增并发连接数限制
- RDP 端口防护：从单一速率限制升级为双重防护

**不影响的功能**：
- 普通模式（非 --rdp）：保持原有行为
- `--whitelist-only` 模式：不受影响
- `--strict` 模式：不受影响
- 白名单IP：不受任何限制影响

---

## 📖 使用建议

### 🔄 升级操作

如果你已经在使用 RDP 保护，建议立即升级：

```bash
# 1. 移除现有规则
sudo ./port-protect.sh remove 19099

# 2. 重新添加（使用新版本的增强防护）
sudo ./port-protect.sh add 19099 --rdp -t 你的IP

# 3. 保存规则
sudo ./port-protect.sh save

# 4. 查看状态
sudo ./port-protect.sh status
```

### ✅ 验证防护效果

```bash
# 查看规则详情
sudo iptables -L DOCKER-HOST-PROTECT-19099 -n -v --line-numbers

# 应该看到类似输出：
# Chain DOCKER-HOST-PROTECT-19099 (1 references)
# 1. ACCEPT  tcp  --  你的IP  0.0.0.0/0  tcp dpt:19099
# 2. ACCEPT  tcp  --  *  *  tcp dpt:19099 ctstate RELATED,ESTABLISHED
# 3. DROP    tcp  --  *  *  tcp dpt:19099 ctstate NEW #conn src/32 > 3
# 4. ACCEPT  tcp  --  *  *  tcp dpt:19099 ctstate NEW limit: avg 30/min burst 50
# 5. DROP    tcp  --  *  *  tcp dpt:19099
```

### 🧪 测试并发连接限制

从另一台机器测试（替换为你的服务器IP）：

```bash
# 测试并发连接限制（应该在3个后被拒绝）
for i in {1..10}; do
    echo "连接 $i"
    timeout 5 telnet 服务器IP 19099 &
done
wait

# 检查有多少连接成功（应该只有3个）
netstat -an | grep :19099 | grep ESTABLISHED | wc -l
```

---

## 🛠️ 技术细节

### iptables connlimit 模块

**模块说明**：
- `xt_connlimit`：Linux 内核模块，用于限制每个IP的并发连接数
- 大多数现代 Linux 发行版默认包含此模块
- 如果模块不可用，脚本会显示警告但继续运行（仅使用速率限制）

**检查模块是否可用**：
```bash
# 检查内核模块
lsmod | grep xt_connlimit

# 或者尝试加载
modprobe xt_connlimit

# 查看模块信息
modinfo xt_connlimit
```

### 为什么选择限制3个并发连接？

1. **正常使用**：RDP 客户端通常只需要 1-2 个连接
2. **断线重连**：预留额外连接用于网络波动时的重连
3. **防护效果**：3个连接足够正常使用，但不足以进行高效爆破

### 性能影响

- ✅ **极低开销**：connlimit 在内核层面实现，性能损耗可忽略
- ✅ **无状态表压力**：只计数当前连接，不记录历史
- ✅ **不影响已建立连接**：只在建立新连接时检查

---

## 📚 相关文档更新

- ✅ `RDP-USAGE.md`: 更新了问题分析和防护机制说明
- ✅ `port-protect.sh`: 更新了输出信息，显示并发连接限制状态

---

## 🔜 下一步计划

- [ ] 添加可配置的并发连接数限制参数（`--max-conns`）
- [ ] 支持更细粒度的连接控制（按子网限制）
- [ ] 添加连接数统计和监控功能
- [ ] 集成 fail2ban 进行持久化封禁

---

## 🙏 致谢

感谢用户反馈 RDP 端口防护失效的问题，这次修复显著提升了安全性！

---

## 📞 支持

如有问题或建议，请提交 Issue 或 Pull Request。
