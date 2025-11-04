#!/bin/bash

# 全端口防护脚本
# 用途：保护所有端口，记录新连接请求，辅助防护
# 版本：1.0.0

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 配置
GLOBAL_CHAIN="GLOBAL-PORT-PROTECT"
LOG_PREFIX="GLOBAL-PORT-PROTECT: "
LOG_FILE="/var/log/global-port-protect.log"
CONFIG_FILE="/etc/global-port-protect.conf"

# 默认配置
DEFAULT_LIMIT="100/min"
DEFAULT_BURST="200"
DEFAULT_WHITELIST_PORTS="22,80,443"  # SSH, HTTP, HTTPS 不限制

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    cat << EOF
${GREEN}全端口防护脚本${NC} - v${VERSION}

${YELLOW}功能特性：${NC}
  ✅ 保护所有端口（防止端口扫描）
  ✅ 全局速率限制（可自定义）
  ✅ 记录所有新连接请求
  ✅ 日志滚动保存
  ✅ 白名单端口（不受限制）
  ✅ 可信IP白名单

${YELLOW}使用方式：${NC} $0 [命令] [参数]

${YELLOW}命令：${NC}

  ${CYAN}enable${NC}                    启用全端口防护
  ${CYAN}disable${NC}                   禁用全端口防护
  ${CYAN}status${NC}                    查看防护状态
  ${CYAN}logs${NC}                      查看最近的连接日志
  ${CYAN}stats${NC}                     统计连接信息
  ${CYAN}top-ips${NC}                   显示连接最多的IP
  ${CYAN}analyze${NC}                   分析可疑IP并建议封禁

  ${CYAN}add-whitelist-ip <IP>${NC}     添加可信IP（不受限制）
  ${CYAN}remove-whitelist-ip <IP>${NC}  移除可信IP
  ${CYAN}list-whitelist-ips${NC}        列出所有可信IP

  ${CYAN}add-whitelist-port <端口>${NC}    添加白名单端口（不受限制）
  ${CYAN}remove-whitelist-port <端口>${NC} 移除白名单端口
  ${CYAN}list-whitelist-ports${NC}         列出白名单端口

  ${CYAN}set-limit <速率>${NC}          设置速率限制（如：100/min）
  ${CYAN}set-burst <数量>${NC}          设置突发限制

${YELLOW}启用选项：${NC}

  ${CYAN}-l, --limit <速率>${NC}        速率限制（默认: 100/min）
  ${CYAN}-b, --burst <数量>${NC}        突发限制（默认: 200）
  ${CYAN}-t, --trust <IP>${NC}          可信IP（可多次使用）
  ${CYAN}-p, --ports <端口列表>${NC}    白名单端口（逗号分隔，默认: 22,80,443）
  ${CYAN}--log-all${NC}                 记录所有连接（包括允许的）

${YELLOW}示例：${NC}

  # 启用全端口防护（使用默认配置）
  sudo $0 enable

  # 启用并自定义配置
  sudo $0 enable -l 50/min -b 100 -t 192.168.1.100 -p 22,80,443,3389

  # 查看状态
  sudo $0 status

  # 查看最近100条日志
  sudo $0 logs -n 100

  # 统计信息
  sudo $0 stats

  # 显示连接最多的前20个IP
  sudo $0 top-ips -n 20

  # 分析可疑IP
  sudo $0 analyze

  # 添加可信IP
  sudo $0 add-whitelist-ip 1.2.3.4

  # 禁用防护
  sudo $0 disable

${YELLOW}工作原理：${NC}

  1. 在 INPUT 链最前面添加全局防护规则
  2. 白名单IP直接放行（不受限制）
  3. 白名单端口直接放行
  4. 其他新连接应用速率限制
  5. 超过限制的连接被记录并拒绝
  6. 日志自动滚动保存

${YELLOW}注意事项：${NC}

  ⚠️  启用前请确保已添加你的IP到白名单
  ⚠️  建议先启用日志模式测试，确认无误后再启用
  ⚠️  配置logrotate自动清理日志文件

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "需要root权限"
        echo "请使用: sudo $0 $*"
        exit 1
    fi
}

