#!/bin/bash

# 🌐 端口转发管理脚本
# 将本地端口数据转发到局域网指定主机端口
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
CONFIG_DIR="$SCRIPT_DIR/config"
LOG_DIR="$SCRIPT_DIR/logs"
PID_DIR="$SCRIPT_DIR/pids"

# 确保必要目录存在
mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$PID_DIR"

# 🔧 显示帮助信息
show_help() {
    cat << EOF
${WHITE}🌐 端口转发管理脚本${NC}

${CYAN}用法:${NC}
    $(basename $0) <命令> [选项]

${CYAN}命令:${NC}
    add <规则名>                 添加新的转发规则
    remove <规则名>              删除转发规则
    start <规则名>               启动指定规则
    stop <规则名>                停止指定规则
    restart <规则名>             重启指定规则
    list                         列出所有规则
    status [规则名]              查看规则状态
    logs <规则名>                查看转发日志

${CYAN}添加规则选项:${NC}
    -l, --local-port <端口>      本地监听端口 (必需)
    -h, --target-host <主机>     目标主机地址 (必需)
    -p, --target-port <端口>     目标端口 (必需)
    -m, --method <方法>          转发方法 (socat|nc|ssh|iptables) 默认: socat
    -d, --description <描述>     规则描述

${CYAN}示例:${NC}
    # 添加HTTP转发规则
    $(basename $0) add web-server -l 8080 -h 192.168.1.100 -p 80 -d "Web服务器转发"
    
    # 添加数据库转发规则
    $(basename $0) add mysql-db -l 3306 -h 192.168.1.200 -p 3306 -m iptables -d "MySQL数据库"
    
    # 添加SSH转发规则
    $(basename $0) add ssh-server -l 2222 -h 192.168.1.50 -p 22 -d "SSH服务器"
    
    # 启动转发
    $(basename $0) start web-server
    
    # 查看状态
    $(basename $0) status
    
    # 查看日志
    $(basename $0) logs web-server

${CYAN}转发方法说明:${NC}
    • ${GREEN}socat${NC}    - 高性能双向数据转发 (推荐)
    • ${BLUE}nc${NC}        - 轻量级网络工具转发
    • ${PURPLE}ssh${NC}     - SSH隧道转发 (需要SSH访问权限)
    • ${RED}iptables${NC}  - 内核级端口转发 (仅Linux，需要root权限)

EOF
}

# 🔍 检查依赖工具
check_dependencies() {
    local missing=()
    
    # 检查常用工具
    for tool in socat nc netstat; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️ 缺少以下工具:${NC}"
        for tool in "${missing[@]}"; do
            echo -e "  • $tool"
        done
        echo
        echo -e "${BLUE}💡 安装建议:${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "  ${GREEN}macOS:${NC} brew install socat netcat"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo -e "  ${GREEN}Ubuntu/Debian:${NC} sudo apt install socat netcat-openbsd net-tools"
            echo -e "  ${GREEN}CentOS/RHEL:${NC} sudo yum install socat nc net-tools"
        fi
        echo
    fi
}

# 📝 保存转发规则配置
save_rule() {
    local name="$1"
    local local_port="$2"
    local target_host="$3"
    local target_port="$4"
    local method="$5"
    local description="$6"
    
    local config_file="$CONFIG_DIR/$name.conf"
    
    cat > "$config_file" << EOF
# 端口转发规则配置
RULE_NAME="$name"
LOCAL_PORT="$local_port"
TARGET_HOST="$target_host"
TARGET_PORT="$target_port"
METHOD="$method"
DESCRIPTION="$description"
CREATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    
    echo -e "${GREEN}✅ 规则配置已保存: $config_file${NC}"
}

# 📖 加载转发规则配置
load_rule() {
    local name="$1"
    local config_file="$CONFIG_DIR/$name.conf"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ 规则不存在: $name${NC}" >&2
        return 1
    fi
    
    source "$config_file"
    return 0
}

