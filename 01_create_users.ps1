<#
.SYNOPSIS
    ล้าง Profile/User เก่า และสร้าง Local User Accounts ตามกำหนดสำหรับห้องแลป ECE
.DESCRIPTION
    1. ลบ Account และ Profile ผู้ใช้งานเก่าทั้งหมดที่ไม่จำเป็น
    2. รีเซ็ต/ลบ Account & Profile 'Student' เก่าออก เพื่อสร้างใหม่ให้สะอาด
    3. สร้าง/อัปเดต 2 Accounts:
       - Admin (19379371) → กลุ่ม Administrators
       - Student (123456) → กลุ่ม Users เท่านั้น
.NOTES
    ต้องรันด้วยสิทธิ์ Administrator (Run as Admin)
#>

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "logs\01_create_users.log"

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
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

# ─────────────────────────────────────────────
# สร้างโฟลเดอร์ logs
# ─────────────────────────────────────────────
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

Write-Log "========== เริ่มกระบวนการล้าง Profile เก่า และสร้าง User Accounts =========="

# ─────────────────────────────────────────────
# 1. รายชื่อ System Accounts ที่ห้ามแตะต้อง
# ─────────────────────────────────────────────
$systemAccounts = @(
    "Administrator",
    "Guest",
    "DefaultAccount",
    "WDAGUtilityAccount",
    "WsiAccount",
    "defaultuser0"
)

$currentUser = $env:USERNAME
Write-Log "บัญชีที่กำลังใช้งานปัจจุบัน: '$currentUser'"

# ─────────────────────────────────────────────
# 2. ลบ User Accounts เก่า (Local Users)
# ─────────────────────────────────────────────
Write-Host ""
Write-Log "--- ขั้นตอนที่ 1: ตรวจสอบและลบ Local User Accounts เก่า ---"

$allLocalUsers = Get-LocalUser
foreach ($usr in $allLocalUsers) {
    $uname = $usr.Name

    # ข้าม System Account
    if ($systemAccounts -contains $uname) {
        continue
    }

    # ข้าม Admin เป้าหมาย (และกรณีตัวพิมพ์เล็ก/ใหญ่)
    if ($uname -ieq "Admin") {
        Write-Log "พบบัญชี 'Admin' (จะอัปเดตรหัสผ่านในขั้นตอนถัดไป)" "INFO"
        continue
    }

    # กรณีเป็น Student เก่า -> ลบออกเพื่อสร้างใหม่ให้หมดจด
    if ($uname -ieq "Student") {
        Write-Log "พบบัญชี 'Student' เก่า -- ทำการลบเพื่อเตรียมสร้างใหม่..." "WARNING"
        try {
            Remove-LocalUser -Name $uname -ErrorAction Stop
            Write-Log "ลบบัญชี 'Student' เก่าสำเร็จ" "SUCCESS"
        }
        catch {
            Write-Log "ไม่สามารถลบบัญชี Student ได้: $($_.Exception.Message)" "WARNING"
        }
        continue
    }

    # ถ้าเป็นบัญชีที่กำลัง Login ใช้งานอยู่ขณะนี้
    if ($uname -ieq $currentUser) {
        Write-Log "บัญชี '$uname' คือบัญชีที่คุณกำลังใช้งานอยู่ -- ข้ามการลบอัตโนมัติ" "WARNING"
        continue
    }

    # บัญชีอื่น ๆ ที่ไม่ใช่ Admin, Student, System Account -> ลบทิ้งทันที
    Write-Log "พบบัญชีเก่า/แปลกปลอม: '$uname' -- กำลังลบ..." "WARNING"
    try {
        Remove-LocalUser -Name $uname -ErrorAction Stop
        Write-Log "ลบบัญชี '$uname' สำเร็จ" "SUCCESS"
    }
    catch {
        Write-Log "ไม่สามารถลบ '$uname': $($_.Exception.Message)" "ERROR"
    }
}

# ─────────────────────────────────────────────
# 3. ลบ User Profiles เก่า (Registry + C:\Users)
# ─────────────────────────────────────────────
Write-Host ""
Write-Log "--- ขั้นตอนที่ 2: ตรวจสอบและลบ Windows User Profiles เก่า ---"

