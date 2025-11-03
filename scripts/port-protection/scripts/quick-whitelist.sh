#!/bin/bash

# 快速白名单管理脚本
# 用途：在不同地点快速添加当前IP到白名单

set -euo pipefail

PORT="${RDP_PORT:-19099}"
CHAIN_NAME="DOCKER-HOST-PROTECT-${PORT}"
WHITELIST_FILE="/etc/port-protect-whitelist.txt"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 需要root权限${NC}" >&2
        echo "请使用: sudo $0 $*"
        exit 1
    fi
}

# 获取当前SSH连接的IP
get_current_ip() {
    local ip=""
    if [ -n "${SSH_CLIENT:-}" ]; then
        ip=$(echo "$SSH_CLIENT" | awk '{print $1}')
    elif [ -n "${SSH_CONNECTION:-}" ]; then
        ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    fi

    if [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi
    return 1
}

# 添加IP到白名单
add_ip() {
    local ip="$1"
    local duration="${2:-1h}"  # 默认1小时后过期

    # 验证IP
    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}无效的IP地址: $ip${NC}" >&2
        return 1
    fi

    # 检查链是否存在
    if ! iptables -L "$CHAIN_NAME" >/dev/null 2>&1; then
        echo -e "${RED}错误: 链 $CHAIN_NAME 不存在${NC}" >&2
        echo "请先运行: sudo ./port-protect.sh add $PORT --rdp"
        return 1
    fi

    # 检查IP是否已在白名单
    if iptables -C "$CHAIN_NAME" -s "$ip" -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null; then
        echo -e "${YELLOW}IP $ip 已在白名单中${NC}"
        return 0
    fi

    # 添加到链的最前面（优先级最高）
    if iptables -I "$CHAIN_NAME" 1 -s "$ip" -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null; then
        echo -e "${GREEN}✅ 已添加 $ip 到白名单${NC}"

        # 记录到文件
        echo "$(date +%s) $ip $duration" >> "$WHITELIST_FILE"

        # 显示过期时间
        if [[ "$duration" =~ ^([0-9]+)([hmd])$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            case "$unit" in
                h) echo "   有效期: ${num}小时" ;;
                d) echo "   有效期: ${num}天" ;;
                m) echo "   有效期: ${num}分钟" ;;
            esac
        fi
    else
        echo -e "${RED}添加失败${NC}" >&2
        return 1
    fi
}

# 移除IP
remove_ip() {
    local ip="$1"

    # 从iptables移除
    while iptables -D "$CHAIN_NAME" -s "$ip" -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null; do
        :
    done

    echo -e "${GREEN}✅ 已从白名单移除: $ip${NC}"
}

# 列出当前白名单
list_whitelist() {
    echo -e "${GREEN}当前白名单:${NC}"
    echo "========================================="

    if ! iptables -L "$CHAIN_NAME" -n --line-numbers 2>/dev/null | grep "ACCEPT.*tcp dpt:$PORT"; then
        echo "白名单为空"
    fi

    echo "========================================="
}

# 清理过期IP
cleanup_expired() {
    if [ ! -f "$WHITELIST_FILE" ]; then
        return 0
    fi

    local now=$(date +%s)
    local cleaned=0

    while IFS=' ' read -r timestamp ip duration; do
        # 计算过期时间
        local expire_time
        if [[ "$duration" =~ ^([0-9]+)h$ ]]; then
            expire_time=$((timestamp + ${BASH_REMATCH[1]} * 3600))
        elif [[ "$duration" =~ ^([0-9]+)d$ ]]; then
            expire_time=$((timestamp + ${BASH_REMATCH[1]} * 86400))
        elif [[ "$duration" =~ ^([0-9]+)m$ ]]; then
            expire_time=$((timestamp + ${BASH_REMATCH[1]} * 60))
        else
            continue
        fi

        # 如果过期，移除
        if [ "$now" -gt "$expire_time" ]; then
            remove_ip "$ip"
            cleaned=$((cleaned + 1))
        fi
    done < "$WHITELIST_FILE"

    # 清理记录文件
    if [ "$cleaned" -gt 0 ]; then
        grep -v "^$(date +%s)" "$WHITELIST_FILE" > "${WHITELIST_FILE}.tmp" 2>/dev/null || true
        mv "${WHITELIST_FILE}.tmp" "$WHITELIST_FILE" 2>/dev/null || true
        echo -e "${GREEN}清理了 $cleaned 个过期IP${NC}"
    fi
}

# 添加当前IP
add_current() {
    local duration="${1:-2h}"

    if current_ip=$(get_current_ip); then
        echo -e "${GREEN}检测到当前IP: $current_ip${NC}"
        add_ip "$current_ip" "$duration"
    else
        echo -e "${RED}无法检测当前IP${NC}" >&2
        echo "请手动指定: sudo $0 add <IP地址> [时长]"
        return 1
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        add-current)
            check_root "$@"
            cleanup_expired
            add_current "${2:-2h}"
            ;;
        add)
            check_root "$@"
            if [ $# -lt 2 ]; then
                echo -e "${RED}用法: $0 add <IP> [时长]${NC}" >&2
                echo "示例: $0 add 1.2.3.4 2h"
                echo "时长格式: 1h=1小时, 1d=1天, 30m=30分钟"
                exit 1
            fi
            cleanup_expired
            add_ip "$2" "${3:-2h}"
            ;;
        remove)
            check_root "$@"
            if [ $# -lt 2 ]; then
                echo -e "${RED}用法: $0 remove <IP>${NC}" >&2
                exit 1
            fi
            remove_ip "$2"
            ;;
        list)
            list_whitelist
            ;;
        cleanup)
            check_root "$@"
            cleanup_expired
            ;;
        help|--help|-h)
            cat << EOF
${GREEN}快速白名单管理脚本${NC}

${YELLOW}用途:${NC} 在不同地点快速添加临时白名单IP

${YELLOW}命令:${NC}
  add-current [时长]    添加当前SSH连接的IP（默认2小时）
  add <IP> [时长]       添加指定IP
  remove <IP>          移除IP
  list                 列出当前白名单
  cleanup              清理过期IP

${YELLOW}示例:${NC}
  # 添加当前IP，2小时后过期
  sudo $0 add-current

  # 添加当前IP，1天后过期
  sudo $0 add-current 1d

  # 添加指定IP，12小时后过期
  sudo $0 add 1.2.3.4 12h

  # 查看白名单
  sudo $0 list

  # 移除IP
  sudo $0 remove 1.2.3.4

${YELLOW}时长格式:${NC}
  - 1h, 2h, 24h (小时)
  - 1d, 7d (天)
  - 30m, 60m (分钟)

${YELLOW}建议配置 cron 定时清理:${NC}
  # 每小时清理一次过期IP
  echo "0 * * * * /usr/local/bin/quick-whitelist.sh cleanup" | sudo crontab -

${YELLOW}配合RDP使用:${NC}
  1. 先配置RDP保护: sudo ./port-protect.sh add 19099 --rdp
  2. SSH登录后: sudo $0 add-current
  3. 然后就可以从当前IP RDP登录了

EOF
            ;;
        *)
            echo -e "${RED}未知命令: $1${NC}" >&2
            echo "使用 $0 help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
