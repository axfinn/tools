# Tools 工具集合

一个实用的脚本和工具集合仓库，提供各种自动化和管理工具。

## 📁 项目结构

```
tools/
├── README.md                    # 项目主说明文件
├── CHANGELOG.md                 # 项目变更日志
└── scripts/                     # 脚本工具目录
    ├── README.md               # 脚本目录说明
    └── port-protection/        # 端口保护脚本
        ├── port-protect.sh     # Docker 端口保护主脚本
        └── README.md           # 详细使用说明
```

## 🛠️ 可用工具

### 🔒 安全防护类

- **[端口保护脚本](./scripts/port-protection/)** - Docker Host 模式端口保护
  - iptables 规则管理
  - 端口访问控制和速率限制
  - 规则备份和恢复功能
  - 可信IP白名单管理

## 🚀 快速开始

1. **克隆仓库**
   ```bash
   git clone https://github.com/axfinn/tools.git
   cd tools
   ```

2. **查看可用脚本**
   ```bash
   ls scripts/
   ```

3. **进入具体脚本目录并查看说明**
   ```bash
   cd scripts/port-protection
   cat README.md
   ```

4. **运行脚本**
   ```bash
   sudo ./port-protect.sh help
   ```

## 📋 使用要求

- **操作系统**: Linux (大部分脚本)
- **权限**: 部分脚本需要 root 权限
- **依赖**: 具体依赖查看各脚本说明文档

## 🔧 贡献指南

欢迎贡献新的实用脚本！请遵循以下规范：

1. **目录结构**: 每个脚本使用独立目录
2. **文档完整**: 包含详细的 README.md
3. **代码规范**: 遵循 Shell 脚本最佳实践
4. **测试验证**: 在提交前充分测试
5. **更新日志**: 在 CHANGELOG.md 中记录变更

### 添加新脚本的步骤

1. 在 `scripts/` 下创建新目录
2. 添加脚本文件和 README.md
3. 更新 `scripts/README.md` 中的脚本列表
4. 更新主项目 `CHANGELOG.md`
5. 提交 Pull Request

## ⚠️ 安全提醒

- 运行脚本前请仔细阅读说明文档
- 在生产环境使用前先在测试环境验证
- 备份重要配置和数据
- 注意脚本的权限要求

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📧 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [Issue](https://github.com/axfinn/tools/issues)
- 发起 [Pull Request](https://github.com/axfinn/tools/pulls)

## 📈 更新日志

查看 [CHANGELOG.md](./CHANGELOG.md) 了解项目更新历史。
