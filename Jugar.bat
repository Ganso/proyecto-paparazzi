@echo off
rem Lanzador para Windows: usa GODOT_BIN, luego un Godot*_win64.exe local y por ultimo godot-4/godot del PATH.
setlocal
cd /d "%~dp0"
if defined GODOT_BIN if exist "%GODOT_BIN%" (
  start "" "%GODOT_BIN%" --path "%CD%"
  exit /b 0
)
set "PAPARAZZI_ENGINE="
for /f "delims=" %%F in ('dir /b /o-n "Godot*_win64.exe" 2^>nul') do if not defined PAPARAZZI_ENGINE set "PAPARAZZI_ENGINE=%%F"
if defined PAPARAZZI_ENGINE (
  start "" "%CD%\%PAPARAZZI_ENGINE%" --path "%CD%"
  exit /b 0
)
for %%G in (godot-4.exe godot-4 godot.exe godot) do (
  where %%G >nul 2>&1 && (
    start "" %%G --path "%CD%"
    exit /b 0
  )
)
echo No se encuentra Godot 4. Copia Godot_v4.x-stable_win64.exe en esta carpeta, instalalo o configura GODOT_BIN.
pause
exit /b 1
