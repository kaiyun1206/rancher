# Rancher v2.10.3 离线编译打包工具集

## 📖 项目说明

本工具集提供了一套完整的自动化脚本，用于在**完全离线的环境**中编译和打包 Rancher v2.10.3。

### 核心特性

✅ **全自动化**: 一键下载所有必需资源，无需手动逐个下载  
✅ **分阶段执行**: 清晰的4个阶段，每步都有明确提示  
✅ **错误检查**: 内置环境检查和完整性验证  
✅ **详细文档**: 中文指南，小白也能轻松跟随  
✅ **灵活配置**: 集中管理所有版本和参数  

---

## 🗂️ 文件结构

```
offline-build/
│
├── 📄 README.md                    # 完整使用指南（必读）
├── 📄 QUICKSTART.md                # 快速开始指南
├── 📄 PROJECT_OVERVIEW.md          # 项目总览（本文件）
│
├── 📁 scripts/                     # 脚本目录
│   ├── check-environment.sh        # 🔍 环境检查工具
│   ├── build-config.sh             # ⚙️  配置文件（版本信息）
│   │
│   ├── 01-download-resources.sh    # 📥 下载所有资源
│   ├── 02-export-docker-images.sh  # 🐳 导出Docker镜像
│   ├── 03-transfer-to-offline.sh   # 📦 打包用于传输
│   ├── 04-build-in-offline.sh      # 🔨 离线编译打包
│   │
│   └── cleanup.sh                  # 🧹 清理临时文件
│
├── 📁 resources/                   # 资源存储目录（自动创建）
│   ├── docker-images/              # Docker镜像tar包
│   ├── binaries/amd64/             # 二进制工具
│   ├── charts/                     # Helm Charts仓库
│   ├── ui-assets/                  # UI资源
│   ├── agent-files/                # Agent相关文件
│   ├── kdm/                        # KDM元数据
│   └── tools/                      # 构建工具
│
└── 📁 modified-files/              # 修改后的文件（自动创建）
    ├── package/Dockerfile.offline
    └── scripts/
        ├── build-server-offline
        └── package-offline
```

---

## 🚀 快速开始

### 前置条件

- ✅ Windows 10/11 + WSL2 + Ubuntu-22.04
- ✅ Docker Desktop 已安装并运行
- ✅ Go 1.23+ 已安装
- ✅ 至少 50GB 可用磁盘空间

### 执行流程

#### 阶段1: 环境检查（可选但推荐）

```bash
cd /home/szl/code/rancher/offline-build
./scripts/check-environment.sh
```

#### 阶段2: 在有网络的环境中准备资源

```bash
# 步骤1: 下载所有外部资源（30-60分钟）
./scripts/01-download-resources.sh

# 步骤2: 导出Docker基础镜像（20-40分钟）
./scripts/02-export-docker-images.sh

# 步骤3: 打包所有资源（10-20分钟）
./scripts/03-transfer-to-offline.sh
```

输出文件: `/tmp/rancher-offline-package.tar.gz` (约10-15GB)

#### 阶段3: 传输到离线环境

通过U盘将 `rancher-offline-package.tar.gz` 复制到离线机器

#### 阶段4: 在离线环境中编译

```bash
# 解压资源
tar xzf rancher-offline-package.tar.gz -C /tmp/
mv /tmp/offline-build-package/* /home/szl/code/rancher/offline-build/

# 执行编译（30-60分钟）
cd /home/szl/code/rancher/offline-build
./scripts/04-build-in-offline.sh
```

输出文件: `../dist/rancher-v2.10.3-amd64.tar`

---

## 📋 脚本详细说明

### 🔍 check-environment.sh

**用途**: 检查系统环境是否满足要求  
**执行时机**: 任何阶段开始前  
**功能**:
- 检查必需软件（git, curl, docker, go等）
- 验证Docker服务状态
- 检查Go版本（需要≥1.23）
- 检查磁盘空间（建议≥50GB）
- 验证项目目录结构

