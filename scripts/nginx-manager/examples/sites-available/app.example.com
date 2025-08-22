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
    
    # HTTP 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name app.example.com;
    
    # SSL 证书配置
    ssl_certificate /etc/ssl/certs/app.example.com.pem;
    ssl_certificate_key /etc/ssl/private/app.example.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 负载均衡代理配置
    location / {
        proxy_pass http://app_backend;
        
        # 代理头设置
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # 会话保持（可选）
        # proxy_set_header Cookie $http_cookie;
        
        # 超时设置
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # 缓冲设置
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # 错误处理和故障转移
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 30s;
        
        # 健康检查间隔
        proxy_intercept_errors on;
    }
    
    # API 接口专用配置
    location /api/ {
        proxy_pass http://app_backend/api/;
        
        # API 专用头设置
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type application/json;
        
        # API 限流
        limit_req zone=api_limit burst=10 nodelay;
        
        # 更严格的超时
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # 静态资源缓存
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://app_backend;
        expires 1d;
        add_header Cache-Control "public";
        add_header Vary Accept-Encoding;
    }
    
    # 健康检查端点
    location /health {
        proxy_pass http://app_backend/health;
        proxy_set_header Host $host;
        access_log off;
    }
    
    # 限制请求体大小
    client_max_body_size 100m;
    
    # 访问日志
    access_log /var/log/nginx/app.example.com.access.log detailed;
    error_log /var/log/nginx/app.example.com.error.log;
}
