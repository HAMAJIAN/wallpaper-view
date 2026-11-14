@echo off
rem Create the "壁纸鉴赏" desktop shortcut (and optionally a Start Menu one).
rem Usage: Install.cmd [-StartMenu] [-NoHotkey] [-ShortcutKey "Ctrl+Alt+W"] [-ShortcutName "壁纸鉴赏"]
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Install.ps1" %*
if "%~1"=="" pause
