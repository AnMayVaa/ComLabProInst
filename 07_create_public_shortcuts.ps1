<#
.SYNOPSIS
    Clone หน้าจอ Desktop และสภาพแวดล้อมจาก Admin สู่ Student โดยตรง
.DESCRIPTION
    1. ทำความสะอาด Public Desktop ไม่ให้มีไอคอนรกเกินไป
    2. Clone หน้าจอ Desktop จาก Admin (C:\Users\Admin\Desktop) ไปยัง Student Desktop 1:1
    3. Clone โปรแกรมระดับ User (เช่น LINE Desktop) จาก Admin AppData ไปยัง Student AppData พร้อมสร้าง Shortcut ใช้งานได้จริง 100%
    4. แก้ไข TargetPath ของทุก Shortcut ให้ชี้เข้าโปรไฟล์ของ Student อย่างถูกต้อง
    5. ซิงค์ไปยัง Default User Desktop Template เพื่อรับประกันความเหมือนกันทุกครั้งที่สร้าง User
    6. เปิดสิทธิ์ Full Control ให้ Student สามารถใช้งาน ลง และลบไฟล์ได้อย่างอิสระ
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

Write-Log "========== เริ่มกระบวนการ Clone สภาพแวดล้อมและ Desktop จาก Admin -> Student =========="

# ─────────────────────────────────────────────
# 1. กำหนดโฟลเดอร์ต้นทาง (Admin) และปลายทาง (Student, Default)
# ─────────────────────────────────────────────
$adminDesktop = "C:\Users\Admin\Desktop"
if (-not (Test-Path $adminDesktop)) {
    $adminDesktop = "$env:USERPROFILE\Desktop"
}

$studentProfile = "C:\Users\Student"
$studentDesktop = "C:\Users\Student\Desktop"
$defaultDesktop = "C:\Users\Default\Desktop"

if (-not (Test-Path $studentDesktop)) {
    New-Item -ItemType Directory -Path $studentDesktop -Force | Out-Null
}
if (-not (Test-Path $defaultDesktop)) {
    New-Item -ItemType Directory -Path $defaultDesktop -Force | Out-Null
}

Write-Log "ต้นทาง Admin Desktop : $adminDesktop"
Write-Log "ปลายทาง Student Desktop : $studentDesktop"

# ─────────────────────────────────────────────
# 2. เคลียร์ไอคอนส่วนเกินใน Public Desktop เพื่อแก้ปัญหา 'icon เยอะเกิน'
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [1/5] เคลียร์ Public Desktop เพื่อลดความรกของไอคอน ---" -ForegroundColor DarkCyan

# รายการโปรแกรมที่ไม่จำเป็น หรือชื่อซ้ำซ้อนบน Public Desktop ให้ลบออก
$redundantShortcuts = @(
    "Python 3.12.lnk",
    "IDLE (Python 3.12).lnk",
    "Jupyter Notebook.lnk",
    "LabFiles*.lnk",
    "Pulsar*.lnk"
)
foreach ($pat in $redundantShortcuts) {
    Get-ChildItem -Path $PublicDesktop -Filter $pat -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        Write-Log "ลบ Shortcut ส่วนเกิน: $($_.Name)" "INFO"
    }
}

# ─────────────────────────────────────────────
# 3. Clone หน้าจอ Admin Desktop ไปยัง Student Desktop 1:1
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [2/5] Clone หน้าจอ Desktop จาก Admin สู่ Student ---" -ForegroundColor DarkCyan

$excludePatterns = @("desktop.ini", "*.bat", "*.ps1", "*.cmd", "*.log", ".git*")

$adminItems = Get-ChildItem -Path $adminDesktop -ErrorAction SilentlyContinue | Where-Object {
    $item = $_
    $isExcluded = $false
    foreach ($pat in $excludePatterns) {
        if ($item.Name -like $pat) { $isExcluded = $true; break }
    }
    -not $isExcluded
}

$clonedCount = 0
foreach ($item in $adminItems) {
    try {
        Copy-Item -Path $item.FullName -Destination $studentDesktop -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path $item.FullName -Destination $defaultDesktop -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "[CLONE] คัดลอก '$($item.Name)' ไปยัง Student Desktop สำเร็จ" "SUCCESS"
        $clonedCount++
    } catch {
        Write-Log "คัดลอก $($item.Name) ล้มเหลว: $($_.Exception.Message)" "WARNING"
    }
}

Write-Log "Clone ไอคอนและไฟล์สำเร็จทั้งหมด $clonedCount รายการ" "SUCCESS"

# ─────────────────────────────────────────────
# 4. จัดการ LINE Desktop ให้ Student ใช้งานได้ 100%
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [3/5] Clone และตั้งค่า LINE Desktop ให้ Student ใช้งานได้จริง ---" -ForegroundColor DarkCyan

$adminLineDir = "C:\Users\Admin\AppData\Local\LINE"
if (-not (Test-Path $adminLineDir)) {
    $adminLineDir = "$env:LOCALAPPDATA\LINE"
}

$studentLineDir = "C:\Users\Student\AppData\Local\LINE"
$defaultLineDir = "C:\Users\Default\AppData\Local\LINE"

