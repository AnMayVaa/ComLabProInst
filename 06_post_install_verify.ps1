<#
.SYNOPSIS
    ตรวจสอบว่าลงโปรแกรมครบหรือไม่
.DESCRIPTION
    ตรวจสอบทุกโปรแกรมที่ต้องลง แล้วสร้าง HTML report
.NOTES
    รันได้ทุกเวลา ไม่ต้องเป็น Admin
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Continue"
$LogFile = Join-Path $PSScriptRoot "logs\06_verify.log"
$ReportFile = Join-Path $PSScriptRoot "logs\install_report.html"

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

Write-Log "========== เริ่มตรวจสอบการติดตั้ง =========="
Write-Host ""

# ─────────────────────────────────────────────
# ค้นหา winget
# ─────────────────────────────────────────────
$wingetExe = $null
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetExe = "winget"
}
else {
    $searchPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "C:\Users\ADMIN\AppData\Local\Microsoft\WindowsApps\winget.exe",
        "C:\Users\Administrator\AppData\Local\Microsoft\WindowsApps\winget.exe"
    )
    foreach ($p in $searchPaths) {
        if (Test-Path $p) {
            $wingetExe = $p
            break
        }
    }
}

# ─────────────────────────────────────────────
# รายการตรวจสอบ
# ─────────────────────────────────────────────
$checks = @(
    @{ Name = "Google Chrome";       Cmd = "chrome";       Paths = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") }
    @{ Name = "Python";              Cmd = "python";       Paths = @("C:\Program Files\Python312\python.exe", "$env:ProgramFiles\Python312\python.exe", "C:\Python312\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"); VersionCmd = "python --version" }
    @{ Name = "Oracle JDK 21";       Cmd = "java";         VersionCmd = "java --version" }
    @{ Name = "Thonny";              Cmd = "thonny";       Paths = @("$env:ProgramFiles\Thonny\thonny.exe", "${env:ProgramFiles(x86)}\Thonny\thonny.exe", "$env:LOCALAPPDATA\Programs\Thonny\thonny.exe") }
    @{ Name = "VS Code";             Cmd = "code";         Paths = @("$env:ProgramFiles\Microsoft VS Code\Code.exe", "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe", "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") }
    @{ Name = "Arduino IDE";         Cmd = "arduino-ide";  Paths = @("$env:ProgramFiles\Arduino IDE\Arduino IDE.exe", "$env:LOCALAPPDATA\Programs\Arduino IDE\Arduino IDE.exe") }
    @{ Name = "IntelliJ IDEA";       Cmd = "idea64";       Paths = @("$env:ProgramFiles\JetBrains\IntelliJ IDEA Community Edition*\bin\idea64.exe") }
    @{ Name = "Dev-C++";             Cmd = "devcpp";       Paths = @("$env:ProgramFiles\Embarcadero\Dev-Cpp\devcpp.exe", "${env:ProgramFiles(x86)}\Embarcadero\Dev-Cpp\devcpp.exe", "C:\Program Files (x86)\Dev-Cpp\devcpp.exe") }
    @{ Name = "Code::Blocks";        Cmd = "codeblocks";   Paths = @("$env:ProgramFiles\CodeBlocks\codeblocks.exe", "${env:ProgramFiles(x86)}\CodeBlocks\codeblocks.exe") }
    @{ Name = "GCC (MinGW)";         Cmd = "gcc";          Paths = @("${env:ProgramFiles(x86)}\Embarcadero\Dev-Cpp\TDM-GCC-64\bin\gcc.exe", "$env:ProgramFiles\Embarcadero\Dev-Cpp\TDM-GCC-64\bin\gcc.exe", "$env:ProgramFiles\CodeBlocks\MinGW\bin\gcc.exe", "${env:ProgramFiles(x86)}\CodeBlocks\MinGW\bin\gcc.exe"); VersionCmd = "gcc --version" }
    @{ Name = "R Language";          Cmd = "Rscript";      Paths = @("$env:ProgramFiles\R\R-*\bin\Rscript.exe", "$env:ProgramFiles\R\R-*\bin\x64\Rscript.exe"); VersionCmd = "Rscript --version" }
    @{ Name = "RStudio";             Cmd = "rstudio";      Paths = @("$env:ProgramFiles\RStudio\rstudio.exe", "$env:ProgramFiles\Posit\RStudio\rstudio.exe") }
    @{ Name = "Git";                 Cmd = "git";          VersionCmd = "git --version" }
    @{ Name = "GitHub Desktop";      Cmd = "github";       Paths = @("$env:ProgramFiles\GitHub Desktop\GitHubDesktop.exe", "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe") }
    @{ Name = "Wireshark";           Cmd = "wireshark";    Paths = @("$env:ProgramFiles\Wireshark\Wireshark.exe") }
    @{ Name = "VirtualBox";          Cmd = "VBoxManage";   Paths = @("$env:ProgramFiles\Oracle\VirtualBox\VirtualBox.exe") }
    @{ Name = "Raspberry Pi Imager"; Cmd = "rpi-imager";   Paths = @("$env:ProgramFiles\Raspberry Pi Imager\rpi-imager.exe", "${env:ProgramFiles(x86)}\Raspberry Pi Imager\rpi-imager.exe") }
    @{ Name = "MySQL";               Cmd = "mysql";        VersionCmd = "mysql --version" }
    @{ Name = "MariaDB";             Cmd = "mariadb";      Paths = @("$env:ProgramFiles\MariaDB*\bin\mariadb.exe") }
    @{ Name = "SSMS";                Cmd = "ssms";         Paths = @("${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe", "$env:ProgramFiles\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe", "C:\Program Files\Microsoft SQL Server Management Studio *\Common7\IDE\Ssms.exe", "C:\Program Files (x86)\Microsoft SQL Server Management Studio *\Common7\IDE\Ssms.exe") }
    @{ Name = "LINE";                Cmd = "LINE";         Paths = @("C:\Program Files\LINE\bin\LineLauncher.exe", "${env:ProgramFiles(x86)}\LINE\bin\LineLauncher.exe", "$env:LOCALAPPDATA\LINE\bin\LineLauncher.exe") }
    @{ Name = "Processing";          Cmd = "processing";   Paths = @("C:\Program Files\Processing 4\processing.exe", "C:\Program Files\Processing\processing.exe", "C:\Processing\processing.exe") }
    @{ Name = "Pulsar (Atom)";       Cmd = "pulsar";       Paths = @("$env:LOCALAPPDATA\Programs\Pulsar\Pulsar.exe", "$env:ProgramFiles\Pulsar\Pulsar.exe") }
    @{ Name = "Eclipse C++";         Cmd = "eclipse";      Paths = @("C:\Eclipse\eclipse.exe") }
    @{ Name = "Quartus Prime";       Cmd = "quartus";      Paths = @("C:\intelFPGA_lite\*\quartus\bin64\quartus.exe", "$env:ProgramFiles\intelFPGA_lite\*\quartus\bin64\quartus.exe") }
    @{ Name = "Packet Tracer";       Cmd = "PacketTracer"; Paths = @("$env:ProgramFiles\Cisco Packet Tracer*\bin\PacketTracer.exe", "${env:ProgramFiles(x86)}\Cisco Packet Tracer*\bin\PacketTracer.exe") }
)

# ─────────────────────────────────────────────
# ตรวจสอบทีละรายการ
# ─────────────────────────────────────────────
$results = @()

foreach ($check in $checks) {
    $found = $false
    $version = "N/A"
    $location = "N/A"

    # 1. ค้นหาจาก PATH
    $cmdResult = Get-Command $check.Cmd -ErrorAction SilentlyContinue
    if ($cmdResult) {
        $found = $true
        $location = $cmdResult.Source
    }

    # 2. ค้นหาจากโฟลเดอร์ Path ตรงๆ
    if (-not $found -and $check.Paths) {
        foreach ($path in $check.Paths) {
            $resolvedPaths = Resolve-Path $path -ErrorAction SilentlyContinue
            if ($resolvedPaths) {
                $found = $true
                $location = $resolvedPaths[0].Path
                break
            }
        }
    }

    # 3. ลองค้นหาผ่าน winget list
    if (-not $found -and $wingetExe) {
        $wingetCheck = & $wingetExe list --name $check.Name --accept-source-agreements 2>&1 | Out-String
        $escapedName = [regex]::Escape($check.Name)
        if ($wingetCheck -match $escapedName -and $wingetCheck -notmatch "No installed package") {
            $found = $true
            $location = "(winget registered)"
        }
    }

    # 4. ดึง version
    if ($found -and $check.VersionCmd) {
        try {
            $version = Invoke-Expression $check.VersionCmd 2>&1 | Select-Object -First 1
        }
        catch { }
    }

    $status = if ($found) { "[PASS]" } else { "[FAIL]" }
    $level = if ($found) { "SUCCESS" } else { "ERROR" }
    Write-Log "$status  $($check.Name)  [$version]  $location" $level

    $results += [PSCustomObject]@{
        Name     = $check.Name
        Status   = if ($found) { "PASS" } else { "FAIL" }
        Version  = $version
        Location = $location
    }
}

# ─────────────────────────────────────────────
# ตรวจสอบ Python Libraries
# ─────────────────────────────────────────────
Write-Host ""
Write-Log "===== ตรวจสอบ Python Libraries ====="

$pyLibs = @("numpy", "pandas", "matplotlib", "scipy", "sklearn", "jupyter",
            "seaborn", "plotly", "statsmodels", "cv2", "flask", "requests")

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

$verifyPy = "python"
$sysPyList = @("C:\Program Files\Python312\python.exe", "$env:ProgramFiles\Python312\python.exe", "C:\Python312\python.exe")
foreach ($sp in $sysPyList) {
    if (Test-Path $sp) { $verifyPy = $sp; break }
}

foreach ($lib in $pyLibs) {
    $importResult = & $verifyPy -c "import $lib; print(getattr($lib, '__version__', 'ok'))" 2>&1
    $success = ($LASTEXITCODE -eq 0)
    $status = if ($success) { "[PASS]" } else { "[FAIL]" }
    $level = if ($success) { "SUCCESS" } else { "ERROR" }
    Write-Log "$status  Python: $lib  [$importResult]" $level

    $results += [PSCustomObject]@{
        Name     = "Python: $lib"
        Status   = if ($success) { "PASS" } else { "FAIL" }
        Version  = if ($success) { $importResult } else { "N/A" }
        Location = "pip"
    }
}

# ─────────────────────────────────────────────
# ตรวจสอบ User Accounts
# ─────────────────────────────────────────────
Write-Host ""
Write-Log "===== ตรวจสอบ User Accounts ====="

foreach ($username in @("Admin", "Student")) {
    $user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
    if ($user) {
        $groups = (Get-LocalGroup | Where-Object {
            (Get-LocalGroupMember $_ -ErrorAction SilentlyContinue).Name -like "*\$username"
        }).Name -join ", "
        Write-Log "User '$username' -- Enabled: $($user.Enabled) -- Groups: $groups" "SUCCESS"
    }
    else {
        Write-Log "User '$username' ไม่มีในระบบ!" "ERROR"
    }
}

# ─────────────────────────────────────────────
# สร้าง HTML Report
# ─────────────────────────────────────────────
$passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$total = $results.Count
$computerName = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$htmlRows = ""
foreach ($r in $results) {
    $rowClass = if ($r.Status -eq "PASS") { "pass" } else { "fail" }
    $statusIcon = if ($r.Status -eq "PASS") { "PASS" } else { "FAIL" }
    $htmlRows += "        <tr class='$rowClass'><td><strong>$statusIcon</strong> $($r.Name)</td><td>$($r.Version)</td><td>$($r.Location)</td></tr>`n"
}

$html = @"
<!DOCTYPE html>
<html lang="th">
<head>
    <meta charset="UTF-8">
    <title>Lab Install Report -- $computerName</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; margin: 40px; background: #f5f5f5; }
        h1 { color: #1a73e8; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); min-width: 150px; text-align: center; }
        .card h2 { margin: 0; font-size: 36px; }
        .card.pass h2 { color: #34a853; }
        .card.fail h2 { color: #ea4335; }
        .card.total h2 { color: #1a73e8; }
        table { width: 100%; border-collapse: collapse; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        th { background: #1a73e8; color: white; padding: 12px; text-align: left; }
        td { padding: 10px 12px; border-bottom: 1px solid #eee; }
        tr.fail { background: #fce8e6; }
        tr.pass:hover { background: #e8f5e9; }
        .footer { margin-top: 20px; color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <h1>ECE Lab Installation Report</h1>
    <p><strong>Computer:</strong> $computerName | <strong>Date:</strong> $timestamp</p>
    
    <div class="summary">
        <div class="card pass"><h2>$passCount</h2><p>Passed</p></div>
        <div class="card fail"><h2>$failCount</h2><p>Failed</p></div>
        <div class="card total"><h2>$total</h2><p>Total Checks</p></div>
    </div>

    <table>
        <thead>
            <tr><th>Software / Library</th><th>Version</th><th>Location</th></tr>
        </thead>
        <tbody>
$htmlRows
        </tbody>
    </table>

    <p class="footer">Generated by ComLabProInst -- ECE Lab Provisioning System</p>
</body>
</html>
"@

$html | Out-File -FilePath $ReportFile -Encoding UTF8
Write-Log "HTML Report: $ReportFile" "SUCCESS"

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor DarkCyan
Write-Host "  สรุปผลตรวจสอบ: $passCount/$total ผ่าน" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })
if ($failCount -gt 0) {
    Write-Host "  ไม่ผ่าน $failCount รายการ" -ForegroundColor Red
}
Write-Host "  Report: $ReportFile" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor DarkCyan

if (Test-Path $ReportFile) {
    Start-Process $ReportFile
}

Write-Log "========== เสร็จสิ้น 06_post_install_verify =========="
