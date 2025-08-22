#!/bin/bash

# 🐧 Nginx Manager for Linux
# 专为 Linux 系统优化的 Nginx 配置管理工具
# 版本: 2.0-linux
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

# 📁 Linux 默认路径配置
NGINX_CONF_DIR="/etc/nginx"
NGINX_CONF_FILE="$NGINX_CONF_DIR/nginx.conf"
NGINX_SITES_DIR="$NGINX_CONF_DIR/sites-available"
NGINX_ENABLED_DIR="$NGINX_CONF_DIR/sites-enabled"
BACKUP_DIR="/var/backups/nginx"
TEMPLATES_DIR="$NGINX_CONF_DIR/templates"

# 🔧 Linux 兼容性函数
get_script_dir() {
    # Linux 使用 readlink -f
    dirname "$(readlink -f "${BASH_SOURCE[0]}")"
}

# Linux sed 使用 -i 参数
linux_sed() {
    sed -i "$@"
}

# 检测 Linux 发行版
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# 检查包管理器和 nginx 安装
check_linux_nginx() {
    local distro=$(detect_linux_distro)
    
    echo -e "${BLUE}🐧 Linux 发行版: $distro${NC}"
    
    case "$distro" in
        ubuntu|debian)
            if dpkg -l | grep -q nginx; then
                echo -e "${GREEN}✅ 检测到 APT Nginx${NC}"
                echo -e "${BLUE}💡 管理命令: systemctl start/stop/restart nginx${NC}"
            else
                echo -e "${YELLOW}⚠️ 未检测到 Nginx${NC}"
                echo -e "${BLUE}💡 安装建议: sudo apt install nginx${NC}"
            fi
            ;;
        centos|rhel|fedora)
            if rpm -q nginx >/dev/null 2>&1; then
                echo -e "${GREEN}✅ 检测到 YUM/DNF Nginx${NC}"
                echo -e "${BLUE}💡 管理命令: systemctl start/stop/restart nginx${NC}"
            else
                echo -e "${YELLOW}⚠️ 未检测到 Nginx${NC}"
                echo -e "${BLUE}💡 安装建议: sudo yum install nginx 或 sudo dnf install nginx${NC}"
            fi
            ;;
        arch)
            if pacman -Q nginx >/dev/null 2>&1; then
                echo -e "${GREEN}✅ 检测到 Pacman Nginx${NC}"
                echo -e "${BLUE}💡 管理命令: systemctl start/stop/restart nginx${NC}"
            else
                echo -e "${YELLOW}⚠️ 未检测到 Nginx${NC}"
                echo -e "${BLUE}💡 安装建议: sudo pacman -S nginx${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}⚠️ 未知的 Linux 发行版${NC}"
            if command -v nginx >/dev/null 2>&1; then
                echo -e "${GREEN}✅ 检测到 Nginx${NC}"
            else
                echo -e "${RED}❌ 未检测到 Nginx${NC}"
            fi
            ;;
    esac
}

# 🔧 主要功能保持不变，但使用 Linux 兼容函数
show_help() {
    local distro=$(detect_linux_distro)
    
    cat << EOF
${WHITE}🐧 Nginx Manager for Linux - $distro 版本${NC}

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

${CYAN}Linux 特性:${NC}
    • 支持多种 Linux 发行版
    • 自动检测包管理器
    • 兼容 systemd 服务管理
    • 支持 Linux 标准路径结构

${CYAN}示例:${NC}
    # 添加静态网站 (Linux)
    $(basename $0) add-site blog.example.com -r /var/www/blog -s -g

    # 添加 API 代理 (Linux)  
    $(basename $0) add-proxy api.example.com -p http://localhost:3000 -w -k

    # 生成文档
    $(basename $0) generate-docs

EOF
}

