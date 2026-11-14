#Requires -Version 5.1
<#
    在桌面（可选开始菜单）创建“壁纸鉴赏”快捷方式：一个带图标的按钮，
    双击即进入全屏壁纸；可选绑定全局快捷键（默认 Ctrl+Alt+W）。

    用法：
        powershell -ExecutionPolicy Bypass -File src\Install.ps1
        powershell -ExecutionPolicy Bypass -File src\Install.ps1 -StartMenu
        powershell -ExecutionPolicy Bypass -File src\Install.ps1 -Remove
#>
[CmdletBinding()]
param(
    [switch]$Remove,
    [string]$ShortcutName = '壁纸鉴赏',
    [string]$ShortcutKey = 'Ctrl+Alt+W',
    [switch]$StartMenu,
    [switch]$NoHotkey
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

$vbs = Join-Path $root 'src\WallpaperView.vbs'
$cmdLauncher = Join-Path $root 'src\WallpaperView.cmd'
$iconSrc = Join-Path $root 'assets\icon.ico'
$iconMaker = Join-Path $root 'build\make-icon.ps1'

function Get-ShortcutDirs {
    $dirs = New-Object System.Collections.Generic.List[string]
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ($desktop) { $dirs.Add($desktop) }
    if ($StartMenu) {
        $programs = [Environment]::GetFolderPath('Programs')
        if ($programs) { $dirs.Add($programs) }
    }
    return $dirs
}

function Format-ShortcutKey {
    param([string]$Key)

    if (-not $Key) { return $null }
    $parts = $Key -split '\+'
    $map = @{
        'ctrl' = 'CTRL'; 'control' = 'CTRL'
        'alt' = 'ALT'
        'shift' = 'SHIFT'
        'win' = 'WIN'
    }
    $out = @()
    foreach ($p in $parts) {
        $t = $p.Trim()
        if (-not $t) { continue }
        $lower = $t.ToLower()
        if ($map.ContainsKey($lower)) { $out += $map[$lower] } else { $out += $t.ToUpper() }
    }
    if ($out.Count -lt 2) { return $null }
    return ($out -join '+')
}

# --- 卸载 ---
if ($Remove) {
    $removed = 0
    foreach ($dir in (Get-ShortcutDirs)) {
        $lnk = Join-Path $dir "$ShortcutName.lnk"
        if (Test-Path -LiteralPath $lnk) {
            Remove-Item -LiteralPath $lnk -Force
            Write-Host "  已删除：$lnk"
            $removed++
        }
    }
    if ($removed -eq 0) { Write-Host '  没有找到需要删除的快捷方式。' }
    Write-Host ''
    exit 0
}

# --- 准备图标 ---
if (-not (Test-Path -LiteralPath $iconSrc)) {
    if (Test-Path -LiteralPath $iconMaker) {
        Write-Host '  首次使用，正在生成图标…'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $iconMaker | Out-Null
    }
}
if (-not (Test-Path -LiteralPath $iconSrc)) {
    Write-Host '  ! 找不到 assets\icon.ico，快捷方式将使用默认图标。'
    $iconSrc = $null
}

$iconDst = $null
if ($iconSrc) {
    $store = Join-Path $env:LOCALAPPDATA 'WallpaperView'
    if (-not (Test-Path -LiteralPath $store)) { New-Item -ItemType Directory -Path $store -Force | Out-Null }
    $iconDst = Join-Path $store 'icon.ico'
    Copy-Item -LiteralPath $iconSrc -Destination $iconDst -Force
}

# --- 选择启动器 ---
if (Test-Path -LiteralPath $vbs) {
    $target = Join-Path $env:windir 'System32\wscript.exe'
    $arguments = '"{0}"' -f $vbs
    $launcherKind = 'wscript（无控制台窗口闪烁）'
} elseif (Test-Path -LiteralPath $cmdLauncher) {
    $target = Join-Path $env:windir 'System32\cmd.exe'
    $arguments = '/c ""{0}""' -f $cmdLauncher
    $launcherKind = 'cmd（备用启动器）'
} else {
    Write-Host '  × 找不到 WallpaperView.vbs / WallpaperView.cmd，安装中断。'
    exit 1
}

$key = $null
if (-not $NoHotkey) { $key = Format-ShortcutKey -Key $ShortcutKey }

$shell = New-Object -ComObject WScript.Shell
$count = 0

foreach ($dir in (Get-ShortcutDirs)) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $lnkPath = Join-Path $dir "$ShortcutName.lnk"

    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $target
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $root
    $shortcut.WindowStyle = 7
    $shortcut.Description = '一键壁纸鉴赏模式 —— 全屏只剩壁纸'
    if ($iconDst) { $shortcut.IconLocation = "$iconDst,0" }
    if ($key) {
        try { $shortcut.Hotkey = $key } catch { Write-Host "  ! 快捷键 $key 设置失败（可手动在快捷方式属性里设置）：$_" }
    }
    $shortcut.Save()

    Write-Host "  已创建：$lnkPath"
    $count++
}

[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)

Write-Host ''
Write-Host "  启动器：$launcherKind"
if ($key) { Write-Host "  快捷键：$key（桌面/开始菜单里有快捷方式时才生效）" }
Write-Host
Write-Host '  双击桌面上的“壁纸鉴赏”图标即可进入全屏壁纸，'
Write-Host '  动一下鼠标或按任意键退出。'
Write-Host
if ($count -eq 0) {
    Write-Host '  × 没有创建任何快捷方式，请检查桌面路径是否可写。'
    exit 1
}
exit 0
