#!/bin/bash
###############################################################################
# 脚本名称: 04-build-in-offline.sh
# 用途: 在离线环境中执行 Rancher 编译和 Docker 镜像打包
# 执行环境: WSL2 Ubuntu-22.04（完全离线环境）
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
RANCHER_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OFFLINE_BUILD_DIR="$RANCHER_DIR/offline-build"
RESOURCES_DIR="$OFFLINE_BUILD_DIR/resources"
MODIFIED_FILES_DIR="$OFFLINE_BUILD_DIR/modified-files"
DIST_DIR="$RANCHER_DIR/dist"

ARCH="amd64"
TAG="${TAG:-v2.10.3}"
REPO="${REPO:-rancher}"

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
# 检查环境
###############################################################################

check_environment() {
    print_header "步骤 1/7: 检查离线环境"
    
    # 检查必需目录
    if [ ! -d "$RESOURCES_DIR" ]; then
        print_error "资源目录不存在: $RESOURCES_DIR"
        echo "请确保已解压离线资源包"
        exit 1
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行"
        echo "启动 Docker: sudo service docker start"
        exit 1
    fi
    
    # 检查 Go
    if ! command -v go &> /dev/null; then
        print_error "Go 未安装"
        exit 1
    fi
    
    local go_version=$(go version | awk '{print $3}')
    echo "Go 版本: $go_version"
    
    # 检查磁盘空间
    local available_space=$(df -BG "$RANCHER_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$available_space" -lt 50 ]; then
        print_warning "可用磁盘空间不足: ${available_space}GB（建议至少 50GB）"
        confirm_continue
    fi
    
    print_success "环境检查通过"
    confirm_continue
}

###############################################################################
# 加载 Docker 镜像
###############################################################################

