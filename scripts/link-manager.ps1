# ============================================================
# Cross-IDE Link Manager - Create/verify/remove symbolic links
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Deploy","Remove","Verify","Backup","Restore","CreateRule")]
    [string]$Action,
    
    [string]$PluginId = "",
    [string]$CentralHub = "D:\CrossIDE\shared",
    [string]$BackupRoot = "D:\CrossIDE\backup",
    [string]$RulesFile = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# ============================================================
# Utility Functions
# ============================================================
function Write-Step { param($msg) Write-Host "" ; Write-Host "[Step] $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-SKIP { param($msg) Write-Host "  [SKIP] $msg" -ForegroundColor Gray }
function Write-WARN { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-ERR { param($msg) Write-Host "  [ERR] $msg" -ForegroundColor Red }

function Test-AdminPriv {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================
# IDE Discovery
# ============================================================
function Get-InstalledIDEs {
    $KnownIDEs = @("Cursor","windsurf","trae","codebuddy","Code - UI","CursorCanary","windsurf-canary")
    $Result = @()
    foreach ($name in $KnownIDEs) {
        $configPath = Join-Path (Join-Path $env:APPData $name) "User"
        if (-not (Test-Path $configPath)) { $configPath = Join-Path (Join-Path $env:APPDATA $name) "User" }
        if (Test-Path $configPath) {
            $Result += @{ Name=$name; ConfigRoot=$configPath }
        }
    }
    return $Result
}

# ============================================================
# Sync Rules Parser
# ============================================================
function Parse-SyncRules {
    param($rulesFile)
    
    if (-not $rulesFile -or -not (Test-Path $rulesFile)) {
        $defaultRules = Join-Path $RootDir "templates\sync-rules.yaml"
        if (Test-Path $defaultRules) { $rulesFile = $defaultRules } else { return $null }
    }
    
    # Simple YAML parser for our structure
    $rules = @{}
    $currentPlugin = $null
    $currentSection = $null
    
    Get-Content $rulesFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -match "^-\s+pluginId:\s*(.+)") {
            $currentPlugin = $matches[1].Trim('"')
            $rules[$currentPlugin] = @{ Share=@(); Isolate=@() }
            $currentSection = $null
        } elseif ($line -match "^share:" -and $currentPlugin) {
            $currentSection = "Share"
        } elseif ($line -match "^isolate:" -and $currentPlugin) {
            $currentSection = "Isolate"
        } elseif ($line -match "^\s+-\s+\"?(.+)\"?" -and $currentSection -and $currentPlugin) {
            $path = $matches[1].Trim('"')
            if ($currentSection -eq "Share") { $rules[$currentPlugin].Share += $path }
            else { $rules[$currentPlugin].Isolate += $path }
        }
    }
    return $rules
}

function Get-DefaultRules {
    return @{
        "rooveterinaryinc.roo-cline" = @{
            Share = @("globalStorage/settings","globalStorage/cache","globalStorage/tasks")
            Isolate = @()
        }
    }
}

# ============================================================
# Core Operations
# ============================================================
function Create-CentralHub {
    param($hubPath, $pluginId)
    $pluginHub = Join-Path $hubPath $pluginId
    if (-not (Test-Path $pluginHub)) {
        New-Item -ItemType Directory -Path $pluginHub -Force | Out-Null
        Write-OK "Created hub: $pluginHub"
    }
    return $pluginHub
}

function Create-Symlink {
    param($targetPath, $linkPath, $pluginId)
    
    # Ensure parent directory exists
    $parentDir = Split-Path $linkPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    # Remove existing file/dir if present
    if (Test-Path $linkPath) {
        $item = Get-Item $linkPath
        if ($item.LinkType -eq "SymbolicLink") {
            if (-not $Force) {
                Write-WARN "Symlink exists: $linkPath (use -Force to replace)"
                return $false
            }
            Remove-Item $linkPath -Force
        } else {
            Write-WARN "Existing file (not symlink): $linkPath"
            return $false
        }
    }
    
    # Create symlink
    try {
        $result = cmd /c "mklink /D `"$linkPath`" `"$targetPath`"" 2>&1
        if (Test-Path $linkPath) {
            $linkInfo = Get-Item $linkPath
            if ($linkInfo.LinkType -eq "SymbolicLink") {
                Write-OK "Symlink created: $linkPath -> $targetPath"
                return $true
            }
        }
        Write-ERR "Failed to create symlink: $result"
        return $false
    } catch {
        Write-ERR "Exception: $($_.Exception.Message)"
        return $false
    }
}

function Backup-PluginConfig {
    param($configPath, $pluginId, $ideName)
    $backupDir = Join-Path $BackupRoot $Timestamp
    $backupPath = Join-Path $backupDir "$ideName`_$pluginId"
    
    if (Test-Path $configPath) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Copy-Item -Path $configPath -Destination $backupPath -Recurse -Force
        Write-OK "Backed up: $configPath -> $backupPath"
        return $backupPath
    }
    return $null
}