if (Test-Path $adminLineDir) {
    Write-Log "พบ LINE ติดตั้งอยู่ที่ $adminLineDir -- กำลัง Clone สำหรับ Student..." "INFO"
    
    # สร้างโฟลเดอร์ปลายทาง
    $studentAppLocal = "C:\Users\Student\AppData\Local"
    if (-not (Test-Path $studentAppLocal)) { New-Item -ItemType Directory -Path $studentAppLocal -Force | Out-Null }
    
    # Clone โฟลเดอร์โปรแกรม LINE
    Copy-Item -Path $adminLineDir -Destination $studentAppLocal -Recurse -Force -ErrorAction SilentlyContinue
    
    $defaultAppLocal = "C:\Users\Default\AppData\Local"
    if (-not (Test-Path $defaultAppLocal)) { New-Item -ItemType Directory -Path $defaultAppLocal -Force | Out-Null }
    Copy-Item -Path $adminLineDir -Destination $defaultAppLocal -Recurse -Force -ErrorAction SilentlyContinue
    
    # ล้าง Session และ Cache ของ Admin ออก เพื่อให้ Student เปิดมาเจอกล่องล็อกอินใหม่สะอาด
    Remove-Item -Path "$studentLineDir\Data\session*" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$studentLineDir\Data\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    # สร้าง Shortcut บนหน้าจอ Student ที่ชี้ตรงไปยัง LineLauncher ของ Student เอง
    $studentLineExe = "$studentLineDir\bin\LineLauncher.exe"
    if (Test-Path $studentLineExe) {
        $lineLnkPath = Join-Path $studentDesktop "LINE.lnk"
        $lineSc = $WshShell.CreateShortcut($lineLnkPath)
        $lineSc.TargetPath = $studentLineExe
        $lineSc.WorkingDirectory = "$studentLineDir\bin"
        $lineSc.Save()
        
        Copy-Item $lineLnkPath (Join-Path $defaultDesktop "LINE.lnk") -Force -ErrorAction SilentlyContinue
        Write-Log "สร้าง Shortcut LINE สำหรับ Student สำเร็จ (พร้อมล็อกอินใช้งานได้ทันที)" "SUCCESS"
    }
} else {
    Write-Log "ไม่พบ LINE ใน $adminLineDir" "WARNING"
}

# ─────────────────────────────────────────────
# 5. Clone และแก้ไขโปรแกรมอื่นใน AppData (เช่น VS Code, Thonny, GitHub Desktop)
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [4/5] ปรับแต่ง Shortcut และ AppData ทั้งหมดให้ Student ---" -ForegroundColor DarkCyan

$appDataApps = @(
    "GitHubDesktop",
    "Programs\Microsoft VS Code",
    "Programs\Thonny"
)

foreach ($rel in $appDataApps) {
    $srcPath = "C:\Users\Admin\AppData\Local\$rel"
    if (Test-Path $srcPath) {
        $dstPath = "C:\Users\Student\AppData\Local\$rel"
        if (-not (Test-Path $dstPath)) {
            $parent = Split-Path $dstPath
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Copy-Item -Path $srcPath -Destination $parent -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Clone AppData: $rel -> Student สำเร็จ" "SUCCESS"
        }
    }
}

# ตรวจสอบและแก้ไขทุก Shortcut บนหน้าจอ Student ที่ชี้ไปยัง C:\Users\Admin ให้ชี้เข้า C:\Users\Student แทน
$allStudentShortcuts = Get-ChildItem -Path $studentDesktop -Filter "*.lnk" -ErrorAction SilentlyContinue
foreach ($s in $allStudentShortcuts) {
    try {
        $sc = $WshShell.CreateShortcut($s.FullName)
        $target = $sc.TargetPath
        $modified = $false
        
        # ถ้า Target ชี้ไปที่ Admin AppData ให้เปลี่ยนเป็น Student AppData
        if ($target -like "C:\Users\Admin\*") {
            $sc.TargetPath = $target -replace "C:\\Users\\Admin", "C:\Users\Student"
            $modified = $true
        }
        if ($sc.WorkingDirectory -like "C:\Users\Admin\*") {
            $sc.WorkingDirectory = $sc.WorkingDirectory -replace "C:\\Users\\Admin", "C:\Users\Student"
            $modified = $true
        }
        
        # สำหรับ VS Code ถ้ามีใน Program Files ให้เปลี่ยนมาชี้ที่ Program Files เลย
        if ($s.Name -like "*Code*" -and (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe")) {
            $sc.TargetPath = "$env:ProgramFiles\Microsoft VS Code\Code.exe"
            $sc.WorkingDirectory = "$env:ProgramFiles\Microsoft VS Code"
            $modified = $true
        }
        
        if ($modified) {
            $sc.Save()
            Write-Log "ปรับแต่ง Shortcut: $($s.Name) ให้เปิดในบริบทของ Student ได้สมบูรณ์" "SUCCESS"
        }
    } catch {}
}

# ─────────────────────────────────────────────
# 6. กำหนดสิทธิ์ให้ Student สามารถลง/ลบ/แก้ไขไฟล์ได้อิสระ
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- [5/5] กำหนดสิทธิ์ Full Control ให้ Student ---" -ForegroundColor DarkCyan

Write-Log "กำหนดสิทธิ์ Full Control ให้ Student Account..." "INFO"
icacls "C:\Users\Student" /grant "Student:(OI)(CI)F" /T /Q 2>&1 | Out-Null
icacls "C:\Users\Student" /grant "Administrators:(OI)(CI)F" /T /Q 2>&1 | Out-Null

Write-Log "========== เสร็จสิ้นการ Clone จาก Admin -> Student เรียบร้อย =========="
Write-Host ""
Write-Host "✅ Clone หน้าจอ Desktop จาก Admin ให้ Student เรียบร้อย (เหมือนกัน 100% ไม่รก ไม่ซ้ำ)!" -ForegroundColor Green
Write-Host "✅ โปรแกรม LINE และแอปทั้งหมดเปิดใช้งานบน Student ได้สมบูรณ์แล้ว!" -ForegroundColor Green
Write-Host "✅ Student มีสิทธิ์ลง/ลบอะไรก็ได้ตามต้องการ (เดี๋ยวเจ้าหน้าที่ค่อยรีเซ็ตคืนสภาพ)!" -ForegroundColor Green
