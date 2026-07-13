# Server Log Monitor Automation Tool

A lightweight, automated PowerShell solution for Windows 11 environments to streamline daily server monitoring tasks. It eliminates the manual effort of clicking through multiple network directories to open daily operational logs.

## Features
- **Shift-Aware Scheduling:** Automatically detects the time of day to load different directory lists for Morning (Before 1:00 PM) and Evening checks.
- **Dynamic File Filtering:** Filters files strictly targeting `.log` formats updated within the current calendar date (`$Today`).
- **Custom Selection Rules:** Supports pulling custom quantities of the latest logs per directory, with built-in logic to extract specific historical offsets (e.g., retrieving the 3rd latest log via `-Skip 2`).
- **UNC/Network Path Support:** Built to query remote LAN nodes without relying on mapped network drive letters.

---

## Prerequisites
- **Operating System:** Windows 11
- **Permissions:** Read access to the configured network shared folders (`\\192.168.x.x\SharedFolder`).

---

## Deployment Guide

### 1. Script Customization
1. Clone or download `OpenTodayLogs.ps1` into your local directory.
2. Edit the **CONFIGURATION AREA** to match your network environments:
   - Update the IP addresses or Hostnames.
   - Adjust the log target count numbers (`= 2`, `= 3`, etc.).
   - Update the exceptions list conditional clause (`*Folder1*`, `*Folder2*`) to accurately match your offset-based log directories.

### 2. Configure Desktop One-Click Shortcut
To launch the script cleanly by double-clicking without being blocked by Windows Execution Policies, configure a desktop shortcut redirect:

1. Right-click on your desktop, select **New -> Shortcut**.
2. In the location text field, enter the following launch execution command (Replace the file path with your actual script destination):
   ```cmd
   powershell.exe -ExecutionPolicy Bypass -File "C:\Your\Project\Path\OpenTodayLogs.ps1"