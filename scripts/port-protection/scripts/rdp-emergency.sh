#!/bin/bash

# RDP紧急保护脚本
# 用途：立即保护RDP端口，防止恶意密码爆破
# 问题：频繁密码尝试导致账户被锁定，连自己都无法登录

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# RDP相关配置
DEFAULT_RDP_PORT=3389
IPSET_RDP_WHITELIST="rdp-whitelist"
IPSET_RDP_BLACKLIST="rdp-blacklist"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    cat << EOF
${RED}RDP紧急保护脚本${NC} - v${VERSION}

${YELLOW}紧急情况：${NC}
  RDP被恶意爆破，导致账户锁定，自己也无法登录！

${YELLOW}使用方式：${NC} $0 [命令] [参数]

${YELLOW}紧急命令（按顺序执行）：${NC}

  ${RED}1. emergency-lock${NC}        立即锁定RDP，阻止所有IP（包括攻击者）
  ${GREEN}2. add-my-ip${NC}            添加你的IP到白名单
  ${GREEN}3. unlock${NC}                解除紧急锁定，只允许白名单IP访问

${YELLOW}常规命令：${NC}

  quick-protect              快速保护（一键设置）
  add-whitelist <IP>         添加IP到白名单
  remove-whitelist <IP>      从白名单移除IP
  list-whitelist             查看白名单
  list-blacklist             查看黑名单
  change-port <新端口>       修改RDP端口（推荐）
  status                     查看保护状态

${YELLOW}紧急操作流程：${NC}

${RED}步骤1：立即停止攻击${NC}
  sudo $0 emergency-lock

${GREEN}步骤2：添加你的IP${NC}
  sudo $0 add-my-ip
  # 或手动指定：sudo $0 add-whitelist 你的IP

${GREEN}步骤3：解除锁定${NC}
  sudo $0 unlock

${CYAN}步骤4：修改RDP端口（强烈推荐）${NC}
  sudo $0 change-port 19099

${YELLOW}快速开始（如果还能SSH登录）：${NC}

  # 一键保护
  sudo $0 quick-protect

  # 这将自动：
  # 1. 创建白名单
  # 2. 添加当前IP
  # 3. 阻止其他所有IP访问RDP
  # 4. 建议修改RDP端口

${YELLOW}示例：${NC}

  # 紧急锁定RDP
  sudo $0 emergency-lock

  # 添加当前IP到白名单
  sudo $0 add-my-ip

  # 添加指定IP到白名单
  sudo $0 add-whitelist 1.2.3.4

  # 解除紧急锁定
  sudo $0 unlock

  # 查看状态
  sudo $0 status

${RED}重要提示：${NC}
  1. 执行 emergency-lock 后，所有RDP连接都会被阻断
  2. 必须先添加你的IP到白名单，再执行 unlock
  3. 强烈建议修改RDP默认端口（3389）
  4. 如果无法SSH，需要通过云服务商控制台操作

EOF
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 需要root权限${NC}" >&2
        echo "请使用: sudo $0 $*"
        exit 1
    fi
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

# 获取当前SSH连接的IP
get_current_ip() {
    local ip=""
    if [ -n "${SSH_CLIENT:-}" ]; then
        ip=$(echo "$SSH_CLIENT" | awk '{print $1}')
    elif [ -n "${SSH_CONNECTION:-}" ]; then
        ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    fi

    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return 0
    fi
    return 1
}

# 紧急锁定RDP
emergency_lock() {
    log_warn "========================================"
    log_warn "执行紧急锁定RDP"
    log_warn "========================================"
    echo
    log_warn "这将立即阻止所有IP访问RDP（包括你自己）"
    echo
    read -p "确认执行？(yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "已取消"
        return 0
    fi

    # 在最前面添加DROP规则，阻止所有到RDP端口的连接
    if ! iptables -C INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP 2>/dev/null; then
        iptables -I INPUT 1 -p tcp --dport $DEFAULT_RDP_PORT -j DROP
        log_success "已添加RDP紧急锁定规则"
    else
        log_info "RDP紧急锁定规则已存在"
    fi

    echo
    log_success "========================================"
    log_success "RDP已紧急锁定！"
    log_success "========================================"
    echo
    echo -e "${CYAN}下一步：${NC}"
    echo "  1. 添加你的IP到白名单: sudo $0 add-my-ip"
    echo "  2. 或手动指定IP: sudo $0 add-whitelist <你的IP>"
    echo "  3. 解除紧急锁定: sudo $0 unlock"
    echo
    log_warn "注意：在执行unlock之前，请确保已添加你的IP到白名单！"
}

