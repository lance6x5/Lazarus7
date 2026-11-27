# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Lazarus7 - raise your 7-inch HP tablet from the dead.

.DESCRIPTION
    Interactive recovery and deployment wizard for the HP Stream 7 (TSW 7H,
    shipped with Windows 8.1 with Bing). Android HP Slate 7 tablets are
    supported as a secondary path. Start it with Lazarus7.cmd (double-click),
    which asks for admin rights - needed only to write USB sticks.

.PARAMETER DryRun
    Walk through every flow without erasing disks or flashing anything.
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Paths = @{
    Payload   = Join-Path $Root 'payload'
    Downloads = Join-Path $Root 'downloads'
    Tools     = Join-Path $Root 'tools'
    Guide     = Join-Path $Root 'docs\GUIDE.md'
}

foreach ($m in 'Ui', 'Detect', 'Triage', 'Download', 'Usb', 'Android') {
    Import-Module (Join-Path $Root "src\Lazarus7.$m.psm1") -Force -DisableNameChecking
}

function Test-L7Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-L7AdminForUsb {
    if ($DryRun -or (Test-L7Admin)) { return $true }
    Write-L7Warn 'Writing a USB stick needs administrator rights.'
    if (Read-L7YesNo 'Relaunch Lazarus7 as administrator now?' -DefaultYes) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        exit
    }
    return $false
}

function Show-L7FirstAid {
    Write-L7Section 'First aid for the HP Stream 7 (no tools needed)'
    Write-Host '   Dead battery' -ForegroundColor White
    Write-L7Info '2 A wall charger + short cable, 4+ hours. A drained Bay Trail shows NOTHING for the first hour.'
    Write-L7Info 'Then hold Power 15-30 s (hard reset), release, hold Power 5 s to boot.'
    Write-Host ''
    Write-Host '   Startup menu' -ForegroundColor White
    Write-L7Info 'Tablet off -> hold Vol-Down -> press Power until HP logo -> release Power. Tap the keys:'
    Write-L7Info '  F2  hardware diagnostics (test the eMMC first!)'
    Write-L7Info '  F9  boot from USB'
    Write-L7Info '  F10 BIOS setup (Secure Boot, boot order with F5/F6)'
    Write-L7Info '  F11 Windows 8.1 recovery -> Troubleshoot:'
    Write-L7Info '        "Refresh your PC" keeps your files;  "Reset your PC" erases all, back to factory'
    Write-Host ''
    Write-Host '   Windows 8.1 facts that matter' -ForegroundColor White
    Write-L7Info 'It is WIMBoot: C: holds ~4 GB, the rest of Windows lives in the ~5 GB recovery partition.'
    Write-L7Info 'Deleting that partition breaks Windows 8.1. Back it up first (Make a tablet toolkit USB).'
    Write-L7Info 'Windows 8.1 support ended Jan 2023. The Windows key is stored in the firmware.'
    Write-Host ''
    Write-Host '   You will need for USB work' -ForegroundColor White
    Write-L7Info 'micro-USB OTG adapter, POWERED USB hub, USB keyboard (+ mouse), 8 GB+ USB sticks (two for backups).'
    Write-Host ''
    Write-Host '   Android Slate 7 (not a Stream 7)' -ForegroundColor DarkGray
    Write-L7Info 'Recovery: Power + Vol+ (2800: sometimes + Vol-). Rockchip loader: hold Vol+ while plugging in USB.'
    Wait-L7Key
}

