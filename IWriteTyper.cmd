@echo off
rem 备用启动器（如果 .vbs 被系统禁用，双击这个）
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0IWriteTyper.ps1"
