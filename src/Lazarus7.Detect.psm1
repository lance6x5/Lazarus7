# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Read-only USB detection: figures out which tablet chip / mode is talking to the PC.

$script:KnownVendors = @{
    '2207' = @{ Family = 'Rockchip'; Meaning = 'HP Slate 7 2800 (RK3066) in loader / mask-ROM mode' }
    '0955' = @{ Family = 'Tegra';    Meaning = 'HP Slate 7 Extreme / Plus (Tegra 4) in APX recovery or ADB' }
    '18D1' = @{ Family = 'Android';  Meaning = 'Android ADB or fastboot interface' }
    '1286' = @{ Family = 'Marvell';  Meaning = 'HP Slate 7 HD / VoiceTab download mode' }
    '0BB4' = @{ Family = 'Android';  Meaning = 'Generic Android ADB interface' }
}
# HP's own VID (03F0) is shared with docks and hubs, so HP tablets are matched by name.
$script:AndroidNamePattern = 'ADB|Android|Fastboot|Bootloader|Slate'

<#
  Pure function: classifies one PnP device. Returns $null when it isn't interesting.
  Kept separate from Get-PnpDevice so it can be unit-tested.
#>
function ConvertTo-L7TabletDevice {
    param([string]$InstanceId, [string]$FriendlyName, [string]$Status)
    if ($InstanceId -notmatch 'VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') { return $null }
    $vid = $Matches[1].ToUpper()
    $pid_ = $Matches[2].ToUpper()
    $known = $script:KnownVendors[$vid]
    if (-not $known -and $FriendlyName -match $script:AndroidNamePattern) {
        $known = @{ Family = 'Android'; Meaning = 'Android ADB/fastboot-style interface' }
    }
    if (-not $known) { return $null }
    [pscustomobject]@{
        VID          = $vid
        PID          = $pid_
        Family       = $known.Family
        Status       = $Status
        Name         = $FriendlyName
        Meaning      = $known.Meaning
        NeedsDriver  = ($Status -ne 'OK')
    }
}

function Get-L7TabletUsbDevice {
    Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        ForEach-Object { ConvertTo-L7TabletDevice -InstanceId $_.InstanceId -FriendlyName $_.FriendlyName -Status $_.Status } |
        Where-Object { $_ } |
        Sort-Object VID, PID -Unique
}

function Invoke-L7DetectWizard {
    Write-L7Section 'Identify my tablet'
    Write-L7Info 'Quick check: what does the label on the back say, and what OS did it ship with?'
    Write-L7Info '  "TSW 7H" / Windows 8.1   -> HP Stream 7 (Intel Atom, 32-bit UEFI)'
    Write-L7Info '  "Slate 7" / Android      -> HP Slate 7 family (Rockchip / Tegra / Marvell)'
    Write-Host ''
    Write-L7Info 'If it is an Android Slate, plug it into this PC now (use a DATA cable).'
    Write-L7Info 'If it is a Stream 7, it will never show up on a PC - that is normal.'
    Wait-L7Key

    Write-L7Step 'Scanning USB...'
    $found = @(Get-L7TabletUsbDevice)
    if ($found.Count -eq 0) {
        Write-L7Warn 'No tablet-related USB device found.'
        Write-L7Info 'Stream 7: expected. Use "Diagnose" or "Deploy Linux" from the main menu.'
        Write-L7Info 'Android Slate: try another cable/port, and hold Vol+ while plugging in (Rockchip),'
        Write-L7Info 'or Vol- + Power (Tegra APX). Then scan again.'
        return $null
    }
    $found | Format-Table VID, PID, Status, Name, Meaning -AutoSize -Wrap | Out-Host
    foreach ($d in $found | Where-Object NeedsDriver) {
        switch ($d.Family) {
            'Rockchip' { Write-L7Warn 'Rockchip device has no driver: install Rockchip DriverAssistant, then rescan.' }
            'Android'  { Write-L7Warn 'ADB device has no driver: install the Google USB Driver (Android SDK).' }
            default    { Write-L7Warn "$($d.Family) device has no driver installed." }
        }
    }
    return ($found | Select-Object -First 1).Family
}

Export-ModuleMember -Function ConvertTo-L7TabletDevice, Get-L7TabletUsbDevice, Invoke-L7DetectWizard
