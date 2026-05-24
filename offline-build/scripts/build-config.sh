#!/bin/bash
###############################################################################
# 文件名称: build-config.sh
# 用途: 集中管理所有版本配置和参数
# 说明: 其他脚本可以 source 此文件获取配置
###############################################################################

# Rancher 版本
export RANCHER_VERSION="v2.10.3"
export RANCHER_BRANCH="release-v2.10"

# 架构配置
export ARCH="amd64"
# 如需支持 arm64，改为: export ARCH="arm64"

# Docker 镜像配置
export DOCKER_REGISTRY="rancher"
export DOCKER_TAG="${RANCHER_VERSION}"

# Charts 分支配置
export SYSTEM_CHART_BRANCH="release-v2.10"
export CHARTS_BRANCH="release-v2.10"
export PARTNER_CHARTS_BRANCH="main"
export RKE2_CHARTS_BRANCH="main"

# 二进制工具版本
export CATTLE_MACHINE_VERSION="v0.15.0-rancher125"
export DOCKER_MACHINE_LINODE_VERSION="v0.1.12"
export HARVESTER_DRIVER_VERSION="v0.7.2"
export TINI_VERSION="v0.18.0"
export HELM_V2_VERSION="v2.16.8-rancher2"
export HELM_V3_VERSION="v3.16.1"
export ETCD_VERSION="v3.5.14"
export KUSTOMIZE_VERSION="v5.4.2"
export TELEMETRY_VERSION="v0.6.2"

# Agent 版本
export SYSTEM_AGENT_VERSION="v0.3.11"
export WINS_VERSION="v0.5.0"
export CSI_PROXY_VERSION="v1.1.3"
export CLI_VERSION="v2.10.1"

# UI 版本
export UI_VERSION="2.10.3"
export DASHBOARD_VERSION="v2.10.3"
export API_UI_VERSION="1.1.11"

# KDM 配置
export KDM_BRANCH="release-v2.10"

# Docker 基础镜像
export BCI_MICRO_VERSION="15.6"
export BCI_BASE_VERSION="15.6"
export GOLANG_VERSION="1.23"
export K3S_VERSION="v1.31.1-k3s1"

# Go 配置
export GO_VERSION="1.23"
export GOPROXY_OFFLINE="off"
export GOFLAGS_OFFLINE="-mod=vendor"

# 构建配置
export BUILD_DEBUG="${BUILD_DEBUG:-false}"
export BUILD_CGO_ENABLED="0"

# 目录配置（相对于 offline-build 目录）
export RESOURCES_DIR="resources"
export MODIFIED_FILES_DIR="modified-files"
export DIST_DIR="../dist"

# 网络超时设置（秒）
export CURL_TIMEOUT=300
export GIT_TIMEOUT=600

# 打印配置信息
print_config() {
    echo "=========================================="
    echo "  Rancher 离线编译配置"
    echo "=========================================="
    echo ""
    echo "Rancher 版本: $RANCHER_VERSION"
    echo "架构: $ARCH"
    echo "Docker 镜像: $DOCKER_REGISTRY/rancher:$DOCKER_TAG"
    echo ""
    echo "Charts 分支:"
    echo "  System Charts: $SYSTEM_CHART_BRANCH"
    echo "  Charts: $CHARTS_BRANCH"
    echo "  Partner Charts: $PARTNER_CHARTS_BRANCH"
    echo "  RKE2 Charts: $RKE2_CHARTS_BRANCH"
    echo ""
    echo "关键工具版本:"
    echo "  Machine: $CATTLE_MACHINE_VERSION"
    echo "  Helm v2: $HELM_V2_VERSION"
    echo "  Helm v3: $HELM_V3_VERSION"
    echo "  Etcd: $ETCD_VERSION"
    echo "  System Agent: $SYSTEM_AGENT_VERSION"
    echo ""
    echo "UI 版本:"
    echo "  UI: $UI_VERSION"
    echo "  Dashboard: $DASHBOARD_VERSION"
    echo "  API UI: $API_UI_VERSION"
    echo ""
    echo "Docker 基础镜像:"
    echo "  BCI Micro: $BCI_MICRO_VERSION"
    echo "  BCI Base: $BCI_BASE_VERSION"
    echo "  Golang: $GOLANG_VERSION"
    echo "  K3s: $K3S_VERSION"
    echo ""
    echo "=========================================="
}

# 如果直接执行此脚本，显示配置
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_config
fi
