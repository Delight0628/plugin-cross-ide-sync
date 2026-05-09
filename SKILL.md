---
name: plugin-cross-ide-sync
description: Universal cross-IDE configuration sync framework for VS Code-compatible IDEs. Creates symbolic links to share plugin globalStorage, workspaceState, and custom config files across Cursor/Windsurf/Trae/CodeBuddy and any VS Code-based IDE. Supports dynamic config scanning, incremental sync, conflict detection, and rollback.
---

# Cross-IDE Configuration Sync Framework

Universal framework for sharing VS Code plugin data across multiple IDEs via centralized config storage and symbolic links.

## Quick Start

```powershell
# 1. Scan for installed IDEs and plugin configs
.\scripts\config-scanner.ps1 -Action Scan

# 2. Create sync rule config (edit templates/sync-rules.yaml)
.\scripts\link-manager.ps1 -Action CreateRule -PluginId "rooveterinaryinc.roo-cline"

# 3. Deploy symbolic links
.\scripts\link-manager.ps1 -Action Deploy

# 4. Verify sync status
.\scripts\link-manager.ps1 -Action Verify
```

## Architecture Overview

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

## Core Components

| Component | File | Purpose |
|-----------|------|---------|
| Config Scanner | [`scripts/config-scanner.ps1`](scripts/config-scanner.ps1) | Auto-detect IDEs and plugin paths |
| Link Manager | [`scripts/link-manager.ps1`](scripts/link-manager.ps1) | Create/verify/remove symbolic links |
| Sync Engine | [`scripts/sync-engine.ps1`](scripts/sync-engine.ps1) | Incremental sync with conflict detection |
| Platform Adapter | [`scripts/platform-adapter.ps1`](scripts/platform-adapter.ps1) | Cross-platform compatibility (Win/Mac/Linux) |
| Sync Rules | [`templates/sync-rules.yaml`](templates/sync-rules.yaml) | Define what to share per plugin |

## Workflow

1. **Scan**: Auto-discover installed IDEs and their plugin storage paths
2. **Map**: Generate config mapping based on sync-rules.yaml
3. **Deploy**: Create symbolic links from each IDE to central hub
4. **Sync**: Monitor and sync changes incrementally
5. **Verify**: Check link integrity and data consistency
6. **Rollback**: Restore from backup if needed

## Sync Rules Configuration

Edit [`templates/sync-rules.yaml`](templates/sync-rules.yaml) to define sharing rules:

```yaml
plugins:
  - pluginId: "rooveterinaryinc.roo-cline"
    share:
      - "globalStorage/settings/"
      - "globalStorage/cache/"
      - "globalStorage/tasks/"
    isolate:
      - "globalStorage/sessions/"
```

## Platform Support

| Platform | Mechanism | Admin Required |
|----------|-----------|----------------|
| Windows 10/11 | `mklink /D` | Yes |
| macOS | `ln -s` | No (with warnings) |
| Linux | `ln -s` | No |

## Safety Features

- Automatic backup before any change
- Link integrity verification
- Conflict detection with resolution strategies
- Full rollback capability
- Detailed logging to `logs/` directory

## References

- Architecture details: [`references/architecture.md`](references/architecture.md)
- Plugin examples: [`examples/plugin-mappings.md`](examples/plugin-mappings.md)
- Security model: [`references/security.md`](references/security.md)
