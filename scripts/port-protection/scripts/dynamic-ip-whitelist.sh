#!/bin/bash

# 动态IP白名单管理脚本
# 用途：为动态IP用户提供自助白名单更新功能
# 解决：用户IP不固定，需要动态更新白名单的问题

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLACKLIST_MANAGER="$SCRIPT_DIR/blacklist-manager.sh"

# 配置文件
CONFIG_DIR="/etc/port-protect"
WHITELIST_FILE="$CONFIG_DIR/dynamic-whitelist.conf"
AUTH_TOKEN_FILE="$CONFIG_DIR/auth-tokens.conf"
IPSET_WHITELIST="port-protect-whitelist"
LOG_FILE="/var/log/port-protect-dynamic-whitelist.log"

# 认证令牌过期时间（秒）
TOKEN_EXPIRE_TIME=2592000  # 30天

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# 显示帮助
show_help() {
    cat << EOF
${BLUE}动态IP白名单管理${NC} - v${VERSION}

${YELLOW}用途：${NC}
  解决动态IP用户无法固定加入白名单的问题
  提供三种方案供选择

${YELLOW}使用方式：${NC} $0 [命令] [参数]

${YELLOW}命令：${NC}
  init                     初始化动态白名单系统
  add-current              将当前IP添加到白名单
  add <IP>                 将指定IP添加到白名单
  remove <IP>              从白名单移除IP
  list                     列出所有白名单IP
  cleanup                  清理过期的白名单条目
  status                   查看白名单系统状态

  generate-token           生成认证令牌（用于远程更新）
  update-with-token <令牌> 使用令牌更新白名单

  auto-update             启用自动更新（客户端模式）

${YELLOW}三种解决方案：${NC}

${CYAN}方案1: 手动更新（最简单）${NC}
  每次IP变化后，SSH登录服务器运行：
  sudo $0 add-current

${CYAN}方案2: 认证令牌（推荐）${NC}
  1. 服务器生成令牌：sudo $0 generate-token
  2. 客户端使用令牌：curl "https://your-server/update-whitelist?token=XXX"
  （需要配置Web服务器）

${CYAN}方案3: 端口敲门（最安全）${NC}
  使用特定序列访问端口来临时开放白名单
  （需要安装 knockd）

${YELLOW}示例：${NC}
  # 初始化系统
  sudo $0 init

  # 添加当前IP到白名单
  sudo $0 add-current

  # 生成认证令牌
  sudo $0 generate-token

  # 查看白名单
  sudo $0 list

${YELLOW}快速解决方案：${NC}
  如果你现在被锁定，无法访问：

  1. 通过其他方式登录服务器（如VNC、控制台）
  2. 运行：sudo $0 add <你的IP>
  3. 或者：sudo ./blacklist-manager.sh unban <你的IP>
EOF
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "此命令需要root权限"
        echo "请使用: sudo $0 $*"
        exit 1
    fi
}

# 初始化系统
init_system() {
    log_info "初始化动态白名单系统..."

    # 创建配置目录
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        chmod 700 "$CONFIG_DIR"
    fi

    # 创建白名单文件
    if [ ! -f "$WHITELIST_FILE" ]; then
        cat > "$WHITELIST_FILE" << 'EOF'
# 动态白名单配置
# 格式：IP地址 添加时间 过期时间 描述
# 示例：1.2.3.4 2025-01-01T10:00:00 2025-02-01T10:00:00 我的家庭IP
EOF
        chmod 600 "$WHITELIST_FILE"
    fi

    # 创建令牌文件
    if [ ! -f "$AUTH_TOKEN_FILE" ]; then
        touch "$AUTH_TOKEN_FILE"
        chmod 600 "$AUTH_TOKEN_FILE"
    fi

    # 创建ipset白名单集合
    if ! ipset list "$IPSET_WHITELIST" >/dev/null 2>&1; then
        ipset create "$IPSET_WHITELIST" hash:ip timeout 0
        log_success "创建白名单 ipset: $IPSET_WHITELIST"
    fi

    # 添加iptables规则（在黑名单规则之前）
    if ! iptables -C INPUT -m set --match-set "$IPSET_WHITELIST" src -j ACCEPT 2>/dev/null; then
        iptables -I INPUT 1 -m set --match-set "$IPSET_WHITELIST" src -j ACCEPT
        log_success "添加白名单 iptables 规则"
    fi

    # 创建日志文件
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    log_success "动态白名单系统初始化完成"
    echo
    echo -e "${CYAN}下一步：${NC}"
    echo "  1. 添加当前IP: sudo $0 add-current"
    echo "  2. 查看状态: sudo $0 status"
    echo "  3. 生成令牌: sudo $0 generate-token（用于远程更新）"
}

