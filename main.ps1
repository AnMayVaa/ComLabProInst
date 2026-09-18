<#
.SYNOPSIS
    Master Controller Script สำหรับติดตั้งห้องแลป ECE
.DESCRIPTION
    รันสคริปต์ขั้นตอนที่ 1-7 ตามลำดับ พร้อมแสดงผลภาษาไทยอย่างถูกต้อง
    และสร้าง Desktop Shortcuts บน Public Desktop ให้ทั้ง Admin และ Student
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Clear-Host
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "     ECE Computer Lab -- Automated Provisioning" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " Script นี้จะดำเนินการตามขั้นตอนดังนี้:" -ForegroundColor White
Write-Host "   [1/7] ล้าง Profile เก่า และสร้าง Admin / Student" -ForegroundColor Gray
Write-Host "   [2/7] ติดตั้ง Software ด้วย winget (Machine-wide)" -ForegroundColor Gray
Write-Host "   [3/7] ติดตั้ง Manual & Shared Apps (LINE, Processing, Dev-C++)" -ForegroundColor Gray
Write-Host "   [4/7] ติดตั้ง Python Data Science Libraries" -ForegroundColor Gray
Write-Host "   [5/7] ตั้งค่านโยบายความปลอดภัยและสิทธิ์ Student" -ForegroundColor Gray
Write-Host "   [6/7] สร้าง Desktop Shortcuts บน Public Desktop ให้ทุก User" -ForegroundColor Gray
Write-Host "   [7/7] ตรวจสอบความถูกต้องและสร้างรายงานผล HTML" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "กด Y เพื่อเริ่มการติดตั้ง หรือ N เพื่อยกเลิก [Y/N]"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "ยกเลิกการติดตั้งแล้ว" -ForegroundColor Yellow
    exit 0
}

# กำหนดเส้นทาง PATH ของ winget เข้า session นี้
$searchPaths = @(
    "$env:LOCALAPPDATA\Microsoft\WindowsApps",
    "C:\Users\ADMIN\AppData\Local\Microsoft\WindowsApps",
    "C:\Users\Administrator\AppData\Local\Microsoft\WindowsApps"
)
foreach ($sp in $searchPaths) {
    if (Test-Path $sp) {
        $env:Path = "$sp;" + $env:Path
    }
}

$steps = @(
    @{ File = "01_create_users.ps1";             Name = "[1/7] ล้าง Profile และสร้าง User Accounts" }
    @{ File = "02_install_winget_apps.ps1";        Name = "[2/7] ติดตั้ง Software ด้วย winget (Machine-wide)" }
    @{ File = "03_install_manual_apps.ps1";        Name = "[3/7] ติดตั้ง Manual & Shared Apps (LINE, Processing, Dev-C++)" }
    @{ File = "04_install_python_libs.ps1";        Name = "[4/7] ติดตั้ง Python Libraries" }
    @{ File = "05_configure_student.ps1";          Name = "[5/7] ตั้งค่าระบบสำหรับ Student (เปิดสิทธิ์ลง/ลบได้อิสระ)" }
    @{ File = "07_create_public_shortcuts.ps1";    Name = "[6/7] Clone หน้าจอ Desktop และ AppData จาก Admin สู่ Student" }
    @{ File = "06_post_install_verify.ps1";        Name = "[7/7] ตรวจสอบความถูกต้องของระบบทั้งหมด" }
)

foreach ($step in $steps) {
    $scriptPath = Join-Path $PSScriptRoot $step.File
    Write-Host ""
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " กำลังทำงาน: $($step.Name)..." -ForegroundColor Green
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkCyan
    
    if (Test-Path $scriptPath) {
        & $scriptPath
    } else {
        Write-Host "ไม่พบไฟล์สคริปต์: $scriptPath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " เสร็จสิ้นกระบวนการทั้งหมดเรียบร้อยแล้ว!" -ForegroundColor Green
Write-Host " Desktop Shortcuts ถูกสร้างไว้ที่หน้าจอ Desktop ของทุกบัญชีแล้ว" -ForegroundColor Green
Write-Host " ตรวจสอบรายงานผลได้ที่: $PSScriptRoot\logs\install_report.html" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan
