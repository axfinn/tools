#!/bin/bash

# Nginx配置管理脚本
# 支持虚拟站点、反向代理、长连接等功能
# 使用方式: ./nginx-manager.sh [命令] [参数]

# 默认配置参数
DEFAULT_NGINX_CONF_DIR="/etc/nginx"
BACKUP_DIR="/var/backups/nginx"
TEMPLATES_DIR="$(dirname "$0")/templates"

# 动态配置参数（可通过参数覆盖）
NGINX_CONF_DIR="$DEFAULT_NGINX_CONF_DIR"
NGINX_SITES_DIR=""
NGINX_ENABLED_DIR=""
NGINX_CONF_FILE=""

# 设置nginx配置路径
set_nginx_paths() {
    local custom_conf_dir="$1"
    
    if [[ -n "$custom_conf_dir" ]]; then
        if [[ -f "$custom_conf_dir" ]]; then
            # 如果传入的是文件路径，提取目录
            NGINX_CONF_DIR="$(dirname "$custom_conf_dir")"
            NGINX_CONF_FILE="$custom_conf_dir"
        else
            # 如果传入的是目录路径
            NGINX_CONF_DIR="$custom_conf_dir"
            NGINX_CONF_FILE="$NGINX_CONF_DIR/nginx.conf"
        fi
    else
        NGINX_CONF_DIR="$DEFAULT_NGINX_CONF_DIR"
        NGINX_CONF_FILE="$NGINX_CONF_DIR/nginx.conf"
    fi
    
    NGINX_SITES_DIR="$NGINX_CONF_DIR/sites-available"
    NGINX_ENABLED_DIR="$NGINX_CONF_DIR/sites-enabled"
    
    # 确保目录存在
    mkdir -p "$NGINX_SITES_DIR" "$NGINX_ENABLED_DIR" 2>/dev/null || true
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "Nginx配置管理脚本"
    echo "使用方式: $0 [全局选项] [命令] [参数]"
    echo
    echo "全局选项:"
    echo "  -c, --config <路径>          指定nginx配置文件或目录 (默认: /etc/nginx)"
    echo "  -h, --help                   显示帮助信息"
    echo
    echo "命令:"
    echo "  add-site <域名> [选项]       添加虚拟站点"
    echo "  add-proxy <域名> [选项]      添加反向代理站点"
    echo "  remove-site <域名>           移除站点"
    echo "  enable-site <域名>           启用站点"
    echo "  disable-site <域名>          禁用站点"
    echo "  list-sites                   列出所有站点"
    echo "  backup [标签]                备份nginx配置"
    echo "  restore [标签|文件]          恢复配置"
    echo "  test                         测试nginx配置"
    echo "  reload                       重载nginx配置"
    echo "  optimize                     优化nginx主配置"
    echo "  ssl-setup <域名>             设置SSL证书"
    echo "  status                       查看nginx状态"
    echo "  generate-docs                生成中文配置文档"
    echo
    echo "添加站点选项:"
    echo "  -r, --root <path>            网站根目录"
    echo "  -p, --proxy <url>            反向代理目标URL"
    echo "  -s, --ssl                    启用SSL"
    echo "  -c, --cert <path>            SSL证书路径"
    echo "  -k, --key <path>             SSL私钥路径"
    echo "  -i, --index <files>          默认索引文件"
    echo "  -l, --log                    启用访问日志"
    echo "  -g, --gzip                   启用gzip压缩"
    echo "  -w, --websocket              支持WebSocket"
    echo "  -t, --timeout <seconds>      设置超时时间"
    echo "  -m, --max-body <size>        最大请求体大小"
    echo
    echo "示例:"
    echo "  # 添加静态网站"
    echo "  $0 add-site example.com -r /var/www/example.com -s -l -g"
    echo
    echo "  # 添加反向代理"
    echo "  $0 add-proxy api.example.com -p http://localhost:3000 -w -t 300"
    echo
    echo "  # 添加负载均衡代理"
    echo "  $0 add-proxy app.example.com -p 'http://backend1:8080,http://backend2:8080'"
    echo
    echo "  # 设置SSL证书"
    echo "  $0 ssl-setup example.com -c /path/to/cert.pem -k /path/to/key.pem"
    echo
    echo "  # 使用自定义nginx配置目录"
    echo "  $0 -c /custom/nginx add-site example.com -r /var/www/example.com"
    echo
    echo "长连接支持说明:"
    echo "  --websocket 选项会自动配置:"
    echo "  - WebSocket协议升级头"
    echo "  - 长连接保持 (keepalive)"
    echo "  - 代理缓存绕过"
    echo "  - 扩展超时时间"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}" >&2
        exit 1
    fi
}

