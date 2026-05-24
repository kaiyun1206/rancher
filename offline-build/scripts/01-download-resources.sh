#!/bin/bash
###############################################################################
# 脚本名称: 01-download-resources.sh
# 用途: 在有网络的环境中下载所有离线编译所需的资源
# 执行环境: WSL2 Ubuntu-22.04（需要有网络连接）
# 架构支持: amd64
###############################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
ARCH="amd64"
RESOURCES_DIR="$(cd "$(dirname "$0")/.." && pwd)/resources"
CHARTS_DIR="$RESOURCES_DIR/charts"
BINARIES_DIR="$RESOURCES_DIR/binaries/$ARCH"
UI_DIR="$RESOURCES_DIR/ui-assets"
AGENT_DIR="$RESOURCES_DIR/agent-files"
KDM_DIR="$RESOURCES_DIR/kdm"
TOOLS_DIR="$RESOURCES_DIR/tools"

# 版本配置（从项目文件中提取）
CATTLE_MACHINE_VERSION="v0.15.0-rancher125"
DOCKER_MACHINE_LINODE_VERSION="v0.7.0"
HARVESTER_DRIVER_VERSION="v0.7.2"
TINI_VERSION="v0.18.0"
HELM_V2_VERSION="v2.16.8-rancher2"
HELM_V3_VERSION="v3.16.1"
ETCD_VERSION="v3.5.14"
KUSTOMIZE_VERSION="v5.4.2"
TELEMETRY_VERSION="v0.6.2"
SYSTEM_AGENT_VERSION="v0.3.11"
WINS_VERSION="v0.5.0"
CSI_PROXY_VERSION="v1.1.3"
CLI_VERSION="v2.10.1"
UI_VERSION="2.10.3"
DASHBOARD_VERSION="v2.10.3"
API_UI_VERSION="1.1.11"
CHARTS_BRANCH="release-v2.10"

###############################################################################
# 工具函数
###############################################################################

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_step() {
    echo -e "\n${YELLOW}>>> $1${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}\n"
}

print_error() {
    echo -e "${RED}✗ $1${NC}\n"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}\n"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}\n"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 未安装，请先安装"
        exit 1
    fi
}

confirm_continue() {
    echo -e "${YELLOW}按 Enter 键继续，或输入 'q' 退出...${NC}"
    read -r response
    if [[ "$response" == "q" || "$response" == "Q" ]]; then
        echo "用户取消操作"
        exit 0
    fi
}

###############################################################################
# 检查依赖
###############################################################################