# 创建白名单
init_whitelist() {
    # 创建白名单ipset
    if ! ipset list "$IPSET_RDP_WHITELIST" >/dev/null 2>&1; then
        ipset create "$IPSET_RDP_WHITELIST" hash:ip timeout 0
        log_success "创建RDP白名单: $IPSET_RDP_WHITELIST"
    fi

    # 添加白名单ACCEPT规则（需要在DROP规则之前）
    if ! iptables -C INPUT -p tcp --dport $DEFAULT_RDP_PORT -m set --match-set "$IPSET_RDP_WHITELIST" src -j ACCEPT 2>/dev/null; then
        # 找到DROP规则的位置，在它之前插入
        local drop_line=$(iptables -L INPUT -n --line-numbers | grep "tcp dpt:$DEFAULT_RDP_PORT" | grep "DROP" | head -1 | awk '{print $1}')
        if [ -n "$drop_line" ]; then
            iptables -I INPUT $drop_line -p tcp --dport $DEFAULT_RDP_PORT -m set --match-set "$IPSET_RDP_WHITELIST" src -j ACCEPT
        else
            iptables -I INPUT 1 -p tcp --dport $DEFAULT_RDP_PORT -m set --match-set "$IPSET_RDP_WHITELIST" src -j ACCEPT
        fi
        log_success "添加RDP白名单规则"
    fi
}

# 添加IP到白名单
add_to_whitelist() {
    local ip="$1"

    # 验证IP格式
    if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        log_error "无效的IP地址: $ip"
        return 1
    fi

    # 确保白名单存在
    init_whitelist

    # 添加到ipset
    if ipset test "$IPSET_RDP_WHITELIST" "$ip" 2>/dev/null; then
        log_info "IP $ip 已在RDP白名单中"
    else
        ipset add "$IPSET_RDP_WHITELIST" "$ip"
        log_success "已将 $ip 添加到RDP白名单"
    fi

    # 如果IP在黑名单中，移除
    if [ -x "$SCRIPT_DIR/blacklist-manager.sh" ]; then
        "$SCRIPT_DIR/blacklist-manager.sh" unban "$ip" 2>/dev/null || true
    fi
}

# 添加当前IP
add_my_ip() {
    local current_ip
    if current_ip=$(get_current_ip); then
        log_info "检测到当前IP: $current_ip"
        add_to_whitelist "$current_ip"
        echo
        log_success "你的IP已加入白名单，现在可以执行: sudo $0 unlock"
    else
        log_error "无法自动检测当前IP"
        echo
        echo "请手动获取你的IP并添加："
        echo "  1. 获取IP: curl ifconfig.me"
        echo "  2. 添加白名单: sudo $0 add-whitelist <你的IP>"
    fi
}

# 从白名单移除
remove_from_whitelist() {
    local ip="$1"
    if ipset test "$IPSET_RDP_WHITELIST" "$ip" 2>/dev/null; then
        ipset del "$IPSET_RDP_WHITELIST" "$ip"
        log_success "已从RDP白名单移除: $ip"
    else
        log_warn "IP $ip 不在RDP白名单中"
    fi
}

# 列出白名单
list_whitelist() {
    echo -e "${BLUE}RDP白名单:${NC}"
    echo "========================================"

    if ! ipset list "$IPSET_RDP_WHITELIST" >/dev/null 2>&1; then
        echo "白名单未初始化"
        return 0
    fi

    local output=$(ipset list "$IPSET_RDP_WHITELIST" | grep -E '^[0-9]')
    if [ -z "$output" ]; then
        echo "白名单为空"
    else
        echo "$output" | while read -r ip rest; do
            echo "  $ip"
        done
    fi

    echo "========================================"
}

