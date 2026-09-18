<#
.SYNOPSIS
    จำกัดสิทธิ์ Student Account
.DESCRIPTION
    ตั้งค่า Registry เพื่อจำกัดสิทธิ์ Student:
    - ปิดการลง software (UAC จะถามรหัส Admin)
    - ปิด Windows Store (ถ้าต้องการ)
    - ซ่อน drives บางตัว (optional)
    - ตั้ง default apps
.NOTES
    ต้องรันด้วยสิทธิ์ Administrator
    Windows 11 Home ไม่รองรับ Group Policy (gpedit.msc) จึงใช้ Registry แทน
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "logs\05_configure_student.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR"   { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default   { "White" }
        }
    )
    $logsDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry
}

Write-Log "========== เริ่มตั้งค่า Student Account =========="

# ─────────────────────────────────────────────
# หา Student profile path
# ─────────────────────────────────────────────

# ต้องให้ Student login อย่างน้อย 1 ครั้งก่อนถึงจะมี profile folder
$studentProfile = "C:\Users\Student"
$studentSID = $null

try {
    $studentUser = Get-LocalUser -Name "Student" -ErrorAction Stop
    $studentSID = (New-Object System.Security.Principal.NTAccount("Student")).Translate(
        [System.Security.Principal.SecurityIdentifier]).Value
    Write-Log "Student SID: $studentSID"
}
catch {
    Write-Log "❌ ไม่พบ Student account! กรุณารัน 01_create_users.ps1 ก่อน" "ERROR"
    exit 1
}

# ─────────────────────────────────────────────
# 1. ตั้งค่า UAC ให้สูงสุด (ถาม Admin password เวลาลง software)
# ─────────────────────────────────────────────
Write-Log "ตั้งค่า UAC..."

$uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorUser" -Value 1 -Type DWord
Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 1 -Type DWord
Write-Log "✅ UAC ตั้งให้ถาม Admin credentials เวลาลง software" "SUCCESS"

# ─────────────────────────────────────────────
# 2. ปิด Windows Store สำหรับ non-admin (optional)
# ─────────────────────────────────────────────
Write-Log "ปิด Microsoft Store สำหรับ non-admin users..."

$storePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
if (-not (Test-Path $storePolicyPath)) {
    New-Item -Path $storePolicyPath -Force | Out-Null
}
# 0 = ปิด Store, ลบ key = เปิด Store
# Set-ItemProperty -Path $storePolicyPath -Name "RemoveWindowsStore" -Value 1 -Type DWord
# Write-Log "✅ ปิด Microsoft Store" "SUCCESS"
Write-Log "⏭️  Microsoft Store ยังเปิดอยู่ (uncomment ใน script ถ้าต้องการปิด)" "WARNING"

# ─────────────────────────────────────────────
# 3. ปิด Settings บางส่วนสำหรับ Student (Registry per-user via HKU)
# ─────────────────────────────────────────────
Write-Log "ตั้งค่า Registry สำหรับ Student..."

# Load Student registry hive ถ้ายังไม่ได้ login
$studentNTUserDat = "$studentProfile\NTUSER.DAT"
$hiveLoaded = $false

