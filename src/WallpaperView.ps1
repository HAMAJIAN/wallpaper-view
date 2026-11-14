#Requires -Version 5.1
<#
    WallpaperView —— 一键壁纸鉴赏模式
    让 Wallpaper Engine 的壁纸占满整块屏幕，别的什么都没有。

    原理：直接调用 Wallpaper Engine 自带的屏幕保护程序宿主
    （wpxscreensaver64.scr /s）。它会在所有显示器上铺满壁纸、
    覆盖任务栏和所有窗口，动一下鼠标或按任意键立即退出。

    本脚本不修改注册表、不修改 Windows 屏保设置、不注入进程。
#>
[CmdletBinding()]
param(
    [ValidateSet('Saver', 'Desktop')]
    [string]$Mode = 'Saver',

    # 只体检，不进入鉴赏模式
    [switch]$Check,

    # 恢复桌面图标（-Mode Desktop 之后用）
    [switch]$Restore,

    # 把屏保宿主装进 C:\Windows\System32（需要管理员），方便在系统屏保设置里也能选到
    [switch]$Install,

    # 每次进入前换一张壁纸
    [switch]$Shuffle,

    # 进入前等待的秒数
    [int]$Delay = 0,

    # 静默模式：不输出文本，出错时弹窗（双击启动器用）
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$script:AppName = 'WallpaperView'
$script:LogDir = Join-Path $env:LOCALAPPDATA 'WallpaperView'
$script:LogFile = Join-Path $script:LogDir 'last-run.log'

# ---------------------------------------------------------------- 输出 / 日志

function Write-Log {
    param([string]$Text, [switch]$Echo)

    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text
    try {
        if (-not (Test-Path -LiteralPath $script:LogDir)) {
            New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
        }
        if ((Test-Path -LiteralPath $script:LogFile) -and
            (Get-Item -LiteralPath $script:LogFile).Length -gt 256KB) {
            Remove-Item -LiteralPath $script:LogFile -Force
        }
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
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
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            [void][System.Windows.Forms.MessageBox]::Show($body, '壁纸鉴赏', 'OK', 'Warning')
        } catch { }
    } else {
        Write-Host ''
        Write-Host "  ×  $Text" -ForegroundColor Red
        foreach ($h in $Hint) { Write-Host "     $h" -ForegroundColor Yellow }
        Write-Host "     日志：$script:LogFile" -ForegroundColor DarkGray
        Write-Host ''
    }
    exit 1
}

# ---------------------------------------------------------------- 环境探测

function Test-EngineDir {
    param([string]$Path)

    if (-not $Path) { return $false }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    (Test-Path -LiteralPath (Join-Path $Path 'wallpaper64.exe')) -or
    (Test-Path -LiteralPath (Join-Path $Path 'wallpaper32.exe'))
}

