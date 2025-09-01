# 🌐 端口转发管理工具

将本地端口数据直接转发到局域网指定主机指定端口的完整解决方案。

## 📋 ## 🚀 快速开始

### 🎯 方法对比演示

首次使用建议运行演示脚本，了解各种转发方法的特点和适用场景：

```bash
# 运行对比演示
./demo.sh
```

演示内容包括：
- 📋 系统信息和工具检测
- 📊 各种转发方法的性能对比
- 🎯 使用场景推荐
- ⚡ 性能测试建议
- 🔧 故障排除指南

### 临时转发 (推荐新手)

使用 `quick-forward.sh` 进行一次性端口转发：

```bash
# 基本用法
./quick-forward.sh <本地端口> <目标主机> <目标端口> [方法]

# 示例：将本地8080端口转发到192.168.1.100的80端口
./quick-forward.sh 8080 192.168.1.100 80

# 指定转发方法
./quick-forward.sh 8080 192.168.1.100 80 socat
```性

- ✅ **多种转发方法**: 支持 socat、nc、ssh 等转发方式
- ✅ **规则管理**: 添加、删除、启动、停止转发规则
- ✅ **状态监控**: 实时查看转发状态和连接数
- ✅ **日志记录**: 完整的转发日志记录和查看
- ✅ **快速转发**: 一行命令实现临时端口转发
- ✅ **持久化配置**: 转发规则持久化保存
- ✅ **智能检测**: 自动检查端口占用和依赖工具

## 🚀 快速开始

### 安装依赖

```bash
# macOS
brew install socat netcat

# Ubuntu/Debian  
sudo apt install socat netcat-openbsd net-tools

# CentOS/RHEL
sudo yum install socat nc net-tools
```

### 基本使用

```bash
# 给脚本添加执行权限
chmod +x port-forwarder.sh quick-forward.sh

# 1. 添加转发规则
./port-forwarder.sh add web-server -l 8080 -h 192.168.1.100 -p 80 -d "Web服务器转发"

# 2. 启动转发
./port-forwarder.sh start web-server

# 3. 查看状态
./port-forwarder.sh status

# 4. 查看日志
./port-forwarder.sh logs web-server

# 5. 停止转发
./port-forwarder.sh stop web-server
```

### 快速转发

```bash
# 临时转发 (前台运行，Ctrl+C停止)
./quick-forward.sh 8080 192.168.1.100 80

# 使用nc方法转发
./quick-forward.sh 3306 192.168.1.200 3306 nc
```

## 📖 详细用法

### 1. 转发规则管理

#### 添加规则
```bash
./port-forwarder.sh add <规则名> [选项]

选项:
  -l, --local-port <端口>      本地监听端口 (必需)
  -h, --target-host <主机>     目标主机地址 (必需)  
  -p, --target-port <端口>     目标端口 (必需)
  -m, --method <方法>          转发方法 (socat|nc|ssh)
  -d, --description <描述>     规则描述
```

#### 示例
```bash
# Web服务转发
./port-forwarder.sh add web -l 8080 -h 192.168.1.100 -p 80 -d "Web服务器"

# 数据库转发  
./port-forwarder.sh add mysql -l 3306 -h 192.168.1.200 -p 3306 -m socat

# SSH转发
./port-forwarder.sh add ssh -l 2222 -h 192.168.1.50 -p 22 -d "SSH服务器"
```

### 2. 转发控制

```bash
# 启动转发
./port-forwarder.sh start <规则名>

# 停止转发
./port-forwarder.sh stop <规则名>

# 重启转发
./port-forwarder.sh restart <规则名>

# 删除规则
./port-forwarder.sh remove <规则名>
```

### 3. 状态查看

```bash
# 列出所有规则
./port-forwarder.sh list

# 查看特定规则状态
./port-forwarder.sh status <规则名>

# 查看所有规则状态
./port-forwarder.sh status
```

### 4. 日志查看

```bash
# 查看转发日志
./port-forwarder.sh logs <规则名>

# 实时日志 (如果转发正在运行)
./port-forwarder.sh logs <规则名>
```

## 🔧 转发方法说明

### Socat (推荐)
- **优点**: 高性能、稳定、支持多种协议
- **适用**: 生产环境、高并发场景
- **安装**: `brew install socat` (macOS) 或 `apt install socat` (Linux)

### Netcat (nc)
- **优点**: 轻量级、系统通常自带
- **适用**: 临时转发、简单场景
- **限制**: 性能相对较低

### SSH隧道
- **优点**: 加密传输、安全性高
- **适用**: 需要加密的场景
- **要求**: 需要SSH密钥认证

## 📁 文件结构

```
port-forwarder/
├── port-forwarder.sh         # 主要管理脚本
├── quick-forward.sh          # 快速转发脚本
├── config/                   # 规则配置目录
│   └── *.conf               # 转发规则配置文件
├── logs/                     # 日志目录
│   └── *.log                # 转发日志文件
├── pids/                     # 进程ID目录
│   └── *.pid                # 进程ID文件
└── examples/                 # 示例配置
    └── example.conf         # 配置示例
```

## 💡 使用场景

### 1. 开发环境
```bash
# 本地访问局域网开发服务器
./port-forwarder.sh add dev-api -l 3000 -h 192.168.1.120 -p 8000 -d "开发API"
./port-forwarder.sh start dev-api

# 现在可以通过 localhost:3000 访问 192.168.1.120:8000
```

### 2. 数据库访问
```bash
# 本地连接远程数据库
./port-forwarder.sh add mysql -l 3306 -h 192.168.1.200 -p 3306 -d "MySQL数据库"
./port-forwarder.sh start mysql

# 使用 localhost:3306 连接数据库
```

### 3. Web服务访问
```bash
# 访问局域网Web应用
./port-forwarder.sh add webapp -l 8080 -h 192.168.1.100 -p 80 -d "Web应用"
./port-forwarder.sh start webapp

# 浏览器访问 http://localhost:8080
```

### 4. 服务器管理
```bash
# SSH连接内网服务器
./port-forwarder.sh add ssh -l 2222 -h 192.168.1.50 -p 22 -d "内网SSH"
./port-forwarder.sh start ssh

# 使用 ssh user@localhost -p 2222 连接
```

## 🛠️ 故障排除

### 1. 端口被占用
```bash
# 检查端口占用
netstat -ln | grep :8080

# 或使用lsof (macOS/Linux)
lsof -i :8080
```

### 2. 工具未安装
```bash
# 检查依赖
./port-forwarder.sh status
```

### 3. 转发失败
```bash
# 查看详细日志
./port-forwarder.sh logs <规则名>

# 检查目标主机连通性
ping 192.168.1.100
telnet 192.168.1.100 80
```

## 📚 高级用法

### 批量管理
```bash
# 启动所有规则
for rule in $(ls config/*.conf | xargs -n1 basename -s .conf); do
    ./port-forwarder.sh start "$rule"
done

# 停止所有规则
for rule in $(ls config/*.conf | xargs -n1 basename -s .conf); do
    ./port-forwarder.sh stop "$rule"
done
```

### 开机自启
```bash
# 添加到crontab
@reboot /path/to/port-forwarder.sh start web-server

# 或使用systemd (Linux)
# 创建服务文件: /etc/systemd/system/port-forward.service
```

## 🔒 安全注意事项

1. **防火墙设置**: 确保本地防火墙允许监听端口
2. **网络安全**: 谨慎转发敏感端口
3. **访问控制**: 考虑使用iptables限制访问来源
4. **日志监控**: 定期检查转发日志

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个工具！

## 📄 许可证

MIT License
