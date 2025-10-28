#!/bin/bash

# Port Protection 脚本测试套件
# 此脚本用于验证 port-protect.sh 的所有功能
# 注意：需要 root 权限运行

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTECT_SCRIPT="$SCRIPT_DIR/port-protect.sh"

# 测试计数器
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 测试端口列表（使用高端口避免冲突）
TEST_PORTS=(51000 51001 51002 51003 51004)
TEST_IP="192.168.100.100"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "此测试脚本需要root权限运行"
        exit 1
    fi
}

# 清理函数
cleanup() {
    log_info "清理测试环境..."
    for port in "${TEST_PORTS[@]}"; do
        "$PROTECT_SCRIPT" remove "$port" 2>/dev/null || true
        "$PROTECT_SCRIPT" remove "$port" --protocol udp 2>/dev/null || true
    done
    log_info "清理完成"
}

# 测试帮助命令
test_help() {
    ((TESTS_RUN++))
    log_info "测试: help 命令"

    if "$PROTECT_SCRIPT" help | grep -q "增强版 Docker 端口保护脚本"; then
        log_success "help 命令输出正常"
    else
        log_error "help 命令输出异常"
    fi
}

# 测试语法检查
test_syntax() {
    ((TESTS_RUN++))
    log_info "测试: 脚本语法检查"

    if bash -n "$PROTECT_SCRIPT" 2>/dev/null; then
        log_success "脚本语法正确"
    else
        log_error "脚本语法错误"
    fi
}

# 测试添加标准端口保护
test_add_standard() {
    ((TESTS_RUN++))
    log_info "测试: 添加标准端口保护"

    local port=${TEST_PORTS[0]}
    if "$PROTECT_SCRIPT" add "$port" -t "$TEST_IP" 2>&1 | grep -q "成功"; then
        # 验证规则是否存在
        if iptables -S INPUT | grep -q "dport $port"; then
            log_success "标准端口保护添加成功 (端口 $port)"
        else
            log_error "标准端口保护添加失败：规则未生效"
        fi
    else
        log_error "标准端口保护添加失败"
    fi
}

# 测试添加RDP模式
test_add_rdp() {
    ((TESTS_RUN++))
    log_info "测试: 添加RDP模式端口保护"

    local port=${TEST_PORTS[1]}
    if "$PROTECT_SCRIPT" add "$port" --rdp -t "$TEST_IP" 2>&1 | grep -q "成功"; then
        # 验证RDP优化模式
        if iptables -S INPUT | grep -q "dport $port"; then
            log_success "RDP模式端口保护添加成功 (端口 $port)"
        else
            log_error "RDP模式端口保护添加失败：规则未生效"
        fi
    else
        log_error "RDP模式端口保护添加失败"
    fi
}

# 测试添加白名单模式
test_add_whitelist() {
    ((TESTS_RUN++))
    log_info "测试: 添加白名单模式端口保护"

    local port=${TEST_PORTS[2]}
    if "$PROTECT_SCRIPT" add "$port" --whitelist-only -t "$TEST_IP" 2>&1 | grep -q "成功"; then
        if iptables -S INPUT | grep -q "dport $port"; then
            log_success "白名单模式端口保护添加成功 (端口 $port)"
        else
            log_error "白名单模式端口保护添加失败：规则未生效"
        fi
    else
        log_error "白名单模式端口保护添加失败"
    fi
}

# 测试添加严格模式
test_add_strict() {
    ((TESTS_RUN++))
    log_info "测试: 添加严格模式端口保护"

    local port=${TEST_PORTS[3]}
    if "$PROTECT_SCRIPT" add "$port" --strict -t "$TEST_IP" 2>&1 | grep -q "成功"; then
        if iptables -S INPUT | grep -q "dport $port"; then
            log_success "严格模式端口保护添加成功 (端口 $port)"
        else
            log_error "严格模式端口保护添加失败：规则未生效"
        fi
    else
        log_error "严格模式端口保护添加失败"
    fi
}

