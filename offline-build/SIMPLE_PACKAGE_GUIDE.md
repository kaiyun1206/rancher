# Rancher 离线编译 - 简化打包方案

## 📋 概述

本方案采用**直接压缩整个 Rancher 项目目录**的方式，比原有的复杂打包脚本更简单、更高效。

### 优势

✅ **简单高效**：一条命令完成打包  
✅ **完整性保证**：包含所有必需文件  
✅ **减少出错**：避免遗漏关键文件  
✅ **易于维护**：无需维护复杂的打包逻辑  

---

## 🚀 快速开始

### 方法一：使用快速打包脚本（推荐）

```bash
cd /home/szl/code/rancher/offline-build
./scripts/quick-package.sh
```

### 方法二：手动执行（最简单）

```bash
cd /home/szl/code
tar czf rancher-offline-package.tar.gz rancher/
```

### 方法三：使用完整打包脚本（带检查）

```bash
cd /home/szl/code/rancher/offline-build
./scripts/03-transfer-to-offline.sh
```

---

## 📦 打包内容

压缩包包含以下内容：

```
rancher/
├── .git/                    # Git 历史记录（可选但建议保留）
├── vendor/                  # Go 依赖包（关键！）
├── go.mod                   # Go 模块定义
├── go.sum                   # Go 依赖校验
├── main.go                  # 主程序入口
├── pkg/                     # 核心代码
├── offline-build/           # 离线构建资源
│   ├── resources/
│   │   ├── docker-images/   # Docker 基础镜像 (*.tar)
│   │   ├── binaries/        # 二进制工具
│   │   ├── charts/          # Helm Charts 仓库
│   │   ├── ui-assets/       # UI 资源
│   │   ├── agent-files/     # Agent 文件
│   │   └── zypper-packages/ # RPM 系统依赖包
│   ├── scripts/             # 自动化脚本
│   └── modified-files/      # 离线版配置文件
└── ...                      # 其他项目文件
```

---

## 📊 文件大小预估

| 组件 | 大小 |
|------|------|
| Rancher 源码 + .git | ~1.5 GB |
| Go vendor 依赖 | ~800 MB |
| Docker 基础镜像 | ~500 MB |
| Binary 工具 | ~200 MB |
| Charts 仓库 | ~300 MB |
| UI 资源 | ~100 MB |
| 其他资源 | ~100 MB |
| **总计** | **~3.5 GB** |

> 💡 **提示**：适合单张 4.7GB DVD 光盘或普通 U 盘传输

---

## 💿 传输到离线机器

### 方法 1: 刻录到 DVD 光盘

```bash
# 检查光盘设备
lsblk | grep sr0

# 刻录到光盘
growisofs -dvd-compat -Z /dev/sr0=/tmp/rancher-offline-*.tar.gz
```

### 方法 2: 复制到 U 盘

```bash
# 挂载 U 盘后复制
cp /tmp/rancher-offline-*.tar.gz /media/usb/
cp /tmp/rancher-offline-*.sha256 /media/usb/  # 如果有校验文件
```

### 方法 3: 通过网络传输（临时网络）

```bash
# 使用 scp
scp /tmp/rancher-offline-*.tar.gz user@offline-machine:/path/to/destination/

# 或使用 rsync
rsync -avP /tmp/rancher-offline-*.tar.gz user@offline-machine:/path/to/destination/
```

---

## 🔧 离线机器上的操作

### 步骤 1: 验证文件完整性

```bash
# 如果有 SHA256 校验文件
sha256sum -c rancher-offline-*.tar.gz.sha256

# 或手动计算并对比
sha256sum rancher-offline-*.tar.gz
```

### 步骤 2: 解压文件

```bash
# 选择合适的目录解压（确保有足够空间）
cd /path/to/destination
tar xzf rancher-offline-*.tar.gz
```

### 步骤 3: 进入离线构建目录

```bash
cd rancher/offline-build
```

### 步骤 4: 执行离线构建

```bash
# 运行离线构建脚本
./scripts/04-build-in-offline.sh
```

该脚本会自动：
- ✅ 加载 Docker 基础镜像
- ✅ 安装 Go 编译环境
- ✅ 使用 vendor 目录编译 Rancher
- ✅ 构建 Docker 镜像
- ✅ 生成最终的 Rancher 安装包

---

## ⚠️ 注意事项

### 打包前必须完成的准备

1. **生成 Go vendor 目录**（关键！）
   ```bash
   cd /home/szl/code/rancher
   go mod tidy
   go mod vendor
   ```

2. **导出 Docker 基础镜像**
   ```bash
   cd /home/szl/code/rancher/offline-build
   ./scripts/02-export-docker-images.sh
   ```

3. **导出 zypper RPM 包**（可选但推荐）
   ```bash
   ./scripts/05-export-zypper-packages.sh
   ```

4. **验证资源完整性**
   ```bash
   ./scripts/verify-downloaded-resources.sh
   ```

### 常见问题

#### Q1: 打包文件太大，超过 4.7GB？

**解决方案 A**: 排除大型 Docker 镜像，单独传输
```bash
# 打包源码（不含 Docker 镜像）
tar czf rancher-code.tar.gz \
  --exclude='rancher/offline-build/resources/docker-images/*.tar' \
  rancher/

# 单独打包 Docker 镜像
tar czf rancher-docker-images.tar.gz \
  -C rancher/offline-build/resources docker-images/
```

**解决方案 B**: 使用分卷压缩
```bash
# 分割成多个 4GB 的文件
split -b 4G rancher-offline-package.tar.gz rancher-offline-part-
# 在离线机器上合并
cat rancher-offline-part-* > rancher-offline-package.tar.gz
```

#### Q2: 离线构建时提示缺少 vendor 目录？

**原因**: 打包前未执行 `go mod vendor`

**解决**: 
1. 返回联网环境
2. 执行 `go mod vendor`
3. 重新打包

#### Q3: Docker 镜像加载失败？

**检查**:
```bash
# 确认镜像文件存在
ls -lh rancher/offline-build/resources/docker-images/*.tar

# 手动加载测试
docker load -i rancher/offline-build/resources/docker-images/bci-base-15.6.tar
```

---

## 📝 对比：简化方案 vs 原方案

| 特性 | 简化方案 | 原方案 (03-transfer-to-offline.sh) |
|------|---------|-----------------------------------|
| 复杂度 | ⭐ 极简 | ⭐⭐⭐⭐ 复杂 |
| 打包时间 | ~5 分钟 | ~10-15 分钟 |
| 出错概率 | 低 | 中等 |
| 维护成本 | 低 | 高 |
| 灵活性 | 中 | 高 |
| 适用场景 | 通用场景 | 需要精细控制的场景 |

**建议**: 大多数情况下使用简化方案即可，只有在需要特殊定制时才使用原方案。

---

## 🎯 总结

### 最简操作流程

```bash
# === 联网环境 ===
cd /home/szl/code/rancher
go mod vendor                                    # 生成依赖
cd offline-build
./scripts/02-export-docker-images.sh            # 导出镜像
./scripts/quick-package.sh                       # 一键打包

# === 传输到离线机器 ===
# （通过光盘/U盘/网络）

# === 离线环境 ===
tar xzf rancher-offline-*.tar.gz                 # 解压
cd rancher/offline-build
./scripts/04-build-in-offline.sh                 # 构建
```

就这么简单！🎉

---

**最后更新**: 2026-05-24  
**适用版本**: Rancher v2.10.3  
**作者**: Rancher 离线编译项目组
