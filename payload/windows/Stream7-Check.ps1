# Lazarus7 - Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Runs ON THE HP STREAM 7 under Windows 8.1 (PowerShell 4.0) or Windows 10.
# Start it with Stream7-Check.cmd from the Lazarus7 USB stick.
#
#  1. Saves a report to the stick: model, serial, product number, the Windows
#     key embedded in the firmware, activation, WIMBoot, BitLocker, partitions.
#  2. Helps you back up before wiping: turn off Fast Startup / hibernation,
#     open the Windows Recovery Drive creator, install drivers from \Drivers.
#
# Keep to PowerShell 4.0 syntax (no classes, no ::new()).

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$usbRoot = Split-Path -Parent (Split-Path -Parent $here)   # <usb>\lazarus7\windows -> <usb>\

function Say($text, $color) { if (-not $color) { $color = 'Gray' }; Write-Host "  $text" -ForegroundColor $color }
function Try-Get($block) { try { & $block } catch { $null } }

function Get-Stream7Facts {
    $cs   = Try-Get { Get-CimInstance Win32_ComputerSystem }
    $bios = Try-Get { Get-CimInstance Win32_BIOS }
    $sku  = Try-Get { (Get-CimInstance -Namespace root\wmi -ClassName MS_SystemInformation).SystemSKU }
    $os   = Try-Get { Get-CimInstance Win32_OperatingSystem }
    $key  = Try-Get { (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey }
    $lic  = Try-Get { Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" | Select-Object -First 1 }
    $bat  = Try-Get { Get-CimInstance Win32_Battery | Select-Object -First 1 }
    $c    = Try-Get { Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" }

    $wimboot = 'unknown (run as administrator)'
    $dism = Try-Get { & dism.exe /English /Get-WIMBootEntry /Path:C:\ 2>&1 | Out-String }
    if ($dism -match 'WIM File') { $wimboot = 'YES - Windows runs from the recovery partition. Do NOT delete it.' }
    elseif ($dism -match 'Error: 740|elevat') { $wimboot = 'unknown (run as administrator)' }
    elseif ($dism -match 'error|Error') { $wimboot = 'no (or unsupported) - ' + (($dism -split "`r?`n" | Where-Object { $_ -match 'Error' } | Select-Object -First 1)) }
    elseif ($dism) { $wimboot = 'no' }

    $bitlocker = Try-Get { (& manage-bde.exe -status C: 2>&1 | Out-String) }
    $protection = if ($bitlocker -match 'Protection Status:\s*(.+)') { $Matches[1].Trim() } else { 'unknown' }

    $fastStartup = Try-Get { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled).HiberbootEnabled }

    $licStatus = switch ($lic.LicenseStatus) { 1 { 'Activated' } 0 { 'Unlicensed' } 2 { 'Grace period' } 5 { 'Notification (not activated)' } default { 'unknown' } }

    [ordered]@{
        'Model'                 = "$($cs.Manufacturer) $($cs.Model)"
        'Product number (SKU)'  = $sku
        'Serial number'         = $bios.SerialNumber
        'BIOS version'          = $bios.SMBIOSBIOSVersion
        'Windows'               = "$($os.Caption) $($os.OSArchitecture) build $($os.BuildNumber)"
        'Activation'            = $licStatus
        'Firmware product key'  = $(if ($key) { $key } else { 'none found' })
        'WIMBoot'               = $wimboot
        'BitLocker / device encryption' = $protection
        'Fast Startup'          = $(switch ($fastStartup) { 1 { 'ON (turn off before installing Linux)' } 0 { 'off' } default { 'unknown' } })
        'C: free'               = $(if ($c) { '{0:N1} GB of {1:N1} GB' -f ($c.FreeSpace / 1GB), ($c.Size / 1GB) } else { 'unknown' })
        'Battery'               = $(if ($bat) { "$($bat.EstimatedChargeRemaining)%" } else { 'unknown' })
    }
}

function Save-Report($facts) {
    $dir = Join-Path $usbRoot 'lazarus7\reports'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $serial = ($facts['Serial number'] -replace '[^A-Za-z0-9]', '')
    if (-not $serial) { $serial = 'unknown' }
    $file = Join-Path $dir ("Stream7-{0}-{1}.txt" -f $serial, (Get-Date -Format 'yyyyMMdd-HHmm'))
    $lines = @("Lazarus7 Stream 7 report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '')
    foreach ($k in $facts.Keys) { $lines += ('{0,-31} {1}' -f ($k + ':'), $facts[$k]) }
    $lines += ''
    $lines += 'Partitions:'
    $parts = Try-Get { Get-Partition -DiskNumber 0 | Select-Object PartitionNumber, DriveLetter, @{n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 2) } }, Type | Format-Table -AutoSize | Out-String }
    $lines += $(if ($parts) { $parts } else { '  (run as administrator to list partitions)' })
    $lines += 'Keep this file private: it contains your Windows product key and serial number.'
    Set-Content -Path $file -Value $lines -Encoding UTF8
    return $file
}

function Invoke-InstallDrivers {
    $drivers = Join-Path $usbRoot 'Drivers'
    if (-not (Test-Path $drivers)) { Say "No \Drivers folder on the stick. Put HP's Stream 7 5701 drivers there first." Yellow; return }
    $infs = @(Get-ChildItem $drivers -Recurse -Filter *.inf)
    $exes = @(Get-ChildItem $drivers -Recurse -Filter *.exe)
    if ($infs.Count) {
        Say "Installing $($infs.Count) INF driver(s)..." Cyan
        $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
        if ($build -ge 10240) { & pnputil.exe /add-driver (Join-Path $drivers '*.inf') /subdirs /install }
        else { foreach ($i in $infs) { & pnputil.exe -i -a $i.FullName } }
    }
    if ($exes.Count) {
        Say 'HP SoftPaq installers found. Run them in this order, rebooting only at the end:' Yellow
        Say '  1) chipset / "Driver Pack"  2) Goodix touch  3) Realtek audio  4) Bluetooth  5) Kionix sensor' Yellow
        $exes | ForEach-Object { Say ('     ' + $_.FullName.Substring($drivers.Length)) }
    }
}

# ---- main ------------------------------------------------------------------
Clear-Host
Write-Host ''
Write-Host '  LAZARUS7 :: HP Stream 7 check & backup' -ForegroundColor DarkYellow
Write-Host '  For help only - use at your own risk, no warranty, no liability (DISCLAIMER.md).' -ForegroundColor DarkGray
Write-Host ''
Say 'Collecting facts...' Cyan
$facts = Get-Stream7Facts
foreach ($k in $facts.Keys) { Write-Host ('  {0,-31} ' -f ($k + ':')) -NoNewline -ForegroundColor Gray; Write-Host $facts[$k] -ForegroundColor White }
$report = Save-Report $facts
Write-Host ''
Say "Report saved: $report" Green
Say 'It holds your product key + serial - keep it private.' DarkGray

while ($true) {
    Write-Host ''
    Write-Host '  [1] Turn off Fast Startup + hibernation  (needed before Linux; frees space on C:)' -ForegroundColor White
    Write-Host '  [2] Make a Windows recovery drive        (use a SECOND 8 GB+ stick - it gets erased)' -ForegroundColor White
    Write-Host '  [3] Install drivers from \Drivers on this stick' -ForegroundColor White
    Write-Host '  [4] Open HP driver downloads for the Stream 7 5701' -ForegroundColor White
    Write-Host '  [0] Exit' -ForegroundColor Gray
    $a = (Read-Host '  Choose').Trim()
    switch ($a) {
        '1' { & powercfg.exe /h off; Say 'Fast Startup and hibernation are off.' Green }
        '2' {
            Say 'In the wizard: TICK "Copy the recovery partition from the PC to the recovery drive".' Yellow
            Say 'On a WIMBoot Stream 7 that partition IS Windows 8.1 - this stick becomes your only way back.' Yellow
            Say 'Do NOT pick this Lazarus7 stick as the target.' Yellow
            Start-Process "$env:WINDIR\System32\RecoveryDrive.exe"
        }
        '3' { Invoke-InstallDrivers }
        '4' { Start-Process 'https://support.hp.com/us-en/drivers/selfservice/hp-stream-tablets/7439994/model/7482041' }
        '0' { return }
        default { Say 'Pick 0-4.' Yellow }
    }
}
