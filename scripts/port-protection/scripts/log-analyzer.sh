#!/bin/bash

# 全端口防护日志分析工具
# 用途：实时分析日志，生成报告，辅助决策
# 版本：1.0.0

set -euo pipefail

VERSION="1.0.0"
LOG_FILE="/var/log/global-port-protect.log"
LOG_PREFIX="GLOBAL-PORT-PROTECT: "

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

show_help() {
    cat << EOF
${GREEN}全端口防护日志分析工具${NC} - v${VERSION}

${YELLOW}使用方式：${NC} $0 [命令] [选项]

${YELLOW}命令：${NC}

  ${CYAN}report${NC}               生成综合分析报告
  ${CYAN}realtime${NC}             实时监控（持续显示新连接）
  ${CYAN}timeline${NC}             时间线分析（每小时统计）
  ${CYAN}geo${NC}                  地理位置分析（需要geoip）
  ${CYAN}attack-pattern${NC}       攻击模式识别
  ${CYAN}export${NC}               导出数据（JSON/CSV格式）

${YELLOW}选项：${NC}

  ${CYAN}-d, --date <日期>${NC}    指定日期（格式: YYYY-MM-DD）
  ${CYAN}-h, --hours <小时>${NC}   最近N小时的数据
  ${CYAN}-n, --limit <数量>${NC}   限制结果数量
  ${CYAN}-f, --format <格式>${NC}  输出格式（text/json/csv）

${YELLOW}示例：${NC}

  # 生成今日综合报告
  $0 report

  # 最近24小时的报告
  $0 report -h 24

  # 实时监控
  $0 realtime

  # 时间线分析
  $0 timeline -d 2025-11-03

  # 攻击模式识别
  $0 attack-pattern

  # 导出为JSON
  $0 export -f json > report.json

EOF
}

# 解析日志行
parse_log_line() {
    local line="$1"
    local timestamp=$(echo "$line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+')
    local src_ip=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
    local dst_port=$(echo "$line" | grep -oP 'DPT=\K[0-9]+')
    local protocol=$(echo "$line" | grep -oP 'PROTO=\K[A-Z]+')

    echo "$timestamp|$src_ip|$dst_port|$protocol"
}

# 生成综合报告
generate_report() {
    local hours=""
    local date=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--hours)
                hours="$2"
                shift 2
                ;;
            -d|--date)
                date="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        全端口防护 - 综合分析报告                               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "报告时间: $(date '+%Y-%m-%d %H:%M:%S')"
    [ -n "$hours" ] && echo "分析范围: 最近 $hours 小时"
    [ -n "$date" ] && echo "分析日期: $date"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local log_data
    if [ -f "$LOG_FILE" ]; then
        if [ -n "$date" ]; then
            log_data=$(grep "$LOG_PREFIX" "$LOG_FILE" | grep "$date" || true)
        elif [ -n "$hours" ]; then
            local cutoff=$(date -d "$hours hours ago" '+%b %d %H:%M:%S' 2>/dev/null || date -v-${hours}H '+%b %d %H:%M:%S')
            log_data=$(grep "$LOG_PREFIX" "$LOG_FILE" || true)
        else
            log_data=$(grep "$LOG_PREFIX" "$LOG_FILE" || true)
        fi
    else
        log_data=$(dmesg | grep "$LOG_PREFIX" || true)
    fi

    if [ -z "$log_data" ]; then
        echo -e "${YELLOW}没有找到日志数据${NC}"
        return
    fi

    # 1. 总体统计
    echo -e "\n${CYAN}【总体统计】${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local total=$(echo "$log_data" | wc -l)
    local unique_ips=$(echo "$log_data" | grep -oP 'SRC=\K[0-9.]+' | sort -u | wc -l)
    local unique_ports=$(echo "$log_data" | grep -oP 'DPT=\K[0-9]+' | sort -u | wc -l)

    printf "  总拒绝连接数: ${GREEN}%'d${NC}\n" "$total"
    printf "  唯一源IP数:   ${GREEN}%'d${NC}\n" "$unique_ips"
    printf "  被扫描端口数: ${GREEN}%'d${NC}\n" "$unique_ports"

    # 2. 攻击来源 Top 10
    echo -e "\n${CYAN}【Top 10 攻击来源IP】${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$log_data" | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn | head -10 | \
        awk '{printf "  %2d. %-15s : %s 次\n", NR, $2, $1}'

    # 3. 被扫描端口 Top 10
    echo -e "\n${CYAN}【Top 10 被扫描端口】${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$log_data" | grep -oP 'DPT=\K[0-9]+' | sort | uniq -c | sort -rn | head -10 | \
        awk '{
            port_name="";
            if ($2 == 22) port_name="(SSH)";
            else if ($2 == 80) port_name="(HTTP)";
            else if ($2 == 443) port_name="(HTTPS)";
            else if ($2 == 3389) port_name="(RDP)";
            else if ($2 == 3306) port_name="(MySQL)";
            else if ($2 == 5432) port_name="(PostgreSQL)";
            else if ($2 == 6379) port_name="(Redis)";
            else if ($2 == 27017) port_name="(MongoDB)";
            printf "  %2d. 端口 %-6s %-12s : %s 次\n", NR, $2, port_name, $1
        }'

    # 4. 协议分布
    echo -e "\n${CYAN}【协议分布】${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$log_data" | grep -oP 'PROTO=\K[A-Z]+' | sort | uniq -c | sort -rn | \
        awk -v total="$total" '{
            percentage = ($1 / total) * 100
            printf "  %-6s : %6d 次 (%.1f%%)\n", $2, $1, percentage
        }'

    # 5. 高频攻击者（超过100次）
    echo -e "\n${CYAN}【高频攻击者（>100次）】${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local high_freq=$(echo "$log_data" | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn | \
        awk '$1 > 100 {printf "  %-15s : %s 次\n", $2, $1}')

    if [ -n "$high_freq" ]; then
        echo "$high_freq"
        echo
        echo -e "${YELLOW}  建议: 使用以下命令封禁这些IP${NC}"
        echo "$log_data" | grep -oP 'SRC=\K[0-9.]+' | sort | uniq -c | sort -rn | \
            awk '$1 > 100 {printf "  sudo ./blacklist-manager.sh ban %s --reason \"High attack rate: %s\" --duration 30d\n", $2, $1}'
    else
        echo "  无高频攻击者"
    fi

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "报告生成完成"
}

