#!/bin/bash

# 黑名单管理脚本 - 多系统兼容版本
# 管理被封禁的IP地址，支持滚动日志记录
# 使用 ipset 实现高效的IP集合管理
# 支持：CentOS/RHEL 7+, Debian/Ubuntu 18.04+

set -euo pipefail  # 更严格的错误处理

# 版本信息
VERSION="3.1.0"
SCRIPT_NAME="$(basename "$0")"

# 系统类型（运行时检测）
OS_TYPE=""
PKG_MANAGER=""
FIREWALL_CMD=""

# 配置
IPSET_NAME="port-protect-blacklist"
BAN_LOG="/var/log/port-protect-ban.log"
BAN_HISTORY="/var/log/port-protect-ban-history.log"
CONFIG_FILE="/etc/port-protect-autoban.conf"
DEFAULT_BAN_DURATION=2592000  # 30天 (秒)
IPSET_SAVE_FILE="/etc/iptables/ipsets"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 调试模式
DEBUG=${DEBUG:-0}

# 调试日志
debug_log() {
    if [ "$DEBUG" -eq 1 ]; then
        echo -e "${CYAN}[DEBUG] $*${NC}" >&2
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}黑名单管理脚本${NC} - 多系统兼容版 v${VERSION} (CentOS/Debian/Ubuntu)

${YELLOW}使用方式:${NC} $SCRIPT_NAME [命令] [参数]

${YELLOW}命令:${NC}
  init                     初始化黑名单系统（创建ipset和iptables规则）
  ban <IP> [原因] [时长]   封禁IP地址
  unban <IP>               解封IP地址
  check <IP>               检查IP是否被封禁
  list                     列出所有被封禁的IP
  history [IP]             查看封禁历史记录
  flush                    清空所有封禁
  status                   查看黑名单系统状态
  cleanup                  清理过期的日志记录
  save                     保存ipset到文件（持久化）
  restore                  从文件恢复ipset
  diagnose                 诊断系统问题
  install-deps             安装所需依赖包

${YELLOW}参数:${NC}
  IP       - IP地址或CIDR网段
  原因     - 封禁原因（可选，默认：Manual ban）
  时长     - 封禁时长（秒，可选，默认：30天，0表示永久）

${YELLOW}示例:${NC}
  $SCRIPT_NAME init                              # 初始化系统
  $SCRIPT_NAME install-deps                      # 安装依赖
  $SCRIPT_NAME ban 1.2.3.4                       # 封禁IP（30天）
  $SCRIPT_NAME ban 1.2.3.4 "爆破攻击" 86400     # 封禁24小时
  $SCRIPT_NAME ban 1.2.3.4 "恶意扫描" 0         # 永久封禁
  $SCRIPT_NAME unban 1.2.3.4                     # 解封IP
  $SCRIPT_NAME check 1.2.3.4                     # 检查IP状态
  $SCRIPT_NAME list                              # 列出所有封禁
  $SCRIPT_NAME history                           # 查看所有历史
  $SCRIPT_NAME history 1.2.3.4                   # 查看指定IP历史
  $SCRIPT_NAME diagnose                          # 诊断问题

${YELLOW}环境变量:${NC}
  DEBUG=1          启用调试模式
EOF
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}" >&2
        echo "请使用: sudo $SCRIPT_NAME $*" >&2
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        OS_NAME="$NAME"
        debug_log "检测到操作系统: $OS_NAME ($OS_ID $OS_VERSION)"
    else
        echo -e "${RED}错误: 无法检测操作系统类型${NC}" >&2
        exit 1
    fi

    # 检测系统类型并设置包管理器
    case "$OS_ID" in
        centos|rhel|rocky|almalinux|fedora)
            OS_TYPE="rhel"
            # CentOS 8+/RHEL 8+ 使用 dnf
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            FIREWALL_CMD="firewalld"
            debug_log "系统类型: RHEL系列, 包管理器: $PKG_MANAGER"
            ;;
        debian|ubuntu|linuxmint|pop)
            OS_TYPE="debian"
            PKG_MANAGER="apt"
            FIREWALL_CMD="iptables"
            debug_log "系统类型: Debian系列, 包管理器: $PKG_MANAGER"
            ;;
        *)
            echo -e "${YELLOW}警告: 未知系统类型 $OS_ID，尝试继续...${NC}"
            # 尝试检测包管理器
            if command -v dnf >/dev/null 2>&1; then
                OS_TYPE="rhel"
                PKG_MANAGER="dnf"
            elif command -v yum >/dev/null 2>&1; then
                OS_TYPE="rhel"
                PKG_MANAGER="yum"
            elif command -v apt-get >/dev/null 2>&1; then
                OS_TYPE="debian"
                PKG_MANAGER="apt"
            else
                echo -e "${RED}错误: 无法检测包管理器${NC}" >&2
                exit 1
            fi
            ;;
    esac
}

