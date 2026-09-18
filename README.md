# 🖥️ ComLabProInst — ECE Computer Lab Provisioning

ระบบติดตั้ง Software อัตโนมัติสำหรับห้องแลป ECE

## 📥 วิธีนำ Script เข้าเครื่องเป้าหมาย (ECE01)

> [!NOTE]
> ในเครื่องใหม่ที่ยังไม่มี Git ติดตั้ง แนะนำให้ใช้ **วิธีที่ 1 (Flash Drive)** หรือ **วิธีที่ 2 (PowerShell Download)**

- **วิธี A (ง่าย & เร็วสุด): USB Flash Drive**  
  ก๊อปปี้ทั้งโฟลเดอร์ `ComLabProInst` ใส่ Flash Drive แล้วนำไปวางที่ `C:\ComLabProInst`
- **วิธี B: PowerShell ดาวน์โหลดอัตโนมัติ (ไม่ต้องลง Git)**  
  เปิด PowerShell (Admin) แล้วสั่งโหลดตรงจาก GitHub Repository:
  ```powershell
  Invoke-WebRequest -Uri "https://github.com/AnMayVaa/ComLabProInst/archive/refs/heads/main.zip" -OutFile "$env:TEMP\lab.zip"
  Expand-Archive -Path "$env:TEMP\lab.zip" -DestinationPath "C:\" -Force
  cd C:\*ComLab*
  .\RUN_ALL.bat
  ```
- **วิธี C: git clone (ถ้าเครื่องนั้นมี Git อยู่แล้ว)**  
  ```powershell
  git clone https://github.com/AnMayVaa/ComLabProInst.git C:\ComLabProInst
  cd C:\ComLabProInst
  .\RUN_ALL.bat
  ```

## 🚀 วิธีสั่งติดตั้ง

### วิธีที่ 1: ดับเบิลคลิกเดียวจบ (Master Batch)
1. **ดับเบิลคลิก** ที่ `RUN_ALL.bat` (ระบบจะขอสิทธิ์ Administrator / Auto-Elevate ให้อัตโนมัติ ไม่ต้องคลิกขวา)
2. กด **Y** เพื่อเริ่มกระบวนการทั้งหมด
3. รอประมาณ 30-60 นาที (ขึ้นอยู่กับความเร็วอินเทอร์เน็ต)

### วิธีที่ 2: รันผ่าน PowerShell (Admin)
```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\main.ps1                     # รันตัวควบคุมหลัก รวม 6 ขั้นตอน

# หรือรันทีละสคริปต์:
.\01_create_users.ps1          # ล้าง profile เก่า + สร้าง Admin/Student
.\02_install_winget_apps.ps1   # ลงแอปผ่าน winget
.\03_install_manual_apps.ps1   # ลง Processing, Pulsar, Eclipse
.\04_install_python_libs.ps1   # ลง Python Data Science libraries
.\05_configure_student.ps1     # ตั้งค่านโยบายและสิทธิ์ Student
.\06_post_install_verify.ps1   # ทดสอบและออกรายงานผล HTML
```

## 📦 Software ที่ลง

### ลงอัตโนมัติ (winget)
| Software | หมวด |
|----------|------|
| Google Chrome | Browser |
| Python 3.12 + Data Science libs | Programming |
| Oracle JDK 21 | Programming |
| R + RStudio | Programming |
| VS Code | IDE |
| Thonny | IDE |
| IntelliJ IDEA Community | IDE |
| Dev-C++ (+ GCC/MinGW) | IDE |
| Code::Blocks | IDE |
| Arduino IDE | IDE |
| Git + GitHub Desktop | DevTools |
| Wireshark | Networking |
| Oracle VirtualBox | Virtualization |
| Raspberry Pi Imager | Tools |
| MySQL Server | Database |
| MariaDB Server | Database |
| SQL Server Management Studio | Database |
| LINE Desktop | Communication |

### ลงกึ่งอัตโนมัติ (download + extract)
| Software | หมายเหตุ |
|----------|----------|
| Processing | Download zip + extract อัตโนมัติ |
| Pulsar (Atom fork) | Download installer + silent install |
| Eclipse IDE for C/C++ | Download zip + extract อัตโนมัติ |

### ต้องลง Manual
| Software | เหตุผล |
|----------|--------|
| Intel Quartus Prime 21 | ต้อง login Intel account |
| Cisco Packet Tracer | ต้อง login Cisco NetAcad account |

### ลงทีหลัง (ต้องมี license)
MATLAB, Microsoft Office, SolidWorks, ANSYS, Minitab

## 👤 User Accounts

| Username | Password | Role | สิทธิ์ |
|----------|----------|------|--------|
| Admin | 19379371 | ผู้ดูแล | Administrators group — ลง software ได้ |
| Student | 123456 | นักศึกษา | Users group — ใช้งานเท่านั้น |

## 📁 โครงสร้างไฟล์

```
ComLabProInst/
├── RUN_ALL.bat                 ← คลิกขวา > Run as admin
├── 01_create_users.ps1         ← สร้าง user accounts
├── 02_install_winget_apps.ps1  ← ลง software ด้วย winget
├── 03_install_manual_apps.ps1  ← ลง Processing, Pulsar, Eclipse
├── 04_install_python_libs.ps1  ← ลง Python libraries
├── 05_configure_student.ps1    ← จำกัดสิทธิ์ Student
├── 06_post_install_verify.ps1  ← ตรวจสอบ + สร้าง report
├── config/
│   ├── apps_list.json          ← รายการ apps (แก้ไขได้)
│   └── python_libs.txt         ← Python requirements
├── downloads/                  ← เก็บ installer ที่ download
├── logs/                       ← เก็บ log + HTML report
└── README.md                   ← ไฟล์นี้
```

## 🔄 สำหรับหลายเครื่อง (Imaging Strategy)

1. ลงเครื่องแรก (ECE01) ด้วย script ให้เรียบร้อย
2. ทดสอบจน OK
3. Clone image ด้วย **Clonezilla** หรือ **FOG Project**
4. Deploy ไปทุกเครื่องผ่าน USB หรือ PXE boot
5. เปลี่ยนชื่อเครื่อง:
   ```powershell
   Rename-Computer -NewName "ECE02" -Force -Restart
   ```

## ⚠️ ข้อควรระวัง

- ต้องรันด้วยสิทธิ์ **Administrator** เสมอ
- ต้องมีอินเทอร์เน็ตระหว่างติดตั้ง
- Windows 11 **Home** ไม่รองรับ Group Policy
- Quartus ไฟล์ใหญ่มาก (~5-20 GB) ควร download ล่วงหน้า
