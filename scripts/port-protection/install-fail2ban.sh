#!/bin/bash

# Fail2Ban快速安装和配置脚本
# 用途：一键安装Fail2Ban并配置RDP+SSH保护
# 适用：Debian/Ubuntu/CentOS/RHEL系统（多系统支持）

set -euo pipefail

VERSION="2.0.0"

# 系统检测变量
OS_TYPE=""      # "rhel" 或 "debian"
PKG_MANAGER=""  # "yum", "dnf", 或 "apt"
LOG_PATH=""     # "/var/log/secure" 或 "/var/log/auth.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
        echo "请使用: sudo $0"
        exit 1
    fi
}

detect_os() {
    log_info "检测操作系统..."

    if [ ! -f /etc/os-release ]; then
        log_error "无法检测操作系统（/etc/os-release不存在）"
        exit 1
    fi

    source /etc/os-release
    local OS_ID="${ID:-unknown}"

    case "$OS_ID" in
        centos|rhel|rocky|almalinux|fedora)
            OS_TYPE="rhel"
            LOG_PATH="/var/log/secure"

            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi

            log_success "检测到 CentOS/RHEL 系统 (包管理器: $PKG_MANAGER)"
            ;;
        debian|ubuntu|linuxmint|pop)
            OS_TYPE="debian"
            PKG_MANAGER="apt"
            LOG_PATH="/var/log/auth.log"

            log_success "检测到 Debian/Ubuntu 系统"
            ;;
        *)
            log_error "不支持的操作系统: $OS_ID"
            echo "仅支持: CentOS, RHEL, Debian, Ubuntu"
            exit 1
            ;;
    esac
}

get_current_ip() {
    local ip=""
    if [ -n "${SSH_CLIENT:-}" ]; then
        ip=$(echo "$SSH_CLIENT" | awk '{print $1}')
    elif [ -n "${SSH_CONNECTION:-}" ]; then
        ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    fi
    echo "$ip"
}

install_fail2ban() {
    log_info "========================================"
    log_info "安装Fail2Ban"
    log_info "========================================"
    echo

    # 检查是否已安装
    if command -v fail2ban-client >/dev/null 2>&1; then
        log_warn "Fail2Ban已安装"
        fail2ban-client --version
        read -p "是否重新安装? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    if [ "$OS_TYPE" = "rhel" ]; then
        # CentOS/RHEL 安装
        log_info "检查 EPEL 仓库..."

        # 安装 EPEL（如果未安装）
        if ! rpm -q epel-release >/dev/null 2>&1; then
            log_info "安装 EPEL 仓库..."
            $PKG_MANAGER install -y epel-release || {
                log_error "EPEL 仓库安装失败"
                exit 1
            }
            log_success "EPEL 仓库已安装"
        else
            log_success "EPEL 仓库已安装"
        fi

        # 安装 Fail2Ban
        log_info "安装 Fail2Ban..."
        if [ "$PKG_MANAGER" = "dnf" ]; then
            $PKG_MANAGER install -y fail2ban fail2ban-systemd
        else
            $PKG_MANAGER install -y fail2ban fail2ban-systemd
        fi
    else
        # Debian/Ubuntu 安装
        log_info "更新包列表..."
        apt-get update

        log_info "安装Fail2Ban..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban
    fi

    log_success "Fail2Ban安装完成"
    fail2ban-client --version
}

configure_ssh() {
    log_info "配置SSH保护..."

    cat > /etc/fail2ban/jail.d/sshd.local << EOF
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = $LOG_PATH
maxretry = 5
bantime  = 3600      # 封禁1小时
findtime = 600       # 10分钟内
EOF

    log_success "SSH保护已配置 (日志: $LOG_PATH)"
}

configure_rdp() {
    log_info "配置RDP保护..."

    # RDP 日志路径（根据系统选择）
    local rdp_log="$LOG_PATH"
    if [ "$OS_TYPE" = "debian" ]; then
        # Debian/Ubuntu 可能同时监控 syslog 和 auth.log
        rdp_log="/var/log/syslog
         /var/log/auth.log"
    fi

    # 创建RDP jail配置
    cat > /etc/fail2ban/jail.d/rdp.local << EOF
[rdp]
enabled  = true
port     = 3389
filter   = rdp
logpath  = $rdp_log
maxretry = 3
bantime  = 86400     # 封禁24小时
findtime = 600       # 10分钟内
EOF

    # 创建RDP过滤器
    cat > /etc/fail2ban/filter.d/rdp.conf << 'EOF'
[Definition]
# RDP登录失败检测
failregex = ^.*Failed password.*from <HOST>.*$
            ^.*authentication failure.*rhost=<HOST>.*$
            ^.*Connection reset by.*<HOST>.*$
            ^.*Invalid user.*from <HOST>.*$

ignoreregex =
EOF

    log_success "RDP保护已配置 (日志: $rdp_log)"
}

