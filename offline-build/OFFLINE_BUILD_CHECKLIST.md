# Rancher 离线编译 - 完整检查清单与操作指南

## ⚠️ **重要提示**

**当前环境断开网络后不能完全模拟离线环境！**

虽然断开网络可以阻止新的网络连接，但离线编译还需要满足以下关键条件：

---

## 📋 **离线编译前置条件检查清单**

### ✅ **必须完成的准备工作（在联网环境中）**

#### 1. Go vendor 目录准备
```bash
cd /home/szl/code/rancher
go mod tidy
go mod vendor
```

**验证方法**:
```bash
ls -lh /home/szl/code/rancher/vendor/ | head -20
du -sh /home/szl/code/rancher/vendor/
# 预期输出: ~800MB
```

**❌ 如果缺少 vendor 目录**: 离线编译会立即失败，错误信息类似：
```
go: github.com/rancher/norman@v0.0.0-xxx: missing go.sum entry
```

---

#### 2. Docker 基础镜像导出
```bash
cd /home/szl/code/rancher/offline-build
./scripts/02-export-docker-images.sh
```

**验证方法**:
```bash
ls -lh resources/docker-images/*.tar
# 应该看到 4 个 .tar 文件：
# - bci-base-15.6.tar
# - bci-micro-15.6.tar  
# - golang-1.23.tar
# - k3s-v1.31.1-k3s1.tar
```

**❌ 如果缺少镜像文件**: Docker build 时会失败，错误信息：
```
ERROR: pull access denied, repository does not exist or may require authentication
```

---

#### 3. Zypper RPM 包导出
```bash
./scripts/05-export-zypper-packages.sh
```

**验证方法**:
```bash
ls -lh resources/zypper-packages/*.rpm
# 应该看到 8 个 RPM 包
du -sh resources/zypper-packages/
# 预期输出: ~8MB
```

**❌ 如果缺少 RPM 包**: Dockerfile.offline 构建时会失败（已修复为使用本地 RPM）

---

#### 4. 所有静态资源下载
```bash
./scripts/01-download-resources.sh
```

**验证方法**:
```bash
./scripts/verify-downloaded-resources.sh
```

**必需的资源包括**:
- ✅ Binary 工具（rancher-machine, helm, etcd, kustomize 等）
- ✅ Charts 仓库（system-charts, charts, partner-charts, rke2-charts）
- ✅ UI 资源（ui, dashboard, api-ui, linode-driver）
- ✅ Agent 文件（system-agent, wins, cli tools）
- ✅ KDM data.json

---

#### 5. 打包传输到离线环境
```bash
./scripts/quick-package.sh
# 或手动执行
cd /home/szl/code
tar czf rancher-offline-package.tar.gz rancher/
```

**输出文件**: `/tmp/rancher-offline-YYYYMMDD_HHMMSS.tar.gz` (~2.5GB)

---

### ✅ **离线环境中的操作步骤**

#### 步骤 1: 解压资源包
```bash
# 在离线机器上
tar xzf rancher-offline-package.tar.gz
cd rancher/offline-build
```

---

#### 步骤 2: 加载 Docker 镜像（关键！）
```bash
# 脚本会自动执行，也可以手动执行
for img in resources/docker-images/*.tar; do
    echo "加载: $img"
    docker load -i "$img"
done

# 验证镜像是否加载成功
docker images | grep -E "(bci-base|bci-micro|golang|k3s)"
```

**预期输出**:
```
registry.suse.com/bci/bci-base      15.6    xxx   xxx MB
registry.suse.com/bci/bci-micro     15.6    xxx   xxx MB
registry.suse.com/bci/golang        1.23    xxx   xxx MB
rancher/k3s                         v1.31.1-k3s1  xxx MB
```

**❌ 如果未加载镜像**: Docker build 会失败！

---

#### 步骤 3: 验证 Go 环境
```bash
go version
# 预期输出: go version go1.23.x linux/amd64

# 检查 vendor 目录
ls vendor/ | head -10
# 应该能看到很多依赖包目录
```

---

#### 步骤 4: 执行离线构建
```bash
./scripts/04-build-in-offline.sh
```

该脚本会自动完成以下步骤：
1. ✅ 检查离线环境（Docker、Go、磁盘空间）
2. ✅ 加载 Docker 基础镜像
3. ✅ 替换为离线版本文件（Dockerfile.offline, build-server-offline）
4. ✅ 设置 Go 编译环境（GOPROXY=off, GOFLAGS=-mod=vendor）
5. ✅ 编译 Rancher 二进制文件
6. ✅ 构建 Docker 镜像
7. ✅ 生成最终安装包

---

## 🔍 **当前环境状态检查**

让我帮你检查当前环境是否满足离线编译条件：

### 检查项 1: vendor 目录
```bash
if [ -d "/home/szl/code/rancher/vendor" ]; then
    echo "✅ vendor 目录存在"
    du -sh /home/szl/code/rancher/vendor/
else
    echo "❌ vendor 目录缺失！需要执行: go mod vendor"
fi
```

