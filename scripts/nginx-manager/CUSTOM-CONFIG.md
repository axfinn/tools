# 自定义Nginx配置路径功能说明

## 功能概述

nginx-manager.sh 现已支持指定自定义的nginx配置文件或目录进行操作，这使得脚本更加灵活，适用于各种部署场景。

## 新增功能

### 1. 自定义配置路径支持

- **配置目录指定**: `-c /custom/nginx`
- **配置文件指定**: `-c /custom/nginx/nginx.conf`
- **自动路径检测**: 脚本会自动判断输入是文件还是目录

### 2. 智能路径管理

```bash
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
```

### 3. 中文文档生成增强

生成的文档现在包含：
- 配置目录路径信息
- 主配置文件路径
- 长连接配置统计
- WebSocket站点统计

## 使用场景

### 开发环境

```bash
# 为开发环境创建独立的nginx配置
sudo ./nginx-manager.sh -c /tmp/dev-nginx add-site dev.example.com -r /var/www/dev
```

### 容器化部署

```bash
# Docker容器中的nginx配置
sudo ./nginx-manager.sh -c /etc/nginx-custom add-proxy api.app.com -p http://backend:3000
```

### 多实例管理

```bash
# 管理多个nginx实例
sudo ./nginx-manager.sh -c /etc/nginx-instance1 status
sudo ./nginx-manager.sh -c /etc/nginx-instance2 status
```

## 长连接处理方案

### WebSocket长连接优化

脚本对长连接反向代理网站的处理策略：

1. **协议升级处理**
   ```nginx
   proxy_http_version 1.1;
   proxy_set_header Upgrade $http_upgrade;
   proxy_set_header Connection "upgrade";
   ```

2. **连接保持优化**
   ```nginx
   proxy_set_header Host $host;
   proxy_set_header X-Real-IP $remote_addr;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   proxy_set_header X-Forwarded-Proto $scheme;
   ```

3. **超时时间扩展**
   ```nginx
   proxy_connect_timeout 300s;
   proxy_send_timeout 300s;
   proxy_read_timeout 300s;
   ```

4. **缓存策略调整**
   ```nginx
   proxy_cache_bypass $http_upgrade;
   proxy_no_cache $http_upgrade;
   ```

### 长连接性能优化

对于高并发长连接场景：

- **upstream keepalive**: 配置连接池复用后端连接
- **proxy_buffering**: 智能缓冲控制
- **client_max_body_size**: 适配大数据传输
- **worker_connections**: 优化工作进程连接数

## 测试方法

使用提供的测试脚本验证功能：

```bash
# 运行自定义配置测试
sudo ./test-custom-config.sh

# 运行基本功能测试
sudo ./test.sh
```

## 最佳实践

1. **配置隔离**: 不同项目使用独立的nginx配置目录
2. **备份策略**: 使用自定义路径时，确保备份路径正确
3. **权限管理**: 确保自定义路径具有正确的文件权限
4. **路径规范**: 使用绝对路径避免相对路径问题
