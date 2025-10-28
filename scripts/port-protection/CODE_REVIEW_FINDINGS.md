# Port Protection Script - 代码审查发现的问题

## 日期：2025-10-28

## 严重问题

### 1. rdp-reconfig.sh - 硬编码占位符 (高优先级)
**文件**: rdp-reconfig.sh:30
**问题**: 包含未替换的占位符 "你的IP地址"
**影响**: 脚本无法直接使用，会导致 IP 验证失败
**修复**: 应改为提示用户传入参数或使用环境变量

```bash
# 当前代码:
sudo "$PROTECT_SCRIPT" add 19099 --rdp -t 你的IP地址

# 建议修复:
if [ $# -lt 1 ]; then
    echo "用法: $0 <可信IP地址>"
    exit 1
fi
sudo "$PROTECT_SCRIPT" add 19099 --rdp -t "$1"
```

## 逻辑问题

### 2. RDP模式参数覆盖问题
**文件**: port-protect.sh:336-339
**问题**: --rdp 标志硬编码覆盖 limit 和 burst，用户无法自定义
**影响**: 即使用户在 --rdp 之前指定了 -l 或 -b，也会被覆盖
**当前行为**:
```bash
-r|--rdp)
    rdp_mode=true
    limit="30/min"    # 直接覆盖
    burst="50"        # 直接覆盖
```
**建议**: 仅在用户未指定时才设置默认值，或在文档中明确说明参数顺序

### 3. 参数验证位置问题
**文件**: port-protect.sh:286-315
**问题**: --protocol 和 --burst 参数在 shift 前验证，但验证错误后仍然 exit，可能导致参数混乱
**建议**: 统一验证逻辑，在所有参数解析完成后统一验证

### 4. 链名冲突处理不完整
**文件**: port-protect.sh:374-382
**问题**: 当使用共享链时，条件判断不够严格
```bash
if [[ "$chain_name" == *"-${port}" ]]; then
    # 只清空包含端口号的链
else
    echo " [!] 使用共享链 $chain_name (不会清空已有其它端口规则)"
fi
```
**影响**: 如果用户手动创建名为 "MYCHAIN-3389" 的链保护端口 8080，会被误判为专用链

### 5. remove_rules 协议参数处理不一致
**文件**: port-protect.sh:462-466
**问题**: remove 命令接受协议参数但未在命令行解析中实现
```bash
remove_rules() {
    local port=$1
    local protocol="${2:-tcp}"  # 接受协议参数
    local user_chain="${3:-}"
```
但在 main 函数中：
```bash
remove)
    # ... 只传递了 port
    remove_rules "$port"  # 协议和链名未传递
```
**影响**: 移除 UDP 端口规则时无法正确指定协议

### 6. status 命令只显示旧版共享链
**文件**: port-protect.sh:524-554
**问题**: status 命令只检查 DOCKER-HOST-PROTECT 链，不显示新版独立链
```bash
if iptables -L "$CHAIN_NAME" >/dev/null 2>&1; then
    # 只显示 DOCKER-HOST-PROTECT
```
**影响**: 使用独立链（新版默认）的端口状态不会显示

## 潜在问题

### 7. 备份文件权限
**文件**: port-protect.sh:150-154
**问题**: 备份文件可能包含敏感防火墙规则，但未设置权限
**建议**: 创建备份后设置 600 权限
```bash
chmod 600 "$backup_file"
```

### 8. 错误处理不完整
**文件**: 多处
**问题**: 某些 iptables 命令失败后继续执行
**示例**: port-protect.sh:387-391
```bash
if iptables -A "$chain_name" -s "$ip" -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null; then
    echo " [+] 添加可信IP(限端口 $port): $ip"
else
    echo "警告: 无法添加可信IP $ip" >&2
    # 继续执行，不退出
fi
```
**建议**: 关键操作失败应该退出

### 9. list-ports 正则可能不匹配所有情况
**文件**: port-protect.sh:561
**问题**: 正则假设链名格式固定
```bash
iptables -S INPUT 2>/dev/null | grep -E "-j (${CHAIN_NAME}(-[0-9]+)?)"
```
**影响**: 自定义链名可能无法被 list-ports 识别

### 10. 配置文件未使用
**文件**: port-protect.sh:12, 161-163
**问题**: 创建了 /etc/port-protect.conf 但只用于记录备份路径，未实现端口配置持久化
**建议**: 可以用于保存端口配置映射，便于管理

## 文档问题

### 11. README 示例与实际行为不符
**文件**: README.md:302-303
**问题**: 文档说参数顺序重要，但代码中 --rdp 无条件覆盖
```markdown
执行顺序很重要：若把 `-l` 放在 `--rdp` 之前会被 RDP 预设覆盖，应始终放在其后。
```
**实际**: 即使放在后面也会被覆盖（因为在 case 语句中立即设置）

### 12. rdp-reconfig.sh 验证命令错误
**文件**: rdp-reconfig.sh:48
**问题**: 验证命令仍使用旧版共享链名
```bash
sudo iptables -L DOCKER-HOST-PROTECT -n --line-numbers
```
**应该**: 使用新版独立链名 `DOCKER-HOST-PROTECT-19099`

## 测试建议

1. 测试所有命令行参数组合
2. 测试多端口独立链场景
3. 测试链冲突和重复添加场景
4. 测试备份恢复完整流程
5. 测试错误输入和边界条件
6. 验证 UDP 协议支持
7. 测试白名单模式
8. 测试严格模式

## 优先级修复顺序

1. **紧急**: 修复 rdp-reconfig.sh 占位符问题
2. **高**: 修复 remove 命令协议参数支持
3. **高**: 修复 status 命令不显示独立链
4. **中**: 改进 RDP 模式参数处理逻辑
5. **中**: 添加备份文件权限设置
6. **低**: 优化链名冲突检测
7. **低**: 改进配置文件使用
8. **文档**: 更新 README 和示例脚本
