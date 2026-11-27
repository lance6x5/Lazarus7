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
    param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$Destination, [string]$UserAgent)
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromHours(2)
    # SourceForge serves a browser landing page instead of the file unless the client looks like a download tool.
    if ($UserAgent) { $client.DefaultRequestHeaders.UserAgent.ParseAdd($UserAgent) }
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
  Android-x86 9.0-r2 (32-bit) - the last Android-x86 release, and its ISO ships
  EFI/BOOT/bootia32.efi, so the Stream 7 can boot it. Checked against two
  independent published hashes: SHA-1 from android-x86.org's release note and
  MD5 from SourceForge's file listing. Both must match.
#>
$script:AndroidX86 = [pscustomobject]@{
    Name      = 'Android-x86 9.0-r2 (32-bit)'
    FileName  = 'android-x86-9.0-r2.iso'
    Urls      = @('https://master.dl.sourceforge.net/project/android-x86/Release%209.0/android-x86-9.0-r2.iso?viasf=1',
                  'https://downloads.sourceforge.net/project/android-x86/Release%209.0/android-x86-9.0-r2.iso')
    Sha1      = 'd72bbd11c1bedbe99f50da54731c6a83b41becb0'   # https://www.android-x86.org/releases/releasenote-9-0-r2.html
    Md5       = 'a58dd3e12385f368edee978f8ce20a03'           # SourceForge file listing
    UserAgent = 'Wget/1.21.4 (Lazarus7)'
}

function Get-L7AndroidX86Release { $script:AndroidX86 }

function Test-L7AndroidX86Iso {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    ((Get-FileHash -Algorithm SHA1 -LiteralPath $Path).Hash -ieq $script:AndroidX86.Sha1) -and
    ((Get-FileHash -Algorithm MD5 -LiteralPath $Path).Hash -ieq $script:AndroidX86.Md5)
}

function Get-L7VerifiedAndroidX86Iso {
    param([Parameter(Mandatory)][string]$DownloadDir)
    $rel = $script:AndroidX86
    $null = New-Item -ItemType Directory -Force $DownloadDir
    $dest = Join-Path $DownloadDir $rel.FileName
    if (Test-L7AndroidX86Iso $dest) { Write-L7Ok "$($rel.Name) already downloaded and verified."; return $dest }
    foreach ($u in $rel.Urls) {
        Write-L7Step "Downloading $($rel.Name) (~900 MB) from SourceForge..."
        try { Save-L7Download -Url $u -Destination $dest -UserAgent $rel.UserAgent } catch { Write-L7Warn "Mirror failed: $($_.Exception.Message)"; continue }
        Write-L7Step 'Verifying SHA-1 (android-x86.org) and MD5 (SourceForge)...'
        if (Test-L7AndroidX86Iso $dest) { Write-L7Ok 'Both checksums match.'; return $dest }
        Remove-Item -Force $dest
        Write-L7Warn 'Checksum mismatch - deleted. Trying the next mirror.'
    }
    throw "Could not get a verified $($rel.FileName). Download it yourself and use 'My own ISO'."
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
    Test-L7FileHash, Save-L7Download, Get-L7VerifiedDebianIso, Get-L7PlatformTools,
    Get-L7AndroidX86Release, Test-L7AndroidX86Iso, Get-L7VerifiedAndroidX86Iso
