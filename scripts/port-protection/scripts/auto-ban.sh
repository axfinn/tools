#!/bin/bash

# 自动封禁监控脚本
# 监控系统日志，自动封禁频繁触发防护规则的IP
# 支持：配置化阈值、白名单保护、滚动日志记录

set -e

# 配置文件
CONFIG_FILE="/etc/port-protect-autoban.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLACKLIST_MANAGER="$SCRIPT_DIR/blacklist-manager.sh"
PID_FILE="/var/run/port-protect-autoban.pid"
MONITOR_LOG="/var/log/port-protect-autoban.log"

# 默认配置
MONITOR_ENABLED=true
LOG_FILE="/var/log/syslog"
BAN_THRESHOLD=10
TIME_WINDOW=600          # 10分钟
BAN_DURATION=2592000     # 30天
AUTO_BAN_ENABLED=true

# 白名单（默认保护本地网络）
declare -a WHITELIST=(
    "127.0.0.1"
    "::1"
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 临时文件用于统计
declare -A ip_counter
declare -A ip_first_seen

# 日志函数
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "$MONITOR_LOG"
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$MONITOR_LOG"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$MONITOR_LOG"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$MONITOR_LOG"
}

# 显示帮助信息
show_help() {
    echo "自动封禁监控脚本"
    echo "使用方式: $0 [命令]"
    echo
    echo "命令:"
    echo "  start            启动监控服务（后台运行）"
    echo "  stop             停止监控服务"
    echo "  status           查看监控状态"
    echo "  test             测试模式（前台运行，不封禁）"
    echo "  init             初始化配置文件"
    echo "  reload           重新加载配置"
    echo
    echo "配置文件: $CONFIG_FILE"
    echo "监控日志: $MONITOR_LOG"
    echo
    echo "示例:"
    echo "  $0 init          # 创建配置文件"
    echo "  $0 start         # 启动监控"
    echo "  $0 status        # 查看状态"
    echo "  $0 stop          # 停止监控"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    if [ ! -f "$BLACKLIST_MANAGER" ]; then
        log_error "找不到黑名单管理脚本: $BLACKLIST_MANAGER"
        exit 1
    fi

    if [ ! -x "$BLACKLIST_MANAGER" ]; then
        chmod +x "$BLACKLIST_MANAGER"
    fi

    # 检查黑名单系统是否初始化
    if ! "$BLACKLIST_MANAGER" status >/dev/null 2>&1; then
        log_warn "黑名单系统未初始化，正在初始化..."
        "$BLACKLIST_MANAGER" init
    fi
}

# 创建默认配置文件
create_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Port Protection 自动封禁配置文件

# ===== 监控配置 =====
MONITOR_ENABLED=true
LOG_FILE="/var/log/syslog"

# ===== 封禁阈值 =====
# 触发次数：在时间窗口内触发多少次后封禁
BAN_THRESHOLD=10

# 时间窗口（秒）：统计时间范围
TIME_WINDOW=600

# 封禁时长（秒）：0表示永久封禁
BAN_DURATION=2592000

# 自动封禁开关
AUTO_BAN_ENABLED=true

# ===== 白名单配置 =====
# 白名单IP不会被自动封禁
# 支持单个IP或CIDR网段
# 格式：一行一个IP/网段
WHITELIST=(
    "127.0.0.1"
    "::1"
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
    # 添加你的可信IP
    # "1.2.3.4"
    # "5.6.7.0/24"
)

# ===== 通知配置 =====
# 邮件通知（未实现）
NOTIFY_EMAIL=""

# Webhook通知（未实现）
NOTIFY_WEBHOOK=""

# ===== 日志配置 =====
MONITOR_LOG="/var/log/port-protect-autoban.log"

# 日志保留天数
LOG_RETENTION_DAYS=30
EOF

    chmod 600 "$CONFIG_FILE"
    log_success "已创建配置文件: $CONFIG_FILE"
    echo
    echo "请编辑配置文件，添加你的可信IP到白名单"
    echo "编辑命令: nano $CONFIG_FILE"
}

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log_info "已加载配置文件: $CONFIG_FILE"
    else
        log_warn "配置文件不存在，使用默认配置"
    fi
}

# 检查IP是否在白名单中
is_whitelisted() {
    local ip="$1"

    for whitelist_ip in "${WHITELIST[@]}"; do
        # 处理CIDR网段
        if [[ "$whitelist_ip" == *"/"* ]]; then
            # 使用ipcalc或简单的字符串匹配
            if echo "$ip" | grep -q "^${whitelist_ip%/*}"; then
                return 0
            fi
        else
            # 精确匹配
            if [ "$ip" = "$whitelist_ip" ]; then
                return 0
            fi
        fi
    done

    return 1
}

# 处理检测到的IP
process_ip() {
    local ip="$1"
    local port="$2"
    local current_time=$(date +%s)

    # 检查白名单
    if is_whitelisted "$ip"; then
        return 0
    fi

    # 初始化计数器
    if [ -z "${ip_counter[$ip]}" ]; then
        ip_counter[$ip]=0
        ip_first_seen[$ip]=$current_time
    fi

    # 增加计数
    ((ip_counter[$ip]++))

    # 检查时间窗口
    local time_diff=$((current_time - ${ip_first_seen[$ip]}))

    if [ $time_diff -gt $TIME_WINDOW ]; then
        # 超出时间窗口，重置计数
        ip_counter[$ip]=1
        ip_first_seen[$ip]=$current_time
    elif [ ${ip_counter[$ip]} -ge $BAN_THRESHOLD ]; then
        # 达到阈值，封禁IP
        ban_ip "$ip" "$port" ${ip_counter[$ip]}

        # 重置计数
        unset ip_counter[$ip]
        unset ip_first_seen[$ip]
    fi
}

