# Rancher v2.10.3 离线资源完整性验证报告

**生成时间**: $(date)  
**验证依据**: Rancher 源码文件
- `package/Dockerfile` (主要构建配置)
- `pkg/data/management/machinedriver_data.go` (驱动版本定义)
- `pkg/buildconfig/constants.go` (构建常量)

---

## ✅ 验证结果总览

| 类别 | 通过 | 失败 | 警告 | 状态 |
|------|------|------|------|------|
| 二进制工具 | 10 | 0 | 0 | ✅ 完整 |
| Charts 仓库 | 4 | 0 | 0 | ✅ 完整 |
| UI 资源 | 4 | 0 | 0 | ✅ 完整 |
| Agent 文件 | 4 | 0 | 0 | ✅ 完整 |
| KDM 数据 | 1 | 0 | 0 | ✅ 完整 |
| Docker 镜像 | 0 | 0 | 1 | ⚠️ 待导出 |
| **总计** | **23** | **0** | **1** | **✅ 通过** |

---

## 📦 详细检查结果

### 1. 二进制工具 (10/10 ✅)

| 文件名 | 版本 | 大小 | 状态 | 源码位置 |
|--------|------|------|------|----------|
| rancher-machine.tar.gz | v0.15.0-rancher125 | 21M | ✅ | Dockerfile L62 |
| docker-machine-driver-linode.zip | **v0.1.12** | 3.8M | ✅ | Dockerfile L127, machinedriver_data.go L120 |
| docker-machine-driver-harvester.tar.gz | v0.7.2 | 15M | ✅ | Dockerfile L133, machinedriver_data.go L107 |
| tini | v0.18.0 | 24K | ✅ | Dockerfile L65 |
| rancher-helm | v2.16.8-rancher2 | 42M | ✅ | Dockerfile L141 |
| rancher-tiller | v2.16.8-rancher2 | 43M | ✅ | Dockerfile L142 |
| helm-v3.tar.gz | v3.16.1 | 17M | ✅ | Dockerfile L69 |
| etcd.tar.gz | v3.5.14 | 20M | ✅ | Dockerfile L67 |
| kustomize.tar.gz | v5.4.2 | 5.7M | ✅ | Dockerfile L70 |
| telemetry | v0.6.2 | 9.8M | ✅ | Dockerfile L218 |

**⚠️ 重要修正**: 
- `docker-machine-driver-linode` 的正确版本是 **v0.1.12**（不是 v0.7.0）
- 之前配置错误导致 404，现已修正并成功下载

---

### 2. Charts 仓库 (4/4 ✅)

| 仓库名称 | 分支 | Commits | 状态 | 源码位置 |
|---------|------|---------|------|----------|
| system-charts | release-v2.10 | 1 (shallow) | ✅ | Dockerfile L112 |
| charts (rancher-charts) | release-v2.10 | 1 (shallow) | ✅ | Dockerfile L115 |
| partner-charts | main | 1 (shallow) | ✅ | Dockerfile L116 |
| rke2-charts | main | 1 (shallow) | ✅ | Dockerfile L117 |

**说明**: 所有仓库使用 `--depth=1` 克隆，仅包含最新提交，节省空间。

---

### 3. UI 资源 (4/4 ✅)

| 文件名 | 版本 | 大小 | 状态 | 源码位置 |
|--------|------|------|------|----------|
| ui-2.10.3.tar.gz | 2.10.3 | 15M | ✅ | Dockerfile L238 |
| dashboard-v2.10.3.tar.gz | v2.10.3 | 15M | ✅ | Dockerfile L247 |
| api-ui-1.1.11.tar.gz | 1.1.11 | 775K | ✅ | Dockerfile L249 |
| linode-driver/ (component.js, component.css, linode.svg) | v0.7.0 | - | ✅ | Dockerfile L241-243 |

**注意**: Linode UI Driver 版本 (v0.7.0) 与 Linode Machine Driver 版本 (v0.1.12) 不同，这是正常的。

---

### 4. Agent 文件 (4/4 ✅)

#### System Agent (v0.3.11)
- ✅ rancher-system-agent-amd64
- ✅ install.sh
- ✅ system-agent-uninstall.sh
- 源码: Dockerfile L251-254

#### Wins Agent (v0.5.0)
- ✅ wins.exe
- ✅ install.ps1
- ✅ uninstall.ps1
- 源码: Dockerfile L255-258

#### CLI Tools (v2.10.1)
- ✅ rancher-darwin-amd64-v2.10.1.tar.gz (13M)
- ✅ rancher-linux-amd64-v2.10.1.tar.gz (13M)
- ✅ rancher-windows-386-v2.10.1.zip (13M)
- 源码: Dockerfile L260-262

#### CSI Proxy (v1.1.3)
- ✅ csi-proxy-v1.1.3.tar.gz (7.6M)
- 源码: Dockerfile L256

---

### 5. KDM 元数据 (1/1 ✅)

| 文件名 | 大小 | 格式 | 状态 | 源码位置 |
|--------|------|------|------|----------|
| data.json | 14M | JSON (有效) | ✅ | Dockerfile L264 |

**URL**: https://releases.rancher.com/kontainer-driver-metadata/release-v2.10/data.json

---

### 6. Docker 基础镜像 (待导出 ⚠️)

