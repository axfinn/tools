#!/bin/bash

# CrowdSec Docker 快速部署脚本
# 用途：一键部署 CrowdSec + Firewall Bouncer
# 适用：Debian/Ubuntu/CentOS/RHEL 系统（多系统支持）

set -euo pipefail

VERSION="2.0.0"

# 系统检测变量
OS_TYPE=""      # "rhel" 或 "debian"
PKG_MANAGER=""  # "yum", "dnf", 或 "apt"
LOG_PATH=""     # "/var/log/secure" 或 "/var/log/auth.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="docker-compose-crowdsec.yml"
CROWDSEC_DIR="$SCRIPT_DIR/crowdsec"
CONFIG_DIR="$CROWDSEC_DIR/config"
DATA_DIR="$CROWDSEC_DIR/data"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "需要root权限"
        echo "请使用: sudo $0"
        exit 1
    fi
}

detect_os() {
    log_info "检测操作系统..."

    if [ ! -f /etc/os-release ]; then
        log_error "无法检测操作系统（/etc/os-release不存在）"
        exit 1
    fi

    source /etc/os-release
    local OS_ID="${ID:-unknown}"

    case "$OS_ID" in
        centos|rhel|rocky|almalinux|fedora)
            OS_TYPE="rhel"
            LOG_PATH="/var/log/secure"

            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi

            log_success "检测到 CentOS/RHEL 系统 (包管理器: $PKG_MANAGER)"
            ;;
        debian|ubuntu|linuxmint|pop)
            OS_TYPE="debian"
            PKG_MANAGER="apt"
            LOG_PATH="/var/log/auth.log"

            log_success "检测到 Debian/Ubuntu 系统"
            ;;
        *)
            log_error "不支持的操作系统: $OS_ID"
            echo "仅支持: CentOS, RHEL, Debian, Ubuntu"
            exit 1
            ;;
    esac
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker 未安装"
        echo
        echo "安装 Docker:"
        if [ "$OS_TYPE" = "rhel" ]; then
            echo "  CentOS/RHEL:"
            echo "  sudo yum install -y yum-utils"
            echo "  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
            echo "  sudo $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io"
            echo "  sudo systemctl enable docker"
            echo "  sudo systemctl start docker"
        else
            echo "  Debian/Ubuntu:"
            echo "  curl -fsSL https://get.docker.com | sh"
        fi
        exit 1
    fi

    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "docker-compose 未安装"
        echo
        echo "安装 docker-compose:"
        if [ "$OS_TYPE" = "rhel" ]; then
            echo "  sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
            echo "  sudo chmod +x /usr/local/bin/docker-compose"
        else
            echo "  sudo apt-get install docker-compose"
        fi
        exit 1
    fi
}

create_directories() {
    log_info "创建目录结构..."

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DATA_DIR"

    # 创建采集配置（根据系统类型选择日志路径）
    if [ "$OS_TYPE" = "rhel" ]; then
        # CentOS/RHEL 日志位置
        cat > "$CONFIG_DIR/acquis.yaml" << 'EOF'
---
# 系统认证日志（SSH等） - CentOS/RHEL
filenames:
  - /logs/secure
labels:
  type: syslog

---
# 系统日志（RDP、其他服务）
filenames:
  - /logs/messages
labels:
  type: syslog
EOF
    else
        # Debian/Ubuntu 日志位置
        cat > "$CONFIG_DIR/acquis.yaml" << 'EOF'
---
# 系统认证日志（SSH等） - Debian/Ubuntu
filenames:
  - /logs/auth.log
labels:
  type: syslog

---
# 系统日志（RDP、其他服务）
filenames:
  - /logs/syslog
labels:
  type: syslog
EOF
    fi

    chmod 644 "$CONFIG_DIR/acquis.yaml"
    log_success "目录结构创建完成 (日志: $LOG_PATH)"
}

start_crowdsec() {
    log_info "启动 CrowdSec 容器..."

    cd "$SCRIPT_DIR"

    # 启动容器
    docker-compose -f "$COMPOSE_FILE" up -d

    # 等待容器启动
    log_info "等待容器启动..."
    sleep 10

    # 检查容器状态
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_success "CrowdSec 容器启动成功"
    else
        log_error "CrowdSec 容器启动失败"
        docker-compose -f "$COMPOSE_FILE" logs
        exit 1
    fi
}

