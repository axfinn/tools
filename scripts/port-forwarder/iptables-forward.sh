#!/bin/bash

# 🔥 iptables 端口转发管理脚本
# 使用 iptables 实现高性能端口转发
# 版本: 1.0
# 作者: port-forwarder 项目
# 最后更新: 2025-09-01

# 🎨 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 📁 配置文件路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/iptables-rules"
BACKUP_DIR="$SCRIPT_DIR/iptables-backup"

# 确保必要目录存在
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"

# 🔧 显示帮助信息
show_help() {
    cat << EOF
${WHITE}🔥 iptables 端口转发管理脚本${NC}

${CYAN}用法:${NC}
    $(basename $0) <命令> [选项]

${CYAN}命令:${NC}
    add <规则名>                 添加新的转发规则
    remove <规则名>              删除转发规则
    enable <规则名>              启用指定规则
    disable <规则名>             禁用指定规则
    list                         列出所有规则
    status                       查看规则状态
    backup                       备份当前iptables规则
    restore                      恢复iptables规则
    flush                        清空所有转发规则

${CYAN}添加规则选项:${NC}
    -l, --local-port <端口>      本地监听端口 (必需)
    -h, --target-host <主机>     目标主机地址 (必需)
    -p, --target-port <端口>     目标端口 (必需)
    -i, --interface <网卡>       指定网络接口 (默认: 自动检测)
    -d, --description <描述>     规则描述

${CYAN}示例:${NC}
    # 添加HTTP转发规则
    $(basename $0) add web-server -l 8080 -h 192.168.1.100 -p 80 -d "Web服务器转发"
    
    # 添加数据库转发规则
    $(basename $0) add mysql-db -l 3306 -h 192.168.1.200 -p 3306 -d "MySQL数据库"
    
    # 启用转发
    $(basename $0) enable web-server
    
    # 查看状态
    $(basename $0) status
    
    # 备份当前规则
    $(basename $0) backup

${CYAN}iptables 转发特性:${NC}
    • ${GREEN}高性能${NC}       - 内核级别转发，性能最佳
    • ${BLUE}低延迟${NC}       - 无用户空间开销
    • ${PURPLE}系统集成${NC}   - 与防火墙规则统一管理
    • ${YELLOW}持久化${NC}     - 可配置开机自动加载

${RED}⚠️ 注意事项:${NC}
    • 需要 root 权限运行
    • 仅适用于 Linux 系统
    • 需要启用 IP 转发功能

EOF
}

# 🔍 检查系统要求
check_requirements() {
    # 检查是否为Linux系统
    if [ "$(uname)" != "Linux" ]; then
        echo -e "${RED}❌ 此脚本仅适用于 Linux 系统${NC}" >&2
        exit 1
    fi
    
    # 检查root权限
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}❌ 此脚本需要 root 权限运行${NC}" >&2
        echo -e "${BLUE}💡 请使用: sudo $(basename $0) ...${NC}"
        exit 1
    fi
    
    # 检查iptables
    if ! command -v iptables >/dev/null 2>&1; then
        echo -e "${RED}❌ 未找到 iptables${NC}" >&2
        echo -e "${BLUE}💡 请安装: apt install iptables (Ubuntu) 或 yum install iptables (CentOS)${NC}"
        exit 1
    fi
    
    # 检查IP转发是否启用
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
        echo -e "${YELLOW}⚠️ IP转发功能未启用，正在启用...${NC}"
        echo 1 > /proc/sys/net/ipv4/ip_forward
        
        # 持久化设置
        if [ -f /etc/sysctl.conf ]; then
            if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
                echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
            fi
        fi
        echo -e "${GREEN}✅ IP转发功能已启用${NC}"
    fi
}

# 🌐 获取默认网络接口
get_default_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