**示例输出**:
```
==========================================
  Rancher 离线编译环境检查工具
==========================================

【系统信息】
ℹ 操作系统: Ubuntu 22.04.3 LTS
✓ 运行在 WSL2 环境中

【必需工具】
✓ git 已安装
✓ curl 已安装
✓ docker 已安装
✓ go 已安装

【Docker 服务】
✓ Docker 服务正在运行
ℹ Docker 版本: Docker version 24.0.7

【Go 环境】
ℹ Go 版本: go1.23.4
✓ Go 版本满足要求 (>= 1.23)

【磁盘空间】
ℹ 当前目录: /home/szl/code/rancher
ℹ 可用空间: 120GB
✓ 磁盘空间充足 (>= 50GB)

==========================================
  检查结果汇总
==========================================
通过: 12
失败: 0
警告: 0

✓ 环境检查通过！可以开始离线编译流程
```

---

### 📥 01-download-resources.sh

**用途**: 下载所有离线编译所需的外部资源  
**执行环境**: 有网络连接的WSL2  
**预计时间**: 30-60分钟  
**预计空间**: 5-10GB  

**下载内容**:
1. **二进制工具** (约800MB)
   - rancher-machine
   - docker-machine-driver-linode
   - docker-machine-driver-harvester
   - tini
   - helm v2 & v3
   - etcd
   - kustomize
   - telemetry

2. **Charts仓库** (约1.5GB)
   - system-charts
   - charts (rancher-charts)
   - partner-charts
   - rke2-charts

3. **UI资源** (约200MB)
   - Rancher UI
   - Dashboard UI
   - API UI
   - Linode UI Driver

4. **Agent文件** (约50MB)
   - System Agent
   - Wins Agent
   - CLI Tools
   - CSI Proxy

5. **KDM数据** (约100MB)
   - data.json

**交互方式**: 半自动化，每个阶段完成后询问是否继续

---

### 🐳 02-export-docker-images.sh

**用途**: 拉取并导出所有必需的Docker基础镜像  
**执行环境**: 有网络连接且Docker运行的WSL2  
**预计时间**: 20-40分钟  
**预计空间**: 3-5GB  

**导出镜像**:
- registry.suse.com/bci/bci-micro:15.6
- registry.suse.com/bci/bci-base:15.6
- registry.suse.com/bci/golang:1.23
- rancher/k3s:v1.31.1-k3s1

**输出位置**: `resources/docker-images/*.tar`

---

### 📦 03-transfer-to-offline.sh

**用途**: 打包所有资源为单个压缩文件，便于U盘传输  
**执行环境**: 资源下载完成后的WSL2  
**预计时间**: 10-20分钟  

**功能**:
1. 验证资源完整性
2. 创建离线版本的配置文件
3. 打包为 tar.gz 格式
4. 生成SHA256校验和

**输出文件**:
- `/tmp/rancher-offline-package.tar.gz` (主文件)
- `/tmp/rancher-offline-package.sha256` (校验和)

---

### 🔨 04-build-in-offline.sh

**用途**: 在离线环境中执行完整的编译和打包流程  
**执行环境**: 完全离线的WSL2  
**预计时间**: 30-60分钟  
**所需空间**: ≥50GB  

**执行步骤**:
1. 检查离线环境
2. 加载Docker基础镜像
3. 替换为离线版本文件
4. 设置离线Go环境（GOPROXY=off）
5. 编译Rancher Server
6. 编译Rancher Agent
7. 构建Docker镜像
8. 保存镜像到dist目录

**输出文件**:
- `dist/rancher-v2.10.3-amd64.tar`
- `dist/rancher-agent-v2.10.3-amd64.tar`

---

### 🧹 cleanup.sh

**用途**: 清理编译过程中产生的临时文件和缓存  
**执行时机**: 编译完成后或需要释放空间时  

