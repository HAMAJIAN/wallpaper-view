@echo off
rem Remove the "壁纸鉴赏" desktop / Start Menu shortcuts.
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Install.ps1" -Remove
pause
