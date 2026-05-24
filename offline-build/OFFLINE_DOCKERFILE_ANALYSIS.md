# Dockerfile.offline 网络依赖分析与修复方案

## 📋 问题概述

[modified-files/package/Dockerfile.offline](file:///home/szl/code/rancher/offline-build/modified-files/package/Dockerfile.offline) 在离线环境中执行时会**失败**，因为存在网络依赖。

---

## 🔍 详细分析

### ✅ **已正确处理的部分（不需要网络）**

以下部分已经改为使用本地资源（COPY 指令），完全适配离线环境：

1. **二进制工具安装**
   ```dockerfile
   COPY resources/binaries/${ARCH}/rancher-machine.tar.gz /tmp/
   RUN tar xvzf /tmp/rancher-machine.tar.gz -C /usr/bin
   
   COPY resources/binaries/${ARCH}/tini /usr/bin/tini
   COPY resources/binaries/${ARCH}/helm-v3.tar.gz /tmp/
   COPY resources/binaries/${ARCH}/etcd.tar.gz /tmp/
   COPY resources/binaries/${ARCH}/kustomize.tar.gz /tmp/
   ```

2. **Charts 仓库复制**
   ```dockerfile
   COPY resources/charts/system-charts /var/lib/rancher-data/local-catalogs/system-library
   COPY resources/charts/charts /var/lib/rancher-data/local-catalogs/v2/rancher-charts/latest
   COPY resources/charts/partner-charts /var/lib/rancher-data/local-catalogs/v2/rancher-partner-charts/latest
   COPY resources/charts/rke2-charts /var/lib/rancher-data/local-catalogs/v2/rancher-rke2-charts/latest
   ```

3. **UI 资源复制**
   ```dockerfile
   COPY resources/ui-assets/ui-*.tar.gz /usr/share/rancher/ui/
   COPY resources/ui-assets/dashboard-*.tar.gz /usr/share/rancher/ui-dashboard/
   COPY resources/ui-assets/api-ui-*.tar.gz /usr/share/rancher/ui-api/
   ```

4. **Agent 文件复制**
   ```dockerfile
   COPY resources/agent-files/system-agent/* /usr/share/rancher/agent-files/system-agent/
   COPY resources/agent-files/wins/* /usr/share/rancher/agent-files/wins/
   ```

5. **KDM 数据复制**
   ```dockerfile
   COPY resources/kdm/data.json /var/lib/rancher-data/kdm/data.json
   ```

---

### ❌ **需要修复的部分（需要网络）**

#### **问题：zypper 包管理器安装系统依赖**

```dockerfile
# 第 10-22 行
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
```

**为什么需要网络？**
- `zypper` 是 SUSE Linux 的包管理器
- 默认从在线软件仓库下载 RPM 包
- 离线环境中无法访问仓库，会报错：
  ```
  Error: Failed to download metadata for repo 'repo-name'
  Cannot download repomd.xml: Cannot download repodata/repomd.xml
  ```

---

## 🛠️ 解决方案

### **方案 A：预下载 RPM 包（推荐）⭐**

#### **步骤 1：在联网环境导出 RPM 包**

创建脚本 [scripts/05-export-zypper-packages.sh](file:///home/szl/code/rancher/offline-build/scripts/05-export-zypper-packages.sh)：

```bash
#!/bin/bash
# 导出 zypper 所需的 RPM 包用于离线安装

set -e

echo "=== 导出 zypper RPM 包 ==="

# 创建输出目录
OUTPUT_DIR="resources/zypper-packages"
mkdir -p "$OUTPUT_DIR"

# 需要安装的软件包列表
PACKAGES=(
    git-core
    curl
    wget
    tar
    gzip
    unzip
    sed
    gawk
    jq
    iptables
    ca-certificates
    ca-certificates-mozilla
)

echo "正在下载软件包..."
for pkg in "${PACKAGES[@]}"; do
    echo "下载: $pkg"
    # 使用 zypper download-only 模式
    zypper --download-only install -y "$pkg" || true
done

# 查找下载的 RPM 包并复制到输出目录
echo "正在复制 RPM 包到 $OUTPUT_DIR..."
find /var/cache/zypp/packages -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;

# 统计结果
echo ""
echo "✓ 导出完成"
echo "RPM 包数量: $(ls -1 "$OUTPUT_DIR"/*.rpm | wc -l)"
echo "总大小: $(du -sh "$OUTPUT_DIR" | cut -f1)"
echo "输出目录: $OUTPUT_DIR"
```

#### **步骤 2：修改 Dockerfile.offline**

将 zypper install 改为从本地 RPM 包安装：

```dockerfile
# 复制 RPM 包到容器
COPY resources/zypper-packages/*.rpm /tmp/packages/

# 从本地安装 RPM 包（不需要网络）
RUN rpm -ivh --nodeps /tmp/packages/*.rpm && \
    rm -rf /tmp/packages
```

**说明**：
- `rpm -ivh`：安装 RPM 包
- `--nodeps`：忽略依赖检查（基础镜像 bci-base:15.6 已包含大部分系统库）
- 如果某些包有依赖问题，可以逐个安装或调整顺序

---

### **方案 B：使用 bci-base 镜像的完整版本（备选）**

bci-base:15.6 可能已经包含了大部分需要的工具，可以尝试直接使用而不安装额外包。

**测试方法**：
```bash
# 启动容器测试已有工具
docker run -it registry.suse.com/bci/bci-base:15.6 bash
which git curl wget tar gzip unzip sed gawk jq iptables
```

如果大部分工具已存在，只需安装缺少的少数几个。

---

### **方案 C：多阶段构建 + 缓存优化（高级）**

利用 Docker 的多阶段构建特性，在联网环境构建一个包含所有工具的中间镜像，然后在离线环境中使用。

**缺点**：需要预先构建并保存中间镜像，增加了复杂性。

---

## 📊 方案对比

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| **方案 A：预下载 RPM** | • 完全离线<br>• 可控性强<br>• 易于验证 | • 需要额外步骤<br>• 增加约 50-100MB | ⭐⭐⭐⭐⭐ |
| **方案 B：使用基础镜像** | • 简单<br>• 无需额外步骤 | • 可能缺少某些工具<br>• 不确定性强 | ⭐⭐⭐ |
| **方案 C：多阶段构建** | • 灵活<br>• 可复用 | • 复杂度高<br>• 需要管理镜像 | ⭐⭐ |

---

## 🎯 推荐实施方案

### **立即执行：方案 A（预下载 RPM 包）**

#### **执行步骤**

1. **创建导出脚本**
   ```bash
   cd /home/szl/code/rancher/offline-build
   chmod +x scripts/05-export-zypper-packages.sh
   ./scripts/05-export-zypper-packages.sh
   ```

2. **更新打包脚本**
   修改 [03-transfer-to-offline.sh](file:///home/szl/code/rancher/offline-build/scripts/03-transfer-to-offline.sh)，确保包含 zypper-packages 目录

3. **修改 Dockerfile.offline**
   替换 zypper install 为 rpm 安装

4. **测试验证**
   在联网环境测试修改后的 Dockerfile.offline 是否能成功构建

---

## 📝 其他文件的网络依赖检查

### ✅ **build-server-offline**

**状态**：完全适配离线环境

**关键配置**：
```bash
export GOPROXY=off          # 禁用 Go 代理
export GOFLAGS=-mod=vendor  # 使用 vendor 目录
```

**无需修改** ✅

---

### ✅ **package-offline**

**状态**：调用 build-server-offline 和 build-agent，两者都已适配离线环境

**无需修改** ✅

---

### ✅ **build-agent**

**状态**：纯 Go 编译，使用 vendor 目录即可

**无需修改** ✅

---

## 🚀 下一步行动

1. **创建 RPM 导出脚本**
2. **执行导出获取 RPM 包**
3. **修改 Dockerfile.offline**
4. **更新打包脚本包含 RPM 包**
5. **测试离线构建流程**

---

**文档生成时间**: 2026-05-24  
**问题严重性**: 🔴 高（会导致离线构建失败）  
**建议优先级**: 立即处理