# 实时监控
realtime_monitor() {
    echo -e "${CYAN}实时监控模式 (Ctrl+C 退出)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "时间                 源IP              端口    协议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE" | grep --line-buffered "$LOG_PREFIX" | while read -r line; do
            local timestamp=$(echo "$line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+')
            local src_ip=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
            local dst_port=$(echo "$line" | grep -oP 'DPT=\K[0-9]+')
            local protocol=$(echo "$line" | grep -oP 'PROTO=\K[A-Z]+')

            printf "${YELLOW}%-20s${NC} ${RED}%-15s${NC} ${GREEN}%-7s${NC} ${BLUE}%-s${NC}\n" \
                "$timestamp" "$src_ip" "$dst_port" "$protocol"
        done
    else
        dmesg -w | grep --line-buffered "$LOG_PREFIX" | while read -r line; do
            local timestamp=$(echo "$line" | grep -oP '^\[\s*[0-9.]+\]')
            local src_ip=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
            local dst_port=$(echo "$line" | grep -oP 'DPT=\K[0-9]+')
            local protocol=$(echo "$line" | grep -oP 'PROTO=\K[A-Z]+')

            printf "${YELLOW}%-20s${NC} ${RED}%-15s${NC} ${GREEN}%-7s${NC} ${BLUE}%-s${NC}\n" \
                "$timestamp" "$src_ip" "$dst_port" "$protocol"
        done
    fi
}

# 时间线分析
timeline_analysis() {
    local date=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--date)
                date="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    echo -e "${CYAN}时间线分析 - 每小时连接数${NC}"
    [ -n "$date" ] && echo "日期: $date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local log_data
    if [ -f "$LOG_FILE" ]; then
        if [ -n "$date" ]; then
            log_data=$(grep "$LOG_PREFIX" "$LOG_FILE" | grep "$date" || true)
        else
            log_data=$(grep "$LOG_PREFIX" "$LOG_FILE" || true)
        fi
    else
        log_data=$(dmesg | grep "$LOG_PREFIX" || true)
    fi

    if [ -z "$log_data" ]; then
        echo "没有找到日志数据"
        return
    fi

    # 按小时统计
    echo "$log_data" | grep -oP '\w+\s+\d+\s+\K\d+' | sort | uniq -c | \
        awk '{
            hour = $2
            count = $1
            # 生成柱状图
            bar = ""
            for (i = 0; i < count / 10; i++) {
                bar = bar "█"
            }
            printf "  %02d:00 - %02d:59  |  %5d 次  %s\n", hour, hour, count, bar
        }'
}

