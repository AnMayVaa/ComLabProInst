@echo off
REM ═══════════════════════════════════════════════
REM   ComLabProInst — ECE Lab Provisioning
REM   Master Script — ดับเบิลคลิกตัวนี้ตัวเดียว
REM ═══════════════════════════════════════════════

title ECE Lab Provisioning
color 0B

echo.
echo  ╔═══════════════════════════════════════════════════╗
echo  ║     ECE Computer Lab — Automated Provisioning     ║
echo  ║                                                   ║
echo  ║  Script นี้จะ:                                    ║
echo  ║    1. สร้าง User Accounts (Admin, Student)        ║
echo  ║    2. ลง Software ทั้งหมดด้วย winget              ║
echo  ║    3. ลง Software ที่ต้อง download manual          ║
echo  ║    4. ลง Python Libraries (Data Science)          ║
echo  ║    5. ตั้งค่า Student Account                      ║
echo  ║    6. ตรวจสอบการติดตั้ง                             ║
echo  ╚═══════════════════════════════════════════════════╝
echo.

REM ─── ตรวจสอบสิทธิ์ Admin ───
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ กรุณารัน script นี้ด้วยสิทธิ์ Administrator!
    echo    คลิกขวา ^> Run as administrator
    echo.
    pause
    exit /b 1
)

echo ✅ สิทธิ์ Administrator — OK
echo.

REM ─── ถามยืนยัน ───
echo ⚠️  Script จะเริ่มติดตั้ง software ทั้งหมด
echo    ใช้เวลาประมาณ 30-60 นาที (ขึ้นอยู่กับความเร็วเน็ต)
echo.
set /p CONFIRM="กด Y เพื่อเริ่ม หรือ N เพื่อยกเลิก [Y/N]: "
if /i not "%CONFIRM%"=="Y" (
    echo ยกเลิกแล้ว
    exit /b 0
)

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo  [Step 1/6] สร้าง User Accounts...
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
powershell -ExecutionPolicy Bypass -File "%~dp001_create_users.ps1"
if %errorLevel% neq 0 (
    echo ⚠️  มีปัญหาในขั้นตอนนี้ ดู log เพิ่มเติม
)

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo  [Step 2/6] ลง Software ด้วย winget...
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
powershell -ExecutionPolicy Bypass -File "%~dp002_install_winget_apps.ps1"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo  [Step 3/6] ลง Manual Apps...
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
powershell -ExecutionPolicy Bypass -File "%~dp003_install_manual_apps.ps1"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo  [Step 4/6] ลง Python Libraries...
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
powershell -ExecutionPolicy Bypass -File "%~dp004_install_python_libs.ps1"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo  [Step 5/6] ตั้งค่า Student Account...
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
powershell -ExecutionPolicy Bypass -File "%~dp005_configure_student.ps1"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo  [Step 6/6] ตรวจสอบการติดตั้ง...
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
powershell -ExecutionPolicy Bypass -File "%~dp006_post_install_verify.ps1"

echo.
echo ═══════════════════════════════════════════════════
echo.
echo  ✅ เสร็จสิ้นทุกขั้นตอน!
echo.
echo  📄 ดู Report ที่: %~dp0logs\install_report.html
echo  📋 ดู Log ที่:    %~dp0logs\
echo.
echo  ⚠️  ยังต้องลง manual:
echo     - Intel Quartus Prime 21
echo     - Cisco Packet Tracer
echo.
echo ═══════════════════════════════════════════════════
echo.
pause
