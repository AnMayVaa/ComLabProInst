<#
.SYNOPSIS
    สร้างและจัดการ Desktop Shortcuts & Shared Files สำหรับทุกผู้ใช้งาน (Admin และ Student)
.DESCRIPTION
    1. ตรวจสอบ Shortcuts ที่มีอยู่แล้วบน Desktop ถ้ามีแล้วจะไม่สร้างซ้ำ
    2. รวม Shortcuts จาก Admin Desktop ไปยัง Public Desktop เพื่อให้ Student มองเห็นด้วย
    3. ซิงค์ไฟล์บทเรียน/เอกสารที่ต้องการแชร์ไปยัง Student และ Public Desktop
    4. สร้างโฟลเดอร์ส่วนกลาง C:\LabFiles สำหรับแชร์ไฟล์แลป และสร้าง Shortcut หน้า Desktop
    5. กำหนดสิทธิ์ NTFS (icacls) ให้กลุ่ม Users (Student) เข้าถึงและรันโปรแกรมได้ 100%
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

Write-Log "========== เริ่มจัดการ Desktop & Shared Files ให้ Admin และ Student =========="
Write-Log "เป้าหมาย Public Desktop: $PublicDesktop"

# ─────────────────────────────────────────────
# 1. รวบรวมและย้าย Shortcuts จาก Admin Desktop -> Public Desktop
# (เพื่อไม่ให้มี Shortcut ซ้ำซ้อน และทำให้ Student มองเห็นโปรแกรมที่ Admin มี)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [1/5] รวบรวม Shortcuts จาก Admin Desktop สู่ Public Desktop ---" -ForegroundColor DarkCyan

$adminDesktopPaths = @(
    "$env:USERPROFILE\Desktop",
    "C:\Users\Admin\Desktop",
    "C:\Users\Administrator\Desktop"
) | Select-Object -Unique

foreach ($adPath in $adminDesktopPaths) {
    if ((Test-Path $adPath) -and ($adPath -ne $PublicDesktop)) {
        Write-Log "กำลังตรวจสอบ: $adPath" "INFO"
        $adminLinks = Get-ChildItem -Path $adPath -Filter "*.lnk" -ErrorAction SilentlyContinue
        
        foreach ($lnk in $adminLinks) {
            try {
                $destPath = Join-Path $PublicDesktop $lnk.Name
                if (Test-Path $destPath) {
                    # ถ้ามีบน Public Desktop อยู่แล้ว ให้ลบตัวซ้ำใน Admin Desktop เพื่อไม่ให้เห็นไอคอนเบิ้ล
                    Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
                    Write-Log "[DEDUP] ลบ Shortcut ซ้ำบน Admin Desktop: $($lnk.Name)" "SKIP"
                } else {
                    # ย้ายไปที่ Public Desktop เพื่อให้ทั้ง Admin และ Student มองเห็นไอคอนเดียวกัน
                    Move-Item -Path $lnk.FullName -Destination $destPath -Force -ErrorAction SilentlyContinue
                    Write-Log "[SHARED] ย้าย Shortcut '$($lnk.Name)' สู่ Public Desktop สำเร็จ" "SUCCESS"
                }
            } catch {}
        }
    }
}

