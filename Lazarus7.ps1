# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Lazarus7 - raise your 7-inch HP tablet from the dead.

.DESCRIPTION
    Interactive recovery and deployment wizard for the HP Stream 7 (TSW 7H) and
    the Android HP Slate 7 family. Start it with Lazarus7.cmd (double-click),
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
    Write-L7Section 'First aid (no tools needed)'
    Write-Host '   Dead battery' -ForegroundColor White
    Write-L7Info '2 A wall charger + short cable, 4+ hours. A drained Bay Trail shows NOTHING for the first hour.'
    Write-L7Info 'Then hold Power 15-30 s (hard reset), release, hold Power 5 s to boot.'
    Write-Host ''
    Write-Host '   Stream 7 startup menu' -ForegroundColor White
    Write-L7Info 'Tablet off -> hold Vol-Down -> press Power until HP logo -> release Power.'
    Write-L7Info '  F2  hardware diagnostics (test the eMMC first!)'
    Write-L7Info '  F9  boot from USB'
    Write-L7Info '  F10 BIOS setup (Secure Boot, boot order with F5/F6)'
    Write-L7Info '  F11 HP System Recovery (factory restore, if the partition still exists)'
    Write-Host ''
    Write-Host '   Android Slate 7' -ForegroundColor White
    Write-L7Info 'Recovery: Power + Vol+ (on the 2800 sometimes Power + Vol+ + Vol-).'
    Write-L7Info 'Rockchip loader mode: tablet off, hold Vol+ while plugging USB into the PC.'
    Write-Host ''
    Write-Host '   You will need for USB work' -ForegroundColor White
    Write-L7Info 'micro-USB OTG adapter, POWERED USB hub, USB keyboard, 8 GB+ USB stick.'
    Wait-L7Key
}

function Invoke-L7WindowsUsb {
    if (-not (Assert-L7AdminForUsb)) { return }
    $kind = Read-L7Menu -Title 'Windows recovery USB - source' -Items @(
        @{ Key = 'hp';  Label = 'HP recovery files (folder)'; Hint = 'from HP Recovery Media, Windows 8.1' }
        @{ Key = 'iso'; Label = 'Windows 10 x86 (32-bit) ISO'; Hint = 'out of support; Windows 11 is impossible here' }
    )
    if (-not $kind) { return }
    $src = if ($kind -eq 'hp') { Select-L7Folder -Title 'Folder with the HP recovery USB files' }
           else { Select-L7File -Title 'Windows 10 x86 ISO' -Filter 'ISO image (*.iso)|*.iso' }
    if (-not $src) { return }
    Invoke-L7BuildUsb -Mode windows -SourcePath $src -PayloadDir $Paths.Payload -DryRun:$DryRun
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
        @{ Key = 'triage';   Label = 'Diagnose - what is wrong?';        Hint = 'start here' }
        @{ Key = 'detect';   Label = 'Identify my tablet';               Hint = 'USB scan' }
        @{ Key = 'firstaid'; Label = 'First aid';                        Hint = 'battery, key combos, BIOS' }
        @{ Key = 'winusb';   Label = 'Build Windows recovery USB';       Hint = 'Stream 7' }
        @{ Key = 'linux';    Label = 'Deploy Linux';                     Hint = 'Stream 7 - Debian USB + tablet tweaks' }
        @{ Key = 'android';  Label = 'Flash / recover Android Slate 7';  Hint = 'ADB, fastboot, Rockchip' }
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