# 🚀 启动端口转发
start_forwarding() {
    local name="$1"
    
    if ! load_rule "$name"; then
        return 1
    fi
    
    local pid_file="$PID_DIR/$name.pid"
    local log_file="$LOG_DIR/$name.log"
    
    # 检查是否已经运行
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ 转发规则 '$name' 已经在运行${NC}"
        return 0
    fi
    
    # 检查端口是否被占用
    if netstat -ln 2>/dev/null | grep -q ":$LOCAL_PORT "; then
        echo -e "${RED}❌ 本地端口 $LOCAL_PORT 已被占用${NC}" >&2
        return 1
    fi
    
    echo -e "${BLUE}🚀 启动端口转发...${NC}"
    echo -e "  📡 本地端口: ${GREEN}$LOCAL_PORT${NC}"
    echo -e "  🎯 目标地址: ${GREEN}$TARGET_HOST:$TARGET_PORT${NC}"
    echo -e "  🔧 转发方法: ${GREEN}$METHOD${NC}"
    
    case "$METHOD" in
        socat)
            nohup socat TCP-LISTEN:$LOCAL_PORT,fork,reuseaddr TCP:$TARGET_HOST:$TARGET_PORT \
                > "$log_file" 2>&1 &
            ;;
        nc)
            # 使用nc和命名管道实现双向转发
            local fifo="/tmp/nc_${name}_$$"
            mkfifo "$fifo"
            nohup sh -c "while true; do nc -l $LOCAL_PORT < $fifo | nc $TARGET_HOST $TARGET_PORT > $fifo; done" \
                > "$log_file" 2>&1 &
            ;;
        ssh)
            # SSH隧道转发 (需要SSH密钥认证)
            nohup ssh -N -L $LOCAL_PORT:$TARGET_HOST:$TARGET_PORT $TARGET_HOST \
                > "$log_file" 2>&1 &
            ;;
        iptables)
            # iptables 内核级转发
            if [ "$(uname)" != "Linux" ]; then
                echo -e "${RED}❌ iptables 转发仅适用于 Linux 系统${NC}" >&2
                return 1
            fi
            
            if [ "$(id -u)" != "0" ]; then
                echo -e "${RED}❌ iptables 转发需要 root 权限${NC}" >&2
                return 1
            fi
            
            # 启用IP转发
            echo 1 > /proc/sys/net/ipv4/ip_forward
            
            # 添加 DNAT 规则
            iptables -t nat -A PREROUTING -p tcp --dport "$LOCAL_PORT" -j DNAT --to-destination "$TARGET_HOST:$TARGET_PORT"
            # 添加 SNAT 规则
            iptables -t nat -A POSTROUTING -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j MASQUERADE
            # 添加 FORWARD 规则
            iptables -A FORWARD -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j ACCEPT
            iptables -A FORWARD -p tcp -s "$TARGET_HOST" --sport "$TARGET_PORT" -j ACCEPT
            
            # iptables 不需要后台进程，创建一个标记文件
            echo "iptables_rule_active" > "$pid_file"
            local pid="iptables"
            ;;
        *)
            echo -e "${RED}❌ 不支持的转发方法: $METHOD${NC}" >&2
            return 1
            ;;
    esac
    
    local pid=$!
    echo "$pid" > "$pid_file"
    
    # 等待一下检查是否启动成功
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}✅ 端口转发已启动 (PID: $pid)${NC}"
        echo -e "${CYAN}📋 规则: $DESCRIPTION${NC}"
    else
        echo -e "${RED}❌ 端口转发启动失败${NC}" >&2
        rm -f "$pid_file"
        return 1
    fi
}

# 🛑 停止端口转发
stop_forwarding() {
    local name="$1"
    local pid_file="$PID_DIR/$name.pid"
    
    if [ ! -f "$pid_file" ]; then
        echo -e "${YELLOW}⚠️ 转发规则 '$name' 未在运行${NC}"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    
    # 检查是否为 iptables 规则
    if [ "$pid" = "iptables" ]; then
        # 加载规则配置以获取参数
        if load_rule "$name"; then
            echo -e "${BLUE}🛑 停止 iptables 转发规则...${NC}"
            
            # 删除 iptables 规则
            iptables -t nat -D PREROUTING -p tcp --dport "$LOCAL_PORT" -j DNAT --to-destination "$TARGET_HOST:$TARGET_PORT" 2>/dev/null
            iptables -t nat -D POSTROUTING -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j MASQUERADE 2>/dev/null
            iptables -D FORWARD -p tcp -d "$TARGET_HOST" --dport "$TARGET_PORT" -j ACCEPT 2>/dev/null
            iptables -D FORWARD -p tcp -s "$TARGET_HOST" --sport "$TARGET_PORT" -j ACCEPT 2>/dev/null
            
            echo -e "${GREEN}✅ iptables 转发规则已停止${NC}"
        fi
    else
        # 处理其他转发方法的进程
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${BLUE}🛑 停止端口转发 (PID: $pid)...${NC}"
            kill "$pid"
            
            # 等待进程结束
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${YELLOW}⚠️ 强制终止进程...${NC}"
                kill -9 "$pid"
            fi
            
            echo -e "${GREEN}✅ 端口转发已停止${NC}"
        else
            echo -e "${YELLOW}⚠️ 进程不存在 (PID: $pid)${NC}"
        fi
    fi
    
    rm -f "$pid_file"
    
    # 清理nc创建的临时文件
    rm -f "/tmp/nc_${name}_"*
}

