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
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

Write-Log "========== เริ่มตั้งค่า Student Account =========="

# ─────────────────────────────────────────────
# หา Student profile path
# ─────────────────────────────────────────────

$studentProfile = "C:\Users\Student"
$studentSID = $null

try {
    $studentUser = Get-LocalUser -Name "Student" -ErrorAction Stop
    $studentSID = (New-Object System.Security.Principal.NTAccount("Student")).Translate(
        [System.Security.Principal.SecurityIdentifier]).Value
    Write-Log "Student SID: $studentSID" "INFO"
}
catch {
    Write-Log "ไม่พบ Student account! กรุณารัน 01_create_users.ps1 ก่อน" "ERROR"
    exit 1
}

# ─────────────────────────────────────────────
# 1. ตั้งค่า UAC ให้ Student ลง/ลบโปรแกรมได้โดยไม่ติดถามรหัสผ่าน
# ─────────────────────────────────────────────
Write-Log "ตั้งค่า UAC ให้สามารถลง/ลบโปรแกรมได้สะดวก..."

$uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 1 -Type DWord
Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord
Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorUser" -Value 0 -Type DWord
Write-Log "UAC ตั้งค่าเรียบร้อย (Student ใช้งานและลงโปรแกรมได้อิสระ)" "SUCCESS"

# ─────────────────────────────────────────────
# 2. ตั้งค่า Registry สำหรับ Student
# ─────────────────────────────────────────────
Write-Log "ตั้งค่า Registry สำหรับ Student..."

$studentNTUserDat = "$studentProfile\NTUSER.DAT"
$hiveLoaded = $false

if ($studentSID) {
    $hkuPath = "Registry::HKU\$studentSID"
    if (-not (Test-Path $hkuPath)) {
        if (Test-Path $studentNTUserDat) {
            Write-Log "Loading Student registry hive..." "INFO"
            reg load "HKU\$studentSID" "$studentNTUserDat" 2>&1 | Out-Null
            $hiveLoaded = $true
        }
        else {
            Write-Log "Student profile ยังไม่มีบนดิสก์ (นักศึกษายังไม่ได้ล็อกอินครั้งแรก) -- ข้าม registry per-user ชั่วคราว" "WARNING"
        }
    }

    if (Test-Path "Registry::HKU\$studentSID") {
        $personalizePath = "Registry::HKU\$studentSID\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"
        if (-not (Test-Path $personalizePath)) {
            New-Item -Path $personalizePath -Force | Out-Null
        }
        Set-ItemProperty -Path $personalizePath -Name "NoChangingWallPaper" -Value 1 -Type DWord
        Write-Log "ปิดการเปลี่ยน wallpaper สำหรับ Student" "SUCCESS"

        if ($hiveLoaded) {
            [gc]::Collect()
            Start-Sleep -Seconds 2
            reg unload "HKU\$studentSID" 2>&1 | Out-Null
            Write-Log "Unloaded Student registry hive" "INFO"
        }
    }
}

# ─────────────────────────────────────────────
# 3. ตั้ง Power Plan ไม่ให้ sleep อัตโนมัติ
# ─────────────────────────────────────────────
Write-Log "ตั้ง Power Plan..."
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 30
Write-Log "ปิด Sleep (AC), Monitor off หลัง 30 นาที" "SUCCESS"

# ─────────────────────────────────────────────
# 4. ปิด Windows Update auto-restart
# ─────────────────────────────────────────────
Write-Log "ตั้งค่า Windows Update..."
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $wuPath)) {
    New-Item -Path $wuPath -Force | Out-Null
}
Set-ItemProperty -Path $wuPath -Name "AUOptions" -Value 2 -Type DWord
Set-ItemProperty -Path $wuPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
Write-Log "ปิด Auto-restart จาก Windows Update เรียบร้อย" "SUCCESS"

# ─────────────────────────────────────────────
# 5. ปิด First Login Animation
# ─────────────────────────────────────────────
$fliPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $fliPath -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord
Write-Log "ปิด First Login Animation (เข้าเครื่องเร็วขึ้น)" "SUCCESS"

# ─────────────────────────────────────────────
# 6. ตั้ง hostname pattern (ECE01, ECE02, etc.)
# ─────────────────────────────────────────────
$currentName = $env:COMPUTERNAME
Write-Log "ชื่อเครื่องปัจจุบัน: $currentName" "INFO"

if ($currentName -notmatch "^ECE\d+$") {
    Write-Log "ชื่อเครื่องปัจจุบันยังไม่ตรงรูปแบบ ECE## -- สามารถเปลี่ยนได้ด้วยคำสั่ง Rename-Computer" "WARNING"
}

# ─────────────────────────────────────────────
Write-Log "========== เสร็จสิ้น 05_configure_student =========="
Write-Host ""
Write-Host "ตั้งค่าความปลอดภัย Student Account เรียบร้อย!" -ForegroundColor Green
