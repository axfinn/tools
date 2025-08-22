# Nginx配置管理脚本使用手册

## 概述

`nginx-manager.sh` 是一个专业的Nginx配置管理脚本，提供了完整的虚拟站点管理、反向代理配置、SSL证书设置等功能。

## 功能特性

- ✅ **虚拟站点管理**: 快速创建和管理静态网站
- ✅ **反向代理配置**: 简化的反向代理设置
- ✅ **负载均衡配置**: 支持单后端和负载均衡代理
- ✅ **SSL证书管理**: 自动配置SSL证书和安全设置
- ✅ **WebSocket支持**: 完整的WebSocket长连接支持
- ✅ **负载均衡**: 多后端服务器负载均衡
- ✅ **配置备份**: 自动备份和恢复nginx配置
- ✅ **安全优化**: 内置安全头和最佳实践配置
- ✅ **性能优化**: Gzip压缩、缓存、长连接等优化
- ✅ **配置测试**: 自动测试配置有效性
- ✅ **生成中文配置文档**: 自动生成当前nginx配置的中文Markdown文档

## 🖥️ 系统兼容性

本项目提供了多个版本以确保最佳兼容性：

| 脚本版本 | 系统支持 | 特性 |
|---------|---------|------|
| `nginx-manager.sh` | 🌐 通用版本 (Linux/macOS) | 完整功能，自动检测系统 |
| `nginx-manager-macos.sh` | 🍎 macOS 专版 | Homebrew 优化，macOS 路径 |
| `nginx-manager-linux.sh` | 🐧 Linux 专版 | 多发行版支持，systemd 集成 |

### 📋 选择指南

- **🔰 新用户推荐**: 使用 `./nginx-manager` (智能启动器)
- **🍎 macOS + Homebrew**: 使用 `nginx-manager-macos.sh` 
- **🐧 Linux 服务器**: 使用 `nginx-manager-linux.sh`

### 🚀 智能启动器

使用 `nginx-manager` 智能启动器会自动检测您的系统并推荐最适合的版本：

```bash
# 智能选择并运行（推荐）
./nginx-manager generate-docs

# 交互式选择版本
./nginx-manager

# 直接指定版本
./nginx-manager macos generate-docs
./nginx-manager linux generate-docs
```

## 系统要求

- **操作系统**: Linux (支持 nginx)
- **权限**: root 用户权限
- **依赖**: nginx, openssl

### 安装依赖

```bash
# Debian/Ubuntu
sudo apt-get install nginx openssl

# CentOS/RHEL
sudo yum install nginx openssl
```

## 基本用法

### 命令格式

```bash
sudo ./nginx-manager.sh [全局选项] [命令] [参数]
```

### 全局选项

| 选项 | 描述 | 示例 |
|------|------|------|
| `-c, --config <路径>` | 指定nginx配置文件或目录 | `-c /custom/nginx` |
| `-h, --help` | 显示帮助信息 | `--help` |

### 自定义配置路径

脚本支持指定不同的nginx配置路径，这对于以下场景非常有用：

- **开发环境**: 使用独立的nginx配置进行测试
- **容器化部署**: nginx配置挂载在非标准路径
- **多实例管理**: 管理多个nginx实例
- **配置隔离**: 不同项目使用独立的nginx配置

#### 使用方法

```bash
# 指定配置目录
sudo ./nginx-manager.sh -c /custom/nginx add-site example.com -r /var/www/example.com

# 指定配置文件
sudo ./nginx-manager.sh -c /custom/nginx/nginx.conf status

# 查看自定义配置状态
sudo ./nginx-manager.sh -c /custom/nginx status
```

### 可用命令

