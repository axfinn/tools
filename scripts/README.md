# Scripts 目录说明

本目录包含各种实用脚本工具，按功能分类管理。

## 目录结构

```
scripts/
├── README.md                    # 本说明文件
├── port-protection/            # Docker 端口保护脚本
│   ├── port-protect.sh         # 主脚本文件
│   └── README.md              # 详细使用说明
└── nginx-manager/              # Nginx 配置管理脚本
    ├── nginx-manager.sh        # 主脚本文件
    ├── README.md              # 详细使用说明
    ├── QUICKSTART.md          # 快速入门指南
    ├── CUSTOM-CONFIG.md       # 自定义配置功能说明
    ├── test.sh               # 功能测试脚本
    ├── test-custom-config.sh  # 自定义配置测试
    └── templates/             # 配置模板目录
        ├── static-site.conf   # 静态站点模板
        ├── proxy-site.conf    # 反向代理模板
        └── ssl-config.conf    # SSL配置模板
```

## 脚本列表

### 🔒 端口保护类

- **[port-protection](./port-protection/)** - Docker Host 模式端口保护脚本
  - 功能：iptables 规则管理、端口访问控制、速率限制
  - 适用：Docker 容器端口保护、Web 服务安全防护

### 🌐 Web服务管理类

- **[nginx-manager](./nginx-manager/)** - Nginx 配置管理系统
  - 功能：虚拟站点管理、反向代理配置、SSL证书设置、负载均衡
  - 特性：WebSocket长连接支持、自定义配置路径、中文文档生成
  - 适用：Web服务器管理、API网关配置、微服务部署

## 快速开始

### 端口保护脚本

```bash
cd port-protection
sudo ./port-protect.sh --help
```

### Nginx管理脚本

```bash
cd nginx-manager
sudo ./nginx-manager.sh --help

# 快速添加静态站点
sudo ./nginx-manager.sh add-site example.com -r /var/www/example.com

# 快速添加反向代理
sudo ./nginx-manager.sh add-proxy api.example.com -p http://localhost:3000 --websocket
```

## 使用指南

1. 进入对应脚本目录
2. 查看该脚本的 README.md 了解详细用法
3. 确保脚本有执行权限：`chmod +x script-name.sh`
4. 按需要以 root 权限运行

## 贡献新脚本

添加新脚本时请遵循以下规范：

1. **目录结构**：为每个脚本创建独立目录
2. **命名规范**：使用小写字母和连字符，如 `my-script`
3. **必需文件**：
   - `script-name.sh` - 主脚本文件
   - `README.md` - 详细使用说明
4. **文档要求**：
   - 功能描述
   - 使用示例
   - 参数说明
   - 依赖要求
5. **更新**：在本文件和主项目 CHANGELOG.md 中记录变更

## 安全提醒

- ⚠️ 脚本可能需要 root 权限运行
- ⚠️ 运行前请仔细阅读脚本说明
- ⚠️ 在生产环境使用前先在测试环境验证
- ⚠️ 重要操作前建议备份相关配置
