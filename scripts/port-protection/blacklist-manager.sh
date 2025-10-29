#!/bin/bash

# 黑名单管理脚本
# 管理被封禁的IP地址，支持滚动日志记录
# 使用 ipset 实现高效的IP集合管理

set -e

# 配置
IPSET_NAME="port-protect-blacklist"
BAN_LOG="/var/log/port-protect-ban.log"
BAN_HISTORY="/var/log/port-protect-ban-history.log"
CONFIG_FILE="/etc/port-protect-autoban.conf"
DEFAULT_BAN_DURATION=2592000  # 30天 (秒)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "黑名单管理脚本"
    echo "使用方式: $0 [命令] [参数]"
    echo
    echo "命令:"
    echo "  init                     初始化黑名单系统（创建ipset和iptables规则）"
    echo "  ban <IP> [原因] [时长]   封禁IP地址"
    echo "  unban <IP>               解封IP地址"
    echo "  check <IP>               检查IP是否被封禁"
    echo "  list                     列出所有被封禁的IP"
    echo "  history [IP]             查看封禁历史记录"
    echo "  flush                    清空所有封禁"
    echo "  status                   查看黑名单系统状态"
    echo "  cleanup                  清理过期的日志记录"
    echo
    echo "参数:"
    echo "  IP       - IP地址或CIDR网段"
    echo "  原因     - 封禁原因（可选，默认：Manual ban）"
    echo "  时长     - 封禁时长（秒，可选，默认：30天，0表示永久）"
    echo
    echo "示例:"
    echo "  $0 init                              # 初始化系统"
    echo "  $0 ban 1.2.3.4                       # 封禁IP（30天）"
    echo "  $0 ban 1.2.3.4 \"爆破攻击\" 86400     # 封禁24小时"
    echo "  $0 ban 1.2.3.4 \"恶意扫描\" 0         # 永久封禁"
    echo "  $0 unban 1.2.3.4                     # 解封IP"
    echo "  $0 check 1.2.3.4                     # 检查IP状态"
    echo "  $0 list                              # 列出所有封禁"
    echo "  $0 history                           # 查看所有历史"
    echo "  $0 history 1.2.3.4                   # 查看指定IP历史"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}" >&2
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    local missing_deps=()

    if ! command -v ipset >/dev/null 2>&1; then
        missing_deps+=("ipset")
    fi

    if ! command -v iptables >/dev/null 2>&1; then
        missing_deps+=("iptables")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少必要的依赖项: ${missing_deps[*]}${NC}" >&2
        echo "请安装: apt-get install ipset iptables  或  yum install ipset iptables" >&2
        exit 1
    fi
}

# 初始化日志文件
init_logs() {
    # 创建日志文件
    for log in "$BAN_LOG" "$BAN_HISTORY"; do
        if [ ! -f "$log" ]; then
            touch "$log" 2>/dev/null || {
                echo -e "${RED}错误: 无法创建日志文件 $log${NC}" >&2
                exit 1
            }
            chmod 600 "$log"
        fi
    done
}

# 记录到日志（滚动日志）
log_ban() {
    local ip="$1"
    local reason="$2"
    local duration="$3"
    local action="$4"  # BAN 或 UNBAN
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local expire_time=""

    if [ "$duration" = "0" ]; then
        expire_time="永久"
    elif [ -n "$duration" ]; then
        expire_time=$(date -d "@$(($(date +%s) + duration))" "+%Y-%m-%d %H:%M:%S")
    fi

    # 记录到当前日志
    echo "${timestamp}|${action}|${ip}|${reason}|${duration}|${expire_time}" >> "$BAN_LOG"

    # 同时记录到历史日志（用于长期保存）
    echo "${timestamp}|${action}|${ip}|${reason}|${duration}|${expire_time}" >> "$BAN_HISTORY"

    # 检查日志大小，超过10MB自动轮转
    if [ -f "$BAN_LOG" ] && [ $(stat -f%z "$BAN_LOG" 2>/dev/null || stat -c%s "$BAN_LOG") -gt 10485760 ]; then
        local backup_log="${BAN_LOG}.$(date +%Y%m%d-%H%M%S)"
        mv "$BAN_LOG" "$backup_log"
        gzip "$backup_log" &
        touch "$BAN_LOG"
        chmod 600 "$BAN_LOG"
        echo -e "${YELLOW}日志已轮转: $backup_log.gz${NC}"
    fi
}

