@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Starting Cursor Usage Tray...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CursorUsageTray.ps1"
pause
