# Scripts 目录说明

本目录包含各种实用脚本工具，按功能分类管理。

## 目录结构

```
scripts/
├── README.md                    # 本说明文件
└── port-protection/            # Docker 端口保护脚本
    ├── port-protect.sh         # 主脚本文件
    └── README.md              # 详细使用说明
```

## 脚本列表

### 🔒 端口保护类

- **[port-protection](./port-protection/)** - Docker Host 模式端口保护脚本
  - 功能：iptables 规则管理、端口访问控制、速率限制
  - 适用：Docker 容器端口保护、Web 服务安全防护

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