# 初始化黑名单系统
init_system() {
    echo -e "${BLUE}初始化黑名单系统...${NC}"

    # 检查ipset是否已存在
    if ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}ipset '$IPSET_NAME' 已存在${NC}"
    else
        # 创建ipset集合（hash:ip类型，支持超时）
        if ! ipset create "$IPSET_NAME" hash:ip timeout $DEFAULT_BAN_DURATION 2>/dev/null; then
            echo -e "${RED}错误: 无法创建ipset${NC}" >&2
            exit 1
        fi
        echo -e "${GREEN}✓ 已创建ipset: $IPSET_NAME${NC}"
    fi

    # 检查iptables规则是否存在
    if iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
        echo -e "${YELLOW}iptables规则已存在${NC}"
    else
        # 在INPUT链最前面添加黑名单规则
        if ! iptables -I INPUT 1 -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
            echo -e "${RED}错误: 无法添加iptables规则${NC}" >&2
            exit 1
        fi
        echo -e "${GREEN}✓ 已添加iptables规则${NC}"
    fi

    # 初始化日志
    init_logs

    echo -e "${GREEN}✓ 黑名单系统初始化完成${NC}"
    echo
    echo "提示:"
    echo "  - ipset集合: $IPSET_NAME"
    echo "  - 默认封禁时长: $DEFAULT_BAN_DURATION 秒 (30天)"
    echo "  - 日志文件: $BAN_LOG"
    echo "  - 历史记录: $BAN_HISTORY"
}

# 封禁IP
ban_ip() {
    local ip="$1"
    local reason="${2:-Manual ban}"
    local duration="${3:-$DEFAULT_BAN_DURATION}"

    # 验证IP格式
    if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'; then
        echo -e "${RED}错误: 无效的IP地址格式${NC}" >&2
        exit 1
    fi

    # 检查ipset是否存在
    if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}ipset不存在，正在初始化...${NC}"
        init_system
    fi

    # 检查IP是否已被封禁
    if ipset test "$IPSET_NAME" "$ip" 2>/dev/null; then
        echo -e "${YELLOW}IP $ip 已在黑名单中${NC}"
        return 0
    fi

    # 添加到ipset
    if [ "$duration" = "0" ]; then
        # 永久封禁（无超时）
        if ! ipset add "$IPSET_NAME" "$ip" 2>/dev/null; then
            echo -e "${RED}错误: 无法封禁IP $ip${NC}" >&2
            exit 1
        fi
        echo -e "${GREEN}✓ 已永久封禁 IP: $ip${NC}"
        echo -e "   原因: $reason"
    else
        # 临时封禁（带超时）
        if ! ipset add "$IPSET_NAME" "$ip" timeout "$duration" 2>/dev/null; then
            echo -e "${RED}错误: 无法封禁IP $ip${NC}" >&2
            exit 1
        fi
        local expire_date=$(date -d "@$(($(date +%s) + duration))" "+%Y-%m-%d %H:%M:%S")
        echo -e "${GREEN}✓ 已封禁 IP: $ip${NC}"
        echo -e "   原因: $reason"
        echo -e "   时长: $duration 秒 ($(($duration / 86400))天)"
        echo -e "   过期时间: $expire_date"
    fi

    # 记录到日志
    log_ban "$ip" "$reason" "$duration" "BAN"
}

# 解封IP
unban_ip() {
    local ip="$1"

    # 验证IP格式
    if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'; then
        echo -e "${RED}错误: 无效的IP地址格式${NC}" >&2
        exit 1
    fi

    # 检查IP是否在黑名单中
    if ! ipset test "$IPSET_NAME" "$ip" 2>/dev/null; then
        echo -e "${YELLOW}IP $ip 不在黑名单中${NC}"
        return 0
    fi

    # 从ipset中删除
    if ! ipset del "$IPSET_NAME" "$ip" 2>/dev/null; then
        echo -e "${RED}错误: 无法解封IP $ip${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}✓ 已解封 IP: $ip${NC}"

    # 记录到日志
    log_ban "$ip" "Manual unban" "0" "UNBAN"
}

# 检查IP是否被封禁
check_ip() {
    local ip="$1"

    if ipset test "$IPSET_NAME" "$ip" 2>/dev/null; then
        echo -e "${RED}✗ IP $ip 已被封禁${NC}"

        # 尝试获取剩余时间
        local remaining=$(ipset list "$IPSET_NAME" | grep "$ip" | awk '{print $3}')
        if [ -n "$remaining" ]; then
            echo -e "   剩余时间: $remaining"
        fi
        return 0
    else
        echo -e "${GREEN}✓ IP $ip 未被封禁${NC}"
        return 1
    fi
}

# 列出所有被封禁的IP
list_bans() {
    echo -e "${BLUE}当前黑名单:${NC}"
    echo "========================================"

    if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}黑名单系统未初始化${NC}"
        return 0
    fi

    local count=0
    local output=$(ipset list "$IPSET_NAME" | grep -E '^[0-9]')

    if [ -z "$output" ]; then
        echo "黑名单为空"
    else
        echo "IP地址                剩余时间"
        echo "----------------------------------------"
        while IFS= read -r line; do
            local ip=$(echo "$line" | awk '{print $1}')
            local timeout=$(echo "$line" | awk '{print $3}')

            if [ -n "$timeout" ]; then
                printf "%-20s %s\n" "$ip" "$timeout"
            else
                printf "%-20s %s\n" "$ip" "永久"
            fi
            ((count++))
        done <<< "$output"
    fi

    echo "========================================"
    echo "总计: $count 个IP被封禁"
}