# 📋 列出所有转发规则
list_rules() {
    echo -e "${WHITE}📋 端口转发规则列表${NC}"
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
            
            local status="🔴 停止"
            local pid_file="$PID_DIR/$RULE_NAME.pid"
            
            if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
                status="🟢 运行"
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

# 📊 查看转发状态
show_status() {
    local name="$1"
    
    if [ -n "$name" ]; then
        # 显示单个规则状态
        if ! load_rule "$name"; then
            return 1
        fi
        
        echo -e "${WHITE}📊 转发规则状态: $name${NC}"
        echo
        echo -e "${CYAN}基本信息:${NC}"
        echo -e "  规则名称: $RULE_NAME"
        echo -e "  本地端口: $LOCAL_PORT"
        echo -e "  目标地址: $TARGET_HOST:$TARGET_PORT"
        echo -e "  转发方法: $METHOD"
        echo -e "  规则描述: $DESCRIPTION"
        echo -e "  创建时间: $CREATED_AT"
        echo
        
        local pid_file="$PID_DIR/$name.pid"
        local log_file="$LOG_DIR/$name.log"
        
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            
            if [ "$pid" = "iptables" ]; then
                # 检查 iptables 规则是否存在
                if iptables -t nat -L PREROUTING -n | grep -q "dpt:$LOCAL_PORT.*to:$TARGET_HOST:$TARGET_PORT"; then
                    echo -e "${GREEN}🟢 运行状态: iptables 规则已启用${NC}"
                else
                    echo -e "${RED}🔴 运行状态: iptables 规则不存在${NC}"
                fi
            elif kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}🟢 运行状态: 正在运行 (PID: $pid)${NC}"
                
                # 显示连接统计
                local connections=$(netstat -an 2>/dev/null | grep ":$LOCAL_PORT " | wc -l)
                echo -e "  当前连接数: $connections"
            else
                echo -e "${RED}🔴 运行状态: 已停止${NC}"
            fi
        else
            echo -e "${RED}🔴 运行状态: 已停止${NC}"
        fi
        
        echo
        echo -e "${CYAN}最近日志:${NC}"
        if [ -f "$log_file" ]; then
            tail -10 "$log_file" 2>/dev/null || echo "  (无日志信息)"
        else
            echo "  (无日志文件)"
        fi
    else
        # 显示所有规则的简要状态
        list_rules
    fi
}

# 📜 查看转发日志
show_logs() {
    local name="$1"
    local log_file="$LOG_DIR/$name.log"
    
    if [ ! -f "$log_file" ]; then
        echo -e "${YELLOW}⚠️ 日志文件不存在: $name${NC}"
        return 1
    fi
    
    echo -e "${WHITE}📜 转发日志: $name${NC}"
    echo "=================================================================="
    
    # 显示实时日志
    if [ -f "$PID_DIR/$name.pid" ] && kill -0 "$(cat "$PID_DIR/$name.pid")" 2>/dev/null; then
        echo -e "${GREEN}🔄 实时日志 (Ctrl+C 退出):${NC}"
        tail -f "$log_file"
    else
        echo -e "${BLUE}📖 历史日志:${NC}"
        cat "$log_file"
    fi
}

# ➕ 添加转发规则
add_rule() {
    local name=""
    local local_port=""
    local target_host=""
    local target_port=""
    local method="socat"
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
            -m|--method)
                method="$2"
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
        description="端口转发 $local_port -> $target_host:$target_port"
    fi
    
    # 保存规则
    save_rule "$name" "$local_port" "$target_host" "$target_port" "$method" "$description"
    
    echo -e "${GREEN}✅ 转发规则添加成功${NC}"
    echo -e "${BLUE}💡 使用以下命令启动转发:${NC}"
    echo -e "  $(basename $0) start $name"
}

# 🗑️ 删除转发规则
remove_rule() {
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
    
    # 先停止转发
    stop_forwarding "$name"
    
    # 删除配置文件
    rm -f "$config_file"
    
    # 删除日志文件
    rm -f "$LOG_DIR/$name.log"
    
    echo -e "${GREEN}✅ 转发规则已删除: $name${NC}"
}

# 🔄 重启转发
restart_forwarding() {
    local name="$1"
    
    echo -e "${BLUE}🔄 重启端口转发: $name${NC}"
    stop_forwarding "$name"
    sleep 1
    start_forwarding "$name"
}

# 🎯 主函数
main() {
    local command="$1"
    shift
    
    case "$command" in
        add)
            check_dependencies
            add_rule "$@"
            ;;
        remove|rm)
            remove_rule "$@"
            ;;
        start)
            check_dependencies
            start_forwarding "$@"
            ;;
        stop)
            stop_forwarding "$@"
            ;;
        restart)
            check_dependencies
            restart_forwarding "$@"
            ;;
        list|ls)
            list_rules
            ;;
        status)
            show_status "$@"
            ;;
        logs|log)
            show_logs "$@"
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
