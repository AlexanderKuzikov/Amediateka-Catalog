' Silent launcher for monthly.ps1: no console window, no focus stealing.
Option Explicit
Dim fso, sh, ps1, rc
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
ps1 = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "monthly.ps1")
rc = sh.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & ps1 & """", 0, True)
WScript.Quit rc
