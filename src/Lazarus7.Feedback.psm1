# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Feedback: opens pre-filled GitHub issue forms (.github/ISSUE_TEMPLATE/*.yml),
# and the list of official download / support links.

$script:Repo = 'lance6x5/Lazarus7'
$script:Templates = @{ bug = 'bug_report.yml'; feature = 'feature_request.yml'; device = 'device_report.yml' }

# Official sources only. Lazarus7 does not link to copies of HP or Microsoft images.
$script:OfficialLinks = @(
    @{ Key = 'hpcontact'; Label = 'HP Support - contact (ask for Stream 7 recovery media)'; Url = 'https://support.hp.com/us-en/contact' }
    @{ Key = 'hpdrivers'; Label = 'HP Stream 7 Tablet 5701 - drivers and software';         Url = 'https://support.hp.com/us-en/drivers/selfservice/hp-stream-tablets/7439994/model/7482041' }
    @{ Key = 'win10';     Label = 'Microsoft - Windows 10 download (choose 32-bit / x86)';  Url = 'https://www.microsoft.com/en-us/software-download/windows10' }
    @{ Key = 'debian';    Label = 'Debian 12 i386 images (Lazarus7 downloads these itself)'; Url = 'https://cdimage.debian.org/cdimage/archive/' }
    @{ Key = 'hpcloud';   Label = 'HP Cloud Recovery supported list (no Stream 7 on it)';  Url = 'https://ftp.hp.com/pub/caps-softpaq/CloudRecovery/crsupportedplatform.html' }
)

function Get-L7OfficialLinks { $script:OfficialLinks }

<#
  Pure function: builds a GitHub "new issue" URL for one of the issue forms,
  pre-filling form fields by id (only input/textarea fields are pre-filled).
#>
function Get-L7IssueUrl {
    param(
        [Parameter(Mandatory)][ValidateSet('bug', 'feature', 'device')][string]$Kind,
        [hashtable]$Fields = @{}
    )
    $query = @('template=' + $script:Templates[$Kind])
    foreach ($k in ($Fields.Keys | Sort-Object)) {
        if ($null -ne $Fields[$k] -and "$($Fields[$k])" -ne '') {
            $query += ([uri]::EscapeDataString($k) + '=' + [uri]::EscapeDataString([string]$Fields[$k]))
        }
    }
    "https://github.com/$script:Repo/issues/new?" + ($query -join '&')
}

function Get-L7PcOsDescription {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        "$($os.Caption) $($os.OSArchitecture) (build $($os.BuildNumber))"
    } catch { [Environment]::OSVersion.VersionString }
}

function Open-L7Url {
    param([Parameter(Mandatory)][string]$Url)
    Write-L7Info $Url
    try { Start-Process $Url } catch { Write-L7Warn 'Could not open a browser - copy the link above.' }
}

function Invoke-L7FeedbackWizard {
    $kind = Read-L7Menu -Title 'Report a problem / request a feature (opens GitHub)' -Items @(
        @{ Key = 'bug';     Label = 'Report a problem';          Hint = 'wrong advice, an error, a crash' }
        @{ Key = 'feature'; Label = 'Request a feature';         Hint = 'new tablet, new OS, a better way to do something' }
        @{ Key = 'device';  Label = 'Tell us what worked';       Hint = 'confirms button combos and fixes for your model' }
    )
    if (-not $kind) { return }
    Write-L7Info 'Needs a free GitHub account. The form opens with your Lazarus7 version filled in.'
    Write-L7Warn 'Do not paste your Windows product key or serial number (the Stream7-Check report has both).'
    $fields = @{ version = 'v' + (Get-Lazarus7Version) }
    if ($kind -eq 'bug') { $fields.pc_os = Get-L7PcOsDescription }
    Open-L7Url (Get-L7IssueUrl -Kind $kind -Fields $fields)
    Wait-L7Key
}

Export-ModuleMember -Function Get-L7OfficialLinks, Get-L7IssueUrl, Get-L7PcOsDescription, Open-L7Url, Invoke-L7FeedbackWizard