if ($studentSID) {
    $hkuPath = "Registry::HKU\$studentSID"
    if (-not (Test-Path $hkuPath)) {
        if (Test-Path $studentNTUserDat) {
            Write-Log "Loading Student registry hive..."
            reg load "HKU\$studentSID" "$studentNTUserDat" 2>&1 | Out-Null
            $hiveLoaded = $true
        }
        else {
            Write-Log "⚠️  Student profile ยังไม่มี — ต้องให้ Student login อย่างน้อย 1 ครั้งก่อน" "WARNING"
            Write-Log "   จากนั้นรัน script นี้อีกครั้ง" "WARNING"
        }
    }

    if (Test-Path "Registry::HKU\$studentSID") {
        # ─── ซ่อน Settings pages บางหน้า ───
        $settingsPath = "Registry::HKU\$studentSID\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        if (-not (Test-Path $settingsPath)) {
            New-Item -Path $settingsPath -Force | Out-Null
        }

        # ปิด Run dialog (Win+R) สำหรับ Student
        # Set-ItemProperty -Path $settingsPath -Name "NoRun" -Value 1 -Type DWord
        # Write-Log "✅ ปิด Run dialog สำหรับ Student" "SUCCESS"

        # ปิดการเข้าถึง Control Panel
        # Set-ItemProperty -Path $settingsPath -Name "NoControlPanel" -Value 1 -Type DWord

        # ปิดการเปลี่ยน wallpaper
        $personalizePath = "Registry::HKU\$studentSID\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"
        if (-not (Test-Path $personalizePath)) {
            New-Item -Path $personalizePath -Force | Out-Null
        }
        Set-ItemProperty -Path $personalizePath -Name "NoChangingWallPaper" -Value 1 -Type DWord
        Write-Log "✅ ปิดการเปลี่ยน wallpaper สำหรับ Student" "SUCCESS"

        # ─── Unload hive ถ้า load มา ───
        if ($hiveLoaded) {
            [gc]::Collect()
            Start-Sleep -Seconds 2
            reg unload "HKU\$studentSID" 2>&1 | Out-Null
            Write-Log "Unloaded Student registry hive"
        }
    }
}

# ─────────────────────────────────────────────
# 4. ตั้ง Power Plan ไม่ให้ sleep อัตโนมัติ
# ─────────────────────────────────────────────
Write-Log "ตั้ง Power Plan..."
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 30
Write-Log "✅ ปิด Sleep (AC), Monitor off หลัง 30 นาที" "SUCCESS"

# ─────────────────────────────────────────────
# 5. ปิด Windows Update auto-restart
# ─────────────────────────────────────────────
Write-Log "ตั้งค่า Windows Update..."
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $wuPath)) {
    New-Item -Path $wuPath -Force | Out-Null
}
# 2 = Notify before download, 3 = Auto download + notify install, 4 = Auto
Set-ItemProperty -Path $wuPath -Name "AUOptions" -Value 2 -Type DWord
Set-ItemProperty -Path $wuPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
Write-Log "✅ ปิด Auto-restart จาก Windows Update" "SUCCESS"

# ─────────────────────────────────────────────
# 6. ปิด First Login Animation
# ─────────────────────────────────────────────
$fliPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $fliPath -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord
Write-Log "✅ ปิด First Login Animation (เร็วขึ้น)" "SUCCESS"

# ─────────────────────────────────────────────
# 7. ตั้ง hostname pattern (ECE01, ECE02, etc.)
# ─────────────────────────────────────────────
$currentName = $env:COMPUTERNAME
Write-Log "ชื่อเครื่องปัจจุบัน: $currentName"

if ($currentName -notmatch "^ECE\d+$") {
    Write-Log "⚠️  ชื่อเครื่องไม่ตรงรูปแบบ ECE## — สามารถเปลี่ยนได้ด้วยคำสั่ง:" "WARNING"
    Write-Host "  Rename-Computer -NewName 'ECE01' -Force -Restart" -ForegroundColor Cyan
}

# ─────────────────────────────────────────────
Write-Log "========== เสร็จสิ้น 05_configure_student =========="
Write-Host ""
Write-Host "✅ ตั้งค่า Student Account เรียบร้อย!" -ForegroundColor Green
Write-Host ""
Write-Host "หมายเหตุ:" -ForegroundColor Yellow
Write-Host "  - Student ไม่สามารถลง software ได้ (UAC จะถาม Admin password)" -ForegroundColor Yellow
Write-Host "  - เครื่องจะไม่ sleep อัตโนมัติ" -ForegroundColor Yellow
Write-Host "  - Windows Update จะไม่ restart เอง" -ForegroundColor Yellow
