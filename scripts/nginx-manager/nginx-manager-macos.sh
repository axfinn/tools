#!/bin/bash

# 🍎 Nginx Manager for macOS
# 专为 macOS 系统优化的 Nginx 配置管理工具
# 版本: 2.0-macos
# 作者: nginx-manager 项目
# 最后更新: 2025-08-22

# 🎨 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 📁 macOS 默认路径配置
NGINX_CONF_DIR="/usr/local/etc/nginx"  # Homebrew nginx 默认路径
NGINX_CONF_FILE="$NGINX_CONF_DIR/nginx.conf"
NGINX_SITES_DIR="$NGINX_CONF_DIR/sites-available"
NGINX_ENABLED_DIR="$NGINX_CONF_DIR/sites-enabled"
BACKUP_DIR="/usr/local/var/backups/nginx"
TEMPLATES_DIR="$NGINX_CONF_DIR/templates"

# 🔧 macOS 兼容性函数
get_script_dir() {
    # macOS 使用 greadlink 或 realpath
    if command -v greadlink >/dev/null 2>&1; then
        dirname "$(greadlink -f "${BASH_SOURCE[0]}")"
    elif command -v realpath >/dev/null 2>&1; then
        dirname "$(realpath "${BASH_SOURCE[0]}")"
    else
        dirname "${BASH_SOURCE[0]}"
    fi
}

# macOS sed 需要 -i '' 参数
macos_sed() {
    sed -i '' "$@"
}

# 检查 Homebrew nginx
check_homebrew_nginx() {
    if command -v brew >/dev/null 2>&1; then
        if brew list nginx >/dev/null 2>&1; then
            echo -e "${GREEN}✅ 检测到 Homebrew Nginx${NC}"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}⚠️ 未检测到 Homebrew Nginx${NC}"
    echo -e "${BLUE}💡 安装建议: brew install nginx${NC}"
    return 1
}

# 🔧 主要功能保持不变，但使用 macOS 兼容函数
show_help() {
    cat << EOF
${WHITE}🍎 Nginx Manager for macOS - Homebrew 版本${NC}

${CYAN}用法:${NC}
    $(basename $0) [全局选项] <命令> [选项]

${CYAN}全局选项:${NC}
    -c, --config <路径>          指定nginx配置目录 (默认: $NGINX_CONF_DIR)
    -h, --help                   显示帮助信息

${CYAN}站点管理命令:${NC}
    add-site <域名> [选项]       添加静态网站
    add-proxy <域名> [选项]      添加反向代理
    remove-site <域名>           删除站点配置
    enable-site <域名>           启用站点
    disable-site <域名>          禁用站点
    list-sites                   列出所有站点

${CYAN}SSL 管理命令:${NC}
    ssl-setup <域名> [选项]      配置SSL证书
    ssl-renew <域名>             续期SSL证书

${CYAN}系统管理命令:${NC}
    status                       查看nginx状态
    test                         测试配置文件
    reload                       重新加载配置
    backup [名称]                备份配置
    restore <备份名>             恢复配置
    generate-docs                生成配置文档

${CYAN}macOS 特性:${NC}
    • 支持 Homebrew nginx 路径
    • 兼容 macOS sed 语法
    • 支持 System Integrity Protection
    • 自动检测 greadlink/realpath

${CYAN}示例:${NC}
    # 添加静态网站 (macOS)
    $(basename $0) add-site blog.example.com -r /usr/local/var/www/blog -s -g

    # 添加 API 代理 (macOS)  
    $(basename $0) add-proxy api.example.com -p http://localhost:3000 -w -k

    # 生成文档
    $(basename $0) generate-docs

EOF
}

