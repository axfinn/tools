# 🌐 Nginx 配置文档

**生成时间**: DOC_TIMESTAMP  
**服务器**: DOC_HOSTNAME  
**Nginx版本**: DOC_VERSION  
**配置目录**: DOC_CONFIG_DIR  
**主配置文件**: DOC_CONFIG_FILE

---

## 📋 配置概览


### 📊 数据统计

| 项目 | 数量 | 百分比 |
|------|------|--------|
| **总站点数** | 4 | 100% |
| **已启用站点** | 3 | 75% |
| **反向代理站点** | 3 | 75% |
| **静态网站** | 1 | 25% |
| **SSL站点** | 4 | 100% |
| **长连接优化** | 1 | 33% (反向代理中) |
| **WebSocket支持** | 1 | 33% (反向代理中) |

---

## 🌐 站点详情


### 🏷️ api.example.com

- **状态**: ✅ 已启用
- **运行状态**: 🟢 在线

- **类型**: 🔄 反向代理
- **后端服务器**:
  - `http://backend_api`
  - `http://backend_api/health`
- **🔗 长连接优化**: ❌ 未启用 
  - ⚠️ 建议启用长连接以提高性能
- **🌐 WebSocket**: ❌ 不支持
- **⚖️ 负载均衡**: ✅ 已配置
- **🔒 SSL/HTTPS**: ✅ 已配置
  - 证书路径: `/etc/ssl/certs/api.example.com.pem`
  - 支持协议: `TLSv1.2 TLSv1.3`
- **🗜️ Gzip压缩**: ❌ 未启用
- **💾 缓存**: ❌ 未配置
- **📊 访问日志**: ❌ 已关闭

**配置预览**:
```nginx
# API反向代理配置 - api.example.com
# 生成时间: 2025-08-22 15:30:00
# 由 nginx-manager.sh 自动生成

server {
    listen 80;
    listen [::]:80;
    server_name api.example.com;
    
    # HTTP 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.example.com;
    
    # SSL 证书配置
    ssl_certificate /etc/ssl/certs/api.example.com.pem;
```


### 🏷️ app.example.com

- **状态**: ❌ 未启用
- **运行状态**: 🔴 离线

- **类型**: 🔄 反向代理
- **后端服务器**:
  - `http://app_backend`
  - `http://app_backend/api/`
  - `http://app_backend/health`
- **🔗 长连接优化**: ✅ 已启用
  - 连接池大小: `32`
  - 超时时间: `60s`
  - 最大请求数: `100`
- **🌐 WebSocket**: ❌ 不支持
- **⚖️ 负载均衡**: ✅ 已配置
- **🔒 SSL/HTTPS**: ✅ 已配置
  - 证书路径: `/etc/ssl/certs/app.example.com.pem`
  - 支持协议: `TLSv1.2 TLSv1.3`
- **🗜️ Gzip压缩**: ❌ 未启用
- **💾 缓存**: ✅ 已配置
- **📊 访问日志**: ❌ 已关闭

**配置预览**:
```nginx
# 负载均衡应用配置 - app.example.com
# 生成时间: 2025-08-22 15:30:00
# 由 nginx-manager.sh 自动生成

# 应用服务器负载均衡池
upstream app_backend {
    least_conn;
    server 10.0.1.10:8080 weight=3 max_fails=3 fail_timeout=30s;
    server 10.0.1.11:8080 weight=3 max_fails=3 fail_timeout=30s;
    server 10.0.1.12:8080 weight=2 max_fails=3 fail_timeout=30s backup;
    keepalive 32;
    keepalive_requests 100;
    keepalive_timeout 60s;
}

server {
    listen 80;
    listen [::]:80;
    server_name app.example.com;
    
```


### 🏷️ company.example.com

- **状态**: ✅ 已启用
- **运行状态**: 🟢 在线

- **类型**: 📁 静态网站
- **根目录**: `/var/www/company.example.com`
- **索引文件**: `.nginx-debian.html`
- **🔒 SSL/HTTPS**: ✅ 已配置
  - 证书路径: `/etc/ssl/certs/company.example.com.pem`
  - 支持协议: `TLSv1.2 TLSv1.3`
- **🗜️ Gzip压缩**: ✅ 已启用
- **💾 缓存**: ✅ 已配置
- **📊 访问日志**: `/var/log/nginx/company.example.com.access.log main`

**配置预览**:
```nginx
# 静态网站配置 - company.example.com
# 生成时间: 2025-08-22 15:30:00
# 由 nginx-manager.sh 自动生成

server {
    listen 80;
    listen [::]:80;
    server_name company.example.com www.company.example.com;
    
    # HTTP 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name company.example.com www.company.example.com;
    
    # 网站根目录
    root /var/www/company.example.com;
```


### 🏷️ ws.example.com

- **状态**: ✅ 已启用
- **运行状态**: 🟢 在线

- **类型**: 🔄 反向代理
- **后端服务器**:
  - `http://websocket_backend`
- **🔗 长连接优化**: ❌ 未启用 
  - ⚠️ 建议启用长连接以提高性能
- **🌐 WebSocket**: ✅ 支持
- **⚖️ 负载均衡**: ✅ 已配置
- **🔒 SSL/HTTPS**: ✅ 已配置
  - 证书路径: `/etc/ssl/certs/ws.example.com.pem`
  - 支持协议: `TLSv1.2 TLSv1.3`
- **🗜️ Gzip压缩**: ❌ 未启用
- **💾 缓存**: ✅ 已配置
- **📊 访问日志**: `/var/log/nginx/ws.example.com.access.log detailed`

**配置预览**:
```nginx
# WebSocket长连接代理配置 - ws.example.com
# 生成时间: 2025-08-22 15:30:00
# 由 nginx-manager.sh 自动生成

server {
    listen 80;
    listen [::]:80;
    server_name ws.example.com;
    
    # HTTP 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ws.example.com;
    
    # SSL 证书配置
    ssl_certificate /etc/ssl/certs/ws.example.com.pem;
```


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


### ⚠️ 针对当前配置的建议

1. **长连接优化不足**: 发现 3 个反向代理站点中只有 1 个启用了长连接
   - 建议为所有反向代理站点启用长连接以提高性能
   - 使用命令: `nginx-manager.sh add-proxy <域名> --proxy <后端> --keepalive`


---

## 📚 命令参考

### 长连接反向代理
```bash
# 添加带长连接优化的反向代理
nginx-manager.sh add-proxy api.example.com --proxy http://127.0.0.1:8080 --keepalive

# 添加WebSocket支持的反向代理  
nginx-manager.sh add-proxy ws.example.com --proxy http://127.0.0.1:3000 --websocket --keepalive
```

### SSL配置
```bash
# 为站点配置SSL
nginx-manager.sh ssl-setup example.com

# 添加SSL站点
nginx-manager.sh add-site example.com --ssl --root /var/www/example.com
```

### 配置管理
```bash
# 测试配置
nginx-manager.sh test

# 重载配置
nginx-manager.sh reload

# 查看状态
nginx-manager.sh status
```

---

**文档生成完成时间**: 2025年08月22日 12:16:55  
**生成工具**: nginx-manager.sh  
**版本**: 2.0
