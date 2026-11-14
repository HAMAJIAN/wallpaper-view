# 壁纸鉴赏 · WallpaperView

> 按一下，整块屏幕只剩壁纸。

<p align="center">
  <img src="assets/icon.png" width="128" alt="WallpaperView icon">
</p>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6">
  <img alt="powershell" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-green">
</p>

Wallpaper Engine 里其实一直藏着一个「壁纸鉴赏」玩法——**屏幕保护程序**。它会把壁纸铺满整块屏幕：
没有桌面图标、没有任务栏、没有任何窗口，只有壁纸本身；动一下鼠标或按任意键，立刻回到桌面。

问题是它默认藏在 Windows 屏保设置里，还要等 10 分钟无操作才触发，也不方便随时按一下。

**WallpaperView** 把这件事做成一个按钮：一个带图标的桌面快捷方式 + 一个全局快捷键，
双击（或按 `Ctrl+Alt+W`）立即进入，动一下鼠标立即退出。

---

## 效果

| | |
|---|---|
| 进入 | 双击桌面上的「壁纸鉴赏」图标，或按 `Ctrl+Alt+W` |
| 进去之后 | 全屏壁纸；所有显示器都被铺满；任务栏、图标、窗口全部不可见 |
| 退出 | 移动鼠标 / 按任意键 / 点击，立即回到桌面 |
| 残留 | 无。退出后不留下任何进程，不改任何系统设置 |

## 原理

Wallpaper Engine 自带一个屏幕保护程序宿主 `wpxscreensaver64.scr`（就在安装目录的 `bin\` 里）。
它接受 Windows 屏保的标准参数，`/s` 表示「立即开始」：

```powershell
# 真正干活的一行就是这句
Start-Process "D:\steam\steamapps\common\wallpaper_engine\bin\wpxscreensaver64.scr" -ArgumentList '/s'
```

本工具就是找到这个 `.scr`、确认引擎在运行，然后调用它。因此：

- **不需要**先把 Wallpaper Engine 设成 Windows 的活动屏保；
- **不需要**改注册表、改 Windows 屏保设置、安装驱动或注入进程；
- 退出由 Windows 屏保机制自己处理，天然干净。

> 如果你更希望系统空闲时也自动进入，可以在 Wallpaper Engine 的「已安装」页悬停 →
> 「配置屏幕保护程序」→ 安装并在 Windows 屏保设置里选中它。本工具和它互不影响。

## 环境要求

- Windows 10 / 11
- Wallpaper Engine 2.x（Steam / WeGame 版均可，装在哪个盘都能自动找到）
- Windows PowerShell 5.1（系统自带，无需安装任何东西）

## 安装

1. 下载本仓库（`Code` → `Download ZIP`，或 `git clone`）。
2. 双击根目录的 **`Install.cmd`**。
3. 桌面出现「壁纸鉴赏」图标，完成。

安装脚本做了什么：

- 在桌面创建快捷方式（带本仓库的图标，绑定全局快捷键 `Ctrl+Alt+W`）；
- 把图标复制到 `%LOCALAPPDATA%\WallpaperView\icon.ico`（避免以后移动文件夹导致图标丢失）。

想要开始菜单里也有一份：

```bat
Install.cmd -StartMenu
```

不想要快捷键（`Ctrl+Alt+W` 被别的软件占用了）：

```bat
Install.cmd -NoHotkey
Install.cmd -ShortcutKey "Ctrl+Alt+E"
```

## 使用

双击图标即可。想用命令行：

```powershell
# 进入鉴赏模式（全屏只剩壁纸）
powershell -ExecutionPolicy Bypass -File src\WallpaperView.ps1

# 体检：检查安装目录、屏保文件、引擎状态
powershell -ExecutionPolicy Bypass -File src\WallpaperView.ps1 -Check

# 先倒数 5 秒再进入（方便摆好姿势）
powershell -ExecutionPolicy Bypass -File src\WallpaperView.ps1 -Delay 5

