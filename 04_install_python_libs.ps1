<#
.SYNOPSIS
    ลง Python Libraries สำหรับ Data Science
.DESCRIPTION
    อ่านจาก config/python_libs.txt แล้ว pip install ทั้งหมด
    ลงแบบ system-wide (--no-user) เพื่อให้ทุก user ใช้ได้
.NOTES
    ต้องรัน 02_install_winget_apps.ps1 ก่อน (ลง Python)
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "logs\04_install_python_libs.log"
$RequirementsFile = Join-Path $PSScriptRoot "config\python_libs.txt"

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

Write-Log "========== เริ่มติดตั้ง Python Libraries =========="

# ─────────────────────────────────────────────
# ตรวจสอบ Python
# ─────────────────────────────────────────────

# Refresh PATH เพื่อให้เจอ Python ที่เพิ่งลง
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

$pythonCmd = $null

# ค้นหา Python Machine-wide (C:\Program Files\Python312) เป็นลำดับแรกเสมอ เพื่อเลี่ยงข้อจำกัด Smart App Control
$systemPyList = @(
    "C:\Program Files\Python312\python.exe",
    "$env:ProgramFiles\Python312\python.exe",
    "C:\Program Files\Python313\python.exe",
    "$env:ProgramFiles\Python313\python.exe",
    "C:\Python312\python.exe"
)
foreach ($sp in $systemPyList) {
    if (Test-Path $sp) {
        $pythonCmd = $sp
        Write-Log "พบ Python (System-wide): $sp" "SUCCESS"
        break
    }
}

if (-not $pythonCmd) {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) {
        $pythonCmd = $cmd.Source
    }
}

if (-not $pythonCmd) {
    $userPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
    )
    foreach ($up in $userPaths) {
        if (Test-Path $up) {
            $pythonCmd = $up
            Write-Log "พบ Python ใน AppData: $up (อาจถูกจำกัดสิทธิ์โดย Smart App Control)" "WARNING"
            break
        }
    }
}

if (-not $pythonCmd) {
    Write-Log "ไม่พบ Python ในระบบ! กรุณารัน 02_install_winget_apps.ps1 ก่อน" "ERROR"
    exit 1
}

$pythonExe = if ($pythonCmd -is [System.Management.Automation.ApplicationInfo]) { $pythonCmd.Source } else { $pythonCmd }
$pythonVersion = & $pythonExe --version 2>&1
Write-Log "Python: $pythonVersion ($pythonExe)" "SUCCESS"

# ─────────────────────────────────────────────
# อัปเดต pip
# ─────────────────────────────────────────────
Write-Log "กำลังอัปเดต pip..."
& $pythonExe -m pip install --upgrade pip 2>&1 | ForEach-Object { Write-Log "  $_" }

# ─────────────────────────────────────────────
# ลง libraries จาก requirements file
# ─────────────────────────────────────────────
if (-not (Test-Path $RequirementsFile)) {
    Write-Log "ไม่พบ requirements file: $RequirementsFile" "ERROR"
    exit 1
}

Write-Log "กำลังลง libraries จาก: $RequirementsFile"
Write-Host ""

& $pythonExe -m pip install -r $RequirementsFile 2>&1 | ForEach-Object {
    if ($_ -match "Successfully installed") {
        Write-Log "  [SUCCESS] $_" "SUCCESS"
    }
    elseif ($_ -match "already satisfied") {
        Write-Log "  [SKIP] $_" "INFO"
    }
    elseif ($_ -match "ERROR") {
        Write-Log "  [FAIL] $_" "ERROR"
    }
    else {
        Write-Log "  $_"
    }
}

# ให้สิทธิ์กลุ่ม Users ใช้งาน C:\Program Files\Python312 ได้อย่างสมบูรณ์
$pyRoot = Split-Path $pythonExe
Write-Log "กำหนดสิทธิ์ให้กลุ่ม Users เข้าถึง: $pyRoot..." "INFO"
icacls "$pyRoot" /grant "Users:(OI)(CI)RX" /T /Q 2>&1 | Out-Null

# ─────────────────────────────────────────────
# ตรวจสอบว่าลงครบ
# ─────────────────────────────────────────────
Write-Host ""
Write-Log "========== ทดสอบ import libraries =========="

$testLibs = @("numpy", "pandas", "matplotlib", "scipy", "sklearn", "jupyter",
              "seaborn", "plotly", "statsmodels", "sympy", "cv2", "PIL",
              "requests", "flask", "tqdm", "openpyxl")

$passed = 0
$failedLibs = @()

foreach ($lib in $testLibs) {
    $result = & $pythonExe -c "import $lib; print($lib.__name__)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "  [PASS] $lib" "SUCCESS"
        $passed++
    }
    else {
        Write-Log "  [FAIL] $lib -- import ล้มเหลว" "ERROR"
        $failedLibs += $lib
    }
}

Write-Host ""
Write-Log "ผลทดสอบ: $passed/$($testLibs.Count) สำเร็จ"
if ($failedLibs.Count -gt 0) {
    Write-Log "Libraries ที่ล้มเหลว: $($failedLibs -join ', ')" "ERROR"
}

Write-Log "========== เสร็จสิ้น 04_install_python_libs =========="