generate_bouncer_key() {
    log_info "生成 Bouncer API Key..."

    # 等待API就绪
    local retries=0
    while [ $retries -lt 30 ]; do
        if docker-compose -f "$COMPOSE_FILE" exec -T crowdsec cscli version >/dev/null 2>&1; then
            break
        fi
        sleep 2
        ((retries++))
    done

    # 生成key
    local bouncer_key
    bouncer_key=$(docker-compose -f "$COMPOSE_FILE" exec -T crowdsec cscli bouncers add firewall-bouncer -o raw 2>/dev/null || echo "")

    if [ -z "$bouncer_key" ]; then
        log_error "生成 Bouncer Key 失败"
        return 1
    fi

    # 保存到文件
    echo "$bouncer_key" > "$SCRIPT_DIR/bouncer-key.txt"
    chmod 600 "$SCRIPT_DIR/bouncer-key.txt"

    echo
    log_success "Bouncer API Key 已生成"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo -e "${GREEN}API Key: $bouncer_key${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo
    echo "Key 已保存到: $SCRIPT_DIR/bouncer-key.txt"
    echo

    export BOUNCER_API_KEY="$bouncer_key"
}

install_firewall_bouncer() {
    log_info "安装 Firewall Bouncer..."

    # 检查是否已安装
    if systemctl list-unit-files | grep -q crowdsec-firewall-bouncer; then
        log_warn "Firewall Bouncer 已安装"
        read -p "是否重新安装? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    if [ "$OS_TYPE" = "rhel" ]; then
        # CentOS/RHEL 安装
        log_info "添加 CrowdSec 仓库..."
        curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | bash

        log_info "安装 crowdsec-firewall-bouncer-iptables..."
        $PKG_MANAGER install -y crowdsec-firewall-bouncer-iptables
    else
        # Debian/Ubuntu 安装
        log_info "添加 CrowdSec 仓库..."
        curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash

        log_info "安装 crowdsec-firewall-bouncer-iptables..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec-firewall-bouncer-iptables
    fi

    log_success "Firewall Bouncer 安装完成"
}

configure_bouncer() {
    log_info "配置 Firewall Bouncer..."

    if [ -z "${BOUNCER_API_KEY:-}" ]; then
        log_error "Bouncer API Key 未设置"
        return 1
    fi

    # 备份原配置
    if [ -f /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml ]; then
        cp /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml \
           /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml.bak
    fi

    # 创建新配置
    cat > /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml << EOF
# CrowdSec Firewall Bouncer 配置

# API配置
api_url: http://127.0.0.1:8080
api_key: $BOUNCER_API_KEY

# 防火墙模式
mode: iptables

# iptables 链配置
iptables_chains:
  - INPUT           # 保护主机
  - DOCKER-USER     # 保护Docker容器（重要！）

# 封禁动作
deny_action: DROP
deny_log: true
deny_log_prefix: "CrowdSec: "

# 日志配置
log_mode: file
log_dir: /var/log/
log_level: info
log_compression: true
log_max_size: 40
log_max_backups: 3
log_max_age: 30

# 更新频率
update_frequency: 10s

# 缓存配置
cache_retention_duration: 1h

# Prometheus（可选）
prometheus:
  enabled: false
  listen_addr: 127.0.0.1
  listen_port: 60601
EOF

    chmod 600 /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
    log_success "Bouncer 配置完成"
}

start_bouncer() {
    log_info "启动 Firewall Bouncer..."

    systemctl enable crowdsec-firewall-bouncer
    systemctl restart crowdsec-firewall-bouncer

    # 等待启动
    sleep 3

    # 检查状态
    if systemctl is-active --quiet crowdsec-firewall-bouncer; then
        log_success "Firewall Bouncer 已启动"
    else
        log_error "Firewall Bouncer 启动失败"
        systemctl status crowdsec-firewall-bouncer
        exit 1
    fi
}

