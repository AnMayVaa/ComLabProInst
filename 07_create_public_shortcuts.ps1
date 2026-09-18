<#
.SYNOPSIS
    สร้าง Desktop Shortcuts ใน Public Desktop เพื่อแชร์ให้ทุกผู้ใช้งาน (Admin และ Student)
.DESCRIPTION
    1. สแกนหาตำแหน่ง Executable ของทุกโปรแกรมในแลป
    2. ปรับสิทธิ์ NTFS (icacls) ให้กลุ่ม Users / Student สามารถเปิดใช้งานได้
    3. สร้าง Desktop Shortcut (.lnk) ลงที่ C:\Users\Public\Desktop
    4. ทุกบัญชีที่ล็อกอินจะมองเห็นโปรแกรมบนหน้าจอ Desktop ทันที
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$LogFile = Join-Path $PSScriptRoot "logs\07_shortcuts.log"
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

Write-Log "========== เริ่มสร้าง Public Desktop Shortcuts ให้ทุก User =========="
Write-Log "เป้าหมาย Public Desktop: $PublicDesktop"

$WshShell = New-Object -ComObject WScript.Shell

function Create-PublicShortcut {
    param(
        [string]$Name,
        [string[]]$CandidatePaths,
        [string]$Arguments = ""
    )

    $targetExe = $null
    foreach ($path in $CandidatePaths) {
        $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
        if ($resolved) {
            $targetExe = $resolved[-1].Path
            break
        }
    }

    if (-not $targetExe) {
        Write-Log "[NOT FOUND] ไม่พบ $Name ในระบบ (อาจยังไม่ได้ติดตั้ง) -- ข้ามการสร้าง Shortcut" "WARNING"
        return $false
    }

    try {
        $shortcutPath = Join-Path $PublicDesktop "$Name.lnk"
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetExe
        $shortcut.WorkingDirectory = Split-Path $targetExe
        if ($Arguments) {
            $shortcut.Arguments = $Arguments
        }
        $shortcut.Save()

        # ให้สิทธิ์ Users อ่านและรันโปรแกรมได้
        $appDir = Split-Path $targetExe
        icacls "$appDir" /grant "Users:(OI)(CI)RX" /Q 2>&1 | Out-Null

        Write-Log "[SUCCESS] สร้าง Shortcut: $Name -> $shortcutPath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "[FAIL] สร้าง Shortcut ล้มเหลวสำหรับ ${Name} - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ─────────────────────────────────────────────
# รายการโปรแกรมทั้งหมดที่ต้องการสร้าง Shortcut
# ─────────────────────────────────────────────
$appDefinitions = @(
    @{
        Name = "Python 3.12"
        Paths = @(
            "C:\Program Files\Python312\python.exe",
            "$env:ProgramFiles\Python312\python.exe",
            "C:\Python312\python.exe"
        )
    },
    @{
        Name = "IDLE (Python 3.12)"
        Paths = @(
            "C:\Program Files\Python312\Lib\idlelib\idle.bat",
            "$env:ProgramFiles\Python312\Lib\idlelib\idle.bat"
        )
    },
    @{
        Name = "Jupyter Notebook"
        Paths = @(
            "C:\Program Files\Python312\Scripts\jupyter-notebook.exe",
            "$env:ProgramFiles\Python312\Scripts\jupyter-notebook.exe"
        )
    },
    @{
        Name = "Google Chrome"
        Paths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        )
    },
    @{
        Name = "Visual Studio Code"
        Paths = @(
            "$env:ProgramFiles\Microsoft VS Code\Code.exe",
            "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe",
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
            "C:\Users\ADMIN\AppData\Local\Programs\Microsoft VS Code\Code.exe"
        )
    },
    @{
        Name = "Dev-C++"
        Paths = @(
            "$env:ProgramFiles\Embarcadero\Dev-Cpp\devcpp.exe",
            "${env:ProgramFiles(x86)}\Embarcadero\Dev-Cpp\devcpp.exe",
            "C:\Program Files (x86)\Dev-Cpp\devcpp.exe",
            "C:\Program Files\Dev-Cpp\devcpp.exe"
        )
    },
    @{
        Name = "SQL Server Management Studio"
        Paths = @(
            "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe",
            "$env:ProgramFiles\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe"
        )
    },
    @{
        Name = "LINE"
        Paths = @(
            "C:\Program Files\LINE\bin\LineLauncher.exe",
            "${env:ProgramFiles(x86)}\LINE\bin\LineLauncher.exe",
            "$env:LOCALAPPDATA\LINE\bin\LineLauncher.exe",
            "C:\Users\ADMIN\AppData\Local\LINE\bin\LineLauncher.exe"
        )
    },
    @{
        Name = "Processing"
        Paths = @(
            "C:\Program Files\Processing 4\processing.exe",
            "C:\Program Files\Processing\processing.exe",
            "${env:ProgramFiles(x86)}\Processing\processing.exe",
            "C:\Processing\processing.exe"
        )
    },
    @{
        Name = "Thonny"
        Paths = @(
            "$env:ProgramFiles\Thonny\thonny.exe",
            "${env:ProgramFiles(x86)}\Thonny\thonny.exe",
            "$env:LOCALAPPDATA\Programs\Thonny\thonny.exe",
            "C:\Users\ADMIN\AppData\Local\Programs\Thonny\thonny.exe"
        )
    },
    @{
        Name = "Arduino IDE"
        Paths = @(
            "$env:ProgramFiles\Arduino IDE\Arduino IDE.exe",
            "$env:LOCALAPPDATA\Programs\Arduino IDE\Arduino IDE.exe",
            "C:\Users\ADMIN\AppData\Local\Programs\Arduino IDE\Arduino IDE.exe"
        )
    },
    @{
        Name = "IntelliJ IDEA Community"
        Paths = @(
            "$env:ProgramFiles\JetBrains\IntelliJ IDEA Community Edition*\bin\idea64.exe"
        )
    },
    @{
        Name = "CodeBlocks"
        Paths = @(
            "$env:ProgramFiles\CodeBlocks\codeblocks.exe",
            "${env:ProgramFiles(x86)}\CodeBlocks\codeblocks.exe"
        )
    },
    @{
        Name = "RStudio"
        Paths = @(
            "$env:ProgramFiles\RStudio\rstudio.exe",
            "$env:ProgramFiles\Posit\RStudio\rstudio.exe"
        )
    },
    @{
        Name = "Git Bash"
        Paths = @(
            "$env:ProgramFiles\Git\git-bash.exe",
            "${env:ProgramFiles(x86)}\Git\git-bash.exe"
        )
    },
    @{
        Name = "GitHub Desktop"
        Paths = @(
            "$env:ProgramFiles\GitHub Desktop\GitHubDesktop.exe",
            "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe",
            "C:\Users\ADMIN\AppData\Local\GitHubDesktop\GitHubDesktop.exe"
        )
    },
    @{
        Name = "Wireshark"
        Paths = @(
            "$env:ProgramFiles\Wireshark\Wireshark.exe"
        )
    },
    @{
        Name = "Oracle VirtualBox"
        Paths = @(
            "$env:ProgramFiles\Oracle\VirtualBox\VirtualBox.exe"
        )
    },
    @{
        Name = "Raspberry Pi Imager"
        Paths = @(
            "$env:ProgramFiles\Raspberry Pi Imager\rpi-imager.exe",
            "${env:ProgramFiles(x86)}\Raspberry Pi Imager\rpi-imager.exe"
        )
    },
    @{
        Name = "Pulsar (Atom)"
        Paths = @(
            "$env:ProgramFiles\Pulsar\Pulsar.exe",
            "$env:LOCALAPPDATA\Programs\Pulsar\Pulsar.exe"
        )
    },
    @{
        Name = "Eclipse C++"
        Paths = @(
            "C:\Eclipse\eclipse.exe",
            "$env:ProgramFiles\Eclipse\eclipse.exe"
        )
    },
    @{
        Name = "Intel Quartus Prime"
        Paths = @(
            "C:\intelFPGA_lite\*\quartus\bin64\quartus.exe",
            "$env:ProgramFiles\intelFPGA_lite\*\quartus\bin64\quartus.exe"
        )
    },
    @{
        Name = "Cisco Packet Tracer"
        Paths = @(
            "$env:ProgramFiles\Cisco Packet Tracer*\bin\PacketTracer.exe",
            "${env:ProgramFiles(x86)}\Cisco Packet Tracer*\bin\PacketTracer.exe"
        )
    }
)

$createdCount = 0
foreach ($app in $appDefinitions) {
    if (Create-PublicShortcut -Name $app.Name -CandidatePaths $app.Paths) {
        $createdCount++
    }
}

# ─────────────────────────────────────────────
# จัดการแชร์โฟลเดอร์สำหรับโปรแกรมที่ติดตั้งใน AppData
# ─────────────────────────────────────────────
Write-Log "กำลังตรวจสอบสิทธิ์การแชร์โปรแกรมให้ Student..."

# ถ้าพบ LINE หรือ VS Code หรือ Thonny หรือ GitHub Desktop อยู่ใน AppData ของ ADMIN
# ให้เปิดสิทธิ์ Read & Execute ให้ Users เปิดใช้งานได้
$appDataFolders = @(
    "C:\Users\ADMIN\AppData\Local\Programs\Microsoft VS Code",
    "C:\Users\ADMIN\AppData\Local\Programs\Thonny",
    "C:\Users\ADMIN\AppData\Local\LINE",
    "C:\Users\ADMIN\AppData\Local\GitHubDesktop"
)

foreach ($f in $appDataFolders) {
    if (Test-Path $f) {
        Write-Log "เปิดสิทธิ์เข้าถึงให้กลุ่ม Users สำหรับ: $f" "INFO"
        icacls "$f" /grant "Users:(OI)(CI)RX" /T /Q 2>&1 | Out-Null
    }
}

# เปิดสิทธิ์โฟลเดอร์ C:\Processing และ C:\Eclipse
$customFolders = @("C:\Program Files\Python312", "C:\Processing", "C:\Eclipse", "C:\Program Files\LINE")
foreach ($cf in $customFolders) {
    if (Test-Path $cf) {
        Write-Log "เปิดสิทธิ์เข้าถึงให้กลุ่ม Users สำหรับ: $cf" "INFO"
        icacls "$cf" /grant "Users:(OI)(CI)RX" /T /Q 2>&1 | Out-Null
    }
}

Write-Log "========== เสร็จสิ้นการสร้าง Public Desktop Shortcuts ($createdCount โปรแกรม) =========="
Write-Host ""
Write-Host "✅ สร้าง Desktop Shortcuts บน Public Desktop เรียบร้อย! ทั้ง Admin และ Student จะมองเห็นบนหน้าจอทันที" -ForegroundColor Green
