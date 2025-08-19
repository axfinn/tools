# Changelog

All notable changes to this project will be documented in this file.

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

## [1.0.0] - 2025-08-19

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