function Show-L7RecoverySources {
    Write-L7Section 'Where Stream 7 recovery media comes from (best first)'
    Write-Host '   1. Make it yourself, while Windows 8.1 still boots' -ForegroundColor White
    Write-L7Info 'Lazarus7 toolkit USB -> Stream7-Check on the tablet -> option 2 (Recovery Drive,'
    Write-L7Info 'tick "Copy the recovery partition"). Then "Save a recovery USB to this PC" here.'
    Write-Host '   2. HP Support' -ForegroundColor White
    Write-L7Info 'HP supplied recovery USBs for this tablet through its support channels. Ask with the'
    Write-L7Info 'serial + product number (Stream7-Check saves both). Not guaranteed for a 2014 tablet.'
    Write-L7Info 'Third-party "recovery kits" exist; buyers report mixed results - check the exact model.'
    Write-Host '   3. Not an option' -ForegroundColor White
    Write-L7Info 'HP Cloud Recovery Tool: its supported list has no Stream 7 and no Windows 8.x images.'
    Write-L7Info 'A generic Windows 8.1 ISO is not WIMBoot, has no tablet drivers and barely fits.'
    Write-L7Info 'Recovery images on file-sharing sites: unverifiable - Lazarus7 will not fetch them.'
    Write-Host '   No media at all?' -ForegroundColor White
    Write-L7Info 'Debian 12 (Deploy Linux) needs nothing from HP and is supported until 2028.'
    Wait-L7Key
}

function Select-L7DriversDir {
    if (-not (Read-L7YesNo 'Add a folder of HP Stream 7 5701 drivers to the stick? (recommended for Windows 10)')) { return $null }
    Write-L7Info 'Get them from HP: support.hp.com -> "HP Stream 7 Tablet - 5701" (check the label: 5701 vs 5709).'
    return (Select-L7Folder -Title 'Folder with the HP Stream 7 drivers')
}

function Invoke-L7Toolkit {
    $drivers = Select-L7DriversDir
    Invoke-L7ToolkitUsb -PayloadDir $Paths.Payload -DriversDir $drivers -DryRun:$DryRun
    Wait-L7Key
}

function Invoke-L7WindowsUsb {
    if (-not (Assert-L7AdminForUsb)) { return }
    Write-L7Section 'Restore Windows on the Stream 7'
    Write-L7Info 'The tablet cannot be flashed from this PC over USB (its port has no device mode).'
    Write-L7Info 'This PC builds the stick; the tablet boots it: Vol- + Power -> F9 -> the stick.'
    $backups = @(Get-L7RecoveryBackup)
    $items = @()
    if ($backups.Count) {
        $items += @{ Key = 'saved'; Label = 'A recovery backup saved on this PC'; Hint = "$($backups.Count) found - verified before and after writing" }
    }
    $items += @{ Key = 'hp';     Label = 'HP recovery media / a recovery drive (folder)'; Hint = 'factory Windows 8.1 with Bing (WIMBoot) + drivers' }
    $items += @{ Key = 'backup'; Label = 'Save a recovery USB to this PC';                Hint = 'do this once, right after making the recovery drive' }
    $items += @{ Key = 'where';  Label = 'Where do I get recovery media?' }
    $items += @{ Key = 'iso';    Label = 'Windows 10 x86 (32-bit) ISO';                   Hint = 'unsupported since Oct 2025; may NOT activate with the 8.1 key' }
    $kind = Read-L7Menu -Title 'Windows recovery USB - source' -Items $items
    if (-not $kind) { return }
    $drivers = $null
    $src = $null
    if ($kind -eq 'backup') { Invoke-L7BackupRecoveryUsb -DryRun:$DryRun; Wait-L7Key; return }
    if ($kind -eq 'where') { Show-L7RecoverySources; return }
    if ($kind -eq 'saved') {
        $pick = Read-L7Menu -Title 'Which backup?' -Items @($backups | ForEach-Object {
            @{ Key = $_.Folder; Label = $_.Name; Hint = ("{0} files, {1:N1} GB, label {2}" -f $_.Manifest.FileCount, ($_.Manifest.TotalSize / 1GB), $_.Manifest.Label) } })
        if (-not $pick) { return }
        $src = $pick
    } elseif ($kind -eq 'hp') {
        Write-L7Info 'Already have the recovery drive as a stick? It boots as-is - no need to rebuild it.'
        Write-L7Info 'A generic Windows 8.1 ISO is NOT the same: no WIMBoot, no drivers, and it barely fits.'
        $src = Select-L7Folder -Title 'Folder with the HP recovery / recovery drive files'
    } else {
        Write-L7Warn 'Windows 10 here: 32-bit only, end of support Oct 2025, and Microsoft stopped honouring'
        Write-L7Warn 'Windows 8.x keys for upgrades in 2023 - a clean install may stay unactivated.'
        Write-L7Info 'Best odds: in-place upgrade from a working 8.1 first, confirm activation, THEN clean install.'
        $src = Select-L7File -Title 'Windows 10 x86 ISO' -Filter 'ISO image (*.iso)|*.iso'
        if ($src) { $drivers = Select-L7DriversDir }
    }
    if (-not $src) { return }
    Invoke-L7BuildUsb -Mode windows -SourcePath $src -PayloadDir $Paths.Payload -DriversDir $drivers -DryRun:$DryRun
    Wait-L7Key
}

