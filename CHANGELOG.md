# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-08-19

### Added
- 初始化 tools 项目
- 创建 scripts 目录
- 添加增强版 Docker 端口保护脚本 (`scripts/port-protect.sh`)
  - 支持端口保护规则的添加和移除
  - 集成 iptables 规则备份和恢复功能
  - 支持多个可信IP地址白名单配置
  - 提供速率限制和突发请求控制
  - 包含完善的参数验证和错误处理
  - 支持规则持久化保存
  - 实现状态监控和规则查看功能
- 创建详细的使用手册 (`scripts/README.md`)
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