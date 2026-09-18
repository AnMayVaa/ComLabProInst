<#
.SYNOPSIS
    ซิงค์หน้าจอ Desktop ให้ Admin และ Student เห็นเหมือนกัน 100%
.DESCRIPTION
    1. ตรวจสอบ Shortcuts ที่มีอยู่แล้ว ถ้ามีอยู่แล้วจะไม่สร้างซ้ำ
    2. ย้าย Shortcuts และไฟล์ทั้งหมดจากหน้าจอ Admin มาไว้ที่ Public Desktop เพื่อให้ Student มองเห็นเหมือนกันทุกอย่าง
    3. สร้าง Shortcuts โปรแกรมที่ยังขาดอยู่ลงบน Public Desktop
    4. คัดลอก Shortcuts ทั้งหมดไปไว้ที่ Default User และ Student Desktop เพื่อรับประกันว่าหน้าจอเหมือนกันแน่นอน
    5. กำหนดสิทธิ์ NTFS (icacls) ให้ Student (Users) สามารถเปิดและใช้งานโปรแกรมได้ทุกตัว
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$LogFile = Join-Path $PSScriptRoot "logs\07_shortcuts.log"
$PublicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory") # C:\Users\Public\Desktop
$WshShell = New-Object -ComObject WScript.Shell

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
    if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

Write-Log "========== เริ่มซิงค์หน้าจอ Desktop ให้ Admin และ Student เหมือนกัน 100% =========="
Write-Log "เป้าหมาย Public Desktop: $PublicDesktop"

# ─────────────────────────────────────────────
# 1. ย้าย Shortcuts และไฟล์จาก Admin Desktop สู่ Public Desktop
# เพื่อให้สิ่งที่ Admin เห็นบนหน้าจอ ปรากฏให้ Student เห็นด้วยทั้งหมด
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [1/4] ซิงค์ไฟล์และ Shortcuts จากหน้าจอ Admin สู่ Public Desktop ---" -ForegroundColor DarkCyan

$adminDesktopPaths = @(
    "$env:USERPROFILE\Desktop",
    "C:\Users\Admin\Desktop",
    "C:\Users\Administrator\Desktop"
) | Select-Object -Unique

# รายการไฟล์ที่ไม่ต้องซิงค์ (ไฟล์ระบบและสคริปต์ติดตั้ง)
$excludePatterns = @("desktop.ini", "*.bat", "*.ps1", "*.cmd", "*.log", ".git*")

foreach ($adPath in $adminDesktopPaths) {
    if ((Test-Path $adPath) -and ($adPath -ne $PublicDesktop)) {
        Write-Log "กำลังตรวจสอบหน้าจอ Admin: $adPath" "INFO"
        
        # 1.1 จัดการไฟล์ Shortcut (.lnk)
        $adminLinks = Get-ChildItem -Path $adPath -Filter "*.lnk" -ErrorAction SilentlyContinue
        foreach ($lnk in $adminLinks) {
            try {
                $destPath = Join-Path $PublicDesktop $lnk.Name
                if (Test-Path $destPath) {
                    # มีบน Public Desktop แล้ว ลบตัวซ้ำใน Admin เพื่อไม่ให้มีไอคอนเบิ้ล
                    Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
                    Write-Log "[DEDUP] ลบ Shortcut ซ้ำบน Admin Desktop: $($lnk.Name)" "SKIP"
                } else {
                    # ย้ายไป Public Desktop เพื่อให้ Student เห็นด้วย
                    Move-Item -Path $lnk.FullName -Destination $destPath -Force -ErrorAction SilentlyContinue
                    Write-Log "[SHARED] ย้าย Shortcut '$($lnk.Name)' ไปยังหน้าจอหลัก (Public Desktop)" "SUCCESS"
                }
            } catch {}
        }

        # 1.2 จัดการไฟล์/โฟลเดอร์อื่นๆ ที่ Admin วางไว้บนหน้าจอ (เช่น ไฟล์งาน, เอกสาร)
        $otherItems = Get-ChildItem -Path $adPath -ErrorAction SilentlyContinue | Where-Object {
            $item = $_
            $isExcluded = $false
            foreach ($pat in $excludePatterns) {
                if ($item.Name -like $pat) { $isExcluded = $true; break }
            }
            (-not $isExcluded) -and ($item.Extension -ne ".lnk")
        }

        foreach ($item in $otherItems) {
            try {
                $destItem = Join-Path $PublicDesktop $item.Name
                if (-not (Test-Path $destItem)) {
                    Copy-Item -Path $item.FullName -Destination $destItem -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "[SYNC] คัดลอก '$($item.Name)' ไปยัง Public Desktop ให้ Student มองเห็นด้วย" "SUCCESS"
                }
            } catch {}
        }
    }
}

