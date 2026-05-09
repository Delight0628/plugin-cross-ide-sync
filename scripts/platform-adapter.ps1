# ============================================================
# Cross-IDE Platform Adapter - Cross-platform compatibility
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Detect","CreateLink","RemoveLink","VerifyLink","GetConfigRoot")]
    [string]$Action,
    
    [string]$TargetPath = "",
    [string]$LinkPath = "",
    [string]$IDEName = ""
)

$ErrorActionPreference = "Stop"

# ============================================================
# Platform Detection
# ============================================================
function Get-PlatformInfo {
    $info = @{
        OS = "Unknown"
        IsWindows = $false
        IsMacOS = $false
        IsLinux = $false
        HomeDir = ""
        AppData = ""
        SupportsSymlinks = $false
        RequiresAdmin = $false
    }
    
    if ($IsWindows) {
        $info.OS = "Windows"
        $info.IsWindows = $true
        $info.HomeDir = $env:USERPROFILE
        $info.AppData = $env:APPDATA
        $info.SupportsSymlinks = $true
        $info.RequiresAdmin = $true  # Windows requires admin for symlinks
    }
    elseif ($IsMacOS) {
        $info.OS = "macOS"
        $info.IsMacOS = $true
        $info.HomeDir = $env:HOME
        $info.AppData = "$env:HOME/Library/Application Support"
        $info.SupportsSymlinks = $true
        $info.RequiresAdmin = $false  # macOS doesn't require admin
    }
    elseif ($IsLinux) {
        $info.OS = "Linux"
        $info.IsLinux = $true
        $info.HomeDir = $env:HOME
        $info.AppData = "$env:HOME/.config"
        $info.SupportsSymlinks = $true
        $info.RequiresAdmin = $false  # Linux doesn't require admin
    }
    
    return $info
}

# ============================================================
# IDE Config Root by Platform
# ============================================================
function Get-IDEConfigRoot {
    param($Platform, $IDEName)
    
    if ($Platform.IsWindows) {
        return Join-Path (Join-Path $env:APPDATA $IDEName) "User"
    }
    elseif ($Platform.IsMacOS) {
        return Join-Path (Join-Path "$env:HOME/Library/Application Support" $IDEName) "User"
    }
    elseif ($Platform.IsLinux) {
        return Join-Path (Join-Path "$env:HOME/.config" $IDEName) "User"
    }
    
    return $null
}

# ============================================================
# Cross-Platform Symlink Operations
# ============================================================
function Create-CrossPlatformLink {
    param($TargetPath, $LinkPath, $Platform)
    
    Write-Host "Platform: $($Platform.OS)" -ForegroundColor Gray
    Write-Host "Target: $TargetPath" -ForegroundColor Gray
    Write-Host "Link: $LinkPath" -ForegroundColor Gray
    Write-Host ""
    
    # Ensure parent directory exists
    $parentDir = Split-Path $LinkPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        Write-Host "  Created parent directory: $parentDir" -ForegroundColor Gray
    }
    
    # Remove existing if present
    if (Test-Path $LinkPath) {
        $existing = Get-Item $LinkPath -ErrorAction SilentlyContinue
        if ($existing.LinkType) {
            Remove-Item $LinkPath -Force
            Write-Host "  Removed existing symlink" -ForegroundColor Gray
        } else {
            Write-Host "  ERROR: Path exists and is not a symlink" -ForegroundColor Red
            return $false
        }
    }
    
    # Create link based on platform
    try {
        if ($Platform.IsWindows) {
            # Windows: mklink /D
            $result = cmd /c "mklink /D `"$LinkPath`" `"$TargetPath`"" 2>&1
            Write-Host "  mklink output: $result" -ForegroundColor Gray
        }
        elseif ($Platform.IsMacOS -or $Platform.IsLinux) {
            # macOS/Linux: ln -s
            $result = ln -s "`"$TargetPath`"" "`"$LinkPath`"" 2>&1
            Write-Host "  ln output: $result" -ForegroundColor Gray
        }
        
        # Verify
        if (Test-Path $LinkPath) {
            $linkInfo = Get-Item $LinkPath -ErrorAction SilentlyContinue
            if ($linkInfo.LinkType) {
                Write-Host "  [OK] Symlink created successfully" -ForegroundColor Green
                return $true
            }
        }
        
        Write-Host "  [ERR] Symlink creation failed" -ForegroundColor Red
        return $false
    } catch {
        Write-Host "  [ERR] Exception: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-CrossPlatformLink {
    param($LinkPath, $Platform)
    
    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath
        if ($item.LinkType) {
            Remove-Item $LinkPath -Force
            Write-Host "  [OK] Removed symlink: $LinkPath" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [WARN] Not a symlink, skipped: $LinkPath" -ForegroundColor Yellow
            return $false
        }
    }
    Write-Host "  [SKIP] Not found: $LinkPath" -ForegroundColor Gray
    return $false
}

function Verify-CrossPlatformLink {
    param($LinkPath, $Platform)
    
    if (-not (Test-Path $LinkPath)) {
        Write-Host "  [FAIL] Not found: $LinkPath" -ForegroundColor Red
        return $false
    }
    
    $item = Get-Item $LinkPath
    if ($item.LinkType -eq "SymbolicLink") {
        $target = $item.Target
        Write-Host "  [OK] Symlink valid: $LinkPath -> $target" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [FAIL] Not a symlink (type: $($item.LinkType)): $LinkPath" -ForegroundColor Red
        return $false
    }
}

# ============================================================
# Main
# ============================================================
$Platform = Get-PlatformInfo

switch ($Action) {
    "Detect" {
        Write-Host ""
        Write-Host "=== Platform Detection ===" -ForegroundColor Cyan
        Write-Host "OS: $($Platform.OS)" -ForegroundColor White
        Write-Host "Home: $($Platform.HomeDir)" -ForegroundColor Gray
        Write-Host "AppData: $($Platform.AppData)" -ForegroundColor Gray
        Write-Host "Supports Symlinks: $($Platform.SupportsSymlinks)" -ForegroundColor $(if($Platform.SupportsSymlinks){"Green"}else{"Red"})
        Write-Host "Requires Admin: $($Platform.RequiresAdmin)" -ForegroundColor $(if($Platform.RequiresAdmin){"Yellow"}else{"Green"})
    }
    
    "CreateLink" {
        if (-not $TargetPath -or -not $LinkPath) {
            Write-Host "Usage: -TargetPath <path> -LinkPath <path>" -ForegroundColor Yellow
            exit 1
        }
        Create-CrossPlatformLink $TargetPath $LinkPath $Platform
    }
    
    "RemoveLink" {
        if (-not $LinkPath) {
            Write-Host "Usage: -LinkPath <path>" -ForegroundColor Yellow
            exit 1
        }
        Remove-CrossPlatformLink $LinkPath $Platform
    }
    
    "VerifyLink" {
        if (-not $LinkPath) {
            Write-Host "Usage: -LinkPath <path>" -ForegroundColor Yellow
            exit 1
        }
        Verify-CrossPlatformLink $LinkPath $Platform
    }
    
    "GetConfigRoot" {
        if (-not $IDEName) {
            Write-Host "Usage: -IDEName <name>" -ForegroundColor Yellow
            exit 1
        }
        $root = Get-IDEConfigRoot $Platform $IDEName
        if ($root) {
            Write-Host $root
        } else {
            Write-Host "Unknown platform" -ForegroundColor Red
            exit 1
        }
    }
}