**清理选项**:
1. Go构建缓存和模块缓存
2. Docker未使用的镜像、容器、卷
3. 临时文件（/tmp中的相关文件）
4. 编译输出文件（dist/*.tar）
5. 所有上述内容
6. 仅检查（不删除）

---

### ⚙️ build-config.sh

**用途**: 集中管理所有版本配置  
**使用方式**: 其他脚本通过 `source build-config.sh` 引用  

**配置内容**:
- Rancher版本和分支
- 所有工具的版本号
- Docker镜像配置
- Charts分支配置
- 目录路径配置

**查看配置**:
```bash
./scripts/build-config.sh
```

---

## 🎯 工作流程图

```
┌─────────────────────────────────────┐
│     有网络的环境（在线准备）          │
└──────────────┬──────────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │ check-environment.sh │ ← 检查环境
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ 01-download-resources.sh │ ← 下载资源（30-60分钟）
    └──────────┬───────────────┘
               │
               ▼
    ┌─────────────────────────────┐
    │ 02-export-docker-images.sh  │ ← 导出镜像（20-40分钟）
    └──────────┬──────────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ 03-transfer-to-offline.sh│ ← 打包传输（10-20分钟）
    └──────────┬───────────────┘
               │
               ▼
        ╔═══════════════╗
        ║  U盘传输       ║
        ╚═══════════════╝
               │
               ▼
┌─────────────────────────────────────┐
│     离线环境（内网编译）              │
└──────────────┬──────────────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ 解压资源包                │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ 04-build-in-offline.sh   │ ← 编译打包（30-60分钟）
    └──────────┬───────────────┘
               │
               ▼
        ╔═══════════════╗
        ║  dist/*.tar   ║ ← 最终产物
        ╚═══════════════╝
```

---

## ⚠️ 注意事项

### 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10/11 + WSL2 + Ubuntu-22.04 |
| Docker | Docker Desktop for Windows |
| Go | 1.23 或更高版本 |
| 磁盘空间（在线环境） | ≥ 20GB |
| 磁盘空间（离线环境） | ≥ 50GB |
| 网络（在线阶段） | 可访问GitHub和相关下载源 |
| U盘容量 | ≥ 32GB |

### 时间估算

| 阶段 | 操作 | 预计时间 |
|------|------|---------|
| 1 | 环境检查 | 1分钟 |
| 2 | 下载资源 | 30-60分钟 |
| 3 | 导出Docker镜像 | 20-40分钟 |
| 4 | 打包传输 | 10-20分钟 |
| 5 | U盘传输 | 5-10分钟 |
| 6 | 离线编译 | 30-60分钟 |
| **总计** | | **90-180分钟** |

### 常见问题

**Q1: 下载速度慢怎么办？**
- 使用更快的网络
- 考虑使用代理
- 分段执行，每次只下载一部分

**Q2: 磁盘空间不足？**
```bash
# 清理Docker
docker system prune -a -f

# 清理Go缓存
go clean -cache -modcache

# 使用cleanup.sh脚本
./scripts/cleanup.sh
```

**Q3: 如何验证资源完整性？**
```bash
# 在离线环境中
sha256sum -c rancher-offline-package.sha256
```

**Q4: 编译失败如何排查？**
1. 检查环境: `./scripts/check-environment.sh`
2. 查看日志输出
3. 参考README.md的故障排查章节
4. 清理后重试: `./scripts/cleanup.sh`

---

## 📚 相关文档

- [README.md](README.md) - 完整使用指南
- [QUICKSTART.md](QUICKSTART.md) - 快速开始指南
- [build-config.sh](scripts/build-config.sh) - 配置说明

---

## 📞 获取帮助

- 📖 详细文档: [README.md](README.md)
- 🚀 快速开始: [QUICKSTART.md](QUICKSTART.md)
- 🌐 Rancher官方: https://ranchermanager.docs.rancher.com
- 💬 社区论坛: https://forums.rancher.com

---

## 📝 版本历史

**v1.0.0** (2024-01-XX)
- 初始版本
- 支持amd64架构
- 包含完整的4阶段自动化脚本
- 提供详细的中文文档

---

**祝编译顺利！** 🎉