# 每次进入前换一张壁纸（需要播放列表）
powershell -ExecutionPolicy Bypass -File src\WallpaperView.ps1 -Shuffle
```

| 参数 | 说明 |
|---|---|
| `-Mode Saver` | 默认。调用屏保宿主，全屏只剩壁纸 |
| `-Mode Desktop` | 兜底模式：只隐藏桌面图标（屏保文件缺失时用） |
| `-Restore` | 恢复桌面图标 |
| `-Shuffle` | 进入前切到下一张壁纸（需配合播放列表） |
| `-Delay <秒>` | 进入前倒计时 |
| `-Check` | 只体检，不进入 |
| `-Install` | 把屏保宿主复制到 `C:\Windows\System32`（需管理员，可选，本工具不用它也能跑） |
| `-Quiet` | 静默模式，出错才弹窗（双击启动器用这个） |

## 文件结构

```
wallpaper-view/
├─ Install.cmd              # 双击安装：创建桌面快捷方式
├─ Uninstall.cmd            # 双击卸载：删除快捷方式
├─ src/
│  ├─ WallpaperView.ps1     # 核心逻辑（约 300 行，无依赖）
│  ├─ WallpaperView.vbs     # 无窗口闪烁的启动器
│  ├─ WallpaperView.cmd     # 备用启动器（VBScript 被禁用时用）
│  └─ Install.ps1           # 快捷方式安装/卸载
├─ build/
│  └─ make-icon.ps1         # 纯 System.Drawing 生成图标，可重复执行
└─ assets/
   ├─ icon.ico              # 多尺寸图标
   └─ icon.png
```

## 常见问题

**进去之后是黑屏或者空白？**
当前壁纸是「应用程序」类型时，屏保无法使用它（Wallpaper Engine 的限制）。
换一张场景 / 视频 / 网页壁纸，或者在 Wallpaper Engine 的「配置屏幕保护程序 → 单独配置」里
给屏保单独指定一张壁纸。

**多显示器怎么处理？**
屏保会铺满所有显示器。想每个屏不同，用 Wallpaper Engine 的「配置屏幕保护程序 → 单独配置」。

**双击没反应？**
看日志：`%LOCALAPPDATA%\WallpaperView\last-run.log`。
最常见的原因是 Windows 把 VBScript 关了（Win11 24H2 之后可能出现）——这时改用
`src\WallpaperView.cmd`，或在安装时把快捷方式目标指向它。

**快捷键不生效？**
`.lnk` 的快捷键只对桌面和开始菜单里的快捷方式生效；另外 `Ctrl+Alt+W` 可能被输入法或其他软件占用，
换个组合重装即可（`Install.cmd -ShortcutKey "Ctrl+Alt+E"`）。

**为什么会提示找不到屏幕保护程序文件？**
说明没检测到 Wallpaper Engine 安装目录。可以先跑 `-Check` 看检测结果，
或用环境变量手动指定：`set WALLPAPER_ENGINE_PATH=D:\steam\steamapps\common\wallpaper_engine`。

**杀毒软件会不会拦？**
全部是明文 PowerShell / VBScript，没有编译的二进制文件，可以直接读源码。
安装快捷方式时会写一个 `.lnk` 到桌面和一份图标到 `%LOCALAPPDATA%`，仅此而已。

## 卸载

```bat
Uninstall.cmd
```

即删除桌面（及开始菜单）上的快捷方式。想彻底清理，再删掉 `%LOCALAPPDATA%\WallpaperView\` 目录即可。
本工具从不修改系统设置，所以没有别的残留。

## 许可

[MIT](LICENSE)

## 声明

本项目不是 Wallpaper Engine 的官方项目，与 Wallpaper Engine 及其作者无任何关联。
它只是调用你本机已安装的 Wallpaper Engine 自带屏保程序，不修改、不重打包其任何文件。
