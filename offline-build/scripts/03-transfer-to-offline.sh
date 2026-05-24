#!/bin/bash
###############################################################################
# 脚本名称: 03-transfer-to-offline.sh
# 用途: 打包所有下载的资源，生成用于光盘传输的压缩包
# 执行环境: WSL2 Ubuntu-22.04（在资源下载完成后执行）
# 架构支持: amd64
# 传输介质: 光盘（4.7GB/张）
###############################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
OFFLINE_BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RANCHER_DIR="$(cd "$OFFLINE_BUILD_DIR/.." && pwd)"
RESOURCES_DIR="$OFFLINE_BUILD_DIR/resources"
MODIFIED_FILES_DIR="$OFFLINE_BUILD_DIR/modified-files"
OUTPUT_FILE="/tmp/rancher-offline-package.tar.gz"
CHECKSUM_FILE="/tmp/rancher-offline-package.sha256"

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
# 检查资源完整性
###############################################################################

check_resources() {
    print_header "步骤 1/4: 检查资源完整性"
    
    local missing_dirs=()
    local required_dirs=(
        "docker-images"
        "binaries/amd64"
        "charts/system-charts"
        "charts/charts"
        "ui-assets"
        "agent-files"
        "kdm"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$RESOURCES_DIR/$dir" ]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [ ${#missing_dirs[@]} -ne 0 ]; then
        print_error "以下必需目录缺失:"
        for dir in "${missing_dirs[@]}"; do
            echo "  - $dir"
        done
        echo ""
        echo "请先运行资源下载脚本:"
        echo "./scripts/01-download-resources.sh"
        echo "./scripts/02-export-docker-images.sh"
        exit 1
    fi
    
    # 检查关键文件
    if [ ! -f "$RESOURCES_DIR/kdm/data.json" ]; then
        print_error "KDM data.json 文件缺失"
        exit 1
    fi
    
    # 检查 Docker 镜像文件
    local image_count=$(find "$RESOURCES_DIR/docker-images" -name "*.tar" | wc -l)
    if [ "$image_count" -eq 0 ]; then
        print_error "未找到 Docker 镜像文件"
        exit 1
    fi
    
    # 检查 zypper RPM 包（用于离线安装系统依赖）
    local rpm_count=$(find "$RESOURCES_DIR/zypper-packages" -name "*.rpm" 2>/dev/null | wc -l)
    if [ "$rpm_count" -eq 0 ]; then
        print_warning "未找到 zypper RPM 包"
        echo ""
        echo "Dockerfile.offline 需要这些 RPM 包来安装系统依赖。"
        echo "请执行以下命令导出 RPM 包:"
        echo "  ./scripts/05-export-zypper-packages.sh"
        echo ""
        echo "按 Enter 键继续（可能导致离线构建失败），或输入 'q' 退出..."
        read -r response
        if [[ "$response" == "q" || "$response" == "Q" ]]; then
            exit 1
        fi
    else
        print_success "找到 $rpm_count 个 zypper RPM 包"
    fi
    
    # 检查 Go vendor 目录
    if [ ! -d "$RANCHER_DIR/vendor" ]; then
        print_error "Go vendor 目录缺失: $RANCHER_DIR/vendor"
        echo ""
        echo "请先在联网环境执行以下命令生成 vendor 目录:"
        echo "  cd $RANCHER_DIR"
        echo "  go mod tidy"
        echo "  go mod vendor"
        exit 1
    fi
    
    # 检查 go.mod 和 go.sum
    if [ ! -f "$RANCHER_DIR/go.mod" ] || [ ! -f "$RANCHER_DIR/go.sum" ]; then
        print_error "go.mod 或 go.sum 文件缺失"
        exit 1
    fi
    
    # 检查 Rancher 源码是否存在
    if [ ! -f "$RANCHER_DIR/main.go" ]; then
        print_error "Rancher 源码不存在: $RANCHER_DIR/main.go"
        exit 1
    fi
    
    # 检查 .git 目录（可选，但建议包含）
    if [ -d "$RANCHER_DIR/.git" ]; then
        print_success ".git 目录存在（将包含所有分支和标签）"
    else
        print_warning ".git 目录不存在（离线环境将无法查看 Git 历史）"
    fi
    
    print_success "资源完整性检查通过"
    echo "找到 $image_count 个 Docker 镜像文件"
    echo "Go vendor 目录大小: $(du -sh "$RANCHER_DIR/vendor" | cut -f1)"
    echo "Rancher 源码大小: $(du -sh "$RANCHER_DIR" --exclude=offline-build | cut -f1)"
    confirm_continue
}

###############################################################################
# 准备修改后的文件
###############################################################################

prepare_modified_files() {
    print_header "步骤 2/4: 准备离线版本文件"
    
    mkdir -p "$MODIFIED_FILES_DIR/package"
    mkdir -p "$MODIFIED_FILES_DIR/scripts"
    
    # 创建离线版 Dockerfile
    print_step "创建离线版 Dockerfile..."
    cat > "$MODIFIED_FILES_DIR/package/Dockerfile.offline" << 'DOCKERFILE_EOF'
# 离线版 Dockerfile - 使用本地资源
# 注意: 此文件需要在构建前替换原始的 package/Dockerfile

FROM registry.suse.com/bci/bci-base:15.6

ARG ARCH=amd64
ENV ARCH=${ARCH}

# 安装基础依赖
RUN zypper -n install \
    git-core \
    curl \
    wget \
    tar \
    gzip \
    unzip \
    sed \
    gawk \
    jq \
    iptables \
    ca-certificates \
    && zypper clean -a

# 从本地复制二进制文件（而不是从网络下载）
COPY resources/binaries/${ARCH}/rancher-machine.tar.gz /tmp/
RUN tar xvzf /tmp/rancher-machine.tar.gz -C /usr/bin && \
    rm /tmp/rancher-machine.tar.gz

COPY resources/binaries/${ARCH}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

COPY resources/binaries/${ARCH}/helm-v3.tar.gz /tmp/
RUN tar xvzf /tmp/helm-v3.tar.gz --strip-components=1 -C /usr/bin && \
    rm /tmp/helm-v3.tar.gz

COPY resources/binaries/${ARCH}/etcd.tar.gz /tmp/
RUN tar xvzf /tmp/etcd.tar.gz --strip-components=1 -C /usr/bin && \
    rm /tmp/etcd.tar.gz

COPY resources/binaries/${ARCH}/kustomize.tar.gz /tmp/
RUN tar xvzf /tmp/kustomize.tar.gz -C /usr/bin && \
    rm /tmp/kustomize.tar.gz

# 复制 Charts 仓库
COPY resources/charts/system-charts /var/lib/rancher-data/local-catalogs/system-library
COPY resources/charts/charts /var/lib/rancher-data/local-catalogs/v2/rancher-charts/latest
COPY resources/charts/partner-charts /var/lib/rancher-data/local-catalogs/v2/rancher-partner-charts/latest
COPY resources/charts/rke2-charts /var/lib/rancher-data/local-catalogs/v2/rancher-rke2-charts/latest

# 复制 UI 资源
COPY resources/ui-assets/ui-*.tar.gz /usr/share/rancher/ui/
COPY resources/ui-assets/dashboard-*.tar.gz /usr/share/rancher/ui-dashboard/
COPY resources/ui-assets/api-ui-*.tar.gz /usr/share/rancher/ui-api/

# 复制 Agent 文件
COPY resources/agent-files/system-agent/* /usr/share/rancher/agent-files/system-agent/
COPY resources/agent-files/wins/* /usr/share/rancher/agent-files/wins/

# 复制 KDM 数据
COPY resources/kdm/data.json /var/lib/rancher-data/kdm/data.json

# ... 其余部分保持与原始 Dockerfile 相同 ...
# 注意: 实际使用时需要基于原始 Dockerfile 进行修改

VOLUME /var/lib/rancher
WORKDIR /usr/share/rancher

ENTRYPOINT ["entrypoint.sh"]
DOCKERFILE_EOF
    
    print_success "离线版 Dockerfile 创建完成"
    
    # 创建离线版 build-server 脚本
    print_step "创建离线版 build-server..."
    cat > "$MODIFIED_FILES_DIR/scripts/build-server-offline" << 'BUILD_SERVER_EOF'
#!/bin/bash
# 离线版 build-server 脚本
set -ex

source $(dirname $0)/version
source $(dirname $0)/export-config

cd $(dirname $0)/..

mkdir -p bin

if [ -n "${DEBUG}" ]; then
  GCFLAGS="-N -l"
fi

if [ "$(uname)" != "Darwin" ]; then
  LINKFLAGS="-extldflags -static"
  if [ -z "${DEBUG}" ]; then
    LINKFLAGS="${LINKFLAGS} -s"
  fi
fi

RKE_VERSION="$(grep -m1 'github.com/rancher/rke' go.mod | awk '{print $2}')"

# Inject Setting values
DEFAULT_VALUES="{\"rke-version\":\"${RKE_VERSION}\"}"

# 离线模式：禁用网络访问
export GOPROXY=off
export GOFLAGS=-mod=vendor

CGO_ENABLED=0 go build -tags k8s \
  -gcflags="all=${GCFLAGS}" \
  -ldflags \
  "-X github.com/rancher/rancher/pkg/version.Version=$VERSION
   -X github.com/rancher/rancher/pkg/version.GitCommit=$COMMIT
   -X github.com/rancher/rancher/pkg/settings.InjectDefaults=$DEFAULT_VALUES $LINKFLAGS" \
  -o bin/rancher

# 使用本地的 data.json
if [ -e resources/kdm/data.json ]; then
    cp resources/kdm/data.json bin/data.json
elif [ -e bin/data.json ]; then
    echo "Using existing bin/data.json"
else
    echo "ERROR: data.json not found!"
    exit 1
fi
BUILD_SERVER_EOF
    
    chmod +x "$MODIFIED_FILES_DIR/scripts/build-server-offline"
    print_success "离线版 build-server 创建完成"
    
    # 创建离线版 package 脚本
    print_step "创建离线版 package 脚本..."
    cat > "$MODIFIED_FILES_DIR/scripts/package-offline" << 'PACKAGE_EOF'
#!/bin/bash
# 离线版 package 脚本
set -ex

source $(dirname $0)/version
source $(dirname $0)/export-config
source $(dirname $0)/package-env

cd $(dirname $0)/..

ARCH=${ARCH:-"amd64"}
TAG=${TAG:-"v2.10.3"}
REPO=${REPO:-"rancher"}

echo "Building Rancher ${TAG} for ${ARCH}..."

# 编译 server 和 agent
./scripts/build-server-offline
./scripts/build-agent

# 构建 Docker 镜像（使用离线版 Dockerfile）
cd package
docker build \
    --build-arg VERSION=${TAG} \
    --build-arg ARCH=${ARCH} \
    --build-arg IMAGE_REPO=${REPO} \
    -f Dockerfile.offline \
    -t ${REPO}/rancher:${TAG} .

cd ..

echo "Build complete!"
PACKAGE_EOF
    
    chmod +x "$MODIFIED_FILES_DIR/scripts/package-offline"
    print_success "离线版 package 脚本创建完成"
    
    confirm_continue
}

###############################################################################
# 打包资源
###############################################################################

package_resources() {
    print_header "步骤 3/4: 打包所有资源"
    
    print_step "计算资源大小..."
    local rancher_size=$(du -sh "$RANCHER_DIR" --exclude=offline-build | cut -f1)
    local resources_size=$(du -sh "$RESOURCES_DIR" | cut -f1)
    local total_size=$(du -sh "$RANCHER_DIR" --exclude=offline-build | cut -f1)
    
    echo "Rancher 源码大小（含.git）: $rancher_size"
    echo "资源目录大小: $resources_size"
    echo "预计压缩包大小: ~3.0 GB"
    echo "光盘容量: 4.7 GB"
    echo ""
    
    # 检查是否超过光盘容量
    local size_mb=$(du -sm "$RANCHER_DIR" --exclude=offline-build | cut -f1)
    local resources_mb=$(du -sm "$RESOURCES_DIR" | cut -f1)
    local total_mb=$((size_mb + resources_mb))
    
    if [ "$total_mb" -gt 4500 ]; then
        print_error "总大小 (${total_mb}MB) 超过光盘容量 (4500MB)"
        echo "请考虑删除不必要的文件或拆分打包"
        exit 1
    fi
    
    print_step "创建压缩包..."
    echo "输出文件: $OUTPUT_FILE"
    echo ""
    
    # 创建临时打包目录
    local temp_dir="/tmp/offline-build-package"
    mkdir -p "$temp_dir"
    
    # 复制整个 Rancher 项目目录（包含 .git、vendor、所有源码）
    print_step "正在复制 Rancher 完整项目（含 .git 目录）..."
    echo "这将包含："
    echo "  - 所有源代码"
    echo "  - .git 目录（所有分支、标签、历史）"
    echo "  - vendor/ 目录（Go 依赖）"
    echo "  - go.mod 和 go.sum"
    echo "  - 所有配置文件"
    cp -r "$RANCHER_DIR" "$temp_dir/rancher"
    
    # 复制 offline-build 资源目录
    print_step "正在复制资源目录..."
    cp -r "$RESOURCES_DIR" "$temp_dir/rancher/offline-build/resources"
    
    # 复制 modified-files
    print_step "正在复制离线配置文件..."
    cp -r "$MODIFIED_FILES_DIR" "$temp_dir/rancher/offline-build/modified-files"
    
    # 创建 README
    cat > "$temp_dir/rancher/offline-build/OFFLINE-BUILD-README.txt" << 'README_EOF'
Rancher v2.10.3 离线编译完整包
================================

包含内容:
- rancher/: 完整的 Rancher 项目目录
  ├── .git/               ← 包含所有分支、标签、Git 历史
  ├── vendor/             ← Go 模块依赖（离线编译必需）
  ├── go.mod & go.sum     ← Go 模块配置
  ├── cmd/                ← 源代码
  ├── pkg/                ← 源代码
  ├── scripts/            ← 构建脚本
  ├── package/            ← Docker 配置
  └── ...                 ← 所有其他文件和目录
  
- rancher/offline-build/resources/  ← 所有下载的资源文件
  ├── docker-images/      ← Docker 基础镜像
  ├── binaries/           ← 二进制工具
  ├── charts/             ← Helm Charts
  ├── ui-assets/          ← UI 资源
  ├── agent-files/        ← Agent 文件
  └── kdm/                ← KDM 元数据

- rancher/offline-build/modified-files/  ← 离线版本配置文件
  ├── package/Dockerfile.offline
  └── scripts/build-server-offline

使用说明:
1. 将此包刻录到光盘（4.7GB）
2. 在离线环境中从光盘复制到硬盘
3. 解压: tar xzf rancher-offline-package.tar.gz
4. 进入目录: cd rancher
5. 执行编译: ./offline-build/scripts/04-build-in-offline.sh

重要提示:
- 此包包含完整的 Git 仓库，可以查看所有分支和标签
- 离线环境中可以使用 git checkout 切换分支
- vendor 目录是离线编译的关键
- 离线编译时使用 GOFLAGS=-mod=vendor 参数

Git 功能（离线环境）:
- ✓ git branch -a        查看所有分支
- ✓ git tag              查看所有标签
- ✓ git log              查看提交历史
- ✓ git checkout <tag>   切换到指定标签
- ✗ git pull/push        需要网络连接

生成时间: $(date)
架构: amd64
版本: v2.10.3
README_EOF
    
    # 打包（包含所有文件和目录，不排除任何内容）
    print_step "开始压缩打包..."
    echo "注意: 此操作可能需要 10-20 分钟"
    echo ""
    
    cd /tmp
    tar czf "$OUTPUT_FILE" -C /tmp offline-build-package
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    print_success "资源打包完成"
    
    # 生成校验和
    sha256sum "$OUTPUT_FILE" > "$CHECKSUM_FILE"
    print_success "校验和文件已生成"
}

###############################################################################
# 显示结果
###############################################################################

show_results() {
    print_header "打包结果"
    
    echo "输出文件信息:"
    ls -lh "$OUTPUT_FILE"
    echo ""
    
    echo "校验和:"
    cat "$CHECKSUM_FILE"
    echo ""
    
    echo "文件大小统计:"
    local file_size_mb=$(du -sm "$OUTPUT_FILE" | cut -f1)
    echo "  压缩包大小: $(du -h "$OUTPUT_FILE" | cut -f1) (${file_size_mb}MB)"
    echo "  光盘容量: 4.7 GB (4700MB)"
    echo "  剩余空间: $((4700 - file_size_mb))MB"
    echo ""
    
    if [ "$file_size_mb" -lt 4500 ]; then
        echo -e "${GREEN}✓ 文件大小适合单张光盘刻录${NC}"
    else
        echo -e "${YELLOW}⚠ 文件较大，建议使用双层光盘或拆分打包${NC}"
    fi
    
    echo ""
    echo "光盘刻录说明:"
    echo "1. Windows 系统:"
    echo "   - 右键点击 ISO 文件 → 刻录光盘映像"
    echo "   - 或使用 ImgBurn、Nero 等刻录软件"
    echo ""
    echo "2. Linux 系统:"
    echo "   - 使用 Brasero、K3b 等刻录工具"
    echo "   - 或命令行: wodim -v dev=/dev/cdrom rancher-offline.iso"
    echo ""
    echo "3. 验证完整性（在目标机器上）:"
    echo "   sha256sum -c rancher-offline-package.sha256"
}

###############################################################################
# 主函数
###############################################################################

main() {
    print_header "Rancher v2.10.3 离线资源打包工具（完整版）"
    
    echo -e "${YELLOW}此脚本将打包完整的 Rancher 项目用于光盘传输${NC}"
    echo -e "${YELLOW}包含内容: 源码(含.git) + vendor + resources + 配置文件${NC}"
    echo -e "${YELLOW}预计耗时: 15-25 分钟${NC}"
    echo -e "${YELLOW}光盘容量: 4.7 GB${NC}\n"
    
    check_resources
    prepare_modified_files
    package_resources
    show_results
    
    print_header "打包完成！"
    
    echo -e "${GREEN}输出文件: $OUTPUT_FILE${NC}"
    echo -e "${GREEN}校验和文件: $CHECKSUM_FILE${NC}\n"
    
    echo -e "${BLUE}下一步:${NC}"
    echo "1. 将 $OUTPUT_FILE 刻录到光盘（4.7GB）"
    echo "2. 在离线环境中从光盘复制到硬盘并解压"
    echo "3. 参考 rancher/offline-build/README.md 获取详细说明"
    echo ""
    echo -e "${BLUE}Git 功能说明:${NC}"
    echo "- 离线环境中可以查看所有分支和标签"
    echo "- 可以使用 git checkout 切换到其他版本"
    echo "- 无法执行 git pull/push（需要网络）"
    
    print_success "资源打包全部完成！可以刻录光盘了！"
}

# 执行主函数
main "$@"
