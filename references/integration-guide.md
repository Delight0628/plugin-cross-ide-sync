# Zero-Intrusion Integration Guide

## Overview

The Cross-IDE Sync Framework is designed to be **zero-intrusion** - it works alongside your existing IDE setup without modifying IDE behavior, startup流程, or user workflow.

## Integration Principles

1. **No IDE Configuration Changes**: IDEs continue to use their normal config paths
2. **No Plugin Modifications**: Extensions work exactly as designed
3. **Transparent Operation**: Symlinks are OS-level, invisible to applications
4. **Opt-Out Ready**: Any IDE can be excluded with one-line change

## Step-by-Step Integration

### Step 1: Install Framework

```powershell
# Framework is already in .roo/skills/plugin-cross-ide-sync/
# No additional installation needed
```

### Step 2: Define Sync Scope

Edit `templates/sync-rules.yaml` to specify which plugins to sync:

```yaml
plugins:
  - pluginId: "rooveterinaryinc.roo-cline"
    share:
      - "globalStorage/settings/"
      - "globalStorage/cache/"
      - "globalStorage/tasks/"
```

### Step 3: Run Scanner

```powershell
# Discover installed IDEs and plugins
.\scripts\config-scanner.ps1 -Action Scan
```

### Step 4: Deploy Links

```powershell
# Deploy for specific plugin
.\scripts\link-manager.ps1 -Action Deploy -PluginId "rooveterinaryinc.roo-cline"

# Deploy for all configured plugins
foreach ($plugin in @("rooveterinaryinc.roo-cline")) {
    .\scripts\link-manager.ps1 -Action Deploy -PluginId $plugin
}
```

### Step 5: Verify

```powershell
.\scripts\link-manager.ps1 -Action Verify -PluginId "rooveterinaryinc.roo-cline"
```

### Step 6: Restart IDEs

Restart all IDEs to pick up the new symlink structure.

## IDE-Specific Notes

### Cursor

- No special configuration needed
- Works with standard VS Code storage paths
- May require disabling Cursor's built-in sync to avoid conflicts

### Windsurf

- No special configuration needed
- Standard VS Code storage path: `%APPDATA%\windsurf\User\`

### Trae

- No special configuration needed
- Standard VS Code storage path: `%APPDATA%\trae\User\`

### CodeBuddy

- No special configuration needed
- Standard VS Code storage path: `%APPDATA%\codebuddy\User\`

### VS Code (Official)

- If using VS Code Settings Sync (cloud), disable it to avoid conflicts
- File > Preferences > Settings > Toggle Settings Sync: Off

## Excluding an IDE

To exclude an IDE from sync:

```powershell
# Remove symlinks for specific IDE
.\scripts\link-manager.ps1 -Action Remove -PluginId "rooveterinaryinc.roo-cline"

# Manually exclude by editing sync-rules.yaml
# Add to excludeIDEs list:
global:
  excludeIDEs:
    - "Cursor"
```

## Workflow Integration

### Daily Development

No changes to your daily workflow:

1. Open any IDE
2. Work normally
3. Config changes sync automatically

### Adding New Plugin

1. Edit `templates/sync-rules.yaml`
2. Run scanner: `.\scripts\config-scanner.ps1 -Action Scan`
3. Deploy: `.\scripts\link-manager.ps1 -Action Deploy -PluginId "<id>"`

### Removing Sync

```powershell
# Remove all symlinks
.\scripts\link-manager.ps1 -Action Remove -PluginId "rooveterinaryinc.roo-cline"

# Restore from backup
.\scripts\link-manager.ps1 -Action Restore
```

## CI/CD Integration

For team environments, sync framework can be integrated into setup scripts:

```powershell
# setup.ps1 - Team environment setup
$ErrorActionPreference = "Stop"

# Install framework
Write-Host "Setting up cross-IDE sync..." -ForegroundColor Cyan

# Deploy rules
.\scripts\link-manager.ps1 -Action Deploy -PluginId "rooveterinaryinc.roo-cline" -Force

# Verify
.\scripts\link-manager.ps1 -Action Verify -PluginId "rooveterinaryinc.roo-cline"

Write-Host "Setup complete!" -ForegroundColor Green
```

## Troubleshooting

### IDE Doesn't See Config

1. Verify symlink: `.\scripts\link-manager.ps1 -Action Verify`
2. Restart IDE
3. Check symlink target: `Get-Item <path> | Select-Object LinkType, Target`

### Config Not Syncing

1. Check logs: `Get-Content D:\CrossIDE\logs\sync_*.log`
2. Run sync engine: `.\scripts\sync-engine.ps1 -Action Sync`
3. Verify file permissions

### Permission Errors

1. Run PowerShell as Administrator
2. Check Windows Developer Mode is enabled (if required)
3. Verify NTFS permissions on central hub

## Advanced Integration

### Custom Central Hub Location

Edit `templates/sync-rules.yaml`:

```yaml
global:
  centralHub: "E:\MyConfig\CrossIDE\shared"
  backupRoot: "E:\MyConfig\CrossIDE\backup"
```

### Network Share (NAS)

For team environments with shared storage:

```yaml
global:
  centralHub: "\\\\server\\shared\\CrossIDE"
  conflictStrategy: "newest-wins"
```

**Note**: Network symlinks may require additional permissions.

### Multiple Workspaces

Each workspace can have its own sync configuration:

```yaml
# In workspace .vscode/settings.json
{
  "crossIDE.sync.workspace": true,
  "crossIDE.sync.plugins": ["rooveterinaryinc.roo-cline"]
}
```

## Maintenance

### Regular Tasks

| Task | Frequency | Command |
|------|-----------|--------|
| Verify links | Weekly | `.\scripts\link-manager.ps1 -Action Verify` |
| Check logs | Monthly | `Get-Content D:\CrossIDE\logs\*.log` |
| Prune old logs | Monthly | `.\scripts\sync-engine.ps1 -Action Prune` |
| Update framework | As needed | Pull latest from repository |

### Backup Strategy

```powershell
# Manual backup
.\scripts\link-manager.ps1 -Action Backup

# Backup is stored in: D:\CrossIDE\backup\<timestamp>\
```

## Support

For issues or questions:

1. Check logs: `D:\CrossIDE\logs\`
2. Run status check: `.\scripts\sync-engine.ps1 -Action Status`
3. Review architecture: `references/architecture.md`
4. Check security: `references/security.md`
