# ============================================================
# Cross-IDE Config Scanner - Auto-discover IDEs and plugin paths
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Scan","ListPlugins","ExportMap")]
    [string]$Action,
    
    [string]$OutputFile = "",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

# ============================================================
# Platform Detection
# ============================================================
function Get-PlatformInfo {
    if ($IsWindows) { return @{ Platform="Windows"; AppData="$env:APPDATA"; BasePath="$env:APPDATA" } }
    elseif ($IsMacOS) { return @{ Platform="macOS"; AppData="$env:HOME/Library/Application Support"; BasePath="$env:HOME" } }
    else { return @{ Platform="Linux"; AppData="$env:HOME/.config"; BasePath="$env:HOME" } }
}

$Platform = Get-PlatformInfo
Write-Host "=== Cross-IDE Config Scanner ===" -ForegroundColor Cyan
Write-Host "Platform: $($Platform.Platform)" -ForegroundColor Gray
Write-Host "Base Path: $($Platform.BasePath)" -ForegroundColor Gray
Write-Host ""

# ============================================================
# Known IDE Definitions
# ============================================================
$KnownIDEs = @(
    @{ Name="Cursor"; PathSuffix="Cursor"; IsVSCodeBased=$true },
    @{ Name="Windsurf"; PathSuffix="windsurf"; IsVSCodeBased=$true },
    @{ Name="Trae"; PathSuffix="trae"; IsVSCodeBased=$true },
    @{ Name="CodeBuddy"; PathSuffix="codebuddy"; IsVSCodeBased=$true },
    @{ Name="VSCode"; PathSuffix="Code - UI"; IsVSCodeBased=$true },
    @{ Name="CursorCanary"; PathSuffix="CursorCanary"; IsVSCodeBased=$true },
    @{ Name="WindsurfCanary"; PathSuffix="windsurf-canary"; IsVSCodeBased=$true }
)

# Known Plugin IDs and their storage patterns
$KnownPlugins = @(
    @{ 
        Id="rooveterinaryinc.roo-cline"
        Name="Roo Code"
        StoragePaths=@("globalStorage/rooveterinaryinc.roo-cline")
        ShareableDirs=@("settings","cache","tasks","modes")
    }
    @{ 
        Id="editorconfig.editorconfig"
        Name="EditorConfig"
        StoragePaths=@("globalStorage/editorconfig.editorconfig")
        ShareableDirs=@()
    }
    @{ 
        Id="github.copilot"
        Name="GitHub Copilot"
        StoragePaths=@("globalStorage/github.copilot","globalStorage/github.copilot-chat")
        ShareableDirs=@("settings")
    }
    @{ 
        Id="ms-vscode.vscode-json"
        Name="VS Code JSON"
        StoragePaths=@("globalStorage/ms-vscode.vscode-json")
        ShareableDirs=@()
    }
)

# ============================================================
# Scan Functions
# ============================================================
function Find-InstalledIDEs {
    Write-Host "[Step 1] Scanning for installed IDEs..." -ForegroundColor Cyan
    $FoundIDEs = @()
    
    foreach ($ide in $KnownIDEs) {
        $configPath = Join-Path (Join-Path $Platform.AppData $ide.PathSuffix) "User"
        if (Test-Path $configPath) {
            $FoundIDEs += @{
                Name = $ide.Name
                ConfigRoot = $configPath
                Exists = $true
                IsVSCodeBased = $ide.IsVSCodeBased
            }
            Write-Host "  [OK] $($ide.Name): $configPath" -ForegroundColor Green
        } else {
            Write-Host "  [SKIP] $($ide.Name): not found" -ForegroundColor Gray
        }
    }
    return $FoundIDEs
}

