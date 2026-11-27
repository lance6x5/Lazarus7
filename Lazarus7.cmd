@echo off
rem Lazarus7 launcher - Copyright (c) 2026 lance6x5 - MIT License
rem Double-click to start. Asks for admin (needed to write USB sticks).
rem   Lazarus7.cmd --dry-run   walk through everything without changing anything

setlocal
set "L7_ARGS="
if /i "%~1"=="--dry-run" set "L7_ARGS=-DryRun"

net session >nul 2>&1
if %errorlevel%==0 goto run
if defined L7_ARGS goto run

echo Requesting administrator rights...
powershell.exe -NoProfile -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0Lazarus7.ps1\"'"
exit /b

:run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lazarus7.ps1" %L7_ARGS%
if errorlevel 1 pause
