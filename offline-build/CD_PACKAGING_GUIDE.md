# Rancher v2.10.3 光盘打包完整指南

## 📋 方案概述

### 打包策略：完整项目打包（单压缩包）

**设计理念**：
- ✅ **不排除任何文件和目录**：完整保留 Rancher 项目结构
- ✅ **包含 .git 目录**：离线环境可查看所有分支、标签和历史
- ✅ **单压缩包方案**：所有内容打包为一个文件，简化传输和验证
- ✅ **适合光盘刻录**：总大小约 3.0 GB < 4.7 GB 光盘容量

---

## 📊 资源大小分析

### 当前资源统计（2026-05-24）

| 组件 | 大小 | 说明 |
|------|------|------|
| Rancher 源码（含 .git） | ~837 MB | 包括所有分支、标签、历史 |
| ├─ 源码文件 | ~657 MB | 不含 .git |
| ├─ .git 目录 | ~180 MB | Git 对象数据库 |
| Go vendor/ | ~622 MB | Go 模块依赖（32,781 文件） |
| resources/ | ~2.3 GB | 下载的所有资源 |
| ├─ charts/ | ~1.7 GB | Helm Charts 仓库 |
| ├─ docker-images/ | ~305 MB | Docker 基础镜像 |
| ├─ binaries/ | ~175 MB | 二进制工具 |
| ├─ agent-files/ | ~143 MB | Agent 文件 |
| ├─ ui-assets/ | ~30 MB | UI 资源 |
| ├─ kdm/ | ~14 MB | KDM 元数据 |
| modified-files/ | ~12 KB | 离线配置文件 |
| go.mod + go.sum | ~172 KB | Go 模块配置 |
| offline-build 脚本 | ~500 KB | 构建脚本和文档 |
| **总计** | **~3.8 GB** | **压缩前** |
| **压缩后预计** | **~3.0 GB** | **tar.gz 格式** |

### 光盘容量对比

```
光盘容量:        4.7 GB (4,700 MB)
压缩包大小:      ~3.0 GB (3,000 MB)
剩余空间:        ~1.7 GB (1,700 MB)
使用率:          ~64%
```

✅ **结论**：完全可以放入单张 DVD 光盘，且有充足余量。

---

## 🎯 为什么包含 .git 目录？

### .git 目录的价值

