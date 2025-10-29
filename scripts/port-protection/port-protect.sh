#!/bin/bash

# 增强版 Docker Host 模式端口保护脚本
# 支持规则添加、移除、备份和恢复功能
# 使用方式: ./port-protect.sh [add|remove|backup|restore] [参数]

# 配置参数
BACKUP_DIR="/var/backups/iptables"
CURRENT_BACKUP="$BACKUP_DIR/current.rules"
# 基础链名前缀（向后兼容旧版本将所有端口放入同一链的方式）
CHAIN_NAME="DOCKER-HOST-PROTECT"
CONFIG_FILE="/etc/port-protect.conf"

# 设计变更 (2025-09):
# 旧实现对每次 add 会对共享链 flush，导致添加第二个端口时第一个端口的规则被清空，
# 输入链仍引用该链但链里没有对应端口规则 -> 端口失去保护；同时可信IP规则未限定端口导致放大权限。
# 新策略: 默认每个端口使用独立链 <CHAIN_NAME>-<port>，除非用户显式 --chain 指定共享链。
# 可信IP规则改为附带 -p/--dport 以限定于该端口。

# 显示帮助信息
show_help() {
    echo "增强版 Docker 端口保护脚本"
    echo "使用方式: $0 [命令] [参数]"
    echo
    echo "命令:"
    echo "  add <端口> [选项]       添加端口保护规则"
    echo "  remove <端口> [选项]    移除端口保护规则"
    echo "  backup [标签]           备份当前iptables规则"
    echo "  restore [标签|文件]     从备份恢复规则"
    echo "  list-backups            列出所有备份"
    echo "  list-ports              列出已受保护的端口 (含协议/链)"
    echo "  save                    保存规则使其重启后依然有效"
    echo "  status                  查看当前保护状态"
    echo
    echo "添加选项 (add):"
    echo "  -p, --protocol <tcp|udp>     协议类型 (默认: tcp)"
    echo "  -l, --limit <rate>           请求限制速率 (默认: 5/min)"
    echo "  -b, --burst <count>          突发请求限制 (默认: 10)"
    echo "  -t, --trust <ip>             添加可信IP (可多次使用)"
    echo "  -c, --chain <name>           自定义链名称 (默认: DOCKER-HOST-PROTECT-<端口>)"
    echo "  -r, --rdp                    RDP协议优化模式 (30/min, burst 50)"
    echo "  -w, --whitelist-only         仅允许可信IP访问 (不添加速率限制)"
    echo "  -s, --strict                 严格模式 (2/min, burst 3) - 高安全环境"
    echo "  --enable-log                 启用日志记录被拒绝的连接（用于自动封禁）"
    echo
    echo "移除选项 (remove):"
    echo "  -p, --protocol <tcp|udp>     协议类型 (默认: tcp)"
    echo "  -c, --chain <name>           指定要移除的链名称"
    echo
    echo "示例:"
    echo "  # 添加RDP端口保护 (优化模式)"
    echo "  $0 add 19099 --rdp -t 192.168.1.100 -t 10.0.0.5"
    echo
    echo "  # 添加多个RDP端口 (各自独立链)"
    echo "  for p in 19099 19100 19101; do $0 add $p --rdp -t 192.168.1.100; done"
    echo
    echo "  # 添加端口保护并备份"
    echo "  $0 add 8080 -t 192.168.1.100 -t 10.0.0.5 && $0 backup before_8080"
    echo
    echo "  # 仅允许可信IP访问 (白名单模式)"
    echo "  $0 add 22 --whitelist-only -t 192.168.1.0/24"
    echo
    echo "  # 查看备份列表并恢复"
    echo "  $0 list-backups"
    echo "  $0 restore 20240101_120000"
    echo
    echo "  # 保存规则到持久存储"
    echo "  $0 save"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "错误: 此脚本需要root权限运行" >&2
        exit 1
    fi
}

