#!/bin/bash

# nginx-manager.sh 功能测试脚本
# 测试主要功能是否正常工作

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试配置
TEST_DOMAIN="test.local"
SCRIPT_PATH="./nginx-manager.sh"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "检查系统环境..."
    
    # 检查是否为root权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此测试脚本需要root权限运行"
        exit 1
    fi
    
    # 检查nginx是否安装
    if ! command -v nginx &> /dev/null; then
        log_error "nginx未安装，请先安装nginx"
        exit 1
    fi
    
    # 检查脚本是否存在
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "nginx-manager.sh 脚本未找到"
        exit 1
    fi
    
    # 检查脚本是否可执行
    if [[ ! -x "$SCRIPT_PATH" ]]; then
        log_error "nginx-manager.sh 脚本没有执行权限"
        exit 1
    fi
    
    log_info "系统环境检查通过"
}

test_help() {
    log_info "测试帮助信息..."
    if $SCRIPT_PATH help > /dev/null 2>&1; then
        log_info "✓ 帮助信息正常"
    else
        log_error "✗ 帮助信息测试失败"
        return 1
    fi
}

test_status() {
    log_info "测试状态查看..."
    if $SCRIPT_PATH status > /dev/null 2>&1; then
        log_info "✓ 状态查看正常"
    else
        log_warn "⚠ 状态查看可能有问题（nginx可能未运行）"
    fi
}

test_list_sites() {
    log_info "测试站点列表..."
    if $SCRIPT_PATH list-sites > /dev/null 2>&1; then
        log_info "✓ 站点列表功能正常"
    else
        log_error "✗ 站点列表功能失败"
        return 1
    fi
}

test_add_static_site() {
    log_info "测试添加静态站点..."
    
    # 创建测试目录
    local test_dir="/tmp/nginx_test_$TEST_DOMAIN"
    mkdir -p "$test_dir"
    echo "<h1>Test Site for $TEST_DOMAIN</h1>" > "$test_dir/index.html"
    
    if $SCRIPT_PATH add-site "$TEST_DOMAIN" --root "$test_dir" --gzip > /dev/null 2>&1; then
        log_info "✓ 静态站点添加成功"
        
        # 检查配置文件是否创建
        if [[ -f "/etc/nginx/sites-available/$TEST_DOMAIN" ]]; then
            log_info "✓ 配置文件已创建"
        else
            log_error "✗ 配置文件未创建"
            return 1
        fi
        
        return 0
    else
        log_error "✗ 静态站点添加失败"
        return 1
    fi
}

test_enable_site() {
    log_info "测试启用站点..."
    if $SCRIPT_PATH enable-site "$TEST_DOMAIN" > /dev/null 2>&1; then
        log_info "✓ 站点启用成功"
        
        # 检查软链接是否创建
        if [[ -L "/etc/nginx/sites-enabled/$TEST_DOMAIN" ]]; then
            log_info "✓ 软链接已创建"
        else
            log_error "✗ 软链接未创建"
            return 1
        fi
        
        return 0
    else
        log_error "✗ 站点启用失败"
        return 1
    fi
}

test_nginx_config() {
    log_info "测试nginx配置..."
    if $SCRIPT_PATH test > /dev/null 2>&1; then
        log_info "✓ nginx配置语法正确"
    else
        log_error "✗ nginx配置语法错误"
        # 显示详细错误
        nginx -t
        return 1
    fi
}

test_disable_site() {
    log_info "测试禁用站点..."
    if $SCRIPT_PATH disable-site "$TEST_DOMAIN" > /dev/null 2>&1; then
        log_info "✓ 站点禁用成功"
        
        # 检查软链接是否删除
        if [[ ! -L "/etc/nginx/sites-enabled/$TEST_DOMAIN" ]]; then
            log_info "✓ 软链接已删除"
        else
            log_error "✗ 软链接未删除"
            return 1
        fi
        
        return 0
    else
        log_error "✗ 站点禁用失败"
        return 1
    fi
}

test_remove_site() {
    log_info "测试移除站点..."
    if $SCRIPT_PATH remove-site "$TEST_DOMAIN" > /dev/null 2>&1; then
        log_info "✓ 站点移除成功"
        
        # 检查配置文件是否删除
        if [[ ! -f "/etc/nginx/sites-available/$TEST_DOMAIN" ]]; then
            log_info "✓ 配置文件已删除"
        else
            log_error "✗ 配置文件未删除"
            return 1
        fi
        
        return 0
    else
        log_error "✗ 站点移除失败"
        return 1
    fi
}

test_backup() {
    log_info "测试配置备份..."
    local backup_name="test_backup_$(date +%s)"
    if $SCRIPT_PATH backup "$backup_name" > /dev/null 2>&1; then
        log_info "✓ 配置备份成功"
        
        # 检查备份文件是否存在
        if ls /var/backups/nginx/nginx_${backup_name}_*.tar.gz > /dev/null 2>&1; then
            log_info "✓ 备份文件已创建"
            # 清理测试备份
            rm -f /var/backups/nginx/nginx_${backup_name}_*.tar.gz
        else
            log_error "✗ 备份文件未创建"
            return 1
        fi
        
        return 0
    else
        log_error "✗ 配置备份失败"
        return 1
    fi
}

cleanup() {
    log_info "清理测试环境..."
    
    # 移除测试站点（如果存在）
    if [[ -f "/etc/nginx/sites-available/$TEST_DOMAIN" ]]; then
        $SCRIPT_PATH remove-site "$TEST_DOMAIN" > /dev/null 2>&1 || true
    fi
    
    # 删除测试目录
    rm -rf "/tmp/nginx_test_$TEST_DOMAIN"
    
    log_info "清理完成"
}

run_tests() {
    log_info "开始nginx-manager.sh功能测试..."
    echo
    
    local failed_tests=0
    
    # 运行测试
    test_help || ((failed_tests++))
    test_status || ((failed_tests++))
    test_list_sites || ((failed_tests++))
    test_add_static_site || ((failed_tests++))
    test_enable_site || ((failed_tests++))
    test_nginx_config || ((failed_tests++))
    test_disable_site || ((failed_tests++))
    test_remove_site || ((failed_tests++))
    test_backup || ((failed_tests++))
    
    echo
    if [[ $failed_tests -eq 0 ]]; then
        log_info "🎉 所有测试通过！nginx-manager.sh 功能正常"
        return 0
    else
        log_error "❌ $failed_tests 个测试失败"
        return 1
    fi
}

main() {
    # 设置错误时清理
    trap cleanup EXIT
    
    check_prerequisites
    echo
    
    run_tests
}

# 检查是否直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
