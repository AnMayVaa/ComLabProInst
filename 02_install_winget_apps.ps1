<#
.SYNOPSIS
    ลงโปรแกรมทั้งหมดด้วย winget (Windows Package Manager)
.DESCRIPTION
    ลง software ทุกตัวที่มีใน winget repository แบบ silent install
    อ่านรายการจาก config/apps_list.json
.NOTES
    ต้องรันด้วยสิทธิ์ Administrator
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "logs\02_install_winget_apps.log"
$ConfigFile = Join-Path $PSScriptRoot "config\apps_list.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR"   { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "SKIP"    { "DarkGray" }
            default   { "White" }
        }
    )
    $logsDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

# ─────────────────────────────────────────────
# ค้นหาและตั้งค่า winget
# ─────────────────────────────────────────────
Write-Log "========== เริ่มติดตั้ง Software ด้วย winget =========="

$wingetExe = $null

if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetExe = "winget"
}
else {
    $searchPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "C:\Users\ADMIN\AppData\Local\Microsoft\WindowsApps\winget.exe",
        "C:\Users\Administrator\AppData\Local\Microsoft\WindowsApps\winget.exe"
    )

    $installedAppx = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    if ($installedAppx) {
        $searchPaths += $installedAppx
    }

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $wingetExe = $path
            $parentDir = Split-Path $path
            $env:Path = "$parentDir;" + $env:Path
            Write-Log "พบ winget ที่: $path" "INFO"
            break
        }
    }
}

if (-not $wingetExe) {
    Write-Log "ไม่พบ winget ในระบบ! กรุณาเปิด Microsoft Store แล้วอัปเดต 'App Installer'" "ERROR"
    exit 1
}

try {
    $wingetVersion = & $wingetExe --version
    Write-Log "winget version: $wingetVersion" "SUCCESS"
}
catch {
    Write-Log "ไม่สามารถเรียกใช้งาน winget ได้: $($_.Exception.Message)" "ERROR"
    exit 1
}

# ─────────────────────────────────────────────
# Accept winget source agreements
# ─────────────────────────────────────────────
Write-Log "ยอมรับ winget source agreements..."
& $wingetExe source update --accept-source-agreements 2>&1 | Out-Null

# ─────────────────────────────────────────────
# อ่าน config
# ─────────────────────────────────────────────
if (-not (Test-Path $ConfigFile)) {
    Write-Log "ไม่พบไฟล์ config: $ConfigFile" "ERROR"
    exit 1
}

$config = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
$apps = $config.winget_apps
$totalApps = $apps.Count
$installed = 0
$failed = 0
$skipped = 0

Write-Log "พบ $totalApps โปรแกรมที่ต้องลง"
Write-Host ""

# ─────────────────────────────────────────────
# ลงทีละตัว
# ─────────────────────────────────────────────
for ($i = 0; $i -lt $totalApps; $i++) {
    $app = $apps[$i]
    $progress = "[$($i + 1)/$totalApps]"
    
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkCyan
    Write-Log "$progress กำลังติดตั้ง: $($app.name) ($($app.id))..."
    
    # ตรวจสอบว่าลงแล้วหรือยัง
    $checkInstalled = & $wingetExe list --id $app.id --accept-source-agreements 2>&1
    if ($checkInstalled -match $app.id) {
        Write-Log "$progress [SKIP] $($app.name) -- ติดตั้งอยู่แล้ว ข้าม" "SKIP"
        $skipped++
        continue
    }

    # ลงโปรแกรม
    $startTime = Get-Date
    try {
        $result = & $wingetExe install --id $app.id `
                                      --silent `
                                      --accept-package-agreements `
                                      --accept-source-agreements `
                                      --disable-interactivity `
                                      --force 2>&1

        $exitCode = $LASTEXITCODE
        $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

        if ($exitCode -eq 0 -or $result -match "Successfully installed") {
            Write-Log "$progress [SUCCESS] $($app.name) -- สำเร็จ (${duration}s)" "SUCCESS"
            $installed++
        }
        elseif ($result -match "already installed") {
            Write-Log "$progress [SKIP] $($app.name) -- ติดตั้งอยู่แล้ว" "SKIP"
            $skipped++
        }
        else {
            Write-Log "$progress [FAIL] $($app.name) -- ล้มเหลว (exit: $exitCode)" "ERROR"
            Write-Log "   Output: $($result | Out-String)" "ERROR"
            $failed++
        }
    }
    catch {
        Write-Log "$progress [FAIL] $($app.name) -- Exception: $($_.Exception.Message)" "ERROR"
        $failed++
    }
}

# ─────────────────────────────────────────────
# สรุปผล
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkCyan
Write-Log "========== สรุปผลการติดตั้ง winget =========="
Write-Log "  ติดตั้งสำเร็จ : $installed"
Write-Log "  ติดตั้งแล้ว (ข้าม) : $skipped"
Write-Log "  ล้มเหลว       : $failed"
Write-Log "  ทั้งหมด       : $totalApps"

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "มี $failed โปรแกรมลงไม่สำเร็จ กรุณาตรวจสอบ log:" -ForegroundColor Yellow
    Write-Host "   $LogFile" -ForegroundColor Yellow
}

Write-Log "========== เสร็จสิ้น 02_install_winget_apps =========="