function Find-PluginPaths ($IdeConfigRoot, $PluginId) {
    $paths = @()
    $plugin = $KnownPlugins | Where-Object { $_.Id -eq $PluginId }
    if (-not $plugin) { return @() }
    
    foreach ($storagePath in $plugin.StoragePaths) {
        $fullPath = Join-Path $IdeConfigRoot $storagePath
        if (Test-Path $fullPath) {
            $paths += @{
                PluginId = $PluginId
                PluginName = $plugin.Name
                StoragePath = $storagePath
                FullPath = $fullPath
                Exists = $true
                FileCount = (Get-ChildItem $fullPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
            }
        }
    }
    return $paths
}

function Scan-AllPlugins ($IdeConfigRoot) {
    $foundPlugins = @()
    $globalStorage = Join-Path $IdeConfigRoot "globalStorage"
    
    if (Test-Path $globalStorage) {
        $pluginDirs = Get-ChildItem $globalStorage -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $pluginDirs) {
            $fileCount = (Get-ChildItem $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
            $foundPlugins += @{
                PluginId = $dir.Name
                StoragePath = "globalStorage/$($dir.Name)"
                FullPath = $dir.FullName
                Exists = $true
                FileCount = $fileCount
                IsKnown = ($KnownPlugins | Where-Object { $_.Id -eq $dir.Name }) -ne $null
            }
        }
    }
    return $foundPlugins
}

# ============================================================
# Action Implementations
# ============================================================
switch ($Action) {
    "Scan" {
        $installedIDEs = Find-InstalledIDEs
        Write-Host ""
        Write-Host "[Step 2] Scanning plugin storage..." -ForegroundColor Cyan
        
        $allPlugins = @()
        foreach ($ide in $installedIDEs) {
            Write-Host ""
            Write-Host "--- $($ide.Name) ---" -ForegroundColor Yellow
            $plugins = Scan-AllPlugins $ide.ConfigRoot
            foreach ($p in $plugins) {
                $status = if ($p.IsKnown) { "[KNOWN]" } else { "[UNKNOWN]" }
                Write-Host "  ${status} $($p.PluginId) ($($p.FileCount) files)" -ForegroundColor Gray
                $allPlugins += $p
            }
        }
        
        Write-Host ""
        Write-Host "=== Scan Complete ===" -ForegroundColor Green
        Write-Host "IDEs found: $($installedIDEs.Count)" -ForegroundColor White
        Write-Host "Plugin storage dirs: $($allPlugins.Count)" -ForegroundColor White
    }
    
    "ListPlugins" {
        $installedIDEs = Find-InstalledIDEs
        Write-Host ""
        Write-Host "[Step 2] Listing known plugin paths..." -ForegroundColor Cyan
        
        foreach ($ide in $installedIDEs) {
            Write-Host ""
            Write-Host "--- $($ide.Name) ---" -ForegroundColor Yellow
            foreach ($plugin in $KnownPlugins) {
                $paths = Find-PluginPaths $ide.ConfigRoot $plugin.Id
                foreach ($p in $paths) {
                    Write-Host "  [$($p.PluginName)] $($p.PluginId)" -ForegroundColor Cyan
                    Write-Host "    Path: $($p.FullPath)" -ForegroundColor Gray
                    Write-Host "    Files: $($p.FileCount)" -ForegroundColor Gray
                }
                if (-not $paths) {
                    Write-Host "  [SKIP] $($plugin.Id): not installed" -ForegroundColor Gray
                }
            }
        }
    }
    
    "ExportMap" {
        $installedIDEs = Find-InstalledIDEs
        $exportMap = @{
            Platform = $Platform.Platform
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            IDEs = @()
        }
        
        foreach ($ide in $installedIDEs) {
            $plugins = Scan-AllPlugins $ide.ConfigRoot
            $ideEntry = @{
                Name = $ide.Name
                ConfigRoot = $ide.ConfigRoot
                Plugins = $plugins
            }
            $exportMap.IDEs += $ideEntry
        }
        
        if ($OutputFile) {
            $exportMap | ConvertTo-Json -Depth 10 | Out-File $OutputFile -Encoding UTF8
            Write-Host ""
            Write-Host "Exported map to: $OutputFile" -ForegroundColor Green
        } else {
            $exportMap | ConvertTo-Json -Depth 10
        }
    }
}
