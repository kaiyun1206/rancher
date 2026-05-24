# Zypper RPM 包说明

## 📦 已下载的 RPM 包（8个）

| 包名 | 版本 | 大小 | 用途 |
|------|------|------|------|
| git-core | 2.43.0 | 5.7M | Git 版本控制 |
| wget | 1.20.3 | 388K | 文件下载工具 |
| gawk | 4.2.1 | 1.2M | AWK 文本处理 |
| iptables | 1.8.7 | 211K | 防火墙工具 |
| unzip | 6.00 | 105K | ZIP 解压工具 |
| tar | 1.34 | 251K | 压缩解压工具 |
| jq | 1.6 | 66K | JSON 处理工具 |
| gzip | 1.10 | 141K | Gzip 压缩工具 |

**总大小**: 8.0 MB

---

## ⚠️ 未下载的包

以下包在基础镜像中已存在或不需要额外安装：

- **sed** - ✅ 基础镜像中已存在（/usr/bin/sed）
- **curl** - ✅ 基础镜像中已存在（/usr/bin/curl）
- **ca-certificates** - ⚠️ 可能已在基础镜像中，构建时验证

---

## 💡 解决方案

### **方案 A: 使用 Docker 容器安装（推荐）**

在离线环境的 Dockerfile 中使用本地 RPM 包安装：

```dockerfile
# 复制已下载的 RPM 包
COPY resources/zypper-packages/*.rpm /tmp/packages/

# 从本地安装（不需要网络）
RUN rpm -ivh --nodeps /tmp/packages/*.rpm && \
    rm -rf /tmp/packages
```

### **方案 B: 补充 ca-certificates（如需要）**

如果 Dockerfile 构建时发现缺少 CA 证书，可以在联网环境中下载：

```bash
# 查找并下载 ca-certificates
wget https://download.opensuse.org/distribution/leap/15.6/repo/oss/x86_64/ca-certificates-*.noarch.rpm
```

---

## 🔍 验证方法

在离线环境构建 Docker 镜像后，验证工具是否可用：

```bash
docker run --rm rancher/rancher:v2.10.3 bash -c "
  which git wget gawk iptables unzip tar gzip sed curl jq 2>&1
"
```

预期输出应显示所有工具的路径。

---

**生成时间**: 2026-05-24  
**镜像源**: openSUSE 官方仓库 + 阿里云开源镜像站  
**架构**: x86_64 (amd64)
