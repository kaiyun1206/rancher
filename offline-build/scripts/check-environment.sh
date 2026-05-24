#!/bin/bash
###############################################################################
# 脚本名称: check-environment.sh
# 用途: 检查系统环境是否满足离线编译要求
# 执行环境: WSL2 Ubuntu-22.04
###############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_fail() {
    echo -e "${RED}✗ $1${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    WARN_COUNT=$((WARN_COUNT + 1))
}

# 初始化计数器
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

echo "=========================================="
echo "  Rancher 离线编译环境检查工具"
echo "=========================================="
echo ""

check_item() {
    local description="$1"
    local command="$2"
    
    if eval "$command" &> /dev/null; then
        print_pass "$description"
        return 0
    else
        print_fail "$description"
        return 1
    fi
}

# 1. 检查操作系统
echo "【系统信息】"
if [ -f /etc/os-release ]; then
    source /etc/os-release
    print_info "操作系统: $PRETTY_NAME"
else
    print_warning "无法检测操作系统版本"
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
    print_pass "运行在 WSL2 环境中"
else
    print_warning "未检测到 WSL2 环境（建议在 WSL2 中执行）"
fi
echo ""

# 2. 检查必需命令
echo "【必需工具】"
check_item "git 已安装" "command -v git"
check_item "curl 已安装" "command -v curl"
check_item "wget 已安装" "command -v wget"
check_item "tar 已安装" "command -v tar"
check_item "unzip 已安装" "command -v unzip"
check_item "jq 已安装" "command -v jq"
check_item "docker 已安装" "command -v docker"
check_item "go 已安装" "command -v go"
echo ""

# 3. 检查 Docker 服务
echo "【Docker 服务】"
if sudo docker info &> /dev/null; then
    print_pass "Docker 服务正在运行"
    docker_version=$(sudo docker --version)
    print_info "Docker 版本: $docker_version"
    
    # 检查当前用户是否在 docker 组中
    if groups | grep -q docker; then
        print_pass "当前用户在 docker 组中（无需 sudo）"
    else
        print_warning "当前用户不在 docker 组中，需要使用 sudo 运行 docker 命令"
        print_info "解决方法: 注销并重新登录 WSL2，或执行: newgrp docker"
    fi
else
    print_fail "Docker 服务未运行"
    print_info "启动 Docker: sudo service docker start"
fi
echo ""

# 4. 检查 Go 版本
echo "【Go 环境】"
if command -v go &> /dev/null; then
    go_version=$(go version | awk '{print $3}')
    print_info "Go 版本: $go_version"
    
    # 检查版本是否 >= 1.23
    if go version | grep -qE 'go1\.(2[3-9]|[3-9][0-9])'; then
        print_pass "Go 版本满足要求 (>= 1.23)"
    else
        print_fail "Go 版本过低，需要 >= 1.23"
        print_info "下载地址: https://go.dev/dl/"
    fi
else
    print_fail "Go 未安装"
fi
echo ""

# 5. 检查磁盘空间
echo "【磁盘空间】"
current_dir=$(pwd)
available_space=$(df -BG "$current_dir" | tail -1 | awk '{print $4}' | sed 's/G//')
print_info "当前目录: $current_dir"
print_info "可用空间: ${available_space}GB"

if [ "$available_space" -ge 50 ]; then
    print_pass "磁盘空间充足 (>= 50GB)"
elif [ "$available_space" -ge 20 ]; then
    print_warning "磁盘空间可能不足 (建议 >= 50GB)"
else
    print_fail "磁盘空间严重不足 (< 20GB)"
fi
echo ""

# 6. 检查网络连接（仅在有网络环境需要）
echo "【网络连接】"
if timeout 2 ping -c 1 github.com &> /dev/null; then
    print_pass "可以访问 GitHub"
else
    print_warning "无法访问 GitHub（如果在离线环境，这是正常的）"
fi
echo ""

# 7. 检查项目目录
echo "【项目目录】"
rancher_dir="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -d "$rancher_dir" ]; then
    print_pass "Rancher 项目目录存在"
    print_info "项目路径: $rancher_dir"
    
    # 检查关键文件
    if [ -f "$rancher_dir/go.mod" ]; then
        print_pass "go.mod 文件存在"
    else
        print_fail "go.mod 文件缺失"
    fi
    
    if [ -f "$rancher_dir/Makefile" ]; then
        print_pass "Makefile 文件存在"
    else
        print_fail "Makefile 文件缺失"
    fi
else
    print_fail "Rancher 项目目录不存在"
fi
echo ""

# 8. 检查资源目录（如果已创建）
offline_build_dir="$rancher_dir/offline-build"
if [ -d "$offline_build_dir" ]; then
    echo "【离线构建目录】"
    print_pass "offline-build 目录存在"
    
    resources_dir="$offline_build_dir/resources"
    if [ -d "$resources_dir" ]; then
        resource_size=$(du -sh "$resources_dir" 2>/dev/null | cut -f1)
        print_info "资源目录大小: $resource_size"
    fi
    echo ""
fi

# 总结
echo "=========================================="
echo "  检查结果汇总"
echo "=========================================="
echo -e "${GREEN}通过: $PASS_COUNT${NC}"
echo -e "${RED}失败: $FAIL_COUNT${NC}"
echo -e "${YELLOW}警告: $WARN_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ 环境检查通过！可以开始离线编译流程${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 在有网络的环境中:"
    echo "     cd $offline_build_dir"
    echo "     ./scripts/01-download-resources.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ 环境检查失败，请先解决上述问题${NC}"
    echo ""
    exit 1
fi
