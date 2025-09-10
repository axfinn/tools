# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] - 2025-09-10

### ✨ Added

- `port-protect.sh`: 新增 `list-ports` 命令，快速列出所有受保护端口及对应链/协议
- 多 RDP 端口示例与独立链策略文档更新

### 🔄 Changed

- 默认策略从“单共享链”变为“每端口独立链 (DOCKER-HOST-PROTECT-\<port\>)”以避免端口间互相影响
- RDP 模式参数与文档统一为 `30/min` + `burst 50`

### 🐛 Fixed

- 修复添加第二个端口会 flush 掉第一个端口规则导致其失去防护的问题
- 修复可信 IP 规则未限定端口导致权限放大的问题（现在规则附带 --dport）
- `remove` 命令现在智能识别独立链 / 旧共享链并正确清理

### 🛡️ Security

- 防止多端口共享链时的静默降级（链被清空但 INPUT 仍引用）带来的潜在暴露
- 白名单条目限制到具体端口，降低误放通面

### 📚 Docs

- 更新 `scripts/port-protection/README.md`：新增多 RDP 端口场景、链策略变更说明、`list-ports` 命令
- 标注 2025-09 链策略迁移提示

### ✅ Migration Notes

无需强制迁移；已有引用共享链 `DOCKER-HOST-PROTECT` 的老规则仍有效。建议为关键端口重新执行 add 以获得独立链隔离：

```bash
sudo ./port-protect.sh remove 19099 && sudo ./port-protect.sh add 19099 --rdp -t <your-ip>
```

---

## [2.0.0] - 2025-08-19

### 🚀 新增功能

#### Docker端口保护脚本重大增强
- **RDP优化模式**: 新增 `--rdp` 参数，专为远程桌面协议优化
  - 自动调整速率限制为 30/min，突发限制为 50
  - 允许已建立连接（ESTABLISHED,RELATED）无限制通过
  - 解决RDP连接在添加防护后无法使用的问题

- **白名单模式**: 新增 `--whitelist-only` 参数
  - 仅允许指定的可信IP访问
  - 提供最严格的访问控制
  - 适用于SSH、数据库等高安全要求的服务

### 🛡️ 安全防护增强

#### RDP爆破攻击防护
- **有效防止公网RDP爆破密码请求**
  - 高频爆破攻击：速率限制直接阻止
  - 分布式爆破：白名单模式完全阻止
  - 慢速爆破：30/min限制使爆破变得不现实

#### 多层防护机制
- 速率限制防护：限制新连接频率
- 白名单防护：IP地址级别访问控制
- 连接状态跟踪：不影响正常会话

### 📚 文档更新

#### 新增文档
- `scripts/port-protection/RDP-USAGE.md`: RDP端口保护专用指南
- `scripts/port-protection/UPDATE-SUMMARY.md`: 更新摘要文档

#### 文档增强
- 更新 `scripts/port-protection/README.md`
  - 新增功能特性说明
  - 添加RDP相关使用示例
  - 增加常见问题解答
  - 新增安全配置建议

### 🔧 技术改进

#### 脚本功能增强
- 新增RDP协议连接状态处理
- 优化速率限制算法
- 增强错误处理和用户反馈
- 向后兼容现有功能

#### 使用场景扩展
- **RDP/VNC远程桌面**: 推荐使用 `--rdp` 模式
- **SSH管理服务**: 推荐使用 `--whitelist-only` 模式
- **Web服务**: 使用默认模式，可调整参数
- **API服务**: 使用严格速率限制或白名单模式

### 📝 使用示例

```bash
# RDP端口保护（推荐配置）
sudo ./port-protect.sh add 19099 --rdp -t 192.168.1.100

# 高安全白名单模式
sudo ./port-protect.sh add 22 --whitelist-only -t 192.168.1.0/24

# 批量RDP端口保护
for port in 3389 19099 19100; do
    sudo ./port-protect.sh add $port --rdp --trust 192.168.1.0/24
done
```

### 🔄 向后兼容性

- 所有现有功能保持不变
- 新增参数为可选项
- 不影响现有脚本使用

### 📋 问题修复

- 解决RDP连接在添加防护规则后无法使用的问题
- 优化长连接协议的防护策略
- 改进速率限制对正常连接的影响

## [1.1.0] - 2025-08-19

### Changed
- 重构项目目录结构，优化脚本管理
- 将端口保护脚本移动到独立目录 `scripts/port-protection/`
- 更新项目主 README.md，添加完整的项目介绍和使用指南
- 创建 scripts 目录总体说明文档

### Added
- 建立模块化脚本管理体系
- 添加贡献指南和开发规范
- 完善项目文档结构

# Changelog

All notable changes to this project will be documented in this file.

## [2024-08-20] - Nginx管理系统增强

### Added
- **自定义配置路径支持** - nginx-manager.sh 现支持指定自定义nginx配置目录
  - 新增 `-c, --config` 全局参数指定配置路径
  - 智能路径检测：自动识别文件路径vs目录路径
  - 支持开发环境、容器化部署等多种场景
  - 自动创建必要的目录结构

- **中文配置文档生成增强**
  - `generate-docs` 命令现包含自定义配置路径信息
  - 详细的长连接和WebSocket配置统计
  - 配置文件路径和状态信息展示

- **长连接配置优化说明**
  - 详细的WebSocket长连接处理方案文档
  - 协议升级、连接保持、超时优化等配置说明
  - 性能优化建议和最佳实践

- **测试工具增强**
  - 新增 `test-custom-config.sh` 专门测试自定义配置功能
  - 自动创建测试环境和清理机制
  - 全面的功能验证流程

### Enhanced
- **状态显示优化** - `status` 命令现显示更详细的配置路径信息
- **帮助信息完善** - 添加长连接配置说明和使用示例
- **错误处理改进** - 更好的参数验证和错误提示

## [2024-08-19] - Nginx Management System

### Added
- **New nginx-manager.sh script** - Complete nginx configuration management system
  - Virtual host management (static sites and reverse proxy)
  - SSL certificate setup and management
  - WebSocket and long connection support
  - Load balancing configuration
  - Automatic security headers and optimization
  - Configuration backup and restore
  - Comprehensive error handling and validation

- **Nginx configuration templates**
  - Static site template with optimization
  - Reverse proxy template with WebSocket support
  - SSL configuration template with security best practices

- **Documentation and testing**
  - Complete README with usage examples
  - Quick start guide for rapid deployment
  - Automated test script for functionality validation

## [2024-08-19] - Port Protection Enhanced

### Added
- 初始化 tools 项目
- 创建 scripts 目录
- 添加增强版 Docker 端口保护脚本 (`scripts/port-protection/port-protect.sh`)
  - 支持端口保护规则的添加和移除
  - 集成 iptables 规则备份和恢复功能
  - 支持多个可信IP地址白名单配置
  - 提供速率限制和突发请求控制
  - 包含完善的参数验证和错误处理
  - 支持规则持久化保存
  - 实现状态监控和规则查看功能
- 创建详细的使用手册 (`scripts/port-protection/README.md`)
  - 包含完整的功能特性说明
  - 提供详细的安装和配置指南
  - 包含多种使用场景示例
  - 提供故障排除和安全建议

### Fixed
- 修复原始脚本中的多个问题:
  - 添加依赖项检查功能
  - 增强IP地址格式验证
  - 改进参数解析和错误处理
  - 修复链删除时的引用检查
  - 优化备份文件管理逻辑
  - 增强规则重复检查机制
  - 改进错误信息和状态显示