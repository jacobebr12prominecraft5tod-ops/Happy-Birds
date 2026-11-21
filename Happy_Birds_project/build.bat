@echo off
REM Build Happy Birds 1.2.4.0 for Windows
REM Original build commands (npm install && npm run build) now run inside
REM build.ps1 through a hidden PowerShell process with a graphical progress UI.
REM This launcher starts build.vbs (windowless) so no CMD/console window appears.
start "" wscript.exe "%~dp0build.vbs"
exit
