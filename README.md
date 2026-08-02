<div align="center">

# 🔗 Plugin Cross-IDE Sync

**通用跨 IDE 配置同步框架**

> 一键创建符号链接，让 Cursor / Windsurf / Trae / CodeBuddy 的插件配置完美共享

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-orange)
![VS Code Compatible](https://img.shields.io/badge/VS%20Code-compatible-blueviolet)
![Status](https://img.shields.io/badge/status-active-brightgreen)

</div>

---

## 📖 项目简介

**Plugin Cross-IDE Sync** 是一个面向 VS Code 兼容 IDE 的通用跨 IDE 配置同步框架。通过创建符号链接（symbolic links）将多个 IDE 的插件 `globalStorage`、`workspaceState` 和自定义配置文件集中管理，实现一处修改、处处生效。

> 🎯 **痛点解决**：同时使用 Cursor、Windsurf、Trae 等 IDE 时，每个 IDE 都有独立的插件存储目录，导致配置割裂、重复设置。本工具让你告别这种烦恼。

---

## ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🔍 **自动 IDE 发现** | 扫描已安装的 IDE 及其插件存储路径 |
| 🔗 **符号链接管理** | 创建和管理符号链接，实现透明配置共享 |
| 🔄 **增量同步** | 基于文件哈希的变更检测，高效同步 |
| ⚠️ **冲突检测** | 多种冲突解决策略：hub-wins / ide-wins / newest-wins |
| 🌐 **跨平台支持** | Windows (mklink) / macOS (ln -s) / Linux |
| 🛡️ **安全保障** | 自动备份、链接验证、完整回滚能力 |
| 🎭 **零侵入** | 不修改 IDE 工作流或插件行为 |

---

## 🏗️ 架构概览

```
┌─────────────────────────────────────────────┐
│           中央配置中心 (Config Hub)            │
│           D:\CrossIDE\shared\                │
│           ├── <plugin-id>/                   │
│           │   ├── globalStorage/             │
│           │   ├── workspaceState/            │
│           │   └── custom-configs/            │
│           └── sync-rules.yaml                │
└─────────────────────────────────────────────┘
          ↑ symlink          ↑ symlink         ↑ symlink
   ┌──────┴──────┐    ┌──────┴──────┐    ┌──────┴──────┐
   │   Cursor    │    │  Windsurf   │    │    Trae     │
   │  (IDE 1)    │    │   (IDE 2)   │    │   (IDE N)   │
   └─────────────┘    └─────────────┘    └─────────────┘
```

---

## 🚀 快速开始

### 环境要求

- **操作系统**：Windows 10/11（需开启开发者模式）、macOS 或 Linux
- **运行环境**：PowerShell 5.1+（Windows）或 Bash（macOS/Linux）
- **权限**：Windows 需要管理员权限（用于创建符号链接）

### 安装步骤

```powershell
# 1️⃣ 克隆仓库
git clone https://github.com/Delight0628/plugin-cross-ide-sync.git
cd plugin-cross-ide-sync

# 2️⃣ 扫描已安装的 IDE 和插件配置
.\scripts\config-scanner.ps1 -Action Scan

# 3️⃣ 创建同步规则（编辑 templates/sync-rules.yaml）
.\scripts\link-manager.ps1 -Action CreateRule -PluginId "rooveterinaryinc.roo-cline"

# 4️⃣ 部署符号链接（Windows 需要管理员权限）
.\scripts\link-manager.ps1 -Action Deploy

# 5️⃣ 验证同步状态
.\scripts\link-manager.ps1 -Action Verify
```

---

## 📦 核心组件

| 组件 | 文件 | 功能 |
|------|------|------|
| 🔍 Config Scanner | [`scripts/config-scanner.ps1`](scripts/config-scanner.ps1) | 自动发现 IDE 及插件路径 |
| 🔗 Link Manager | [`scripts/link-manager.ps1`](scripts/link-manager.ps1) | 创建/验证/移除符号链接 |
| ⚙️ Sync Engine | [`scripts/sync-engine.ps1`](scripts/sync-engine.ps1) | 增量同步与冲突检测 |
| 🌐 Platform Adapter | [`scripts/platform-adapter.ps1`](scripts/platform-adapter.ps1) | 跨平台兼容层（Win/Mac/Linux） |
| 📋 Sync Rules | [`templates/sync-rules.yaml`](templates/sync-rules.yaml) | 定义每个插件的共享规则 |

---

## 💻 支持的 IDE

| IDE | 配置路径 | 状态 |
|-----|---------|------|
| 🖱️ Cursor | `%APPDATA%\Cursor\User\globalStorage\` | ✅ 已支持 |
| 🌊 Windsurf | `%APPDATA%\windsurf\User\globalStorage\` | ✅ 已支持 |
| 🚀 Trae | `%APPDATA%\trae\User\globalStorage\` | ✅ 已支持 |
| 🤖 CodeBuddy | `%APPDATA%\codebuddy\User\globalStorage\` | ✅ 已支持 |
| 📝 VS Code | `%APPDATA%\Code\User\globalStorage\` | ✅ 已支持 |

---

## 🖥️ 平台支持

| 平台 | 机制 | 需要管理员权限 |
|------|------|----------------|
| Windows 10/11 | `mklink /D` | ✅ 是 |
| macOS | `ln -s` | ⚠️ 否（有警告） |
| Linux | `ln -s` | ❌ 否 |

---

## 🛡️ 安全特性

- **🔄 自动备份** — 每次变更前自动创建备份
- **✅ 链接完整性验证** — 部署后自动验证符号链接
- **⚠️ 冲突检测** — 识别并解决配置冲突
- **⏪ 完整回滚** — 出错时可从备份恢复
- **📝 详细日志** — 所有操作记录在 `logs/` 目录

---

## 📚 参考文档

- [架构详解](references/architecture.md) — 系统架构与数据流
- [集成指南](references/integration-guide.md) — 零侵入集成方案
- [安全模型](references/security.md) — 安全控制与沙箱设计
- [插件映射](examples/plugin-mappings.md) — 预配置插件示例

---

## 🤝 参与贡献

欢迎参与贡献！你可以通过以下方式参与：

1. **Fork** 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 **Pull Request**

---

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐ Star 支持一下！**

</div>
