# Server Log Monitor Tool

A modular PowerShell tool that automatically opens the appropriate daily server logs based on the configured work shift.

## Features

- Opens the relevant server log folders for the current date.
- Selects logs automatically according to the configured shift schedule.
- Supports configurable server addresses and shared folders.
- Creates a ready-to-use desktop shortcut automatically.
- Launches the tool with `-ExecutionPolicy Bypass` through the generated shortcut.
- Keeps configuration and functional modules separate for easier maintenance.

## Directory Structure

```text
ServerLogMonitor/
├── modules/                 # Functional PowerShell modules
├── change.log               # Version history and change notes
├── config.json              # Server, shift, and folder configuration
├── Install-Shortcut.ps1     # Creates the desktop shortcut
├── README.md                # Project documentation
└── Start-Tool.ps1           # Main launcher