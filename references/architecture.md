# Cross-IDE Sync Architecture

## Overview

The Cross-IDE Sync Framework provides a universal solution for sharing VS Code plugin data across multiple IDEs using symbolic links and a centralized configuration hub.

## Architecture Diagram

```
+===================================================================+
|                    Central Config Hub                              |
|                    D:\CrossIDE\shared\                             |
|                                                                    |
|  +-- <plugin-id>/                                                 |
|  |   +-- globalStorage/                                           |
|  |   |   +-- settings/         (shared config files)              |
|  |   |   +-- cache/            (model/plugin cache)               |
|  |   |   +-- tasks/            (conversation history)             |
|  |   +-- workspaceState/    (per-workspace state)                 |
|  |   +-- custom-configs/  (user-defined shared files)             |
|  +-- sync-rules.yaml        (configuration)                        |
|  +-- logs/                (sync operation logs)                    |
+===================================================================+
               ^ symlink              ^ symlink           ^ symlink
    +-----------+-----------+  +------+------+  +-------+-------+
    | IDE 1 (Cursor)        |  | IDE 2 (Windsurf) | | IDE N (Trae) |
    | User/globalStorage/    |  | User/globalStorage/ | | User/globalStorage/ |
    |   +-- <plugin-id> ---+ |  +-- <plugin-id> ---+ | |   +-- <plugin-id> ---+ |
    +-----------------------+  +-------------------+  +----------------------+
```

## Component Design

### 1. Config Scanner (`config-scanner.ps1`)

**Purpose**: Auto-discover installed IDEs and their plugin storage paths.

**Workflow**:
1. Scan known IDE paths in `%APPDATA%`
2. Identify `globalStorage/` directories
3. Map plugin IDs to their storage locations
4. Export scan results as JSON map

**Output**: JSON structure containing IDE list, plugin paths, and file counts.

### 2. Link Manager (`link-manager.ps1`)

**Purpose**: Create, verify, and remove symbolic links.

**Operations**:
- `Deploy`: Create symlinks for specified plugin
- `Remove`: Remove symlinks, restore original config
- `Verify`: Check link integrity
- `Backup`: Create timestamped backup
- `Restore`: Restore from backup
- `CreateRule`: Generate sync-rules.yaml

**Safety**:
- Automatic backup before any modification
- Admin privilege check on Windows
- Link type verification after creation

### 3. Sync Engine (`sync-engine.ps1`)

**Purpose**: Incremental sync with conflict detection.

**Features**:
- File hash comparison for change detection
- Conflict identification between hub and IDEs
- Configurable conflict resolution strategy
- Log rotation and pruning

**Conflict Strategies**:
- `hub-wins`: Central hub config takes precedence
- `ide-wins`: First detected IDE config takes precedence
- `newest-wins`: Most recently modified file wins
- `manual`: Flag conflicts for user review

### 4. Platform Adapter (`platform-adapter.ps1`)

**Purpose**: Cross-platform compatibility layer.

**Supported Platforms**:
| Platform | Link Command | Admin Required |
|----------|-------------|----------------|
| Windows 10/11 | `mklink /D` | Yes |
| macOS | `ln -s` | No |
| Linux | `ln -s` | No |

## Data Flow

```
User modifies config in IDE A
        |
        v
File written to symlink target (central hub)
        |
        v
All other IDEs read from same central hub
        |
        v
Changes visible immediately (or after IDE refresh)
```

## Storage Layout

```
Central Hub (D:\CrossIDE\shared\)
├── <plugin-id>/
│   ├── globalStorage/
│   │   ├── settings/          # JSON/YAML config files
│   │   ├── cache/             # Model/plugin caches
│   │   ├── tasks/             # Conversation history
│   │   └── modes/             # Custom mode definitions
│   └── workspaceState/        # Per-workspace data (optional)
└── sync-rules.yaml            # Configuration

IDE Config (<APPDATA>/<IDE>/User/)
└── globalStorage/
    └── <plugin-id> ──(symlink)──> D:\CrossIDE\shared\<plugin-id>\
```

## Security Model

See [`references/security.md`](references/security.md) for detailed security considerations.

## Extension Points

### Adding New Plugin Support

1. Add plugin entry to `templates/sync-rules.yaml`
2. Define `share` and `isolate` directories
3. Run `link-manager.ps1 -Action Deploy -PluginId "<id>"`

### Custom Sync Rules

The YAML parser in `link-manager.ps1` supports:
- Multiple plugins per file
- Nested directory paths
- Comments and documentation
- Global settings override

## Performance Considerations

- Symbolic links add minimal overhead (OS-level redirect)
- File hash computation is cached where possible
- Incremental sync only processes changed files
- Log rotation prevents unbounded growth
