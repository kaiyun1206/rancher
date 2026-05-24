#!/bin/bash
###############################################################################
# 脚本名称: cleanup.sh
# 用途: 清理离线编译过程中产生的临时文件和缓存
# 执行环境: WSL2 Ubuntu-22.04
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

confirm_action() {
    echo -e "${YELLOW}警告: 此操作将删除以下文件/目录:${NC}"
    echo "$1"
    echo ""
    echo -e "${YELLOW}按 Enter 键继续，或输入 'q' 退出...${NC}"
    read -r response
    if [[ "$response" == "q" || "$response" == "Q" ]]; then
        echo "操作已取消"
        exit 0
    fi
}

RANCHER_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

print_header "Rancher 离线编译清理工具"

echo "请选择要清理的内容:"
echo "1. Go 构建缓存和模块缓存"
echo "2. Docker 未使用的镜像、容器、卷"
echo "3. 临时文件 (/tmp 中的相关文件)"
echo "4. 编译输出文件 (dist/*.tar)"
echo "5. 所有上述内容"
echo "6. 仅检查（不删除）"
echo ""
echo -n "请输入选项 [1-6]: "
read -r choice

case $choice in
    1)
        confirm_action "Go 缓存文件"
        
        print_step "清理 Go 构建缓存..."
        go clean -cache -testcache -fuzzcache -modcache
        print_success "Go 缓存已清理"
        
        # 显示释放的空间
        echo "Go 缓存目录: $(go env GOCACHE)"
        echo "Go 模块目录: $(go env GOMODCACHE)"
        ;;
    
    2)
        confirm_action "Docker 未使用的资源"
        
        print_step "清理 Docker 系统..."
        docker system prune -a -f --volumes
        print_success "Docker 资源已清理"
        ;;
    
    3)
        confirm_action "/tmp 中的离线编译临时文件"
        
        print_step "清理临时文件..."
        rm -rf /tmp/offline-build-package 2>/dev/null || true
        rm -f /tmp/rancher-offline-package.tar.gz 2>/dev/null || true
        rm -f /tmp/rancher-offline-package.sha256 2>/dev/null || true
        print_success "临时文件已清理"
        ;;
    
    4)
        confirm_action "dist 目录中的所有 tar 文件"
        
        print_step "清理编译输出..."
        if [ -d "$RANCHER_DIR/dist" ]; then
            rm -f "$RANCHER_DIR/dist"/*.tar
            print_success "编译输出文件已清理"
        else
            echo "dist 目录不存在，跳过"
        fi
        ;;
    
    5)
        confirm_action "所有缓存、临时文件和编译输出"
        
        print_step "执行全面清理..."
        
        echo "[1/4] 清理 Go 缓存..."
        go clean -cache -testcache -fuzzcache -modcache
        
        echo "[2/4] 清理 Docker 资源..."
        docker system prune -a -f --volumes
        
        echo "[3/4] 清理临时文件..."
        rm -rf /tmp/offline-build-package 2>/dev/null || true
        rm -f /tmp/rancher-offline-package.tar.gz 2>/dev/null || true
        rm -f /tmp/rancher-offline-package.sha256 2>/dev/null || true
        
        echo "[4/4] 清理编译输出..."
        rm -f "$RANCHER_DIR/dist"/*.tar 2>/dev/null || true
        
        print_success "全面清理完成"
        ;;
    
    6)
        print_header "磁盘使用情况检查"
        
        echo "【Go 缓存】"
        echo "  GOCACHE: $(go env GOCACHE)"
        if [ -d "$(go env GOCACHE)" ]; then
            echo "  大小: $(du -sh "$(go env GOCACHE)" | cut -f1)"
        fi
        echo ""
        
        echo "【Go 模块】"
        echo "  GOMODCACHE: $(go env GOMODCACHE)"
        if [ -d "$(go env GOMODCACHE)" ]; then
            echo "  大小: $(du -sh "$(go env GOMODCACHE)" | cut -f1)"
        fi
        echo ""
        
        echo "【Docker】"
        docker system df
        echo ""
        
        echo "【临时文件】"
        ls -lh /tmp/rancher-offline-* 2>/dev/null || echo "  无相关临时文件"
        echo ""
        
        echo "【编译输出】"
        if [ -d "$RANCHER_DIR/dist" ]; then
            ls -lh "$RANCHER_DIR/dist"/*.tar 2>/dev/null || echo "  无编译输出文件"
        else
            echo "  dist 目录不存在"
        fi
        echo ""
        
        echo "【项目目录总大小】"
        du -sh "$RANCHER_DIR"
        ;;
    
    *)
        echo "无效选项"
        exit 1
        ;;
esac

print_header "清理完成"

echo -e "${GREEN}清理操作已完成！${NC}"
echo ""
echo "提示:"
echo "- 定期清理可以释放磁盘空间"
echo "- 建议在每次完整编译流程后执行清理"
echo "- 如需重新编译，保留 resources/ 目录可避免重复下载"
