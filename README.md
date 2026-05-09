# Plugin Cross-IDE Sync

Universal cross-IDE configuration sync framework for VS Code-compatible IDEs.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-orange)

## Overview

Cross-IDE Sync enables seamless configuration synchronization for VS Code-compatible IDEs (Cursor, Windsurf, Trae, CodeBuddy, etc.) by using symbolic links to a centralized configuration hub. This ensures all your plugin settings, tasks, modes, and MCP configurations stay in sync across all your development environments.

## Features

- **Automatic IDE Discovery**: Scans for installed IDEs and their plugin storage paths
- **Symbolic Link Management**: Creates and manages symbolic links for transparent config sharing
- **Incremental Sync**: File hash-based change detection for efficient synchronization
- **Conflict Detection**: Multiple conflict resolution strategies (hub-wins, ide-wins, newest-wins)
- **Cross-Platform**: Supports Windows (mklink), macOS (ln -s), and Linux
- **Safety First**: Automatic backups, link verification, and full rollback capability
- **Zero Intrusion**: Doesn't modify IDE workflows or plugin behavior

## Architecture

```
+-----------------------------------------------------------+
|              Central Config Hub                            |
|              D:\CrossIDE\shared\                           |
|              +-- <plugin-id>/                              |
|              |   +-- globalStorage/                         |
|              |   +-- workspaceState/                        |
|              |   +-- custom-configs/                        |
|              +-- sync-rules.yaml                            |
+-----------------------------------------------------------+
            ^ symlink          ^ symlink        ^ symlink
    +------+------+    +------+------+    +------+------+
    | IDE 1       |    | IDE 2      |    | IDE N      |
    | Cursor      |    | Windsurf   |    | Trae       |
    +-------------+    +------------+    +------------+
```

## Quick Start

### Prerequisites

- Windows 10/11 (with Developer Mode enabled) or macOS/Linux
- PowerShell 5.1+ (Windows) or Bash (macOS/Linux)
- Administrator privileges on Windows (for symbolic links)

### Installation

```powershell
# 1. Clone this repository
git clone https://github.com/Delight0628/plugin-cross-ide-sync.git
cd plugin-cross-ide-sync

# 2. Scan for installed IDEs and plugin configs
.\scripts\config-scanner.ps1 -Action Scan

# 3. Create sync rule config (edit templates/sync-rules.yaml)
.\scripts\link-manager.ps1 -Action CreateRule -PluginId "rooveterinaryinc.roo-cline"

# 4. Deploy symbolic links (requires admin on Windows)
.\scripts\link-manager.ps1 -Action Deploy

# 5. Verify sync status
.\scripts\link-manager.ps1 -Action Verify
```

## Core Components

| Component | File | Purpose |
|-----------|------|---------|
| Config Scanner | [`scripts/config-scanner.ps1`](scripts/config-scanner.ps1) | Auto-detect IDEs and plugin paths |
| Link Manager | [`scripts/link-manager.ps1`](scripts/link-manager.ps1) | Create/verify/remove symbolic links |
| Sync Engine | [`scripts/sync-engine.ps1`](scripts/sync-engine.ps1) | Incremental sync with conflict detection |
| Platform Adapter | [`scripts/platform-adapter.ps1`](scripts/platform-adapter.ps1) | Cross-platform compatibility (Win/Mac/Linux) |
| Sync Rules | [`templates/sync-rules.yaml`](templates/sync-rules.yaml) | Define what to share per plugin |

## Supported IDEs

| IDE | Windows Path | Status |
|-----|--------------|--------|
| Cursor | `%APPDATA%\Cursor\User\globalStorage\` | Supported |
| Windsurf | `%APPDATA%\windsurf\User\globalStorage\` | Supported |
| Trae | `%APPDATA%\trae\User\globalStorage\` | Supported |
| CodeBuddy | `%APPDATA%\codebuddy\User\globalStorage\` | Supported |
| VS Code | `%APPDATA%\Code\User\globalStorage\` | Supported |

## Platform Support

| Platform | Mechanism | Admin Required |
|----------|-----------|----------------|
| Windows 10/11 | `mklink /D` | Yes |
| macOS | `ln -s` | No (with warnings) |
| Linux | `ln -s` | No |

## Safety Features

- **Automatic Backup**: Creates backups before any changes
- **Link Integrity Verification**: Verifies symbolic links after deployment
- **Conflict Detection**: Identifies and resolves configuration conflicts
- **Full Rollback**: Restore from backup if something goes wrong
- **Detailed Logging**: All operations logged to `logs/` directory

## References

- [Architecture Details](references/architecture.md) - System architecture and data flow
- [Integration Guide](references/integration-guide.md) - Zero-intrusion integration guide
- [Security Model](references/security.md) - Security controls and sandbox design
- [Plugin Mappings](examples/plugin-mappings.md) - Pre-configured plugin examples

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
