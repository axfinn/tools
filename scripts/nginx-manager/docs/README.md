# 📚 Nginx 配置文档目录

本目录用于保存由 `nginx-manager.sh` 自动生成的中文配置文档。

## 📋 文档说明

### 文档生成
使用以下命令生成配置文档：
```bash
sudo ./nginx-manager.sh generate-docs
```

### 文档命名规则
生成的文档文件名格式：`nginx_config_docs_YYYYMMDD_HHMMSS.md`

例如：`nginx_config_docs_20250822_153000.md`

### 文档内容
每个生成的文档包含：

- **服务器基本信息**
  - 生成时间和服务器名称
  - Nginx版本信息
  - 配置文件路径

- **配置概览统计**
  - 站点总数和启用状态
  - SSL、反向代理、WebSocket统计
  - 负载均衡配置统计

- **详细站点配置**
  - 每个站点的完整配置信息
  - SSL证书配置
  - 反向代理设置
  - 长连接和WebSocket配置

- **优化建议**
  - 性能优化建议
  - 安全配置建议
  - 最佳实践推荐

## 📁 使用场景

1. **配置审计**: 定期生成文档进行配置审查
2. **团队协作**: 分享配置信息给团队成员
3. **文档归档**: 重要变更后的配置备案
4. **故障排查**: 问题发生时的配置参考
5. **合规检查**: 安全和性能配置验证

## 🔧 自定义配置路径

使用自定义配置路径时：
```bash
sudo ./nginx-manager.sh -c /custom/nginx generate-docs
```

文档仍会保存在此 `docs/` 目录中，但会包含自定义配置路径的信息。

## 📖 文档格式

生成的文档采用 Markdown 格式，可以：
- 在GitHub、GitLab等平台直接预览
- 使用Markdown编辑器查看和编辑
- 转换为PDF、HTML等其他格式
- 集成到文档系统中

## 🗑️ 清理旧文档

建议定期清理旧的配置文档：
```bash
# 删除30天前的文档
find docs/ -name "nginx_config_docs_*.md" -mtime +30 -delete

# 或保留最近5个文档
ls -t docs/nginx_config_docs_*.md | tail -n +6 | xargs rm -f
```
