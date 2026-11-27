# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Pester tests (compatible with the Pester 3.4 that ships with Windows).
#   Invoke-Pester .\tests

$src = Join-Path (Split-Path $PSScriptRoot) 'src'
foreach ($m in 'Ui', 'Detect', 'Triage', 'Download', 'Usb', 'Android', 'Feedback') {
    Import-Module (Join-Path $src "Lazarus7.$m.psm1") -Force -DisableNameChecking
}

Describe 'Banner' {
    It 'renders five rows of equal width' {
        $lines = @(Get-Lazarus7BannerLines)
        $lines.Count | Should Be 5
        ($lines | ForEach-Object Length | Sort-Object -Unique).Count | Should Be 1
    }
}

Describe 'Versioning' {
    $repoRoot = Split-Path $PSScriptRoot
    It 'has a CHANGELOG entry for the current version at the top' {
        $md = [IO.File]::ReadAllText((Join-Path $repoRoot 'CHANGELOG.md'))
        $top = [regex]::Match($md, '(?m)^## \[([^\]]+)\]').Groups[1].Value
        $top | Should Be (Get-Lazarus7Version)
    }
    It 'shows the same version as the fallback on the website' {
        $html = [IO.File]::ReadAllText((Join-Path $repoRoot 'docs\index.html'))
        $html -match ('data-version="' + [regex]::Escape((Get-Lazarus7Version)) + '"') | Should Be $true
    }
}

Describe 'ConvertTo-L7TabletDevice' {
    It 'recognises a Rockchip loader' {
        $d = ConvertTo-L7TabletDevice -InstanceId 'USB\VID_2207&PID_300A\5&1' -FriendlyName 'Unknown' -Status 'Error'
        $d.Family | Should Be 'Rockchip'
        $d.NeedsDriver | Should Be $true
    }
    It 'ignores HP docks and hubs (shared VID 03F0)' {
        ConvertTo-L7TabletDevice -InstanceId 'USB\VID_03F0&PID_036B\1' -FriendlyName 'Generic USB Hub' -Status 'OK' | Should BeNullOrEmpty
    }
    It 'matches an ADB interface by name from any vendor' {
        $d = ConvertTo-L7TabletDevice -InstanceId 'USB\VID_03F0&PID_5A1D&MI_01\1' -FriendlyName 'Android Composite ADB Interface' -Status 'OK'
        $d.Family | Should Be 'Android'
        $d.NeedsDriver | Should Be $false
    }
    It 'ignores non-USB instance ids' {
        ConvertTo-L7TabletDevice -InstanceId 'ACPI\PNP0C0A\1' -FriendlyName 'Battery' -Status 'OK' | Should BeNullOrEmpty
    }
}

Describe 'Get-L7TriageRecommendation' {
    It 'sends unknown tablets to detection' {
        (Get-L7TriageRecommendation -Platform Unknown -Symptom dead).Action | Should Be 'detect'
    }
    It 'sends a dead tablet to first aid on any platform' {
        (Get-L7TriageRecommendation -Platform Windows -Symptom dead).Action | Should Be 'firstaid'
        (Get-L7TriageRecommendation -Platform Android -Symptom dead).Action | Should Be 'firstaid'
    }
    It 'routes a Stream 7 boot loop to the Windows USB builder' {
        (Get-L7TriageRecommendation -Platform Windows -Symptom logo).Action | Should Be 'winusb'
    }
    It 'routes Android problems to the Android tools' {
        (Get-L7TriageRecommendation -Platform Android -Symptom logo).Action | Should Be 'android'
    }
    It 'has a recommendation for every symptom on every platform' {
        foreach ($p in 'Windows', 'Android') {
            foreach ($s in Get-L7Symptoms -Platform $p) {
                $r = Get-L7TriageRecommendation -Platform $p -Symptom $s.Key
                $r.Title | Should Not Be 'No specific recommendation'
            }
        }
    }
    It 'sends a Windows 8.1 Automatic Repair loop to the recovery USB' {
        (Get-L7TriageRecommendation -Platform Windows -Symptom repair).Action | Should Be 'winusb'
    }
    It 'sends a working Stream 7 to the backup toolkit first, not straight to Linux' {
        (Get-L7TriageRecommendation -Platform Windows -Symptom boots).Action | Should Be 'toolkit'
    }
    It 'only offers Windows-specific symptoms for the Stream 7' {
        $android = (Get-L7Symptoms -Platform Android) | ForEach-Object { $_.Key }
        $android -contains 'repair' | Should Be $false
        $android -contains 'winpass' | Should Be $false
        ((Get-L7Symptoms -Platform Windows) | ForEach-Object { $_.Key }) -contains 'repair' | Should Be $true
    }
    It 'only recommends actions the main menu can handle' {
        $main = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) 'Lazarus7.ps1'))
        $handled = [regex]::Matches($main, "(?m)^\s*'(\w+)'\s*\{") | ForEach-Object { $_.Groups[1].Value }
        foreach ($p in 'Windows', 'Android') {
            foreach ($s in Get-L7Symptoms -Platform $p) {
                $a = (Get-L7TriageRecommendation -Platform $p -Symptom $s.Key).Action
                if ($a) { $handled -contains $a | Should Be $true }
            }
        }
    }
}

