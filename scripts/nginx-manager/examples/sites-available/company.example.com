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
    index index.html index.htm index.nginx-debian.html;
    
    # SSL 证书配置
    ssl_certificate /etc/ssl/certs/company.example.com.pem;
    ssl_certificate_key /etc/ssl/private/company.example.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
    }
    
    # 主页面配置
    location / {
        try_files $uri $uri/ =404;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
    }
    
    # 错误页面
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    # 访问日志
    access_log /var/log/nginx/company.example.com.access.log main;
    error_log /var/log/nginx/company.example.com.error.log;
}
