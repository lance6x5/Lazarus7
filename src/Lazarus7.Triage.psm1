# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Triage: turns "what does the tablet do?" answers into a recommended next step.
# The questions and answers live in docs/triage.json, which the website reads
# too, so the desktop wizard and the browser wizard can never drift apart.

$script:TriagePath = Join-Path (Split-Path $PSScriptRoot) 'docs\triage.json'
$script:Triage = [IO.File]::ReadAllText($script:TriagePath, [Text.Encoding]::UTF8) | ConvertFrom-Json

function ConvertTo-L7Recommendation {
    param($Node)
    @{ Title = $Node.title; Steps = @($Node.steps); Action = $Node.action }
}

<#
  Pure function. Platform: 'Windows' (HP Stream 7) | 'Android' (Slate 7) | 'Unknown'
  Symptom: one of the keys in Get-L7Symptoms.
  Returns @{ Title; Steps = string[]; Action = main-menu key or $null }
#>
function Get-L7TriageRecommendation {
    param(
        [Parameter(Mandatory)][ValidateSet('Windows', 'Android', 'Unknown')][string]$Platform,
        [Parameter(Mandatory)][string]$Symptom
    )
    $t = $script:Triage
    if ($Platform -eq 'Unknown') { return ConvertTo-L7Recommendation $t.unknown }
    if ($t.common.$Symptom) { return ConvertTo-L7Recommendation $t.common.$Symptom }
    $specific = $t.byPlatform.$Platform.$Symptom
    if ($specific) { return ConvertTo-L7Recommendation $specific }
    return ConvertTo-L7Recommendation $t.fallback
}

function Get-L7Symptoms {
    param([ValidateSet('Windows', 'Android')][string]$Platform = 'Windows')
    $script:Triage.symptoms.$Platform | ForEach-Object { @{ Key = $_.key; Label = $_.label } }
}

function Get-L7TriagePlatforms {
    $script:Triage.platforms | ForEach-Object { @{ Key = $_.key; Label = $_.label; Hint = $_.hint } }
}

function Invoke-L7TriageWizard {
    $platform = Read-L7Menu -Title 'Diagnose: which tablet is it?' -Items @(Get-L7TriagePlatforms)
    if (-not $platform) { return $null }

    $symptom = 'dead'
    if ($platform -ne 'Unknown') {
        $symptom = Read-L7Menu -Title 'What happens when you press Power (after charging)?' -Items @(Get-L7Symptoms -Platform $platform)
        if (-not $symptom) { return $null }
    }

    $rec = Get-L7TriageRecommendation -Platform $platform -Symptom $symptom
    Write-L7Section "Recommendation: $($rec.Title)"
    $i = 1
    foreach ($s in $rec.Steps) {
        if ($s.StartsWith('  ')) { Write-Host ("      {0}" -f $s.Trim()) -ForegroundColor White }
        else { Write-Host ("   {0}. {1}" -f $i++, $s) -ForegroundColor White }
    }
    if ($rec.Action -and (Read-L7YesNo "`n  Go to the matching tool now?" -DefaultYes)) { return $rec.Action }
    Wait-L7Key
    return $null
}

Export-ModuleMember -Function Get-L7TriageRecommendation, Get-L7Symptoms, Get-L7TriagePlatforms, Invoke-L7TriageWizard
