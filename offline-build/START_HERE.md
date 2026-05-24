# 🎯 从这里开始 - Rancher 离线编译指南

## 👋 欢迎使用 Rancher v2.10.3 离线编译工具集！

本工具集帮助你**在完全离线的环境中**编译和打包 Rancher。

---

## 📖 我应该先读哪个文档？

### 🚀 新手推荐路线

```
第1步: 阅读本文档 (START_HERE.md)        ← 你现在在这里
         ↓
第2步: 查看快速开始 (QUICKSTART.md)       ← 5分钟了解流程
         ↓
第3步: 运行环境检查                        ← 确认系统就绪
         ./scripts/check-environment.sh
         ↓
第4步: 阅读完整指南 (README.md)           ← 详细操作步骤
         ↓
第5步: 开始执行!                          ← 按照脚本顺序执行
```

### 📚 文档说明

| 文档 | 用途 | 阅读时间 |
|------|------|---------|
| **START_HERE.md** | 入门指引（本文档） | 3分钟 |
| **QUICKSTART.md** | 快速参考手册 | 5分钟 |
| **README.md** | 完整操作指南 | 15分钟 |
| **PROJECT_OVERVIEW.md** | 项目详细说明 | 10分钟 |
| **DELIVERY_CHECKLIST.md** | 交付清单 | 5分钟 |

---

## ⚡ 快速行动指南

### 场景1: 我还没准备任何资源

**目标**: 在有网络的环境中下载所有资源

```bash
# 1. 进入目录
cd /home/szl/code/rancher/offline-build

# 2. 检查环境
./scripts/check-environment.sh

# 3. 如果检查通过，开始下载
./scripts/01-download-resources.sh    # 下载所有资源（30-60分钟）
./scripts/02-export-docker-images.sh  # 导出Docker镜像（20-40分钟）
./scripts/03-transfer-to-offline.sh   # 打包用于传输（10-20分钟）

# 4. 将生成的文件复制到U盘
# 文件位置: /tmp/rancher-offline-package.tar.gz
```

### 场景2: 我已经有资源包，需要在离线环境编译

**目标**: 在离线环境中编译Rancher

```bash
# 1. 解压资源包
tar xzf rancher-offline-package.tar.gz -C /tmp/
mv /tmp/offline-build-package/* /home/szl/code/rancher/offline-build/

# 2. 进入目录并编译
cd /home/szl/code/rancher/offline-build
./scripts/04-build-in-offline.sh      # 编译打包（30-60分钟）

# 3. 完成！输出在 ../dist/ 目录
ls -lh ../dist/*.tar
```

### 场景3: 我想了解整个流程

👉 阅读 [QUICKSTART.md](QUICKSTART.md) 查看工作流程图

### 场景4: 我遇到了问题

👉 阅读 [README.md](README.md) 的"验证和故障排查"章节

---

## 🎬 核心脚本速览

### 🔍 环境检查
```bash
./scripts/check-environment.sh
```
检查你的系统是否满足要求

### 📥 下载资源
```bash
./scripts/01-download-resources.sh
```
自动下载所有必需的外部资源

### 🐳 导出镜像
```bash
./scripts/02-export-docker-images.sh
```
拉取并导出Docker基础镜像

### 📦 打包传输
```bash
./scripts/03-transfer-to-offline.sh
```
将所有资源打包为单个文件

### 🔨 离线编译
```bash
./scripts/04-build-in-offline.sh
```
在离线环境中执行编译和打包

### 🧹 清理空间
```bash
./scripts/cleanup.sh
```
清理临时文件和缓存

---

## 📊 时间和空间需求

### 在线准备阶段（有网络）

| 步骤 | 时间 | 空间 |
|------|------|------|
| 下载资源 | 30-60分钟 | 5-10GB |
| 导出镜像 | 20-40分钟 | 3-5GB |
| 打包传输 | 10-20分钟 | - |
| **小计** | **60-120分钟** | **8-15GB** |

### 离线编译阶段（无网络）

| 步骤 | 时间 | 空间 |
|------|------|------|
| 加载镜像 | 5分钟 | - |
| 编译打包 | 30-60分钟 | 30-40GB |
| **小计** | **35-65分钟** | **30-40GB** |

### 总计
- **总时间**: 95-185分钟（约1.5-3小时）
- **总空间**: 建议至少 50GB 可用空间
- **U盘容量**: 建议 32GB 或更大

---

## ✅ 开始前检查清单

在开始之前，请确认：

- [ ] Windows 10/11 已安装 WSL2
- [ ] Ubuntu-22.04 已在 WSL2 中安装
- [ ] Docker Desktop 已安装并运行
- [ ] Go 1.23+ 已安装
- [ ] 至少 50GB 可用磁盘空间
- [ ] （在线阶段）网络连接正常
- [ ] （离线阶段）U盘已准备好

**快速检查**: 
```bash
./scripts/check-environment.sh
```

---

## 🎯 我的建议

### 第一次使用？

1. **不要跳过环境检查** - 运行 `check-environment.sh`
2. **先读 QUICKSTART.md** - 了解整体流程
3. **按顺序执行脚本** - 01 → 02 → 03 → 04
4. **遇到问题查 README.md** - 有详细的故障排查

### 想节省时间？

- 确保网络速度快（影响下载时间）
- 预留足够的磁盘空间（避免中途失败）
- 使用SSD硬盘（加快编译速度）
- 关闭不必要的程序（释放内存）

### 想确保安全？

- 在测试环境中先演练一次
- 保留原始文件的备份
- 记录每步的输出日志
- 验证最终产物的完整性

---

## 🆘 需要帮助？

### 文档
- 📖 完整指南: [README.md](README.md)
- 🚀 快速开始: [QUICKSTART.md](QUICKSTART.md)
- 📋 项目总览: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)

### 外部资源
- Rancher官方文档: https://ranchermanager.docs.rancher.com
- Rancher社区论坛: https://forums.rancher.com
- GitHub Issues: https://github.com/rancher/rancher/issues

---

## 🎉 准备好了吗？

### 立即开始

```bash
# 第一步：检查环境
cd /home/szl/code/rancher/offline-build
./scripts/check-environment.sh
```

如果检查通过，就可以开始正式流程了！

**祝你编译顺利！** 🚀

---

*最后更新: 2024-01-XX*  
*适用版本: Rancher v2.10.3*  
*架构支持: amd64*