check_dependencies() {
    print_header "步骤 1/7: 检查系统依赖"
    
    local deps=("git" "curl" "wget" "tar" "unzip" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "以下必需工具未安装: ${missing[*]}"
        echo "请执行以下命令安装:"
        echo "sudo apt update && sudo apt install -y ${missing[*]}"
        exit 1
    fi
    
    print_success "所有依赖检查通过"
    confirm_continue
}

###############################################################################
# 创建目录结构
###############################################################################

create_directories() {
    print_header "步骤 2/7: 创建目录结构"
    
    mkdir -p "$CHARTS_DIR"
    mkdir -p "$BINARIES_DIR"
    mkdir -p "$UI_DIR"
    mkdir -p "$AGENT_DIR/system-agent"
    mkdir -p "$AGENT_DIR/wins"
    mkdir -p "$AGENT_DIR/cli"
    mkdir -p "$KDM_DIR"
    mkdir -p "$TOOLS_DIR"
    
    print_success "目录结构创建完成"
    echo "资源目录: $RESOURCES_DIR"
    confirm_continue
}

###############################################################################
# 下载二进制文件
###############################################################################

download_binaries() {
    print_header "步骤 3/7: 下载二进制文件"
    
    cd "$BINARIES_DIR"
    
    # rancher-machine
    print_step "下载 rancher-machine..."
    curl -fL "https://github.com/rancher/machine/releases/download/${CATTLE_MACHINE_VERSION}/rancher-machine-${ARCH}.tar.gz" \
        -o rancher-machine.tar.gz
    print_success "rancher-machine 下载完成"
    
    # docker-machine-driver-linode
    print_step "下载 docker-machine-driver-linode..."
    if curl -fL "https://github.com/linode/docker-machine-driver-linode/releases/download/${DOCKER_MACHINE_LINODE_VERSION}/docker-machine-driver-linode_linux-${ARCH}.zip" \
        -o docker-machine-driver-linode.zip; then
        print_success "docker-machine-driver-linode 下载完成"
    else
        print_warning "docker-machine-driver-linode 下载失败（404），该驱动可能已废弃或版本变更"
        print_info "这不影响 Rancher 核心功能，可以继续"
    fi
    
    # docker-machine-driver-harvester
    print_step "下载 docker-machine-driver-harvester..."
    curl -fL "https://github.com/harvester/docker-machine-driver-harvester/releases/download/${HARVESTER_DRIVER_VERSION}/docker-machine-driver-harvester-${ARCH}.tar.gz" \
        -o docker-machine-driver-harvester.tar.gz
    print_success "docker-machine-driver-harvester 下载完成"
    
    # tini
    print_step "下载 tini..."
    curl -fL "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini" \
        -o tini
    chmod +x tini
    print_success "tini 下载完成"
    
    # helm v2
    print_step "下载 helm v2..."
    curl -fL "https://github.com/rancher/helm/releases/download/${HELM_V2_VERSION}/rancher-helm" \
        -o rancher-helm
    chmod +x rancher-helm
    print_success "helm v2 下载完成"
    
    # tiller v2
    print_step "下载 tiller v2..."
    curl -fL "https://github.com/rancher/helm/releases/download/${HELM_V2_VERSION}/rancher-tiller" \
        -o rancher-tiller
    chmod +x rancher-tiller
    print_success "tiller v2 下载完成"
    
    # helm v3
    print_step "下载 helm v3..."
    curl -fL "https://get.helm.sh/helm-${HELM_V3_VERSION}-linux-${ARCH}.tar.gz" \
        -o helm-v3.tar.gz
    print_success "helm v3 下载完成"
    
    # etcd
    print_step "下载 etcd..."
    curl -fL "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz" \
        -o etcd.tar.gz
    print_success "etcd 下载完成"
    
    # kustomize
    print_step "下载 kustomize..."
    curl -fL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz" \
        -o kustomize.tar.gz
    print_success "kustomize 下载完成"
    
    # telemetry
    print_step "下载 telemetry..."
    curl -fL "https://github.com/rancher/telemetry/releases/download/${TELEMETRY_VERSION}/telemetry-${ARCH}" \
        -o telemetry
    chmod +x telemetry
    print_success "telemetry 下载完成"
    
    print_success "所有二进制文件下载完成"
    confirm_continue
}

###############################################################################
# 克隆 Charts 仓库
###############################################################################

clone_charts() {
    print_header "步骤 4/7: 克隆 Charts 仓库"
    
    cd "$CHARTS_DIR"
    
    # system-charts
    print_step "克隆 system-charts..."
    if [ ! -d "system-charts" ]; then
        git clone --depth=1 --branch "$CHARTS_BRANCH" \
            https://github.com/rancher/system-charts.git
        print_success "system-charts 克隆完成"
    else
        print_warning "system-charts 已存在，跳过"
    fi
    
    # charts (rancher-charts)
    print_step "克隆 charts..."
    if [ ! -d "charts" ]; then
        git clone --depth=1 --branch "$CHARTS_BRANCH" \
            https://github.com/rancher/charts.git
        print_success "charts 克隆完成"
    else
        print_warning "charts 已存在，跳过"
    fi
    
    # partner-charts
    print_step "克隆 partner-charts..."
    if [ ! -d "partner-charts" ]; then
        git clone --depth=1 --branch main \
            https://github.com/rancher/partner-charts.git
        print_success "partner-charts 克隆完成"
    else
        print_warning "partner-charts 已存在，跳过"
    fi
    
    # rke2-charts
    print_step "克隆 rke2-charts..."
    if [ ! -d "rke2-charts" ]; then
        git clone --depth=1 --branch main \
            https://github.com/rancher/rke2-charts.git
        print_success "rke2-charts 克隆完成"
    else
        print_warning "rke2-charts 已存在，跳过"
    fi
    
    print_success "所有 Charts 仓库克隆完成"
    confirm_continue
}

###############################################################################
# 下载 UI 资源
###############################################################################

download_ui_assets() {
    print_header "步骤 5/7: 下载 UI 资源"
    
    cd "$UI_DIR"
    
    # Rancher UI
    print_step "下载 Rancher UI..."
    curl -fL "https://releases.rancher.com/ui/${UI_VERSION}.tar.gz" \
        -o ui-${UI_VERSION}.tar.gz
    print_success "Rancher UI 下载完成"
    
    # Dashboard UI
    print_step "下载 Dashboard UI..."
    curl -fL "https://releases.rancher.com/dashboard/${DASHBOARD_VERSION}.tar.gz" \
        -o dashboard-${DASHBOARD_VERSION}.tar.gz
    print_success "Dashboard UI 下载完成"
    
    # API UI
    print_step "下载 API UI..."
    curl -fL "https://releases.rancher.com/api-ui/${API_UI_VERSION}.tar.gz" \
        -o api-ui-${API_UI_VERSION}.tar.gz
    print_success "API UI 下载完成"
    
    # Linode UI Driver
    print_step "下载 Linode UI Driver..."
    mkdir -p linode-driver
    cd linode-driver
    curl -fL "https://linode.github.io/rancher-ui-driver-linode/releases/${DOCKER_MACHINE_LINODE_VERSION}/component.js" \
        -o component.js
    curl -fL "https://linode.github.io/rancher-ui-driver-linode/releases/${DOCKER_MACHINE_LINODE_VERSION}/component.css" \
        -o component.css
    curl -fL "https://linode.github.io/rancher-ui-driver-linode/releases/${DOCKER_MACHINE_LINODE_VERSION}/linode.svg" \
        -o linode.svg
    cd ..
    print_success "Linode UI Driver 下载完成"
    
    print_success "所有 UI 资源下载完成"
    confirm_continue
}

###############################################################################
# 下载 Agent 文件
###############################################################################

download_agent_files() {
    print_header "步骤 6/7: 下载 Agent 相关文件"
    
    # System Agent
    print_step "下载 System Agent..."
    cd "$AGENT_DIR/system-agent"
    curl -fL "https://github.com/rancher/system-agent/releases/download/${SYSTEM_AGENT_VERSION}/rancher-system-agent-${ARCH}" \
        -o rancher-system-agent-${ARCH}
    curl -fL "https://github.com/rancher/system-agent/releases/download/${SYSTEM_AGENT_VERSION}/install.sh" \
        -o install.sh
    curl -fL "https://github.com/rancher/system-agent/releases/download/${SYSTEM_AGENT_VERSION}/system-agent-uninstall.sh" \
        -o system-agent-uninstall.sh
    print_success "System Agent 下载完成"
    
    # Wins Agent
    print_step "下载 Wins Agent..."
    cd "$AGENT_DIR/wins"
    curl -fL "https://github.com/rancher/wins/releases/download/${WINS_VERSION}/wins.exe" \
        -o wins.exe
    curl -fL "https://raw.githubusercontent.com/rancher/wins/${WINS_VERSION}/install.ps1" \
        -o install.ps1
    curl -fL "https://raw.githubusercontent.com/rancher/wins/${WINS_VERSION}/uninstall.ps1" \
        -o uninstall.ps1
    print_success "Wins Agent 下载完成"
    
    # CLI Tools
    print_step "下载 CLI 工具..."
    cd "$AGENT_DIR/cli"
    curl -fL "https://releases.rancher.com/cli2/${CLI_VERSION}/rancher-linux-${ARCH}-${CLI_VERSION}.tar.gz" \
        -o rancher-linux-${ARCH}-${CLI_VERSION}.tar.gz
    curl -fL "https://releases.rancher.com/cli2/${CLI_VERSION}/rancher-darwin-amd64-${CLI_VERSION}.tar.gz" \
        -o rancher-darwin-amd64-${CLI_VERSION}.tar.gz
    curl -fL "https://releases.rancher.com/cli2/${CLI_VERSION}/rancher-windows-386-${CLI_VERSION}.zip" \
        -o rancher-windows-386-${CLI_VERSION}.zip
    print_success "CLI 工具下载完成"
    
    # CSI Proxy
    print_step "下载 CSI Proxy..."
    curl -fL "https://acs-mirror.azureedge.net/csi-proxy/${CSI_PROXY_VERSION}/binaries/csi-proxy-${CSI_PROXY_VERSION}.tar.gz" \
        -o csi-proxy-${CSI_PROXY_VERSION}.tar.gz
    print_success "CSI Proxy 下载完成"
    
    print_success "所有 Agent 文件下载完成"
    confirm_continue
}

###############################################################################
# 下载 KDM 数据
###############################################################################

download_kdm_data() {
    print_header "步骤 7/7: 下载 KDM 元数据"
    
    cd "$KDM_DIR"
    
    print_step "下载 data.json..."
    curl -fL "https://releases.rancher.com/kontainer-driver-metadata/release-v2.10/data.json" \
        -o data.json
    print_success "KDM data.json 下载完成"
    
    print_success "KDM 数据下载完成"
}

###############################################################################
# 主函数
###############################################################################

main() {
    print_header "Rancher v2.10.3 离线资源下载工具"
    
    echo -e "${YELLOW}警告: 此脚本将在有网络的环境中下载大量资源${NC}"
    echo -e "${YELLOW}预计需要空间: 10-15 GB${NC}"
    echo -e "${YELLOW}预计耗时: 30-60 分钟（取决于网络速度）${NC}\n"
    
    check_dependencies
    create_directories
    download_binaries
    clone_charts
    download_ui_assets
    download_agent_files
    download_kdm_data
    
    print_header "下载完成！"
    
    echo -e "${GREEN}所有资源已下载到: $RESOURCES_DIR${NC}\n"
    echo "目录结构:"
    tree -L 2 "$RESOURCES_DIR" 2>/dev/null || find "$RESOURCES_DIR" -maxdepth 2 -type d
    
    echo -e "\n${BLUE}下一步:${NC}"
    echo "1. 执行脚本导出 Docker 镜像:"
    echo "   ./scripts/02-export-docker-images.sh"
    echo ""
    echo "2. 打包所有资源用于传输:"
    echo "   ./scripts/03-transfer-to-offline.sh"
    
    print_success "资源下载全部完成！"
}

# 执行主函数
main "$@"