# 检查依赖项
check_dependencies() {
    local missing_deps=()
    
    # 检查iptables
    if ! command -v iptables >/dev/null 2>&1; then
        missing_deps+=("iptables")
    fi
    
    # 检查iptables-save
    if ! command -v iptables-save >/dev/null 2>&1; then
        missing_deps+=("iptables-save")
    fi
    
    # 检查iptables-restore
    if ! command -v iptables-restore >/dev/null 2>&1; then
        missing_deps+=("iptables-restore")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "错误: 缺少必要的依赖项: ${missing_deps[*]}" >&2
        echo "请安装: apt-get install iptables-persistent 或 yum install iptables-services" >&2
        exit 1
    fi
}

# 初始化环境
init_environment() {
    # 创建备份目录
    if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        echo "错误: 无法创建备份目录 $BACKUP_DIR" >&2
        exit 1
    fi
    
    # 创建配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        if ! touch "$CONFIG_FILE" 2>/dev/null; then
            echo "警告: 无法创建配置文件 $CONFIG_FILE" >&2
        fi
    fi
}

# 验证端口号
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "错误: 无效的端口号 '$port'，必须是1-65535之间的数字" >&2
        exit 1
    fi
}

# 验证IP地址
validate_ip() {
    local ip=$1
    local ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/([0-9]|[1-2][0-9]|3[0-2]))?$"
    
    if ! [[ "$ip" =~ $ip_regex ]]; then
        echo "错误: 无效的IP地址格式 '$ip'" >&2
        exit 1
    fi
}

# 备份iptables规则
backup_rules() {
    local tag=$1
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file
    
    if [ -n "$tag" ]; then
        # 清理标签中的特殊字符
        tag=$(echo "$tag" | tr -cd '[:alnum:]_-')
        backup_file="${BACKUP_DIR}/iptables_${tag}_${timestamp}.rules"
    else
        backup_file="${BACKUP_DIR}/iptables_${timestamp}.rules"
    fi
    
    # 创建备份
    if ! iptables-save > "$backup_file" 2>/dev/null; then
        echo "错误: 无法创建备份文件 $backup_file" >&2
        return 1
    fi

    # 设置备份文件权限（防火墙规则可能包含敏感信息）
    if ! chmod 600 "$backup_file" 2>/dev/null; then
        echo "警告: 无法设置备份文件权限" >&2
    fi

    if ! cp "$backup_file" "$CURRENT_BACKUP" 2>/dev/null; then
        echo "警告: 无法更新当前备份文件" >&2
    else
        chmod 600 "$CURRENT_BACKUP" 2>/dev/null
    fi
    
    # 记录到配置文件
    if [ -w "$CONFIG_FILE" ]; then
        echo "$backup_file" >> "$CONFIG_FILE"
    fi
    
    echo "✅ 已创建备份: $backup_file"
    echo "当前备份位置: $CURRENT_BACKUP"
}