Describe 'Slate 7 button combos (docs/keycombos.json)' {
    $data = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) 'docs\keycombos.json')) | ConvertFrom-Json
    $labels = @($data.confidenceLabels.PSObject.Properties.Name)

    It 'is ASCII so PowerShell 5.1 and the browser read it the same' {
        $bytes = [IO.File]::ReadAllBytes((Join-Path (Split-Path $PSScriptRoot) 'docs\keycombos.json'))
        @($bytes | Where-Object { $_ -gt 127 }).Count | Should Be 0
    }
    It 'gives every model a unique key and a recovery combo' {
        $keys = @($data.models | ForEach-Object key)
        ($keys | Sort-Object -Unique).Count | Should Be $keys.Count
        foreach ($m in $data.models) {
            @($m.combos | Where-Object { $_.action -match 'Recovery' }).Count -ge 1 | Should Be $true
        }
    }
    It 'labels every combo with a known confidence level and real keys' {
        foreach ($c in @($data.models | ForEach-Object { $_.combos }) + @($data.common)) {
            $labels -contains $c.confidence | Should Be $true
            [string]::IsNullOrWhiteSpace($c.keys) | Should Be $false
        }
    }
    It 'is what the desktop module serves' {
        @(Get-L7KeyComboModels).Count | Should Be @($data.models).Count
        @(Get-L7CommonKeyCombos).Count | Should Be @($data.common).Count
    }
}

Describe 'Feedback and official links' {
    $root = Split-Path $PSScriptRoot
    It 'builds a pre-filled issue URL for each form, with encoded values' {
        $u = Get-L7IssueUrl -Kind bug -Fields @{ version = 'v1.6.0'; pc_os = 'Windows 11 & more' }
        $u | Should Be 'https://github.com/lance6x5/Lazarus7/issues/new?template=bug_report.yml&pc_os=Windows%2011%20%26%20more&version=v1.6.0'
        Get-L7IssueUrl -Kind device | Should Be 'https://github.com/lance6x5/Lazarus7/issues/new?template=device_report.yml'
    }
    It 'points every form at a template that exists, and pre-fills only fields that exist in it' {
        foreach ($kind in 'bug', 'feature', 'device') {
            $url = Get-L7IssueUrl -Kind $kind -Fields @{ version = 'v1' }
            $tpl = [regex]::Match($url, 'template=([^&]+)').Groups[1].Value
            $yml = Join-Path $root ".github\ISSUE_TEMPLATE\$tpl"
            Test-Path $yml | Should Be $true
            [IO.File]::ReadAllText($yml) -match '(?m)^\s*id:\s*version\s*$' | Should Be $true
        }
        [IO.File]::ReadAllText((Join-Path $root '.github\ISSUE_TEMPLATE\bug_report.yml')) -match '(?m)^\s*id:\s*pc_os\s*$' | Should Be $true
    }
    It 'only links to official HP, Microsoft and Debian sites' {
        foreach ($l in Get-L7OfficialLinks) {
            $l.Url -match '^https://([a-z0-9-]+\.)*(hp\.com|microsoft\.com|debian\.org)/' | Should Be $true
        }
    }
    It 'wires the report action into the main menu' {
        [IO.File]::ReadAllText((Join-Path $root 'Lazarus7.ps1')) -match "'report'\s*\{\s*Invoke-L7FeedbackWizard" | Should Be $true
    }
}

