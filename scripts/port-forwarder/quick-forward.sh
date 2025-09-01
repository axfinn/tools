#!/bin/bash

# 🚀 快速端口转发脚本
# 一行命令实现端口转发

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示帮助
if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << EOF
${BLUE}🚀 快速端口转发工具${NC}

${GREEN}用法:${NC}
    $(basename $0) <本地端口> <目标主机> <目标端口> [方法]

${GREEN}参数:${NC}
    本地端口    - 本地监听端口
    目标主机    - 目标主机IP或域名
    目标端口    - 目标主机端口
    方法        - 转发方法 (socat|nc) 默认: socat

${GREEN}示例:${NC}
    # 转发本地8080到192.168.1.100的80端口
    $(basename $0) 8080 192.168.1.100 80
    
    # 使用nc方法转发
    $(basename $0) 3306 192.168.1.200 3306 nc
    
    # SSH转发
    $(basename $0) 2222 192.168.1.50 22 socat

EOF
    exit 0
fi

LOCAL_PORT="$1"
TARGET_HOST="$2"
TARGET_PORT="$3"
METHOD="${4:-socat}"

# 验证端口号
if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]] || [ "$LOCAL_PORT" -lt 1 ] || [ "$LOCAL_PORT" -gt 65535 ]; then
    echo -e "${RED}❌ 无效的本地端口: $LOCAL_PORT${NC}" >&2
    exit 1
fi

if ! [[ "$TARGET_PORT" =~ ^[0-9]+$ ]] || [ "$TARGET_PORT" -lt 1 ] || [ "$TARGET_PORT" -gt 65535 ]; then
    echo -e "${RED}❌ 无效的目标端口: $TARGET_PORT${NC}" >&2
    exit 1
fi

# 检查端口是否被占用
if netstat -ln 2>/dev/null | grep -q ":$LOCAL_PORT "; then
    echo -e "${RED}❌ 本地端口 $LOCAL_PORT 已被占用${NC}" >&2
    exit 1
fi

echo -e "${BLUE}🚀 启动端口转发...${NC}"
echo -e "  📡 本地端口: ${GREEN}$LOCAL_PORT${NC}"
echo -e "  🎯 目标地址: ${GREEN}$TARGET_HOST:$TARGET_PORT${NC}"
echo -e "  🔧 转发方法: ${GREEN}$METHOD${NC}"
echo -e "  ⏹️  按 Ctrl+C 停止转发"
echo

# 根据方法执行转发
case "$METHOD" in
    socat)
        if ! command -v socat >/dev/null 2>&1; then
            echo -e "${RED}❌ 未找到 socat 工具${NC}" >&2
            echo -e "${YELLOW}💡 安装: brew install socat (macOS) 或 apt install socat (Linux)${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ 使用 socat 进行转发...${NC}"
        socat TCP-LISTEN:$LOCAL_PORT,fork,reuseaddr TCP:$TARGET_HOST:$TARGET_PORT
        ;;
    nc)
        if ! command -v nc >/dev/null 2>&1; then
            echo -e "${RED}❌ 未找到 nc 工具${NC}" >&2
            exit 1
        fi
        echo -e "${GREEN}✅ 使用 nc 进行转发...${NC}"
        # 使用命名管道实现双向转发
        FIFO="/tmp/nc_forward_$$"
        mkfifo "$FIFO"
        
        # 清理函数
        cleanup() {
            rm -f "$FIFO"
            exit 0
        }
        trap cleanup INT TERM
        
        while true; do
            nc -l "$LOCAL_PORT" < "$FIFO" | nc "$TARGET_HOST" "$TARGET_PORT" > "$FIFO"
        done
        ;;
    *)
        echo -e "${RED}❌ 不支持的转发方法: $METHOD${NC}" >&2
        echo -e "${BLUE}💡 支持的方法: socat, nc${NC}"
        exit 1
        ;;
esac
