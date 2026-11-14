' WallpaperView launcher
' 双击后不显示任何控制台窗口，直接把 -Quiet 交给 WallpaperView.ps1。
Option Explicit

Dim fso, shell, here, ps1, cmdline, i

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

here = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = fso.BuildPath(here, "WallpaperView.ps1")

If Not fso.FileExists(ps1) Then
    MsgBox "WallpaperView.ps1 not found next to this launcher." & vbCrLf & vbCrLf & _
           "Expected: " & ps1, 16, "WallpaperView"
    WScript.Quit 1
End If

cmdline = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """ -Quiet"

For i = 0 To WScript.Arguments.Count - 1
    cmdline = cmdline & " """ & WScript.Arguments(i) & """"
Next

' 0 = hidden window, False = do not wait
shell.Run cmdline, 0, False