# 检查链是否存在
chain_exists() {
    iptables -L "$GLOBAL_CHAIN" >/dev/null 2>&1
}

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# 保存配置
save_config() {
    cat > "$CONFIG_FILE" << EOF
# 全端口防护配置文件
# 自动生成于 $(date)

LIMIT="${LIMIT:-$DEFAULT_LIMIT}"
BURST="${BURST:-$DEFAULT_BURST}"
WHITELIST_PORTS="${WHITELIST_PORTS:-$DEFAULT_WHITELIST_PORTS}"
WHITELIST_IPS="${WHITELIST_IPS:-}"
LOG_ALL="${LOG_ALL:-false}"
EOF
    chmod 600 "$CONFIG_FILE"
    log_success "配置已保存到 $CONFIG_FILE"
}

# 启用全端口防护
enable_protection() {
    local limit="${LIMIT:-$DEFAULT_LIMIT}"
    local burst="${BURST:-$DEFAULT_BURST}"
    local whitelist_ports="${WHITELIST_PORTS:-$DEFAULT_WHITELIST_PORTS}"
    local whitelist_ips="${WHITELIST_IPS:-}"
    local log_all="${LOG_ALL:-false}"

    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--limit)
                limit="$2"
                shift 2
                ;;
            -b|--burst)
                burst="$2"
                shift 2
                ;;
            -t|--trust)
                if [ -n "$whitelist_ips" ]; then
                    whitelist_ips="$whitelist_ips,$2"
                else
                    whitelist_ips="$2"
                fi
                shift 2
                ;;
            -p|--ports)
                whitelist_ports="$2"
                shift 2
                ;;
            --log-all)
                log_all=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    # 保存配置
    LIMIT="$limit"
    BURST="$burst"
    WHITELIST_PORTS="$whitelist_ports"
    WHITELIST_IPS="$whitelist_ips"
    LOG_ALL="$log_all"
    save_config

    log_info "========================================"
    log_info "启用全端口防护"
    log_info "========================================"
    echo

    # 创建链
    if ! chain_exists; then
        if ! iptables -N "$GLOBAL_CHAIN" 2>/dev/null; then
            log_error "无法创建链 $GLOBAL_CHAIN"
            exit 1
        fi
        log_success "创建防护链: $GLOBAL_CHAIN"
    else
        # 清空现有规则
        iptables -F "$GLOBAL_CHAIN"
        log_info "清空现有规则"
    fi

    # 1. 添加可信IP规则（最高优先级）
    if [ -n "$whitelist_ips" ]; then
        IFS=',' read -ra IPS <<< "$whitelist_ips"
        for ip in "${IPS[@]}"; do
            ip=$(echo "$ip" | xargs)  # 去除空格
            if [ -n "$ip" ]; then
                iptables -A "$GLOBAL_CHAIN" -s "$ip" -j ACCEPT
                log_success "添加可信IP: $ip"
            fi
        done
    fi

    # 2. 添加白名单端口规则
    if [ -n "$whitelist_ports" ]; then
        IFS=',' read -ra PORTS <<< "$whitelist_ports"
        for port in "${PORTS[@]}"; do
            port=$(echo "$port" | xargs)
            if [ -n "$port" ]; then
                iptables -A "$GLOBAL_CHAIN" -p tcp --dport "$port" -j ACCEPT
                iptables -A "$GLOBAL_CHAIN" -p udp --dport "$port" -j ACCEPT
                log_success "添加白名单端口: $port"
            fi
        done
    fi

    # 3. 放行已建立的连接
    iptables -A "$GLOBAL_CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    log_success "允许已建立的连接"

    # 4. 速率限制（仅针对新连接）
    iptables -A "$GLOBAL_CHAIN" -m conntrack --ctstate NEW \
             -m limit --limit "$limit" --limit-burst "$burst" -j ACCEPT
    log_success "添加速率限制: $limit (突发: $burst)"

    # 5. 记录被拒绝的连接
    iptables -A "$GLOBAL_CHAIN" -m conntrack --ctstate NEW \
             -m limit --limit 10/min --limit-burst 20 \
             -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
    log_success "启用日志记录（速率限制: 10/min）"

    # 6. 拒绝其他连接
    iptables -A "$GLOBAL_CHAIN" -j DROP
    log_success "拒绝超过限制的连接"

    # 7. 挂载到INPUT链
    if iptables -C INPUT -j "$GLOBAL_CHAIN" 2>/dev/null; then
        log_info "INPUT链中已存在引用"
    else
        # 在INPUT链最前面插入
        iptables -I INPUT 1 -j "$GLOBAL_CHAIN"
        log_success "将规则添加到INPUT链（最高优先级）"
    fi

    # 创建日志文件
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    echo
    log_success "========================================"
    log_success "全端口防护已启用！"
    log_success "========================================"
    echo
    echo "配置信息："
    echo "  - 速率限制: $limit (突发: $burst)"
    echo "  - 白名单端口: $whitelist_ports"
    [ -n "$whitelist_ips" ] && echo "  - 可信IP: $whitelist_ips"
    echo "  - 日志文件: $LOG_FILE"
    echo
    echo "建议："
    echo "  1. 配置日志轮转: sudo cp ../config/port-protect.logrotate /etc/logrotate.d/global-port-protect"
    echo "  2. 查看日志: sudo $0 logs"
    echo "  3. 统计分析: sudo $0 stats"
    echo "  4. 保存规则: sudo iptables-save > /etc/iptables/rules.v4"
}

