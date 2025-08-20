#!/bin/bash

# 测试自定义nginx配置路径功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建测试环境
setup_test_env() {
    local test_dir="/tmp/nginx_test_config"
    
    log_info "创建测试环境: $test_dir"
    
    # 清理旧的测试环境
    rm -rf "$test_dir"
    
    # 创建测试目录结构
    mkdir -p "$test_dir"/{sites-available,sites-enabled,conf.d}
    
    # 创建基本的nginx.conf
    cat > "$test_dir/nginx.conf" << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 包含虚拟主机配置
    include CUSTOM_DIR/sites-enabled/*;
}
EOF
    
    # 替换自定义目录路径
    sed -i "s|CUSTOM_DIR|$test_dir|g" "$test_dir/nginx.conf"
    
    echo "$test_dir"
}

# 测试基本功能
test_basic_functionality() {
    local test_dir="$1"
    local script_path="./nginx-manager.sh"
    
    log_info "测试基本功能..."
    
    # 测试帮助信息
    if $script_path --help > /dev/null 2>&1; then
        log_info "✓ 帮助信息正常"
    else
        log_error "✗ 帮助信息失败"
        return 1
    fi
    
    # 测试状态查看（使用自定义配置）
    log_info "测试自定义配置路径状态查看..."
    if $script_path -c "$test_dir" status 2>/dev/null; then
        log_info "✓ 自定义配置路径状态查看正常"
    else
        log_warn "⚠ 自定义配置路径状态查看（nginx可能未运行）"
    fi
}

# 测试站点操作
test_site_operations() {
    local test_dir="$1"
    local script_path="./nginx-manager.sh"
    local test_domain="test.local"
    
    log_info "测试站点操作..."
    
    # 创建测试网站目录
    local web_dir="/tmp/nginx_test_web"
    mkdir -p "$web_dir"
    echo "<h1>Test Site</h1>" > "$web_dir/index.html"
    
    # 测试添加站点
    if $script_path -c "$test_dir" add-site "$test_domain" --root "$web_dir" --gzip 2>/dev/null; then
        log_info "✓ 添加站点成功"
        
        # 检查配置文件是否创建
        if [[ -f "$test_dir/sites-available/$test_domain" ]]; then
            log_info "✓ 配置文件已创建"
        else
            log_error "✗ 配置文件未创建"
            return 1
        fi
        
        # 测试启用站点
        if $script_path -c "$test_dir" enable-site "$test_domain" 2>/dev/null; then
            log_info "✓ 站点启用成功"
            
            # 检查软链接
            if [[ -L "$test_dir/sites-enabled/$test_domain" ]]; then
                log_info "✓ 软链接已创建"
            else
                log_error "✗ 软链接未创建"
                return 1
            fi
        else
            log_error "✗ 站点启用失败"
            return 1
        fi
        
        # 测试列出站点
        if $script_path -c "$test_dir" list-sites 2>/dev/null | grep -q "$test_domain"; then
            log_info "✓ 站点列表显示正常"
        else
            log_error "✗ 站点列表显示异常"
            return 1
        fi
        
        # 测试禁用站点
        if $script_path -c "$test_dir" disable-site "$test_domain" 2>/dev/null; then
            log_info "✓ 站点禁用成功"
        else
            log_error "✗ 站点禁用失败"
            return 1
        fi
        
        # 测试移除站点
        if $script_path -c "$test_dir" remove-site "$test_domain" 2>/dev/null; then
            log_info "✓ 站点移除成功"
        else
            log_error "✗ 站点移除失败"
            return 1
        fi
        
    else
        log_error "✗ 添加站点失败"
        return 1
    fi
    
    # 清理测试目录
    rm -rf "$web_dir"
}

# 测试文档生成
test_docs_generation() {
    local test_dir="$1"
    local script_path="./nginx-manager.sh"
    
    log_info "测试文档生成..."
    
    # 生成文档
    if $script_path -c "$test_dir" generate-docs 2>/dev/null; then
        log_info "✓ 文档生成成功"
        
        # 检查文档是否包含自定义路径信息
        local doc_file=$(ls nginx_config_docs_*.md 2>/dev/null | head -1)
        if [[ -n "$doc_file" && -f "$doc_file" ]]; then
            if grep -q "$test_dir" "$doc_file"; then
                log_info "✓ 文档包含自定义配置路径信息"
            else
                log_error "✗ 文档未包含自定义配置路径信息"
                return 1
            fi
            
            # 清理文档
            rm -f "$doc_file"
        else
            log_error "✗ 文档文件未生成"
            return 1
        fi
    else
        log_error "✗ 文档生成失败"
        return 1
    fi
}

# 清理测试环境
cleanup_test_env() {
    local test_dir="$1"
    
    log_info "清理测试环境..."
    rm -rf "$test_dir"
    rm -f nginx_config_docs_*.md
}

# 主函数
main() {
    log_info "开始测试自定义nginx配置路径功能..."
    echo
    
    # 检查脚本是否存在
    if [[ ! -f "./nginx-manager.sh" ]]; then
        log_error "nginx-manager.sh 脚本未找到"
        exit 1
    fi
    
    # 检查脚本是否可执行
    if [[ ! -x "./nginx-manager.sh" ]]; then
        log_error "nginx-manager.sh 脚本没有执行权限"
        exit 1
    fi
    
    local test_dir
    local failed_tests=0
    
    # 设置错误时清理
    trap 'cleanup_test_env "$test_dir"' EXIT
    
    # 创建测试环境
    test_dir=$(setup_test_env)
    echo
    
    # 运行测试
    test_basic_functionality "$test_dir" || ((failed_tests++))
    test_site_operations "$test_dir" || ((failed_tests++))
    test_docs_generation "$test_dir" || ((failed_tests++))
    
    echo
    if [[ $failed_tests -eq 0 ]]; then
        log_info "🎉 所有测试通过！自定义配置路径功能正常"
        return 0
    else
        log_error "❌ $failed_tests 个测试失败"
        return 1
    fi
}

# 检查是否直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
