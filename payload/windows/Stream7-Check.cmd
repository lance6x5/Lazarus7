@echo off
rem Lazarus7 - Copyright (c) 2026 lance6x5 - MIT License
rem Run this ON THE HP STREAM 7 (Windows 8.1 / 10): double-tap it in File Explorer.
rem Asks for admin so it can read WIMBoot / BitLocker status and turn off Fast Startup.

net session >nul 2>&1
if %errorlevel%==0 goto run
powershell.exe -NoProfile -Command "Start-Process cmd.exe -Verb RunAs -ArgumentList '/c','\"%~f0\"'"
exit /b

:run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stream7-Check.ps1"
pause