# 获取当前IP
get_current_ip() {
    # 尝试多种方法获取公网IP
    local ip=""

    # 方法1: 从SSH连接获取
    if [ -n "${SSH_CLIENT:-}" ]; then
        ip=$(echo "$SSH_CLIENT" | awk '{print $1}')
    # 方法2: 从SSH连接获取（另一个变量）
    elif [ -n "${SSH_CONNECTION:-}" ]; then
        ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    fi

    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi

    return 1
}

# 添加IP到白名单
add_to_whitelist() {
    local ip="$1"
    local description="${2:-动态IP}"
    local expire_days="${3:-30}"

    # 验证IP格式
    if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        log_error "无效的IP地址格式: $ip"
        return 1
    fi

    # 检查是否已在白名单中
    if ipset test "$IPSET_WHITELIST" "$ip" 2>/dev/null; then
        log_warn "IP $ip 已在白名单中"
        # 更新记录
        sed -i "/^$ip /d" "$WHITELIST_FILE"
    fi

    # 添加到ipset
    ipset add "$IPSET_WHITELIST" "$ip" 2>/dev/null || true

    # 记录到文件
    local add_time=$(date '+%Y-%m-%dT%H:%M:%S')
    local expire_time=$(date -d "+${expire_days} days" '+%Y-%m-%dT%H:%M:%S')
    echo "$ip $add_time $expire_time $description" >> "$WHITELIST_FILE"

    # 如果IP在黑名单中，解除封禁
    if [ -x "$BLACKLIST_MANAGER" ]; then
        "$BLACKLIST_MANAGER" unban "$ip" 2>/dev/null || true
    fi

    log_success "已将 $ip 添加到白名单"
    echo "  描述: $description"
    echo "  过期时间: $expire_time (${expire_days}天后)"

    return 0
}

# 添加当前IP
add_current_ip() {
    local current_ip
    if current_ip=$(get_current_ip); then
        log_info "检测到当前IP: $current_ip"
        add_to_whitelist "$current_ip" "当前SSH连接IP" 30
    else
        log_error "无法自动检测当前IP"
        echo
        echo "请手动指定IP:"
        echo "  sudo $0 add <你的IP地址>"
        echo
        echo "获取你的公网IP的方法:"
        echo "  curl ifconfig.me"
        echo "  curl ip.sb"
        return 1
    fi
}

# 从白名单移除IP
remove_from_whitelist() {
    local ip="$1"

    # 从ipset移除
    if ipset test "$IPSET_WHITELIST" "$ip" 2>/dev/null; then
        ipset del "$IPSET_WHITELIST" "$ip"
        log_success "已从白名单移除: $ip"
    else
        log_warn "IP $ip 不在白名单中"
    fi

    # 从文件移除
    sed -i "/^$ip /d" "$WHITELIST_FILE"
}

# 列出白名单
list_whitelist() {
    echo -e "${BLUE}当前白名单:${NC}"
    echo "========================================"

    if [ ! -f "$WHITELIST_FILE" ] || [ ! -s "$WHITELIST_FILE" ]; then
        echo "白名单为空"
        return 0
    fi

    echo "IP地址            添加时间            过期时间            描述"
    echo "--------------------------------------------------------------------------------"

    grep -v "^#" "$WHITELIST_FILE" | while read -r ip add_time expire_time description; do
        printf "%-16s %-19s %-19s %s\n" "$ip" "$add_time" "$expire_time" "$description"
    done

    echo "========================================"
    local count=$(grep -v "^#" "$WHITELIST_FILE" | wc -l)
    echo "总计: $count 个IP"
}

