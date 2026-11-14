#Requires -Version 5.1
<#
    壁纸鉴赏模式。
    找到 Wallpaper Engine 自带的屏幕保护程序，直接跑起来：
    全屏只剩壁纸，动一下鼠标就退出。

    用法：WallpaperView.ps1 [-Mode Saver|Desktop] [-Check] [-Restore] [-Quiet]
#>
[CmdletBinding()]
param(
    # Saver 走屏保（默认）；Desktop 只隐藏桌面图标，屏保用不了时的退路
    [ValidateSet('Saver', 'Desktop')]
    [string]$Mode = 'Saver',

    # 只体检，不进鉴赏模式
    [switch]$Check,

    # 把桌面图标放回来
    [switch]$Restore,

    # 双击启动器用：不往控制台输出，出错才弹窗
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$logDir = Join-Path $env:LOCALAPPDATA 'WallpaperView'
$logFile = Join-Path $logDir 'last-run.log'

function Write-Log {
    param([string]$Text, [switch]$Echo, [switch]$Fresh)

    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text
    try {
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        if ($Fresh) { Set-Content -LiteralPath $logFile -Value $line -Encoding UTF8 }
        else { Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 }
    } catch { }

    if ($Echo -and -not $Quiet) { Write-Host $Text }
}

function Write-Info {
    param([string]$Text)
    if (-not $Quiet) { Write-Host $Text }
}

function Fail {
    param([string]$Text, [string[]]$Hint)

    Write-Log "ERROR  $Text"
    foreach ($h in $Hint) { Write-Log "HINT   $h" }

    if ($Quiet) {
        $body = $Text
        if ($Hint) { $body = $body + "`r`n`r`n" + ($Hint -join "`r`n") }
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [void][System.Windows.Forms.MessageBox]::Show($body, '壁纸鉴赏', 'OK', 'Warning')
        } catch { }
    } else {
        Write-Host ''
        Write-Host "  ×  $Text" -ForegroundColor Red
        foreach ($h in $Hint) { Write-Host "     $h" -ForegroundColor Yellow }
        Write-Host "     日志：$logFile" -ForegroundColor DarkGray
        Write-Host ''
    }
    exit 1
}

