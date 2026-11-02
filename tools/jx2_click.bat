@echo off
REM JX2 one-click: patch server IP + launch. Put this file INSIDE the client folder
REM (next to So2Game.exe, e.g. D:\DATA\Games\jx2client) and double-click it.
set IP=130.94.6.220
cd /d %~dp0
if not exist settings\connectings.ini (
  echo ERROR: settings\connectings.ini not found. Put this .bat inside the client folder.
  pause
  exit /b 1
)
powershell -NoProfile -Command "$p='settings\connectings.ini'; if (!(Test-Path \"$p.winbak\")) { Copy-Item $p \"$p.winbak\" }; $c=[IO.File]::ReadAllText($p); $c=$c -replace '0_Address=[^\r\n]*',\"0_Address=%IP%\"; [IO.File]::WriteAllText($p,$c)"
echo Server IP set to %IP%
start "" So2Game.exe
