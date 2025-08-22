# Nginx Manager 快速入门

## 5分钟快速上手

### 第一步：确认环境

```bash
# 检查nginx是否安装
sudo nginx -v

# 检查脚本是否可执行
ls -la nginx-manager.sh
```

### 第二步：查看帮助

```bash
sudo ./nginx-manager.sh help
```

### 第三步：创建第一个站点

#### 创建静态网站
```bash
# 创建网站目录
sudo mkdir -p /var/www/mysite.com
echo "<h1>Hello World!</h1>" | sudo tee /var/www/mysite.com/index.html

# 添加站点配置
sudo ./nginx-manager.sh add-site mysite.com --root /var/www/mysite.com --gzip --log

# 启用站点
sudo ./nginx-manager.sh enable-site mysite.com

# 测试并重载配置
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

#### 创建反向代理
```bash
# 假设你有一个运行在3000端口的应用
sudo ./nginx-manager.sh add-proxy api.mysite.com --proxy http://localhost:3000 --websocket --log

# 启用并重载
sudo ./nginx-manager.sh enable-site api.mysite.com
sudo ./nginx-manager.sh test && sudo ./nginx-manager.sh reload
```

### 第四步：设置SSL（可选）

```bash
# 生成自签名证书（测试用）
sudo ./nginx-manager.sh ssl-setup mysite.com --auto

# 或者使用现有证书
sudo ./nginx-manager.sh ssl-setup mysite.com \
  --cert /path/to/cert.pem \
  --key /path/to/key.pem
```

### 第五步：管理站点

```bash
# 查看所有站点
sudo ./nginx-manager.sh list-sites

# 查看nginx状态
sudo ./nginx-manager.sh status

# 备份配置
sudo ./nginx-manager.sh backup my_backup

# 优化nginx
sudo ./nginx-manager.sh optimize

# 生成配置文档
sudo ./nginx-manager.sh generate-docs
# 文档保存在 docs/ 目录中
```

## 常用命令速查

| 场景 | 命令 |
|------|------|
| 添加静态站点 | `sudo ./nginx-manager.sh add-site domain.com -r /var/www/domain.com` |
| 添加API代理 | `sudo ./nginx-manager.sh add-proxy api.domain.com -p http://localhost:3000` |
| 启用站点 | `sudo ./nginx-manager.sh enable-site domain.com` |
| 禁用站点 | `sudo ./nginx-manager.sh disable-site domain.com` |
| 删除站点 | `sudo ./nginx-manager.sh remove-site domain.com` |
| 测试配置 | `sudo ./nginx-manager.sh test` |
| 重载配置 | `sudo ./nginx-manager.sh reload` |
| 查看状态 | `sudo ./nginx-manager.sh status` |
| 配置备份 | `sudo ./nginx-manager.sh backup backup_name` |

## 测试脚本

运行功能测试：

```bash
sudo ./test.sh
```

## 需要帮助？

查看完整文档：`cat README.md`

遇到问题？检查：
1. 是否使用了root权限
2. nginx是否正确安装
3. 配置语法是否正确（`sudo ./nginx-manager.sh test`）
