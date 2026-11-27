# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Triage: turns "what does the tablet do?" answers into a recommended next step.

<#
  Pure function. Platform: 'Windows' | 'Android' | 'Unknown'
  Symptom: one of the keys in Get-L7Symptoms.
  Returns @{ Title; Steps = string[]; Action = main-menu key or $null }
#>
function Get-L7TriageRecommendation {
    param(
        [Parameter(Mandatory)][ValidateSet('Windows', 'Android', 'Unknown')][string]$Platform,
        [Parameter(Mandatory)][string]$Symptom
    )

    if ($Platform -eq 'Unknown') {
        return @{
            Title  = 'Identify the tablet first'
            Steps  = @('Check the back label: "TSW 7H" means HP Stream 7 (Windows).',
                       'Run "Identify my tablet" with the tablet plugged into this PC.')
            Action = 'detect'
        }
    }

    switch ($Symptom) {
        'dead' {
            return @{
                Title  = 'Revive the battery'
                Steps  = @('Charge with a 2 A wall charger + short cable for 4+ hours (not a PC port).',
                           'Hold Power 15-30 s (hard reset), release, then hold Power 5 s.',
                           'Try a second charger and cable before giving up.',
                           'Never any battery icon = dead battery or board; a battery swap is the fix.')
                Action = 'firstaid'
            }
        }
        'password' {
            return @{
                Title  = 'BIOS / power-on password'
                Steps  = @('Enter a wrong password 3 times to get a halt code.',
                           'HP Support can turn the halt code + serial number into an unlock code.',
                           'There is no safe software bypass for this.')
                Action = $null
            }
        }
        'bitlocker' {
            return @{
                Title  = 'BitLocker recovery screen'
                Steps  = @('Get the key at https://account.microsoft.com/devices/recoverykey',
                           'No key? Data is unrecoverable, but you can reinstall (Windows or Linux).')
                Action = 'winusb'
            }
        }
    }

    if ($Platform -eq 'Windows') {
        switch ($Symptom) {
            'logo' {
                return @{
                    Title  = 'Stuck at HP logo / boot loop'
                    Steps  = @('Vol- + Power -> F2: run the storage (eMMC) test first.',
                               'Vol- + Power -> F11: HP System Recovery, if the partition survived.',
                               'Otherwise build a recovery USB (Windows) or deploy Linux.')
                    Action = 'winusb'
                }
            }
            'noboot' {
                return @{
                    Title  = '"No bootable device"'
                    Steps  = @('The OS is gone or the UEFI forgot its boot entry.',
                               'If you had Linux: a USB with BOOTIA32.EFI or re-running the Lazarus7',
                               'post-install script fixes it. Otherwise reinstall from USB.')
                    Action = 'linux'
                }
            }
            'boots' {
                return @{
                    Title  = 'It boots - ready for a new OS'
                    Steps  = @('Turn off Fast Startup in Windows, then deploy Linux from USB.',
                               'Optional: make an HP recovery USB first so you can go back.')
                    Action = 'linux'
                }
            }
        }
    }

    if ($Platform -eq 'Android') {
        switch ($Symptom) {
            'logo' {
                return @{
                    Title  = 'Android boot loop'
                    Steps  = @('Try stock recovery: Power + Vol+ (on the 2800 sometimes Vol+ AND Vol-).',
                               'Wipe data/factory reset, or "apply update from ADB" with an HP OTA zip.',
                               'No recovery? Rockchip loader mode + RKDevTool full flash.')
                    Action = 'android'
                }
            }
            'noboot' {
                return @{
                    Title  = 'Black screen but USB responds'
                    Steps  = @('Plug into this PC and run "Identify my tablet".',
                               'Rockchip VID 2207 = loader mode: full firmware flash is possible.')
                    Action = 'android'
                }
            }
            'boots' {
                return @{
                    Title  = 'It boots Android'
                    Steps  = @('Enable USB debugging, then use ADB tools to reboot to recovery/bootloader.')
                    Action = 'android'
                }
            }
        }
    }

    return @{ Title = 'No specific recommendation'; Steps = @('See docs/GUIDE.md.'); Action = 'guide' }
}

function Get-L7Symptoms {
    @(
        @{ Key = 'dead';      Label = 'Completely dead, no charging icon' }
        @{ Key = 'logo';      Label = 'Shows HP logo, then black screen / boot loop' }
        @{ Key = 'password';  Label = 'Asks for a password before the logo' }
        @{ Key = 'bitlocker'; Label = 'Blue BitLocker recovery-key screen' }
        @{ Key = 'noboot';    Label = '"No bootable device" / black screen' }
        @{ Key = 'boots';     Label = 'It actually boots - I just want a new OS' }
    )
}

function Invoke-L7TriageWizard {
    $platform = Read-L7Menu -Title 'Diagnose: what did it originally run?' -Items @(
        @{ Key = 'Windows'; Label = 'Windows 8.1 / 10';  Hint = 'HP Stream 7, label TSW 7H' }
        @{ Key = 'Android'; Label = 'Android';           Hint = 'HP Slate 7 family' }
        @{ Key = 'Unknown'; Label = "I'm not sure" }
    )
    if (-not $platform) { return $null }

    $symptom = 'dead'
    if ($platform -ne 'Unknown') {
        $symptom = Read-L7Menu -Title 'What happens when you press Power (after charging)?' -Items (Get-L7Symptoms)
        if (-not $symptom) { return $null }
    }

    $rec = Get-L7TriageRecommendation -Platform $platform -Symptom $symptom
    Write-L7Section "Recommendation: $($rec.Title)"
    $i = 1
    foreach ($s in $rec.Steps) { Write-Host ("   {0}. {1}" -f $i++, $s) -ForegroundColor White }
    if ($rec.Action -and (Read-L7YesNo "`n  Go to the matching tool now?" -DefaultYes)) { return $rec.Action }
    Wait-L7Key
    return $null
}

Export-ModuleMember -Function Get-L7TriageRecommendation, Get-L7Symptoms, Invoke-L7TriageWizard
