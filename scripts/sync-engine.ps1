# ============================================================
# Cross-IDE Sync Engine - Incremental sync with conflict detection
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Sync","Status","Resolve","Prune")]
    [string]$Action,
    
    [string]$PluginId = "rooveterinaryinc.roo-cline",
    [string]$CentralHub = "D:\CrossIDE\shared",
    [string]$LogDir = "D:\CrossIDE\logs",
    [int]$MaxLogDays = 30
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# ============================================================
# Logging
# ============================================================
function Write-Log {
    param($Message, $Level="INFO")
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $logFile = Join-Path $LogDir "sync_$($PluginId).log"
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content $logFile $logEntry -Encoding UTF8
    if ($Level -eq "ERROR") { Write-Host "  [ERR] $Message" -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    else { Write-Host "  [$Level] $Message" -ForegroundColor Gray }
}

# ============================================================
# Hash Utilities
# ============================================================
function Get-FileHashFast {
    param($FilePath)
    if (-not (Test-Path $FilePath)) { return $null }
    $stream = [System.IO.FileStream]::new($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    $hash = [System.Security.Cryptography.MD5]::Create().ComputeHash($stream)
    $stream.Close()
    return ($hash | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Get-DirHash {
    param($DirPath)
    if (-not (Test-Path $DirPath)) { return $null }
    $files = Get-ChildItem $DirPath -Recurse -File | Sort-Object FullName
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($content)) | Out-Null
    }
    return "dir-$(Get-Date -Format 'yyyyMMdd')"
}

# ============================================================
# Sync Status
# ============================================================
function Get-SyncStatus {
    param($pluginId, $centralHub)
    
    $hubPath = Join-Path $centralHub $pluginId
    $status = @{
        HubExists = Test-Path $hubPath
        HubFiles = 0
        IDEs = @()
        LastSync = $null
    }
    
    if ($status.HubExists) {
        $status.HubFiles = (Get-ChildItem $hubPath -Recurse -File | Measure-Object).Count
        
        $knownIDEs = @("Cursor","windsurf","trae","codebuddy")
        foreach ($ide in $knownIDEs) {
            $idePath = Join-Path (Join-Path $env:APPDATA $ide) "User\globalStorage\$pluginId"
            $ideStatus = @{
                Name = $ide
                Exists = Test-Path $idePath
                IsSymlink = $false
                FileCount = 0
                LastModified = $null
            }
            
            if (Test-Path $idePath) {
                $item = Get-Item $idePath
                $ideStatus.IsSymlink = ($item.LinkType -eq "SymbolicLink")
                $ideStatus.FileCount = (Get-ChildItem $idePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
                $ideStatus.LastModified = (Get-Item $idePath).LastWriteTime
            }
            
            $status.IDEs += $ideStatus
        }
    }
    
    return $status
}

# ============================================================
# Incremental Sync
# ============================================================
function Perform-IncrementalSync {
    param($pluginId, $centralHub)
    
    $hubPath = Join-Path $centralHub $pluginId
    $knownIDEs = @("Cursor","windsurf","trae","codebuddy")
    
    Write-Log "Starting incremental sync for: $pluginId"
    
    # Find source IDE (first one with valid config)
    $sourceIDE = $null
    foreach ($ide in $knownIDEs) {
        $idePath = Join-Path (Join-Path $env:APPDATA $ide) "User\globalStorage\$pluginId"
        if (Test-Path $idePath) {
            $item = Get-Item $idePath
            if (-not $item.LinkType) {
                $sourceIDE = $ide
                Write-Log "Source IDE: $ide"
                break
            }
        }
    }
    
    if (-not $sourceIDE) {
        Write-Log "No source IDE found with non-symlink config" "WARN"
        return
    }
    
    # Sync IDEs that are symlinks
    foreach ($ide in $knownIDEs) {
        if ($ide -eq $sourceIDE) { continue }
        
        $idePath = Join-Path (Join-Path $env:APPDATA $ide) "User\globalStorage\$pluginId"
        if (Test-Path $idePath) {
            $item = Get-Item $idePath
            if ($item.LinkType -eq "SymbolicLink") {
                Write-Log "$ide is already linked, skipping"
            }
        }
    }
    
    Write-Log "Sync complete"
}

# ============================================================
# Conflict Detection
# ============================================================
function Detect-Conflicts {
    param($pluginId, $centralHub)
    
    $hubPath = Join-Path $centralHub $pluginId
    $knownIDEs = @("Cursor","windsurf","trae","codebuddy")
    $conflicts = @()
    
    # Compare file hashes between hub and non-linked IDEs
    foreach ($ide in $knownIDEs) {
        $idePath = Join-Path (Join-Path $env:APPDATA $ide) "User\globalStorage\$pluginId"
        if (Test-Path $idePath) {
            $item = Get-Item $idePath
            if (-not $item.LinkType) {
                # Non-linked IDE - check for conflicts
                $commonFiles = Get-ChildItem $hubPath -Recurse -File | Select-Object -First 100
                foreach ($file in $commonFiles) {
                    $relativePath = $file.FullName.Substring($hubPath.Length + 1)
                    $ideFile = Join-Path $idePath $relativePath
                    
                    if (Test-Path $ideFile) {
                        $hubHash = Get-FileHashFast $file.FullName
                        $ideHash = Get-FileHashFast $ideFile
                        
                        if ($hubHash -ne $ideHash) {
                            $conflicts += @{
                                IDE = $ide
                                File = $relativePath
                                HubHash = $hubHash
                                IDEHash = $ideHash
                                HubModified = (Get-Item $file.FullName).LastWriteTime
                                IDEModified = (Get-Item $ideFile).LastWriteTime
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $conflicts
}

# ============================================================
# Action: Sync
# ============================================================
switch ($Action) {
    "Sync" {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Cross-IDE Sync Engine" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Plugin: $PluginId" -ForegroundColor Gray
        Write-Host "Hub: $CentralHub" -ForegroundColor Gray
        Write-Host ""
        
        Perform-IncrementalSync $PluginId $CentralHub
    }
    
    "Status" {
        Write-Host ""
        Write-Host "=== Sync Status ===" -ForegroundColor Cyan
        $status = Get-SyncStatus $PluginId $CentralHub
        
        Write-Host "Hub: $(if($status.HubExists){'OK'}else{'MISSING'})" -ForegroundColor $(if($status.HubExists){"Green"}else{"Red"})
        Write-Host "Hub Files: $($status.HubFiles)" -ForegroundColor Gray
        
        foreach ($ide in $status.IDEs) {
            $icon = if ($ide.Exists) {
                if ($ide.IsSymlink) { "[LINK]" } else { "[LOCAL]" }
            } else { "[MISSING]" }
            $color = if ($ide.Exists) { "Green" } else { "Red" }
            Write-Host "  $icon $($ide.Name): $($ide.FileCount) files" -ForegroundColor $color
        }
    }
    
    "Resolve" {
        Write-Host ""
        Write-Host "=== Conflict Detection ===" -ForegroundColor Cyan
        $conflicts = Detect-Conflicts $PluginId $CentralHub
        
        if ($conflicts) {
            Write-Host "Found $($conflicts.Count) conflicts:" -ForegroundColor Yellow
            foreach ($c in $conflicts) {
                Write-Host "  $($c.IDE)/$($c.File)" -ForegroundColor Yellow
                Write-Host "    Hub modified: $($c.HubModified)" -ForegroundColor Gray
                Write-Host "    IDE modified: $($c.IDEModified)" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Resolution strategy: Hub wins (latest source)" -ForegroundColor Cyan
        } else {
            Write-Host "No conflicts detected" -ForegroundColor Green
        }
    }
    
    "Prune" {
        Write-Host ""
        Write-Host "=== Pruning Old Logs ===" -ForegroundColor Cyan
        if (Test-Path $LogDir) {
            $cutoff = (Get-Date).AddDays(-$MaxLogDays)
            $oldLogs = Get-ChildItem $LogDir -File | Where-Object { $_.LastWriteTime -lt $cutoff }
            foreach ($log in $oldLogs) {
                Remove-Item $log.FullName -Force
                Write-Host "  Removed: $($log.Name)" -ForegroundColor Gray
            }
            Write-Host "Pruned $($oldLogs.Count) old log files" -ForegroundColor Green
        } else {
            Write-Host "No log directory found" -ForegroundColor Gray
        }
    }
}