# 安装依赖包
install_dependencies() {
    echo -e "${BLUE}检查并安装依赖包...${NC}"

    detect_os

    local missing_packages=()

    # 根据系统类型检查包
    if [ "$OS_TYPE" = "rhel" ]; then
        # CentOS/RHEL 包列表
        local packages=("ipset" "iptables" "iptables-services")

        # 检查缺失的包
        for pkg in "${packages[@]}"; do
            if ! rpm -q "$pkg" >/dev/null 2>&1; then
                missing_packages+=("$pkg")
            fi
        done
    else
        # Debian/Ubuntu 包列表
        local packages=("ipset" "iptables" "ipset-persistent" "iptables-persistent")

        # 检查缺失的包
        for pkg in "${packages[@]}"; do
            if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                missing_packages+=("$pkg")
            fi
        done
    fi

    if [ ${#missing_packages[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ 所有依赖包已安装${NC}"
        return 0
    fi

    echo -e "${YELLOW}需要安装以下包: ${missing_packages[*]}${NC}"
    read -p "是否继续安装? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消安装"
        exit 1
    fi

    # 根据包管理器安装
    if [ "$OS_TYPE" = "rhel" ]; then
        # CentOS/RHEL 安装
        echo -e "${BLUE}使用 $PKG_MANAGER 安装依赖包...${NC}"

        # 确保 EPEL 仓库可用（某些包可能需要）
        if [ "$PKG_MANAGER" = "yum" ]; then
            if ! rpm -q epel-release >/dev/null 2>&1; then
                echo -e "${BLUE}安装 EPEL 仓库...${NC}"
                $PKG_MANAGER install -y epel-release || true
            fi
        fi

        # 安装包
        for pkg in "${missing_packages[@]}"; do
            echo -e "${CYAN}安装 $pkg...${NC}"
            if $PKG_MANAGER install -y "$pkg"; then
                echo -e "${GREEN}✓ $pkg 安装成功${NC}"
            else
                echo -e "${RED}错误: $pkg 安装失败${NC}" >&2
                exit 1
            fi
        done

        # 启用 iptables 服务
        if rpm -q iptables-services >/dev/null 2>&1; then
            systemctl enable iptables 2>/dev/null || true
        fi

    else
        # Debian/Ubuntu 安装
        echo -e "${BLUE}更新包列表...${NC}"
        if ! apt-get update; then
            echo -e "${RED}错误: 无法更新包列表${NC}" >&2
            exit 1
        fi

        # 安装包
        echo -e "${BLUE}安装依赖包...${NC}"
        for pkg in "${missing_packages[@]}"; do
            echo -e "${CYAN}安装 $pkg...${NC}"
            if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
                echo -e "${GREEN}✓ $pkg 安装成功${NC}"
            else
                # ipset-persistent 在某些版本可能不可用
                if [ "$pkg" = "ipset-persistent" ]; then
                    echo -e "${YELLOW}⚠ ipset-persistent 不可用，将使用手动保存方式${NC}"
                    continue
                fi
                echo -e "${RED}错误: $pkg 安装失败${NC}" >&2
                exit 1
            fi
        done
    fi

    echo -e "${GREEN}✓ 所有依赖包安装完成${NC}"
}

# 检查依赖
# 检查依赖
check_dependencies() {
    local missing_deps=()
    local kernel_modules=()

    # 检查命令
    if ! command -v ipset >/dev/null 2>&1; then
        missing_deps+=("ipset")
    fi

    if ! command -v iptables >/dev/null 2>&1; then
        missing_deps+=("iptables")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少必要的依赖项: ${missing_deps[*]}${NC}" >&2
        echo
        echo "解决方案:"
        echo "  1. 运行: sudo $SCRIPT_NAME install-deps"
        echo "  2. 或手动安装: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi

    # 检查内核模块
    if ! lsmod | grep -q "^ip_set "; then
        debug_log "ip_set 模块未加载，尝试加载..."
        if ! modprobe ip_set 2>/dev/null; then
            kernel_modules+=("ip_set")
        fi
    fi

    if ! lsmod | grep -q "^ip_set_hash_"; then
        debug_log "ip_set_hash 模块未加载，尝试加载..."
        if ! modprobe ip_set_hash_ip 2>/dev/null; then
            kernel_modules+=("ip_set_hash_ip")
        fi
    fi

    if [ ${#kernel_modules[@]} -gt 0 ]; then
        echo -e "${RED}错误: 无法加载内核模块: ${kernel_modules[*]}${NC}" >&2
        echo "您的内核可能不支持 ipset，请检查内核配置" >&2
        exit 1
    fi

    debug_log "依赖检查通过"
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
        expire_time=$(date -d "@$(($(date +%s) + duration))" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
    fi

    # 记录到当前日志
    echo "${timestamp}|${action}|${ip}|${reason}|${duration}|${expire_time}" >> "$BAN_LOG"

    # 同时记录到历史日志（用于长期保存）
    echo "${timestamp}|${action}|${ip}|${reason}|${duration}|${expire_time}" >> "$BAN_HISTORY"

    # 检查日志大小，超过10MB自动轮转（使用 -c 适配 Debian/Ubuntu）
    if [ -f "$BAN_LOG" ]; then
        local log_size=$(stat -c%s "$BAN_LOG" 2>/dev/null || echo "0")
        if [ "$log_size" -gt 10485760 ]; then
            local backup_log="${BAN_LOG}.$(date +%Y%m%d-%H%M%S)"
            mv "$BAN_LOG" "$backup_log"
            gzip "$backup_log" &
            touch "$BAN_LOG"
            chmod 600 "$BAN_LOG"
            echo -e "${YELLOW}日志已轮转: $backup_log.gz${NC}"
        fi
    fi
}

# 诊断系统问题
diagnose_system() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}系统诊断报告${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo

    # 1. 操作系统信息
    echo -e "${CYAN}[1] 操作系统信息${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "  操作系统: $NAME $VERSION"
        echo "  内核版本: $(uname -r)"
    fi
    echo

    # 2. 检查依赖
    echo -e "${CYAN}[2] 依赖检查${NC}"
    for cmd in ipset iptables; do
        if command -v $cmd >/dev/null 2>&1; then
            local version=$($cmd --version 2>&1 | head -1 || echo "无法获取版本")
            echo -e "  ${GREEN}✓${NC} $cmd: $version"
        else
            echo -e "  ${RED}✗${NC} $cmd: 未安装"
        fi
    done
    echo

    # 3. 内核模块
    echo -e "${CYAN}[3] 内核模块${NC}"
    for module in ip_set ip_set_hash_ip ip_set_hash_net iptable_filter; do
        if lsmod | grep -q "^$module "; then
            echo -e "  ${GREEN}✓${NC} $module: 已加载"
        else
            echo -e "  ${YELLOW}⚠${NC} $module: 未加载"
        fi
    done
    echo

    # 4. ipset 状态
    echo -e "${CYAN}[4] ipset 状态${NC}"
    if command -v ipset >/dev/null 2>&1; then
        if ipset list "$IPSET_NAME" >/dev/null 2>&1; then
            local count=$(ipset list "$IPSET_NAME" | grep -cE '^[0-9]' || echo "0")
            echo -e "  ${GREEN}✓${NC} ipset '$IPSET_NAME' 存在"
            echo "  - 类型: $(ipset list "$IPSET_NAME" | grep "Type:" | cut -d: -f2)"
            echo "  - 成员数量: $count"
            echo "  - 大小限制: $(ipset list "$IPSET_NAME" | grep "Size in memory:" | cut -d: -f2 || echo "N/A")"
        else
            echo -e "  ${YELLOW}⚠${NC} ipset '$IPSET_NAME' 不存在"
        fi
    else
        echo -e "  ${RED}✗${NC} ipset 命令不可用"
    fi
    echo

    # 5. iptables 规则
    echo -e "${CYAN}[5] iptables 规则${NC}"
    if command -v iptables >/dev/null 2>&1; then
        if iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} iptables 规则已配置"
            iptables -L INPUT -n --line-numbers | grep "$IPSET_NAME" | head -1 | sed 's/^/  /'
        else
            echo -e "  ${YELLOW}⚠${NC} iptables 规则不存在"
        fi
    else
        echo -e "  ${RED}✗${NC} iptables 命令不可用"
    fi
    echo

    # 6. 日志文件
    echo -e "${CYAN}[6] 日志文件${NC}"
    for log_file in "$BAN_LOG" "$BAN_HISTORY"; do
        if [ -f "$log_file" ]; then
            local size=$(du -h "$log_file" | awk '{print $1}')
            local lines=$(wc -l < "$log_file")
            local perms=$(stat -c "%a" "$log_file" 2>/dev/null || echo "N/A")
            echo -e "  ${GREEN}✓${NC} $(basename "$log_file"): $size, $lines 行, 权限: $perms"
        else
            echo -e "  ${YELLOW}⚠${NC} $(basename "$log_file"): 不存在"
        fi
    done
    echo

    # 7. 持久化配置
    echo -e "${CYAN}[7] 持久化配置${NC}"
    if [ -f "$IPSET_SAVE_FILE" ]; then
        echo -e "  ${GREEN}✓${NC} ipset 保存文件存在: $IPSET_SAVE_FILE"
    else
        echo -e "  ${YELLOW}⚠${NC} ipset 保存文件不存在: $IPSET_SAVE_FILE"
    fi

    if command -v netfilter-persistent >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} netfilter-persistent 已安装"
    else
        echo -e "  ${YELLOW}⚠${NC} netfilter-persistent 未安装"
    fi
    echo

    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}诊断完成${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

# 初始化黑名单系统
init_system() {
    echo -e "${BLUE}初始化黑名单系统...${NC}"
    echo

    # 创建保存目录
    local save_dir=$(dirname "$IPSET_SAVE_FILE")
    if [ ! -d "$save_dir" ]; then
        debug_log "创建目录: $save_dir"
        mkdir -p "$save_dir" || {
            echo -e "${RED}错误: 无法创建目录 $save_dir${NC}" >&2
            exit 1
        }
    fi

    # 检查ipset是否已存在
    if ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ ipset '$IPSET_NAME' 已存在${NC}"
    else
        # 创建ipset集合（hash:ip类型，支持超时）
        debug_log "创建 ipset: $IPSET_NAME"
        local create_output
        if ! create_output=$(ipset create "$IPSET_NAME" hash:ip timeout $DEFAULT_BAN_DURATION 2>&1); then
            echo -e "${RED}错误: 无法创建ipset${NC}" >&2
            echo "详细信息: $create_output" >&2
            echo
            echo "可能的原因:"
            echo "  1. 内核模块未加载（尝试: modprobe ip_set ip_set_hash_ip）"
            echo "  2. 内核不支持 ipset"
            echo "  3. 权限不足（需要 root 权限）"
            echo
            echo "运行诊断: sudo $SCRIPT_NAME diagnose"
            exit 1
        fi
        echo -e "${GREEN}✓ 已创建ipset: $IPSET_NAME${NC}"
    fi

    # 检查iptables规则是否存在
    if iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
        echo -e "${YELLOW}⚠ iptables规则已存在${NC}"
    else
        # 在INPUT链最前面添加黑名单规则
        debug_log "添加 iptables 规则"
        if ! iptables -I INPUT 1 -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
            echo -e "${RED}错误: 无法添加iptables规则${NC}" >&2
            echo "请检查 iptables 配置和权限" >&2
            exit 1
        fi
        echo -e "${GREEN}✓ 已添加iptables规则${NC}"
    fi

    # 初始化日志
    init_logs

    # 保存配置
    save_ipset
    if command -v netfilter-persistent >/dev/null 2>&1; then
        echo -e "${BLUE}保存 iptables 规则...${NC}"
        netfilter-persistent save >/dev/null 2>&1 || echo -e "${YELLOW}⚠ 无法保存 iptables 规则${NC}"
    fi

    echo
    echo -e "${GREEN}✓ 黑名单系统初始化完成${NC}"
    echo
    echo -e "${CYAN}配置信息:${NC}"
    echo "  - ipset集合: $IPSET_NAME"
    echo "  - 默认封禁时长: $DEFAULT_BAN_DURATION 秒 (30天)"
    echo "  - 日志文件: $BAN_LOG"
    echo "  - 历史记录: $BAN_HISTORY"
    echo "  - 保存文件: $IPSET_SAVE_FILE"
    echo
    echo -e "${CYAN}下一步:${NC}"
    echo "  - 查看状态: sudo $SCRIPT_NAME status"
    echo "  - 封禁IP: sudo $SCRIPT_NAME ban <IP>"
    echo "  - 诊断系统: sudo $SCRIPT_NAME diagnose"
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
    local log_dir=$(dirname "$BAN_LOG")
    local log_base=$(basename "$BAN_LOG")
    local deleted_count=0

    while IFS= read -r -d '' file; do
        echo "  删除: $file"
        ((deleted_count++))
    done < <(find "$log_dir" -name "${log_base}.*.gz" -mtime +30 -print0 -delete 2>/dev/null)

    if [ "$deleted_count" -eq 0 ]; then
        echo "  没有过期的日志文件"
    else
        echo -e "${GREEN}✓ 已删除 $deleted_count 个过期日志文件${NC}"
    fi

    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 保存 ipset 到文件
save_ipset() {
    debug_log "保存 ipset 到 $IPSET_SAVE_FILE"

    local save_dir=$(dirname "$IPSET_SAVE_FILE")
    if [ ! -d "$save_dir" ]; then
        mkdir -p "$save_dir" || {
            echo -e "${RED}错误: 无法创建目录 $save_dir${NC}" >&2
            return 1
        }
    fi

    if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ ipset '$IPSET_NAME' 不存在，跳过保存${NC}"
        return 0
    fi

    if ipset save "$IPSET_NAME" > "$IPSET_SAVE_FILE" 2>/dev/null; then
        chmod 600 "$IPSET_SAVE_FILE"
        echo -e "${GREEN}✓ 已保存 ipset 到 $IPSET_SAVE_FILE${NC}"
        return 0
    else
        echo -e "${RED}错误: 无法保存 ipset${NC}" >&2
        return 1
    fi
}

# 从文件恢复 ipset
restore_ipset() {
    if [ ! -f "$IPSET_SAVE_FILE" ]; then
        echo -e "${YELLOW}⚠ 保存文件不存在: $IPSET_SAVE_FILE${NC}"
        echo "请先运行: sudo $SCRIPT_NAME save"
        return 1
    fi

    echo -e "${BLUE}从文件恢复 ipset...${NC}"

    if ipset restore < "$IPSET_SAVE_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ 已从 $IPSET_SAVE_FILE 恢复 ipset${NC}"
        return 0
    else
        echo -e "${RED}错误: 无法恢复 ipset${NC}" >&2
        echo "请检查文件内容: $IPSET_SAVE_FILE"
        return 1
    fi
}

# 主函数
main() {
    # 对于某些命令，不需要 root 权限
    case "${1:-}" in
        help|--help|-h|"")
            show_help
            exit 0
            ;;
        install-deps)
            check_root "$@"
            install_dependencies
            exit 0
            ;;
        diagnose)
            # 诊断命令最好用 root 运行，但不强制
            if [ "$(id -u)" != "0" ]; then
                echo -e "${YELLOW}提示: 建议使用 root 权限运行诊断以获取完整信息${NC}"
                echo
            fi
            ;;
        *)
            check_root "$@"
            check_dependencies
            ;;
    esac

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
        save)
            save_ipset
            ;;
        restore)
            restore_ipset
            ;;
        diagnose)
            diagnose_system
            ;;
        install-deps)
            # 已在前面处理
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}错误: 未知命令 '$command'${NC}" >&2
            echo
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