# 检查依赖项
check_dependencies() {
    local missing_deps=()
    
    if ! command -v nginx >/dev/null 2>&1; then
        missing_deps+=("nginx")
    fi
    
    if ! command -v openssl >/dev/null 2>&1; then
        missing_deps+=("openssl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少必要的依赖项: ${missing_deps[*]}${NC}" >&2
        echo "请安装: apt-get install nginx openssl 或 yum install nginx openssl" >&2
        exit 1
    fi
}

# 初始化环境
init_environment() {
    # 创建必要的目录
    for dir in "$NGINX_SITES_DIR" "$NGINX_ENABLED_DIR" "$BACKUP_DIR" "$TEMPLATES_DIR"; do
        if [ ! -d "$dir" ]; then
            if ! mkdir -p "$dir" 2>/dev/null; then
                echo -e "${YELLOW}警告: 无法创建目录 $dir${NC}" >&2
            fi
        fi
    done
    
    # 确保nginx配置目录存在
    if [ ! -f "$NGINX_CONF_FILE" ]; then
        echo -e "${RED}错误: nginx配置文件不存在: $NGINX_CONF_FILE${NC}" >&2
        exit 1
    fi
}

# 生成中文配置文档
generate_docs() {
    local doc_file="nginx_config_docs_$(date +%Y%m%d_%H%M%S).md"
    
    echo "🔄 正在生成Nginx配置文档..."
    echo "📍 配置目录: $NGINX_CONF_DIR"
    echo "📄 主配置文件: $NGINX_CONF_FILE"
    
    cat > "$doc_file" << 'DOC_HEADER'
# 🌐 Nginx 配置文档

**生成时间**: DOC_TIMESTAMP  
**服务器**: DOC_HOSTNAME  
**Nginx版本**: DOC_VERSION  
**配置目录**: DOC_CONFIG_DIR  
**主配置文件**: DOC_CONFIG_FILE

---

## 📋 配置概览

DOC_HEADER
    
    # 替换动态内容
    sed -i "s/DOC_TIMESTAMP/$(date '+%Y年%m月%d日 %H:%M:%S')/g" "$doc_file"
    sed -i "s/DOC_HOSTNAME/$(hostname)/g" "$doc_file"
    sed -i "s/DOC_VERSION/$(nginx -v 2>&1 | sed 's/nginx version: nginx\///')/g" "$doc_file"
    sed -i "s|DOC_CONFIG_DIR|$NGINX_CONF_DIR|g" "$doc_file"
    sed -i "s|DOC_CONFIG_FILE|$NGINX_CONF_FILE|g" "$doc_file"
    
    # 统计信息
    local total_sites=0
    local enabled_sites=0
    local proxy_sites=0
    local ssl_sites=0
    local static_sites=0
    local keepalive_sites=0
    local websocket_sites=0
    
    # 计算统计数据
    for site_file in "$NGINX_SITES_DIR"/*; do
        if [ -f "$site_file" ]; then
            total_sites=$((total_sites + 1))
            
            # 检查是否启用
            local site_name=$(basename "$site_file")
            if [ -L "$NGINX_ENABLED_DIR/$site_name" ]; then
                enabled_sites=$((enabled_sites + 1))
            fi
            
            # 检查类型
            if grep -q "proxy_pass" "$site_file"; then
                proxy_sites=$((proxy_sites + 1))
                
                # 检查长连接
                if grep -q "keepalive" "$site_file"; then
                    keepalive_sites=$((keepalive_sites + 1))
                fi
                
                # 检查WebSocket
                if grep -q "upgrade.*websocket\|Connection.*upgrade" "$site_file"; then
                    websocket_sites=$((websocket_sites + 1))
                fi
            else
                static_sites=$((static_sites + 1))
            fi
            
            # 检查SSL
            if grep -q "ssl_certificate\|listen.*ssl" "$site_file"; then
                ssl_sites=$((ssl_sites + 1))
            fi
        fi
    done
    
    # 添加统计信息
    cat >> "$doc_file" << EOF

### 📊 数据统计

| 项目 | 数量 | 百分比 |
|------|------|--------|
| **总站点数** | $total_sites | 100% |
| **已启用站点** | $enabled_sites | $([ $total_sites -gt 0 ] && echo "$((enabled_sites * 100 / total_sites))%" || echo "0%") |
| **反向代理站点** | $proxy_sites | $([ $total_sites -gt 0 ] && echo "$((proxy_sites * 100 / total_sites))%" || echo "0%") |
| **静态网站** | $static_sites | $([ $total_sites -gt 0 ] && echo "$((static_sites * 100 / total_sites))%" || echo "0%") |
| **SSL站点** | $ssl_sites | $([ $total_sites -gt 0 ] && echo "$((ssl_sites * 100 / total_sites))%" || echo "0%") |
| **长连接优化** | $keepalive_sites | $([ $proxy_sites -gt 0 ] && echo "$((keepalive_sites * 100 / proxy_sites))%" || echo "0%") (反向代理中) |
| **WebSocket支持** | $websocket_sites | $([ $proxy_sites -gt 0 ] && echo "$((websocket_sites * 100 / proxy_sites))%" || echo "0%") (反向代理中) |

---

## 🌐 站点详情

EOF

    # 遍历所有站点配置
    for site_file in "$NGINX_SITES_DIR"/*; do
        if [ -f "$site_file" ]; then
            local site_name=$(basename "$site_file")
            local is_enabled="❌ 未启用"
            local site_status="🔴 离线"
            
            # 检查启用状态
            if [ -L "$NGINX_ENABLED_DIR/$site_name" ]; then
                is_enabled="✅ 已启用"
                site_status="🟢 在线"
            fi
            
            cat >> "$doc_file" << EOF

### 🏷️ $site_name

- **状态**: $is_enabled
- **运行状态**: $site_status

EOF
            
            # 分析配置类型和详情
            if grep -q "proxy_pass" "$site_file"; then
                cat >> "$doc_file" << EOF
- **类型**: 🔄 反向代理
EOF
                
                # 提取后端地址
                local backends=$(grep "proxy_pass" "$site_file" | sed 's/.*proxy_pass *//; s/;//' | sort -u)
                if [ -n "$backends" ]; then
                    cat >> "$doc_file" << EOF
- **后端服务器**:
EOF
                    echo "$backends" | while read -r backend; do
                        if [ -n "$backend" ]; then
                            echo "  - \`$backend\`" >> "$doc_file"
                        fi
                    done
                fi
                
                # 检查长连接配置
                if grep -q "keepalive" "$site_file"; then
                    local keepalive_num=$(grep "keepalive [0-9]" "$site_file" | head -1 | sed 's/.*keepalive *//; s/;.*//')
                    local keepalive_timeout=$(grep "keepalive_timeout" "$site_file" | head -1 | sed 's/.*keepalive_timeout *//; s/;.*//')
                    local keepalive_requests=$(grep "keepalive_requests" "$site_file" | head -1 | sed 's/.*keepalive_requests *//; s/;.*//')
                    
                    cat >> "$doc_file" << EOF
- **🔗 长连接优化**: ✅ 已启用
  - 连接池大小: \`$keepalive_num\`
  - 超时时间: \`$keepalive_timeout\`
  - 最大请求数: \`$keepalive_requests\`
EOF
                else
                    cat >> "$doc_file" << EOF
- **🔗 长连接优化**: ❌ 未启用 
  - ⚠️ 建议启用长连接以提高性能
EOF
                fi
                
                # 检查WebSocket支持
                if grep -q "upgrade.*websocket\|Connection.*upgrade" "$site_file"; then
                    cat >> "$doc_file" << EOF
- **🌐 WebSocket**: ✅ 支持
EOF
                else
                    cat >> "$doc_file" << EOF
- **🌐 WebSocket**: ❌ 不支持
EOF
                fi
                
                # 检查负载均衡
                if grep -q "upstream" "$site_file"; then
                    cat >> "$doc_file" << EOF
- **⚖️ 负载均衡**: ✅ 已配置
EOF
                fi
                
            else
                # 静态网站
                cat >> "$doc_file" << EOF
- **类型**: 📁 静态网站
EOF
                
                # 提取根目录
                local root_dir=$(grep "root " "$site_file" | head -1 | sed 's/.*root *//; s/;.*//')
                if [ -n "$root_dir" ]; then
                    cat >> "$doc_file" << EOF
- **根目录**: \`$root_dir\`
EOF
                fi
                
                # 检查索引文件
                local index_files=$(grep "index " "$site_file" | head -1 | sed 's/.*index *//; s/;.*//')
                if [ -n "$index_files" ]; then
                    cat >> "$doc_file" << EOF
- **索引文件**: \`$index_files\`
EOF
                fi
            fi
            
            # 检查SSL配置
            if grep -q "ssl_certificate\|listen.*ssl" "$site_file"; then
                local ssl_cert=$(grep "ssl_certificate " "$site_file" | head -1 | sed 's/.*ssl_certificate *//; s/;.*//')
                local ssl_protocols=$(grep "ssl_protocols" "$site_file" | head -1 | sed 's/.*ssl_protocols *//; s/;.*//')
                
                cat >> "$doc_file" << EOF
- **🔒 SSL/HTTPS**: ✅ 已配置
  - 证书路径: \`$ssl_cert\`
  - 支持协议: \`$ssl_protocols\`
EOF
            else
                cat >> "$doc_file" << EOF
- **🔒 SSL/HTTPS**: ❌ 未配置
  - ⚠️ 建议配置SSL证书以提高安全性
EOF
            fi
            
            # 检查Gzip压缩
            if grep -q "gzip" "$site_file"; then
                cat >> "$doc_file" << EOF
- **🗜️ Gzip压缩**: ✅ 已启用
EOF
            else
                cat >> "$doc_file" << EOF
- **🗜️ Gzip压缩**: ❌ 未启用
EOF
            fi
            
            # 检查缓存配置
            if grep -q "proxy_cache\|expires\|add_header.*Cache-Control" "$site_file"; then
                cat >> "$doc_file" << EOF
- **💾 缓存**: ✅ 已配置
EOF
            else
                cat >> "$doc_file" << EOF
- **💾 缓存**: ❌ 未配置
EOF
            fi
            
            # 检查访问日志
            local access_log=$(grep "access_log" "$site_file" | head -1 | sed 's/.*access_log *//; s/;.*//')
            if [ -n "$access_log" ] && [ "$access_log" != "off" ]; then
                cat >> "$doc_file" << EOF
- **📊 访问日志**: \`$access_log\`
EOF
            else
                cat >> "$doc_file" << EOF
- **📊 访问日志**: ❌ 已关闭
EOF
            fi
            
            # 添加配置片段
            cat >> "$doc_file" << EOF

**配置预览**:
\`\`\`nginx
EOF
            head -20 "$site_file" >> "$doc_file"
            cat >> "$doc_file" << EOF
\`\`\`

EOF
        fi
    done
    
    # 添加性能优化建议
    cat >> "$doc_file" << 'OPTIMIZE_SECTION'

---

## 🚀 性能优化建议

### 🔗 长连接优化
长连接（Keep-Alive）可以显著提高网站性能，特别是对于反向代理场景：

**优势**:
- ✅ **降低延迟**: 避免重复的TCP握手过程
- ✅ **减少资源消耗**: 减少服务器连接数和内存使用  
- ✅ **提高吞吐量**: 特别适合高频API调用
- ✅ **改善用户体验**: 页面加载更快

**推荐配置**:
```nginx
upstream backend {
    server 127.0.0.1:8080;
    
    # 长连接配置
    keepalive 32;          # 保持32个长连接
    keepalive_requests 100; # 每个连接最多处理100个请求  
    keepalive_timeout 60s;  # 连接超时时间
}

server {
    location / {
        proxy_pass http://backend;
        
        # 关键设置
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        
        # 超时优化
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 📱 WebSocket优化
对于需要实时通信的应用，正确配置WebSocket支持：

```nginx
location /ws {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    
    # WebSocket特殊超时
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}
```

### 🔒 SSL性能优化
```nginx
# SSL会话复用
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# 启用HTTP/2
listen 443 ssl http2;

# 优化SSL协议
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
```

### 🗜️ 压缩优化
```nginx
# Gzip压缩
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

# Brotli压缩 (需要模块支持)
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css application/json application/javascript text/xml application/xml;
```

OPTIMIZE_SECTION

    # 根据当前配置给出具体建议
    if [ $keepalive_sites -lt $proxy_sites ] && [ $proxy_sites -gt 0 ]; then
        cat >> "$doc_file" << EOF

### ⚠️ 针对当前配置的建议

1. **长连接优化不足**: 发现 $proxy_sites 个反向代理站点中只有 $keepalive_sites 个启用了长连接
   - 建议为所有反向代理站点启用长连接以提高性能
   - 使用命令: \`nginx-manager.sh add-proxy <域名> --proxy <后端> --keepalive\`

EOF
    fi
    
    if [ $ssl_sites -lt $total_sites ] && [ $total_sites -gt 0 ]; then
        cat >> "$doc_file" << EOF

2. **SSL配置不足**: $total_sites 个站点中只有 $ssl_sites 个配置了SSL
   - 建议为所有公网站点配置SSL证书
   - 使用命令: \`nginx-manager.sh ssl-setup <域名>\`

EOF
    fi
    
    cat >> "$doc_file" << EOF

---

## 📚 命令参考

### 长连接反向代理
\`\`\`bash
# 添加带长连接优化的反向代理
nginx-manager.sh add-proxy api.example.com --proxy http://127.0.0.1:8080 --keepalive

# 添加WebSocket支持的反向代理  
nginx-manager.sh add-proxy ws.example.com --proxy http://127.0.0.1:3000 --websocket --keepalive
\`\`\`

### SSL配置
\`\`\`bash
# 为站点配置SSL
nginx-manager.sh ssl-setup example.com

# 添加SSL站点
nginx-manager.sh add-site example.com --ssl --root /var/www/example.com
\`\`\`

### 配置管理
\`\`\`bash
# 测试配置
nginx-manager.sh test

# 重载配置
nginx-manager.sh reload

# 查看状态
nginx-manager.sh status
\`\`\`

---

**文档生成完成时间**: $(date '+%Y年%m月%d日 %H:%M:%S')  
**生成工具**: nginx-manager.sh  
**版本**: 2.0
EOF
    
    echo -e "${GREEN}✅ Nginx配置文档已生成: $doc_file${NC}"
    echo -e "${BLUE}📖 文档包含了所有站点的详细配置信息和优化建议${NC}"
    
    # 如果在桌面环境，尝试打开文档
    if command -v xdg-open >/dev/null 2>&1; then
        echo -e "${YELLOW}🔗 尝试打开文档...${NC}"
        xdg-open "$doc_file" 2>/dev/null || true
    fi
}

# 验证域名格式
validate_domain() {
    local domain=$1
    local domain_regex="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$"
    
    if ! [[ "$domain" =~ $domain_regex ]]; then
        echo -e "${RED}错误: 无效的域名格式 '$domain'${NC}" >&2
        exit 1
    fi
}

# 备份nginx配置
backup_nginx() {
    local tag=$1
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file
    
    if [ -n "$tag" ]; then
        tag=$(echo "$tag" | tr -cd '[:alnum:]_-')
        backup_file="${BACKUP_DIR}/nginx_${tag}_${timestamp}.tar.gz"
    else
        backup_file="${BACKUP_DIR}/nginx_${timestamp}.tar.gz"
    fi
    
    # 创建备份
    if tar -czf "$backup_file" -C "$(dirname "$NGINX_CONF_DIR")" "$(basename "$NGINX_CONF_DIR")" 2>/dev/null; then
        echo -e "${GREEN}✅ 已创建备份: $backup_file${NC}"
        return 0
    else
        echo -e "${RED}错误: 无法创建备份文件${NC}" >&2
        return 1
    fi
}

# 恢复nginx配置
restore_nginx() {
    local target=$1
    
    if [ -z "$target" ]; then
        # 查找最新备份
        local latest_backup=$(ls -t "$BACKUP_DIR"/nginx_*.tar.gz 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            target="$latest_backup"
        else
            echo -e "${RED}错误: 未指定恢复目标且没有备份文件${NC}" >&2
            return 1
        fi
    fi
    
    # 如果是标签而不是文件路径
    if [[ "$target" != /* ]]; then
        local backup_file=$(ls -t "${BACKUP_DIR}/nginx_${target}"_*.tar.gz 2>/dev/null | head -1)
        if [ -n "$backup_file" ]; then
            target="$backup_file"
        else
            echo -e "${RED}错误: 找不到标签为 '$target' 的备份${NC}" >&2
            return 1
        fi
    fi
    
    if [ ! -f "$target" ]; then
        echo -e "${RED}错误: 备份文件 $target 不存在${NC}" >&2
        return 1
    fi
    
    # 恢复前先备份当前配置
    backup_nginx "before_restore"
    
    # 恢复配置
    if tar -xzf "$target" -C "$(dirname "$NGINX_CONF_DIR")" 2>/dev/null; then
        echo -e "${GREEN}✅ 已从备份恢复: $target${NC}"
        return 0
    else
        echo -e "${RED}错误: 恢复配置失败${NC}" >&2
        return 1
    fi
}

# 测试nginx配置
test_nginx() {
    if nginx -t 2>/dev/null; then
        echo -e "${GREEN}✅ nginx配置测试通过${NC}"
        return 0
    else
        echo -e "${RED}❌ nginx配置测试失败${NC}"
        nginx -t
        return 1
    fi
}

# 重载nginx配置
reload_nginx() {
    if test_nginx; then
        if systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null; then
            echo -e "${GREEN}✅ nginx配置已重载${NC}"
            return 0
        else
            echo -e "${RED}错误: nginx重载失败${NC}" >&2
            return 1
        fi
    else
        return 1
    fi
}

# 检查nginx状态
check_nginx_status() {
    echo "Nginx服务状态:"
    echo "============================================"
    
    if systemctl is-active nginx >/dev/null 2>&1; then
        echo -e "服务状态: ${GREEN}运行中${NC}"
    else
        echo -e "服务状态: ${RED}未运行${NC}"
    fi
    
    if systemctl is-enabled nginx >/dev/null 2>&1; then
        echo -e "开机启动: ${GREEN}已启用${NC}"
    else
        echo -e "开机启动: ${YELLOW}未启用${NC}"
    fi
    
    echo
    echo "配置路径:"
    echo "----------------------------------------"
    echo "配置目录: $NGINX_CONF_DIR"
    echo "主配置文件: $NGINX_CONF_FILE"
    echo "站点配置目录: $NGINX_SITES_DIR"
    echo "启用站点目录: $NGINX_ENABLED_DIR"
    
    # 检查配置文件是否存在
    if [[ -f "$NGINX_CONF_FILE" ]]; then
        echo -e "主配置文件: ${GREEN}存在${NC}"
    else
        echo -e "主配置文件: ${RED}不存在${NC}"
    fi
    
    # 显示监听端口
    echo
    echo "监听端口:"
    echo "----------------------------------------"
    ss -tlnp | grep nginx | awk '{print $4}' | sort -u
    
    # 显示启用的站点
    echo
    echo "启用的站点:"
    echo "----------------------------------------"
    if [ -d "$NGINX_ENABLED_DIR" ]; then
        for site in "$NGINX_ENABLED_DIR"/*; do
            if [ -f "$site" ] && [ ! -L "$site" ] || [ -L "$site" ]; then
                basename "$site"
            fi
        done
    else
        echo "无启用站点"
    fi
}

# 列出所有站点
list_sites() {
    echo "Nginx站点列表:"
    echo "============================================"
    
    if [ ! -d "$NGINX_SITES_DIR" ]; then
        echo "站点目录不存在"
        return 1
    fi
    
    local has_sites=false
    
    for site_file in "$NGINX_SITES_DIR"/*; do
        if [ -f "$site_file" ]; then
            has_sites=true
            local site_name=$(basename "$site_file")
            local status="禁用"
            local ssl_status="无SSL"
            
            # 检查是否启用
            if [ -e "$NGINX_ENABLED_DIR/$site_name" ]; then
                status="${GREEN}启用${NC}"
            else
                status="${YELLOW}禁用${NC}"
            fi
            
            # 检查SSL配置
            if grep -q "ssl_certificate" "$site_file" 2>/dev/null; then
                ssl_status="${GREEN}SSL${NC}"
            fi
            
            # 获取server_name
            local server_names=$(grep -m 1 "server_name" "$site_file" 2>/dev/null | sed 's/.*server_name[[:space:]]*\([^;]*\);.*/\1/' | tr -d ' ')
            
            printf "%-20s %-10s %-8s %s\n" "$site_name" "$status" "$ssl_status" "$server_names"
        fi
    done
    
    if [ "$has_sites" = false ]; then
        echo "暂无配置的站点"
    fi
}

# 启用站点
enable_site() {
    local site_name=$1
    
    if [ ! -f "$NGINX_SITES_DIR/$site_name" ]; then
        echo -e "${RED}错误: 站点配置文件不存在: $site_name${NC}" >&2
        return 1
    fi
    
    if [ -e "$NGINX_ENABLED_DIR/$site_name" ]; then
        echo -e "${YELLOW}站点 '$site_name' 已经启用${NC}"
        return 0
    fi
    
    if ln -s "$NGINX_SITES_DIR/$site_name" "$NGINX_ENABLED_DIR/$site_name" 2>/dev/null; then
        echo -e "${GREEN}✅ 已启用站点: $site_name${NC}"
        return 0
    else
        echo -e "${RED}错误: 无法启用站点 $site_name${NC}" >&2
        return 1
    fi
}

# 禁用站点
disable_site() {
    local site_name=$1
    
    if [ ! -e "$NGINX_ENABLED_DIR/$site_name" ]; then
        echo -e "${YELLOW}站点 '$site_name' 已经禁用${NC}"
        return 0
    fi
    
    if rm "$NGINX_ENABLED_DIR/$site_name" 2>/dev/null; then
        echo -e "${GREEN}✅ 已禁用站点: $site_name${NC}"
        return 0
    else
        echo -e "${RED}错误: 无法禁用站点 $site_name${NC}" >&2
        return 1
    fi
}

# 移除站点
remove_site() {
    local site_name=$1
    
    if [ ! -f "$NGINX_SITES_DIR/$site_name" ]; then
        echo -e "${YELLOW}站点配置文件不存在: $site_name${NC}"
        return 0
    fi
    
    # 先禁用站点
    disable_site "$site_name"
    
    # 删除配置文件
    if rm "$NGINX_SITES_DIR/$site_name" 2>/dev/null; then
        echo -e "${GREEN}✅ 已移除站点配置: $site_name${NC}"
        return 0
    else
        echo -e "${RED}错误: 无法移除站点配置 $site_name${NC}" >&2
        return 1
    fi
}

# 主函数
main() {
    check_root
    check_dependencies
    
    # 解析全局参数
    local custom_config_path=""
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                if [[ -n "$2" && "$2" != -* ]]; then
                    custom_config_path="$2"
                    shift 2
                else
                    echo -e "${RED}错误: --config 需要指定路径${NC}" >&2
                    exit 1
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}错误: 未知的全局选项: $1${NC}" >&2
                show_help
                exit 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # 设置nginx配置路径
    set_nginx_paths "$custom_config_path"
    
    # 初始化环境
    init_environment
    
    # 恢复参数
    set -- "${args[@]}"
    
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command=$1
    shift
    
    case "$command" in
        add-site)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定域名${NC}" >&2
                show_help
                exit 1
            fi
            local domain=$1
            shift
            validate_domain "$domain"
            add_static_site "$domain" "$@"
            ;;
            
        add-proxy)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定域名${NC}" >&2
                show_help
                exit 1
            fi
            local domain=$1
            shift
            validate_domain "$domain"
            add_proxy_site "$domain" "$@"
            ;;
            
        remove-site)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定域名${NC}" >&2
                exit 1
            fi
            remove_site "$1"
            ;;
            
        enable-site)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定域名${NC}" >&2
                exit 1
            fi
            enable_site "$1"
            ;;
            
        disable-site)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定域名${NC}" >&2
                exit 1
            fi
            disable_site "$1"
            ;;
            
        list-sites)
            list_sites
            ;;
            
        backup)
            backup_nginx "$1"
            ;;
            
        restore)
            restore_nginx "$1"
            ;;
            
        test)
            test_nginx
            ;;
            
        reload)
            reload_nginx
            ;;
            
        optimize)
            optimize_nginx
            ;;
            
        ssl-setup)
            if [ $# -lt 1 ]; then
                echo -e "${RED}错误: 需要指定域名${NC}" >&2
                exit 1
            fi
            local domain=$1
            shift
            validate_domain "$domain"
            setup_ssl "$domain" "$@"
            ;;
            
        status)
            check_nginx_status
            ;;
            
        generate-docs)
            generate_docs
            ;;
            
        help|--help|-h)
            show_help
            ;;
            
        *)
            echo -e "${RED}错误: 未知命令 '$command'${NC}" >&2
            echo "使用 '$0 help' 查看帮助信息" >&2
            exit 1
            ;;
    esac
}

# 添加静态网站
add_static_site() {
    local domain=$1
    shift
    
    # 解析选项
    local root_dir="/var/www/$domain"
    local enable_ssl=false
    local ssl_cert=""
    local ssl_key=""
    local index_files="index.html index.htm index.php"
    local enable_log=false
    local enable_gzip=false
    local max_body_size="1m"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -r|--root)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --root 需要参数${NC}" >&2
                    exit 1
                fi
                root_dir="$2"
                shift 2
                ;;
            -s|--ssl)
                enable_ssl=true
                shift
                ;;
            -c|--cert)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --cert 需要参数${NC}" >&2
                    exit 1
                fi
                ssl_cert="$2"
                enable_ssl=true
                shift 2
                ;;
            -k|--key)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --key 需要参数${NC}" >&2
                    exit 1
                fi
                ssl_key="$2"
                shift 2
                ;;
            -i|--index)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --index 需要参数${NC}" >&2
                    exit 1
                fi
                index_files="$2"
                shift 2
                ;;
            -l|--log)
                enable_log=true
                shift
                ;;
            -g|--gzip)
                enable_gzip=true
                shift
                ;;
            -m|--max-body)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --max-body 需要参数${NC}" >&2
                    exit 1
                fi
                max_body_size="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}" >&2
                exit 1
                ;;
        esac
    done
    
    # 创建站点配置文件
    local config_file="$NGINX_SITES_DIR/$domain"
    
    # 备份现有配置
    if [ -f "$config_file" ]; then
        backup_nginx "before_${domain}_update"
    fi
    
    # 生成配置内容
    cat > "$config_file" << EOF
# $domain - 静态网站配置
# 生成时间: $(date)

server {
    listen 80;
    server_name $domain www.$domain;
    
    root $root_dir;
    index $index_files;
    
    # 安全设置
    server_tokens off;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # 客户端设置
    client_max_body_size $max_body_size;
    
EOF

    # 添加SSL配置
    if [ "$enable_ssl" = true ]; then
        cat >> "$config_file" << EOF
    # HTTP重定向到HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain www.$domain;
    
    root $root_dir;
    index $index_files;
    
    # SSL配置
EOF
        if [ -n "$ssl_cert" ] && [ -n "$ssl_key" ]; then
            cat >> "$config_file" << EOF
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
EOF
        else
            cat >> "$config_file" << EOF
    ssl_certificate /etc/ssl/certs/$domain.pem;
    ssl_certificate_key /etc/ssl/private/$domain.key;
EOF
        fi
        
        cat >> "$config_file" << EOF
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 5m;
    
    # 安全设置
    server_tokens off;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 客户端设置
    client_max_body_size $max_body_size;
    
EOF
    fi
    
    # 添加gzip配置
    if [ "$enable_gzip" = true ]; then
        cat >> "$config_file" << EOF
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
EOF
    fi
    
    # 添加日志配置
    if [ "$enable_log" = true ]; then
        cat >> "$config_file" << EOF
    # 访问日志
    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
    
EOF
    fi
    
    # 添加基本location配置
    cat >> "$config_file" << EOF
    # 静态文件处理
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # 安全设置
    location ~ /\. {
        deny all;
    }
    
    location ~ ~\$ {
        deny all;
    }
}
EOF
    
    echo -e "${GREEN}✅ 已创建静态网站配置: $domain${NC}"
    echo "   - 网站根目录: $root_dir"
    echo "   - SSL: $([ "$enable_ssl" = true ] && echo "启用" || echo "禁用")"
    echo "   - Gzip: $([ "$enable_gzip" = true ] && echo "启用" || echo "禁用")"
    echo "   - 日志: $([ "$enable_log" = true ] && echo "启用" || echo "禁用")"
    
    # 创建网站根目录
    if [ ! -d "$root_dir" ]; then
        if mkdir -p "$root_dir" 2>/dev/null; then
            echo "   - 已创建根目录: $root_dir"
            
            # 创建默认index.html
            cat > "$root_dir/index.html" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to $domain</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <h1>Welcome to $domain</h1>
    <p>Your nginx server is working correctly.</p>
    <p>Please replace this default page with your own content.</p>
</body>
</html>
EOF
            echo "   - 已创建默认首页"
        else
            echo -e "${YELLOW}   - 警告: 无法创建根目录 $root_dir${NC}"
        fi
    fi
    
    # 自动启用站点
    enable_site "$domain"
}

# 添加反向代理站点
add_proxy_site() {
    local domain=$1
    shift
    
    # 解析选项
    local proxy_pass=""
    local enable_ssl=false
    local ssl_cert=""
    local ssl_key=""
    local enable_websocket=false
    local timeout=60
    local enable_log=false
    local max_body_size="10m"
    local load_balance=false
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -p|--proxy)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --proxy 需要参数${NC}" >&2
                    exit 1
                fi
                proxy_pass="$2"
                shift 2
                ;;
            -s|--ssl)
                enable_ssl=true
                shift
                ;;
            -c|--cert)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --cert 需要参数${NC}" >&2
                    exit 1
                fi
                ssl_cert="$2"
                enable_ssl=true
                shift 2
                ;;
            -k|--key)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --key 需要参数${NC}" >&2
                    exit 1
                fi
                ssl_key="$2"
                shift 2
                ;;
            -w|--websocket)
                enable_websocket=true
                shift
                ;;
            -t|--timeout)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --timeout 需要参数${NC}" >&2
                    exit 1
                fi
                timeout="$2"
                shift 2
                ;;
            -l|--log)
                enable_log=true
                shift
                ;;
            -m|--max-body)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --max-body 需要参数${NC}" >&2
                    exit 1
                fi
                max_body_size="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}" >&2
                exit 1
                ;;
        esac
    done
    
    if [ -z "$proxy_pass" ]; then
        echo -e "${RED}错误: 必须指定反向代理目标 --proxy${NC}" >&2
        exit 1
    fi
    
    # 检查是否为负载均衡配置
    if [[ "$proxy_pass" == *","* ]]; then
        load_balance=true
    fi
    
    # 创建站点配置文件
    local config_file="$NGINX_SITES_DIR/$domain"
    
    # 备份现有配置
    if [ -f "$config_file" ]; then
        backup_nginx "before_${domain}_update"
    fi
    
    # 生成配置内容
    cat > "$config_file" << EOF
# $domain - 反向代理配置
# 生成时间: $(date)

EOF

    # 添加负载均衡配置
    if [ "$load_balance" = true ]; then
        cat >> "$config_file" << EOF
upstream ${domain}_backend {
EOF
        IFS=',' read -ra BACKENDS <<< "$proxy_pass"
        for backend in "${BACKENDS[@]}"; do
            backend=$(echo "$backend" | xargs) # 去除空格
            cat >> "$config_file" << EOF
    server ${backend#http://} max_fails=3 fail_timeout=30s;
EOF
        done
        cat >> "$config_file" << EOF
    keepalive 32;
}

EOF
        proxy_pass="http://${domain}_backend"
    fi
    
    cat >> "$config_file" << EOF
server {
    listen 80;
    server_name $domain www.$domain;
    
    # 安全设置
    server_tokens off;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # 客户端设置
    client_max_body_size $max_body_size;
    
EOF

    # 添加SSL配置
    if [ "$enable_ssl" = true ]; then
        cat >> "$config_file" << EOF
    # HTTP重定向到HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain www.$domain;
    
    # SSL配置
EOF
        if [ -n "$ssl_cert" ] && [ -n "$ssl_key" ]; then
            cat >> "$config_file" << EOF
    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
EOF
        else
            cat >> "$config_file" << EOF
    ssl_certificate /etc/ssl/certs/$domain.pem;
    ssl_certificate_key /etc/ssl/private/$domain.key;
EOF
        fi
        
        cat >> "$config_file" << EOF
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 5m;
    
    # 安全设置
    server_tokens off;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 客户端设置
    client_max_body_size $max_body_size;
    
EOF
    fi
    
    # 添加日志配置
    if [ "$enable_log" = true ]; then
        cat >> "$config_file" << EOF
    # 访问日志
    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
    
EOF
    fi
    
    # 添加反向代理配置
    cat >> "$config_file" << EOF
    # 反向代理配置
    location / {
        proxy_pass $proxy_pass;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # 超时设置
        proxy_connect_timeout ${timeout}s;
        proxy_send_timeout ${timeout}s;
        proxy_read_timeout ${timeout}s;
        
        # 缓冲设置
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
        
        # 长连接支持
        proxy_set_header Connection "";
EOF

    # 添加WebSocket支持
    if [ "$enable_websocket" = true ]; then
        cat >> "$config_file" << EOF
        
        # WebSocket支持
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_cache_bypass \$http_upgrade;
EOF
    fi
    
    cat >> "$config_file" << EOF
    }
    
    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    echo -e "${GREEN}✅ 已创建反向代理配置: $domain${NC}"
    echo "   - 代理目标: $proxy_pass"
    echo "   - SSL: $([ "$enable_ssl" = true ] && echo "启用" || echo "禁用")"
    echo "   - WebSocket: $([ "$enable_websocket" = true ] && echo "启用" || echo "禁用")"
    echo "   - 负载均衡: $([ "$load_balance" = true ] && echo "启用" || echo "禁用")"
    echo "   - 超时: ${timeout}s"
    echo "   - 日志: $([ "$enable_log" = true ] && echo "启用" || echo "禁用")"
    
    # 自动启用站点
    enable_site "$domain"
}

# 设置SSL证书
setup_ssl() {
    local domain=$1
    shift
    
    local ssl_cert=""
    local ssl_key=""
    local auto_cert=false
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--cert)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --cert 需要参数${NC}" >&2
                    exit 1
                fi
                ssl_cert="$2"
                shift 2
                ;;
            -k|--key)
                if [ -z "$2" ]; then
                    echo -e "${RED}错误: --key 需要参数${NC}" >&2
                    exit 1
                fi
                ssl_key="$2"
                shift 2
                ;;
            -a|--auto)
                auto_cert=true
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}" >&2
                exit 1
                ;;
        esac
    done
    
    if [ "$auto_cert" = true ]; then
        # 自动生成自签名证书
        ssl_cert="/etc/ssl/certs/$domain.pem"
        ssl_key="/etc/ssl/private/$domain.key"
        
        # 创建目录
        mkdir -p "$(dirname "$ssl_cert")" "$(dirname "$ssl_key")"
        
        # 生成私钥
        openssl genrsa -out "$ssl_key" 2048 2>/dev/null
        
        # 生成证书请求
        openssl req -new -key "$ssl_key" -out "/tmp/$domain.csr" \
            -subj "/C=CN/ST=State/L=City/O=Organization/CN=$domain" 2>/dev/null
        
        # 生成自签名证书
        openssl x509 -req -in "/tmp/$domain.csr" -signkey "$ssl_key" \
            -out "$ssl_cert" -days 365 2>/dev/null
        
        # 清理临时文件
        rm "/tmp/$domain.csr" 2>/dev/null
        
        # 设置权限
        chmod 600 "$ssl_key"
        chmod 644 "$ssl_cert"
        
        echo -e "${GREEN}✅ 已生成自签名SSL证书: $domain${NC}"
        echo "   - 证书文件: $ssl_cert"
        echo "   - 私钥文件: $ssl_key"
        echo -e "${YELLOW}   - 注意: 自签名证书仅用于测试，生产环境请使用CA签名证书${NC}"
    else
        if [ -z "$ssl_cert" ] || [ -z "$ssl_key" ]; then
            echo -e "${RED}错误: 必须指定证书和私钥文件，或使用 --auto 生成自签名证书${NC}" >&2
            exit 1
        fi
        
        if [ ! -f "$ssl_cert" ]; then
            echo -e "${RED}错误: SSL证书文件不存在: $ssl_cert${NC}" >&2
            exit 1
        fi
        
        if [ ! -f "$ssl_key" ]; then
            echo -e "${RED}错误: SSL私钥文件不存在: $ssl_key${NC}" >&2
            exit 1
        fi
        
        echo -e "${GREEN}✅ SSL证书配置完成: $domain${NC}"
        echo "   - 证书文件: $ssl_cert"
        echo "   - 私钥文件: $ssl_key"
    fi
    
    # 更新站点配置以启用SSL
    local config_file="$NGINX_SITES_DIR/$domain"
    if [ -f "$config_file" ]; then
        backup_nginx "before_ssl_${domain}"
        
        # 这里可以添加更复杂的配置更新逻辑
        echo -e "${BLUE}提示: 请手动更新站点配置以启用SSL，或重新创建站点配置${NC}"
    fi
}

# 优化nginx主配置
optimize_nginx() {
    backup_nginx "before_optimize"
    
    echo "优化nginx主配置..."
    
    # 检查是否已经优化过
    if grep -q "# Optimized by nginx-manager" "$NGINX_CONF_FILE" 2>/dev/null; then
        echo -e "${YELLOW}nginx配置已经优化过${NC}"
        return 0
    fi
    
    # 创建优化配置
    cat > "/tmp/nginx_optimization.conf" << 'EOF'
# Optimized by nginx-manager

# 工作进程数 (通常设置为CPU核心数)
worker_processes auto;

# 工作进程的最大文件描述符数
worker_rlimit_nofile 65535;

events {
    # 每个工作进程的最大连接数
    worker_connections 1024;
    
    # 使用epoll (Linux 2.6+)
    use epoll;
    
    # 允许一个工作进程同时接受多个连接
    multi_accept on;
}

http {
    # 基本设置
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    # 访问日志
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    
    # 连接超时
    keepalive_timeout 65;
    keepalive_requests 100;
    
    # 客户端设置
    client_max_body_size 10m;
    client_body_timeout 60;
    client_header_timeout 60;
    client_body_buffer_size 16k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;
    
    # 服务器设置
    server_tokens off;
    server_names_hash_bucket_size 128;
    server_name_in_redirect off;
    
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # 包含站点配置
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
    
    # 备份并替换配置文件
    if cp "$NGINX_CONF_FILE" "${NGINX_CONF_FILE}.backup" && 
       cp "/tmp/nginx_optimization.conf" "$NGINX_CONF_FILE"; then
        echo -e "${GREEN}✅ nginx配置已优化${NC}"
        echo "   - 原配置备份: ${NGINX_CONF_FILE}.backup"
        
        # 清理临时文件
        rm "/tmp/nginx_optimization.conf"
        
        # 测试配置
        if test_nginx; then
            echo -e "${GREEN}✅ 优化配置测试通过${NC}"
        else
            echo -e "${RED}❌ 优化配置测试失败，正在恢复原配置${NC}"
            cp "${NGINX_CONF_FILE}.backup" "$NGINX_CONF_FILE"
            return 1
        fi
    else
        echo -e "${RED}错误: 无法优化nginx配置${NC}" >&2
        return 1
    fi
}

# 执行主函数
main "$@"