Describe 'Other operating systems' {
    $root = Split-Path $PSScriptRoot
    It 'pins Android-x86 to two independent, well-formed checksums and HTTPS SourceForge mirrors' {
        $a = Get-L7AndroidX86Release
        $a.FileName | Should Be 'android-x86-9.0-r2.iso'
        $a.Sha1 -match '^[0-9a-f]{40}$' | Should Be $true
        $a.Md5 -match '^[0-9a-f]{32}$' | Should Be $true
        foreach ($u in $a.Urls) { $u -match '^https://[a-z.]*sourceforge\.net/project/android-x86/' | Should Be $true }
    }
    It 'rejects a missing or wrong Android-x86 image' {
        Test-L7AndroidX86Iso -Path (Join-Path $TestDrive 'nope.iso') | Should Be $false
        $fake = Join-Path $TestDrive 'android-x86-9.0-r2.iso'
        Set-Content $fake 'not really an ISO'
        Test-L7AndroidX86Iso -Path $fake | Should Be $false
    }
    It 'offers Kodi and Android-x86 in the Deploy menu' {
        $main = [IO.File]::ReadAllText((Join-Path $root 'Lazarus7.ps1'))
        $main -match "Key = 'kodi'" | Should Be $true
        $main -match "Key = 'android'; Label = 'Android-x86" | Should Be $true
    }
    It 'ships the Kodi media-center script with strict mode and validated rotation' {
        $sh = Join-Path $root 'payload\linux\stream7-media-center.sh'
        Test-Path $sh | Should Be $true
        $text = [IO.File]::ReadAllText($sh)
        $text -match '(?m)^set -eu$' | Should Be $true
        $text -match 'normal\|left\|right\|inverted' | Should Be $true
        $text -match 'kodi-standalone' | Should Be $true
        @([IO.File]::ReadAllBytes($sh) | Where-Object { $_ -gt 127 }).Count | Should Be 0
    }
}

Describe 'Tablet payload' {
    $payload = Join-Path (Split-Path $PSScriptRoot) 'payload'
    It 'ships the Windows helper and the Linux post-install script' {
        Test-Path (Join-Path $payload 'windows\Stream7-Check.cmd') | Should Be $true
        Test-Path (Join-Path $payload 'windows\Stream7-Check.ps1') | Should Be $true
        Test-Path (Join-Path $payload 'windows\Stream7-Repair.cmd') | Should Be $true
        Test-Path (Join-Path $payload 'linux\stream7-debian-postinstall.sh') | Should Be $true
    }
    It 'keeps the WinPE repair helper ASCII and its only write step behind the REPAIR prompt' {
        $file = Join-Path $payload 'windows\Stream7-Repair.cmd'
        @([IO.File]::ReadAllBytes($file) | Where-Object { $_ -gt 127 }).Count | Should Be 0
        $lines = Get-Content $file
        $bcd = @($lines | Select-String -Pattern '^\s*bcdboot ')
        $bcd.Count | Should Be 1
        $gate = @($lines | Select-String -Pattern 'if not "!ANS!"=="REPAIR"')
        $gate.Count | Should Be 1
        $gate[0].LineNumber -lt $bcd[0].LineNumber | Should Be $true
        # WinPE has no PowerShell
        ($lines -join "`n") -match '(?im)^\s*powershell' | Should Be $false
    }
    It 'keeps the tablet helper parseable and free of PowerShell 5-only syntax (Windows 8.1 has 4.0)' {
        $file = Join-Path $payload 'windows\Stream7-Check.ps1'
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$errors)
        @($errors).Count | Should Be 0
        $code = (Get-Content $file | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $code -match '::new\(|(?m)^\s*class\s|-AsHashtable|using namespace' | Should Be $false
    }
}