# 简化的文档生成函数 (Linux 优化)
generate_docs() {
    local script_dir="$(get_script_dir)"
    local docs_dir="$script_dir/docs"
    local doc_file="$docs_dir/nginx_config_docs_linux_$(date +%Y%m%d_%H%M%S).md"
    local distro=$(detect_linux_distro)
    
    echo "🔄 正在生成 Linux Nginx 配置文档..."
    echo "📍 配置目录: $NGINX_CONF_DIR"
    echo "📄 主配置文件: $NGINX_CONF_FILE"
    echo "📁 文档保存目录: $docs_dir"
    echo "🐧 Linux 发行版: $distro"
    
    # 确保docs目录存在
    mkdir -p "$docs_dir"
    
    cat > "$doc_file" << 'DOC_HEADER'
# 🐧 Linux Nginx 配置文档

**生成时间**: DOC_TIMESTAMP  
**系统**: Linux (DOC_DISTRO)  
**服务器**: DOC_HOSTNAME  
**Nginx版本**: DOC_VERSION  
**配置目录**: DOC_CONFIG_DIR  
**主配置文件**: DOC_CONFIG_FILE

---

## 📋 Linux 特定配置

### 🐧 系统路径结构
- **配置目录**: `/etc/nginx`
- **日志目录**: `/var/log/nginx`
- **服务管理**: `systemctl start/stop/restart nginx`
- **网站根目录**: `/var/www/html`
- **进程用户**: `www-data` (Debian/Ubuntu) 或 `nginx` (RHEL/CentOS)

DOC_HEADER
    
    # Linux 专用替换
    linux_sed "s/DOC_TIMESTAMP/$(date '+%Y年%m月%d日 %H:%M:%S')/g" "$doc_file"
    linux_sed "s/DOC_HOSTNAME/$(hostname)/g" "$doc_file"
    linux_sed "s/DOC_DISTRO/$distro/g" "$doc_file"
    linux_sed "s/DOC_VERSION/$(nginx -v 2>&1 | sed 's/nginx version: nginx\///' 2>/dev/null || echo '未安装')/g" "$doc_file"
    linux_sed "s|DOC_CONFIG_DIR|$NGINX_CONF_DIR|g" "$doc_file"
    linux_sed "s|DOC_CONFIG_FILE|$NGINX_CONF_FILE|g" "$doc_file"
    
    # 添加站点统计
    local total_sites=0
    local enabled_sites=0
    
    if [ -d "$NGINX_SITES_DIR" ]; then
        total_sites=$(find "$NGINX_SITES_DIR" -maxdepth 1 -type f | wc -l)
    fi
    
    if [ -d "$NGINX_ENABLED_DIR" ]; then
        enabled_sites=$(find "$NGINX_ENABLED_DIR" -maxdepth 1 -type l | wc -l)
    fi
    
    # 根据发行版添加不同的管理命令
    local pkg_manager=""
    local install_cmd=""
    case "$distro" in
        ubuntu|debian)
            pkg_manager="APT"
            install_cmd="sudo apt install nginx"
            ;;
        centos|rhel)
            pkg_manager="YUM"
            install_cmd="sudo yum install nginx"
            ;;
        fedora)
            pkg_manager="DNF"
            install_cmd="sudo dnf install nginx"
            ;;
        arch)
            pkg_manager="Pacman"
            install_cmd="sudo pacman -S nginx"
            ;;
        *)
            pkg_manager="包管理器"
            install_cmd="sudo [包管理器] install nginx"
            ;;
    esac
    
    cat >> "$doc_file" << EOF

### 📊 站点统计

| 项目 | 数量 |
|------|------|
| **总站点数** | $total_sites |
| **已启用站点** | $enabled_sites |

### 🐧 $distro 管理命令

\`\`\`bash
# 安装 nginx
$install_cmd

# 服务管理 (systemd)
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx
sudo systemctl enable nginx    # 开机自启
sudo systemctl disable nginx   # 禁用自启

# 查看服务状态
sudo systemctl status nginx

# 查看日志
sudo journalctl -u nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# 测试配置
sudo nginx -t

# 重新加载配置
sudo nginx -s reload
\`\`\`

### 🔧 Linux 特定优化

1. **权限管理**:
   - 配置文件所有者: \`root:root\`
   - 配置文件权限: \`644\`
   - 网站目录所有者: \`www-data:www-data\` (Debian/Ubuntu)
   - 网站目录权限: \`755\`

2. **路径配置**:
   - 网站根目录: \`/var/www/html\`
   - 配置目录: \`/etc/nginx\`
   - 日志目录: \`/var/log/nginx\`
   - PID 文件: \`/var/run/nginx.pid\`

3. **防火墙配置** (UFW/iptables):
   \`\`\`bash
   # UFW (Ubuntu/Debian)
   sudo ufw allow 'Nginx Full'
   sudo ufw allow 80
   sudo ufw allow 443
   
   # iptables (通用)
   sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
   sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
   \`\`\`

4. **SELinux 配置** (RHEL/CentOS):
   \`\`\`bash
   # 查看 SELinux 状态
   sestatus
   
   # 允许 nginx 网络连接
   sudo setsebool -P httpd_can_network_connect 1
   
   # 设置网站目录 SELinux 上下文
   sudo setsebool -P httpd_enable_homedirs 1
   sudo chcon -R -t httpd_exec_t /var/www/
   \`\`\`

EOF

    echo -e "${GREEN}✅ Linux Nginx配置文档已生成: $(basename "$doc_file")${NC}"
    echo -e "${BLUE}📖 文档包含了 $distro 特定的配置信息和管理命令${NC}"
    echo -e "${CYAN}📁 文档保存位置: $doc_file${NC}"
}

# 主函数简化版
main() {
    # 检查 Linux 环境
    if [ "$(uname)" != "Linux" ]; then
        echo -e "${RED}❌ 此脚本专为 Linux 设计，请使用通用版本${NC}" >&2
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
            check_linux_nginx
            ;;
        *)
            echo -e "${RED}错误: 未知命令 '$command'${NC}" >&2
            echo -e "${YELLOW}这是简化的 Linux 版本，仅支持文档生成功能${NC}"
            echo -e "${BLUE}使用完整功能请运行主脚本: nginx-manager.sh${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