# 清理过期条目
cleanup_expired() {
    log_info "清理过期的白名单条目..."

    local now=$(date '+%Y-%m-%dT%H:%M:%S')
    local removed=0

    while read -r ip add_time expire_time description; do
        if [[ "$expire_time" < "$now" ]]; then
            remove_from_whitelist "$ip"
            log_info "移除过期IP: $ip (过期时间: $expire_time)"
            ((removed++))
        fi
    done < <(grep -v "^#" "$WHITELIST_FILE" || true)

    if [ "$removed" -eq 0 ]; then
        log_info "没有过期的条目"
    else
        log_success "已移除 $removed 个过期条目"
    fi
}

# 生成认证令牌
generate_token() {
    local token=$(openssl rand -hex 32)
    local created=$(date '+%Y-%m-%dT%H:%M:%S')
    local expires=$(date -d "+30 days" '+%Y-%m-%dT%H:%M:%S')

    echo "$token $created $expires active" >> "$AUTH_TOKEN_FILE"

    echo -e "${GREEN}认证令牌已生成${NC}"
    echo "========================================"
    echo "令牌: $token"
    echo "创建时间: $created"
    echo "过期时间: $expires"
    echo "========================================"
    echo
    echo -e "${CYAN}使用方法（客户端）：${NC}"
    echo
    echo "方法1: 使用curl更新白名单"
    echo "  curl -X POST \"http://你的服务器IP:8080/update-whitelist?token=$token\""
    echo
    echo "方法2: 创建定时任务自动更新"
    echo "  crontab -e"
    echo "  添加: */30 * * * * curl -X POST \"http://你的服务器IP:8080/update-whitelist?token=$token\""
    echo
    echo -e "${YELLOW}注意：需要先设置Web服务器来接收请求${NC}"
}

# 查看状态
show_status() {
    echo -e "${BLUE}动态白名单系统状态${NC}"
    echo "========================================"

    # ipset状态
    if ipset list "$IPSET_WHITELIST" >/dev/null 2>&1; then
        local count=$(ipset list "$IPSET_WHITELIST" | grep -cE '^[0-9]' || echo "0")
        echo -e "${GREEN}✓${NC} ipset白名单: $IPSET_WHITELIST (${count}个IP)"
    else
        echo -e "${RED}✗${NC} ipset白名单未创建"
    fi

    # iptables规则
    if iptables -C INPUT -m set --match-set "$IPSET_WHITELIST" src -j ACCEPT 2>/dev/null; then
        echo -e "${GREEN}✓${NC} iptables规则已配置"
    else
        echo -e "${RED}✗${NC} iptables规则未配置"
    fi

    # 配置文件
    if [ -f "$WHITELIST_FILE" ]; then
        local file_count=$(grep -v "^#" "$WHITELIST_FILE" | wc -l)
        echo -e "${GREEN}✓${NC} 配置文件: $WHITELIST_FILE (${file_count}条记录)"
    else
        echo -e "${YELLOW}⚠${NC} 配置文件不存在"
    fi

    # 当前IP
    local current_ip
    if current_ip=$(get_current_ip); then
        echo
        echo "当前连接IP: $current_ip"
        if ipset test "$IPSET_WHITELIST" "$current_ip" 2>/dev/null; then
            echo -e "状态: ${GREEN}✓ 已在白名单中${NC}"
        else
            echo -e "状态: ${YELLOW}⚠ 不在白名单中${NC}"
            echo
            echo "建议: sudo $0 add-current"
        fi
    fi

    echo "========================================"
}

# 主函数
main() {
    case "${1:-}" in
        help|--help|-h)
            show_help
            ;;
        init)
            check_root "$@"
            init_system
            ;;
        add-current)
            check_root "$@"
            add_current_ip
            ;;
        add)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定IP地址"
                echo "用法: sudo $0 add <IP地址> [描述]"
                exit 1
            fi
            add_to_whitelist "$2" "${3:-手动添加}"
            ;;
        remove)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定IP地址"
                echo "用法: sudo $0 remove <IP地址>"
                exit 1
            fi
            remove_from_whitelist "$2"
            ;;
        list)
            list_whitelist
            ;;
        cleanup)
            check_root "$@"
            cleanup_expired
            ;;
        status)
            show_status
            ;;
        generate-token)
            check_root "$@"
            if ! command -v openssl >/dev/null 2>&1; then
                log_error "需要安装 openssl"
                echo "运行: sudo apt-get install openssl"
                exit 1
            fi
            generate_token
            ;;
        "")
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