Describe 'Debian release parsing' {
    $sums = @"
71506f6fa501d4ad50d0835666f5102e9c9b090123ca2668b995a911009c0a69  debian-12.15.0-i386-netinst.iso
d588973497974b3991e2e1f5c444c0aec7075de295e4fc567a4b17a277a95c80  debian-edu-12.15.0-i386-netinst.iso
06d77bf7221a9bca43a3dfa1a271dcd46276a643db3063baa240d84e92273f31  debian-mac-12.15.0-i386-netinst.iso
"@
    It 'picks the plain netinst, not edu/mac variants' {
        $e = Find-L7NetinstChecksum -Sha256Sums $sums -Arch i386
        $e.FileName | Should Be 'debian-12.15.0-i386-netinst.iso'
        $e.Sha256 | Should Be '71506f6fa501d4ad50d0835666f5102e9c9b090123ca2668b995a911009c0a69'
    }
    It 'returns nothing for an arch that is not listed' {
        Find-L7NetinstChecksum -Sha256Sums $sums -Arch amd64 | Should BeNullOrEmpty
    }
    It 'chooses the newest point release numerically (12.15 > 12.9)' {
        $hrefs = @('../', '11.9.0/', '12.9.0/', '12.10.0/', '12.15.0/', '12.15.0/', '13.1.0/')
        (Select-L7LatestPointRelease -Hrefs $hrefs -Major 12).ToString() | Should Be '12.15.0'
    }
}

Describe 'Recovery backup manifest' {
    $src = Join-Path $TestDrive 'stick'
    New-Item -ItemType Directory -Force (Join-Path $src 'EFI\BOOT'), (Join-Path $src 'sources'), (Join-Path $src 'System Volume Information') | Out-Null
    Set-Content (Join-Path $src 'EFI\BOOT\BOOTIA32.EFI') 'loader'
    Set-Content (Join-Path $src 'sources\install.wim') 'pretend this is 3.8 GB'
    Set-Content (Join-Path $src 'System Volume Information\IndexerVolumeGuid') 'noise'
    $m = New-L7FileManifest -Root $src -Label 'RECOVERY'

    It 'lists real files and skips Windows housekeeping folders' {
        $m.FileCount | Should Be 2
        ($m.Files | ForEach-Object Path) -contains 'sources\install.wim' | Should Be $true
        @($m.Files | Where-Object { $_.Path -like 'System Volume Information*' }).Count | Should Be 0
        $m.Label | Should Be 'RECOVERY'
    }
    It 'passes an identical copy' {
        $copy = Join-Path $TestDrive 'copy'
        Copy-Item -Recurse $src $copy
        @(Test-L7FileManifest -Root $copy -Manifest $m).Count | Should Be 0
    }
    It 'survives a JSON round trip (how backups are stored)' {
        $back = $m | ConvertTo-Json -Depth 4 | ConvertFrom-Json
        @(Test-L7FileManifest -Root $src -Manifest $back).Count | Should Be 0
    }
    It 'catches changed, truncated and missing files' {
        $bad = Join-Path $TestDrive 'bad'
        Copy-Item -Recurse $src $bad
        Set-Content (Join-Path $bad 'sources\install.wim') 'pretend this is 3.8 GB!'
        Remove-Item (Join-Path $bad 'EFI\BOOT\BOOTIA32.EFI')
        $problems = Test-L7FileManifest -Root $bad -Manifest $m
        @($problems).Count | Should Be 2
        ($problems -join ' ') -match 'missing: EFI\\BOOT\\BOOTIA32.EFI' | Should Be $true
        ($problems -join ' ') -match 'install.wim' | Should Be $true
    }
    It 'catches a same-size corruption (hash, not just size)' {
        $flip = Join-Path $TestDrive 'flip'
        Copy-Item -Recurse $src $flip
        Set-Content (Join-Path $flip 'sources\install.wim') 'PRETEND this is 3.8 GB'
        ((Test-L7FileManifest -Root $flip -Manifest $m) -join ' ') -match 'content differs' | Should Be $true
    }
}

Describe 'USB source checks' {
    $root = Join-Path $TestDrive 'iso'
    New-Item -ItemType Directory -Force (Join-Path $root 'EFI\BOOT') | Out-Null

    It 'reports media without BOOTIA32.EFI as unbootable' {
        Test-L7Ia32Boot $root | Should Be $false
    }
    It 'reports media with BOOTIA32.EFI as bootable' {
        Set-Content (Join-Path $root 'EFI\BOOT\BOOTIA32.EFI') 'x'
        Test-L7Ia32Boot $root | Should Be $true
    }
    It 'finds no oversized files in a small tree' {
        @(Get-L7OversizedFile $root).Count | Should Be 0
    }
}