# 封禁IP
ban_ip() {
    local ip="$1"
    local port="$2"
    local count="$3"
    local reason="端口${port}触发${count}次防护规则"

    log_warn "检测到异常IP: $ip ($reason)"

    if [ "$AUTO_BAN_ENABLED" != "true" ]; then
        log_info "自动封禁已禁用，跳过封禁"
        return 0
    fi

    # 调用黑名单管理器封禁IP
    if "$BLACKLIST_MANAGER" ban "$ip" "$reason" "$BAN_DURATION" >/dev/null 2>&1; then
        log_success "已封禁IP: $ip"

        # 记录详细信息到监控日志
        local expire_date=$(date -d "@$(($(date +%s) + BAN_DURATION))" "+%Y-%m-%d %H:%M:%S")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BANNED: IP=$ip PORT=$port COUNT=$count EXPIRE=$expire_date" >> "$MONITOR_LOG"
    else
        log_error "封禁IP失败: $ip"
    fi
}

# 监控日志文件
monitor_logs() {
    log_info "开始监控系统日志: $LOG_FILE"
    log_info "封禁阈值: $BAN_THRESHOLD 次 / $TIME_WINDOW 秒"
    log_info "封禁时长: $BAN_DURATION 秒 ($(($BAN_DURATION / 86400)) 天)"
    log_info "白名单数量: ${#WHITELIST[@]}"

    # 检查日志文件是否存在
    if [ ! -f "$LOG_FILE" ]; then
        log_error "日志文件不存在: $LOG_FILE"
        exit 1
    fi

    # 使用tail -f监控日志
    tail -f "$LOG_FILE" | while read -r line; do
        # 检测 PORT-PROTECT-DROP 日志
        if echo "$line" | grep -q "PORT-PROTECT-DROP-"; then
            # 提取IP地址和端口
            local ip=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
            local port=$(echo "$line" | grep -oP 'PORT-PROTECT-DROP-\K[0-9]+')

            if [ -n "$ip" ] && [ -n "$port" ]; then
                process_ip "$ip" "$port"
            fi
        fi
    done
}

# 测试模式
test_mode() {
    log_info "进入测试模式（不会实际封禁IP）"
    AUTO_BAN_ENABLED=false
    monitor_logs
}

# 启动监控服务
start_service() {
    # 检查是否已运行
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "监控服务已在运行 (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi

    log_info "启动监控服务..."

    # 后台运行
    nohup "$0" _monitor > /dev/null 2>&1 &
    local pid=$!

    echo $pid > "$PID_FILE"
    log_success "监控服务已启动 (PID: $pid)"

    echo
    echo "查看日志: tail -f $MONITOR_LOG"
    echo "查看状态: $0 status"
    echo "停止服务: $0 stop"
}

# 停止监控服务
stop_service() {
    if [ ! -f "$PID_FILE" ]; then
        log_warn "监控服务未运行"
        return 0
    fi

    local pid=$(cat "$PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
        log_info "停止监控服务 (PID: $pid)..."
        kill "$pid"
        rm -f "$PID_FILE"
        log_success "监控服务已停止"
    else
        log_warn "进程不存在，清理PID文件"
        rm -f "$PID_FILE"
    fi
}

# 查看服务状态
show_status() {
    echo -e "${BLUE}自动封禁监控状态:${NC}"
    echo "========================================"

    # 检查服务状态
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓ 服务状态: 运行中${NC}"
            echo "  - PID: $pid"
            echo "  - 运行时长: $(ps -p $pid -o etime= | xargs)"
        else
            echo -e "${RED}✗ 服务状态: 已停止（PID文件过期）${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}✗ 服务状态: 未运行${NC}"
    fi

    echo

    # 配置信息
    echo "配置信息:"
    echo "  - 配置文件: $CONFIG_FILE"
    echo "  - 日志文件: $MONITOR_LOG"
    echo "  - 系统日志: $LOG_FILE"
    echo "  - 封禁阈值: $BAN_THRESHOLD 次 / $TIME_WINDOW 秒"
    echo "  - 封禁时长: $BAN_DURATION 秒 ($(($BAN_DURATION / 86400)) 天)"
    echo "  - 自动封禁: $([ "$AUTO_BAN_ENABLED" = "true" ] && echo "启用" || echo "禁用")"

    echo

    # 最近的封禁记录
    echo "最近封禁记录 (最近5条):"
    echo "----------------------------------------"
    if [ -f "$MONITOR_LOG" ]; then
        grep "BANNED:" "$MONITOR_LOG" | tail -5 | while read -r line; do
            echo "  $line"
        done
    else
        echo "  暂无记录"
    fi

    echo "========================================"

    # 黑名单状态
    echo
    "$BLACKLIST_MANAGER" status
}

# 内部监控函数（由start_service调用）
internal_monitor() {
    load_config
    check_dependencies

    # 初始化监控日志
    if [ ! -f "$MONITOR_LOG" ]; then
        touch "$MONITOR_LOG"
        chmod 600 "$MONITOR_LOG"
    fi

    monitor_logs
}

# 主函数
main() {
    check_root
    load_config

    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=$1
    shift

    case "$command" in
        start)
            check_dependencies
            start_service
            ;;
        stop)
            stop_service
            ;;
        status)
            show_status
            ;;
        test)
            check_dependencies
            test_mode
            ;;
        init)
            create_config
            ;;
        reload)
            log_info "重新加载配置..."
            load_config
            log_success "配置已重新加载"
            ;;
        _monitor)
            # 内部命令，由start调用
            internal_monitor
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