# ─────────────────────────────────────────────
# 2. ฟังก์ชันตรวจสอบและสร้าง Public Shortcut
# (ถ้ามีอยู่แล้ว หรือมี Shortcut ที่ชี้ไปยัง Target เดียวกัน จะข้ามทันที)
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
        Write-Log "[NOT FOUND] ไม่พบ $Name ในระบบ -- ข้ามการสร้าง Shortcut" "WARNING"
        return $false
    }

    # 1. เช็คว่ามีไฟล์ Shortcut ชื่อนี้อยู่บน Public Desktop แล้วหรือไม่
    $shortcutPath = Join-Path $PublicDesktop "$Name.lnk"
    if (Test-Path $shortcutPath) {
        Write-Log "[SKIP] มี Shortcut '$Name.lnk' อยู่บน Desktop แล้ว -- ข้าม" "SKIP"
        return $true
    }

    # 2. เช็คว่ามี Shortcut ใดๆ ใน Public Desktop ที่ชี้ไปยัง $targetExe อยู่แล้วหรือไม่ (เช่น ชื่อต่างกันเล็กน้อย)
    $allExistingLnk = Get-ChildItem -Path $PublicDesktop -Filter "*.lnk" -ErrorAction SilentlyContinue
    foreach ($lnk in $allExistingLnk) {
        try {
            $sc = $WshShell.CreateShortcut($lnk.FullName)
            if ($sc.TargetPath -ieq $targetExe) {
                Write-Log "[SKIP] มี Shortcut ชี้ไปยังเป้าหมายแล้ว ($($lnk.Name)) -- ข้าม" "SKIP"
                return $true
            }
        } catch {}
    }

    # 3. ถ้ายังไม่มี ให้สร้างใหม่
    try {
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

        Write-Log "[SUCCESS] สร้าง Shortcut ใหม่: $Name -> $shortcutPath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "[FAIL] สร้าง Shortcut ล้มเหลวสำหรับ ${Name} - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ─────────────────────────────────────────────
# 3. รายการโปรแกรมทั้งหมดที่ต้องการให้มีบน Desktop
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [2/5] ตรวจสอบและสร้าง Shortcuts โปรแกรมการเรียนการสอน ---" -ForegroundColor DarkCyan

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
            "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe",
            "$env:ProgramFiles\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe",
            "C:\Program Files\Microsoft SQL Server Management Studio *\Common7\IDE\Ssms.exe",
            "C:\Program Files (x86)\Microsoft SQL Server Management Studio *\Common7\IDE\Ssms.exe"
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
# 4. สร้างพื้นที่แชร์ไฟล์บทเรียน C:\LabFiles สำหรับแลป
# (แก้ไขปัญหา Student ไม่เห็นไฟล์เอกสารของ Admin)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [3/5] จัดเตรียมพื้นที่แชร์ไฟล์บทเรียน (C:\LabFiles) ---" -ForegroundColor DarkCyan

$labShareDir = "C:\LabFiles"
if (-not (Test-Path $labShareDir)) {
    New-Item -ItemType Directory -Path $labShareDir -Force | Out-Null
    Write-Log "สร้างโฟลเดอร์แชร์งานแลป: $labShareDir" "SUCCESS"
}

# กำหนดสิทธิ์ให้นักศึกษา (Users) มีสิทธิ์เปิด อ่าน แก้ไข และบันทึกไฟล์ใน C:\LabFiles ได้
icacls "$labShareDir" /grant "Users:(OI)(CI)M" /Q 2>&1 | Out-Null
Write-Log "กำหนดสิทธิ์ให้กลุ่ม Users (Student) เข้าถึงและบันทึกไฟล์ใน $labShareDir ได้สมบูรณ์" "SUCCESS"

# สร้าง Shortcut ไปยัง C:\LabFiles บน Desktop
$labShareLnk = Join-Path $PublicDesktop "LabFiles (พื้นที่แชร์ไฟล์บทเรียน).lnk"
if (-not (Test-Path $labShareLnk)) {
    $folderShortcut = $WshShell.CreateShortcut($labShareLnk)
    $folderShortcut.TargetPath = $labShareDir
    $folderShortcut.Description = "โฟลเดอร์สำหรับแชร์เอกสาร ใบงาน และไฟล์แลประหว่างอาจารย์กับนักศึกษา"
    $folderShortcut.Save()
    Write-Log "[SUCCESS] สร้าง Shortcut 'LabFiles' บนหน้าจอ Desktop ให้ทุก User" "SUCCESS"
}

# ─────────────────────────────────────────────
# 5. ซิงค์ไฟล์บทเรียนจาก Admin Desktop สู่ Public Desktop (ถ้ามี)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [4/5] ซิงค์ไฟล์งาน/เอกสารจาก Admin Desktop สู่ Public Desktop ---" -ForegroundColor DarkCyan

$excludePatterns = @("*.lnk", "*.bat", "*.ps1", "*.cmd", "desktop.ini", "*.log", ".git*")
foreach ($adPath in $adminDesktopPaths) {
    if ((Test-Path $adPath) -and ($adPath -ne $PublicDesktop)) {
        $filesToShare = Get-ChildItem -Path $adPath -File -ErrorAction SilentlyContinue | Where-Object {
            $f = $_
            $isExcluded = $false
            foreach ($pat in $excludePatterns) {
                if ($f.Name -like $pat) { $isExcluded = $true; break }
            }
            -not $isExcluded
        }
        foreach ($file in $filesToShare) {
            $destFile = Join-Path $PublicDesktop $file.Name
            if (-not (Test-Path $destFile)) {
                Copy-Item -Path $file.FullName -Destination $destFile -Force -ErrorAction SilentlyContinue
                Write-Log "[SYNC] คัดลอกไฟล์เอกสาร '$($file.Name)' ไปยัง Public Desktop เรียบร้อย" "SUCCESS"
            }
        }
    }
}

# ─────────────────────────────────────────────
# 6. คัดลอก Shortcuts สู่ Default User และปรับสิทธิ์ NTFS
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [5/5] กำหนดสิทธิ์และอัปเดต Default Profile ---" -ForegroundColor DarkCyan

# 1. ให้สิทธิ์ Users อ่าน Public Desktop
icacls "$PublicDesktop" /grant "Users:(OI)(CI)RX" /Q 2>&1 | Out-Null

# 2. คัดลอก Shortcuts ไปยัง Default Profile Desktop เผื่อการสร้างโปรไฟล์ใหม่
$defaultDesktop = "C:\Users\Default\Desktop"
if (Test-Path $defaultDesktop) {
    Copy-Item -Path "$PublicDesktop\*.lnk" -Destination $defaultDesktop -Force -ErrorAction SilentlyContinue
    Write-Log "อัปเดต Shortcuts ไปยัง Default User Desktop Template เรียบร้อย" "INFO"
}

# 3. ถ้าโฟลเดอร์ Student Desktop มีอยู่แล้ว ให้สิทธิ์ Users เต็มที่
$studentDesktop = "C:\Users\Student\Desktop"
if (Test-Path $studentDesktop) {
    icacls "$studentDesktop" /grant "Users:(OI)(CI)F" /Q 2>&1 | Out-Null
}

# 4. ให้สิทธิ์ Users กับโฟลเดอร์โปรแกรมที่ติดตั้งในระดับระบบและ AppData
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

Write-Log "========== เสร็จสิ้นการจัดการ Desktop & Shared Files =========="
Write-Host ""
Write-Host "✅ ทุกโปรแกรมและไฟล์ที่แชร์จะปรากฏบน Desktop ของทั้ง Admin และ Student ทันที!" -ForegroundColor Green
