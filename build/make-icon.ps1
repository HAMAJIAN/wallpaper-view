#Requires -Version 5.1
<#
    生成 WallpaperView 的图标（assets/icon.ico + assets/icon.png）。
    纯 System.Drawing 绘制，不依赖任何第三方库，可重复执行。

    用法：powershell -ExecutionPolicy Bypass -File build\make-icon.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $root 'assets' }
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

function New-RoundedPath {
    param([single]$X, [single]$Y, [single]$W, [single]$H, [single]$R)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $path.AddArc($X, $Y, $d, $d, 180, 90)
    $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
    $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-IconBitmap {
    param([int]$Size = 512)

    $s = [single]$Size
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # ---- 外框：深色“显示器外壳”
    $bezel = New-RoundedPath -X 0 -Y 0 -W $s -H $s -R ($s * 0.225)
    $bezelBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.RectangleF(0, 0, $s, $s)),
        [System.Drawing.Color]::FromArgb(255, 27, 30, 62),
        [System.Drawing.Color]::FromArgb(255, 12, 14, 33),
        [single]90)
    $g.FillPath($bezelBrush, $bezel)

    # ---- 屏幕：内嵌的圆角矩形
    $inset = $s * 0.070
    $sx = $inset
    $sy = $inset
    $sw = $s - 2 * $inset
    $sh = $s - 2 * $inset
    $screen = New-RoundedPath -X $sx -Y $sy -W $sw -H $sh -R ($s * 0.135)
    $g.SetClip($screen)

    # 暮色天空
    $sky = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.RectangleF($sx, $sy, $sw, $sh)),
        [System.Drawing.Color]::FromArgb(255, 31, 33, 96),
        [System.Drawing.Color]::FromArgb(255, 126, 79, 240),
        [single]68)
    $g.FillRectangle($sky, [single]$sx, [single]$sy, [single]$sw, [single]$sh)

    # 星星
    $star = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(95, 255, 255, 255))
    foreach ($p in @(@(0.22, 0.16, 0.010), @(0.36, 0.11, 0.007), @(0.58, 0.20, 0.008), @(0.72, 0.12, 0.006))) {
        $r = $sw * $p[2]
        $g.FillEllipse($star,
            [single]($sx + $sw * $p[0] - $r), [single]($sy + $sh * $p[1] - $r),
            [single]($r * 2), [single]($r * 2))
    }

    # 月亮 + 柔光
    $moon = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 218, 132))
    $moonGlow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 255, 214, 122))
    $mr = $sw * 0.072
    $mx = [single]($sx + $sw * 0.29)
    $my = [single]($sy + $sh * 0.22)
    $g.FillEllipse($moonGlow, [single]($mx - $mr * 2.2), [single]($my - $mr * 2.2), [single]($mr * 4.4), [single]($mr * 4.4))
    $g.FillEllipse($moon, [single]($mx - $mr), [single]($my - $mr), [single]($mr * 2), [single]($mr * 2))

    # 地平线
    $horizon = [single]($sy + $sh * 0.775)

    # 远山
    $far = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 198, 209, 255))
    $g.FillPolygon($far, [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF([single]($sx - $sw * 0.03), $horizon)),
        (New-Object System.Drawing.PointF([single]($sx + $sw * 0.26), [single]($sy + $sh * 0.44))),
        (New-Object System.Drawing.PointF([single]($sx + $sw * 0.58), $horizon))
    ))

    # 近山
    $near = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 238, 242, 255))
    $g.FillPolygon($near, [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF([single]($sx + $sw * 0.40), $horizon)),
        (New-Object System.Drawing.PointF([single]($sx + $sw * 0.63), [single]($sy + $sh * 0.31))),
        (New-Object System.Drawing.PointF([single]($sx + $sw * 1.03), $horizon))
    ))

    # 水面
    $water = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(62, 255, 255, 255))
    $g.FillRectangle($water, [single]$sx, $horizon, [single]$sw, [single]($sy + $sh - $horizon))

    # 月光在水面的碎影
    $shine = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(42, 255, 232, 180))
    for ($i = 0; $i -lt 4; $i++) {
        $w = $sw * (0.26 - 0.05 * $i)
        $x = $sx + $sw * 0.29 - $w / 2
        $y = $horizon + $sh * (0.030 + 0.042 * $i)
        $g.FillRectangle($shine, [single]$x, [single]$y, [single]$w, [single]($sh * 0.011))
    }

    $g.ResetClip()

    # 屏幕描边
    $screenPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 255, 255, 255), [single]($s * 0.008))
    $g.DrawPath($screenPen, $screen)

    # 外框内描边，深色任务栏上也有轮廓
    $bezelPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(38, 255, 255, 255), [single]($s * 0.007))
    $g.DrawPath($bezelPen, $bezel)

    $g.Dispose()
    $bezel.Dispose(); $screen.Dispose()
    $bezelBrush.Dispose(); $sky.Dispose()
    $star.Dispose(); $moon.Dispose(); $moonGlow.Dispose(); $shine.Dispose()
    $far.Dispose(); $near.Dispose(); $water.Dispose()
    $screenPen.Dispose(); $bezelPen.Dispose()

    return $bmp
}

function Get-ScaledPng {
    param([System.Drawing.Bitmap]$Source, [int]$Size)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.DrawImage($Source, (New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)))
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray()
    $ms.Dispose(); $bmp.Dispose()
    return ,$bytes
}

$master = New-IconBitmap -Size 512

$png = Join-Path $OutDir 'icon.png'
$master.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "wrote $png"

# 多尺寸 ICO（PNG 压缩条目，Vista 及以上支持）
$sizes = @(256, 128, 96, 64, 48, 40, 32, 24, 20, 16)
$images = @{}
foreach ($size in $sizes) { $images[$size] = Get-ScaledPng -Source $master -Size $size }

$icoPath = Join-Path $OutDir 'icon.ico'

$offset = 6 + (16 * $sizes.Count)
$offsets = @{}
foreach ($size in $sizes) {
    $offsets[$size] = $offset
    $offset += ([byte[]]$images[$size]).Length
}

$stream = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter($stream)

$writer.Write([uint16]0)
$writer.Write([uint16]1)
$writer.Write([uint16]$sizes.Count)

foreach ($size in $sizes) {
    $data = [byte[]]$images[$size]
    if ($size -ge 256) { $dim = [byte]0 } else { $dim = [byte]$size }
    $writer.Write($dim)
    $writer.Write($dim)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]$data.Length)
    $writer.Write([uint32]$offsets[$size])
}

foreach ($size in $sizes) {
    $writer.Write([byte[]]$images[$size])
}

$writer.Flush()
[System.IO.File]::WriteAllBytes($icoPath, $stream.ToArray())
$writer.Dispose(); $stream.Dispose()
Write-Host "wrote $icoPath ($($sizes.Count) sizes, $((Get-Item -LiteralPath $icoPath).Length) bytes)"

$master.Dispose()