1. **完整的版本控制信息**
   - 所有远程分支引用（remotes/origin/*）
   - 所有标签（v2.10.3, v2.10.8, v2.10.9 等）
   - 完整的提交历史和差异

2. **离线环境的灵活性**
   ```bash
   # 可以执行的操作
   git branch -a              # 查看所有分支
   git tag                    # 查看所有标签
   git log --oneline          # 查看提交历史
   git diff v2.10.3 v2.10.8   # 比较版本差异
   git checkout v2.10.8       # 切换到其他版本
   
   # 无法执行的操作（需要网络）
   git pull                   # ✗
   git push                   # ✗
   git fetch                  # ✗
   ```

3. **成本效益高**
   - .git 只有 180 MB，占总容量的 3.8%
   - 提供了巨大的功能价值
   - 符合"不排除任何目录"的需求

4. **开发和调试便利**
   - 可以查看代码演进历史
   - 可以追溯 bug 的引入时间
   - 可以对比不同版本的实现差异

---

## 🛠️ 打包流程详解

### 步骤 1: 在线环境准备

```bash
# 1. 进入项目根目录
cd /home/szl/code/rancher

# 2. 确保 Go 依赖已下载
go mod tidy
go mod vendor

# 3. 进入离线构建目录
cd offline-build

# 4. 下载所有资源（如果还未完成）
./scripts/01-download-resources.sh
./scripts/02-export-docker-images.sh
```

### 步骤 2: 执行打包脚本

```bash
# 执行打包脚本
chmod +x scripts/03-transfer-to-offline.sh
./scripts/03-transfer-to-offline.sh
```

**脚本执行流程**：

1. **检查资源完整性**（步骤 1/4）
   - 验证 resources/ 目录的 7 个子目录
   - 验证 Docker 镜像文件
   - 验证 vendor/ 目录
   - 验证 go.mod 和 go.sum
   - 验证 Rancher 源码存在
   - 检查 .git 目录（可选但建议）

2. **准备离线版本文件**（步骤 2/4）
   - 创建 Dockerfile.offline
   - 创建 build-server-offline
   - 创建 package-offline

3. **打包所有资源**（步骤 3/4）
   - 复制整个 Rancher 项目到临时目录
   - 复制 resources/ 到 rancher/offline-build/resources/
   - 复制 modified-files/ 到 rancher/offline-build/modified-files/
   - 创建 README 说明文件
   - 压缩为 tar.gz 格式
   - 生成 SHA256 校验和

4. **显示结果**（步骤 4/4）
   - 显示文件大小
   - 显示校验和
   - 提供光盘刻录说明

**预计输出**：
```
输出文件: /tmp/rancher-offline-package.tar.gz
校验和文件: /tmp/rancher-offline-package.sha256
文件大小: ~3.0 GB
预计耗时: 15-25 分钟
```

### 步骤 3: 刻录到光盘

#### Windows 系统

**方法 1: 使用 ImgBurn（推荐）**

1. 下载安装 ImgBurn: https://www.imgburn.com/
2. 插入空白 DVD 光盘
3. 打开 ImgBurn，选择"Write files/folders to disc"
4. 添加以下文件：
   - `/tmp/rancher-offline-package.tar.gz`
   - `/tmp/rancher-offline-package.sha256`
5. 设置刻录参数：
   - Destination: 选择光驱
   - Write Speed: 4x 或 8x（更稳定）
   - Verification: ✓ 启用验证
6. 点击"Build"开始刻录

**方法 2: 使用 Nero Burning ROM**

1. 打开 Nero，选择"Data Disc"
2. 添加文件
3. 设置刻录速度为 4x
4. 点击"Burn"

**方法 3: Windows 内置功能**

1. 插入光盘
2. 访问 `\\wsl$\Ubuntu-22.04\tmp\`
3. 右键文件 → "发送到" → "DVD RW 驱动器"
4. 按照向导完成

#### Linux 系统

**方法 1: 使用 Brasero（图形界面）**

```bash
sudo apt install brasero
brasero
```

**方法 2: 使用 wodim（命令行）**

```bash
# 安装刻录工具
sudo apt install wodim

# 查找光驱设备
wodim --devices

# 刻录文件
sudo wodim -v dev=/dev/cdrom speed=4 \
    /tmp/rancher-offline-package.tar.gz \
    /tmp/rancher-offline-package.sha256

# 验证刻录
sudo mount /dev/cdrom /mnt
ls -lh /mnt/
sha256sum -c /mnt/rancher-offline-package.sha256
sudo umount /mnt
```

### 步骤 4: 验证光盘

```bash
# 挂载光盘
sudo mount /dev/cdrom /mnt

# 检查文件
ls -lh /mnt/

# 验证完整性
cd /mnt
sha256sum -c rancher-offline-package.sha256

# 卸载光盘
sudo umount /mnt
```

---

## 📦 压缩包内容结构

```
rancher-offline-package.tar.gz
└── rancher/                          # 完整的 Rancher 项目
    ├── .git/                         # ⭐ Git 仓库（所有分支、标签、历史）
    │   ├── objects/
    │   ├── refs/
    │   ├── HEAD
    │   └── config
    ├── vendor/                       # ⭐ Go 模块依赖（622MB）
    │   ├── github.com/
    │   ├── k8s.io/
    │   └── modules.txt
    ├── go.mod                        # Go 模块定义
    ├── go.sum                        # Go 校验和
    ├── main.go                       # 入口文件
    ├── cmd/                          # 源代码
    ├── pkg/                          # 源代码
    ├── scripts/                      # 构建脚本
    ├── package/                      # Docker 配置
    ├── chart/                        # Helm Chart
    ├── offline-build/                # 离线构建目录
    │   ├── resources/                # ⭐ 下载的资源（2.3GB）
    │   │   ├── docker-images/        # Docker 镜像
    │   │   ├── binaries/             # 二进制工具
    │   │   ├── charts/               # Helm Charts
    │   │   ├── ui-assets/            # UI 资源
    │   │   ├── agent-files/          # Agent 文件
    │   │   └── kdm/                  # KDM 数据
    │   ├── modified-files/           # 离线配置文件
    │   │   ├── package/
    │   │   │   └── Dockerfile.offline
    │   │   └── scripts/
    │   │       ├── build-server-offline
    │   │       └── package-offline
    │   ├── scripts/                  # 构建脚本
    │   │   ├── 01-download-resources.sh
    │   │   ├── 02-export-docker-images.sh
    │   │   ├── 03-transfer-to-offline.sh
    │   │   └── 04-build-in-offline.sh
    │   ├── README.md                 # 完整指南
    │   ├── QUICKSTART.md             # 快速开始
    │   └── OFFLINE-BUILD-README.txt  # 使用说明
    └── ...                           # 所有其他文件和目录
```

---

## 🔍 离线环境使用指南

### 解压和验证

```bash
# 1. 从光盘复制
sudo mount /dev/cdrom /mnt
cp /mnt/rancher-offline-package.tar.gz /tmp/
cp /mnt/rancher-offline-package.sha256 /tmp/
sudo umount /mnt

# 2. 验证完整性
cd /tmp
sha256sum -c rancher-offline-package.sha256

# 3. 解压
tar xzf /tmp/rancher-offline-package.tar.gz -C /home/szl/code/

# 4. 验证解压结果
cd /home/szl/code/rancher

# 检查源码
ls -la main.go

# 检查 .git
git branch -a | head -10
git tag | grep v2.10

# 检查 vendor
du -sh vendor/

# 检查 resources
du -sh offline-build/resources/
```

### Git 功能演示

```bash
# 查看所有分支
git branch -a
# 输出示例:
#   main
# * v2.10.3.1
#   remotes/origin/main
#   remotes/origin/release-v2.10
#   ...

# 查看所有标签
git tag | grep v2.10
# 输出示例:
#   v2.10.0
#   v2.10.1
#   v2.10.2
#   v2.10.3
#   v2.10.8
#   v2.10.9

# 切换到其他版本
git checkout v2.10.8

# 查看提交历史
git log --oneline | head -20

# 比较版本差异
git diff v2.10.3 v2.10.8 --stat

# 返回原分支
git checkout v2.10.3.1
```

### 执行离线编译

```bash
cd /home/szl/code/rancher/offline-build
./scripts/04-build-in-offline.sh
```

---

## ⚠️ 注意事项

### 光盘刻录建议

1. **光盘类型**
   - 推荐使用 DVD-R 或 DVD+R（一次性写入）
   - 避免使用 DVD-RW（可重写，稳定性较差）

2. **刻录速度**
   - 建议使用 4x 或 8x 速度
   - 高速刻录（16x）可能导致读取错误

3. **验证刻录**
   - 始终启用刻录验证功能
   - 刻录完成后重新读取校验和

4. **存储条件**
   - 避免阳光直射
   - 避免高温高湿环境
   - 垂直存放，避免弯曲

### 常见问题

**Q1: 压缩包超过 4.7GB 怎么办？**

A: 当前设计约 3.0 GB，远低于光盘容量。如果未来增长：
- 清理不必要的文件（如 dist/、build/）
- 考虑拆分为多个压缩包
- 使用双层 DVD（8.5GB）

**Q2: 离线环境需要查看其他分支的代码怎么办？**

A: 直接使用 Git 命令：
```bash
git checkout <branch-name>  # 切换分支
git checkout <tag>          # 切换标签
```

**Q3: 能否在离线环境执行 git pull？**

A: 不能。git pull/push/fetch 需要网络连接。但本地 Git 操作（checkout、log、diff 等）完全可用。

**Q4: 光盘读取速度慢怎么办？**

A: 建议先从光盘复制到硬盘，再从硬盘解压：
```bash
cp /mnt/rancher-offline-package.tar.gz /tmp/
tar xzf /tmp/rancher-offline-package.tar.gz -C /home/szl/code/
```

---

## 📞 技术支持

如遇到问题，请参考：
- 完整指南: `offline-build/README.md`
- 快速开始: `offline-build/QUICKSTART.md`
- 项目概览: `offline-build/PROJECT_OVERVIEW.md`
- 交付清单: `offline-build/DELIVERY_CHECKLIST.md`

---

**文档生成时间**: 2026-05-24  
**适用版本**: Rancher v2.10.3  
**传输介质**: DVD 光盘（4.7GB）  
**打包策略**: 完整项目打包（含 .git）
