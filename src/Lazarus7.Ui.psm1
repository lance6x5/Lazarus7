# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Console UI: banner, menus, prompts, file pickers. Plain ASCII on purpose so it
# renders correctly in the stock Windows PowerShell 5.1 console.

$script:Lazarus7Version = '1.6.0'

# figlet "standard"-style glyphs, rendered by Show-Lazarus7Banner so that the
# columns always line up.
$script:Glyphs = @{
    'L' = @(' _     ', '| |    ', '| |    ', '| |___ ', '|_____|')
    'A' = @('    _    ', '   / \   ', '  / _ \  ', ' / ___ \ ', '/_/   \_\')
    'Z' = @(' _____', '|__  /', '  / / ', ' / /_ ', '/____|')
    'R' = @(' ____  ', '|  _ \ ', '| |_) |', '|  _ < ', '|_| \_\')
    'U' = @(' _   _ ', '| | | |', '| | | |', '| |_| |', ' \___/ ')
    'S' = @(' ____  ', '/ ___| ', '\___ \ ', ' ___) |', '|____/ ')
    '7' = @(' _____ ', '|___  |', '   / / ', '  / /  ', ' /_/   ')
}

# Phoenix palette: embers at the top, white-hot at the bottom.
$script:FireColors = @('DarkRed', 'Red', 'DarkYellow', 'Yellow', 'White')

function Get-Lazarus7Version { $script:Lazarus7Version }

function Get-Lazarus7BannerLines {
    param([string]$Text = 'LAZARUS7')
    for ($row = 0; $row -lt 5; $row++) {
        ($Text.ToCharArray() | ForEach-Object { $script:Glyphs[[string]$_][$row] }) -join ' '
    }
}

function Show-Lazarus7Banner {
    param([switch]$DryRun)
    Clear-Host
    $lines = @(Get-Lazarus7BannerLines)
    Write-Host ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        Write-Host ('  ' + $lines[$i]) -ForegroundColor $script:FireColors[$i]
    }
    Write-Host ''
    Write-Host '  Raise your 7-inch HP tablet from the dead.' -ForegroundColor Gray -NoNewline
    Write-Host ("   v$script:Lazarus7Version") -ForegroundColor DarkGray
    Write-Host '  Built for the HP Stream 7 (TSW 7H, Windows 8.1)  |  + Android Slate 7' -ForegroundColor DarkGray
    if ($DryRun) {
        Write-Host '  [DRY RUN] No disks will be erased and nothing will be flashed.' -ForegroundColor Cyan
    }
    Write-Host ('  ' + ('-' * 62)) -ForegroundColor DarkGray
}

function Write-L7Step   { param([string]$Text) Write-Host "  >> $Text" -ForegroundColor Cyan }
function Write-L7Ok     { param([string]$Text) Write-Host "  [ok] $Text" -ForegroundColor Green }
function Write-L7Warn   { param([string]$Text) Write-Host "  [!] $Text" -ForegroundColor Yellow }
function Write-L7Fail   { param([string]$Text) Write-Host "  [x] $Text" -ForegroundColor Red }
function Write-L7Info   { param([string]$Text) Write-Host "      $Text" -ForegroundColor Gray }

function Write-L7Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "  == $Title ==" -ForegroundColor Yellow
    Write-Host ''
}

function Wait-L7Key {
    Write-Host ''
    Write-Host '  Press Enter to continue...' -ForegroundColor DarkGray -NoNewline
    [void](Read-Host)
}

<#
  Shows a numbered menu and returns the Key of the chosen item.
  Items: array of @{ Key = 'x'; Label = '...'; Hint = '...' }
#>
function Read-L7Menu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Items,
        [string]$BackLabel = 'Back'
    )
    Write-L7Section $Title
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ("   [{0}] " -f ($i + 1)) -ForegroundColor Yellow -NoNewline
        Write-Host $Items[$i].Label -ForegroundColor White -NoNewline
        if ($Items[$i].Hint) { Write-Host ("  - " + $Items[$i].Hint) -ForegroundColor DarkGray } else { Write-Host '' }
    }
    Write-Host '   [0] ' -ForegroundColor Yellow -NoNewline
    Write-Host $BackLabel -ForegroundColor Gray
    while ($true) {
        $answer = (Read-Host "`n  Choose").Trim()
        if ($answer -eq '0' -or $answer -ieq 'q') { return $null }
        $n = 0
        if ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) {
            return $Items[$n - 1].Key
        }
        Write-L7Warn "Enter a number from 0 to $($Items.Count)."
    }
}

function Read-L7YesNo {
    param([string]$Question, [switch]$DefaultYes)
    $suffix = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $a = (Read-Host "  $Question $suffix").Trim()
    if (-not $a) { return [bool]$DefaultYes }
    return $a -match '^(y|yes)$'
}

<#
  Makes the user type an exact phrase before anything destructive happens.
#>
function Confirm-L7Danger {
    param([Parameter(Mandatory)][string]$What, [Parameter(Mandatory)][string]$Phrase)
    Write-Host ''
    Write-Host "  !!! $What" -ForegroundColor Red
    Write-Host "  Type " -ForegroundColor Red -NoNewline
    Write-Host $Phrase -ForegroundColor White -NoNewline
    Write-Host " to continue, anything else to cancel." -ForegroundColor Red
    return ((Read-Host '  ').Trim() -ceq $Phrase)
}

function Select-L7File {
    param([string]$Title = 'Select a file', [string]$Filter = 'All files (*.*)|*.*')
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = $Title
        $dlg.Filter = $Filter
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
        return $null
    } catch {
        $p = (Read-Host "  $Title (full path)").Trim('" ')
        if ($p) { return $p } else { return $null }
    }
}

function Select-L7Folder {
    param([string]$Title = 'Select a folder')
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = $Title
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
        return $null
    } catch {
        $p = (Read-Host "  $Title (full path)").Trim('" ')
        if ($p) { return $p } else { return $null }
    }
}

Export-ModuleMember -Function *-Lazarus7*, *-L7*
