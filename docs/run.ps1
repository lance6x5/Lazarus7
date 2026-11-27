# Lazarus7 web launcher - Copyright (c) 2026 lance6x5 - MIT License
#
# Downloads the latest Lazarus7 release from GitHub, verifies its SHA256,
# unpacks it to %LOCALAPPDATA%\Lazarus7\<version> and starts it.
#
#   irm https://lance6x5.github.io/Lazarus7/run.ps1 | iex
#
# Dry run (nothing is erased or flashed):
#   & ([scriptblock]::Create((irm https://lance6x5.github.io/Lazarus7/run.ps1))) -DryRun
param([switch]$DryRun, [string]$Version = 'latest')

& {
    param([bool]$DryRun, [string]$Version)
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if ($env:OS -ne 'Windows_NT') { throw 'Lazarus7 runs on Windows only.' }

    $repo = 'lance6x5/Lazarus7'
    $headers = @{ 'User-Agent' = 'Lazarus7-launcher'; 'Accept' = 'application/vnd.github+json' }
    $api = if ($Version -eq 'latest') { "https://api.github.com/repos/$repo/releases/latest" }
           else { "https://api.github.com/repos/$repo/releases/tags/$Version" }

    Write-Host ''
    Write-Host '  LAZARUS7 :: raise your 7-inch HP tablet from the dead' -ForegroundColor DarkYellow
    Write-Host "  Looking up release ($Version)..." -ForegroundColor Gray
    $rel = Invoke-RestMethod -Uri $api -Headers $headers
    $zipAsset = $rel.assets | Where-Object name -eq 'Lazarus7.zip'
    $shaAsset = $rel.assets | Where-Object name -eq 'Lazarus7.zip.sha256'
    if (-not $zipAsset -or -not $shaAsset) { throw "Release $($rel.tag_name) is missing Lazarus7.zip or its .sha256." }

    $home_ = Join-Path $env:LOCALAPPDATA "Lazarus7\$($rel.tag_name)"
    $entry = Join-Path $home_ 'Lazarus7\Lazarus7.cmd'

    if (Test-Path $entry) {
        Write-Host "  Using cached $($rel.tag_name) in $home_" -ForegroundColor Gray
    } else {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("lazarus7-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force $tmp | Out-Null
        try {
            $zip = Join-Path $tmp 'Lazarus7.zip'
            Write-Host "  Downloading $($rel.tag_name)..." -ForegroundColor Gray
            Invoke-WebRequest -UseBasicParsing -Uri $zipAsset.browser_download_url -OutFile $zip -Headers $headers
            $expected = ((Invoke-WebRequest -UseBasicParsing -Uri $shaAsset.browser_download_url -Headers $headers).Content |
                         ForEach-Object { if ($_ -is [byte[]]) { [Text.Encoding]::ASCII.GetString($_) } else { $_ } }).Trim().Split(' ')[0]
            $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash
            if ($actual -ine $expected) { throw "SHA256 mismatch (expected $expected, got $actual). Not running it." }
            Write-Host "  SHA256 verified: $($actual.Substring(0, 16))..." -ForegroundColor Green

            $stage = Join-Path $tmp 'x'
            Expand-Archive -Path $zip -DestinationPath $stage -Force
            if (Test-Path $home_) { Remove-Item -Recurse -Force $home_ }   # leftover from an interrupted run
            New-Item -ItemType Directory -Force $home_ | Out-Null
            Move-Item (Join-Path $stage 'Lazarus7') $home_
        } finally {
            Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        }
    }

    Write-Host '  Starting Lazarus7 in a new window...' -ForegroundColor Cyan
    $launchArgs = if ($DryRun) { @('/c', "`"$entry`" --dry-run") } else { @('/c', "`"$entry`"") }
    Start-Process -FilePath cmd.exe -ArgumentList $launchArgs
    Write-Host "  Installed at: $(Split-Path $entry)" -ForegroundColor DarkGray
    Write-Host ''
} ([bool]$DryRun) $Version
