# Rancher v2.10.3 离线编译 - 快速开始指南

## 🚀 5分钟快速了解

本指南帮助你快速了解如何使用离线编译工具。详细步骤请参考 [README.md](README.md)。

---

## ⚠️ 重要提示

**完整打包方案（含 .git 目录）：**

本次打包采用**完整项目打包**方案，包含：
- ✅ 完整的 Rancher 源码（所有文件和目录）
- ✅ `.git` 目录（所有分支、标签、Git 历史）
- ✅ `vendor/` 目录（Go 依赖，约 622MB）
- ✅ `resources/` 目录（下载的所有资源，约 2.3GB）
- ✅ 离线配置文件

**传输介质：光盘（4.7GB）**
- 总大小约 3.0 GB，可放入单张 DVD 光盘
- 刻录时建议使用 4x 或 8x 速度以保证稳定性

**离线环境 Git 功能：**
```bash
# 可以执行的操作
git branch -a        # 查看所有分支
git tag              # 查看所有标签
git checkout <tag>   # 切换到指定版本
git log              # 查看提交历史

# 无法执行的操作（需要网络）
git pull             # ✗ 需要网络
git push             # ✗ 需要网络
```

---

## 📋 工作流程概览

```
┌─────────────────────┐
│  有网络的环境        │
│  (在线准备)          │
└──────────┬──────────┘
           │
           ├─ 步骤1: 下载所有资源
           │   ./scripts/01-download-resources.sh
           │
           ├─ 步骤2: 导出Docker镜像
           │   ./scripts/02-export-docker-images.sh
           │
           ├─ 步骤3: 下载Go依赖 ⭐新增
           │   go mod tidy && go mod vendor
           │
           ├─ 步骤4: 完整打包 ⭐修改
           │   ./scripts/03-transfer-to-offline.sh
           │   （包含源码+git+vendor+resources）
           │
           ▼
    ┌──────────────┐
    │  光盘刻录     │  ← 4.7GB DVD
    └──────┬───────┘
           │
           ▼
┌─────────────────────┐
│  离线环境            │
│  (内网编译)          │
└──────────┬──────────┘
           │
           ├─ 步骤5: 从光盘复制并解压
           │   tar xzf rancher-offline-package.tar.gz
           │
           ├─ 步骤6: 加载Docker镜像
           │   docker load -i resources/docker-images/*.tar
           │
           ├─ 步骤7: 执行离线编译
               ./offline-build/scripts/04-build-in-offline.sh
           │
           ▼
    ┌──────────────┐
    │  完成！       │
    │  dist/*.tar   │
    └──────────────┘
```

---

## 💻 快速命令参考

### 阶段1：在有网络的环境中（WSL2 Ubuntu）

```bash
# 进入项目根目录
cd /home/szl/code/rancher

# 步骤1：下载Go依赖（关键！）
go mod tidy
go mod vendor

# 进入离线构建目录
cd offline-build

# 步骤2：下载所有资源（30-60分钟）
./scripts/01-download-resources.sh

# 步骤3：导出Docker镜像（20-40分钟）
./scripts/02-export-docker-images.sh

# 步骤4：完整打包（15-25分钟）
./scripts/03-transfer-to-offline.sh

# 输出文件位置
ls -lh /tmp/rancher-offline-package.tar.gz
# 预计大小: ~3.0 GB
```

### 阶段2：刻录到光盘

**Windows 系统：**
1. 插入空白 DVD 光盘（4.7GB）
2. 访问 WSL2 文件系统：
   ```
   \\wsl$\Ubuntu-22.04\tmp\
   ```
3. 使用刻录软件（ImgBurn、Nero等）刻录以下文件：
   - `rancher-offline-package.tar.gz`
   - `rancher-offline-package.sha256`
4. 设置刻录速度为 4x 或 8x

