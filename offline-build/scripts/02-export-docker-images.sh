#!/bin/bash
###############################################################################
# 脚本名称: 02-export-docker-images.sh
# 用途: 导出所有必需的 Docker 基础镜像为 tar 文件
# 执行环境: WSL2 Ubuntu-22.04（需要有网络连接和 Docker）
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
RESOURCES_DIR="$(cd "$(dirname "$0")/.." && pwd)/resources"
IMAGES_DIR="$RESOURCES_DIR/docker-images"

# Docker 镜像列表
declare -A DOCKER_IMAGES=(
    ["registry.suse.com/bci/bci-micro:15.6"]="bci-micro-15.6.tar"
    ["registry.suse.com/bci/bci-base:15.6"]="bci-base-15.6.tar"
    ["registry.suse.com/bci/golang:1.23"]="golang-1.23.tar"
    ["rancher/k3s:v1.31.1-k3s1"]="k3s-v1.31.1-k3s1.tar"
)

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

confirm_continue() {
    echo -e "${YELLOW}按 Enter 键继续，或输入 'q' 退出...${NC}"
    read -r response
    if [[ "$response" == "q" || "$response" == "Q" ]]; then
        echo "用户取消操作"
        exit 0
    fi
}

###############################################################################
# 检查 Docker
###############################################################################

check_docker() {
    print_header "步骤 1/3: 检查 Docker 环境"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装"
        echo "请安装 Docker:"
        echo "sudo apt install -y docker.io"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行"
        echo "请启动 Docker 服务:"
        echo "sudo service docker start"
        exit 1
    fi
    
    print_success "Docker 环境检查通过"
    echo "Docker 版本: $(docker --version)"
    confirm_continue
}

###############################################################################
# 创建输出目录
###############################################################################

create_output_dir() {
    print_header "步骤 2/3: 准备输出目录"
    
    mkdir -p "$IMAGES_DIR"
    
    print_success "输出目录已创建: $IMAGES_DIR"
    confirm_continue
}

###############################################################################
# 拉取并导出镜像
###############################################################################

export_images() {
    print_header "步骤 3/3: 拉取并导出 Docker 镜像"
    
    local total=${#DOCKER_IMAGES[@]}
    local current=0
    local failed=()
    
    for image in "${!DOCKER_IMAGES[@]}"; do
        current=$((current + 1))
        local output_file="${DOCKER_IMAGES[$image]}"
        local output_path="$IMAGES_DIR/$output_file"
        
        print_step "[$current/$total] 处理镜像: $image"
        
        # 检查是否已存在
        if [ -f "$output_path" ]; then
            print_warning "$output_file 已存在，跳过"
            continue
        fi
        
        # 拉取镜像
        echo "正在拉取镜像..."
        if ! docker pull "$image"; then
            print_error "拉取镜像失败: $image"
            failed+=("$image")
            continue
        fi
        
        # 导出镜像
        echo "正在导出镜像到 $output_file..."
        if docker save "$image" -o "$output_path"; then
            print_success "$image 导出完成 ($(du -h "$output_path" | cut -f1))"
        else
            print_error "导出镜像失败: $image"
            failed+=("$image")
            rm -f "$output_path"
        fi
        
        echo ""
    done
    
    # 检查是否有失败的
    if [ ${#failed[@]} -ne 0 ]; then
        print_error "以下镜像处理失败:"
        for img in "${failed[@]}"; do
            echo "  - $img"
        done
        echo ""
        echo "请检查网络连接后重新运行脚本"
        exit 1
    fi
    
    print_success "所有 Docker 镜像导出完成"
}

###############################################################################
# 显示结果
###############################################################################

show_results() {
    print_header "导出结果"
    
    echo "导出的镜像文件:"
    ls -lh "$IMAGES_DIR"/*.tar
    
    echo ""
    echo "总大小:"
    du -sh "$IMAGES_DIR"
    
    echo ""
    echo "验证镜像可以加载（可选）:"
    echo "docker load -i $IMAGES_DIR/bci-micro-15.6.tar"
}

###############################################################################
# 主函数
###############################################################################

main() {
    print_header "Rancher v2.10.3 Docker 镜像导出工具"
    
    echo -e "${YELLOW}警告: 此脚本将拉取并导出多个 Docker 镜像${NC}"
    echo -e "${YELLOW}预计需要空间: 5-8 GB${NC}"
    echo -e "${YELLOW}预计耗时: 20-40 分钟（取决于网络速度）${NC}\n"
    
    check_docker
    create_output_dir
    export_images
    show_results
    
    print_header "导出完成！"
    
    echo -e "${BLUE}下一步:${NC}"
    echo "打包所有资源用于传输:"
    echo "./scripts/03-transfer-to-offline.sh"
    
    print_success "Docker 镜像导出全部完成！"
}

# 执行主函数
main "$@"