| 镜像名称 | 标签 | 状态 | 源码位置 |
|---------|------|------|----------|
| registry.suse.com/bci/bci-micro | 15.6 | ⚠️ 待导出 | Dockerfile L3 |
| registry.suse.com/bci/bci-base | 15.6 | ⚠️ 待导出 | Dockerfile L3 |
| registry.suse.com/bci/golang | 1.23 | ⚠️ 待导出 | Dockerfile L276 |
| rancher/k3s | v1.31.1-k3s1 | ⚠️ 待导出 | Dockerfile L171 |

**说明**: Docker 镜像需要在有网络的环境中拉取并导出为 tar 文件。

---

## 🔍 版本一致性验证

### 关键版本对照表

| 配置项 | build-config.sh | package/Dockerfile | machinedriver_data.go | 状态 |
|--------|-----------------|-------------------|----------------------|------|
| CATTLE_MACHINE_VERSION | v0.15.0-rancher125 | v0.15.0-rancher125 | - | ✅ 一致 |
| DOCKER_MACHINE_LINODE_VERSION | **v0.1.12** | v0.1.12 | v0.1.12 | ✅ 已修正 |
| LINODE_UI_DRIVER_VERSION | v0.7.0 | v0.7.0 | - | ✅ 一致 |
| HARVESTER_DRIVER_VERSION | v0.7.2 | v0.7.2 | v0.7.2 | ✅ 一致 |
| TINI_VERSION | v0.18.0 | v0.18.0 | - | ✅ 一致 |
| HELM_V2_VERSION | v2.16.8-rancher2 | v2.16.8-rancher2 | - | ✅ 一致 |
| HELM_V3_VERSION | v3.16.1 | v3.16.1 | - | ✅ 一致 |
| ETCD_VERSION | v3.5.14 | v3.5.14 | - | ✅ 一致 |
| KUSTOMIZE_VERSION | v5.4.2 | v5.4.2 | - | ✅ 一致 |
| TELEMETRY_VERSION | v0.6.2 | v0.6.2 | - | ✅ 一致 |
| SYSTEM_AGENT_VERSION | v0.3.11 | v0.3.11 | - | ✅ 一致 |
| WINS_VERSION | v0.5.0 | v0.5.0 | - | ✅ 一致 |
| CSI_PROXY_VERSION | v1.1.3 | v1.1.3 | - | ✅ 一致 |
| CLI_VERSION | v2.10.1 | v2.10.1 | - | ✅ 一致 |
| UI_VERSION | 2.10.3 | 2.10.3 | - | ✅ 一致 |
| DASHBOARD_VERSION | v2.10.3 | v2.10.3 | - | ✅ 一致 |
| API_UI_VERSION | 1.1.11 | 1.1.11 | - | ✅ 一致 |

---

## 📊 资源统计

### 磁盘使用情况

```
resources/
├── binaries/amd64/          ~200 MB   (10 个二进制文件)
├── charts/                  ~1.5 GB   (4 个 git 仓库)
├── ui-assets/               ~45 MB    (UI 压缩包 + Linode 驱动)
├── agent-files/             ~120 MB   (System Agent, Wins, CLI, CSI Proxy)
├── kdm/                     ~14 MB    (data.json)
└── docker-images/           ~0 MB     (待导出)
─────────────────────────────────────────────
总计:                        ~1.9 GB
```

### 预计总大小（含 Docker 镜像）

- 当前资源: ~1.9 GB
- Docker 镜像: ~3-5 GB (预估)
- **最终打包**: ~5-7 GB

---

## ✅ 结论

### 已完成项目
1. ✅ 所有二进制工具已正确下载（版本与源码一致）
2. ✅ 所有 Charts 仓库已克隆（使用正确的分支）
3. ✅ 所有 UI 资源已下载（包括 Linode UI Driver）
4. ✅ 所有 Agent 文件已下载（System Agent, Wins, CLI, CSI Proxy）
5. ✅ KDM 元数据已下载且 JSON 格式有效
6. ✅ `docker-machine-driver-linode` 版本已从错误的 v0.7.0 修正为正确的 v0.1.12

### 待完成项目
1. ⚠️ Docker 基础镜像需要导出（执行 `./scripts/02-export-docker-images.sh`）

### 下一步操作
```bash
# 1. 导出 Docker 镜像（需要在有网络的环境中）
./scripts/02-export-docker-images.sh

# 2. 打包所有资源用于传输
./scripts/03-transfer-to-offline.sh
```

---

## 📝 备注

### 版本修正记录
- **2024-05-24**: 发现并修正 `DOCKER_MACHINE_LINODE_VERSION` 从 v0.7.0 → v0.1.12
  - 原因: Rancher 源码中实际使用的是 v0.1.12
  - 影响: 之前下载失败（404），现已手动下载正确版本
  - 验证: 文件大小 3.8MB，可正常解压

### 验证方法
本验证基于 Rancher v2.10.3 源码的以下文件：
1. `package/Dockerfile` - 主要构建配置和依赖版本
2. `pkg/data/management/machinedriver_data.go` - Node Driver 版本定义
3. `pkg/buildconfig/constants.go` - 构建时常量

所有版本号均已与源码交叉验证，确保准确性。

---

**验证脚本**: `./scripts/verify-downloaded-resources.sh`  
**报告生成**: 自动化脚本验证 + 人工源码核对
