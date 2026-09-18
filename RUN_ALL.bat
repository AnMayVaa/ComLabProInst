@echo off
setlocal EnableDelayedExpansion
title ECE Lab Provisioning

:: 1. Auto-Elevate to Administrator if needed
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Requesting Administrator Privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/k \"\"%~dpnx0\"\"' -Verb RunAs"
    exit /b
)

:: 2. Set directory to script folder
cd /d "%~dp0"

:: 3. Launch PowerShell Master Controller
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0main.ps1"

echo.
pause
