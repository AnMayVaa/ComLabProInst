<#
.SYNOPSIS
    ดาวน์โหลดและติดตั้งโปรแกรมสำหรับแชร์ให้ทุกผู้ใช้งาน (Admin และ Student)
.DESCRIPTION
    จัดการ:
    - LINE Desktop (ติดตั้งแบบแชร์ให้ทุก User พร้อม Desktop Shortcut)
    - Processing 4 (ติดตั้งผ่าน Official MSI แบบ ALLUSERS พร้อม Shortcut)
    - Dev-C++ (ระบบตรวจเช็คและติดตั้งสำรองแบบ System-wide)
    - Pulsar / Atom (ติดตั้งแบบ /allusers)
    - Eclipse IDE for C/C++ (แตกไฟล์ลง C:\Eclipse และกำหนดสิทธิ์ Users)
    - แจ้งเตือนดาวน์โหลด Quartus และ Packet Tracer
.NOTES
    ต้องรันด้วยสิทธิ์ Administrator
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "logs\03_install_manual_apps.log"
$DownloadDir = Join-Path $PSScriptRoot "downloads"
$PublicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory") # C:\Users\Public\Desktop

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

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile
    )
    if (Test-Path $OutFile) {
        Write-Log "ไฟล์มีอยู่แล้ว: $OutFile -- ข้ามการ download" "WARNING"
        return $true
    }
    try {
        Write-Log "กำลัง download: $Url"
        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        $ProgressPreference = $oldProgress
        Write-Log "Download สำเร็จ: $OutFile" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Download ล้มเหลว: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

$WshShell = New-Object -ComObject WScript.Shell

function Set-PublicShortcut {
    param(
        [string]$ShortcutName,
        [string]$TargetPath,
        [string]$Arguments = ""
    )
    try {
        $linkPath = Join-Path $PublicDesktop "$ShortcutName.lnk"
        $shortcut = $WshShell.CreateShortcut($linkPath)
        $shortcut.TargetPath = $TargetPath
        $shortcut.WorkingDirectory = Split-Path $TargetPath
        if ($Arguments) { $shortcut.Arguments = $Arguments }
        $shortcut.Save()

        $parent = Split-Path $TargetPath
        icacls "$parent" /grant "Users:(OI)(CI)RX" /Q 2>&1 | Out-Null
        Write-Log "[SHORTCUT] สร้าง Shortcut บน Public Desktop: $ShortcutName.lnk" "SUCCESS"
    }
    catch {
        Write-Log "[FAIL] สร้าง Shortcut ล้มเหลวสำหรับ ${ShortcutName} - $($_.Exception.Message)" "WARNING"
    }
}

# ─────────────────────────────────────────────
# สร้างโฟลเดอร์ downloads
# ─────────────────────────────────────────────
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

Write-Log "========== เริ่มติดตั้ง Manual / Shared Apps =========="

# ===============================================
# 1. LINE Desktop (แชร์ให้ทุก User)
# ===============================================
Write-Host ""
Write-Host "--- [1/6] LINE Desktop (Shared) ---" -ForegroundColor DarkCyan

$lineSharedDir = "C:\Program Files\LINE"
$lineSharedExe = "$lineSharedDir\bin\LineLauncher.exe"

if (Test-Path $lineSharedExe) {
    Write-Log "LINE ติดตั้งอยู่ที่ $lineSharedExe แล้ว" "SUCCESS"
    Set-PublicShortcut -ShortcutName "LINE" -TargetPath $lineSharedExe
}
else {
    $lineUrl = "https://desktop.line-scdn.net/win/new/LineInst.exe"
    $lineInstaller = Join-Path $DownloadDir "LineInst.exe"
    $downloaded = Download-File -Url $lineUrl -OutFile $lineInstaller

    if ($downloaded) {
        Write-Log "กำลังติดตั้ง LINE Desktop..."
        try {
            Start-Process -FilePath $lineInstaller -ArgumentList "/S" -Wait -NoNewWindow
            Start-Sleep -Seconds 3

            # ตรวจสอบตำแหน่งที่ LINE ติดตั้งลงไป
            $candidateLine = @(
                "$env:LOCALAPPDATA\LINE\bin\LineLauncher.exe",
                "C:\Users\ADMIN\AppData\Local\LINE\bin\LineLauncher.exe",
                "${env:ProgramFiles(x86)}\LINE\bin\LineLauncher.exe",
                "C:\Program Files\LINE\bin\LineLauncher.exe"
            )

            $foundLine = $null
            foreach ($cl in $candidateLine) {
                if (Test-Path $cl) { $foundLine = $cl; break }
            }

            if ($foundLine) {
                # ถ้าอยู่ใน AppData ให้ย้าย/คัดลอกมาที่ Program Files เพื่อแชร์ให้ Student
                if ($foundLine -like "*AppData*") {
                    Write-Log "คัดลอก LINE ไปยัง C:\Program Files\LINE เพื่อแชร์ให้ทุก User..." "INFO"
                    $sourceDir = Split-Path (Split-Path $foundLine)
                    if (-not (Test-Path $lineSharedDir)) {
                        New-Item -ItemType Directory -Path $lineSharedDir -Force | Out-Null
                    }
                    Copy-Item -Path "$sourceDir\*" -Destination $lineSharedDir -Recurse -Force -ErrorAction SilentlyContinue
                    $foundLine = $lineSharedExe
                }

                Set-PublicShortcut -ShortcutName "LINE" -TargetPath $foundLine
                Write-Log "LINE Desktop ติดตั้งและแชร์ให้ Student สำเร็จ!" "SUCCESS"
            }
        }
        catch {
            Write-Log "ติดตั้ง LINE ล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 2. Processing 4 (Official MSI Installer)
# ===============================================
Write-Host ""
Write-Host "--- [2/6] Processing 4 ---" -ForegroundColor DarkCyan

$processingCandidate = @(
    "C:\Program Files\Processing 4\processing.exe",
    "C:\Program Files\Processing\processing.exe",
    "${env:ProgramFiles(x86)}\Processing\processing.exe",
    "C:\Processing\processing.exe"
)
$processingExe = $null
foreach ($p in $processingCandidate) {
    if (Test-Path $p) { $processingExe = $p; break }
}

if ($processingExe) {
    Write-Log "Processing ติดตั้งอยู่แล้ว: $processingExe" "SUCCESS"
    Set-PublicShortcut -ShortcutName "Processing" -TargetPath $processingExe
}
else {
    $procMsiUrl = "https://github.com/processing/processing4/releases/download/processing-1434-4.5.6/processing-4.5.6-windows-x64.msi"
    $procMsiFile = Join-Path $DownloadDir "processing-4.5.6-windows-x64.msi"
    $downloaded = Download-File -Url $procMsiUrl -OutFile $procMsiFile

    if ($downloaded) {
        Write-Log "กำลังติดตั้ง Processing 4 แบบ Machine-wide (MSI)..."
        try {
            $msiProcess = Start-Process msiexec.exe -ArgumentList "/i `"$procMsiFile`" /quiet /norestart ALLUSERS=1" -Wait -PassThru
            if ($msiProcess.ExitCode -eq 0) {
                Write-Log "Processing 4 ติดตั้งสำเร็จ!" "SUCCESS"
            } else {
                Write-Log "MSI ExitCode: $($msiProcess.ExitCode)" "WARNING"
            }

            foreach ($p in $processingCandidate) {
                if (Test-Path $p) {
                    Set-PublicShortcut -ShortcutName "Processing" -TargetPath $p
                    break
                }
            }
        }
        catch {
            Write-Log "ติดตั้ง Processing 4 ล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 3. Dev-C++ (ระบบตรวจเช็คและติดตั้งสำรอง)
# ===============================================
Write-Host ""
Write-Host "--- [3/6] Embarcadero Dev-C++ ---" -ForegroundColor DarkCyan

$devcppCandidates = @(
    "$env:ProgramFiles\Embarcadero\Dev-Cpp\devcpp.exe",
    "${env:ProgramFiles(x86)}\Embarcadero\Dev-Cpp\devcpp.exe",
    "C:\Program Files (x86)\Dev-Cpp\devcpp.exe"
)
$devcppExe = $null
foreach ($d in $devcppCandidates) {
    if (Test-Path $d) { $devcppExe = $d; break }
}

if ($devcppExe) {
    Write-Log "Dev-C++ ติดตั้งอยู่แล้ว: $devcppExe" "SUCCESS"
    Set-PublicShortcut -ShortcutName "Dev-C++" -TargetPath $devcppExe
}
else {
    Write-Log "Dev-C++ ยังไม่ถูกติดตั้งจาก winget -- กำลังดาวน์โหลดตัวติดตั้งสำรอง..." "WARNING"
    $devcppUrl = "https://github.com/Embarcadero/Dev-Cpp/releases/download/v6.3/Embarcadero_Dev-Cpp_6.3_TDM-GCC_9.2_Setup.exe"
    $devcppInstaller = Join-Path $DownloadDir "DevCpp_Setup.exe"
    $downloaded = Download-File -Url $devcppUrl -OutFile $devcppInstaller

    if ($downloaded) {
        Write-Log "กำลังติดตั้ง Dev-C++ (Silent)..."
        try {
            Start-Process -FilePath $devcppInstaller -ArgumentList "/S" -Wait -NoNewWindow
            Start-Sleep -Seconds 3
            foreach ($d in $devcppCandidates) {
                if (Test-Path $d) {
                    Set-PublicShortcut -ShortcutName "Dev-C++" -TargetPath $d
                    Write-Log "Dev-C++ ติดตั้งสำเร็จ!" "SUCCESS"
                    
                    # เพิ่ม MinGW GCC เข้า System PATH
                    $tdmDir = Split-Path (Split-Path $d)
                    $gccPath = Join-Path $tdmDir "TDM-GCC-64\bin"
                    if (Test-Path "$gccPath\gcc.exe") {
                        $currentMPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                        if ($currentMPath -notlike "*$gccPath*") {
                            [Environment]::SetEnvironmentVariable("Path", "$gccPath;$currentMPath", "Machine")
                            $env:Path = "$gccPath;" + $env:Path
                            Write-Log "[PATH] เพิ่ม TDM-GCC เข้าสู่ System PATH: $gccPath" "SUCCESS"
                        }
                    }
                    break
                }
            }
        }
        catch {
            Write-Log "ติดตั้ง Dev-C++ สำรองล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 4. Pulsar Editor (Atom fork)
# ===============================================
Write-Host ""
Write-Host "--- [4/6] Pulsar Editor (Atom fork) ---" -ForegroundColor DarkCyan

$pulsarCandidates = @(
    "$env:ProgramFiles\Pulsar\Pulsar.exe",
    "$env:LOCALAPPDATA\Programs\Pulsar\Pulsar.exe"
)
$pulsarExe = $null
foreach ($pu in $pulsarCandidates) {
    if (Test-Path $pu) { $pulsarExe = $pu; break }
}

if ($pulsarExe) {
    Write-Log "Pulsar ติดตั้งอยู่แล้ว: $pulsarExe" "SUCCESS"
    Set-PublicShortcut -ShortcutName "Pulsar (Atom)" -TargetPath $pulsarExe
}
else {
    $pulsarUrl = "https://github.com/pulsar-edit/pulsar/releases/download/v1.122.0/Windows.Pulsar.Setup.1.122.0.exe"
    $pulsarInstaller = Join-Path $DownloadDir "PulsarSetup.exe"
    $downloaded = Download-File -Url $pulsarUrl -OutFile $pulsarInstaller

    if ($downloaded) {
        Write-Log "กำลังติดตั้ง Pulsar..."
        try {
            Start-Process -FilePath $pulsarInstaller -ArgumentList "/S", "/allusers" -Wait -NoNewWindow
            foreach ($pu in $pulsarCandidates) {
                if (Test-Path $pu) {
                    Set-PublicShortcut -ShortcutName "Pulsar (Atom)" -TargetPath $pu
                    Write-Log "Pulsar ติดตั้งสำเร็จ" "SUCCESS"
                    break
                }
            }
        }
        catch {
            Write-Log "Pulsar ติดตั้งล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 5. Eclipse IDE for C/C++ Developers
# ===============================================
Write-Host ""
Write-Host "--- [5/6] Eclipse IDE for C/C++ ---" -ForegroundColor DarkCyan

$eclipseInstallDir = "C:\Eclipse"
$eclipseExe = "$eclipseInstallDir\eclipse.exe"

if (Test-Path $eclipseExe) {
    Write-Log "Eclipse ติดตั้งอยู่ที่ $eclipseExe แล้ว" "SUCCESS"
    Set-PublicShortcut -ShortcutName "Eclipse C++" -TargetPath $eclipseExe
}
else {
    $eclipseUrl = "https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2024-09/R/eclipse-cpp-2024-09-R-win32-x86_64.zip&r=1"
    $eclipseZip = Join-Path $DownloadDir "eclipse-cpp.zip"
    $downloaded = Download-File -Url $eclipseUrl -OutFile $eclipseZip

    if ($downloaded) {
        Write-Log "กำลังแตกไฟล์ Eclipse C++..."
        try {
            Expand-Archive -Path $eclipseZip -DestinationPath "C:\" -Force
            if ((Test-Path "C:\eclipse") -and -not (Test-Path $eclipseInstallDir)) {
                Rename-Item "C:\eclipse" "Eclipse"
            }
            if (Test-Path $eclipseExe) {
                Set-PublicShortcut -ShortcutName "Eclipse C++" -TargetPath $eclipseExe
                Write-Log "Eclipse C++ ติดตั้งสำเร็จที่ $eclipseInstallDir" "SUCCESS"
            }
        }
        catch {
            Write-Log "แตกไฟล์ Eclipse ล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 6. Quartus & Packet Tracer (เปิดลิงก์ดาวน์โหลด)
# ===============================================
Write-Host ""
Write-Host "--- [6/6] Intel Quartus 21 & Cisco Packet Tracer ---" -ForegroundColor DarkCyan

# ตรวจสอบ Quartus
$quartusFound = Resolve-Path "C:\intelFPGA_lite\*\quartus\bin64\quartus.exe" -ErrorAction SilentlyContinue
if ($quartusFound) {
    Write-Log "พบ Intel Quartus Prime: $($quartusFound[-1].Path)" "SUCCESS"
    Set-PublicShortcut -ShortcutName "Intel Quartus Prime" -TargetPath $quartusFound[-1].Path
}
else {
    Write-Log "ยังไม่พบ Quartus Prime -- เปิดหน้าเว็บให้ดาวน์โหลด..." "WARNING"
    Start-Process "https://www.intel.com/content/www/us/en/software-kit/785086/intel-quartus-prime-lite-edition-design-software-version-22-1-2-for-windows.html"
}

# ตรวจสอบ Packet Tracer
$ptFound = Resolve-Path "$env:ProgramFiles\Cisco Packet Tracer*\bin\PacketTracer.exe" -ErrorAction SilentlyContinue
if ($ptFound) {
    Write-Log "พบ Cisco Packet Tracer: $($ptFound[-1].Path)" "SUCCESS"
    Set-PublicShortcut -ShortcutName "Cisco Packet Tracer" -TargetPath $ptFound[-1].Path
}
else {
    Write-Log "ยังไม่พบ Packet Tracer -- เปิดหน้าเว็บให้ดาวน์โหลด..." "WARNING"
    Start-Process "https://www.netacad.com/resources/lab-downloads"
}

# ─────────────────────────────────────────────
Write-Log "========== เสร็จสิ้น 03_install_manual_apps =========="
Write-Host ""
Write-Host "✅ ติดตั้ง Manual Apps และสร้าง Desktop Shortcuts ให้ Student เรียบร้อย!" -ForegroundColor Green
