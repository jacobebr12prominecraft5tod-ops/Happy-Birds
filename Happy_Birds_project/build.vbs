' ExeForge hidden build launcher for Happy Birds
' Launches build.ps1 in a completely hidden PowerShell window (no CMD/console).
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
psPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "build.ps1")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psPath & """", 0, False