# 📝 保存转发规则配置
save_rule_config() {
    local name="$1"
    local local_port="$2"
    local target_host="$3"
    local target_port="$4"
    local interface="$5"
    local description="$6"
    
    local config_file="$CONFIG_DIR/$name.conf"
    
    cat > "$config_file" << EOF
# iptables 端口转发规则配置
RULE_NAME="$name"
LOCAL_PORT="$local_port"
TARGET_HOST="$target_host"
TARGET_PORT="$target_port"
INTERFACE="$interface"
DESCRIPTION="$description"
CREATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
ENABLED="false"
EOF
    
    echo -e "${GREEN}✅ 规则配置已保存: $config_file${NC}"
}

# 📖 加载转发规则配置
load_rule_config() {
    local name="$1"
    local config_file="$CONFIG_DIR/$name.conf"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ 规则不存在: $name${NC}" >&2
        return 1
    fi
    
    source "$config_file"
    return 0
}

# 🔥 启用 iptables 转发规则
enable_iptables_rule() {
    local name="$1"
    
    if ! load_rule_config "$name"; then
        return 1
    fi
    
    # 检查规则是否已经启用
    if [ "$ENABLED" = "true" ]; then
        echo -e "${YELLOW}⚠️ 规则 '$name' 已经启用${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔥 启用 iptables 转发规则...${NC}"
    echo -e "  📡 本地端口: ${GREEN}$LOCAL_PORT${NC}"
    echo -e "  🎯 目标地址: ${GREEN}$TARGET_HOST:$TARGET_PORT${NC}"
    echo -e "  🌐 网络接口: ${GREEN}$INTERFACE${NC}"
    
    # 添加 DNAT 规则 (目标地址转换)
    iptables -t nat -A PREROUTING -p tcp --dport "$LOCAL_PORT" -j DNAT --to-destination "$TARGET_HOST:$TARGET_PORT"
    
    # 添加 SNAT 规则 (源地址转换) - 确保回包正确路由
    iptables -t nat -A POSTROUTING -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j MASQUERADE
    
    # 添加 FORWARD 规则 (允许转发)
    iptables -A FORWARD -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j ACCEPT
    iptables -A FORWARD -p tcp -s "$TARGET_HOST" --sport "$TARGET_PORT" -j ACCEPT
    
    # 更新配置文件状态
    sed -i 's/ENABLED="false"/ENABLED="true"/' "$CONFIG_DIR/$name.conf"
    
    echo -e "${GREEN}✅ iptables 转发规则已启用${NC}"
    echo -e "${CYAN}📋 规则: $DESCRIPTION${NC}"
}

# 🛑 禁用 iptables 转发规则
disable_iptables_rule() {
    local name="$1"
    
    if ! load_rule_config "$name"; then
        return 1
    fi
    
    # 检查规则是否已经禁用
    if [ "$ENABLED" = "false" ]; then
        echo -e "${YELLOW}⚠️ 规则 '$name' 已经禁用${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🛑 禁用 iptables 转发规则...${NC}"
    
    # 删除 DNAT 规则
    iptables -t nat -D PREROUTING -p tcp --dport "$LOCAL_PORT" -j DNAT --to-destination "$TARGET_HOST:$TARGET_PORT" 2>/dev/null
    
    # 删除 SNAT 规则
    iptables -t nat -D POSTROUTING -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j MASQUERADE 2>/dev/null
    
    # 删除 FORWARD 规则
    iptables -D FORWARD -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -p tcp -s "$TARGET_HOST" --sport "$TARGET_PORT" -j ACCEPT 2>/dev/null
    
    # 更新配置文件状态
    sed -i 's/ENABLED="true"/ENABLED="false"/' "$CONFIG_DIR/$name.conf"
    
    echo -e "${GREEN}✅ iptables 转发规则已禁用${NC}"
}