# 禁用全端口防护
disable_protection() {
    log_info "禁用全端口防护..."

    # 从INPUT链移除引用
    while iptables -C INPUT -j "$GLOBAL_CHAIN" 2>/dev/null; do
        iptables -D INPUT -j "$GLOBAL_CHAIN"
    done

    # 删除链
    if chain_exists; then
        iptables -F "$GLOBAL_CHAIN"
        iptables -X "$GLOBAL_CHAIN"
        log_success "已删除防护链"
    fi

    log_success "全端口防护已禁用"
}

# 查看状态
show_status() {
    echo -e "${BLUE}全端口防护状态${NC}"
    echo "========================================"

    if chain_exists; then
        echo -e "${GREEN}✓${NC} 防护已启用"
        echo

        # 加载配置
        load_config

        echo "配置信息："
        [ -n "${LIMIT:-}" ] && echo "  - 速率限制: ${LIMIT}"
        [ -n "${BURST:-}" ] && echo "  - 突发限制: ${BURST}"
        [ -n "${WHITELIST_PORTS:-}" ] && echo "  - 白名单端口: ${WHITELIST_PORTS}"
        [ -n "${WHITELIST_IPS:-}" ] && echo "  - 可信IP: ${WHITELIST_IPS}"
        echo

        echo "规则详情："
        iptables -L "$GLOBAL_CHAIN" -n -v --line-numbers

        echo
        echo "INPUT链引用："
        iptables -S INPUT | grep "$GLOBAL_CHAIN" || echo "  未找到引用"

        echo
        echo "统计信息："
        local total_drops=$(iptables -L "$GLOBAL_CHAIN" -v -n | grep DROP | awk '{sum+=$1} END {print sum+0}')
        local total_accepts=$(iptables -L "$GLOBAL_CHAIN" -v -n | grep ACCEPT | awk '{sum+=$1} END {print sum+0}')
        echo "  - 已拒绝: $total_drops 个包"
        echo "  - 已接受: $total_accepts 个包"

        if [ -f "$LOG_FILE" ]; then
            local log_lines=$(wc -l < "$LOG_FILE")
            local log_size=$(du -h "$LOG_FILE" | awk '{print $1}')
            echo "  - 日志条目: $log_lines 条"
            echo "  - 日志大小: $log_size"
        fi
    else
        echo -e "${RED}✗${NC} 防护未启用"
        echo
        echo "使用以下命令启用："
        echo "  sudo $0 enable"
    fi

    echo "========================================"
}

# 查看日志
view_logs() {
    local lines=100

    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--lines)
                lines="$2"
                shift 2
                ;;
            -f|--follow)
                tail -f "$LOG_FILE"
                return
                ;;
            *)
                shift
                ;;
        esac
    done

    if [ -f "$LOG_FILE" ]; then
        echo "最近 $lines 条日志："
        echo "========================================"
        tail -n "$lines" "$LOG_FILE" | grep "$LOG_PREFIX" || dmesg | grep "$LOG_PREFIX" | tail -n "$lines"
    else
        log_warn "日志文件不存在: $LOG_FILE"
        echo "尝试从系统日志读取："
        dmesg | grep "$LOG_PREFIX" | tail -n "$lines"
    fi
}

