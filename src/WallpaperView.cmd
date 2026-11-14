@echo off
rem Fallback launcher for machines where VBScript is disabled.
rem Extra arguments are passed through to WallpaperView.ps1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0WallpaperView.ps1" -Quiet %*
