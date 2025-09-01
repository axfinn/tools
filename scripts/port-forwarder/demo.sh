#!/bin/bash

# 🎯 端口转发方法对比演示
# 展示不同转发方法的特点和适用场景

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${WHITE}🎯 端口转发方法对比演示${NC}"
echo "=================================================================="
echo

# 系统检测
OS_TYPE=$(uname -s)
IS_ROOT=$([[ $EUID -eq 0 ]] && echo "true" || echo "false")

echo -e "${CYAN}📋 系统信息:${NC}"
echo -e "  操作系统: $OS_TYPE"
echo -e "  运行权限: $([ "$IS_ROOT" = "true" ] && echo "root" || echo "普通用户")"
echo

# 工具检测
echo -e "${CYAN}🔧 可用工具检测:${NC}"

# socat
if command -v socat >/dev/null 2>&1; then
    echo -e "  ✅ socat    - $(socat -V | head -1)"
else
    echo -e "  ❌ socat    - 未安装"
fi

# nc
if command -v nc >/dev/null 2>&1; then
    echo -e "  ✅ nc       - $(nc -h 2>&1 | head -1 | cut -d' ' -f1-2)"
else
    echo -e "  ❌ nc       - 未安装"
fi

# ssh
if command -v ssh >/dev/null 2>&1; then
    echo -e "  ✅ ssh      - $(ssh -V 2>&1 | cut -d' ' -f1)"
else
    echo -e "  ❌ ssh      - 未安装"
fi

# iptables (仅Linux)
if [ "$OS_TYPE" = "Linux" ]; then
    if command -v iptables >/dev/null 2>&1; then
        if [ "$IS_ROOT" = "true" ]; then
            echo -e "  ✅ iptables - $(iptables --version | cut -d' ' -f1-2)"
        else
            echo -e "  ⚠️ iptables - 已安装但需要root权限"
        fi
    else
        echo -e "  ❌ iptables - 未安装"
    fi
else
    echo -e "  ➖ iptables - 不适用于 $OS_TYPE"
fi

echo
echo "=================================================================="

# 方法对比表
echo -e "${WHITE}📊 转发方法对比${NC}"
echo
printf "${CYAN}%-12s %-10s %-10s %-15s %-15s %s${NC}\n" \
    "方法" "性能" "资源占用" "适用系统" "权限要求" "特点"
echo "=================================================================="

printf "%-12s %-10s %-10s %-15s %-15s %s\n" \
    "socat" "高" "中等" "Linux/macOS" "普通用户" "稳定，功能丰富"

printf "%-12s %-10s %-10s %-15s %-15s %s\n" \
    "nc" "中等" "低" "Linux/macOS" "普通用户" "轻量，系统自带"

printf "%-12s %-10s %-10s %-15s %-15s %s\n" \
    "ssh" "中等" "中等" "Linux/macOS" "SSH密钥" "加密传输"

printf "%-12s %-10s %-10s %-15s %-15s %s\n" \
    "iptables" "最高" "最低" "仅Linux" "root" "内核级转发"

echo
echo "=================================================================="

# 使用场景推荐
echo -e "${WHITE}🎯 使用场景推荐${NC}"
echo

echo -e "${GREEN}🔸 开发测试环境:${NC}"
echo -e "  推荐: ${YELLOW}socat${NC} 或 ${YELLOW}nc${NC}"
echo -e "  理由: 安装简单，使用灵活，适合临时转发"
echo

echo -e "${GREEN}🔸 生产环境:${NC}"
echo -e "  推荐: ${YELLOW}iptables${NC} (Linux) 或 ${YELLOW}socat${NC} (macOS)"
echo -e "  理由: 性能最佳，资源占用最低"
echo

echo -e "${GREEN}🔸 安全要求高的场景:${NC}"
echo -e "  推荐: ${YELLOW}ssh${NC} 隧道"
echo -e "  理由: 端到端加密，安全性最高"
echo

echo -e "${GREEN}🔸 高并发场景:${NC}"
echo -e "  推荐: ${YELLOW}iptables${NC}"
echo -e "  理由: 内核级处理，无用户空间开销"
echo

echo -e "${GREEN}🔸 跨平台兼容:${NC}"
echo -e "  推荐: ${YELLOW}socat${NC}"
echo -e "  理由: 支持多种操作系统和协议"
echo

echo "=================================================================="

# 性能测试建议
echo -e "${WHITE}⚡ 性能测试建议${NC}"
echo

echo -e "${BLUE}1. 延迟测试:${NC}"
echo '  ping <目标主机>'
echo

echo -e "${BLUE}2. 带宽测试:${NC}"
echo '  # 使用 iperf3 测试'
echo '  iperf3 -s                    # 服务端'
echo '  iperf3 -c <服务端IP>         # 客户端'
echo

echo -e "${BLUE}3. 并发连接测试:${NC}"
echo '  # 使用 ab 测试HTTP服务'
echo '  ab -n 1000 -c 10 http://localhost:8080/'
echo

echo -e "${BLUE}4. 资源占用监控:${NC}"
echo '  top -p <进程ID>               # 监控CPU和内存'
echo '  ss -tunlp | grep :<端口>      # 监控网络连接'
echo

echo "=================================================================="

# 故障排除
echo -e "${WHITE}🔧 常见问题排除${NC}"
echo

echo -e "${RED}问题1: 端口被占用${NC}"
echo -e "${BLUE}解决:${NC} netstat -tulpn | grep :<端口号>"
echo -e "      lsof -i :<端口号>"
echo

echo -e "${RED}问题2: 权限不足${NC}"
echo -e "${BLUE}解决:${NC} sudo ./script.sh (iptables方法)"
echo -e "      使用其他方法 (socat/nc/ssh)"
echo

echo -e "${RED}问题3: 防火墙阻断${NC}"
echo -e "${BLUE}解决:${NC} sudo ufw allow <端口> (Ubuntu)"
echo -e "      sudo firewall-cmd --add-port=<端口>/tcp (CentOS)"
echo

echo -e "${RED}问题4: 目标不可达${NC}"
echo -e "${BLUE}解决:${NC} ping <目标主机>"
echo -e "      telnet <目标主机> <端口>"
echo

echo "=================================================================="

# 快速开始
echo -e "${WHITE}🚀 快速开始命令${NC}"
echo

echo -e "${GREEN}基础转发 (8080 -> 192.168.1.100:80):${NC}"
echo

echo -e "${YELLOW}socat 方法:${NC}"
echo '  ./quick-forward.sh 8080 192.168.1.100 80 socat'
echo

echo -e "${YELLOW}nc 方法:${NC}"
echo '  ./quick-forward.sh 8080 192.168.1.100 80 nc'
echo

echo -e "${YELLOW}管理方式:${NC}"
echo '  ./port-forwarder.sh add web -l 8080 -h 192.168.1.100 -p 80'
echo '  ./port-forwarder.sh start web'
echo

if [ "$OS_TYPE" = "Linux" ] && [ "$IS_ROOT" = "true" ]; then
    echo -e "${YELLOW}iptables 方法:${NC}"
    echo '  ./iptables-forward.sh add web -l 8080 -h 192.168.1.100 -p 80'
    echo '  ./iptables-forward.sh enable web'
fi

echo
echo -e "${CYAN}💡 更多帮助:${NC}"
echo '  ./port-forwarder.sh help'
echo '  ./quick-forward.sh --help'
if [ "$OS_TYPE" = "Linux" ]; then
    echo '  ./iptables-forward.sh help'
fi

echo
echo "=================================================================="
echo -e "${GREEN}✅ 演示完成！选择适合你的转发方法开始使用吧！${NC}"