show_status() {
    echo
    log_info "════════════════════════════════════"
    log_info "CrowdSec 部署状态"
    log_info "════════════════════════════════════"
    echo

    # Docker 容器状态
    echo -e "${CYAN}[Docker 容器]${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    echo

    # CrowdSec 指标
    echo -e "${CYAN}[CrowdSec 指标]${NC}"
    docker-compose -f "$COMPOSE_FILE" exec -T crowdsec cscli metrics || echo "指标获取失败"
    echo

    # Bouncer 状态
    echo -e "${CYAN}[Firewall Bouncer]${NC}"
    systemctl status crowdsec-firewall-bouncer --no-pager | head -10
    echo

    # iptables 规则
    echo -e "${CYAN}[iptables 规则]${NC}"
    iptables -L crowdsec-chain -n 2>/dev/null | head -10 || echo "CrowdSec链尚未创建"
    echo

    # 决策列表
    echo -e "${CYAN}[当前封禁]${NC}"
    docker-compose -f "$COMPOSE_FILE" exec -T crowdsec cscli decisions list || echo "暂无封禁"
    echo
}

show_next_steps() {
    echo
    log_success "════════════════════════════════════"
    log_success "CrowdSec Docker 部署完成！"
    log_success "════════════════════════════════════"
    echo

    echo -e "${CYAN}访问地址：${NC}"
    echo "  Dashboard: http://localhost:3000"
    echo "  API: http://localhost:8080"
    echo "  Metrics: http://localhost:6060"
    echo

    echo -e "${CYAN}常用命令：${NC}"
    echo "  # 查看容器日志"
    echo "  docker-compose -f $COMPOSE_FILE logs -f crowdsec"
    echo
    echo "  # 查看决策（封禁列表）"
    echo "  docker-compose -f $COMPOSE_FILE exec crowdsec cscli decisions list"
    echo
    echo "  # 查看警报"
    echo "  docker-compose -f $COMPOSE_FILE exec crowdsec cscli alerts list"
    echo
    echo "  # 手动封禁IP"
    echo "  docker-compose -f $COMPOSE_FILE exec crowdsec cscli decisions add --ip 1.2.3.4"
    echo
    echo "  # 解封IP"
    echo "  docker-compose -f $COMPOSE_FILE exec crowdsec cscli decisions delete --ip 1.2.3.4"
    echo
    echo "  # 查看Bouncer日志"
    echo "  sudo tail -f /var/log/crowdsec-firewall-bouncer.log"
    echo

    echo -e "${CYAN}配置文件：${NC}"
    echo "  CrowdSec: $CONFIG_DIR"
    echo "  Bouncer: /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"
    echo "  Compose: $SCRIPT_DIR/$COMPOSE_FILE"
    echo
}

test_setup() {
    log_info "测试配置..."

    # 测试API连接
    if curl -s http://127.0.0.1:8080/v1/heartbeat >/dev/null 2>&1; then
        log_success "API 连接正常"
    else
        log_warn "API 连接失败，请检查端口映射"
    fi

    # 测试Bouncer连接
    if grep -q "successfully connected" /var/log/crowdsec-firewall-bouncer.log 2>/dev/null; then
        log_success "Bouncer 连接正常"
    else
        log_warn "Bouncer 可能尚未连接，查看日志: sudo tail /var/log/crowdsec-firewall-bouncer.log"
    fi
}

main() {
    check_root

    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════╗
║   CrowdSec Docker 快速部署脚本        ║
║   版本: 2.0.0 (多系统支持)           ║
╚═══════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo
    log_info "这个脚本将："
    echo "  1. 检测操作系统类型"
    echo "  2. 检查 Docker 环境"
    echo "  3. 创建配置目录"
    echo "  4. 启动 CrowdSec 容器"
    echo "  5. 生成 Bouncer API Key"
    echo "  6. 安装 Firewall Bouncer"
    echo "  7. 配置并启动 Bouncer"
    echo
    read -p "继续? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi

    # 执行部署
    detect_os
    echo

    check_docker
    echo

    create_directories
    echo

    start_crowdsec
    echo

    generate_bouncer_key
    echo

    install_firewall_bouncer
    echo

    configure_bouncer
    echo

    start_bouncer
    echo

    test_setup
    echo

    show_status

    show_next_steps

    if [ "$OS_TYPE" = "rhel" ]; then
        echo
        echo -e "${YELLOW}CentOS/RHEL 注意事项：${NC}"
        echo "  - 日志位置: $LOG_PATH"
        echo "  - 如果使用 firewalld，建议切换到 iptables"
        echo "  - SELinux 可能需要配置: sudo setenforce 0 (测试)"
        echo "  - Docker 日志挂载已自动适配 CentOS"
    fi
}

main "$@"
