# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Android HP Slate 7 recovery: ADB / fastboot wrappers and the Rockchip flash flow.

function Invoke-L7Tool {
    param([Parameter(Mandatory)][string]$Exe, [string[]]$Arguments, [switch]$DryRun)
    $line = "$(Split-Path -Leaf $Exe) $($Arguments -join ' ')"
    if ($DryRun) { Write-L7Info "[dry run] Would run: $line"; return 0 }
    Write-L7Step $line
    & $Exe @Arguments | Out-Host
    return $LASTEXITCODE
}

function Invoke-L7RockchipFlow {
    param([Parameter(Mandatory)][string]$ToolsDir, [switch]$DryRun)
    Write-L7Section 'Rockchip (HP Slate 7 2800) full firmware flash'
    Write-L7Info 'You need, all for the SAME board revision:'
    Write-L7Info '  - Rockchip DriverAssistant (USB driver)'
    Write-L7Info '  - RKDevTool / RKBatchTool (Rockchip flasher, Windows GUI)'
    Write-L7Info '  - A Slate 7 2800 update.img (stock or custom) - check its checksum'
    Write-Host ''
    Write-L7Info 'Enter loader mode: tablet OFF, hold Vol+ (try Vol+ AND Vol- if needed),'
    Write-L7Info 'plug the USB cable into this PC, keep holding ~5 s.'
    Wait-L7Key

    $rk = @(Get-L7TabletUsbDevice | Where-Object Family -eq 'Rockchip')
    if (-not $rk) {
        Write-L7Warn 'No Rockchip device (VID 2207) detected yet.'
        Write-L7Info 'Check the cable is a data cable and the driver is installed, then retry.'
        if (-not (Read-L7YesNo 'Continue to the flasher anyway?')) { return }
    } elseif ($rk | Where-Object NeedsDriver) {
        Write-L7Warn 'Rockchip device found but has no driver - install DriverAssistant first.'
        return
    } else {
        Write-L7Ok "Rockchip device in loader mode: $($rk[0].VID):$($rk[0].PID)"
    }

    $settings = Join-Path $ToolsDir 'rockchip-tool.txt'
    $flasher = if (Test-Path $settings) { (Get-Content $settings -TotalCount 1).Trim() } else { $null }
    if (-not $flasher -or -not (Test-Path $flasher)) {
        $flasher = Select-L7File -Title 'Locate RKDevTool.exe / RKBatchTool.exe / AndroidTool.exe' -Filter 'Rockchip flasher (*.exe)|*.exe'
        if (-not $flasher) { return }
        $null = New-Item -ItemType Directory -Force $ToolsDir
        Set-Content -Path $settings -Value $flasher -Encoding UTF8
    }
    $sig = Get-AuthenticodeSignature $flasher
    if ($sig.Status -ne 'Valid') { Write-L7Warn "Flasher is not validly signed ($($sig.Status)). Only run tools you trust." }

    Write-L7Section 'In the flasher window'
    Write-L7Info 'RKBatchTool: load update.img in "Firmware" -> click Upgrade.'
    Write-L7Info 'RKDevTool  : "Upgrade Firmware" tab -> Firmware -> pick update.img -> Upgrade.'
    Write-L7Info 'Do NOT unplug until it says Finished. The tablet may reboot mid-way; keep it connected.'
    if ($DryRun) { Write-L7Info "[dry run] Would launch $flasher"; return }
    if (Read-L7YesNo "Launch $(Split-Path -Leaf $flasher) now?" -DefaultYes) {
        Start-Process -FilePath $flasher -WorkingDirectory (Split-Path $flasher)
    }
}