configure_whitelist() {
    log_info "配置白名单..."

    local current_ip=$(get_current_ip)
    local whitelist="127.0.0.1/8 ::1"

    if [ -n "$current_ip" ]; then
        log_info "检测到当前IP: $current_ip"
        whitelist="$whitelist $current_ip"
    fi

    echo
    read -p "是否添加更多IP到白名单? (y/N): " add_more
    if [[ "$add_more" =~ ^[Yy]$ ]]; then
        read -p "输入IP地址或网段（空格分隔）: " extra_ips
        if [ -n "$extra_ips" ]; then
            whitelist="$whitelist $extra_ips"
        fi
    fi

    # 创建默认配置
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# 白名单
ignoreip = $whitelist

# 默认封禁时间
bantime  = 3600
findtime = 600
maxretry = 5

# 动作
banaction = iptables-multiport
EOF

    log_success "白名单已配置: $whitelist"
}

configure_email_notification() {
    log_warn "邮件通知配置（可选）"
    echo
    read -p "是否配置邮件通知? (y/N): " setup_email

    if [[ "$setup_email" =~ ^[Yy]$ ]]; then
        read -p "输入通知邮箱地址: " email_addr

        cat >> /etc/fail2ban/jail.local << EOF

# 邮件通知
action = %(action_mwl)s
destemail = $email_addr
sender = fail2ban@$(hostname)
EOF

        log_success "邮件通知已配置: $email_addr"
    fi
}

start_fail2ban() {
    log_info "启动Fail2Ban..."

    # 重启服务
    systemctl restart fail2ban
    systemctl enable fail2ban

    # 等待启动
    sleep 2

    # 检查状态
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2Ban已启动"
    else
        log_error "Fail2Ban启动失败"
        systemctl status fail2ban
        exit 1
    fi
}

show_status() {
    log_info "========================================"
    log_info "Fail2Ban状态"
    log_info "========================================"
    echo

    # 服务状态
    systemctl status fail2ban --no-pager | head -10

    echo
    echo "======================================"
    echo "已启用的Jail:"
    echo "======================================"
    fail2ban-client status

    echo
    echo "======================================"
    echo "SSH Jail详情:"
    echo "======================================"
    fail2ban-client status sshd || echo "sshd jail未启用"

    echo
    echo "======================================"
    echo "RDP Jail详情:"
    echo "======================================"
    fail2ban-client status rdp || echo "rdp jail未启用"

    echo
    log_info "========================================"
    log_info "常用命令"
    log_info "========================================"
    echo "查看所有jail状态:    sudo fail2ban-client status"
    echo "查看SSH封禁列表:     sudo fail2ban-client status sshd"
    echo "查看RDP封禁列表:     sudo fail2ban-client status rdp"
    echo "解封IP:             sudo fail2ban-client set sshd unbanip <IP>"
    echo "手动封禁IP:         sudo fail2ban-client set sshd banip <IP>"
    echo "重新加载配置:       sudo fail2ban-client reload"
    echo "查看日志:           sudo tail -f /var/log/fail2ban.log"
}

test_configuration() {
    log_info "测试配置..."

    if fail2ban-client --test; then
        log_success "配置文件测试通过"
    else
        log_error "配置文件测试失败"
        return 1
    fi
}

main() {
    check_root

    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════╗
║   Fail2Ban 快速安装配置脚本          ║
║   版本: 2.0.0 (多系统支持)           ║
╚═══════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo
    log_info "这个脚本将："
    echo "  1. 检测操作系统类型"
    echo "  2. 安装Fail2Ban"
    echo "  3. 配置SSH保护"
    echo "  4. 配置RDP保护"
    echo "  5. 设置白名单"
    echo "  6. 启动服务"
    echo
    read -p "继续? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi

    # 执行安装和配置
    detect_os
    echo

    install_fail2ban
    echo

    configure_whitelist
    echo

    configure_ssh
    echo

    configure_rdp
    echo

    configure_email_notification
    echo

    test_configuration
    echo

    start_fail2ban
    echo

    show_status

    echo
    log_success "========================================"
    log_success "Fail2Ban安装配置完成！"
    log_success "========================================"
    echo
    log_info "下一步："
    echo "  1. 查看状态: sudo fail2ban-client status"
    echo "  2. 查看日志: sudo tail -f /var/log/fail2ban.log"
    echo "  3. 测试保护: 尝试多次SSH登录失败"
    echo "  4. 修改配置: /etc/fail2ban/jail.local"
    if [ "$OS_TYPE" = "rhel" ]; then
        echo
        echo "CentOS/RHEL 注意事项："
        echo "  - SSH日志位置: $LOG_PATH"
        echo "  - 如果使用 firewalld，确保已停用（脚本使用 iptables）"
        echo "  - SELinux 可能需要配置: sudo setenforce 0 (测试)"
    fi
}

main "$@"