### 检查项 2: Docker 镜像
```bash
echo "=== 已加载的 Docker 镜像 ==="
docker images | grep -E "(bci-base|bci-micro|golang|k3s)" || echo "❌ 未找到必需的 Docker 镜像"

echo ""
echo "=== 导出的镜像文件 ==="
ls -lh /home/szl/code/rancher/offline-build/resources/docker-images/*.tar 2>/dev/null || echo "❌ 未找到导出的镜像文件"
```

### 检查项 3: RPM 包
```bash
echo "=== Zypper RPM 包 ==="
ls -lh /home/szl/code/rancher/offline-build/resources/zypper-packages/*.rpm 2>/dev/null | wc -l
echo "个 RPM 包"
```

### 检查项 4: 其他资源
```bash
echo "=== 资源完整性 ==="
./scripts/verify-downloaded-resources.sh
```

---

## 🎯 **结论与建议**

### ❌ **当前环境不能直接执行离线编译的原因**

1. **Docker 镜像可能未加载**
   - 虽然有 `.tar` 文件，但需要先 `docker load` 导入
   - 离线构建脚本会自动执行这一步

2. **Dockerfile.offline 已修复** ✅
   - 之前使用 `zypper install`（需要网络）
   - 现已改为使用本地 RPM 包（完全离线）

3. **vendor 目录可能存在**
   - 需要验证是否存在且完整

---

### ✅ **推荐操作流程**

#### **方案 A: 在当前环境测试（不断网）**

如果你想先测试流程是否正确：

```bash
cd /home/szl/code/rancher/offline-build

# 1. 先验证资源完整性
./scripts/verify-downloaded-resources.sh

# 2. 加载 Docker 镜像（如果还没加载）
for img in resources/docker-images/*.tar; do
    docker load -i "$img"
done

# 3. 执行离线构建
./scripts/04-build-in-offline.sh
```

**优点**: 
- 可以快速发现问题并修复
- 如果失败可以从网络下载缺失资源

**缺点**:
- 不是真正的离线环境
- 某些网络依赖可能被忽略

---

#### **方案 B: 真正的离线测试（断网）**

如果你想在真正的离线环境中测试：

```bash
# 1. 确保所有准备工作已完成
cd /home/szl/code/rancher
go mod vendor  # 如果 vendor 不存在

cd offline-build
./scripts/verify-downloaded-resources.sh  # 验证资源

# 2. 打包
./scripts/quick-package.sh

# 3. 断开网络
sudo ip link set eth0 down  # WSL2 中可能是其他接口名

# 4. 验证网络已断开
ping -c 1 8.8.8.8  # 应该失败

# 5. 执行离线构建
./scripts/04-build-in-offline.sh
```

**优点**:
- 真实的离线环境测试
- 能发现所有网络依赖问题

**缺点**:
- 如果失败，排查和修复较困难
- 需要重新连接网络来下载缺失资源

---

## 📊 **快速检查命令**

运行以下命令快速检查当前状态：

```bash
cd /home/szl/code/rancher/offline-build

echo "=== 1. Vendor 目录 ==="
[ -d "../vendor" ] && echo "✅ 存在 ($(du -sh ../vendor | cut -f1))" || echo "❌ 缺失"

echo ""
echo "=== 2. Docker 镜像文件 ==="
ls resources/docker-images/*.tar 2>/dev/null | wc -l
echo "个镜像文件"

echo ""
echo "=== 3. 已加载的 Docker 镜像 ==="
docker images | grep -E "(bci-base|bci-micro|golang|k3s)" | wc -l
echo "个镜像已加载"

echo ""
echo "=== 4. RPM 包 ==="
ls resources/zypper-packages/*.rpm 2>/dev/null | wc -l
echo "个 RPM 包"

echo ""
echo "=== 5. 其他资源 ==="
[ -d "resources/binaries" ] && echo "✅ binaries" || echo "❌ binaries"
[ -d "resources/charts" ] && echo "✅ charts" || echo "❌ charts"
[ -d "resources/ui-assets" ] && echo "✅ ui-assets" || echo "❌ ui-assets"
[ -d "resources/agent-files" ] && echo "✅ agent-files" || echo "❌ agent-files"
[ -f "resources/kdm/data.json" ] && echo "✅ kdm/data.json" || echo "❌ kdm/data.json"

echo ""
echo "=== 6. Dockerfile.offline 检查 ==="
grep -q "zypper.*install" modified-files/package/Dockerfile.offline && \
    echo "❌ 仍使用 zypper install（需要网络）" || \
    echo "✅ 已使用本地 RPM 包（完全离线）"
```

---

## 🚀 **最终建议**

### **我的建议：先在联网环境测试，确认无误后再断网**

1. **第一步**: 验证所有资源已准备好
   ```bash
   ./scripts/verify-downloaded-resources.sh
   ```

2. **第二步**: 加载 Docker 镜像
   ```bash
   for img in resources/docker-images/*.tar; do
       docker load -i "$img"
   done
   ```

3. **第三步**: 尝试执行离线构建（联网状态下）
   ```bash
   ./scripts/04-build-in-offline.sh
   ```

4. **第四步**: 如果成功，再断网进行真正的离线测试

这样可以最大程度减少问题，提高成功率！

---

**最后更新**: 2026-05-24  
**适用版本**: Rancher v2.10.3