function Invoke-L7AndroidWizard {
    param([Parameter(Mandatory)][string]$ToolsDir, [switch]$DryRun)
    while ($true) {
        $choice = Read-L7Menu -Title 'Android HP Slate 7 - flash & recover' -Items @(
            @{ Key = 'devices';    Label = 'Show connected devices';            Hint = 'adb + fastboot' }
            @{ Key = 'recovery';   Label = 'Reboot to recovery';                Hint = 'needs a booting Android with USB debugging' }
            @{ Key = 'bootloader'; Label = 'Reboot to bootloader / fastboot' }
            @{ Key = 'sideload';   Label = 'Sideload an OTA / ROM zip';         Hint = 'recovery -> "Apply update from ADB"' }
            @{ Key = 'fbboot';     Label = 'Fastboot: boot an image (temporary)'; Hint = 'safe test, nothing written' }
            @{ Key = 'fbflash';    Label = 'Fastboot: flash a partition';       Hint = 'writes to the tablet' }
            @{ Key = 'rockchip';   Label = 'Rockchip full firmware flash';      Hint = 'Slate 7 2800, loader mode' }
            @{ Key = 'tegra';      Label = 'Tegra 4 (Extreme / Plus) notes' }
        )
        if (-not $choice) { return }

        if ($choice -eq 'rockchip') { Invoke-L7RockchipFlow -ToolsDir $ToolsDir -DryRun:$DryRun; Wait-L7Key; continue }
        if ($choice -eq 'tegra') {
            Write-L7Section 'Tegra 4 notes'
            Write-L7Info 'APX mode: tablet off, hold Vol- + Power while plugged in (NVIDIA VID 0955).'
            Write-L7Info 'Unbricking from APX needs NVIDIA nvflash plus device-specific bootloader blobs and'
            Write-L7Info 'SBK keys, which HP never published. If fastboot or recovery still works, use those.'
            Wait-L7Key; continue
        }

        $pt = Get-L7PlatformTools -ToolsDir $ToolsDir
        if (-not $pt) { Write-L7Warn 'adb/fastboot unavailable.'; Wait-L7Key; continue }
        $adb = Join-Path $pt 'adb.exe'
        $fastboot = Join-Path $pt 'fastboot.exe'

        switch ($choice) {
            'devices' {
                Invoke-L7Tool $adb @('devices', '-l') | Out-Null
                Invoke-L7Tool $fastboot @('devices') | Out-Null
            }
            'recovery'   { Invoke-L7Tool $adb @('reboot', 'recovery') -DryRun:$DryRun | Out-Null }
            'bootloader' { Invoke-L7Tool $adb @('reboot', 'bootloader') -DryRun:$DryRun | Out-Null }
            'sideload' {
                Write-L7Info 'On the tablet: recovery -> "Apply update from ADB", then continue.'
                $zip = Select-L7File -Title 'Select OTA / ROM zip' -Filter 'Update zip (*.zip)|*.zip'
                if ($zip -and (Confirm-L7Danger -What "Sideload $(Split-Path -Leaf $zip) onto the tablet." -Phrase 'FLASH')) {
                    Write-L7Info "SHA256: $((Get-FileHash -Algorithm SHA256 $zip).Hash)"
                    Invoke-L7Tool $adb @('sideload', $zip) -DryRun:$DryRun | Out-Null
                }
            }
            'fbboot' {
                $img = Select-L7File -Title 'Select boot/recovery image' -Filter 'Image (*.img)|*.img'
                if ($img) { Invoke-L7Tool $fastboot @('boot', $img) -DryRun:$DryRun | Out-Null }
            }
            'fbflash' {
                $part = Read-L7Menu -Title 'Which partition?' -Items @(
                    @{ Key = 'recovery'; Label = 'recovery'; Hint = 'safest - Android itself is untouched' }
                    @{ Key = 'boot';     Label = 'boot' }
                    @{ Key = 'system';   Label = 'system' }
                )
                if (-not $part) { continue }
                $img = Select-L7File -Title "Select $part image" -Filter 'Image (*.img)|*.img'
                if ($img -and (Confirm-L7Danger -What "Overwrite the tablet's '$part' partition with $(Split-Path -Leaf $img)." -Phrase 'FLASH')) {
                    Write-L7Info "SHA256: $((Get-FileHash -Algorithm SHA256 $img).Hash)"
                    Invoke-L7Tool $fastboot @('flash', $part, $img) -DryRun:$DryRun | Out-Null
                }
            }
        }
        Wait-L7Key
    }
}

Export-ModuleMember -Function Invoke-L7Tool, Invoke-L7RockchipFlow, Invoke-L7AndroidWizard
