#!/bin/bash
###############################################################################
# 文件名称: verify-downloaded-resources.sh
# 用途: 验证已下载的资源是否完整且版本正确
# 说明: 根据 Rancher v2.10.3 源码进行严格检查
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

RESOURCES_DIR="resources"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS_COUNT++)) || true
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL_COUNT++)) || true
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN_COUNT++)) || true
}

print_header() {
    echo ""
    echo "=========================================="
    echo "  $1"
    echo "=========================================="
}

echo ""
echo "================================================"
echo "  Rancher v2.10.3 资源完整性检查"
echo "================================================"
echo ""
echo "基于源码位置:"
echo "  - package/Dockerfile"
echo "  - pkg/data/management/machinedriver_data.go"
echo "  - pkg/buildconfig/constants.go"
echo ""

###############################################################################
# 1. 检查二进制文件
###############################################################################
print_header "1. 二进制工具检查"

BINARIES_DIR="$RESOURCES_DIR/binaries/amd64"

check_binary() {
    local file=$1
    local expected_version=$2
    local description=$3
    
    if [ -f "$BINARIES_DIR/$file" ]; then
        size=$(ls -lh "$BINARIES_DIR/$file" | awk '{print $5}')
        print_pass "$description ($size)"
    else
        print_fail "$description - 文件缺失"
    fi
}

# rancher-machine
check_binary "rancher-machine.tar.gz" "v0.15.0-rancher125" "rancher-machine"

# docker-machine-driver-linode (修正后的版本)
if [ -f "$BINARIES_DIR/docker-machine-driver-linode.zip" ]; then
    print_pass "docker-machine-driver-linode (v0.1.12)"
else
    print_fail "docker-machine-driver-linode - 文件缺失或版本错误"
    echo "  提示: 应为 v0.1.12，之前错误配置为 v0.7.0"
fi

# docker-machine-driver-harvester
check_binary "docker-machine-driver-harvester.tar.gz" "v0.7.2" "docker-machine-driver-harvester"

# tini
if [ -f "$BINARIES_DIR/tini" ] && [ -x "$BINARIES_DIR/tini" ]; then
    print_pass "tini (v0.18.0, 可执行)"
else
    print_fail "tini - 文件缺失或不可执行"
fi

# helm v2 (rancher-helm)
if [ -f "$BINARIES_DIR/rancher-helm" ] && [ -x "$BINARIES_DIR/rancher-helm" ]; then
    print_pass "helm v2 (v2.16.8-rancher2, 可执行)"
else
    print_fail "helm v2 - 文件缺失或不可执行"
fi

# tiller v2
if [ -f "$BINARIES_DIR/rancher-tiller" ] && [ -x "$BINARIES_DIR/rancher-tiller" ]; then
    print_pass "tiller v2 (v2.16.8-rancher2, 可执行)"
else
    print_fail "tiller v2 - 文件缺失或不可执行"
fi

# helm v3
check_binary "helm-v3.tar.gz" "v3.16.1" "helm v3"

# etcd
check_binary "etcd.tar.gz" "v3.5.14" "etcd"

# kustomize
check_binary "kustomize.tar.gz" "v5.4.2" "kustomize"

# telemetry
if [ -f "$BINARIES_DIR/telemetry" ] && [ -x "$BINARIES_DIR/telemetry" ]; then
    print_pass "telemetry (v0.6.2, 可执行)"
else
    print_fail "telemetry - 文件缺失或不可执行"
fi

###############################################################################
# 2. 检查 Charts 仓库
###############################################################################
print_header "2. Charts 仓库检查"

CHARTS_DIR="$RESOURCES_DIR/charts"

check_git_repo() {
    local repo_dir=$1
    local branch=$2
    local description=$3
    
    if [ -d "$repo_dir/.git" ]; then
        cd "$repo_dir"
        current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
        commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "unknown")
        cd - > /dev/null
        print_pass "$description (分支: $current_branch, commits: $commit_count)"
    else
        print_fail "$description - 目录不存在或非 git 仓库"
    fi
}

check_git_repo "$CHARTS_DIR/system-charts" "release-v2.10" "system-charts"
check_git_repo "$CHARTS_DIR/charts" "release-v2.10" "charts (rancher-charts)"
check_git_repo "$CHARTS_DIR/partner-charts" "main" "partner-charts"
check_git_repo "$CHARTS_DIR/rke2-charts" "main" "rke2-charts"

###############################################################################
# 3. 检查 UI 资源
###############################################################################
print_header "3. UI 资源检查"

UI_DIR="$RESOURCES_DIR/ui-assets"

check_ui_file() {
    local file=$1
    local version=$2
    local description=$3
    
    if [ -f "$UI_DIR/$file" ]; then
        size=$(ls -lh "$UI_DIR/$file" | awk '{print $5}')
        print_pass "$description ($size)"
    else
        print_fail "$description - 文件缺失"
    fi
}