function Get-EngineDir {
    $candidates = New-Object System.Collections.Generic.List[string]

    # 1. 环境变量
    if ($env:WALLPAPER_ENGINE_PATH) {
        $p = $env:WALLPAPER_ENGINE_PATH -replace '/', '\'
        if (Test-Path -LiteralPath $p -PathType Leaf) { $p = Split-Path -Parent $p }
        $candidates.Add($p)
    }

    # 2. Wallpaper Engine 自己的注册表项（存的是 exe 全路径）
    foreach ($key in @('HKCU:\Software\WallpaperEngine',
                       'HKLM:\SOFTWARE\WallpaperEngine',
                       'HKLM:\SOFTWARE\WOW6432Node\WallpaperEngine')) {
        $value = $null
        try { $value = (Get-ItemProperty -Path $key -Name 'installPath' -ErrorAction Stop).installPath } catch { }
        if ($value) {
            $value = $value -replace '/', '\'
            $candidates.Add((Split-Path -Parent $value))
        }
    }

    # 3. Steam 安装目录
    foreach ($key in @('HKCU:\Software\Valve\Steam',
                       'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
                       'HKLM:\SOFTWARE\Valve\Steam')) {
        $steam = $null
        foreach ($name in @('SteamPath', 'InstallPath')) {
            try { $steam = (Get-ItemProperty -Path $key -Name $name -ErrorAction Stop).$name } catch { }
            if ($steam) { break }
        }
        if ($steam) {
            $steam = $steam -replace '/', '\'
            $candidates.Add((Join-Path $steam 'steamapps\common\wallpaper_engine'))
        }
    }

    # 4. 常见路径兜底
    $candidates.Add('C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine')
    $candidates.Add('C:\Program Files\Steam\steamapps\common\wallpaper_engine')

    foreach ($c in $candidates) {
        if ($c -and (Test-EngineDir $c)) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
}

function Get-EngineExe {
    param([string]$EngineDir)

    if (-not $EngineDir) { return $null }
    foreach ($name in @('wallpaper64.exe', 'wallpaper32.exe')) {
        $p = Join-Path $EngineDir $name
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Get-ScreensaverPath {
    param([string]$EngineDir)

    $candidates = New-Object System.Collections.Generic.List[string]

    if ($env:WALLPAPERVIEW_SCREENSAVER) { $candidates.Add($env:WALLPAPERVIEW_SCREENSAVER) }

    # 已安装到系统目录的（Windows 屏保设置里选过 Wallpaper Engine 就会有）
    $system32 = Join-Path $env:windir 'System32'
    $candidates.Add((Join-Path $system32 'wpxscreensaver64.scr'))
    $candidates.Add((Join-Path $system32 'wpxscreensaver32.scr'))

    # 安装目录里的原件——不需要管理员权限，本工具默认就用这个
    if ($EngineDir) {
        foreach ($sub in @('bin', 'distribution\bin')) {
            foreach ($name in @('wpxscreensaver64.scr', 'wpxscreensaver32.scr')) {
                $candidates.Add((Join-Path (Join-Path $EngineDir $sub) $name))
            }
        }
    }

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $c).Path
        }
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
    try {
        $json = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json
        return $json.version
    } catch { return $null }
}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($id)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

# ---------------------------------------------------------------- 体检

function Invoke-Check {
    $engineDir = Get-EngineDir
    $engineExe = Get-EngineExe -EngineDir $engineDir
    $scr = Get-ScreensaverPath -EngineDir $engineDir
    $engineRunning = Test-EngineRunning
    $saverRunning = (Get-ProcessLike 'wpxscreensaver*').Count -gt 0

    $rows = @(
        @{ Item = '系统';        Value = "$([Environment]::OSVersion.VersionString)  ($env:PROCESSOR_ARCHITECTURE)" }
        @{ Item = 'PowerShell';  Value = $PSVersionTable.PSVersion.ToString() }
        @{ Item = '安装目录';    Value = $(if ($engineDir) { $engineDir } else { '未找到' }) }
        @{ Item = '引擎版本';    Value = $(if ($engineDir) { Get-EngineVersion -EngineDir $engineDir } else { '-' }) }
        @{ Item = '主程序';      Value = $(if ($engineExe) { $engineExe } else { '未找到' }) }
        @{ Item = '屏保宿主';    Value = $(if ($scr) { $scr } else { '未找到' }) }
        @{ Item = '引擎在运行';  Value = $(if ($engineRunning) { '是' } else { '否' }) }
        @{ Item = '鉴赏进行中';  Value = $(if ($saverRunning) { '是' } else { '否' }) }
        @{ Item = '管理员权限';  Value = $(if (Test-Admin) { '是' } else { '否（本工具不需要）' }) }
    )

    Write-Info ''
    Write-Info '  壁纸鉴赏 · 体检结果'
    Write-Info '  ------------------------------------------------'
    foreach ($r in $rows) {
        Write-Info ("  {0,-12}{1}" -f $r.Item, $r.Value)
        Write-Log ('CHECK  {0} = {1}' -f $r.Item, $r.Value)
    }
    Write-Info '  ------------------------------------------------'

    if (-not $engineDir) { Write-Info '  ! 没有找到 Wallpaper Engine 安装目录。' }
    if (-not $scr)       { Write-Info '  ! 没有找到 wpxscreensaver64.scr，只能使用 -Mode Desktop。' }
    if ($engineDir -and -not $engineRunning) { Write-Info '  ! 引擎没在运行，进入鉴赏前会自动启动它。' }
    Write-Info ''

    return [bool]($engineDir -and $scr)
}

# ---------------------------------------------------------------- 动作

function Enter-Saver {
    param([string]$EngineDir)

    $scr = Get-ScreensaverPath -EngineDir $EngineDir
    if (-not $scr) {
        Fail '没有找到 Wallpaper Engine 的屏幕保护程序文件（wpxscreensaver64.scr）。' @(
            '请确认已安装 Wallpaper Engine 2.x（Steam 里的“Wallpaper Engine：壁纸引擎”）。',
            '如果只是想隐藏桌面图标，可以用：WallpaperView.ps1 -Mode Desktop'
        )
    }

    if ((Get-ProcessLike 'wpxscreensaver*').Count -gt 0) {
        Write-Log 'screensaver already running, nothing to do'
        exit 0
    }

    if (-not (Test-EngineRunning)) {
        if (-not (Start-Engine -EngineDir $EngineDir)) {
            Fail 'Wallpaper Engine 没有运行，自动启动也失败了。' @(
                '请手动启动 Wallpaper Engine 后重试。'
            )
        }
    }

    if ($Shuffle) {
        $exe = Get-EngineExe -EngineDir $EngineDir
        if ($exe) {
            Write-Log 'shuffle: next wallpaper'
            try { & $exe -control nextWallpaper | Out-Null } catch { Write-Log "shuffle failed: $_" }
            Start-Sleep -Milliseconds 600
        }
    }

    if ($Delay -gt 0) {
        Write-Log "delay $Delay s"
        if (-not $Quiet) {
            for ($i = $Delay; $i -gt 0; $i--) {
                Write-Host -NoNewline ("`r  壁纸鉴赏模式将在 {0} 秒后开始…" -f $i)
                Start-Sleep -Seconds 1
            }
            Write-Host ''
        } else {
            Start-Sleep -Seconds $Delay
        }
    }

    Write-Log "starting screensaver: $scr"
    # 直接跑屏保宿主：它自己全屏、自己接管输入、动一下鼠标就退出
    Start-Process -FilePath $scr -ArgumentList '/s' | Out-Null
    Write-Log 'screensaver launched'
}

function Enter-Desktop {
    param([string]$EngineDir)

    $exe = Get-EngineExe -EngineDir $EngineDir
    if (-not $exe) {
        Fail '没有找到 Wallpaper Engine 主程序，无法隐藏桌面图标。' @(
            '请确认已安装 Wallpaper Engine 2.x。',
            '也可以手动隐藏：桌面右键 → 查看 → 取消勾选“显示桌面图标”。'
        )
    }

    & $exe -control hideIcons | Out-Null
    Write-Log 'desktop icons hidden'

    Write-Info ''
    Write-Info '  已隐藏桌面图标，桌面只剩壁纸。'
    Write-Info '  把任务栏设为“自动隐藏”（设置 → 个性化 → 任务栏）会更干净。'
    Write-Info '  恢复图标：WallpaperView.ps1 -Restore'
    Write-Info ''
}

function Restore-Desktop {
    param([string]$EngineDir)

    $exe = Get-EngineExe -EngineDir $EngineDir
    if (-not $exe) { Fail '没有找到 Wallpaper Engine 主程序。' @() }

    & $exe -control showIcons | Out-Null
    Write-Log 'desktop icons restored'
    Write-Info '  已恢复桌面图标。'
}

function Install-ScreenSaver {
    param([string]$EngineDir)

    $source = Get-ScreensaverPath -EngineDir $EngineDir
    if (-not $source) { Fail '找不到 wpxscreensaver64.scr，无法安装。' @() }

    $name = Split-Path -Leaf $source
    $target = Join-Path (Join-Path $env:windir 'System32') $name

    if (Test-Path -LiteralPath $target) {
        Write-Info "  已经安装过了：$target"
        return
    }

    if (-not (Test-Admin)) {
        Fail '把屏保装到 System32 需要管理员权限。' @(
            '本工具不装也能用（默认直接调用安装目录里的原件）。',
            '确实想装：右键 PowerShell → 以管理员身份运行，再执行本命令。'
        )
    }

    Copy-Item -LiteralPath $source -Destination $target -Force
    Write-Log "installed screensaver: $target"
    Write-Info "  已安装到：$target"
    Write-Info '  现在 Windows 屏保设置里也能选到它了（不装也不影响本工具）。'
}

# ---------------------------------------------------------------- 主流程

Write-Log "run: mode=$Mode check=$Check restore=$Restore install=$Install shuffle=$Shuffle delay=$Delay"

$engineDir = Get-EngineDir

if ($Check) {
    [void](Invoke-Check)
    exit 0
}

if ($Install) {
    Install-ScreenSaver -EngineDir $engineDir
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