# 解除紧急锁定
unlock() {
    log_info "解除RDP紧急锁定..."

    # 检查白名单是否有IP
    if ! ipset list "$IPSET_RDP_WHITELIST" >/dev/null 2>&1; then
        log_error "白名单未初始化！"
        echo "请先运行: sudo $0 add-my-ip"
        return 1
    fi

    local count=$(ipset list "$IPSET_RDP_WHITELIST" | grep -cE '^[0-9]' || echo "0")
    if [ "$count" -eq 0 ]; then
        log_error "白名单为空！"
        echo "请先添加你的IP: sudo $0 add-my-ip"
        return 1
    fi

    echo
    log_info "当前白名单有 $count 个IP"
    list_whitelist
    echo
    read -p "确认解除锁定？只有白名单IP可以访问RDP (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "已取消"
        return 0
    fi

    # 移除DROP所有的规则
    while iptables -C INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP 2>/dev/null; do
        iptables -D INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP
    done

    # 确保白名单规则存在
    init_whitelist

    # 添加DROP其他IP的规则（在白名单规则之后）
    if ! iptables -C INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP 2>/dev/null; then
        iptables -A INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP
        log_success "添加拒绝其他IP的规则"
    fi

    echo
    log_success "========================================"
    log_success "RDP保护已启用！"
    log_success "========================================"
    echo
    echo "当前配置："
    echo "  ✓ 白名单模式：只有白名单IP可以访问RDP"
    echo "  ✓ 其他所有IP被阻止"
    echo "  ✓ 白名单IP数量: $count"
    echo
    echo -e "${CYAN}强烈建议：${NC}"
    echo "  sudo $0 change-port <新端口>  # 修改RDP端口，避免扫描"
}

# 快速保护
quick_protect() {
    log_info "========================================"
    log_info "RDP快速保护"
    log_info "========================================"
    echo

    # 1. 创建白名单
    init_whitelist

    # 2. 添加当前IP
    local current_ip
    if current_ip=$(get_current_ip); then
        log_info "检测到当前IP: $current_ip"
        add_to_whitelist "$current_ip"
    else
        echo
        log_warn "无法自动检测IP，请手动输入你的IP地址："
        read -p "你的IP: " manual_ip
        if [ -n "$manual_ip" ]; then
            add_to_whitelist "$manual_ip"
        else
            log_error "未输入IP，无法继续"
            return 1
        fi
    fi

    echo
    read -p "是否添加更多IP到白名单? (y/N): " add_more
    while [[ "$add_more" =~ ^[Yy]$ ]]; do
        read -p "输入IP地址: " extra_ip
        if [ -n "$extra_ip" ]; then
            add_to_whitelist "$extra_ip"
        fi
        read -p "继续添加? (y/N): " add_more
    done

    # 3. 启用保护
    echo
    log_info "启用RDP白名单保护..."

    # 移除所有RDP相关的DROP规则
    while iptables -D INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP 2>/dev/null; do
        :
    done

    # 添加拒绝非白名单的规则
    iptables -A INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP

    echo
    log_success "========================================"
    log_success "RDP保护已启用！"
    log_success "========================================"
    echo
    list_whitelist
    echo

    # 4. 建议修改端口
    echo -e "${CYAN}强烈建议修改RDP端口：${NC}"
    echo "  当前端口: $DEFAULT_RDP_PORT (容易被扫描)"
    echo
    read -p "是否现在修改RDP端口? (y/N): " change_now
    if [[ "$change_now" =~ ^[Yy]$ ]]; then
        read -p "输入新端口 (1024-65535): " new_port
        if [ -n "$new_port" ] && [ "$new_port" -ge 1024 ] && [ "$new_port" -le 65535 ]; then
            change_port "$new_port"
        fi
    else
        echo
        echo "稍后可以运行: sudo $0 change-port <新端口>"
    fi

    show_status
}