# ─────────────────────────────────────────────
# 2. ฟังก์ชันตรวจสอบและสร้าง Shortcut
# (ถ้ามีอยู่แล้วหน้า Desktop หรือมี Shortcut ชี้ไปยังโปรแกรมเดียวกัน จะข้ามทันที)
# ─────────────────────────────────────────────
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
        Write-Log "[NOT FOUND] ไม่พบ $Name ในระบบ -- ข้าม" "WARNING"
        return $false
    }

    # 1. ถ้ามี Shortcut ชื่อนี้อยู่แล้วบน Desktop ให้ข้ามทันที
    $shortcutPath = Join-Path $PublicDesktop "$Name.lnk"
    if (Test-Path $shortcutPath) {
        Write-Log "[SKIP] มี Shortcut '$Name.lnk' อยู่บน Desktop แล้ว -- ข้าม" "SKIP"
        return $true
    }

    # 2. ถ้ามี Shortcut อื่นที่ชี้ไปยังไฟล์ .exe เดียวกันอยู่แล้ว ให้ข้ามทันที
    $allExistingLnk = Get-ChildItem -Path $PublicDesktop -Filter "*.lnk" -ErrorAction SilentlyContinue
    foreach ($lnk in $allExistingLnk) {
        try {
            $sc = $WshShell.CreateShortcut($lnk.FullName)
            if ($sc.TargetPath -ieq $targetExe) {
                Write-Log "[SKIP] มี Shortcut ที่ชี้ไปยัง $Name อยู่แล้ว ($($lnk.Name)) -- ข้าม" "SKIP"
                return $true
            }
        } catch {}
    }

    # 3. ถ้ายังไม่มีบนหน้าจอ ให้สร้างใหม่
    try {
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetExe
        $shortcut.WorkingDirectory = Split-Path $targetExe
        if ($Arguments) {
            $shortcut.Arguments = $Arguments
        }
        $shortcut.Save()

        # ให้สิทธิ์ Users อ่านและเปิดใช้งานได้
        $appDir = Split-Path $targetExe
        icacls "$appDir" /grant "Users:(OI)(CI)RX" /Q 2>&1 | Out-Null

        Write-Log "[SUCCESS] สร้าง Shortcut: $Name -> $shortcutPath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "[FAIL] สร้าง Shortcut ล้มเหลว: ${Name} - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ─────────────────────────────────────────────
# 3. รายการโปรแกรมมาตรฐานของห้องแลป
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [2/4] ตรวจสอบโปรแกรมทั้งหมดและสร้าง Shortcuts ที่ยังขาด ---" -ForegroundColor DarkCyan

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
        Name = "CodeBlocks"
        Paths = @(
            "$env:ProgramFiles\CodeBlocks\codeblocks.exe",
            "${env:ProgramFiles(x86)}\CodeBlocks\codeblocks.exe"
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
        Name = "LINE"
        Paths = @(
            "C:\Program Files\LINE\bin\LineLauncher.exe",
            "${env:ProgramFiles(x86)}\LINE\bin\LineLauncher.exe",
            "$env:LOCALAPPDATA\LINE\bin\LineLauncher.exe",
            "C:\Users\ADMIN\AppData\Local\LINE\bin\LineLauncher.exe"
        )
    },
    @{
        Name = "SQL Server Management Studio"
        Paths = @(
            "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio*\Common7\\IDE\Ssms.exe",
            "$env:ProgramFiles\Microsoft SQL Server Management Studio*\Common7\\IDE\Ssms.exe",
            "C:\Program Files\Microsoft SQL Server Management Studio *\Common7\\IDE\Ssms.exe",
            "C:\Program Files (x86)\Microsoft SQL Server Management Studio *\Common7\\IDE\Ssms.exe"
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

foreach ($app in $appDefinitions) {
    Create-PublicShortcut -Name $app.Name -CandidatePaths $app.Paths | Out-Null
}

# ─────────────────────────────────────────────
# 4. คัดลอกสู่ Default User & Student Desktop และเปิดสิทธิ์ NTFS
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [3/4] รับประกันความเหมือนกันระหว่าง Admin และ Student ---" -ForegroundColor DarkCyan

# ให้สิทธิ์กลุ่ม Users (Student) เข้าถึง Public Desktop
icacls "$PublicDesktop" /grant "Users:(OI)(CI)RX" /Q 2>&1 | Out-Null

# คัดลอก Shortcuts และไฟล์ทั้งหมดไปยัง Default User Desktop Template
# เพื่อให้ทุกบัญชีใหม่ที่สร้างขึ้น ได้รับหน้าจอ Desktop ที่เหมือนกันทันที
$defaultDesktop = "C:\Users\Default\Desktop"
if (Test-Path $defaultDesktop) {
    Copy-Item -Path "$PublicDesktop\*" -Destination $defaultDesktop -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "ซิงค์หน้าจอไปยัง Default User Template สำเร็จ" "INFO"
}

# ถ้ามีโฟลเดอร์ Student Desktop อยู่แล้ว ให้คัดลอกไฟล์ทั้งหมดไปใส่ และเปิดสิทธิ์ให้ Student
$studentDesktop = "C:\Users\Student\Desktop"
if (Test-Path $studentDesktop) {
    Copy-Item -Path "$PublicDesktop\*" -Destination $studentDesktop -Recurse -Force -ErrorAction SilentlyContinue
    icacls "$studentDesktop" /grant "Users:(OI)(CI)F" /Q 2>&1 | Out-Null
    Write-Log "ซิงค์หน้าจอไปยัง Student Desktop สำเร็จ" "INFO"
}

# ─────────────────────────────────────────────
# 5. เปิดสิทธิ์การใช้งานโปรแกรมให้ Student (Users)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [4/4] เปิดสิทธิ์การรันโปรแกรมให้ Student ---" -ForegroundColor DarkCyan

$appFoldersToGrant = @(
    "C:\Program Files\Python312",
    "C:\Program Files\LINE",
    "C:\Processing",
    "C:\Eclipse",
    "C:\Users\ADMIN\AppData\Local\Programs\Microsoft VS Code",
    "C:\Users\ADMIN\AppData\Local\Programs\Thonny",
    "C:\Users\ADMIN\AppData\Local\LINE",
    "C:\Users\ADMIN\AppData\Local\GitHubDesktop"
)

foreach ($f in $appFoldersToGrant) {
    if (Test-Path $f) {
        icacls "$f" /grant "Users:(OI)(CI)RX" /T /Q 2>&1 | Out-Null
    }
}

Write-Log "========== เสร็จสิ้น: หน้าจอ Desktop ของ Admin และ Student เหมือนกัน 100% เรียบร้อย =========="
Write-Host ""
Write-Host "✅ หน้าจอ Desktop ของ Admin และ Student มีโปรแกรมและไฟล์เหมือนกันทุกประการ!" -ForegroundColor Green
Write-Host "🔒 ความแตกต่าง: Admin มีสิทธิ์ตั้งค่าระบบและลงโปรแกรม ส่วน Student เป็น Standard User" -ForegroundColor Cyan