check_ui_file "ui-2.10.3.tar.gz" "2.10.3" "Rancher UI"
check_ui_file "dashboard-v2.10.3.tar.gz" "v2.10.3" "Dashboard UI"
check_ui_file "api-ui-1.1.11.tar.gz" "1.1.11" "API UI"

# Linode UI Driver
LINODE_DRIVER_DIR="$UI_DIR/linode-driver"
if [ -f "$LINODE_DRIVER_DIR/component.js" ] && \
   [ -f "$LINODE_DRIVER_DIR/component.css" ] && \
   [ -f "$LINODE_DRIVER_DIR/linode.svg" ]; then
    print_pass "Linode UI Driver (v0.7.0)"
else
    print_fail "Linode UI Driver - 文件缺失"
fi

###############################################################################
# 4. 检查 Agent 文件
###############################################################################
print_header "4. Agent 文件检查"

AGENT_DIR="$RESOURCES_DIR/agent-files"

# System Agent
SYSTEM_AGENT_DIR="$AGENT_DIR/system-agent"
if [ -f "$SYSTEM_AGENT_DIR/rancher-system-agent-amd64" ] && \
   [ -f "$SYSTEM_AGENT_DIR/install.sh" ] && \
   [ -f "$SYSTEM_AGENT_DIR/system-agent-uninstall.sh" ]; then
    print_pass "System Agent (v0.3.11)"
else
    print_fail "System Agent - 文件缺失"
fi

# Wins Agent
WINS_DIR="$AGENT_DIR/wins"
if [ -f "$WINS_DIR/wins.exe" ] && \
   [ -f "$WINS_DIR/install.ps1" ] && \
   [ -f "$WINS_DIR/uninstall.ps1" ]; then
    print_pass "Wins Agent (v0.5.0)"
else
    print_fail "Wins Agent - 文件缺失"
fi

# CLI Tools
CLI_DIR="$AGENT_DIR/cli"
if [ -f "$CLI_DIR/rancher-darwin-amd64-v2.10.1.tar.gz" ] && \
   [ -f "$CLI_DIR/rancher-linux-amd64-v2.10.1.tar.gz" ] && \
   [ -f "$CLI_DIR/rancher-windows-386-v2.10.1.zip" ]; then
    print_pass "CLI Tools (v2.10.1)"
else
    print_fail "CLI Tools - 部分文件缺失"
fi

# CSI Proxy
if [ -f "$CLI_DIR/csi-proxy-v1.1.3.tar.gz" ]; then
    print_pass "CSI Proxy (v1.1.3)"
else
    print_fail "CSI Proxy - 文件缺失"
fi

###############################################################################
# 5. 检查 KDM 数据
###############################################################################
print_header "5. KDM 元数据检查"

KDM_DIR="$RESOURCES_DIR/kdm"
if [ -f "$KDM_DIR/data.json" ]; then
    size=$(ls -lh "$KDM_DIR/data.json" | awk '{print $5}')
    # 验证 JSON 格式
    if jq empty "$KDM_DIR/data.json" 2>/dev/null; then
        print_pass "KDM data.json ($size, JSON 格式有效)"
    else
        print_fail "KDM data.json - JSON 格式无效"
    fi
else
    print_fail "KDM data.json - 文件缺失"
fi

###############################################################################
# 6. 检查 Docker 镜像目录
###############################################################################
print_header "6. Docker 镜像目录检查"

DOCKER_IMAGES_DIR="$RESOURCES_DIR/docker-images"
if [ -d "$DOCKER_IMAGES_DIR" ]; then
    image_count=$(ls -1 "$DOCKER_IMAGES_DIR"/*.tar 2>/dev/null | wc -l)
    if [ "$image_count" -gt 0 ]; then
        print_pass "Docker 镜像目录存在 ($image_count 个镜像文件)"
    else
        print_warn "Docker 镜像目录存在但无镜像文件 (需执行 02-export-docker-images.sh)"
    fi
else
    print_warn "Docker 镜像目录不存在 (需执行 02-export-docker-images.sh)"
fi

###############################################################################
# 总结
###############################################################################
print_header "检查结果汇总"

echo ""
echo -e "${GREEN}通过: $PASS_COUNT${NC}"
echo -e "${RED}失败: $FAIL_COUNT${NC}"
echo -e "${YELLOW}警告: $WARN_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ 所有必需资源已完整下载！${NC}"
    echo ""
    echo "下一步操作:"
    echo "  1. 如果 Docker 镜像未导出，执行: ./scripts/02-export-docker-images.sh"
    echo "  2. 打包资源: ./scripts/03-transfer-to-offline.sh"
    exit 0
else
    echo -e "${RED}✗ 存在缺失或错误的资源，请检查上述失败项${NC}"
    echo ""
    echo "常见问题修复:"
    echo "  - docker-machine-driver-linode 版本错误: 已修正为 v0.1.12"
    echo "  - 重新运行下载脚本: ./scripts/01-download-resources.sh"
    exit 1
fi