| 命令 | 描述 | 示例 |
|------|------|------|
| `add-site` | 添加静态网站 | `add-site example.com -r /var/www/example.com` |
| `add-proxy` | 添加反向代理 | `add-proxy api.example.com -p http://localhost:3000` |
| `remove-site` | 移除站点 | `remove-site example.com` |
| `enable-site` | 启用站点 | `enable-site example.com` |
| `disable-site` | 禁用站点 | `disable-site example.com` |
| `list-sites` | 列出所有站点 | `list-sites` |
| `ssl-setup` | 设置SSL证书 | `ssl-setup example.com -c cert.pem -k key.pem` |
| `backup` | 备份配置 | `backup production` |
| `restore` | 恢复配置 | `restore production` |
| `test` | 测试配置 | `test` |
| `reload` | 重载配置 | `reload` |
| `optimize` | 优化主配置 | `optimize` |
| `status` | 查看状态 | `status` |
| `generate-docs` | 生成中文配置文档 | `generate-docs` |

## 详细功能说明

### 1. 添加静态网站

创建一个静态网站配置：

```bash
sudo ./nginx-manager.sh add-site example.com -r /var/www/example.com -s -l -g
```

#### 参数说明

| 参数 | 简写 | 描述 |
|------|------|------|
| `--root` | `-r` | 网站根目录 |
| `--ssl` | `-s` | 启用SSL |
| `--cert` | `-c` | SSL证书路径 |
| `--key` | `-k` | SSL私钥路径 |
| `--index` | `-i` | 默认索引文件 |
| `--log` | `-l` | 启用访问日志 |
| `--gzip` | `-g` | 启用gzip压缩 |
| `--max-body` | `-m` | 最大请求体大小 |

### 2. 添加反向代理

创建反向代理配置：

```bash
sudo ./nginx-manager.sh add-proxy api.example.com -p http://localhost:3000 -w -t 300
```

### 反向代理参数说明

| 参数 | 简写 | 描述 |
|------|------|------|
| `--proxy` | `-p` | 反向代理目标URL |
| `--ssl` | `-s` | 启用SSL |
| `--websocket` | `-w` | 支持WebSocket |
| `--timeout` | `-t` | 超时时间(秒) |
| `--log` | `-l` | 启用访问日志 |
| `--max-body` | `-m` | 最大请求体大小 |

### 3. 负载均衡配置

使用逗号分隔多个后端服务器：

```bash
sudo ./nginx-manager.sh add-proxy app.example.com -p "http://backend1:8080,http://backend2:8080,http://backend3:8080"
```

### 4. SSL证书管理

#### 使用现有证书
```bash
sudo ./nginx-manager.sh ssl-setup example.com -c /path/to/cert.pem -k /path/to/key.pem
```

#### 生成自签名证书
```bash
sudo ./nginx-manager.sh ssl-setup example.com --auto
```

### 5. 配置备份和恢复

#### 创建备份
```bash
sudo ./nginx-manager.sh backup production
```

#### 恢复配置
```bash
sudo ./nginx-manager.sh restore production
```

### 6. 生成中文配置文档

使用 `generate-docs` 命令可以自动读取当前nginx配置，生成一份结构化的中文Markdown文档，便于归档、审计和团队协作。

#### 用法

```bash
sudo ./nginx-manager.sh generate-docs
# 或指定自定义配置目录
sudo ./nginx-manager.sh -c /custom/nginx generate-docs
```

#### 功能说明
- 自动分析当前nginx主配置、虚拟主机、反向代理、SSL、WebSocket等所有站点配置
- 统计站点数量、启用状态、长连接/负载均衡/SSL等特性
- 输出详细的中文结构化文档，包含配置路径、站点类型、关键参数等
- 文档自动保存在脚本目录下的 `docs/` 文件夹中，文件名如：`docs/nginx_config_docs_20250822_153000.md`

#### 示例输出片段

```markdown
# 🌐 Nginx 配置文档

**生成时间**: 2025年08月22日 15:30:00  
**服务器**: myserver  
**Nginx版本**: 1.24.0  
**配置目录**: /etc/nginx  
**主配置文件**: /etc/nginx/nginx.conf

---

## 📋 配置概览
- 站点总数: 5
- 启用站点: 4
- 反向代理: 2
- WebSocket长连接: 1
- 含SSL站点: 3
- 静态站点: 2
...（更多详细内容）
```

> 生成的文档可直接用于归档、交付、团队审查或自动化文档系统。文档保存在 `docs/` 目录中，便于版本管理和分享。

## 使用示例

### 场景1: 创建企业官网

