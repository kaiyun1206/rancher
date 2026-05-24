#!/bin/bash
###############################################################################
# 脚本名称: 03-transfer-to-offline.sh (简化版)
# 用途: 快速打包整个 Rancher 项目用于离线传输
# 执行环境: WSL2 Ubuntu-22.04（联网环境）
# 架构支持: amd64
# 传输介质: 光盘（4.7GB/张）或 USB 存储设备
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
OUTPUT_DIR="/tmp/rancher-offline"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/rancher-offline-${TIMESTAMP}.tar.gz"

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

###############################################################################
# 主流程
###############################################################################

main() {
    print_header "Rancher 离线编译资源打包工具（简化版）"
    
    echo -e "${BLUE}本脚本将直接压缩整个 Rancher 项目目录，包含:${NC}"
    echo -e "  ✓ 完整的 Rancher 源码（含 .git 历史）"
    echo -e "  ✓ Go vendor 依赖目录"
    echo -e "  ✓ Docker 基础镜像（resources/docker-images/*.tar）"
    echo -e "  ✓ 二进制工具（rancher-machine, helm, etcd 等）"
    echo -e "  ✓ Helm Charts 仓库（system-charts, charts 等）"
    echo -e "  ✓ UI 资源（dashboard, ui, api-ui）"
    echo -e "  ✓ Agent 文件（system-agent, wins, cli tools）"
    echo -e "  ✓ Zypper RPM 包（系统依赖）"
    echo -e "  ✓ 离线构建脚本和文档"
    echo ""
    
    # 步骤 1: 检查关键资源
    print_step "步骤 1/3: 检查关键资源"
    
    # 检查 vendor 目录
    if [ ! -d "$RANCHER_DIR/vendor" ]; then
        print_error "Go vendor 目录缺失！"
        echo ""
        echo "请先在联网环境执行以下命令生成 vendor 目录:"
        echo "  cd $RANCHER_DIR"
        echo "  go mod tidy"
        echo "  go mod vendor"
        exit 1
    fi
    print_success "Go vendor 目录存在 ($(du -sh "$RANCHER_DIR/vendor" | cut -f1))"
    
    # 检查 Docker 镜像
    local image_count=$(find "$OFFLINE_BUILD_DIR/resources/docker-images" -name "*.tar" 2>/dev/null | wc -l)
    if [ "$image_count" -eq 0 ]; then
        print_warning "未找到 Docker 镜像文件"
        echo ""
        echo "请先运行导出脚本:"
        echo "  ./scripts/02-export-docker-images.sh"
        echo ""
        echo "按 Enter 键继续（可能导致离线构建失败），或输入 'q' 退出..."
        read -r response
        if [[ "$response" == "q" || "$response" == "Q" ]]; then
            exit 1
        fi
    else
        print_success "找到 $image_count 个 Docker 镜像文件"
    fi
    
    # 检查 zypper RPM 包
    local rpm_count=$(find "$OFFLINE_BUILD_DIR/resources/zypper-packages" -name "*.rpm" 2>/dev/null | wc -l)
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
    
    # 步骤 2: 计算总大小并确认
    print_step "步骤 2/3: 计算打包大小"
    
    local total_size=$(du -sh "$RANCHER_DIR" | cut -f1)
    echo -e "${BLUE}预计打包大小: ${total_size}${NC}"
    echo ""
    echo "这包括："
    echo "  - Rancher 源码及 Git 历史"
    echo "  - Go vendor 依赖"
    echo "  - 所有下载的资源文件"
    echo ""
    echo -e "${YELLOW}提示: 如果超过 4.7GB，建议分卷压缩或使用大容量 U 盘${NC}"
    echo ""
    echo -e "${YELLOW}按 Enter 键开始打包，或输入 'q' 退出...${NC}"
    read -r response
    if [[ "$response" == "q" || "$response" == "Q" ]]; then
        echo "用户取消操作"
        exit 0
    fi
    
    # 步骤 3: 执行打包
    print_step "步骤 3/3: 执行打包"
    
    mkdir -p "$OUTPUT_DIR"
    
    echo -e "${BLUE}正在打包 Rancher 项目...${NC}"
    echo -e "${BLUE}输出文件: ${OUTPUT_FILE}${NC}"
    echo ""
    
    # 使用 tar 压缩整个 rancher 目录
    cd "$(dirname "$RANCHER_DIR")"
    tar czf "$OUTPUT_FILE" "$(basename "$RANCHER_DIR")" --checkpoint=.1000 --checkpoint-action=dot
    
    print_success "打包完成！"
    
    # 显示结果
    print_header "打包结果"
    
    echo -e "${GREEN}输出文件:${NC} $OUTPUT_FILE"
    echo -e "${GREEN}文件大小:${NC} $(du -sh "$OUTPUT_FILE" | cut -f1)"
    echo -e "${GREEN}SHA256 校验:${NC}"
    sha256sum "$OUTPUT_FILE" | tee "${OUTPUT_FILE}.sha256"
    echo ""
    
    # 提供传输说明
    print_header "下一步操作"
    
    echo -e "${BLUE}方法 1: 刻录到光盘${NC}"
    echo "  # 对于 4.7GB DVD:"
    echo "  growisofs -dvd-compat -Z /dev/dvd=${OUTPUT_FILE}"
    echo ""
    
    echo -e "${BLUE}方法 2: 复制到 U 盘${NC}"
    echo "  cp ${OUTPUT_FILE} /media/usb/"
    echo "  cp ${OUTPUT_FILE}.sha256 /media/usb/"
    echo ""
    
    echo -e "${BLUE}方法 3: 通过网络传输（如果有临时网络）${NC}"
    echo "  scp ${OUTPUT_FILE} user@offline-machine:/path/to/destination/"
    echo "  scp ${OUTPUT_FILE}.sha256 user@offline-machine:/path/to/destination/"
    echo ""
    
    echo -e "${BLUE}离线机器上的操作:${NC}"
    echo "  # 1. 验证文件完整性"
    echo "  sha256sum -c rancher-offline-*.tar.gz.sha256"
    echo ""
    echo "  # 2. 解压"
    echo "  tar xzf rancher-offline-*.tar.gz"
    echo ""
    echo "  # 3. 进入项目目录"
    echo "  cd rancher/offline-build"
    echo ""
    echo "  # 4. 执行离线构建"
    echo "  ./scripts/04-build-in-offline.sh"
    echo ""
    
    print_success "打包完成！文件已保存到: $OUTPUT_FILE"
}

# 执行主流程
main "$@"