try {
    $profiles = Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special }
    foreach ($p in $profiles) {
        # ถ้ากำลังโหลด/ใช้งานอยู่ (Loaded = True) ให้ข้าม
        if ($p.Loaded) {
            Write-Log "Profile '$($p.LocalPath)' กำลังถูกใช้งานอยู่ในเซสชันนี้ -- ข้าม" "INFO"
            continue
        }

        $folderName = Split-Path $p.LocalPath -Leaf

        # ข้าม Admin หรือ Administrator
        if ($folderName -ieq "Admin" -or $folderName -ieq "Administrator") {
            continue
        }

        Write-Log "กำลังล้าง Profile: '$($p.LocalPath)'..." "WARNING"
        try {
            Remove-CimInstance -InputObject $p -ErrorAction Stop
            Write-Log "ล้าง Profile '$($p.LocalPath)' สำเร็จ" "SUCCESS"
        }
        catch {
            Write-Log "ลบ CIM Profile ล้มเหลว: $($_.Exception.Message)" "WARNING"
        }

        # ลบโฟลเดอร์ตกค้างในดิสก์ถ้ายังมีอยู่
        if (Test-Path $p.LocalPath) {
            try {
                Remove-Item -Path $p.LocalPath -Recurse -Force -ErrorAction Stop
                Write-Log "ลบโฟลเดอร์ตกค้าง '$($p.LocalPath)' สำเร็จ" "SUCCESS"
            }
            catch {
                Write-Log "ไม่สามารถลบโฟลเดอร์ '$($p.LocalPath)': $($_.Exception.Message)" "WARNING"
            }
        }
    }
}
catch {
    Write-Log "ข้อผิดพลาดในการตรวจสอบ User Profile: $($_.Exception.Message)" "WARNING"
}

# ─────────────────────────────────────────────
# 4. สร้าง User Accounts ที่ต้องการ (Admin, Student)
# ─────────────────────────────────────────────
Write-Host ""
Write-Log "--- ขั้นตอนที่ 3: สร้างและกำหนดสิทธิ์ User Accounts ใหม่ ---"

$users = @(
    @{
        Username    = "Admin"
        Password    = "19379371"
        FullName    = "Lab Administrator"
        Description = "ผู้ดูแลห้องแลป ECE"
        Group       = "Administrators"
    },
    @{
        Username    = "Student"
        Password    = "123456"
        FullName    = "Lab Student"
        Description = "นักศึกษาใช้งานห้องแลป ECE"
        Group       = "Administrators"
    }
)

foreach ($user in $users) {
    $username = $user.Username
    $password = ConvertTo-SecureString $user.Password -AsPlainText -Force

    try {
        $existingUser = Get-LocalUser -Name $username -ErrorAction SilentlyContinue

        if ($existingUser) {
            Write-Log "User '$username' มีอยู่แล้ว -- อัปเดตรหัสผ่าน ข้อมูล และเปิดใช้งาน (Enabled)..." "INFO"
            Set-LocalUser -Name $username -Password $password -Description $user.Description -FullName $user.FullName
            Enable-LocalUser -Name $username -ErrorAction SilentlyContinue
            Set-LocalUser -Name $username -PasswordNeverExpires $true
            if ($username -eq "Student") {
                Set-LocalUser -Name $username -UserMayNotChangePassword $true
            }
            Write-Log "อัปเดต '$username' สำเร็จ" "SUCCESS"
        }
        else {
            Write-Log "กำลังสร้าง user '$username'..."
            New-LocalUser -Name $username `
                          -Password $password `
                          -FullName $user.FullName `
                          -Description $user.Description `
                          -PasswordNeverExpires `
                          -AccountNeverExpires `
                          -UserMayNotChangePassword:$($username -eq "Student")
            Write-Log "สร้าง user '$username' สำเร็จ" "SUCCESS"
        }

        # กำหนดกลุ่ม (Group)
        $groupName = $user.Group
        $isMember = Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "*\$username" }

        if (-not $isMember) {
            Add-LocalGroupMember -Group $groupName -Member $username
            Write-Log "เพิ่ม '$username' เข้ากลุ่ม '$groupName'" "SUCCESS"
        }
        else {
            Write-Log "'$username' อยู่ในกลุ่ม '$groupName' แล้ว" "INFO"
        }

        # ให้ Student อยู่ใน Administrators เพื่อให้สามารถลง/ลบโปรแกรมในการเรียนได้อิสระ
        if ($username -eq "Student") {
            $isAdmin = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -like "*\Student" }
            if (-not $isAdmin) {
                Add-LocalGroupMember -Group "Administrators" -Member "Student"
                Write-Log "เพิ่ม 'Student' เข้ากลุ่ม 'Administrators' ตามข้อกำหนด" "SUCCESS"
            }
        }
    }
    catch {
        Write-Log "ข้อผิดพลาดในการจัดการ user '$username': $($_.Exception.Message)" "ERROR"
    }
}

# ─────────────────────────────────────────────
# 5. สรุปผล
# ─────────────────────────────────────────────
Write-Host ""
Write-Log "========== สรุป User Accounts ล่าสุดในระบบ =========="
Get-LocalUser | Format-Table Name, Enabled, Description, PasswordRequired -AutoSize |
    Out-String | ForEach-Object { Write-Log $_ }

Write-Log "========== เสร็จสิ้น 01_create_users =========="
Write-Host ""
Write-Host " จัดการลบโปรไฟล์เก่าและสร้าง User Accounts ใหม่เรียบร้อย!" -ForegroundColor Green
Write-Host "   Admin    -> password: 19379371 (Administrators)" -ForegroundColor Cyan
Write-Host "   Student  -> password: 123456   (Administrators - Full Access)" -ForegroundColor Cyan