# 📋 列出所有转发规则
list_iptables_rules() {
    echo -e "${WHITE}🔥 iptables 端口转发规则列表${NC}"
    echo
    
    if [ ! -d "$CONFIG_DIR" ] || [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠️ 暂无转发规则${NC}"
        return 0
    fi
    
    printf "${CYAN}%-15s %-8s %-20s %-8s %-10s %s${NC}\n" \
        "规则名称" "本地端口" "目标地址" "目标端口" "状态" "描述"
    echo "=================================================================="
    
    for config_file in "$CONFIG_DIR"/*.conf; do
        if [ -f "$config_file" ]; then
            source "$config_file"
            
            local status="🔴 禁用"
            if [ "$ENABLED" = "true" ]; then
                status="🟢 启用"
            fi
            
            printf "%-15s %-8s %-20s %-8s %-10s %s\n" \
                "$RULE_NAME" \
                "$LOCAL_PORT" \
                "$TARGET_HOST" \
                "$TARGET_PORT" \
                "$status" \
                "$DESCRIPTION"
        fi
    done
}

# 📊 查看 iptables 状态
show_iptables_status() {
    echo -e "${WHITE}📊 iptables 转发状态${NC}"
    echo
    
    echo -e "${CYAN}当前 iptables NAT 规则:${NC}"
    iptables -t nat -L PREROUTING -n --line-numbers | grep -E "DNAT|tcp dpt:" || echo "  (无DNAT规则)"
    echo
    
    echo -e "${CYAN}当前 iptables FORWARD 规则:${NC}"
    iptables -L FORWARD -n --line-numbers | grep -E "ACCEPT.*tcp" || echo "  (无相关FORWARD规则)"
    echo
    
    echo -e "${CYAN}IP转发状态:${NC}"
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
        echo -e "  🟢 已启用"
    else
        echo -e "  🔴 未启用"
    fi
    echo
    
    echo -e "${CYAN}网络接口信息:${NC}"
    ip addr show | grep -E "^[0-9]+:|inet " | grep -A1 "state UP" || echo "  (无活动接口)"
}

# 💾 备份 iptables 规则
backup_iptables() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/iptables_backup_$timestamp.rules"
    
    echo -e "${BLUE}💾 备份 iptables 规则...${NC}"
    
    if iptables-save > "$backup_file"; then
        echo -e "${GREEN}✅ iptables 规则已备份到: $backup_file${NC}"
    else
        echo -e "${RED}❌ 备份失败${NC}" >&2
        return 1
    fi
}

# 🔄 恢复 iptables 规则
restore_iptables() {
    echo -e "${BLUE}📁 可用的备份文件:${NC}"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠️ 暂无备份文件${NC}"
        return 1
    fi
    
    local backup_files=($(ls -t "$BACKUP_DIR"/*.rules 2>/dev/null))
    
    for i in "${!backup_files[@]}"; do
        local filename=$(basename "${backup_files[$i]}")
        echo -e "  $((i+1)). $filename"
    done
    
    echo
    read -p "请选择要恢复的备份文件 (1-${#backup_files[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backup_files[@]}" ]; then
        local selected_file="${backup_files[$((choice-1))]}"
        echo -e "${BLUE}🔄 恢复 iptables 规则: $(basename "$selected_file")${NC}"
        
        if iptables-restore < "$selected_file"; then
            echo -e "${GREEN}✅ iptables 规则恢复成功${NC}"
        else
            echo -e "${RED}❌ 恢复失败${NC}" >&2
            return 1
        fi
    else
        echo -e "${RED}❌ 无效选择${NC}" >&2
        return 1
    fi
}

# 🧹 清空转发规则
flush_iptables_rules() {
    echo -e "${YELLOW}⚠️ 此操作将清空所有转发规则，是否继续? (y/N)${NC}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🧹 清空 iptables 转发规则...${NC}"
        
        # 清空 NAT 表的 PREROUTING 和 POSTROUTING 链
        iptables -t nat -F PREROUTING
        iptables -t nat -F POSTROUTING
        
        # 清空 FORWARD 链
        iptables -F FORWARD
        
        # 更新所有配置文件状态
        for config_file in "$CONFIG_DIR"/*.conf; do
            if [ -f "$config_file" ]; then
                sed -i 's/ENABLED="true"/ENABLED="false"/' "$config_file"
            fi
        done
        
        echo -e "${GREEN}✅ 所有转发规则已清空${NC}"
    else
        echo -e "${BLUE}操作已取消${NC}"
    fi
}

# ➕ 添加转发规则
add_iptables_rule() {
    local name=""
    local local_port=""
    local target_host=""
    local target_port=""
    local interface=""
    local description=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--local-port)
                local_port="$2"
                shift 2
                ;;
            -h|--target-host)
                target_host="$2"
                shift 2
                ;;
            -p|--target-port)
                target_port="$2"
                shift 2
                ;;
            -i|--interface)
                interface="$2"
                shift 2
                ;;
            -d|--description)
                description="$2"
                shift 2
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                else
                    echo -e "${RED}❌ 未知参数: $1${NC}" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # 验证必需参数
    if [ -z "$name" ] || [ -z "$local_port" ] || [ -z "$target_host" ] || [ -z "$target_port" ]; then
        echo -e "${RED}❌ 缺少必需参数${NC}" >&2
        echo -e "${BLUE}💡 用法: $(basename $0) add <规则名> -l <本地端口> -h <目标主机> -p <目标端口>${NC}"
        return 1
    fi
    
    # 设置默认网络接口
    if [ -z "$interface" ]; then
        interface=$(get_default_interface)
        if [ -z "$interface" ]; then
            interface="eth0"
        fi
    fi
    
    # 验证端口号
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [ "$local_port" -lt 1 ] || [ "$local_port" -gt 65535 ]; then
        echo -e "${RED}❌ 无效的本地端口: $local_port${NC}" >&2
        return 1
    fi
    
    if ! [[ "$target_port" =~ ^[0-9]+$ ]] || [ "$target_port" -lt 1 ] || [ "$target_port" -gt 65535 ]; then
        echo -e "${RED}❌ 无效的目标端口: $target_port${NC}" >&2
        return 1
    fi
    
    # 检查规则名是否已存在
    if [ -f "$CONFIG_DIR/$name.conf" ]; then
        echo -e "${RED}❌ 规则已存在: $name${NC}" >&2
        return 1
    fi
    
    # 设置默认描述
    if [ -z "$description" ]; then
        description="iptables转发 $local_port -> $target_host:$target_port"
    fi
    
    # 保存规则
    save_rule_config "$name" "$local_port" "$target_host" "$target_port" "$interface" "$description"
    
    echo -e "${GREEN}✅ iptables 转发规则添加成功${NC}"
    echo -e "${BLUE}💡 使用以下命令启用转发:${NC}"
    echo -e "  $(basename $0) enable $name"
}

# 🗑️ 删除转发规则
remove_iptables_rule() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${RED}❌ 请指定规则名称${NC}" >&2
        return 1
    fi
    
    local config_file="$CONFIG_DIR/$name.conf"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ 规则不存在: $name${NC}" >&2
        return 1
    fi
    
    # 先禁用规则
    disable_iptables_rule "$name"
    
    # 删除配置文件
    rm -f "$config_file"
    
    echo -e "${GREEN}✅ iptables 转发规则已删除: $name${NC}"
}

# 🎯 主函数
main() {
    check_requirements
    
    local command="$1"
    shift
    
    case "$command" in
        add)
            add_iptables_rule "$@"
            ;;
        remove|rm)
            remove_iptables_rule "$@"
            ;;
        enable|start)
            enable_iptables_rule "$@"
            ;;
        disable|stop)
            disable_iptables_rule "$@"
            ;;
        list|ls)
            list_iptables_rules
            ;;
        status)
            show_iptables_status
            ;;
        backup)
            backup_iptables
            ;;
        restore)
            restore_iptables
            ;;
        flush|clear)
            flush_iptables_rules
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $command${NC}" >&2
            echo -e "${BLUE}💡 使用 '$(basename $0) help' 查看帮助${NC}"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
