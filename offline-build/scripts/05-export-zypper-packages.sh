#!/bin/bash
###############################################################################
# 脚本名称: 05-export-zypper-packages.sh
# 用途: 导出 zypper 所需的 RPM 包用于离线安装
# 执行环境: WSL2 Ubuntu-22.04（在联网环境中执行）
# 架构支持: amd64
# 方法: 从阿里云开源镜像站下载 RPM 包（国内访问更快）
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

###############################################################################
# 主函数
###############################################################################

main() {
    print_header "导出 zypper RPM 包用于离线安装（阿里云镜像）"
    
    OFFLINE_BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    OUTPUT_DIR="$OFFLINE_BUILD_DIR/resources/zypper-packages"
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    # 阿里云 openSUSE Leap 15.6 镜像仓库 URL
    ALIYUN_MIRROR="https://mirrors.aliyun.com/opensuse/distribution/leap/15.6/repo/oss/x86_64"
    ALIYUN_UPDATE="https://mirrors.aliyun.com/opensuse/update/leap/15.6/oss/x86_64"
    
    # 需要安装的软件包列表及其对应的 RPM 文件名模式
    declare -A PACKAGES=(
        ["git-core"]="git-core-*"
        ["curl"]="curl-*"
        ["wget"]="wget-*"
        ["tar"]="tar-*"
        ["gzip"]="gzip-*"
        ["unzip"]="unzip-*"
        ["sed"]="sed-*"
        ["gawk"]="gawk-*"
        ["jq"]="jq-*"
        ["iptables"]="iptables-*"
        ["ca-certificates"]="ca-certificates-*"
        ["ca-certificates-mozilla"]="ca-certificates-mozilla-*"
    )
    
    print_step "正在从阿里云开源镜像站下载 RPM 包..."
    echo "镜像地址: $ALIYUN_MIRROR"
    echo ""
    
    local downloaded=0
    local failed=0
    
    for pkg_name in "${!PACKAGES[@]}"; do
        local pattern="${PACKAGES[$pkg_name]}"
        echo "下载: $pkg_name ($pattern)"
        
        # 尝试从主仓库下载
        if wget -q --timeout=30 -P "$OUTPUT_DIR" "${ALIYUN_MIRROR}/${pattern}.rpm" 2>/dev/null; then
            downloaded=$((downloaded + 1))
            echo "  ✓ 成功"
        # 如果失败，尝试从更新仓库下载
        elif wget -q --timeout=30 -P "$OUTPUT_DIR" "${ALIYUN_UPDATE}/${pattern}.rpm" 2>/dev/null; then
            downloaded=$((downloaded + 1))
            echo "  ✓ 成功（从更新仓库）"
        else
            echo "  ✗ 失败，尝试查找最新版本..."
            # 尝试使用 curl 列出目录并找到最新版本
            local latest_rpm=$(curl -s --connect-timeout 10 "${ALIYUN_MIRROR}/" | grep -oP "${pattern//\*/[^\" ]*}" | head -1)
            if [ -n "$latest_rpm" ]; then
                if wget -q --timeout=30 -P "$OUTPUT_DIR" "${ALIYUN_MIRROR}/${latest_rpm}" 2>/dev/null; then
                    downloaded=$((downloaded + 1))
                    echo "  ✓ 成功（找到版本: $latest_rpm）"
                else
                    failed=$((failed + 1))
                    echo "  ✗ 仍然失败"
                fi
            else
                failed=$((failed + 1))
                echo "  ✗ 未找到匹配的 RPM 包"
            fi
        fi
    done
    
    echo ""
    
    # 清理空文件或部分下载的文件
    find "$OUTPUT_DIR" -name "*.rpm.part" -delete 2>/dev/null || true
    find "$OUTPUT_DIR" -empty -delete 2>/dev/null || true
    
    # 统计结果
    local rpm_count=$(ls -1 "$OUTPUT_DIR"/*.rpm 2>/dev/null | wc -l)
    local total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)
    
    print_success "导出完成"
    echo "成功下载: $downloaded 个包"
    echo "失败: $failed 个包"
    echo "RPM 包数量: $rpm_count"
    echo "总大小: $total_size"
    echo "输出目录: $OUTPUT_DIR"
    echo ""
    
    if [ "$rpm_count" -eq 0 ]; then
        print_error "未找到任何 RPM 包！"
        echo "请检查网络连接或尝试其他方法。"
        exit 1
    fi
    
    # 列出所有 RPM 包
    echo "导出的 RPM 包列表:"
    ls -lh "$OUTPUT_DIR"/*.rpm | awk '{print "  - " $9 " (" $5 ")"}'
    
    if [ "$failed" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠ 注意: 有 $failed 个包下载失败${NC}"
        echo "这些可能是基础镜像中已包含的工具（如 tar, gzip, sed 等）"
        echo "可以在 Dockerfile 构建时验证是否需要这些包"
    fi
    
    print_success "RPM 包导出成功！可以打包传输到离线环境了。"
}

# 执行主函数
main "$@"
