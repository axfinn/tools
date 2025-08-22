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
    ssl_certificate_key /etc/ssl/private/api.example.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 反向代理配置
    location / {
        proxy_pass http://backend_api;
        
        # 代理头设置
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # 超时设置
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # 缓冲设置
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # 错误处理
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 30s;
    }
    
    # API 健康检查端点
    location /health {
        proxy_pass http://backend_api/health;
        proxy_set_header Host $host;
        access_log off;
    }
    
    # 限制请求体大小
    client_max_body_size 10m;
    
    # 访问日志
    access_log /var/log/nginx/api.example.com.access.log detailed;
    error_log /var/log/nginx/api.example.com.error.log;
}