**Linux 系统：**
```bash
sudo apt install wodim
sudo wodim -v dev=/dev/cdrom speed=4 \
    /tmp/rancher-offline-package.tar.gz \
    /tmp/rancher-offline-package.sha256
```

### 阶段3：在离线环境中（WSL2 Ubuntu）

```bash
# 步骤5：从光盘复制并解压
sudo mount /dev/cdrom /mnt
cp /mnt/rancher-offline-package.tar.gz /tmp/
cp /mnt/rancher-offline-package.sha256 /tmp/
sudo umount /mnt

# 验证完整性
cd /tmp
sha256sum -c rancher-offline-package.sha256

# 解压（得到完整项目）
tar xzf /tmp/rancher-offline-package.tar.gz -C /home/szl/code/

# 验证解压结果
cd /home/szl/code/rancher
git branch -a | head -5  # 查看所有分支
git tag | grep v2.10     # 查看所有标签
du -sh vendor/           # 检查 vendor 目录

# 步骤6：加载Docker镜像
cd offline-build
./scripts/04-build-in-offline.sh

# 查看输出
ls -lh ../dist/*.tar
```

---

## 📁 目录结构说明

```
offline-build/
├── README.md                          # 完整使用指南
├── QUICKSTART.md                      # 快速开始指南（本文件）
├── scripts/
│   ├── 01-download-resources.sh       # 下载资源脚本 ⭐
│   ├── 02-export-docker-images.sh     # 导出镜像脚本 ⭐
│   ├── 03-transfer-to-offline.sh      # 打包传输脚本 ⭐
│   └── 04-build-in-offline.sh         # 离线编译脚本 ⭐
├── resources/                         # 存放下载的资源
│   ├── docker-images/                 # Docker镜像tar包
│   ├── binaries/amd64/                # 二进制文件
│   ├── charts/                        # Helm Charts仓库
│   ├── ui-assets/                     # UI资源
│   ├── agent-files/                   # Agent文件
│   ├── kdm/                           # KDM数据
│   └── tools/                         # 构建工具
└── modified-files/                    # 离线版本文件
    ├── package/Dockerfile.offline
    └── scripts/
        ├── build-server-offline
        └── package-offline
```

---

## ⚠️ 重要提示

### 系统要求

**有网络的环境：**
- Windows 10/11 + WSL2 + Ubuntu-22.04
- Docker Desktop
- 可用磁盘空间：≥ 20GB
- 网络连接

**离线环境：**
- 相同的系统配置
- 可用磁盘空间：≥ 50GB
- 无需网络

### 预计时间

| 步骤 | 操作 | 预计时间 |
|------|------|---------|
| 1 | 下载资源 | 30-60分钟 |
| 2 | 导出Docker镜像 | 20-40分钟 |
| 3 | 打包传输 | 10-20分钟 |
| 4 | 离线编译 | 30-60分钟 |
| **总计** | | **90-180分钟** |

### 常见问题

**Q1: 脚本执行失败怎么办？**
- 检查错误信息
- 确认已安装所有依赖
- 查看 README.md 的故障排查章节

**Q2: 磁盘空间不足？**
```bash
# 清理Docker缓存
docker system prune -a -f

# 清理Go缓存
go clean -cache -modcache

# 检查磁盘使用
df -h
```

**Q3: 如何验证下载的资源完整性？**
```bash
# 检查关键文件
ls -lh resources/kdm/data.json
ls -lh resources/docker-images/*.tar
ls -lh resources/charts/
```

---

## 🎯 下一步

1. **阅读完整指南**: [README.md](README.md)
2. **开始执行**: 按照上述命令逐步执行
3. **遇到问题**: 查阅 README.md 的"验证和故障排查"章节

---

## 📞 获取帮助

- 详细文档: [README.md](README.md)
- Rancher官方文档: https://ranchermanager.docs.rancher.com
- 社区论坛: https://forums.rancher.com

---

**祝编译顺利！** 🎉