# 恢复iptables规则
restore_rules() {
    local target=$1
    
    if [ -z "$target" ]; then
        # 恢复最近的备份
        if [ -f "$CURRENT_BACKUP" ]; then
            target="$CURRENT_BACKUP"
        else
            echo "错误: 未指定恢复目标且没有当前备份" >&2
            return 1
        fi
    fi
    
    # 如果是备份标签而不是文件路径
    if [[ "$target" != /* ]]; then
        local latest_backup=$(ls -t "${BACKUP_DIR}/iptables_${target}"_*.rules 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            target="$latest_backup"
        else
            echo "错误: 找不到标签为 '$target' 的备份" >&2
            return 1
        fi
    fi
    
    if [ ! -f "$target" ]; then
        echo "错误: 备份文件 $target 不存在" >&2
        return 1
    fi
    
    # 恢复前备份当前状态
    local pre_restore_backup="${BACKUP_DIR}/pre_restore_$(date +%s).rules"
    if ! iptables-save > "$pre_restore_backup" 2>/dev/null; then
        echo "警告: 无法创建恢复前备份" >&2
    else
        chmod 600 "$pre_restore_backup" 2>/dev/null
    fi
    
    # 恢复规则
    if ! iptables-restore < "$target" 2>/dev/null; then
        echo "错误: 恢复规则失败" >&2
        return 1
    fi
    
    if ! cp "$target" "$CURRENT_BACKUP" 2>/dev/null; then
        echo "警告: 无法更新当前备份文件" >&2
    fi
    
    echo "✅ 已从备份恢复: $target"
    echo "恢复前备份: $pre_restore_backup"
}

# 列出所有备份
list_backups() {
    echo "可用的iptables备份:"
    echo "----------------------------------------"
    if ls "$BACKUP_DIR"/*.rules >/dev/null 2>&1; then
        ls -lt "$BACKUP_DIR"/*.rules | awk -F/ '{print $NF}' | head -20
        echo "----------------------------------------"
        local total=$(ls "$BACKUP_DIR"/*.rules 2>/dev/null | wc -l)
        echo "总共 $total 个备份文件"
        if [ -f "$CURRENT_BACKUP" ]; then
            echo "当前备份: $(basename "$CURRENT_BACKUP")"
        fi
    else
        echo "暂无备份文件"
        echo "----------------------------------------"
    fi
}

# 保存规则到持久存储
save_rules() {
    local saved=false
    
    # Debian/Ubuntu
    if [ -d /etc/iptables ]; then
        if iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
            echo "✅ 规则已保存到 /etc/iptables/rules.v4"
            saved=true
        fi
    fi
    
    # CentOS/RHEL
    if [ -f /etc/sysconfig/iptables ] || [ -d /etc/sysconfig ]; then
        if iptables-save > /etc/sysconfig/iptables 2>/dev/null; then
            echo "✅ 规则已保存到 /etc/sysconfig/iptables"
            saved=true
        fi
    fi
    
    if [ "$saved" = false ]; then
        echo "⚠️  无法确定系统类型，请手动保存规则:"
        echo "    iptables-save > /etc/iptables/rules.v4  # Debian/Ubuntu"
        echo "    iptables-save > /etc/sysconfig/iptables  # CentOS/RHEL"
        return 1
    fi
    
    echo "重启后规则将自动加载"
}

# 添加iptables规则
add_rules() {
    local port=$1
    shift
    
    # 解析选项
    local protocol="tcp"
    local limit=""
    local burst=""
    local trusted_ips=()
    # 默认使用独立链（向后兼容：若用户用 --chain 传入与旧版本相同的 DOCKER-HOST-PROTECT 则共享）
    local chain_name=""
    local rdp_mode=false
    local whitelist_only=false
    local strict_mode=false
    local enable_log=false

    while [ $# -gt 0 ]; do
        case "$1" in
            -p|--protocol)
                if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                    echo "错误: --protocol 需要参数" >&2
                    exit 1
                fi
                protocol="$2"
                if [[ ! "$protocol" =~ ^(tcp|udp)$ ]]; then
                    echo "错误: 协议必须是 tcp 或 udp" >&2
                    exit 1
                fi
                shift 2
                ;;
            -l|--limit)
                if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                    echo "错误: --limit 需要参数" >&2
                    exit 1
                fi
                limit="$2"
                shift 2
                ;;
            -b|--burst)
                if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                    echo "错误: --burst 需要参数" >&2
                    exit 1
                fi
                burst="$2"
                if ! [[ "$burst" =~ ^[0-9]+$ ]]; then
                    echo "错误: burst 必须是数字" >&2
                    exit 1
                fi
                shift 2
                ;;
            -t|--trust)
                if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                    echo "错误: --trust 需要参数" >&2
                    exit 1
                fi
                validate_ip "$2"
                trusted_ips+=("$2")
                shift 2
                ;;
            -c|--chain)
                if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                    echo "错误: --chain 需要参数" >&2
                    exit 1
                fi
                chain_name="$2"
                shift 2
                ;;
            -r|--rdp)
                rdp_mode=true
                shift
                ;;
            -w|--whitelist-only)
                whitelist_only=true
                shift
                ;;
            -s|--strict)
                strict_mode=true
                shift
                ;;
            --enable-log)
                enable_log=true
                shift
                ;;
            *)
                echo "错误: 未知选项 $1" >&2
                show_help
                exit 1
                ;;
        esac
    done

    # 设置默认值（优先级：用户指定 > 模式默认 > 全局默认）
    if [ "$rdp_mode" = true ]; then
        # RDP模式默认值
        [ -z "$limit" ] && limit="30/min"
        [ -z "$burst" ] && burst="50"
    elif [ "$strict_mode" = true ]; then
        # 严格模式默认值
        [ -z "$limit" ] && limit="2/min"
        [ -z "$burst" ] && burst="3"
    else
        # 标准模式默认值
        [ -z "$limit" ] && limit="5/min"
        [ -z "$burst" ] && burst="10"
    fi

    # 若未显式指定 --chain 则使用独立链名
    if [ -z "$chain_name" ]; then
        chain_name="${CHAIN_NAME}-${port}"
    fi

    # 创建链（不存在则创建，存在则仅在我们重建该端口规则时清空）
    if ! iptables -L "$chain_name" >/dev/null 2>&1; then
        if ! iptables -N "$chain_name" 2>/dev/null; then
            echo "错误: 无法创建自定义链 $chain_name" >&2
            exit 1
        fi
        echo " [+] 创建自定义链: $chain_name"
    else
        # 仅在该链看起来是专用于此端口 (命名匹配 -<port>) 或用户确实希望覆盖时清空
        if [[ "$chain_name" == *"-${port}" ]]; then
            if ! iptables -F "$chain_name" 2>/dev/null; then
                echo "错误: 无法清空链 $chain_name" >&2
                exit 1
            fi
            echo " [+] 重建端口 $port 的链: $chain_name"
        else
            echo " [!] 使用共享链 $chain_name (不会清空已有其它端口规则)"
        fi
    fi
    
    # 添加可信IP规则
    for ip in "${trusted_ips[@]}"; do
        if iptables -A "$chain_name" -s "$ip" -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null; then
            echo " [+] 添加可信IP(限端口 $port): $ip"
        else
            echo "警告: 无法添加可信IP $ip" >&2
        fi
    done
    
    # 如果是白名单模式，只允许可信IP访问
    if [ "$whitelist_only" = true ]; then
        if [ ${#trusted_ips[@]} -eq 0 ]; then
            echo "错误: 白名单模式至少需要一个可信IP" >&2
            exit 1
        fi

        # 启用日志时，在DROP前记录
        if [ "$enable_log" = true ]; then
            if ! iptables -A "$chain_name" -p "$protocol" --dport "$port" \
                           -m limit --limit 1/min --limit-burst 5 \
                           -j LOG --log-prefix "PORT-PROTECT-DROP-$port: " --log-level 4 2>/dev/null; then
                echo "警告: 无法添加日志规则" >&2
            else
                echo " [+] 已启用日志记录（速率限制：1/min）"
            fi
        fi

        # 直接拒绝其他所有连接
        if ! iptables -A "$chain_name" -p "$protocol" --dport "$port" -j DROP 2>/dev/null; then
            echo "错误: 无法添加白名单拒绝规则" >&2
            exit 1
        fi
        echo " [+] 白名单模式: 仅允许可信IP访问"
    else
        # RDP模式或普通模式的速率限制
        if [ "$rdp_mode" = true ]; then
            # RDP特殊处理：允许已建立的连接
            if ! iptables -A "$chain_name" -p "$protocol" --dport "$port" \
                           -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
                echo "错误: 无法添加RDP已建立连接规则" >&2
                exit 1
            fi
            echo " [+] RDP模式: 允许已建立的连接"
        fi
        
        # 添加速率限制规则
        if ! iptables -A "$chain_name" -p "$protocol" --dport "$port" \
                       -m conntrack --ctstate NEW \
                       -m limit --limit "$limit" --limit-burst "$burst" -j ACCEPT 2>/dev/null; then
            echo "错误: 无法添加速率限制规则" >&2
            exit 1
        fi

        # 启用日志时，在DROP前记录被拒绝的连接
        if [ "$enable_log" = true ]; then
            if ! iptables -A "$chain_name" -p "$protocol" --dport "$port" \
                           -m limit --limit 1/min --limit-burst 5 \
                           -j LOG --log-prefix "PORT-PROTECT-DROP-$port: " --log-level 4 2>/dev/null; then
                echo "警告: 无法添加日志规则" >&2
            else
                echo " [+] 已启用日志记录（速率限制：1/min）"
            fi
        fi

        # 添加拒绝规则
        if ! iptables -A "$chain_name" -p "$protocol" --dport "$port" -j DROP 2>/dev/null; then
            echo "错误: 无法添加拒绝规则" >&2
            exit 1
        fi
    fi
    
    # 检查INPUT链中是否已存在相同规则
    if iptables -C INPUT -p "$protocol" --dport "$port" -j "$chain_name" 2>/dev/null; then
        echo " [!] INPUT链中已存在相同规则，跳过添加"
    else
        # 将自定义链挂载到INPUT链
        if ! iptables -I INPUT -p "$protocol" --dport "$port" -j "$chain_name" 2>/dev/null; then
            echo "错误: 无法将规则添加到INPUT链" >&2
            exit 1
        fi
        echo " [+] 将规则添加到INPUT链"
    fi
    
    echo "✅ 已成功添加端口 $port/$protocol 的防护规则"
    if [ "$rdp_mode" = true ]; then
        echo "   - RDP优化模式: 速率限制 $limit (突发: $burst)"
        echo "   - 已建立连接: 无限制"
    elif [ "$whitelist_only" = true ]; then
        echo "   - 白名单模式: 仅允许可信IP访问"
    elif [ "$strict_mode" = true ]; then
        echo "   - 严格模式: 速率限制 $limit (突发: $burst) - 高安全防护"
    else
        echo "   - 标准模式: 速率限制 $limit (突发: $burst)"
    fi
    if [ ${#trusted_ips[@]} -gt 0 ]; then
        echo "   - 可信IP: ${trusted_ips[*]}"
    fi
    echo "   - 自定义链: $chain_name"
}

# 移除iptables规则
remove_rules() {
    local port=$1
    local protocol="${2:-tcp}"
    local user_chain="${3:-}" # 用户显式传入的链名（可为空）

    # 优先使用用户指定，其次尝试新格式 <CHAIN_NAME>-<port>，最后回退旧共享链
    local chain_candidates=()
    if [ -n "$user_chain" ]; then
        chain_candidates+=("$user_chain")
    fi
    chain_candidates+=("${CHAIN_NAME}-${port}" "$CHAIN_NAME")

    local found_chain=""
    for c in "${chain_candidates[@]}"; do
        if iptables -L "$c" >/dev/null 2>&1; then
            found_chain="$c"
            break
        fi
    done

    if [ -z "$found_chain" ]; then
        echo "⚠️  未找到与端口 $port 相关的链 (尝试: ${chain_candidates[*]})"
        return 0
    fi

    local chain_name="$found_chain"

    # 从INPUT链移除引用（只针对该端口）
    local removed=false
    while iptables -C INPUT -p "$protocol" --dport "$port" -j "$chain_name" 2>/dev/null; do
        if iptables -D INPUT -p "$protocol" --dport "$port" -j "$chain_name" 2>/dev/null; then
            echo " [-] 从INPUT链移除规则 ($port)"
            removed=true
        else
            echo "警告: 无法从INPUT链移除规则 ($port)" >&2
            break
        fi
    done

    # 如果链是专用链 (名称结尾为 -<port>) 且不再被引用则删除
    local chain_refs=$(iptables -S | grep -c "\-j $chain_name" || true)
    if [[ "$chain_name" == *"-${port}" ]] && [ "$chain_refs" -eq 0 ]; then
        if iptables -F "$chain_name" 2>/dev/null && iptables -X "$chain_name" 2>/dev/null; then
            echo " [-] 删除专用链: $chain_name"
        else
            echo "警告: 无法删除链 $chain_name" >&2
        fi
    elif [ "$chain_refs" -eq 0 ]; then
        echo " [!] 共享链 $chain_name 当前无引用（保留以兼容其它端口历史规则）"
    else
        echo " [!] 链 $chain_name 仍被其它端口引用 ($chain_refs)"
    fi

    if [ "$removed" = true ]; then
        echo "✅ 已成功移除端口 $port/$protocol 的防护规则 (链: $chain_name)"
    else
        echo "⚠️  未找到端口 $port/$protocol 的INPUT引用 (链: $chain_name)"
    fi
}

# 显示当前状态
show_status() {
    echo "当前端口保护状态:"
    echo "========================================"

    # 获取所有相关的链（包括旧版共享链和新版独立链）
    local all_chains=$(iptables -S 2>/dev/null | grep -oE "\-j ${CHAIN_NAME}(-[0-9]+)?" | sed 's/-j //' | sort -u)

    if [ -n "$all_chains" ]; then
        echo "发现以下防护链:"
        echo
        while IFS= read -r chain; do
            if iptables -L "$chain" >/dev/null 2>&1; then
                echo "链名称: $chain"
                echo "----------------------------------------"
                iptables -L "$chain" -n --line-numbers 2>/dev/null

                # 显示INPUT链中对此链的引用
                echo
                echo "INPUT链引用:"
                iptables -S INPUT 2>/dev/null | grep "\-j $chain" || echo "  (未找到引用)"
                echo "========================================"
                echo
            fi
        done <<< "$all_chains"
    else
        echo "未找到任何防护链"
        echo
    fi

    # 显示所有受保护的端口概览
    echo "受保护端口概览:"
    echo "----------------------------------------"
    list_ports

    echo
    echo "备份信息:"
    echo "----------------------------------------"
    if [ -f "$CURRENT_BACKUP" ]; then
        echo "当前备份: $(ls -l "$CURRENT_BACKUP" 2>/dev/null | awk '{print $6, $7, $8, $9}')"
    else
        echo "当前备份: 无"
    fi

    local backup_count=$(ls "$BACKUP_DIR"/*.rules 2>/dev/null | wc -l)
    echo "备份文件总数: $backup_count"
}

# 列出已受保护端口（解析 INPUT 链跳转及独立链内规则）
list_ports() {
    echo "已受保护端口列表 (按链归类):"
    echo "----------------------------------------"
    # 收集 INPUT 链中跳转记录
    iptables -S INPUT 2>/dev/null | grep -E "-j (${CHAIN_NAME}(-[0-9]+)?)" | while read -r line; do
        # 提取 --dport 与链名
        local port=$(echo "$line" | sed -n 's/.*--dport \([0-9]\+\).*/\1/p')
        local proto=$(echo "$line" | sed -n 's/.*-p \(tcp\|udp\).*/\1/p')
        local chain=$(echo "$line" | sed -n "s/.*-j \(${CHAIN_NAME}[-0-9]*\).*/\1/p")
        if [ -n "$port" ]; then
            echo "链: $chain  端口: $port/$proto"
        fi
    done | sort -u || true
    echo "----------------------------------------"
    echo "提示: 默认每个端口使用独立链 ${CHAIN_NAME}-<port>。使用 --chain 可共享。"
}

# 主函数
main() {
    check_root
    check_dependencies
    init_environment
    
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command=$1
    shift
    
    case "$command" in
        add)
            if [ $# -lt 1 ]; then
                echo "错误: 需要指定端口号" >&2
                show_help
                exit 1
            fi
            local port=$1
            shift
            validate_port "$port"
            add_rules "$port" "$@"
            ;;
            
        remove)
            if [ $# -lt 1 ]; then
                echo "错误: 需要指定端口号" >&2
                show_help
                exit 1
            fi
            local port=$1
            shift
            validate_port "$port"

            # 解析可选参数
            local protocol="tcp"
            local user_chain=""

            while [ $# -gt 0 ]; do
                case "$1" in
                    -p|--protocol)
                        if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                            echo "错误: --protocol 需要参数" >&2
                            exit 1
                        fi
                        protocol="$2"
                        if [[ ! "$protocol" =~ ^(tcp|udp)$ ]]; then
                            echo "错误: 协议必须是 tcp 或 udp" >&2
                            exit 1
                        fi
                        shift 2
                        ;;
                    -c|--chain)
                        if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                            echo "错误: --chain 需要参数" >&2
                            exit 1
                        fi
                        user_chain="$2"
                        shift 2
                        ;;
                    *)
                        echo "错误: 未知选项 $1" >&2
                        show_help
                        exit 1
                        ;;
                esac
            done

            remove_rules "$port" "$protocol" "$user_chain"
            ;;
            
        backup)
            backup_rules "$1"
            ;;
            
        restore)
            restore_rules "$1"
            ;;
            
        list-backups)
            list_backups
            ;;

        list-ports)
            list_ports
            ;;
            
        save)
            save_rules
            ;;
            
        status)
            show_status
            ;;
            
        help|--help|-h)
            show_help
            ;;
            
        *)
            echo "错误: 未知命令 '$command'" >&2
            echo "使用 '$0 help' 查看帮助信息" >&2
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"