# 统计信息
show_stats() {
    echo "连接统计信息"
    echo "========================================"

    if [ -f "$LOG_FILE" ]; then
        local total=$(grep -c "$LOG_PREFIX" "$LOG_FILE" || echo "0")
        echo "总拒绝连接数: $total"
        echo
    else
        echo "从系统日志读取..."
        local total=$(dmesg | grep -c "$LOG_PREFIX" || echo "0")
        echo "总拒绝连接数: $total"
        echo
    fi

    echo "按端口统计（Top 10）："
    echo "----------------------------------------"
    if [ -f "$LOG_FILE" ]; then
        grep "$LOG_PREFIX" "$LOG_FILE" | grep -oP 'DPT=\K[0-9]+' | sort | uniq -c | sort -rn | head -10 | \
            awk '{printf "  端口 %-6s : %s 次\n", $2, $1}'
    else
        dmesg | grep "$LOG_PREFIX" | grep -oP 'DPT=\K[0-9]+' | sort | uniq -c | sort -rn | head -10 | \
            awk '{printf "  端口 %-6s : %s 次\n", $2, $1}'
    fi

    echo
    echo "按协议统计："
    echo "----------------------------------------"
    if [ -f "$LOG_FILE" ]; then
        grep "$LOG_PREFIX" "$LOG_FILE" | grep -oP 'PROTO=\K[A-Z]+' | sort | uniq -c | sort -rn | \
            awk '{printf "  %-6s : %s 次\n", $2, $1}'
    else
        dmesg | grep "$LOG_PREFIX" | grep -oP 'PROTO=\K[A-Z]+' | sort | uniq -c | sort -rn | \
            awk '{printf "  %-6s : %s 次\n", $2, $1}'
    fi
}

# 显示连接最多的IP
show_top_ips() {
    local count=20

    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--count)
                count="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    echo "连接最多的 IP (Top $count)"
    echo "========================================"

    if [ -f "$LOG_FILE" ]; then
        grep "$LOG_PREFIX" "$LOG_FILE" | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn | head -n "$count" | \
            awk '{printf "  %-15s : %s 次\n", $2, $1}'
    else
        dmesg | grep "$LOG_PREFIX" | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn | head -n "$count" | \
            awk '{printf "  %-15s : %s 次\n", $2, $1}'
    fi
}

# 分析可疑IP
analyze_suspicious() {
    local threshold=50  # 超过50次连接视为可疑

    echo "可疑IP分析（阈值: $threshold 次）"
    echo "========================================"

    local suspicious_ips
    if [ -f "$LOG_FILE" ]; then
        suspicious_ips=$(grep "$LOG_PREFIX" "$LOG_FILE" | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn | \
            awk -v threshold="$threshold" '$1 > threshold {print $2, $1}')
    else
        suspicious_ips=$(dmesg | grep "$LOG_PREFIX" | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn | \
            awk -v threshold="$threshold" '$1 > threshold {print $2, $1}')
    fi

    if [ -z "$suspicious_ips" ]; then
        log_success "未发现可疑IP"
        return
    fi

    echo "发现以下可疑IP："
    echo
    echo "$suspicious_ips" | awk '{printf "  %-15s : %s 次\n", $1, $2}'
    echo
    echo "========================================"
    echo "建议操作："
    echo

    echo "$suspicious_ips" | while read ip count; do
        echo "  # 封禁 $ip (连接 $count 次)"
        echo "  sudo $SCRIPT_DIR/blacklist-manager.sh ban $ip --reason \"High connection rate: $count\" --duration 7d"
        echo
    done

    echo "或者批量封禁："
    echo "  echo '$suspicious_ips' | while read ip count; do"
    echo "    sudo $SCRIPT_DIR/blacklist-manager.sh ban \$ip --reason \"High connection rate: \$count\" --duration 7d"
    echo "  done"
}