load_docker_images() {
    print_header "步骤 2/7: 加载 Docker 基础镜像"
    
    local images_dir="$RESOURCES_DIR/docker-images"
    local image_count=$(find "$images_dir" -name "*.tar" | wc -l)
    
    if [ "$image_count" -eq 0 ]; then
        print_error "未找到 Docker 镜像文件"
        exit 1
    fi
    
    echo "找到 $image_count 个镜像文件"
    
    for img in "$images_dir"/*.tar; do
        local img_name=$(basename "$img")
        print_step "加载镜像: $img_name"
        
        if docker load -i "$img"; then
            print_success "$img_name 加载成功"
        else
            print_error "$img_name 加载失败"
            exit 1
        fi
    done
    
    # 验证关键镜像
    print_step "验证关键镜像..."
    local required_images=(
        "registry.suse.com/bci/bci-micro:15.6"
        "registry.suse.com/bci/bci-base:15.6"
        "registry.suse.com/bci/golang:1.23"
        "rancher/k3s:v1.31.1-k3s1"
    )
    
    for img in "${required_images[@]}"; do
        if docker image inspect "$img" &> /dev/null; then
            print_success "镜像存在: $img"
        else
            print_error "镜像缺失: $img"
            exit 1
        fi
    done
    
    print_success "所有 Docker 镜像加载完成"
    confirm_continue
}

###############################################################################
# 替换为离线版本文件
###############################################################################

replace_with_offline_files() {
    print_header "步骤 3/7: 替换为离线版本文件"
    
    cd "$RANCHER_DIR"
    
    # 备份原始文件
    print_step "备份原始文件..."
    cp package/Dockerfile package/Dockerfile.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
    cp scripts/build-server scripts/build-server.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
    
    # 复制离线版本文件
    print_step "复制离线版本文件..."
    
    if [ -f "$MODIFIED_FILES_DIR/package/Dockerfile.offline" ]; then
        cp "$MODIFIED_FILES_DIR/package/Dockerfile.offline" package/Dockerfile
        print_success "Dockerfile 已替换"
    else
        print_warning "未找到离线版 Dockerfile，使用原始文件"
    fi
    
    if [ -f "$MODIFIED_FILES_DIR/scripts/build-server-offline" ]; then
        cp "$MODIFIED_FILES_DIR/scripts/build-server-offline" scripts/build-server
        chmod +x scripts/build-server
        print_success "build-server 已替换"
    else
        print_warning "未找到离线版 build-server，使用原始文件"
    fi
    
    print_success "文件替换完成"
    confirm_continue
}

###############################################################################
# 设置 Go 编译环境
###############################################################################

setup_go_environment() {
    print_header "步骤 4/7: 设置离线 Go 编译环境"
    
    cd "$RANCHER_DIR"
    
    # 检查 vendor 目录是否存在（必须从在线环境传输过来）
    if [ ! -d "vendor" ]; then
        print_error "vendor 目录不存在！"
        echo ""
        echo "在离线环境中无法生成 vendor 目录。"
        echo "请确保已将从在线环境打包的 vendor/、go.mod、go.sum 文件复制到项目根目录。"
        echo ""
        echo "正确的操作步骤："
        echo "1. 解压离线资源包到临时目录"
        echo "2. 将 vendor/ 目录移动到 $RANCHER_DIR/"
        echo "3. 将 go.mod 和 go.sum 移动到 $RANCHER_DIR/"
        echo "4. 重新运行此脚本"
        exit 1
    fi
    
    # 检查 go.mod 和 go.sum
    if [ ! -f "go.mod" ] || [ ! -f "go.sum" ]; then
        print_error "go.mod 或 go.sum 文件缺失"
        echo "请确保已从在线环境复制这些文件到项目根目录"
        exit 1
    fi
    
    # 设置离线模式环境变量
    export GOPROXY=off
    export GOFLAGS=-mod=vendor
    export GONOSUMDB=*
    export GONOSUMCHECK=*
    export GO111MODULE=on
    
    print_success "Go 环境变量已设置"
    echo "GOPROXY=$GOPROXY (离线模式)"
    echo "GOFLAGS=$GOFLAGS (使用 vendor 目录)"
    echo "GONOSUMDB=$GONOSUMDB"
    echo "GONOSUMCHECK=$GONOSUMCHECK"
    echo ""
    echo "vendor 目录大小: $(du -sh vendor | cut -f1)"
    echo "vendor 文件数量: $(find vendor -type f | wc -l)"
    
    confirm_continue
}

###############################################################################
# 编译 Rancher Server
###############################################################################

build_rancher_server() {
    print_header "步骤 5/7: 编译 Rancher Server"
    
    cd "$RANCHER_DIR"
    
    print_step "开始编译..."
    
    # 使用离线版 build-server
    if [ -f "scripts/build-server" ]; then
        ./scripts/build-server
    else
        print_error "build-server 脚本不存在"
        exit 1
    fi
    
    # 验证编译结果
    if [ -f "bin/rancher" ]; then
        print_success "Rancher Server 编译成功"
        ls -lh bin/rancher
    else
        print_error "编译失败，未找到 bin/rancher"
        exit 1
    fi
    
    # 复制 data.json
    if [ -f "resources/kdm/data.json" ]; then
        cp resources/kdm/data.json bin/data.json
        print_success "data.json 已复制"
    fi
    
    confirm_continue
}

###############################################################################
# 编译 Rancher Agent
###############################################################################

build_rancher_agent() {
    print_header "步骤 6/7: 编译 Rancher Agent"
    
    cd "$RANCHER_DIR"
    
    print_step "开始编译 Agent..."
    
    # 检查是否有 agent 编译脚本
    if [ -f "scripts/build-agent" ]; then
        ./scripts/build-agent
        print_success "Rancher Agent 编译成功"
    else
        print_warning "未找到 build-agent 脚本，跳过 Agent 编译"
    fi
    
    confirm_continue
}

###############################################################################
# 构建 Docker 镜像
###############################################################################

build_docker_images() {
    print_header "步骤 7/7: 构建 Docker 镜像"
    
    cd "$RANCHER_DIR/package"
    
    mkdir -p "$DIST_DIR"
    
    # 构建 Rancher Server 镜像
    print_step "构建 Rancher Server 镜像..."
    docker build \
        --build-arg VERSION=${TAG} \
        --build-arg ARCH=${ARCH} \
        --build-arg IMAGE_REPO=${REPO} \
        --build-arg SYSTEM_CHART_DEFAULT_BRANCH=release-v2.10 \
        --build-arg CHART_DEFAULT_BRANCH=release-v2.10 \
        -f Dockerfile \
        -t ${REPO}/rancher:${TAG} .
    
    print_success "Rancher Server 镜像构建完成"
    
    # 保存 Server 镜像
    print_step "保存 Rancher Server 镜像..."
    docker save ${REPO}/rancher:${TAG} -o "$DIST_DIR/rancher-${TAG}-${ARCH}.tar"
    print_success "镜像已保存: dist/rancher-${TAG}-${ARCH}.tar"
    
    # 构建 Rancher Agent 镜像（如果有 Dockerfile.agent）
    if [ -f "Dockerfile.agent" ]; then
        print_step "构建 Rancher Agent 镜像..."
        docker build \
            --build-arg VERSION=${TAG} \
            --build-arg ARCH=${ARCH} \
            --build-arg RANCHER_TAG=${TAG} \
            --build-arg RANCHER_REPO=${REPO} \
            -f Dockerfile.agent \
            -t ${REPO}/rancher-agent:${TAG} .
        
        print_success "Rancher Agent 镜像构建完成"
        
        # 保存 Agent 镜像
        print_step "保存 Rancher Agent 镜像..."
        docker save ${REPO}/rancher-agent:${TAG} -o "$DIST_DIR/rancher-agent-${TAG}-${ARCH}.tar"
        print_success "镜像已保存: dist/rancher-agent-${TAG}-${ARCH}.tar"
    else
        print_warning "未找到 Dockerfile.agent，跳过 Agent 镜像构建"
    fi
    
    print_success "所有 Docker 镜像构建完成"
}

###############################################################################
# 显示结果
###############################################################################

show_results() {
    print_header "编译打包完成！"
    
    echo "输出文件:"
    ls -lh "$DIST_DIR"/*.tar 2>/dev/null || echo "未找到输出文件"
    echo ""
    
    echo "镜像列表:"
    docker images | grep rancher
    echo ""
    
    echo "测试运行 Rancher:"
    echo "docker run -d --name rancher-test \\"
    echo "    --restart=unless-stopped \\"
    echo "    -p 80:80 -p 443:443 \\"
    echo "    -e CATTLE_SYSTEM_CATALOG=bundled \\"
    echo "    rancher/rancher:${TAG}"
    echo ""
    
    echo "访问地址: https://localhost"
    echo "注意: 首次访问需要接受自签名证书警告"
}

###############################################################################
# 主函数
###############################################################################

main() {
    print_header "Rancher v2.10.3 离线编译打包工具"
    
    echo -e "${YELLOW}警告: 此脚本将在离线环境中编译 Rancher${NC}"
    echo -e "${YELLOW}预计耗时: 30-60 分钟（取决于机器性能）${NC}"
    echo -e "${YELLOW}所需空间: 至少 50GB${NC}\n"
    
    check_environment
    load_docker_images
    replace_with_offline_files
    setup_go_environment
    build_rancher_server
    build_rancher_agent
    build_docker_images
    show_results
    
    print_header "全部完成！"
    
    echo -e "${GREEN}Rancher v2.10.3 离线编译打包成功！${NC}\n"
    echo "输出目录: $DIST_DIR"
    echo ""
    echo "下一步:"
    echo "1. 将 dist/ 目录中的 tar 文件传输到目标环境"
    echo "2. 在目标环境中加载镜像: docker load -i rancher-*.tar"
    echo "3. 运行 Rancher 容器"
    
    print_success "离线编译打包全部完成！"
}

# 执行主函数
main "$@"