function Invoke-L7LinuxUsb {
    if (-not (Assert-L7AdminForUsb)) { return }
    $kind = Read-L7Menu -Title 'Deploy Linux - choose the OS' -Items @(
        @{ Key = 'debian'; Label = 'Debian 12 i386 (recommended)'; Hint = 'auto-download + SHA256 check; security support to 2028' }
        @{ Key = 'custom'; Label = 'My own ISO';                   Hint = 'must contain EFI\BOOT\BOOTIA32.EFI' }
    )
    if (-not $kind) { return }
    $iso = if ($kind -eq 'debian') { Get-L7VerifiedDebianIso -DownloadDir $Paths.Downloads }
           else { Select-L7File -Title 'Linux ISO' -Filter 'ISO image (*.iso)|*.iso' }
    if (-not $iso) { return }
    Invoke-L7BuildUsb -Mode linux -SourcePath $iso -PayloadDir $Paths.Payload -DryRun:$DryRun
    Wait-L7Key
}

function Invoke-L7Action {
    param([string]$Action)
    while ($Action) {
        $next = $null
        switch ($Action) {
            'detect'   { $family = Invoke-L7DetectWizard
                         if ($family -in 'Rockchip', 'Android', 'Tegra', 'Marvell' -and (Read-L7YesNo 'Open the Android flash tools?' -DefaultYes)) { $next = 'android' }
                         else { Wait-L7Key } }
            'triage'   { $next = Invoke-L7TriageWizard }
            'firstaid' { Show-L7FirstAid }
            'toolkit'  { Invoke-L7Toolkit }
            'winusb'   { Invoke-L7WindowsUsb }
            'linux'    { Invoke-L7LinuxUsb }
            'android'  { Invoke-L7AndroidWizard -ToolsDir $Paths.Tools -DryRun:$DryRun }
            'guide'    { Start-Process $Paths.Guide }
        }
        $Action = $next
    }
}

while ($true) {
    Show-Lazarus7Banner -DryRun:$DryRun
    $choice = Read-L7Menu -Title 'Main menu' -BackLabel 'Quit' -Items @(
        @{ Key = 'triage';   Label = 'Diagnose - what is wrong?';          Hint = 'start here' }
        @{ Key = 'firstaid'; Label = 'First aid';                          Hint = 'battery, F2/F9/F10/F11, Refresh/Reset' }
        @{ Key = 'toolkit';  Label = 'Make a tablet toolkit USB';          Hint = 'back up Windows 8.1 first - nothing erased' }
        @{ Key = 'winusb';   Label = 'Restore Windows (recovery USB)';     Hint = 'factory 8.1 or Windows 10 x86' }
        @{ Key = 'linux';    Label = 'Deploy Linux';                       Hint = 'Debian 12 USB + tablet tweaks' }
        @{ Key = 'detect';   Label = 'Identify a tablet over USB';         Hint = 'Android only - a Stream 7 never shows up' }
        @{ Key = 'android';  Label = 'Other HP tablets: Android Slate 7';  Hint = 'ADB, fastboot, Rockchip' }
        @{ Key = 'guide';    Label = 'Open the full guide' }
    )
    if (-not $choice) { break }
    try {
        Invoke-L7Action $choice
    } catch {
        Write-L7Fail $_.Exception.Message
        Wait-L7Key
    }
}
Write-Host "`n  Lazarus7 out. Good luck with the resurrection.`n" -ForegroundColor DarkYellow
