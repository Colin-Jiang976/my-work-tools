@echo off
chcp 65001 > nul
powershell -ExecutionPolicy Bypass -File "%~dp0archive_files.ps1"
pause