#!/bin/bash
###############################################################################
# 脚本名称: quick-package.sh
# 用途: 最简化的 Rancher 项目打包脚本（一行命令完成）
# 执行环境: WSL2 Ubuntu-22.04（联网环境）
# 使用方式: ./quick-package.sh
###############################################################################

set -e

echo "=========================================="
echo "  Rancher 离线编译资源快速打包"
echo "=========================================="
echo ""

# 检查 vendor 目录
RANCHER_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
if [ ! -d "$RANCHER_DIR/vendor" ]; then
    echo "❌ 错误: Go vendor 目录缺失！"
    echo ""
    echo "请先执行: go mod vendor"
    exit 1
fi

# 生成时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="/tmp/rancher-offline-${TIMESTAMP}.tar.gz"

echo "📦 正在打包 Rancher 项目..."
echo "   输出文件: $OUTPUT_FILE"
echo ""

# 直接压缩整个 rancher 目录
cd "$(dirname "$RANCHER_DIR")"
tar czf "$OUTPUT_FILE" "$(basename "$RANCHER_DIR")" --checkpoint=.1000 --checkpoint-action=dot

echo ""
echo "✅ 打包完成！"
echo ""
echo "📊 文件大小: $(du -sh "$OUTPUT_FILE" | cut -f1)"
echo "🔐 SHA256: $(sha256sum "$OUTPUT_FILE" | awk '{print $1}')"
echo ""
echo "📋 下一步操作:"
echo "   1. 将文件复制到 U 盘或刻录到光盘"
echo "   2. 在离线机器上解压: tar xzf rancher-offline-*.tar.gz"
echo "   3. 进入目录: cd rancher/offline-build"
echo "   4. 执行构建: ./scripts/04-build-in-offline.sh"
echo ""
echo "文件位置: $OUTPUT_FILE"