# 查看封禁历史
show_history() {
    local ip="$1"

    echo -e "${BLUE}封禁历史记录:${NC}"
    echo "========================================"

    if [ ! -f "$BAN_HISTORY" ]; then
        echo "暂无历史记录"
        return 0
    fi

    echo "时间                | 操作  | IP地址         | 原因                 | 时长    | 过期时间"
    echo "---------------------------------------------------------------------------------------------------"

    if [ -n "$ip" ]; then
        # 显示指定IP的历史
        grep "|$ip|" "$BAN_HISTORY" | tail -50 | while IFS='|' read -r timestamp action ip_addr reason duration expire; do
            printf "%-19s | %-5s | %-15s | %-20s | %-7s | %s\n" \
                "$timestamp" "$action" "$ip_addr" "${reason:0:20}" "$duration" "$expire"
        done
    else
        # 显示最近50条记录
        tail -50 "$BAN_HISTORY" | while IFS='|' read -r timestamp action ip_addr reason duration expire; do
            printf "%-19s | %-5s | %-15s | %-20s | %-7s | %s\n" \
                "$timestamp" "$action" "$ip_addr" "${reason:0:20}" "$duration" "$expire"
        done
    fi

    echo "========================================"
    local total=$(wc -l < "$BAN_HISTORY" 2>/dev/null || echo "0")
    echo "总记录数: $total (显示最近50条)"
}

# 清空黑名单
flush_bans() {
    echo -e "${YELLOW}警告: 此操作将清空所有封禁${NC}"
    read -p "确认清空？(yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "已取消"
        return 0
    fi

    if ipset flush "$IPSET_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓ 已清空黑名单${NC}"
        log_ban "ALL" "Flush all" "0" "FLUSH"
    else
        echo -e "${RED}错误: 无法清空黑名单${NC}" >&2
        exit 1
    fi
}

# 查看系统状态
show_status() {
    echo -e "${BLUE}黑名单系统状态:${NC}"
    echo "========================================"

    # 检查ipset
    if ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        local count=$(ipset list "$IPSET_NAME" | grep -cE '^[0-9]' || echo "0")
        echo -e "${GREEN}✓ ipset状态: 运行中${NC}"
        echo "  - 集合名称: $IPSET_NAME"
        echo "  - 封禁数量: $count"
        echo "  - 默认超时: $DEFAULT_BAN_DURATION 秒"
    else
        echo -e "${RED}✗ ipset状态: 未初始化${NC}"
    fi

    echo

    # 检查iptables规则
    if iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
        echo -e "${GREEN}✓ iptables规则: 已配置${NC}"
        iptables -L INPUT -n --line-numbers | grep "$IPSET_NAME" | head -1
    else
        echo -e "${RED}✗ iptables规则: 未配置${NC}"
    fi

    echo

    # 日志状态
    echo "日志文件:"
    if [ -f "$BAN_LOG" ]; then
        local size=$(du -h "$BAN_LOG" | awk '{print $1}')
        local lines=$(wc -l < "$BAN_LOG")
        echo "  - 当前日志: $BAN_LOG ($size, $lines 行)"
    else
        echo "  - 当前日志: 不存在"
    fi

    if [ -f "$BAN_HISTORY" ]; then
        local size=$(du -h "$BAN_HISTORY" | awk '{print $1}')
        local lines=$(wc -l < "$BAN_HISTORY")
        echo "  - 历史记录: $BAN_HISTORY ($size, $lines 行)"
    else
        echo "  - 历史记录: 不存在"
    fi

    echo "========================================"
}

# 清理过期的日志记录
cleanup_logs() {
    echo -e "${BLUE}清理过期日志...${NC}"

    # 删除30天前的备份日志
    find "$(dirname "$BAN_LOG")" -name "$(basename "$BAN_LOG").*.gz" -mtime +30 -delete 2>/dev/null

    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 主函数
main() {
    check_root
    check_dependencies

    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=$1
    shift

    case "$command" in
        init)
            init_system
            ;;
        ban)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定IP地址${NC}" >&2
                show_help
                exit 1
            fi
            ban_ip "$@"
            ;;
        unban)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定IP地址${NC}" >&2
                show_help
                exit 1
            fi
            unban_ip "$1"
            ;;
        check)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定IP地址${NC}" >&2
                show_help
                exit 1
            fi
            check_ip "$1"
            ;;
        list)
            list_bans
            ;;
        history)
            show_history "$1"
            ;;
        flush)
            flush_bans
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup_logs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}错误: 未知命令 '$command'${NC}" >&2
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