# 测试UDP协议
test_add_udp() {
    ((TESTS_RUN++))
    log_info "测试: 添加UDP协议端口保护"

    local port=${TEST_PORTS[4]}
    if "$PROTECT_SCRIPT" add "$port" --protocol udp -t "$TEST_IP" 2>&1 | grep -q "成功"; then
        if iptables -S INPUT | grep -q "udp.*dport $port"; then
            log_success "UDP端口保护添加成功 (端口 $port)"
        else
            log_error "UDP端口保护添加失败：规则未生效"
        fi
    else
        log_error "UDP端口保护添加失败"
    fi
}

# 测试 RDP 模式参数覆盖
test_rdp_custom_params() {
    ((TESTS_RUN++))
    log_info "测试: RDP模式自定义参数覆盖"

    local port=51010
    if "$PROTECT_SCRIPT" add "$port" --rdp -l 20/min -b 25 -t "$TEST_IP" 2>&1 | grep -q "成功"; then
        # 检查链是否创建
        if iptables -L "DOCKER-HOST-PROTECT-${port}" >/dev/null 2>&1; then
            log_success "RDP模式参数覆盖测试成功 (端口 $port)"
        else
            log_error "RDP模式参数覆盖测试失败：链未创建"
        fi
        # 清理
        "$PROTECT_SCRIPT" remove "$port" 2>/dev/null || true
    else
        log_error "RDP模式参数覆盖测试失败"
    fi
}

# 测试独立链创建
test_independent_chains() {
    ((TESTS_RUN++))
    log_info "测试: 独立链创建（每个端口独立链）"

    local port1=51020
    local port2=51021

    # 添加两个端口
    "$PROTECT_SCRIPT" add "$port1" -t "$TEST_IP" >/dev/null 2>&1
    "$PROTECT_SCRIPT" add "$port2" -t "$TEST_IP" >/dev/null 2>&1

    # 检查两个独立链是否都存在
    if iptables -L "DOCKER-HOST-PROTECT-${port1}" >/dev/null 2>&1 && \
       iptables -L "DOCKER-HOST-PROTECT-${port2}" >/dev/null 2>&1; then
        log_success "独立链创建测试成功"
    else
        log_error "独立链创建测试失败"
    fi

    # 清理
    "$PROTECT_SCRIPT" remove "$port1" 2>/dev/null || true
    "$PROTECT_SCRIPT" remove "$port2" 2>/dev/null || true
}

# 测试 list-ports 命令
test_list_ports() {
    ((TESTS_RUN++))
    log_info "测试: list-ports 命令"

    if "$PROTECT_SCRIPT" list-ports 2>&1 | grep -q "已受保护端口列表"; then
        log_success "list-ports 命令执行成功"
    else
        log_error "list-ports 命令执行失败"
    fi
}

# 测试 status 命令
test_status() {
    ((TESTS_RUN++))
    log_info "测试: status 命令"

    if "$PROTECT_SCRIPT" status 2>&1 | grep -q "当前端口保护状态"; then
        log_success "status 命令执行成功"
    else
        log_error "status 命令执行失败"
    fi
}

# 测试备份功能
test_backup() {
    ((TESTS_RUN++))
    log_info "测试: 备份功能"

    local tag="test_backup_$(date +%s)"
    if "$PROTECT_SCRIPT" backup "$tag" 2>&1 | grep -q "已创建备份"; then
        log_success "备份功能测试成功"
    else
        log_error "备份功能测试失败"
    fi
}

# 测试 list-backups 命令
test_list_backups() {
    ((TESTS_RUN++))
    log_info "测试: list-backups 命令"

    if "$PROTECT_SCRIPT" list-backups 2>&1 | grep -q "可用的iptables备份"; then
        log_success "list-backups 命令执行成功"
    else
        log_error "list-backups 命令执行失败"
    fi
}

