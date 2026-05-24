# Rancher v2.10.3 离线编译打包完整指南

## 📋 目录

- [一、环境准备](#一环境准备)
- [二、在线环境资源下载](#二在线环境资源下载)
- [三、资源传输到离线环境](#三资源传输到离线环境)
- [四、离线环境编译打包](#四离线环境编译打包)
- [五、验证和故障排查](#五验证和故障排查)

---

## 一、环境准备

### 1.1 Windows 环境要求

**必需软件：**
- Windows 10/11 专业版或企业版
- WSL2（Windows Subsystem for Linux）
- Docker Desktop for Windows

**检查 WSL2 是否安装：**

在 **Windows PowerShell（管理员）** 中执行：
```powershell
wsl --version
```

如果未安装，执行：
```powershell
wsl --install -d Ubuntu-22.04
```

**检查 Docker Desktop：**
- 确保 Docker Desktop 已安装并运行
- 在设置中启用 "Use the WSL 2 based engine"

### 1.2 WSL2 Ubuntu-22.04 环境配置

**步骤1：打开 WSL2 Ubuntu**

在 **Windows PowerShell** 中执行：
```powershell
wsl -d Ubuntu-22.04
```

**步骤2：安装必需的软件包**

在 **WSL2 Ubuntu 终端** 中执行：
```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必需工具
sudo apt install -y \
    git \
    curl \
    wget \
    docker.io \
    docker-compose \
    golang-go \
    python3 \
    jq \
    tar \
    gzip \
    unzip \
    build-essential

# 启动 Docker 服务
sudo service docker start

# 将当前用户添加到 docker 组（避免每次都用 sudo）
sudo usermod -aG docker $USER

# 重新登录使组生效（执行后退出终端重新进入）
exit
```

**重新进入 WSL2：**
```powershell
wsl -d Ubuntu-22.04
```

**验证 Docker：**
```bash
docker --version
docker run hello-world
```

**验证 Go：**
```bash
go version
# 应该显示 go version go1.23.x 或更高版本
```

如果 Go 版本低于 1.23，需要手动安装：
```bash
# 下载 Go 1.23
wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz

# 添加到 PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# 验证
go version
```

### 1.3 项目代码准备

**克隆 Rancher 代码（在有网络的环境中）：**

在 **WSL2 Ubuntu 终端** 中执行：
```bash
cd ~
git clone https://github.com/rancher/rancher.git
cd rancher
git checkout v2.10.3
```

**确认当前目录：**
```bash
pwd
# 应该显示：/home/szl/code/rancher
```

---

## 二、在线环境资源下载

> **重要提示：** 以下步骤在**有网络连接的环境**中执行

### 2.1 切换到离线构建目录

在 **WSL2 Ubuntu 终端** 中执行：
```bash
cd /home/szl/code/rancher/offline-build
```

### 2.2 执行资源下载脚本

**步骤1：下载所有外部资源**

```bash
chmod +x scripts/01-download-resources.sh
./scripts/01-download-resources.sh
```

该脚本会：
- ✅ 检查依赖软件是否安装
- ✅ 下载所有二进制文件（rancher-machine, helm, etcd 等）
- ✅ 克隆所有 Charts 仓库
- ✅ 下载所有 UI 资源
- ✅ 下载 Agent 相关文件
- ✅ 下载 KDM 数据

**预计耗时：** 30-60 分钟（取决于网络速度）  
**所需空间：** 约 5-10 GB

**步骤2：导出 Docker 基础镜像**

```bash
chmod +x scripts/02-export-docker-images.sh
./scripts/02-export-docker-images.sh
```

该脚本会：
- ✅ 拉取所有必需的 Docker 基础镜像
- ✅ 导出为 tar 文件保存到 `resources/docker-images/`

**预计耗时：** 20-40 分钟  
**所需空间：** 约 3-5 GB

**步骤3：导出 zypper RPM 包（用于离线安装系统依赖）**

> **重要提示：** Dockerfile.offline 需要这些 RPM 包来安装系统工具，必须在联网环境中完成！

在 **WSL2 Ubuntu 终端** 中执行：
```bash
chmod +x scripts/05-export-zypper-packages.sh
./scripts/05-export-zypper-packages.sh
```

该脚本会：
- ✅ 下载所有系统依赖的 RPM 包（git, curl, wget, jq 等）
- ✅ 保存到 `resources/zypper-packages/` 目录
- ✅ 用于 Dockerfile.offline 中的离线安装

**预计耗时：** 5-10 分钟  
**所需空间：** 约 50-100 MB

**注意：** 
- 此步骤需要在 openSUSE/SLES 环境中执行（有 zypper 包管理器）
- 如果在 Ubuntu 中执行，可能需要先安装 zypper 或使用其他方法获取 RPM 包
- 备选方案：在 Docker 容器中执行此脚本

**步骤4：下载 Go 模块依赖（关键！）**

> **重要提示：** 这一步是离线编译成功的关键，必须在联网环境中完成！

在 **WSL2 Ubuntu 终端** 中执行：
```bash
cd /home/szl/code/rancher

# 确保 go.mod 和 go.sum 是最新的
go mod tidy

# 下载所有 Go 依赖到 vendor 目录
go mod vendor
```

这将：
- ✅ 验证并更新 `go.mod` 和 `go.sum` 文件
- ✅ 下载所有 Go 模块依赖到 `vendor/` 目录
- ✅ 生成 `vendor/modules.txt` 清单文件

**预计耗时：** 10-30 分钟（取决于网络速度）  
**vendor 目录大小：** 约 600-800 MB  
**文件数量：** 约 30,000+ 个文件

**验证 vendor 目录：**
```bash
# 检查 vendor 目录
ls -la vendor/ | head -10

# 查看大小
du -sh vendor/

# 应该看到类似输出：
# 622M    vendor/
```

### 2.3 验证下载结果

执行以下命令检查：
```bash
# 检查资源目录
ls -lh resources/

# 应该看到以下子目录：
# docker-images/  binaries/  charts/  ui-assets/  agent-files/  kdm/  tools/

# 检查文件大小
du -sh resources/*

# 检查 Go vendor 目录
ls -la vendor/ | head -5
du -sh vendor/
```

**预期输出示例：**
```
3.2G    resources/docker-images
800M    resources/binaries
1.5G    resources/charts
200M    resources/ui-assets
50M     resources/agent-files
100M    resources/kdm
10M     resources/tools
622M    vendor/          ← Go 依赖目录（新增）
```

---

## 三、资源传输到离线环境

### 3.1 打包所有资源

在 **WSL2 Ubuntu 终端** 中执行：
```bash
cd /home/szl/code/rancher/offline-build
chmod +x scripts/03-transfer-to-offline.sh
./scripts/03-transfer-to-offline.sh
```

该脚本会：
- ✅ **完整打包整个 Rancher 项目目录**（包括 .git、vendor、所有源码）
- ✅ 打包 `resources/` 目录（所有下载的资源）
- ✅ 打包 `modified-files/` 目录（离线配置文件）
- ✅ 生成校验和文件
- ✅ 输出文件到 `/tmp/rancher-offline-package.tar.gz`

**预计耗时：** 15-25 分钟  
**最终包大小：** 约 3.0 GB  
**光盘容量：** 4.7 GB（单张光盘即可容纳）

**重要提示：** 
- 📦 **包含完整的 Git 仓库**：`.git` 目录包含所有分支、标签和历史记录
- 🔍 **离线环境可以查看所有版本**：可以使用 `git branch -a`、`git tag`、`git checkout` 等命令
- 💿 **适合单张光盘刻录**：3.0 GB < 4.7 GB，有充足余量
- ⚠️ **不排除任何文件**：完整保留项目结构，便于离线开发和调试

### 3.2 刻录到光盘

**Windows 系统刻录方法：**

**方法 1: 使用 Windows 内置功能**
1. 插入空白光盘（DVD-R 或 DVD+R，容量 4.7GB）
2. 打开文件资源管理器，找到 WSL2 文件系统：
   ```
   \\wsl$\Ubuntu-22.04\tmp\rancher-offline-package.tar.gz
   ```
3. 右键点击文件 → "发送到" → "DVD RW 驱动器"
4. 按照向导完成刻录

**方法 2: 使用刻录软件（推荐）**
- **ImgBurn**（免费）: https://www.imgburn.com/
- **Nero Burning ROM**（付费）
- **CDBurnerXP**（免费）: https://cdburnerxp.se/

步骤：
1. 打开刻录软件
2. 选择"刻录 ISO 映像"或"刻录文件"
3. 添加 `rancher-offline-package.tar.gz` 和 `rancher-offline-package.sha256`
4. 设置刻录速度为 4x 或 8x（更稳定）
5. 开始刻录

**Linux 系统刻录方法：**

**方法 1: 图形界面工具**
- **Brasero**: `sudo apt install brasero`
- **K3b**: `sudo apt install k3b`

**方法 2: 命令行刻录**
```bash
# 安装刻录工具
sudo apt install wodim

# 查找光驱设备
wodim --devices

# 刻录文件（替换 /dev/cdrom 为实际设备）
sudo wodim -v dev=/dev/cdrom speed=4 \
    /tmp/rancher-offline-package.tar.gz \
    /tmp/rancher-offline-package.sha256
```

**验证刻录成功：**
```bash
# 挂载光盘并检查文件
mount /dev/cdrom /mnt
ls -lh /mnt/
umount /mnt
```

### 3.3 复制到 U 盘（备选方案）

如果不想使用光盘，也可以使用 U 盘：

**在 Windows 中操作：**
1. 插入 U 盘（建议容量 ≥ 8GB）
2. 打开文件资源管理器，找到 WSL2 文件系统：
   ```
   \\wsl$\Ubuntu-22.04\tmp\rancher-offline-package.tar.gz
   ```
3. 复制 `rancher-offline-package.tar.gz` 和 `rancher-offline-package.sha256` 到 U 盘
4. 安全弹出 U 盘

**或者在 WSL2 中直接复制到挂载的 U 盘：**
```bash
# 假设 U 盘挂载在 /mnt/usb
cp /tmp/rancher-offline-package.tar.gz /mnt/usb/
cp /tmp/rancher-offline-package.sha256 /mnt/usb/
```

---

## 四、离线环境编译打包

> **重要提示：** 以下步骤在**完全离线的内网环境**中执行

### 4.1 准备工作

**步骤1：从光盘复制压缩包到离线环境**

```bash
# 挂载光盘（如果尚未自动挂载）
sudo mount /dev/cdrom /mnt

# 验证文件存在
ls -lh /mnt/rancher-offline-package.tar.gz
ls -lh /mnt/rancher-offline-package.sha256

# 复制压缩包到本地（建议复制到空间充足的目录）
cp /mnt/rancher-offline-package.tar.gz /tmp/
cp /mnt/rancher-offline-package.sha256 /tmp/

# 卸载光盘
sudo umount /mnt

# 验证完整性
cd /tmp
sha256sum -c rancher-offline-package.sha256
```

**步骤2：确认目标路径**

压缩包解压后将得到完整的 Rancher 项目，建议解压到：
```
/home/szl/code/rancher/
```

确保该目录不存在或为空：
```bash
# 如果目录已存在，先备份或删除
if [ -d "/home/szl/code/rancher" ]; then
    mv /home/szl/code/rancher /home/szl/code/rancher.backup.$(date +%Y%m%d)
fi

# 创建目录
mkdir -p /home/szl/code/rancher
```

### 4.2 解压资源

```bash
# 解压完整的项目包
tar xzf /tmp/rancher-offline-package.tar.gz -C /home/szl/code/

# 验证解压结果
cd /home/szl/code/rancher
echo "=== 验证解压结果 ==="
echo ""
echo "1. 检查源码:"
ls -la main.go
echo ""
echo "2. 检查 .git 目录（包含所有分支和标签）:"
ls -la .git/ | head -5
echo ""
echo "3. 检查 vendor 目录:"
du -sh vendor/
echo ""
echo "4. 检查 resources 目录:"
du -sh offline-build/resources/
echo ""
echo "5. 查看 Git 分支和标签:"
git branch -a | head -10
echo "..."
git tag | grep "v2.10" | tail -5
echo ""
echo "✓ 解压完成！"
```

**重要说明：**
- ✅ **完整的项目结构**：解压后直接得到完整的 Rancher 项目
- ✅ **包含 .git 目录**：可以查看所有分支、标签和历史
- ✅ **vendor 已在正确位置**：`/home/szl/code/rancher/vendor/`
- ✅ **resources 在正确位置**：`/home/szl/code/rancher/offline-build/resources/`
- ❌ **无需手动移动文件**：所有文件已在正确位置

**Git 功能（离线环境可用）：**
```bash
# 查看所有分支
git branch -a

# 查看所有标签
git tag

# 切换到其他版本（例如 v2.10.8）
git checkout v2.10.8

# 查看提交历史
git log --oneline | head -20

# 查看当前分支
git branch

# 注意：以下操作需要网络，离线环境无法使用
# git pull
# git push
# git fetch
```

### 4.3 加载 Docker 镜像

```
# 加载所有 Docker 基础镜像
for img in resources/docker-images/*.tar; do
    echo "Loading $img..."
    docker load -i "$img"
done

# 验证镜像已加载
docker images | grep -E "(bci|golang|k3s)"
```

### 4.4 替换原始文件

```
# 备份原始文件（可选）
cp package/Dockerfile package/Dockerfile.backup
cp scripts/build-server scripts/build-server.backup
cp scripts/package scripts/package.backup

# 替换为离线版本
cp modified-files/package/Dockerfile.offline package/Dockerfile
cp modified-files/scripts/build-server-offline scripts/build-server
cp modified-files/scripts/package-offline scripts/package

# 设置执行权限
chmod +x scripts/build-server
chmod +x scripts/package
```

### 4.5 执行离线编译

**步骤1：编译 Rancher Server 和 Agent**

```
cd /home/szl/code/rancher

# 执行离线编译脚本
chmod +x offline-build/scripts/04-build-in-offline.sh
./offline-build/scripts/04-build-in-offline.sh
```

该脚本会：
- ✅ 设置离线 Go 编译环境
- ✅ 编译 Rancher Server 二进制文件
- ✅ 编译 Rancher Agent 二进制文件
- ✅ 构建 Docker 镜像（rancher 和 rancher-agent）
- ✅ 保存镜像到 `dist/` 目录

**预计耗时：** 30-60 分钟（取决于机器性能）

### 4.6 验证编译结果

```
# 检查输出文件
ls -lh dist/

# 应该看到：
# rancher-v2.10.3-amd64.tar
# rancher-agent-v2.10.3-amd64.tar

# 验证镜像可以加载
docker load -i dist/rancher-v2.10.3-amd64.tar
docker load -i dist/rancher-agent-v2.10.3-amd64.tar

# 查看镜像
docker images | grep rancher
```

---

## 五、验证和故障排查

### 5.1 快速验证

**测试 Rancher 容器启动：**
```
docker run -d --name rancher-test \
    --restart=unless-stopped \
    -p 80:80 -p 443:443 \
    -e CATTLE_SYSTEM_CATALOG=bundled \
    rancher/rancher:v2.10.3

# 等待 2-3 分钟后检查日志
docker logs rancher-test

# 访问 https://localhost （接受自签名证书警告）
```

### 5.2 常见问题

#### 问题1：Docker 镜像加载失败

**症状：** `docker load` 报错 "no space left on device"

**解决：**
```
# 清理 Docker 缓存
docker system prune -a -f

# 检查磁盘空间
df -h

# 扩展 WSL2 磁盘（如果需要）
# 在 Windows PowerShell 中执行：
wsl --shutdown
# 然后按照 Microsoft 文档扩展 VHDX
```

#### 问题2：Go 编译失败

**症状：** `go build` 报错 "module not found"

**解决：**
```
# 确保设置了离线模式
export GOPROXY=off
export GOFLAGS=-mod=vendor

# 重新生成 vendor 目录
cd /home/szl/code/rancher
go mod vendor
```

#### 问题3：Charts 仓库克隆失败

**症状：** `git clone` 超时或连接拒绝

**解决：**
```
# 检查 resources/charts/ 目录是否已有内容
ls -la resources/charts/

# 如果目录为空，从备份恢复或重新下载
# 确保在有网络环境中完成下载
```

#### 问题4：磁盘空间不足

**症状：** 编译过程中报错 "no space left on device"

**解决：**
```
# 检查 WSL2 磁盘使用
df -h

# 清理不必要的文件
docker system prune -a -f
rm -rf /tmp/*
go clean -cache -modcache

# 如需扩展 WSL2 磁盘，参考：
# https://learn.microsoft.com/en-us/windows/wsl/disk-space
```

### 5.3 获取帮助

如果遇到问题：

1. 检查脚本输出日志
2. 查看 Docker 日志：`docker logs <container-name>`
3. 检查系统资源：`free -h` 和 `df -h`
4. 查阅 Rancher 官方文档：https://ranchermanager.docs.rancher.com

---

## 附录：文件清单

### A. 脚本说明

| 脚本文件 | 用途 | 执行环境 |
|---------|------|---------|
| `01-download-resources.sh` | 下载所有外部资源 | 有网络的 WSL2 |
| `02-export-docker-images.sh` | 导出 Docker 镜像 | 有网络的 WSL2 |
| `03-transfer-to-offline.sh` | 打包资源用于传输 | 有网络的 WSL2 |
| `04-build-in-offline.sh` | 离线编译打包 | 离线 WSL2 |

### B. 资源目录结构

```
resources/
├── docker-images/          # Docker 基础镜像 tar 包
│   ├── bci-micro-15.6.tar
│   ├── bci-base-15.6.tar
│   ├── golang-1.23.tar
│   └── k3s-v1.31.1-k3s1.tar
├── binaries/amd64/         # 二进制工具
│   ├── rancher-machine.tar.gz
│   ├── tini
│   ├── helm-v3.tar.gz
│   ├── etcd.tar.gz
│   └── ...
├── charts/                 # Helm Charts 仓库
│   ├── system-charts/
│   ├── charts/
│   ├── partner-charts/
│   └── rke2-charts/
├── ui-assets/              # UI 资源
│   ├── ui-2.10.3.tar.gz
│   ├── dashboard-v2.10.3.tar.gz
│   └── api-ui-1.1.11.tar.gz
├── agent-files/            # Agent 相关文件
│   ├── system-agent/
│   ├── wins/
│   └── cli/
├── kdm/                    # KDM 元数据
│   └── data.json
└── tools/                  # 构建工具
    └── dapper
```

### C. 修改的文件

| 原文件 | 离线版本 | 主要修改 |
|-------|---------|---------|
| `package/Dockerfile` | `Dockerfile.offline` | 使用本地资源替代网络下载 |
| `scripts/build-server` | `build-server-offline` | 禁用网络依赖，使用本地 data.json |
| `scripts/package` | `package-offline` | 使用本地 charts 和镜像 |

---

## 许可证

本指南遵循 Rancher 项目的 Apache 2.0 许可证。

**最后更新：** 2024-01-XX  
**适用版本：** Rancher v2.10.3  
**架构支持：** amd64
