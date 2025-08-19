#!/bin/bash

# RDP端口重新配置脚本
# 使用正确的RDP优化模式

echo "🔧 重新配置RDP端口19099的防护规则"

# 1. 先备份当前规则
echo "📦 备份当前规则..."
sudo /path/to/port-protect.sh backup before_rdp_reconfig

# 2. 移除现有的19099端口规则
echo "🗑️  移除现有规则..."
sudo /path/to/port-protect.sh remove 19099

# 3. 使用RDP优化模式重新添加（请替换为你的实际IP地址）
echo "🛡️  添加RDP优化模式防护..."
sudo /path/to/port-protect.sh add 19099 --rdp -t 你的IP地址

# 4. 检查新规则状态
echo "📊 检查规则状态..."
sudo /path/to/port-protect.sh status

# 5. 保存规则
echo "💾 保存规则..."
sudo /path/to/port-protect.sh save

echo "✅ RDP端口重新配置完成！"
echo ""
echo "新的防护参数："
echo "- 速率限制: 30/min (每分钟最多30个新连接)"
echo "- 突发限制: 50"
echo "- 已建立连接: 无限制"
echo ""
echo "验证命令:"
echo "sudo iptables -L DOCKER-HOST-PROTECT -n --line-numbers"
