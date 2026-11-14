# 壁纸鉴赏

打开后整块屏幕只留壁纸，动一下鼠标就结束鉴赏，后台进程不会没 能放音乐 用着不烧心。

它做的：找到 `wallpaper_engine\bin\wpxscreensaver64.scr`，给它 `/s` 参数跑起来。不装驱动、不改注册表、不动系统设置，退出后什么都不留。

## 安装

1. 去 [Releases](https://github.com/HAMAJIAN/wallpaper-view/releases) 下载我发布的最新的 zip文件
2. 解压到文件夹里（别在压缩包里直接双击！）
3. 双击 `Install.cmd`
4. 桌面上会多出一个叫「壁纸鉴赏」图标

要 Windows 10/11，加一个已经装好的 Wallpaper Engine。别的什么都不用装。

## 怎么用

双击图标，或者按 `Ctrl+Alt+W`。屏幕变成全屏壁纸。

想回来：晃一下鼠标，或者随便按个键。

不想用快捷键就重装一次：

```bat
Install.cmd -NoHotkey
```

## 一个坑

进去之后一片黑，不是工具坏了：当前这张壁纸是「应用程序」类型时，屏保拿不到它。这是 Wallpaper Engine 自己的限制，换一张场景 / 视频 / 网页壁纸就行，或者在壁纸引擎里「配置屏幕保护程序 → 单独配置」，单独指定一张给屏保用。

真出别的问题，先看日志：`%LOCALAPPDATA%\WallpaperView\last-run.log`。

## 不想要了

双击 `Uninstall.cmd` 删掉快捷方式。想清得干净点，再把 `%LOCALAPPDATA%\WallpaperView\` 删掉——里面只有一个日志和一个图标。

## 许可

MIT。代码很短，想改快捷键、改行为，自己动手就行。