# 添加可信IP
add_whitelist_ip() {
    local ip="$1"
    load_config

    if [[ "$WHITELIST_IPS" == *"$ip"* ]]; then
        log_warn "IP $ip 已在白名单中"
        return
    fi

    if [ -n "$WHITELIST_IPS" ]; then
        WHITELIST_IPS="$WHITELIST_IPS,$ip"
    else
        WHITELIST_IPS="$ip"
    fi

    save_config

    if chain_exists; then
        # 在链的最前面添加规则
        iptables -I "$GLOBAL_CHAIN" 1 -s "$ip" -j ACCEPT
        log_success "已添加可信IP: $ip（立即生效）"
    else
        log_success "已添加可信IP: $ip（启用防护后生效）"
    fi
}

# 移除可信IP
remove_whitelist_ip() {
    local ip="$1"
    load_config

    if [[ "$WHITELIST_IPS" != *"$ip"* ]]; then
        log_warn "IP $ip 不在白名单中"
        return
    fi

    WHITELIST_IPS=$(echo "$WHITELIST_IPS" | sed "s/$ip,\?//g" | sed 's/,$//')
    save_config

    if chain_exists; then
        while iptables -D "$GLOBAL_CHAIN" -s "$ip" -j ACCEPT 2>/dev/null; do
            :
        done
        log_success "已移除可信IP: $ip"
    else
        log_success "已从配置移除IP: $ip"
    fi
}

# 列出可信IP
list_whitelist_ips() {
    load_config
    echo "可信IP列表："
    echo "========================================"
    if [ -n "${WHITELIST_IPS:-}" ]; then
        echo "$WHITELIST_IPS" | tr ',' '\n' | awk '{printf "  - %s\n", $1}'
    else
        echo "  (空)"
    fi
}

# 添加白名单端口
add_whitelist_port() {
    local port="$1"
    load_config

    if [[ "$WHITELIST_PORTS" == *"$port"* ]]; then
        log_warn "端口 $port 已在白名单中"
        return
    fi

    if [ -n "$WHITELIST_PORTS" ]; then
        WHITELIST_PORTS="$WHITELIST_PORTS,$port"
    else
        WHITELIST_PORTS="$port"
    fi

    save_config
    log_success "已添加白名单端口: $port（需要重新启用防护生效）"
}

# 移除白名单端口
remove_whitelist_port() {
    local port="$1"
    load_config

    WHITELIST_PORTS=$(echo "$WHITELIST_PORTS" | sed "s/$port,\?//g" | sed 's/,$//')
    save_config
    log_success "已移除白名单端口: $port（需要重新启用防护生效）"
}

# 列出白名单端口
list_whitelist_ports() {
    load_config
    echo "白名单端口列表："
    echo "========================================"
    if [ -n "${WHITELIST_PORTS:-}" ]; then
        echo "$WHITELIST_PORTS" | tr ',' '\n' | awk '{printf "  - %s\n", $1}'
    else
        echo "  (空)"
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        enable)
            check_root "$@"
            shift
            enable_protection "$@"
            ;;
        disable)
            check_root "$@"
            disable_protection
            ;;
        status)
            show_status
            ;;
        logs)
            shift
            view_logs "$@"
            ;;
        stats)
            show_stats
            ;;
        top-ips)
            shift
            show_top_ips "$@"
            ;;
        analyze)
            analyze_suspicious
            ;;
        add-whitelist-ip)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定IP"
                exit 1
            fi
            add_whitelist_ip "$2"
            ;;
        remove-whitelist-ip)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定IP"
                exit 1
            fi
            remove_whitelist_ip "$2"
            ;;
        list-whitelist-ips)
            list_whitelist_ips
            ;;
        add-whitelist-port)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定端口"
                exit 1
            fi
            add_whitelist_port "$2"
            ;;
        remove-whitelist-port)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定端口"
                exit 1
            fi
            remove_whitelist_port "$2"
            ;;
        list-whitelist-ports)
            list_whitelist_ports
            ;;
        set-limit)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定速率限制"
                exit 1
            fi
            load_config
            LIMIT="$2"
            save_config
            log_success "速率限制已更新为: $2（需要重新启用防护生效）"
            ;;
        set-burst)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定突发限制"
                exit 1
            fi
            load_config
            BURST="$2"
            save_config
            log_success "突发限制已更新为: $2（需要重新启用防护生效）"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

main "$@"
