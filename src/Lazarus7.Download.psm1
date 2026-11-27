# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Verified downloads: Debian netinst images (SHA256 from cdimage.debian.org) and
# Android platform-tools (Authenticode signature must be Google LLC).

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$script:DebianArchive = 'https://cdimage.debian.org/cdimage/archive/'
$script:PlatformToolsUrl = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'

function ConvertFrom-L7Bytes {
    param($Content)
    if ($Content -is [byte[]]) { return [Text.Encoding]::ASCII.GetString($Content) }
    return [string]$Content
}

<#
  Pure function: finds the netinst entry in a SHA256SUMS file.
#>
function Find-L7NetinstChecksum {
    param([Parameter(Mandatory)][string]$Sha256Sums, [Parameter(Mandatory)][string]$Arch)
    foreach ($line in $Sha256Sums -split "`r?`n") {
        if ($line -match "^([0-9a-f]{64})\s+\*?(debian-\d+\.\d+\.\d+-$Arch-netinst\.iso)\s*$") {
            return [pscustomobject]@{ Sha256 = $Matches[1]; FileName = $Matches[2] }
        }
    }
    return $null
}

<#
  Pure function: picks the newest "<major>.x.y/" directory from an index listing.
#>
function Select-L7LatestPointRelease {
    param([Parameter(Mandatory)][string[]]$Hrefs, [Parameter(Mandatory)][int]$Major)
    $Hrefs |
        Where-Object { $_ -match "^$Major\.\d+\.\d+/$" } |
        ForEach-Object { [version]($_.TrimEnd('/')) } |
        Sort-Object -Unique -Descending |
        Select-Object -First 1
}

<#
  Debian 12 is the last release with i386 installer media, and i386 media is
  the only kind that carries EFI/boot/BOOTIA32.EFI - which the Stream 7's
  32-bit UEFI needs. So that's what Lazarus7 deploys.
#>
function Get-L7DebianRelease {
    param([int]$Major = 12, [string]$Arch = 'i386')
    $index = Invoke-WebRequest -UseBasicParsing $script:DebianArchive -TimeoutSec 60
    $version = Select-L7LatestPointRelease -Hrefs @($index.Links.href) -Major $Major
    if (-not $version) { throw "No Debian $Major.x release found in $script:DebianArchive" }
    $base = "$($script:DebianArchive)$version/$Arch/iso-cd/"
    $sums = ConvertFrom-L7Bytes (Invoke-WebRequest -UseBasicParsing ($base + 'SHA256SUMS') -TimeoutSec 60).Content
    $entry = Find-L7NetinstChecksum -Sha256Sums $sums -Arch $Arch
    if (-not $entry) { throw "No $Arch netinst entry in $base`SHA256SUMS" }
    [pscustomobject]@{
        Version  = $version.ToString()
        FileName = $entry.FileName
        Sha256   = $entry.Sha256
        Url      = $base + $entry.FileName
    }
}

function Test-L7FileHash {
    param([string]$Path, [string]$Sha256)
    (Test-Path $Path) -and ((Get-FileHash -Algorithm SHA256 $Path).Hash -ieq $Sha256)
}

<#
  Streams a download to disk with a progress bar. Writes to *.part, then
  renames, so an interrupted download never looks complete.
#>
function Save-L7Download {
    param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$Destination)
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromHours(2)
    $part = "$Destination.part"
    try {
        $resp = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        if (-not $resp.IsSuccessStatusCode) { throw "HTTP $([int]$resp.StatusCode) for $Url" }
        $total = $resp.Content.Headers.ContentLength
        $in = $resp.Content.ReadAsStreamAsync().Result
        $out = [IO.File]::Create($part)
        try {
            $buf = New-Object byte[] (1MB)
            $done = 0L
            $lastPct = -1
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $out.Write($buf, 0, $n)
                $done += $n
                if ($total) {
                    $pct = [int](100 * $done / $total)
                    if ($pct -ne $lastPct) {
                        Write-Progress -Activity 'Lazarus7 download' -Status ("{0:N0} / {1:N0} MB" -f ($done / 1MB), ($total / 1MB)) -PercentComplete $pct
                        $lastPct = $pct
                    }
                }
            }
        } finally { $out.Dispose(); $in.Dispose() }
        Write-Progress -Activity 'Lazarus7 download' -Completed
        Move-Item -Force $part $Destination
    } finally {
        $client.Dispose()
        if (Test-Path $part) { Remove-Item -Force $part }
    }
}

function Get-L7VerifiedDebianIso {
    param([Parameter(Mandatory)][string]$DownloadDir)
    Write-L7Step 'Looking up the latest Debian 12 i386 netinst...'
    $rel = Get-L7DebianRelease
    Write-L7Ok "Debian $($rel.Version): $($rel.FileName)"
    $null = New-Item -ItemType Directory -Force $DownloadDir
    $dest = Join-Path $DownloadDir $rel.FileName

    if (Test-L7FileHash $dest $rel.Sha256) {
        Write-L7Ok 'Already downloaded and checksum matches.'
        return $dest
    }
    Write-L7Step "Downloading $($rel.Url)"
    Save-L7Download -Url $rel.Url -Destination $dest
    Write-L7Step 'Verifying SHA256...'
    if (-not (Test-L7FileHash $dest $rel.Sha256)) {
        Remove-Item -Force $dest
        throw 'SHA256 mismatch - download deleted. Try again.'
    }
    Write-L7Ok "Checksum OK ($($rel.Sha256.Substring(0, 16))...)"
    return $dest
}

<#
  Returns the folder containing adb.exe/fastboot.exe. Uses PATH if available,
  otherwise downloads Google's platform-tools and checks the signature.
#>
function Get-L7PlatformTools {
    param([Parameter(Mandatory)][string]$ToolsDir, [switch]$NoDownload)
    $onPath = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($onPath) { return (Split-Path $onPath.Source) }

    $local = Join-Path $ToolsDir 'platform-tools'
    if (Test-Path (Join-Path $local 'adb.exe')) { return $local }
    if ($NoDownload) { return $null }

    if (-not (Read-L7YesNo 'Android platform-tools (adb/fastboot) not found. Download from Google now?' -DefaultYes)) { return $null }
    $null = New-Item -ItemType Directory -Force $ToolsDir
    $zip = Join-Path $ToolsDir 'platform-tools.zip'
    Save-L7Download -Url $script:PlatformToolsUrl -Destination $zip
    Expand-Archive -Path $zip -DestinationPath $ToolsDir -Force
    Remove-Item -Force $zip

    foreach ($exe in 'adb.exe', 'fastboot.exe') {
        $sig = Get-AuthenticodeSignature (Join-Path $local $exe)
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Google LLC') {
            Remove-Item -Recurse -Force $local
            throw "$exe is not validly signed by Google LLC - removed it."
        }
    }
    Write-L7Ok 'platform-tools downloaded; adb/fastboot signatures verified (Google LLC).'
    return $local
}

Export-ModuleMember -Function Find-L7NetinstChecksum, Select-L7LatestPointRelease, Get-L7DebianRelease,
    Test-L7FileHash, Save-L7Download, Get-L7VerifiedDebianIso, Get-L7PlatformTools