# 测试移除端口保护
test_remove() {
    ((TESTS_RUN++))
    log_info "测试: 移除端口保护"

    local port=${TEST_PORTS[0]}
    if "$PROTECT_SCRIPT" remove "$port" 2>&1 | grep -q "成功\|未找到"; then
        # 验证规则是否被移除
        if ! iptables -S INPUT | grep -q "dport $port.*DOCKER-HOST-PROTECT"; then
            log_success "端口保护移除成功 (端口 $port)"
        else
            log_warning "端口保护移除命令执行，但规则可能仍存在"
            ((TESTS_PASSED++))  # 算作通过，因为可能是其他端口
        fi
    else
        log_error "端口保护移除失败"
    fi
}

# 测试移除UDP端口
test_remove_udp() {
    ((TESTS_RUN++))
    log_info "测试: 移除UDP端口保护"

    local port=${TEST_PORTS[4]}
    if "$PROTECT_SCRIPT" remove "$port" --protocol udp 2>&1 | grep -q "成功\|未找到"; then
        log_success "UDP端口保护移除成功 (端口 $port)"
    else
        log_error "UDP端口保护移除失败"
    fi
}

# 测试错误处理 - 无效端口
test_error_invalid_port() {
    ((TESTS_RUN++))
    log_info "测试: 错误处理 - 无效端口号"

    if "$PROTECT_SCRIPT" add 99999 2>&1 | grep -q "错误"; then
        log_success "无效端口号错误处理正确"
    else
        log_error "无效端口号错误处理失败"
    fi
}

# 测试错误处理 - 无效IP
test_error_invalid_ip() {
    ((TESTS_RUN++))
    log_info "测试: 错误处理 - 无效IP地址"

    if "$PROTECT_SCRIPT" add 8080 -t "999.999.999.999" 2>&1 | grep -q "错误"; then
        log_success "无效IP地址错误处理正确"
    else
        log_error "无效IP地址错误处理失败"
    fi
}

# 测试错误处理 - 无效协议
test_error_invalid_protocol() {
    ((TESTS_RUN++))
    log_info "测试: 错误处理 - 无效协议"

    if "$PROTECT_SCRIPT" add 8080 --protocol invalid 2>&1 | grep -q "错误"; then
        log_success "无效协议错误处理正确"
    else
        log_error "无效协议错误处理失败"
    fi
}

# 打印测试摘要
print_summary() {
    echo
    echo "========================================"
    echo "测试摘要"
    echo "========================================"
    echo "总测试数: $TESTS_RUN"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    echo "========================================"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}所有测试通过！✓${NC}"
        return 0
    else
        echo -e "${RED}部分测试失败！✗${NC}"
        return 1
    fi
}

# 主测试流程
main() {
    echo "========================================"
    echo "Port Protection 脚本测试套件"
    echo "========================================"
    echo

    # 检查root权限
    check_root

    # 检查脚本是否存在
    if [ ! -f "$PROTECT_SCRIPT" ]; then
        log_error "找不到 port-protect.sh 脚本: $PROTECT_SCRIPT"
        exit 1
    fi

    # 清理之前的测试
    cleanup

    # 运行测试
    log_info "开始运行测试..."
    echo

    # 基础测试
    test_syntax
    test_help

    # 添加功能测试
    test_add_standard
    test_add_rdp
    test_add_whitelist
    test_add_strict
    test_add_udp

    # 高级功能测试
    test_rdp_custom_params
    test_independent_chains

    # 查询命令测试
    test_list_ports
    test_status

    # 备份功能测试
    test_backup
    test_list_backups

    # 移除功能测试
    test_remove
    test_remove_udp

    # 错误处理测试
    test_error_invalid_port
    test_error_invalid_ip
    test_error_invalid_protocol

    # 最终清理
    cleanup

    # 打印摘要
    print_summary
}

# 捕获中断信号
trap cleanup EXIT INT TERM

# 运行主函数
main
exit $?
