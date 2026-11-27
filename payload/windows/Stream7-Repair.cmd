@echo off
rem Lazarus7 - Copyright (c) 2026 lance6x5 - MIT License
rem
rem Boot repair for the HP Stream 7, run from a Windows SETUP / RECOVERY stick:
rem   boot the stick (Vol- + Power -> F9), choose "Repair your computer" ->
rem   Troubleshoot -> Command Prompt, then run:   D:\lazarus7\windows\Stream7-Repair.cmd
rem   (the stick's letter may differ: try D:, E:, F:  -  "dir D:\lazarus7" to check)
rem
rem For errors like 0xc0000225 "Your PC needs to be repaired" and a black screen
rem after the HP logo. Steps 1-4 only LOOK. Step 5 (rebuild boot files) changes
rem the EFI partition and runs only if you type REPAIR.
rem Runs in WinPE, which has no PowerShell - plain batch only.

setlocal EnableExtensions EnableDelayedExpansion
title Lazarus7 - HP Stream 7 boot repair
set "HERE=%~dp0"
set "LOG=%HERE%..\reports\Stream7-Repair-%RANDOM%.txt"
if not exist "%HERE%..\reports" mkdir "%HERE%..\reports" >nul 2>&1

echo.
echo   LAZARUS7 :: HP Stream 7 boot repair (Windows PE)
echo   For help only - use at your own risk, no warranty, no liability (DISCLAIMER.md).
echo   Log: %LOG%
echo.
echo Lazarus7 Stream 7 boot repair log> "%LOG%"

rem ---- 1. Disks and partitions (read-only) --------------------------------------
echo   [1/5] Partitions on the tablet's eMMC (disk 0):
set "DP=%TEMP%\l7-diskpart.txt"
> "%DP%" echo list disk
>>"%DP%" echo select disk 0
>>"%DP%" echo list partition
>>"%DP%" echo list volume
diskpart /s "%DP%" > "%TEMP%\l7-parts.txt" 2>&1
type "%TEMP%\l7-parts.txt"
type "%TEMP%\l7-parts.txt" >> "%LOG%"
echo.
echo   What to look for: a ~4-15 GB NTFS volume (Windows), a ~100-300 MB FAT32 "System"
echo   (EFI) partition, and a ~5 GB "Recovery"/hidden partition (WIMBoot images).
echo   Disk 0 missing or tiny = eMMC problem: run the F2 storage test.
echo.
pause

rem ---- 2. Find the Windows installation ----------------------------------------
echo   [2/5] Looking for Windows on the tablet...
set "WIN="
for %%L in (C D E F G H I J K L M N O P Q R T U V W Y Z) do (
  if exist %%L:\Windows\System32\config\SYSTEM (
    if not defined WIN set "WIN=%%L"
    echo     found Windows on %%L:
    echo found Windows on %%L: >> "%LOG%"
  )
)
if not defined WIN (
  echo     No Windows folder found on any lettered volume.
  echo     - BitLocker/Device Encryption locks it: manage-bde -unlock C: -RecoveryPassword ^<key^>
  echo       ^(key at https://account.microsoft.com/devices/recoverykey^), then run this again.
  echo     - Or Windows was erased: restore from recovery media, or install Debian / Windows 10.
  echo no Windows found >> "%LOG%"
  where manage-bde >nul 2>&1 && manage-bde -status >> "%LOG%" 2>&1
  goto :done
)
echo.

rem ---- 3. WIMBoot: does Windows still reach its images? ------------------------
echo   [3/5] WIMBoot check for %WIN%: (Windows 8.1 with Bing keeps its files in WIM images)
dism /English /Get-WIMBootEntry /Path:%WIN%:\ > "%TEMP%\l7-wimboot.txt" 2>&1
type "%TEMP%\l7-wimboot.txt"
type "%TEMP%\l7-wimboot.txt" >> "%LOG%"
findstr /i /c:"WIM File" "%TEMP%\l7-wimboot.txt" >nul && (
  echo.
  echo   WIMBoot entries found. Check the paths above: if their partition is GONE ^(step 1^),
  echo   Windows 8.1 cannot start again - a boot-file rebuild will NOT help. Use recovery media
  echo   or install a new OS.
) || (
  echo   No WIMBoot entries - a normal ^(non-WIMBoot^) install, or a different Windows.
)
echo.
pause

rem ---- 4. EFI boot files ----------------------------------------------------------
echo   [4/5] Checking the EFI system partition...
mountvol S: /s >nul 2>&1
if not exist S:\ (
  echo     Could not mount the EFI partition as S:. If step 1 shows no ~100-300 MB FAT32
  echo     partition, it was deleted - step 5 cannot fix that without re-creating it.
  echo EFI partition not mountable >> "%LOG%"
) else (
  if exist S:\EFI\Microsoft\Boot\BCD (echo     BCD store: present) else (echo     BCD store: MISSING  ^<- explains 0xc0000225)
  if exist S:\EFI\Boot\bootia32.efi (echo     EFI\Boot\bootia32.efi: present) else (echo     EFI\Boot\bootia32.efi: missing)
  dir /s /b S:\EFI >> "%LOG%" 2>&1
)
echo.
set "ANS="
set /p "ANS=  Run a read-only disk check of %WIN%: (chkdsk, can take a while)? [y/N] "
if /i "!ANS!"=="y" (
  chkdsk %WIN%: > "%TEMP%\l7-chkdsk.txt" 2>&1
  type "%TEMP%\l7-chkdsk.txt"
  type "%TEMP%\l7-chkdsk.txt" >> "%LOG%"
)
echo.

rem ---- 5. Rebuild the boot files (only with confirmation) ------------------------
echo   [5/5] Rebuild the boot files with:  bcdboot %WIN%:\Windows /s S: /f UEFI
echo         This rewrites the boot configuration on the EFI partition. It does NOT touch
echo         your files or the WIMBoot images. Do it only if steps 1-3 look healthy.
if not exist S:\ (echo     Skipped: no EFI partition mounted. & goto :done)
set "ANS="
set /p "ANS=  Type REPAIR to rebuild, anything else to skip: "
if not "!ANS!"=="REPAIR" (echo     Skipped. & goto :done)
bcdboot %WIN%:\Windows /s S: /f UEFI >> "%LOG%" 2>&1
if errorlevel 1 (
  echo     bcdboot FAILED - see the log. Recovery media or a new OS is the way forward.
) else (
  echo     Boot files rebuilt. Remove the stick, then: wpeutil reboot
  echo     The F11 recovery entry may still fail; normal boot is what this fixes.
)

:done
mountvol S: /d >nul 2>&1
echo.
echo   Log saved: %LOG%
echo   Bring it to the PC (or paste it) if you want help reading it.
echo.
endlocal
pause
