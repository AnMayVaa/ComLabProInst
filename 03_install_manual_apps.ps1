<#
.SYNOPSIS
    ดาวน์โหลดและติดตั้งโปรแกรมที่ไม่มีใน winget
.DESCRIPTION
    จัดการ:
    - Processing (download zip + extract)
    - Pulsar/Atom (download installer)
    - Eclipse IDE for C/C++ (download zip + extract)
    - เปิดหน้า download สำหรับ Quartus และ Packet Tracer
.NOTES
    ต้องรันด้วยสิทธิ์ Administrator
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "logs\03_install_manual_apps.log"
$DownloadDir = Join-Path $PSScriptRoot "downloads"

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

# ─────────────────────────────────────────────
# สร้างโฟลเดอร์ downloads
# ─────────────────────────────────────────────
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

Write-Log "========== เริ่มติดตั้ง Manual Apps =========="

# ===============================================
# 1. Processing
# ===============================================
Write-Host ""
Write-Host "--- [1/5] Processing ---" -ForegroundColor DarkCyan

$processingInstallDir = "C:\Processing"
if (Test-Path "$processingInstallDir\processing.exe") {
    Write-Log "Processing ติดตั้งอยู่แล้ว -- ข้าม" "SUCCESS"
}
else {
    $processingUrl = "https://github.com/processing/processing4/releases/download/processing-1293-4.3.4/processing-4.3.4-windows-x64.zip"
    $processingZip = Join-Path $DownloadDir "processing-4.3.4-windows-x64.zip"

    $downloaded = Download-File -Url $processingUrl -OutFile $processingZip
    if ($downloaded) {
        Write-Log "กำลังแตกไฟล์ Processing..."
        try {
            Expand-Archive -Path $processingZip -DestinationPath "C:\" -Force
            $extractedDir = Get-ChildItem "C:\" -Directory | Where-Object { $_.Name -match "processing-" } | Select-Object -First 1
            if ($extractedDir -and $extractedDir.Name -ne "Processing") {
                if (Test-Path $processingInstallDir) { Remove-Item $processingInstallDir -Recurse -Force }
                Rename-Item $extractedDir.FullName "Processing"
            }
            Write-Log "Processing ติดตั้งที่ $processingInstallDir" "SUCCESS"

            # สร้าง Desktop shortcut
            $WshShell = New-Object -ComObject WScript.Shell
            $publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
            $shortcut = $WshShell.CreateShortcut("$publicDesktop\Processing.lnk")
            $shortcut.TargetPath = "$processingInstallDir\processing.exe"
            $shortcut.WorkingDirectory = $processingInstallDir
            $shortcut.Save()
            Write-Log "สร้าง Desktop shortcut สำเร็จ" "SUCCESS"
        }
        catch {
            Write-Log "แตกไฟล์ Processing ล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 2. Pulsar Editor (Atom fork)
# ===============================================
Write-Host ""
Write-Host "--- [2/5] Pulsar Editor (Atom fork) ---" -ForegroundColor DarkCyan

$pulsarCheck = Get-Command pulsar -ErrorAction SilentlyContinue
if ($pulsarCheck) {
    Write-Log "Pulsar ติดตั้งอยู่แล้ว -- ข้าม" "SUCCESS"
}
else {
    $pulsarUrl = "https://github.com/pulsar-edit/pulsar/releases/download/v1.122.0/Windows.Pulsar.Setup.1.122.0.exe"
    $pulsarInstaller = Join-Path $DownloadDir "PulsarSetup.exe"

    $downloaded = Download-File -Url $pulsarUrl -OutFile $pulsarInstaller
    if ($downloaded) {
        Write-Log "กำลังติดตั้ง Pulsar..."
        try {
            Start-Process -FilePath $pulsarInstaller -ArgumentList "/S", "/allusers" -Wait -NoNewWindow
            Write-Log "Pulsar ติดตั้งสำเร็จ" "SUCCESS"
        }
        catch {
            Write-Log "Pulsar ติดตั้งล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 3. Eclipse IDE for C/C++ Developers
# ===============================================
Write-Host ""
Write-Host "--- [3/5] Eclipse IDE for C/C++ ---" -ForegroundColor DarkCyan

$eclipseInstallDir = "C:\Eclipse"
if (Test-Path "$eclipseInstallDir\eclipse.exe") {
    Write-Log "Eclipse ติดตั้งอยู่แล้ว -- ข้าม" "SUCCESS"
}
else {
    $eclipseUrl = "https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2024-09/R/eclipse-cpp-2024-09-R-win32-x86_64.zip&r=1"
    $eclipseZip = Join-Path $DownloadDir "eclipse-cpp.zip"

    $downloaded = Download-File -Url $eclipseUrl -OutFile $eclipseZip
    if ($downloaded) {
        Write-Log "กำลังแตกไฟล์ Eclipse..."
        try {
            Expand-Archive -Path $eclipseZip -DestinationPath "C:\" -Force
            if ((Test-Path "C:\eclipse") -and -not (Test-Path $eclipseInstallDir)) {
                Rename-Item "C:\eclipse" "Eclipse"
            }
            Write-Log "Eclipse ติดตั้งที่ $eclipseInstallDir" "SUCCESS"

            $WshShell = New-Object -ComObject WScript.Shell
            $publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
            $shortcut = $WshShell.CreateShortcut("$publicDesktop\Eclipse C++.lnk")
            $shortcut.TargetPath = "$eclipseInstallDir\eclipse.exe"
            $shortcut.WorkingDirectory = $eclipseInstallDir
            $shortcut.Save()
            Write-Log "สร้าง Desktop shortcut สำเร็จ" "SUCCESS"
        }
        catch {
            Write-Log "แตกไฟล์ Eclipse ล้มเหลว: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ===============================================
# 4. Intel Quartus Prime 21 (เปิด browser)
# ===============================================
Write-Host ""
Write-Host "--- [4/5] Intel Quartus Prime 21 ---" -ForegroundColor DarkCyan

Write-Log "Quartus ต้อง download manual -- เปิดหน้าเว็บให้ดาวน์โหลด..." "WARNING"
Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host "   Quartus Prime 21 ต้อง download ด้วยตนเอง" -ForegroundColor Yellow
Write-Host "   1. Login ด้วย Intel Account" -ForegroundColor Yellow
Write-Host "   2. เลือก Quartus Prime Lite Edition" -ForegroundColor Yellow
Write-Host "   3. เลือก Device Support ที่ต้องการ" -ForegroundColor Yellow
Write-Host "   4. Download และ Run Installer" -ForegroundColor Yellow
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host ""

Start-Process "https://www.intel.com/content/www/us/en/software-kit/785086/intel-quartus-prime-lite-edition-design-software-version-22-1-2-for-windows.html"
Write-Log "เปิด browser ไปหน้า download Quartus แล้ว"

# ===============================================
# 5. Cisco Packet Tracer (เปิด browser)
# ===============================================
Write-Host ""
Write-Host "--- [5/5] Cisco Packet Tracer ---" -ForegroundColor DarkCyan

Write-Log "Packet Tracer ต้อง download manual -- เปิดหน้าเว็บให้ดาวน์โหลด..." "WARNING"
Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host "   Cisco Packet Tracer ต้อง download ด้วยตนเอง" -ForegroundColor Yellow
Write-Host "   1. Login ด้วย Cisco Networking Academy Account" -ForegroundColor Yellow
Write-Host "   2. ไปที่ Resources > Download Packet Tracer" -ForegroundColor Yellow
Write-Host "   3. เลือก Windows 64-bit" -ForegroundColor Yellow
Write-Host "   4. Run Installer" -ForegroundColor Yellow
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host ""

Start-Process "https://www.netacad.com/resources/lab-downloads"
Write-Log "เปิด browser ไปหน้า download Packet Tracer แล้ว"

# ─────────────────────────────────────────────
Write-Log "========== เสร็จสิ้น 03_install_manual_apps =========="
Write-Host ""
Write-Host "ลง Processing, Pulsar, Eclipse เรียบร้อย" -ForegroundColor Green
Write-Host "ยังต้องลง Quartus + Packet Tracer ด้วยตนเอง" -ForegroundColor Yellow
