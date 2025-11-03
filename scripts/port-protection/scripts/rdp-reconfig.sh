#!/bin/bash

# RDP端口重新配置脚本
# 使用正确的RDP优化模式
# 用法: ./rdp-reconfig.sh <端口号> <可信IP1> [可信IP2] ...

# 自动检测脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTECT_SCRIPT="$SCRIPT_DIR/port-protect.sh"

# 检查脚本是否存在
if [ ! -f "$PROTECT_SCRIPT" ]; then
    echo "❌ 错误: 找不到 port-protect.sh 脚本"
    echo "期望路径: $PROTECT_SCRIPT"
    exit 1
fi

# 检查参数
if [ $# -lt 2 ]; then
    echo "用法: $0 <端口号> <可信IP1> [可信IP2] ..."
    echo ""
    echo "示例:"
    echo "  $0 19099 192.168.1.100"
    echo "  $0 19099 192.168.1.100 10.0.0.5"
    exit 1
fi

# 获取端口号
RDP_PORT=$1
shift

# 获取所有可信IP
TRUSTED_IPS=("$@")

echo "🔧 重新配置RDP端口${RDP_PORT}的防护规则"
echo "📋 可信IP列表: ${TRUSTED_IPS[*]}"

# 1. 先备份当前规则
echo "📦 备份当前规则..."
sudo "$PROTECT_SCRIPT" backup before_rdp_reconfig

# 2. 移除现有的端口规则
echo "🗑️  移除现有规则..."
sudo "$PROTECT_SCRIPT" remove "$RDP_PORT"

# 3. 使用RDP优化模式重新添加
echo "🛡️  添加RDP优化模式防护..."
CMD="sudo \"$PROTECT_SCRIPT\" add $RDP_PORT --rdp"
for ip in "${TRUSTED_IPS[@]}"; do
    CMD="$CMD -t $ip"
done
eval "$CMD"

# 4. 检查新规则状态
echo "📊 检查规则状态..."
sudo "$PROTECT_SCRIPT" list-ports

# 5. 保存规则
echo "💾 保存规则..."
sudo "$PROTECT_SCRIPT" save

echo "✅ RDP端口重新配置完成！"
echo ""
echo "新的防护参数："
echo "- 速率限制: 30/min (每分钟最多30个新连接)"
echo "- 突发限制: 50"
echo "- 已建立连接: 无限制"
echo "- 可信IP: ${TRUSTED_IPS[*]}"
echo ""
echo "验证命令:"
echo "sudo iptables -L DOCKER-HOST-PROTECT-${RDP_PORT} -n --line-numbers"
echo "sudo ./port-protect.sh status"
