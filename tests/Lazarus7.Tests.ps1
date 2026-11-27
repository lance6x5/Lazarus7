# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Pester tests (compatible with the Pester 3.4 that ships with Windows).
#   Invoke-Pester .\tests

$src = Join-Path (Split-Path $PSScriptRoot) 'src'
foreach ($m in 'Ui', 'Detect', 'Triage', 'Download', 'Usb', 'Android') {
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
    It 'routes a working Stream 7 to Linux deployment' {
        (Get-L7TriageRecommendation -Platform Windows -Symptom boots).Action | Should Be 'linux'
    }
    It 'routes Android problems to the Android tools' {
        (Get-L7TriageRecommendation -Platform Android -Symptom logo).Action | Should Be 'android'
    }
    It 'has a recommendation for every symptom on every platform' {
        foreach ($p in 'Windows', 'Android') {
            foreach ($s in Get-L7Symptoms) {
                $r = Get-L7TriageRecommendation -Platform $p -Symptom $s.Key
                $r.Title | Should Not Be 'No specific recommendation'
            }
        }
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