# 简化的文档生成函数 (macOS 优化)
generate_docs() {
    local script_dir="$(get_script_dir)"
    local docs_dir="$script_dir/docs"
    local doc_file="$docs_dir/nginx_config_docs_macos_$(date +%Y%m%d_%H%M%S).md"
    
    echo "🔄 正在生成 macOS Nginx 配置文档..."
    echo "📍 配置目录: $NGINX_CONF_DIR"
    echo "📄 主配置文件: $NGINX_CONF_FILE"
    echo "📁 文档保存目录: $docs_dir"
    
    # 确保docs目录存在
    mkdir -p "$docs_dir"
    
    cat > "$doc_file" << 'DOC_HEADER'
# 🍎 macOS Nginx 配置文档

**生成时间**: DOC_TIMESTAMP  
**系统**: macOS (Homebrew)  
**服务器**: DOC_HOSTNAME  
**Nginx版本**: DOC_VERSION  
**配置目录**: DOC_CONFIG_DIR  
**主配置文件**: DOC_CONFIG_FILE

---

## 📋 macOS 特定配置

### 🍺 Homebrew Nginx 路径
- **配置目录**: `/usr/local/etc/nginx`
- **日志目录**: `/usr/local/var/log/nginx`
- **服务管理**: `brew services start/stop/restart nginx`
- **网站根目录**: `/usr/local/var/www`

DOC_HEADER
    
    # macOS 专用替换
    macos_sed "s/DOC_TIMESTAMP/$(date '+%Y年%m月%d日 %H:%M:%S')/g" "$doc_file"
    macos_sed "s/DOC_HOSTNAME/$(hostname)/g" "$doc_file"
    macos_sed "s/DOC_VERSION/$(nginx -v 2>&1 | sed 's/nginx version: nginx\///' 2>/dev/null || echo 'Homebrew nginx 未安装')/g" "$doc_file"
    macos_sed "s|DOC_CONFIG_DIR|$NGINX_CONF_DIR|g" "$doc_file"
    macos_sed "s|DOC_CONFIG_FILE|$NGINX_CONF_FILE|g" "$doc_file"
    
    # 添加站点统计
    local total_sites=0
    local enabled_sites=0
    
    if [ -d "$NGINX_SITES_DIR" ]; then
        total_sites=$(find "$NGINX_SITES_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')
    fi
    
    if [ -d "$NGINX_ENABLED_DIR" ]; then
        enabled_sites=$(find "$NGINX_ENABLED_DIR" -maxdepth 1 -type l | wc -l | tr -d ' ')
    fi
    
    cat >> "$doc_file" << EOF

### 📊 站点统计

| 项目 | 数量 |
|------|------|
| **总站点数** | $total_sites |
| **已启用站点** | $enabled_sites |

### 🍺 Homebrew 管理命令

\`\`\`bash
# 启动 nginx 服务
brew services start nginx

# 停止 nginx 服务  
brew services stop nginx

# 重启 nginx 服务
brew services restart nginx

# 查看服务状态
brew services list | grep nginx

# 测试配置
nginx -t

# 重新加载配置
nginx -s reload
\`\`\`

### 🔧 macOS 特定优化

1. **权限管理**:
   - 使用 \`sudo\` 编辑系统配置
   - 配置文件权限: \`644\`
   - 日志文件权限: \`644\`

2. **路径配置**:
   - 网站根目录: \`/usr/local/var/www\`
   - 配置目录: \`/usr/local/etc/nginx\`
   - 日志目录: \`/usr/local/var/log/nginx\`

3. **防火墙配置**:
   - 使用系统偏好设置 → 安全性与隐私 → 防火墙
   - 或使用 \`pfctl\` 命令行工具

EOF

    echo -e "${GREEN}✅ macOS Nginx配置文档已生成: $(basename "$doc_file")${NC}"
    echo -e "${BLUE}📖 文档包含了 macOS 特定的配置信息和管理命令${NC}"
    echo -e "${CYAN}📁 文档保存位置: $doc_file${NC}"
}

# 主函数简化版
main() {
    # 检查 macOS 环境
    if [ "$(uname)" != "Darwin" ]; then
        echo -e "${RED}❌ 此脚本专为 macOS 设计，请使用通用版本${NC}" >&2
        exit 1
    fi
    
    # 解析参数
    local command="${1:-help}"
    
    case "$command" in
        generate-docs)
            generate_docs
            ;;
        help|--help|-h|"")
            show_help
            ;;
        check)
            check_homebrew_nginx
            ;;
        *)
            echo -e "${RED}错误: 未知命令 '$command'${NC}" >&2
            echo -e "${YELLOW}这是简化的 macOS 版本，仅支持文档生成功能${NC}"
            echo -e "${BLUE}使用完整功能请运行主脚本: nginx-manager.sh${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
