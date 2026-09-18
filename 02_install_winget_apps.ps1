<#
.SYNOPSIS
    ลงโปรแกรมทั้งหมดด้วย winget (Windows Package Manager)
.DESCRIPTION
    ลง software ทุกตัวที่มีใน winget repository แบบ silent install
    อ่านรายการจาก config/apps_list.json
.NOTES
    ต้องรันด้วยสิทธิ์ Administrator
    winget มาพร้อม Windows 11 แล้ว ไม่ต้องลงเพิ่ม
#>

#Requires -RunAsAdministrator

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
    Add-Content -Path $LogFile -Value $logEntry
}

# ─────────────────────────────────────────────
# ตรวจสอบ winget
# ─────────────────────────────────────────────
Write-Log "========== เริ่มติดตั้ง Software ด้วย winget =========="

try {
    $wingetVersion = winget --version
    Write-Log "winget version: $wingetVersion" "SUCCESS"
}
catch {
    Write-Log "❌ ไม่พบ winget! กรุณาอัปเดต Windows หรือลง App Installer จาก Microsoft Store" "ERROR"
    Write-Host ""
    Write-Host "วิธีแก้:" -ForegroundColor Yellow
    Write-Host "  1. เปิด Microsoft Store" -ForegroundColor Yellow
    Write-Host "  2. ค้นหา 'App Installer'" -ForegroundColor Yellow
    Write-Host "  3. กดอัปเดต/ติดตั้ง" -ForegroundColor Yellow
    exit 1
}

# ─────────────────────────────────────────────
# Accept winget source agreements
# ─────────────────────────────────────────────
Write-Log "ยอมรับ winget source agreements..."
winget source update --accept-source-agreements 2>&1 | Out-Null

# ─────────────────────────────────────────────
# อ่าน config
# ─────────────────────────────────────────────
if (-not (Test-Path $ConfigFile)) {
    Write-Log "❌ ไม่พบไฟล์ config: $ConfigFile" "ERROR"
    exit 1
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
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
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
    Write-Log "$progress กำลังติดตั้ง: $($app.name) ($($app.id))..."
    
    # ตรวจสอบว่าลงแล้วหรือยัง
    $checkInstalled = winget list --id $app.id --accept-source-agreements 2>&1
    if ($checkInstalled -match $app.id) {
        Write-Log "$progress ⏭️  $($app.name) — ลงแล้ว ข้าม" "SKIP"
        $skipped++
        continue
    }

    # ลงโปรแกรม
    $startTime = Get-Date
    try {
        $result = winget install --id $app.id `
                                 --silent `
                                 --accept-package-agreements `
                                 --accept-source-agreements `
                                 --disable-interactivity `
                                 --force 2>&1

        $exitCode = $LASTEXITCODE
        $duration = ((Get-Date) - $startTime).TotalSeconds

        if ($exitCode -eq 0 -or $result -match "Successfully installed") {
            Write-Log "$progress ✅ $($app.name) — สำเร็จ (${duration}s)" "SUCCESS"
            $installed++
        }
        elseif ($result -match "already installed") {
            Write-Log "$progress ⏭️  $($app.name) — ลงแล้ว" "SKIP"
            $skipped++
        }
        else {
            Write-Log "$progress ❌ $($app.name) — ล้มเหลว (exit: $exitCode)" "ERROR"
            Write-Log "   Output: $($result | Out-String)" "ERROR"
            $failed++
        }
    }
    catch {
        Write-Log "$progress ❌ $($app.name) — Exception: $($_.Exception.Message)" "ERROR"
        $failed++
    }
}

# ─────────────────────────────────────────────
# สรุปผล
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Log "========== สรุปผลการติดตั้ง winget =========="
Write-Log "  ✅ ติดตั้งสำเร็จ : $installed"
Write-Log "  ⏭️  ลงแล้ว (ข้าม) : $skipped"
Write-Log "  ❌ ล้มเหลว       : $failed"
Write-Log "  📦 ทั้งหมด       : $totalApps"

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "⚠️  มี $failed โปรแกรมลงไม่สำเร็จ กรุณาตรวจสอบ log:" -ForegroundColor Yellow
    Write-Host "   $LogFile" -ForegroundColor Yellow
}

Write-Log "========== เสร็จสิ้น 02_install_winget_apps =========="
