# 🚀 Nginx Manager 示例和演示

本目录包含 nginx-manager.sh 的完整示例配置和演示脚本，展示各种实际使用场景。

## 📁 目录结构

```
examples/
├── README.md              # 本说明文件
├── demo.sh               # 功能演示脚本
├── nginx.conf            # 优化的主配置文件示例
├── sites-available/      # 站点配置示例
│   ├── company.example.com   # 静态网站 + SSL
│   ├── api.example.com       # API反向代理
│   ├── ws.example.com        # WebSocket长连接
│   └── app.example.com       # 负载均衡应用
└── sites-enabled/        # 启用站点（软链接）
    ├── company.example.com -> ../sites-available/company.example.com
    ├── api.example.com     -> ../sites-available/api.example.com
    └── ws.example.com      -> ../sites-available/ws.example.com
```

## 🎯 示例配置说明

### 1. 静态网站 (company.example.com)
**适用场景**: 企业官网、文档站点、博客

**特性**:
- ✅ HTTPS 重定向
- ✅ SSL/TLS 配置
- ✅ Gzip 压缩
- ✅ 静态资源缓存
- ✅ 安全头设置
- ✅ 错误页面配置

**生成命令**:
```bash
sudo ./nginx-manager.sh add-site company.example.com \
  --root /var/www/company.example.com \
  --ssl --log --gzip
```

### 2. API 反向代理 (api.example.com)
**适用场景**: RESTful API、微服务接口

**特性**:
- ✅ 负载均衡后端池
- ✅ 健康检查端点
- ✅ 超时和重试配置
- ✅ 请求体大小限制
- ✅ 详细访问日志
- ✅ 错误处理和故障转移

**生成命令**:
```bash
sudo ./nginx-manager.sh add-proxy api.example.com \
  --proxy http://backend_api \
  --ssl --log --timeout 60
```

### 3. WebSocket 长连接 (ws.example.com)
**适用场景**: 实时通信、在线聊天、游戏服务器

**特性**:
- ✅ WebSocket 协议升级
- ✅ 长连接超时优化 (300s)
- ✅ 实时传输（禁用缓冲）
- ✅ 连接保持设置
- ✅ 故障转移机制
- ✅ 静态资源服务

**生成命令**:
```bash
sudo ./nginx-manager.sh add-proxy ws.example.com \
  --proxy http://websocket_backend \
  --websocket --ssl --timeout 300
```

### 4. 负载均衡应用 (app.example.com)
**适用场景**: 高并发Web应用、集群部署

**特性**:
- ✅ 多后端服务器 (3台)
- ✅ 权重分配和备份服务器
- ✅ 连接池优化 (keepalive)
- ✅ API 限流配置
- ✅ 会话保持选项
- ✅ 健康检查和故障转移

**生成命令**:
```bash
sudo ./nginx-manager.sh add-proxy app.example.com \
  --proxy "http://10.0.1.10:8080,http://10.0.1.11:8080,http://10.0.1.12:8080" \
  --ssl --log --timeout 60
```

## 🎬 运行演示

### 1. 功能演示脚本
```bash
# 查看完整功能演示
./demo.sh
```

演示内容包括：
- 📁 自定义配置路径使用
- 🌐 各种站点配置分析
- 📊 配置文件特性统计
- 🛠️ 管理命令示例
- 💡 最佳实践建议
- 📚 文档生成演示

### 2. 测试自定义配置功能
```bash
# 使用示例配置目录测试
cd .. # 回到 nginx-manager 目录
```bash
# 使用示例配置
sudo ./nginx-manager.sh -c examples status
sudo ./nginx-manager.sh -c examples list-sites
sudo ./nginx-manager.sh -c examples generate-docs
# 生成的文档保存在 docs/ 目录中
```
```

### 3. 配置文件测试
```bash
# 测试nginx配置语法（需要nginx已安装）
sudo nginx -t -c /path/to/examples/nginx.conf
```

## 📊 配置统计

本示例配置包含：
- **站点总数**: 4
- **启用站点**: 3
- **SSL 站点**: 4 (100%)
- **反向代理**: 3
- **WebSocket 支持**: 1
- **负载均衡**: 2
- **静态网站**: 1

## 🚀 实际部署

要将这些示例应用到实际环境：

### 1. 复制配置结构
```bash
# 创建标准nginx目录结构
sudo mkdir -p /etc/nginx/sites-{available,enabled}

# 复制主配置文件
sudo cp examples/nginx.conf /etc/nginx/nginx.conf.example

# 复制站点配置
sudo cp examples/sites-available/* /etc/nginx/sites-available/
```

### 2. 修改配置参数
- 🔧 更新域名为实际域名
- 🔧 修改SSL证书路径
- 🔧 调整后端服务器地址
- 🔧 设置正确的网站根目录
- 🔧 配置实际的日志路径

### 3. 启用站点
```bash
# 使用nginx-manager管理
sudo ./nginx-manager.sh enable-site company.example.com
sudo ./nginx-manager.sh enable-site api.example.com
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

## 💡 学习要点

1. **配置模式识别**: 了解不同类型站点的配置模式
2. **性能优化**: 学习缓存、压缩、连接池等优化技巧
3. **安全最佳实践**: SSL配置、安全头、访问控制
4. **长连接处理**: WebSocket协议升级和超时设置
5. **负载均衡策略**: 权重分配、健康检查、故障转移
6. **运维自动化**: 使用脚本管理配置生命周期

## 🔗 相关文档

- [完整使用手册](../README.md)
- [快速入门指南](../QUICKSTART.md)
- [自定义配置说明](../CUSTOM-CONFIG.md)

## 🤝 自定义示例

欢迎根据实际需求修改这些示例，或添加新的配置案例！