# ============================================================
# Action: Deploy
# ============================================================
function Deploy-Symlinks {
    param($pluginId, $centralHub, $rules)
    
    Write-Step "Deploying symbolic links for plugin: $pluginId"
    
    # Get rules for this plugin
    $pluginRules = $null
    if ($rules) {
        $pluginRules = $rules[$pluginId]
    }
    if (-not $pluginRules) {
        $defaultRules = Get-DefaultRules
        $pluginRules = $defaultRules[$pluginId]
        if (-not $pluginRules) {
            Write-WARN "No rules found for $pluginId, using defaults"
            $pluginRules = @{ Share=@("globalStorage"); Isolate=@() }
        }
    }
    
    # Create central hub
    $pluginHub = Create-CentralHub $centralHub $pluginId
    Write-OK "Central hub: $pluginHub"
    
    # Copy existing config to hub
    Write-Step "Copying existing config to central hub"
    $sourceIDE = Get-InstalledIDEs | Select-Object -First 1
    if ($sourceIDE) {
        $sourcePath = Join-Path $sourceIDE.ConfigRoot "globalStorage\$pluginId"
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $pluginHub -Recurse -Force
            Write-OK "Copied from: $sourcePath"
        } else {
            Write-WARN "Source not found, creating empty structure"
        }
    }
    
    # Deploy to each IDE
    Write-Step "Creating symlinks for each IDE"
    $installedIDEs = Get-InstalledIDEs
    $successCount = 0
    $failCount = 0
    
    foreach ($ide in $installedIDEs) {
        Write-Host ""
        Write-Host "--- $($ide.Name) ---" -ForegroundColor Yellow
        
        foreach ($sharePath in $pluginRules.Share) {
            $linkPath = Join-Path $ide.ConfigRoot $sharePath
            $hubSubPath = Join-Path $pluginHub (Split-Path $sharePath -Leaf)
            
            # Create subdirectory in hub
            if (-not (Test-Path $hubSubPath)) {
                New-Item -ItemType Directory -Path $hubSubPath -Force | Out-Null
            }
            
            # Backup before replacing
            if (Test-Path $linkPath) {
                Backup-PluginConfig $linkPath $pluginId $ide.Name
            }
            
            # Create symlink
            if (Create-Symlink $hubSubPath $linkPath $pluginId) {
                $successCount++
            } else {
                $failCount++
            }
        }
    }
    
    Write-Host ""
    Write-Host "=== Deployment Complete ===" -ForegroundColor Green
    Write-Host "Success: $successCount | Failed: $failCount" -ForegroundColor White
}