# 壁纸引擎装哪儿了。注册表里记的是 wallpaper64.exe 的全路径，取父目录就是安装目录
function Get-EngineDir {
    $dirs = New-Object System.Collections.Generic.List[string]

    # 手动指定优先
    if ($env:WALLPAPER_ENGINE_PATH) {
        $p = $env:WALLPAPER_ENGINE_PATH -replace '/', '\'
        if (Test-Path -LiteralPath $p -PathType Leaf) { $p = Split-Path -Parent $p }
        $dirs.Add($p)
    }

    foreach ($key in 'HKCU:\Software\WallpaperEngine', 'HKLM:\SOFTWARE\WallpaperEngine', 'HKLM:\SOFTWARE\WOW6432Node\WallpaperEngine') {
        $exe = $null
        try { $exe = (Get-ItemProperty -Path $key -Name 'installPath' -ErrorAction Stop).installPath } catch { }
        if ($exe) { $dirs.Add((Split-Path -Parent ($exe -replace '/', '\'))) }
    }

    # Steam 那一套
    foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        $steam = $null
        foreach ($name in 'SteamPath', 'InstallPath') {
            try { $steam = (Get-ItemProperty -Path $key -Name $name -ErrorAction Stop).$name } catch { }
            if ($steam) { break }
        }
        if ($steam) { $dirs.Add((Join-Path ($steam -replace '/', '\') 'steamapps\common\wallpaper_engine')) }
    }

    # 上面都没有就赌默认路径
    $dirs.Add('C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine')
    $dirs.Add('C:\Program Files\Steam\steamapps\common\wallpaper_engine')

    foreach ($dir in $dirs) {
        if (-not $dir) { continue }
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        if ((Test-Path -LiteralPath (Join-Path $dir 'wallpaper64.exe')) -or
            (Test-Path -LiteralPath (Join-Path $dir 'wallpaper32.exe'))) {
            return (Resolve-Path -LiteralPath $dir).Path
        }
    }
    return $null
}

function Get-EngineExe {
    param([string]$EngineDir)

    if (-not $EngineDir) { return $null }
    foreach ($name in 'wallpaper64.exe', 'wallpaper32.exe') {
        $p = Join-Path $EngineDir $name
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

# 屏保程序在哪：系统目录里可能有装好的，安装目录里一定有原件
function Get-ScreensaverPath {
    param([string]$EngineDir)

    $candidates = New-Object System.Collections.Generic.List[string]

    if ($env:WALLPAPERVIEW_SCREENSAVER) { $candidates.Add($env:WALLPAPERVIEW_SCREENSAVER) }

    $system32 = Join-Path $env:windir 'System32'
    $candidates.Add((Join-Path $system32 'wpxscreensaver64.scr'))
    $candidates.Add((Join-Path $system32 'wpxscreensaver32.scr'))

    if ($EngineDir) {
        foreach ($sub in 'bin', 'distribution\bin') {
            foreach ($name in 'wpxscreensaver64.scr', 'wpxscreensaver32.scr') {
                $candidates.Add((Join-Path (Join-Path $EngineDir $sub) $name))
            }
        }
    }

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
}

function Get-ProcessLike {
    param([string]$Pattern)
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like $Pattern })
}

function Test-EngineRunning {
    (Get-ProcessLike 'wallpaper6*').Count -gt 0 -or (Get-ProcessLike 'wallpaper3*').Count -gt 0
}

# 没运行就把引擎拉起来，屏保要靠它渲染
function Start-Engine {
    param([string]$EngineDir)

    $exe = Get-EngineExe -EngineDir $EngineDir
    if (-not $exe) { return $false }

    Write-Log "engine not running, starting $exe"
    Start-Process -FilePath $exe -WorkingDirectory $EngineDir | Out-Null

    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        if (Test-EngineRunning) { return $true }
        Start-Sleep -Milliseconds 400
    }
    return $false
}

function Get-EngineVersion {
    param([string]$EngineDir)

    $file = Join-Path $EngineDir 'version.json'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    try { return (Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).version } catch { return $null }
}

# 体检：出问题时先跑这个
function Invoke-Check {
    $engineDir = Get-EngineDir
    $engineExe = Get-EngineExe -EngineDir $engineDir
    $scr = Get-ScreensaverPath -EngineDir $engineDir

    Write-Info ''
    Write-Info "  系统        $([Environment]::OSVersion.VersionString) ($env:PROCESSOR_ARCHITECTURE)"
    Write-Info "  PowerShell  $($PSVersionTable.PSVersion)"
    Write-Info "  安装目录    $($engineDir)"
    if ($engineDir) { Write-Info "  引擎版本    $(Get-EngineVersion -EngineDir $engineDir)" }
    Write-Info "  主程序      $engineExe"
    Write-Info "  屏保文件    $scr"
    if (Test-EngineRunning) { Write-Info '  引擎在运行  是' } else { Write-Info '  引擎在运行  否' }
    if ((Get-ProcessLike 'wpxscreensaver*').Count -gt 0) { Write-Info '  鉴赏进行中  是' } else { Write-Info '  鉴赏进行中  否' }
    Write-Info ''

    if (-not $engineDir) { Write-Info '  ! 没找到 Wallpaper Engine，装一个或者设 WALLPAPER_ENGINE_PATH' }
    if (-not $scr) { Write-Info '  ! 没找到屏保文件，先确认装的是 2.x' }

    Write-Log "check: dir=$engineDir scr=$scr"
    return [bool]($engineDir -and $scr)
}

function Enter-Saver {
    param([string]$EngineDir)

    $scr = Get-ScreensaverPath -EngineDir $EngineDir
    if (-not $scr) {
        Fail '没找到 Wallpaper Engine 的屏保文件（wpxscreensaver64.scr）。' @(
            '确认装的是 Wallpaper Engine 2.x。',
            '只想隐藏桌面图标的话，用 -Mode Desktop。'
        )
    }

    # 已经在里面了，别叠第二个
    if ((Get-ProcessLike 'wpxscreensaver*').Count -gt 0) {
        Write-Log 'screensaver already running'
        exit 0
    }

    if (-not (Test-EngineRunning)) {
        if (-not (Start-Engine -EngineDir $EngineDir)) {
            Fail 'Wallpaper Engine 没在运行，自动启动也没成功。' @('先手动打开 Wallpaper Engine 再试。')
        }
    }

    # 屏保宿主自己会全屏、自己接管键鼠，动一下就退出，不用我们管
    Write-Log "starting $scr"
    Start-Process -FilePath $scr -ArgumentList '/s' | Out-Null
    Write-Log 'entered'
}

function Enter-Desktop {
    param([string]$EngineDir)

    $exe = Get-EngineExe -EngineDir $EngineDir
    if (-not $exe) { Fail '没找到 Wallpaper Engine 主程序。' @('装好 Wallpaper Engine 再试。') }

    & $exe -control hideIcons | Out-Null
    Write-Log 'icons hidden'

    Write-Info ''
    Write-Info '  桌面图标已隐藏。把任务栏设成自动隐藏会更干净。'
    Write-Info '  恢复：WallpaperView.ps1 -Restore'
    Write-Info ''
}

function Restore-Desktop {
    param([string]$EngineDir)

    $exe = Get-EngineExe -EngineDir $EngineDir
    if (-not $exe) { Fail '没找到 Wallpaper Engine 主程序。' @('装好 Wallpaper Engine 再试。') }

    & $exe -control showIcons | Out-Null
    Write-Log 'icons shown'
    Write-Info '  桌面图标回来了。'
}

Write-Log "run: mode=$Mode check=$Check restore=$Restore" -Fresh
$engineDir = Get-EngineDir

if ($Check) {
    [void](Invoke-Check)
    exit 0
}

if ($Restore) {
    Restore-Desktop -EngineDir $engineDir
    exit 0
}

switch ($Mode) {
    'Saver'   { Enter-Saver   -EngineDir $engineDir }
    'Desktop' { Enter-Desktop -EngineDir $engineDir }
}

exit 0
