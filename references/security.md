# Security Model & Sandbox Design

## Overview

The Cross-IDE Sync Framework handles sensitive configuration data including API keys, authentication tokens, and conversation history. This document defines the security model and sandbox design.

## Threat Model

### Assets to Protect

| Asset | Sensitivity | Sync Risk |
|-------|------------|----------|
| API Keys/Tokens | HIGH | May be shared across IDEs unintentionally |
| Conversation History | MEDIUM | Context leakage between workspaces |
| MCP Server Config | HIGH | May contain internal endpoints |
| Custom Modes | LOW | Generally safe to share |
| Model Cache | LOW | No sensitive data |

### Attack Vectors

1. **Cross-IDE Data Leakage**: IDE A sees IDE B's private conversations
2. **Config Tampering**: Malicious mode injection via shared config
3. **Symlink Hijacking**: Attacker replaces symlink with link to sensitive path
4. **Privilege Escalation**: Abuse of admin rights for symlink creation

## Security Controls

### 1. Symlink Validation

```powershell
function Validate-SymlinkTarget {
    param($LinkPath, $TargetPath)
    
    # Resolve to absolute paths
    $absLink = (Get-Item $LinkPath).FullName
    $absTarget = (Get-Item $TargetPath).FullName
    
    # Check target is within expected hub
    $hubRoot = "D:\CrossIDE\shared"
    if (-not $absTarget.StartsWith($hubRoot)) {
        throw "Symlink target outside hub: $absTarget"
    }
    
    # Check for symlink chain loops
    $visited = @{}
    $current = $absTarget
    for ($i = 0; $i -lt 10; $i++) {
        if ($visited[$current]) { throw "Symlink loop detected" }
        $visited[$current] = $true
        $item = Get-Item $current -ErrorAction SilentlyContinue
        if (-not $item -or $item.LinkType -ne "SymbolicLink") { break }
        $current = $item.Target
    }
}
```

### 2. Sensitive Path Isolation

By default, the following paths are ALWAYS isolated (never synced):

| Path Pattern | Reason |
|-------------|--------|
| `**/credentials/**` | Authentication data |
| `**/.env*` | Environment variables |
| `**/secrets/**` | Secret storage |
| `**/sessions/**` | Active sessions |
| `**/tokens/**` | Access tokens |

### 3. File Permission Model

**Windows**:
- Central hub inherits NTFS permissions from parent
- Recommended: Only user account has read/write
- IDEs run as user, no additional permissions needed

**macOS/Linux**:
- Symlinks inherit target permissions
- Ensure hub directory is `700` (user only)

```bash
# Set secure permissions
chmod 700 /path/to/CrossIDE/shared
chmod 600 /path/to/CrossIDE/shared/*/*.json
```

### 4. Audit Logging

All sync operations are logged with:

| Field | Description |
|-------|-------------|
| Timestamp | ISO 8601 format |
| Operation | deploy/remove/verify/sync |
| Plugin ID | Target extension |
| IDE Name | Source/destination IDE |
| Result | success/failure |
| Error | Error message if failed |

**Log Location**: `D:\CrossIDE\logs\sync_<pluginId>.log`

## Sandbox Design

### Isolation Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| Full Sync | All data shared | Development environments |
| Config Only | Settings only, no history | Team sharing |
| Read-Only Hub | Hub is read-only for IDEs | Template distribution |
| Isolated | No sync, backup only | Sensitive projects |

### Configuration Profile

```yaml
# profiles/default.yaml
profile:
  name: "Default"
  isolationLevel: "full-sync"
  
  # Paths to always exclude
  excludePatterns:
    - "**/credentials/**"
    - "**/.env*"
    - "**/sessions/**"
    
  # Max file size for sync (MB)
  maxFileSizeMB: 50
  
  # Sync frequency (minutes, 0 = real-time)
  syncInterval: 0
  
  # Enable hash verification
  verifyHash: true
  
  # Require confirmation for new plugins
  requireConfirmation: true
```

## Incident Response

### If Symlink is Hijacked

1. **Detect**: `sync-engine.ps1 -Action Status` shows unexpected target
2. **Isolate**: Remove symlink immediately
3. **Restore**: `link-manager.ps1 -Action Restore`
4. **Audit**: Check logs for unauthorized changes

### If Data Leakage Occurs

1. **Identify**: Which data was exposed
2. **Rotate**: Change any compromised credentials
3. **Reconfigure**: Add sensitive paths to `isolate` list
4. **Review**: Check sync logs for scope of exposure

## Best Practices

1. **Never sync production credentials** - Use environment variables
2. **Review sync-rules.yaml** before deploying new plugins
3. **Regular backup verification** - Test restore procedure
4. **Keep scripts updated** - Security patches may be released
5. **Use separate hubs** for work vs personal IDEs