# ============================================================
# Action: Remove
# ============================================================
function Remove-Symlinks {
    param($pluginId)
    
    Write-Step "Removing symbolic links for plugin: $pluginId"
    
    $installedIDEs = Get-InstalledIDEs
    $defaultRules = Get-DefaultRules
    $pluginRules = $defaultRules[$pluginId]
    if (-not $pluginRules) { $pluginRules = @{ Share=@("globalStorage"); Isolate=@() } }
    
    foreach ($ide in $installedIDEs) {
        Write-Host ""
        Write-Host "--- $($ide.Name) ---" -ForegroundColor Yellow
        
        foreach ($sharePath in $pluginRules.Share) {
            $linkPath = Join-Path $ide.ConfigRoot $sharePath
            if (Test-Path $linkPath) {
                $item = Get-Item $linkPath
                if ($item.LinkType -eq "SymbolicLink") {
                    Remove-Item $linkPath -Force
                    Write-OK "Removed symlink: $linkPath"
                } else {
                    Write-WARN "Not a symlink, skipped: $linkPath"
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "=== Removal Complete ===" -ForegroundColor Green
}

# ============================================================
# Action: Verify
# ============================================================
function Verify-Symlinks {
    param($pluginId)
    
    Write-Step "Verifying symbolic links for plugin: $pluginId"
    
    $installedIDEs = Get-InstalledIDEs
    $defaultRules = Get-DefaultRules
    $pluginRules = $defaultRules[$pluginId]
    if (-not $pluginRules) { $pluginRules = @{ Share=@("globalStorage"); Isolate=@() } }
    
    $allOK = $true
    foreach ($ide in $installedIDEs) {
        Write-Host ""
        Write-Host "--- $($ide.Name) ---" -ForegroundColor Yellow
        
        foreach ($sharePath in $pluginRules.Share) {
            $linkPath = Join-Path $ide.ConfigRoot $sharePath
            if (Test-Path $linkPath) {
                $item = Get-Item $linkPath
                if ($item.LinkType -eq "SymbolicLink") {
                    $target = $item.Target
                    Write-OK "OK: $sharePath -> $target"
                } else {
                    Write-ERR "FAIL: Not a symlink (type: $($item.LinkType))"
                    $allOK = $false
                }
            } else {
                Write-ERR "FAIL: Not found"
                $allOK = $false
            }
        }
    }
    
    Write-Host ""
    if ($allOK) {
        Write-Host "=== All Links Verified OK ===" -ForegroundColor Green
    } else {
        Write-Host "=== Some Links Have Issues ===" -ForegroundColor Red
    }
}

# ============================================================
# Action: Backup
# ============================================================
function Backup-All {
    param($pluginId)
    
    Write-Step "Backing up all configs for plugin: $pluginId"
    
    $backupDir = Join-Path $BackupRoot $Timestamp
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    $installedIDEs = Get-InstalledIDEs
    foreach ($ide in $installedIDEs) {
        $pluginPath = Join-Path $ide.ConfigRoot "globalStorage\$pluginId"
        if (Test-Path $pluginPath) {
            $dest = Join-Path $backupDir "$($ide.Name)_globalStorage"
            Copy-Item -Path $pluginPath -Destination $dest -Recurse -Force
            Write-OK "$($ide.Name) -> $dest"
        }
    }
    
    Write-Host ""
    Write-Host "=== Backup Complete: $backupDir ===" -ForegroundColor Green
}

# ============================================================
# Action: Restore
# ============================================================
function Restore-FromBackup {
    param($backupDir)
    
    if (-not $backupDir -or -not (Test-Path $backupDir)) {
        # Find latest backup
        $latest = Get-ChildItem $BackupRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { $backupDir = $latest.FullName } else {
            Write-ERR "No backup found"
            return
        }
    }
    
    Write-Step "Restoring from backup: $backupDir"
    
    $installedIDEs = Get-InstalledIDEs
    foreach ($ide in $installedIDEs) {
        $backupPath = Join-Path $backupDir "$($ide.Name)_globalStorage"
        if (Test-Path $backupPath) {
            $targetPath = Join-Path $ide.ConfigRoot "globalStorage\$PluginId"
            $parentDir = Split-Path $targetPath -Parent
            
            # Remove symlink if exists
            if (Test-Path $targetPath) {
                $item = Get-Item $targetPath
                if ($item.LinkType -eq "SymbolicLink") { Remove-Item $targetPath -Force }
            }
            
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            Copy-Item -Path $backupPath -Destination $targetPath -Recurse -Force
            Write-OK "Restored: $($ide.Name)"
        }
    }
    
    Write-Host ""
    Write-Host "=== Restore Complete ===" -ForegroundColor Green
}

# ============================================================
# Action: CreateRule
# ============================================================
function Create-RuleFile {
    param($pluginId)
    
    $templateFile = Join-Path $RootDir "templates\sync-rules.yaml"
    $targetFile = Join-Path $RootDir "templates\sync-rules.yaml"
    
    if (Test-Path $targetFile) {
        Write-WARN "Rules file already exists: $targetFile"
        Write-Host "Edit it manually to add rules for: $pluginId" -ForegroundColor Yellow
    } else {
        $defaultContent = @"
# Cross-IDE Sync Rules Configuration
# Edit this file to define which plugin data to share/isolate

plugins:
  - pluginId: "$pluginId"
    share:
      - "globalStorage/settings"
      - "globalStorage/cache"
      - "globalStorage/tasks"
    isolate: []

# Add more plugins below:
#  - pluginId: "github.copilot"
#    share:
#      - "globalStorage/github.copilot"
#    isolate: []
"@
        Set-Content $targetFile $defaultContent -Encoding UTF8
        Write-OK "Created rules file: $targetFile"
    }
}

# ============================================================
# Main
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cross-IDE Link Manager" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Central Hub: $CentralHub" -ForegroundColor Gray
Write-Host "Backup Root: $BackupRoot" -ForegroundColor Gray
Write-Host ""

# Check admin for deploy/remove
if ($Action -in @("Deploy","Remove") -and -not (Test-AdminPriv)) {
    Write-ERR "Admin privileges required for this action."
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    exit 1
}

# Load rules
$rules = $null
if ($RulesFile) { $rules = Parse-SyncRules $RulesFile }
if (-not $rules) { $rules = Get-DefaultRules }

# Execute action
switch ($Action) {
    "Deploy" { Deploy-Symlinks $PluginId $CentralHub $rules }
    "Remove" { Remove-Symlinks $PluginId }
    "Verify" { Verify-Symlinks $PluginId }
    "Backup" { Backup-All $PluginId }
    "Restore" { Restore-FromBackup "" }
    "CreateRule" { Create-RuleFile $PluginId }
}
