#!/bin/bash

# nginx-manager.sh 功能演示脚本
# 展示各种配置管理功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(dirname "$0")"
NGINX_MANAGER="$SCRIPT_DIR/../nginx-manager.sh"
EXAMPLES_DIR="$SCRIPT_DIR"

log_section() {
    echo
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_demo() {
    echo -e "${PURPLE}[DEMO]${NC} $1"
}

log_command() {
    echo -e "${YELLOW}$ $1${NC}"
}

demo_intro() {
    log_section "🚀 Nginx Manager 功能演示"
    
    echo "本演示将展示 nginx-manager.sh 的主要功能："
    echo "• 📁 自定义配置路径支持"
    echo "• 🌐 静态站点和反向代理管理"
    echo "• 🔒 SSL 证书配置"
    echo "• ⚖️ 负载均衡设置"
    echo "• 🔌 WebSocket 长连接支持"
    echo "• 📊 配置文档生成"
    echo "• 🧪 配置测试和验证"
    echo
    echo "示例配置目录：$EXAMPLES_DIR"
    echo
}

demo_custom_config() {
    log_section "📁 自定义配置路径演示"
    
    log_demo "使用示例配置目录：$EXAMPLES_DIR"
    log_command "nginx-manager.sh -c $EXAMPLES_DIR status"
    
    echo "配置目录结构："
    echo "examples/"
    echo "├── nginx.conf              # 主配置文件"
    echo "├── sites-available/        # 可用站点配置"
    echo "│   ├── company.example.com # 静态网站示例"
    echo "│   ├── api.example.com     # API反向代理示例"
    echo "│   ├── ws.example.com      # WebSocket代理示例"
    echo "│   └── app.example.com     # 负载均衡示例"
    echo "└── sites-enabled/          # 启用站点配置"
    echo "    ├── company.example.com -> ../sites-available/company.example.com"
    echo "    ├── api.example.com     -> ../sites-available/api.example.com"
    echo "    └── ws.example.com      -> ../sites-available/ws.example.com"
    echo
    
    if command -v "$NGINX_MANAGER" >/dev/null 2>&1; then
        log_info "运行状态检查："
        log_command "$NGINX_MANAGER -c $EXAMPLES_DIR status" 
        echo "注意：由于这是示例配置，nginx服务可能显示为未运行状态。"
    else
        log_info "nginx-manager.sh 脚本路径：$NGINX_MANAGER"
    fi
}

demo_site_examples() {
    log_section "🌐 站点配置示例分析"
    
    echo "1. 静态网站示例 (company.example.com)："
    echo "   • HTTPS 重定向"
    echo "   • SSL/TLS 配置"
    echo "   • Gzip 压缩"
    echo "   • 静态资源缓存"
    echo "   • 安全头设置"
    echo
    
    echo "2. API 反向代理示例 (api.example.com)："
    echo "   • 负载均衡后端池"
    echo "   • 健康检查"
    echo "   • 超时和重试配置"
    echo "   • 请求体大小限制"
    echo "   • 详细访问日志"
    echo
    
    echo "3. WebSocket 长连接示例 (ws.example.com)："
    echo "   • 协议升级处理"
    echo "   • 长连接超时优化"
    echo "   • 实时传输配置（禁用缓冲）"
    echo "   • 连接保持设置"
    echo "   • 故障转移机制"
    echo
    
    echo "4. 负载均衡应用示例 (app.example.com)："
    echo "   • 多后端服务器配置"
    echo "   • 权重和备份服务器"
    echo "   • 会话保持选项"
    echo "   • API 限流配置"
    echo "   • 连接池优化"
    echo
}

demo_config_analysis() {
    log_section "📊 配置文件分析"
    
    log_demo "主配置文件特性 (nginx.conf)："
    echo "• 工作进程自动调优"
    echo "• 事件模型优化 (epoll)"
    echo "• Gzip 压缩配置"
    echo "• 安全头设置"
    echo "• 负载均衡池定义"
    echo "• 性能缓冲区优化"
    echo
    
    log_demo "站点配置统计："
    echo "• 总站点数: 4"
    echo "• 启用站点: 3"
    echo "• SSL 站点: 4"
    echo "• 反向代理: 3"
    echo "• WebSocket 支持: 1"
    echo "• 负载均衡: 2"
    echo
}

demo_management_commands() {
    log_section "🛠️ 管理命令演示"
    
    log_demo "常用管理命令："
    echo
    
    log_info "1. 添加新的静态站点："
    log_command "$NGINX_MANAGER -c $EXAMPLES_DIR add-site newsite.com -r /var/www/newsite -s -l -g"
    echo
    
    log_info "2. 添加反向代理站点："
    log_command "$NGINX_MANAGER -c $EXAMPLES_DIR add-proxy api.newsite.com -p http://localhost:3000 -w -t 300"
    echo
    
    log_info "3. 设置 SSL 证书："
    log_command "$NGINX_MANAGER -c $EXAMPLES_DIR ssl-setup newsite.com -c /path/to/cert.pem -k /path/to/key.pem"
    echo
    
    log_info "4. 列出所有站点："
    log_command "$NGINX_MANAGER -c $EXAMPLES_DIR list-sites"
    echo
    
    log_info "5. 生成配置文档："
    log_command "$NGINX_MANAGER -c $EXAMPLES_DIR generate-docs"
    echo
    
    log_info "6. 备份配置："
    log_command "$NGINX_MANAGER -c $EXAMPLES_DIR backup example_backup"
    echo
    
    log_info "7. 测试配置："
    log_command "$NGINX_MANAGER -c $EXAMPLES_DIR test"
    echo
}

demo_best_practices() {
    log_section "💡 最佳实践建议"
    
    echo "1. 🔒 安全配置："
    echo "   • 始终使用 HTTPS（SSL/TLS）"
    echo "   • 配置安全头（HSTS、XSS 保护等）"
    echo "   • 隐藏服务器版本信息"
    echo "   • 设置合适的请求体大小限制"
    echo
    
    echo "2. ⚡ 性能优化："
    echo "   • 启用 Gzip 压缩"
    echo "   • 配置静态资源缓存"
    echo "   • 使用 HTTP/2"
    echo "   • 优化缓冲区大小"
    echo "   • 启用连接复用"
    echo
    
    echo "3. 🔌 长连接配置："
    echo "   • WebSocket 协议升级"
    echo "   • 适当的超时设置"
    echo "   • 禁用代理缓冲（实时应用）"
    echo "   • 配置连接保持"
    echo
    
    echo "4. ⚖️ 负载均衡："
    echo "   • 选择合适的负载均衡算法"
    echo "   • 配置健康检查"
    echo "   • 设置故障转移"
    echo "   • 使用连接池"
    echo
    
    echo "5. 📋 运维管理："
    echo "   • 定期备份配置"
    echo "   • 测试配置有效性"
    echo "   • 监控访问日志"
    echo "   • 生成配置文档"
    echo
}

demo_generate_docs() {
    log_section "📚 配置文档生成演示"
    
    if command -v "$NGINX_MANAGER" >/dev/null 2>&1; then
        log_demo "生成示例配置的中文文档："
        log_command "$NGINX_MANAGER -c $EXAMPLES_DIR generate-docs"
        
        echo "文档将保存在 docs/ 目录中，包含："
        echo "• 服务器信息和配置路径"
        echo "• 站点统计和分类"
        echo "• 详细的站点配置"
        echo "• SSL 证书信息"
        echo "• 负载均衡配置"
        echo "• WebSocket 设置"
        echo "• 性能优化配置"
        echo
        
        # 实际生成文档（如果可以的话）
        if "$NGINX_MANAGER" -c "$EXAMPLES_DIR" generate-docs 2>/dev/null; then
            local doc_file=$(ls ../docs/nginx_config_docs_*.md 2>/dev/null | head -1)
            if [[ -n "$doc_file" ]]; then
                log_info "✅ 文档已生成：$doc_file"
                echo "前几行预览："
                head -15 "$doc_file" | sed 's/^/   /'
            fi
        fi
    else
        log_info "要生成文档，请运行："
        log_command "$NGINX_MANAGER -c $EXAMPLES_DIR generate-docs"
    fi
}

main() {
    demo_intro
    demo_custom_config
    demo_site_examples
    demo_config_analysis
    demo_management_commands
    demo_best_practices
    demo_generate_docs
    
    log_section "🎉 演示完成"
    echo "要查看详细使用说明，请参考："
    echo "• README.md - 完整使用手册"
    echo "• QUICKSTART.md - 快速入门指南"
    echo "• CUSTOM-CONFIG.md - 自定义配置说明"
    echo
    echo "要开始使用，请运行："
    log_command "sudo $NGINX_MANAGER --help"
    echo
}

# 检查是否直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
