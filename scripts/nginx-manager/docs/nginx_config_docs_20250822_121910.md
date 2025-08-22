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
| **总站点数** | 0 | 100% |
| **已启用站点** | 0 | 0% |
| **反向代理站点** | 0 | 0% |
| **静态网站** | 0 | 0% |
| **SSL站点** | 0 | 0% |
| **长连接优化** | 0 | 0% (反向代理中) |
| **WebSocket支持** | 0 | 0% (反向代理中) |

---

## 🌐 站点详情


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

**文档生成完成时间**: 2025年08月22日 12:19:10  
**生成工具**: nginx-manager.sh  
**版本**: 2.0