```bash
# 1. 添加静态网站配置
sudo ./nginx-manager.sh add-site company.com \
  --root /var/www/company.com \
  --ssl \
  --log \
  --gzip

# 2. 设置SSL证书
sudo ./nginx-manager.sh ssl-setup company.com \
  --cert /etc/ssl/certs/company.com.pem \
  --key /etc/ssl/private/company.com.key

# 3. 测试并重载配置
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

### 场景2: 创建API网关

```bash
# 1. 添加API反向代理
sudo ./nginx-manager.sh add-proxy api.company.com \
  --proxy http://localhost:3000 \
  --ssl \
  --websocket \
  --timeout 300 \
  --log \
  --max-body 50m

# 2. 测试配置
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

### 场景3: 设置负载均衡

```bash
# 1. 创建负载均衡配置
sudo ./nginx-manager.sh add-proxy app.company.com \
  --proxy "http://app1:8080,http://app2:8080,http://app3:8080" \
  --ssl \
  --websocket \
  --timeout 120 \
  --log

# 2. 备份配置
sudo ./nginx-manager.sh backup load_balancer

# 3. 测试并重载
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

### 场景4: 微服务网关

```bash
# 为不同的微服务创建代理
sudo ./nginx-manager.sh add-proxy user-api.company.com \
  --proxy http://user-service:8001 \
  --ssl --websocket --log

sudo ./nginx-manager.sh add-proxy order-api.company.com \
  --proxy http://order-service:8002 \
  --ssl --websocket --log

sudo ./nginx-manager.sh add-proxy payment-api.company.com \
  --proxy http://payment-service:8003 \
  --ssl --websocket --log
```

## 高级功能

### 1. 优化nginx主配置

```bash
sudo ./nginx-manager.sh optimize
```

这将自动优化nginx主配置文件，包括：
- 工作进程优化
- 连接池设置
- 缓冲区优化
- Gzip压缩配置
- 安全头设置

### 2. WebSocket支持

脚本自动配置WebSocket支持，包括：
- Connection升级头
- 代理缓存绕过
- 长连接保持

### 3. 安全设置

自动配置的安全设置包括：
- 服务器版本隐藏
- XSS保护
- 内容类型嗅探保护
- 点击劫持保护
- HSTS (HTTPS)

### 4. 性能优化

- Gzip压缩
- 静态资源缓存
- 连接复用
- 缓冲区优化

## 配置文件结构

```
/etc/nginx/
├── nginx.conf                 # 主配置文件
├── sites-available/           # 可用站点配置
│   ├── example.com
│   └── api.example.com
├── sites-enabled/             # 启用站点配置(软链接)
│   ├── example.com -> ../sites-available/example.com
│   └── api.example.com -> ../sites-available/api.example.com
└── ...

/var/backups/nginx/            # 配置备份目录
├── nginx_20240819_123456.tar.gz
└── nginx_production_20240819_123456.tar.gz
```

## 常见问题

### Q1: 脚本提示权限不足
```bash
# 确保使用root权限运行
sudo ./nginx-manager.sh status
```

### Q2: nginx配置测试失败
```bash
# 查看详细错误信息
sudo nginx -t
```

### Q3: SSL证书配置问题
```bash
# 检查证书文件权限和路径
sudo ./nginx-manager.sh ssl-setup domain.com --auto
```

### Q4: 站点无法访问
```bash
# 检查站点是否启用
sudo ./nginx-manager.sh list-sites

# 启用站点
sudo ./nginx-manager.sh enable-site domain.com

# 重载配置
sudo ./nginx-manager.sh reload
```

### Q5: 如何恢复配置
```bash
# 查看备份列表
ls /var/backups/nginx/

# 恢复指定备份
sudo ./nginx-manager.sh restore backup_name
```

## 安全建议

1. **定期备份**: 重要变更前始终创建备份
2. **配置测试**: 每次修改后都要测试配置
3. **SSL证书**: 生产环境使用CA签名的证书
4. **访问控制**: 合理配置防火墙规则
5. **日志监控**: 定期检查访问和错误日志

## 更新日志

参见项目根目录的 CHANGELOG.md 文件。