# 攻击模式识别
attack_pattern() {
    echo -e "${CYAN}攻击模式识别${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local log_data
    if [ -f "$LOG_FILE" ]; then
        log_data=$(grep "$LOG_PREFIX" "$LOG_FILE" || true)
    else
        log_data=$(dmesg | grep "$LOG_PREFIX" || true)
    fi

    # 1. 端口扫描检测
    echo -e "\n${YELLOW}【端口扫描检测】${NC}"
    echo "扫描超过10个不同端口的IP："
    echo "$log_data" | awk '{
        match($0, /SRC=([0-9.]+)/, src);
        match($0, /DPT=([0-9]+)/, dpt);
        if (src[1] && dpt[1]) {
            ips[src[1]][dpt[1]] = 1
        }
    } END {
        for (ip in ips) {
            port_count = 0
            for (port in ips[ip]) {
                port_count++
            }
            if (port_count > 10) {
                printf "  %-15s : 扫描了 %d 个端口\n", ip, port_count
            }
        }
    }'

    # 2. 高频连接检测
    echo -e "\n${YELLOW}【高频连接检测】${NC}"
    echo "每分钟连接超过10次的IP："
    echo "$log_data" | awk '{
        match($0, /(\w+ +\d+ +\d+:\d+)/, time);
        match($0, /SRC=([0-9.]+)/, src);
        if (time[1] && src[1]) {
            connections[src[1]][time[1]]++
        }
    } END {
        for (ip in connections) {
            for (minute in connections[ip]) {
                if (connections[ip][minute] > 10) {
                    printf "  %-15s : %s - %d 次\n", ip, minute, connections[ip][minute]
                }
            }
        }
    }' | head -20

    # 3. 常见服务扫描
    echo -e "\n${YELLOW}【常见服务扫描】${NC}"
    local common_ports="22,80,443,3306,3389,5432,6379,8080,27017"
    echo "扫描常见服务端口的次数："
    echo "$log_data" | grep -oP 'DPT=\K[0-9]+' | grep -E "^($common_ports)$" | sort | uniq -c | sort -rn | \
        awk '{
            port_name="";
            if ($2 == 22) port_name="SSH";
            else if ($2 == 80) port_name="HTTP";
            else if ($2 == 443) port_name="HTTPS";
            else if ($2 == 3389) port_name="RDP";
            else if ($2 == 3306) port_name="MySQL";
            else if ($2 == 5432) port_name="PostgreSQL";
            else if ($2 == 6379) port_name="Redis";
            else if ($2 == 8080) port_name="HTTP-Alt";
            else if ($2 == 27017) port_name="MongoDB";
            printf "  %-6s (%-12s) : %d 次\n", $2, port_name, $1
        }'
}

# 导出数据
export_data() {
    local format="json"

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|--format)
                format="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local log_data
    if [ -f "$LOG_FILE" ]; then
        log_data=$(grep "$LOG_PREFIX" "$LOG_FILE" || true)
    else
        log_data=$(dmesg | grep "$LOG_PREFIX" || true)
    fi

    if [ "$format" = "json" ]; then
        echo "["
        echo "$log_data" | while read -r line; do
            local timestamp=$(echo "$line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+')
            local src_ip=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
            local dst_port=$(echo "$line" | grep -oP 'DPT=\K[0-9]+')
            local protocol=$(echo "$line" | grep -oP 'PROTO=\K[A-Z]+')

            cat << EOF
  {
    "timestamp": "$timestamp",
    "source_ip": "$src_ip",
    "destination_port": "$dst_port",
    "protocol": "$protocol"
  },
EOF
        done | sed '$ s/,$//'
        echo "]"
    elif [ "$format" = "csv" ]; then
        echo "timestamp,source_ip,destination_port,protocol"
        echo "$log_data" | while read -r line; do
            local timestamp=$(echo "$line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+')
            local src_ip=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
            local dst_port=$(echo "$line" | grep -oP 'DPT=\K[0-9]+')
            local protocol=$(echo "$line" | grep -oP 'PROTO=\K[A-Z]+')

            echo "$timestamp,$src_ip,$dst_port,$protocol"
        done
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        report)
            shift
            generate_report "$@"
            ;;
        realtime)
            realtime_monitor
            ;;
        timeline)
            shift
            timeline_analysis "$@"
            ;;
        attack-pattern)
            attack_pattern
            ;;
        export)
            shift
            export_data "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}未知命令: $1${NC}"
            echo
            show_help
            exit 1
            ;;
    esac
}

main "$@"
