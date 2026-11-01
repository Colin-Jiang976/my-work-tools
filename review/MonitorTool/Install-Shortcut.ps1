# ================= Auto-generate/Repair Shortcut =================

$ShortcutFolder = Join-Path $PSScriptRoot "shortcut"



# Create the shortcut directory if it does not exist

if (-not (Test-Path $ShortcutFolder)) { New-Item -ItemType Directory -Path $ShortcutFolder | Out-Null }



$ShortcutPath = Join-Path $ShortcutFolder "Start Tool.lnk"

$WshShell = New-Object -ComObject WScript.Shell

$Shortcut = $WshShell.CreateShortcut($ShortcutPath)



# Bind to the current absolute path automatically, no manual edit required

$Shortcut.TargetPath = "powershell.exe"

$StartToolPath = Join-Path $PSScriptRoot "Start-Tool.ps1"

$Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$StartToolPath`""

$Shortcut.WorkingDirectory = $PSScriptRoot

$Shortcut.WindowStyle = 1

$Shortcut.IconLocation = "powershell.exe,0"

$Shortcut.Save()

# ==================================================================