# 修改RDP端口
change_port() {
    local new_port="$1"

    if [ -z "$new_port" ] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        log_error "端口号必须在 1024-65535 之间"
        return 1
    fi

    echo
    log_warn "========================================"
    log_warn "修改RDP端口"
    log_warn "========================================"
    echo
    echo "这个脚本只修改防火墙规则"
    echo "你还需要手动修改Windows RDP配置："
    echo
    echo -e "${CYAN}Windows端修改步骤：${NC}"
    echo "  1. 打开注册表编辑器 (regedit)"
    echo "  2. 找到: HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp"
    echo "  3. 修改 PortNumber 的值为: $new_port (十进制)"
    echo "  4. 重启服务器"
    echo
    read -p "已完成Windows端配置? (yes/no): " windows_done

    if [ "$windows_done" != "yes" ]; then
        echo "请先完成Windows端配置"
        return 1
    fi

    # 更新防火墙规则
    log_info "更新防火墙规则到新端口 $new_port ..."

    # 移除旧端口的规则
    while iptables -D INPUT -p tcp --dport $DEFAULT_RDP_PORT -m set --match-set "$IPSET_RDP_WHITELIST" src -j ACCEPT 2>/dev/null; do
        :
    done
    while iptables -D INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP 2>/dev/null; do
        :
    done

    # 添加新端口的规则
    iptables -I INPUT 1 -p tcp --dport $new_port -m set --match-set "$IPSET_RDP_WHITELIST" src -j ACCEPT
    iptables -A INPUT -p tcp --dport $new_port -j DROP

    log_success "防火墙规则已更新到端口 $new_port"

    # 保存规则
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
        log_success "规则已保存"
    fi

    echo
    log_success "========================================"
    log_success "RDP端口已修改"
    log_success "========================================"
    echo
    echo "新端口: $new_port"
    echo "连接方式: mstsc /v:服务器IP:$new_port"
}

# 查看状态
show_status() {
    echo -e "${BLUE}RDP保护状态${NC}"
    echo "========================================"

    # 检查紧急锁定状态
    if iptables -C INPUT -p tcp --dport $DEFAULT_RDP_PORT -j DROP 2>/dev/null; then
        local has_whitelist_rule=false
        if iptables -C INPUT -p tcp --dport $DEFAULT_RDP_PORT -m set --match-set "$IPSET_RDP_WHITELIST" src -j ACCEPT 2>/dev/null; then
            has_whitelist_rule=true
        fi

        if [ "$has_whitelist_rule" = true ]; then
            echo -e "${GREEN}✓${NC} RDP保护已启用（白名单模式）"
        else
            echo -e "${RED}✗${NC} RDP处于紧急锁定状态"
        fi
    else
        echo -e "${YELLOW}⚠${NC} RDP未受保护"
    fi

    # 白名单状态
    if ipset list "$IPSET_RDP_WHITELIST" >/dev/null 2>&1; then
        local count=$(ipset list "$IPSET_RDP_WHITELIST" | grep -cE '^[0-9]' || echo "0")
        echo -e "${GREEN}✓${NC} 白名单: $count 个IP"
    else
        echo -e "${YELLOW}⚠${NC} 白名单未初始化"
    fi

    # 当前IP状态
    local current_ip
    if current_ip=$(get_current_ip); then
        echo
        echo "当前连接IP: $current_ip"
        if ipset test "$IPSET_RDP_WHITELIST" "$current_ip" 2>/dev/null; then
            echo -e "状态: ${GREEN}✓ 在白名单中${NC}"
        else
            echo -e "状态: ${RED}✗ 不在白名单中${NC}"
        fi
    fi

    echo "========================================"

    # iptables规则
    echo
    echo "iptables规则:"
    iptables -L INPUT -n --line-numbers | grep "$DEFAULT_RDP_PORT" || echo "  无RDP相关规则"
}

# 主函数
main() {
    case "${1:-}" in
        emergency-lock)
            check_root "$@"
            emergency_lock
            ;;
        add-my-ip)
            check_root "$@"
            add_my_ip
            ;;
        add-whitelist)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定IP"
                echo "用法: sudo $0 add-whitelist <IP>"
                exit 1
            fi
            add_to_whitelist "$2"
            ;;
        remove-whitelist)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定IP"
                echo "用法: sudo $0 remove-whitelist <IP>"
                exit 1
            fi
            remove_from_whitelist "$2"
            ;;
        list-whitelist)
            list_whitelist
            ;;
        unlock)
            check_root "$@"
            unlock
            ;;
        quick-protect)
            check_root "$@"
            quick_protect
            ;;
        change-port)
            check_root "$@"
            if [ $# -lt 2 ]; then
                log_error "需要指定新端口"
                echo "用法: sudo $0 change-port <新端口>"
                exit 1
            fi
            change_port "$2"
            ;;
        status)
            show_status
            ;;
        help|--help|-h|"")
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
