<#
.SYNOPSIS
    ลงโปรแกรมทั้งหมดด้วย winget (Windows Package Manager) แบบ Machine-wide Scope
.DESCRIPTION
    ลง software ทุกตัวที่มีใน winget repository แบบ silent install
    อ่านรายการจาก config/apps_list.json และบังคับติดตั้งแบบ --scope machine
    เพื่อให้ทุกผู้ใช้งานในเครื่อง (ทั้ง Admin และ Student) สามารถเข้าถึงโปรแกรมได้
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
Write-Log "========== เริ่มติดตั้ง Software ด้วย winget (Machine-wide) =========="

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
# ลงทีละตัว (เน้น --scope machine เพื่อแชร์ให้ทุก User)
# ─────────────────────────────────────────────
for ($i = 0; $i -lt $totalApps; $i++) {
    $app = $apps[$i]
    $progress = "[$($i + 1)/$totalApps]"
    
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkCyan
    Write-Log "$progress กำลังติดตั้ง: $($app.name) ($($app.id))..."
    
    # 1. ตรวจสอบว่าลงแล้วหรือยัง
    $escapedId = [regex]::Escape($app.id)
    $checkInstalled = & $wingetExe list --id $app.id --accept-source-agreements 2>&1 | Out-String
    $shouldSkip = ($checkInstalled -match $escapedId -and $checkInstalled -notmatch "No installed package")

    # ข้อยกเว้นพิเศษ: ตรวจสอบว่าติดตั้งแบบ Machine-wide หรือยัง
    if ($app.id -eq "Python.Python.3.12") {
        if (-not (Test-Path "C:\Program Files\Python312\python.exe")) {
            $shouldSkip = $false
            Write-Log "$progress ตรวจพบว่า Python ยังไม่ได้ติดตั้งใน C:\Program Files\Python312 (Machine-wide) -- บังคับติดตั้งใหม่..." "WARNING"
        }
    }
    if ($app.id -eq "Microsoft.VisualStudioCode") {
        if (-not (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe") -and -not (Test-Path "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe")) {
            $shouldSkip = $false
            Write-Log "$progress ตรวจพบว่า VS Code ยังไม่ได้ติดตั้งแบบ Machine-wide -- บังคับติดตั้งแบบ machine..." "WARNING"
        }
    }
    if ($app.id -eq "Embarcadero.Dev-C++") {
        $devFound = (Test-Path "$env:ProgramFiles\Embarcadero\Dev-Cpp\devcpp.exe") -or 
                    (Test-Path "${env:ProgramFiles(x86)}\Embarcadero\Dev-Cpp\devcpp.exe") -or 
                    (Test-Path "C:\Program Files (x86)\Dev-Cpp\devcpp.exe")
        if (-not $devFound) { $shouldSkip = $false }
    }
    if ($app.id -eq "ProcessingFoundation.Processing") {
        $procFound = (Test-Path "C:\Program Files\Processing 4\processing.exe") -or 
                     (Test-Path "C:\Program Files\Processing\processing.exe") -or 
                     (Test-Path "C:\Processing\processing.exe")
        if (-not $procFound) { $shouldSkip = $false }
    }

    if ($shouldSkip) {
        Write-Log "$progress [SKIP] $($app.name) -- ติดตั้งอยู่แล้ว ข้าม" "SKIP"
        $skipped++
        continue
    }

    # 2. ติดตั้งแบบ Scope Machine
    $startTime = Get-Date
    try {
        $argsList = @(
            "install",
            "--id", $app.id,
            "--scope", "machine",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--disable-interactivity",
            "--force"
        )
        if ($app.override) {
            $argsList += @("--override", $app.override)
        }

        $result = & $wingetExe @argsList 2>&1
        $exitCode = $LASTEXITCODE

        # ถ้าลง scope machine ไม่ได้ (บางแอปอาจรองรับแค่ user) ให้ retry อัตโนมัติ
        if ($exitCode -ne 0 -and ($result -match "scope" -or $result -match "No applicable installer" -or $result -match "No installer found")) {
            Write-Log "$progress [RETRY] ไม่รองรับ scope machine -- กำลังลองติดตั้งใหม่อัตโนมัติ..." "WARNING"
            $fallbackArgs = @(
                "install",
                "--id", $app.id,
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements",
                "--disable-interactivity",
                "--force"
            )
            if ($app.override) { $fallbackArgs += @("--override", $app.override) }
            $result = & $wingetExe @fallbackArgs 2>&1
            $exitCode = $LASTEXITCODE
        }

        $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)

        # Exit code 0 หรือ 3010 (Reboot required) หรือข้อความ Successfully installed ถือว่าสำเร็จ
        if ($exitCode -eq 0 -or $exitCode -eq 3010 -or $result -match "Successfully installed") {
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

# ─────────────────────────────────────────────
# ตรวจสอบและอัปเดต System PATH (GCC, R, Python, Eclipse)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkCyan
Write-Log "กำลังตรวจสอบและอัปเดต System PATH สำหรับ GCC, R, Python, Eclipse..." "INFO"

function Add-ToMachinePath {
    param([string]$FolderPath)
    if (Test-Path $FolderPath) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $paths = $currentPath -split ";" | Where-Object { $_ -ne "" }
        if ($paths -notcontains $FolderPath) {
            $newPath = "$FolderPath;" + $currentPath
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            $env:Path = "$FolderPath;" + $env:Path
            Write-Log "[PATH] เพิ่ม $FolderPath เข้าสู่ System PATH สำเร็จ" "SUCCESS"
        }
    }
}

# 1. Python 3.12 (Machine-wide)
Add-ToMachinePath "C:\Program Files\Python312"
Add-ToMachinePath "C:\Program Files\Python312\Scripts"

# 2. MinGW GCC (จาก Dev-C++ หรือ Code::Blocks)
$gccCandidates = @(
    "C:\Program Files (x86)\Embarcadero\Dev-Cpp\TDM-GCC-64\bin",
    "C:\Program Files\Embarcadero\Dev-Cpp\TDM-GCC-64\bin",
    "C:\Program Files\CodeBlocks\MinGW\bin",
    "C:\Program Files (x86)\CodeBlocks\MinGW\bin"
)
foreach ($gccDir in $gccCandidates) {
    if (Test-Path "$gccDir\gcc.exe") {
        Add-ToMachinePath $gccDir
        break
    }
}

# 3. R Language bin
$rDirs = Get-ChildItem -Path "C:\Program Files\R" -Filter "R-*" -Directory -ErrorAction SilentlyContinue
foreach ($rDir in $rDirs) {
    if (Test-Path "$($rDir.FullName)\bin\x64") {
        Add-ToMachinePath "$($rDir.FullName)\bin\x64"
    }
    if (Test-Path "$($rDir.FullName)\bin") {
        Add-ToMachinePath "$($rDir.FullName)\bin"
    }
}

# 4. Eclipse
Add-ToMachinePath "C:\Eclipse"

Write-Log "========== เสร็จสิ้น 02_install_winget_apps =========="
