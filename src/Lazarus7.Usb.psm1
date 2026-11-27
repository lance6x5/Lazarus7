# Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Builds USB sticks the HP Stream 7's 32-bit UEFI will actually boot:
# one FAT32 partition (<= 32 GB), files copied in, EFI\BOOT\BOOTIA32.EFI present.

$script:MaxFat32Partition = 32GB
$script:MaxFat32File = 4GB - 1

function Get-L7UsbDisk {
    Get-Disk | Where-Object { $_.BusType -eq 'USB' -and -not $_.IsBoot -and -not $_.IsSystem }
}

function Select-L7UsbDisk {
    $disks = @(Get-L7UsbDisk)
    if ($disks.Count -eq 0) {
        Write-L7Warn 'No removable USB disk found. Plug in a USB stick (8 GB+) and try again.'
        return $null
    }
    $items = foreach ($d in $disks) {
        @{ Key = $d.Number; Label = ("Disk {0}: {1}" -f $d.Number, $d.FriendlyName); Hint = ("{0:N1} GB, {1}" -f ($d.Size / 1GB), $d.PartitionStyle) }
    }
    $choice = Read-L7Menu -Title 'Pick the USB stick to ERASE' -Items $items
    if ($null -eq $choice) { return $null }
    return ($disks | Where-Object Number -eq $choice)
}

<#
  Opens an ISO (mounts it read-only) or a folder. Returns @{ Root; IsoPath }.
  Call Close-L7Source when done.
#>
function Open-L7Source {
    param([Parameter(Mandatory)][string]$Path)
    $full = (Resolve-Path $Path).Path
    if ($full -match '\.iso$') {
        $img = Get-DiskImage -ImagePath $full
        if (-not $img.Attached) { $img = Mount-DiskImage -ImagePath $full -Access ReadOnly -PassThru }
        $letter = ($img | Get-Volume).DriveLetter
        return @{ Root = "${letter}:\"; IsoPath = $full }
    }
    return @{ Root = $full; IsoPath = $null }
}

function Close-L7Source {
    param($Source)
    if ($Source -and $Source.IsoPath) { Dismount-DiskImage -ImagePath $Source.IsoPath | Out-Null }
}

function Test-L7Ia32Boot {
    param([Parameter(Mandatory)][string]$Root)
    Test-Path (Join-Path $Root 'EFI\BOOT\BOOTIA32.EFI')
}

function Get-L7OversizedFile {
    param([Parameter(Mandatory)][string]$Root)
    Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object Length -gt $script:MaxFat32File
}

function Initialize-L7UsbDisk {
    param(
        [Parameter(Mandatory)]$Disk,
        [ValidateSet('MBR', 'GPT')][string]$PartitionStyle = 'MBR',
        [string]$Label = 'LAZARUS7',
        [switch]$DryRun
    )
    # Re-check right before wiping, in case the disk list changed.
    $fresh = Get-Disk -Number $Disk.Number
    if ($fresh.BusType -ne 'USB' -or $fresh.IsBoot -or $fresh.IsSystem) {
        throw "Disk $($Disk.Number) is not a removable USB data disk. Refusing."
    }
    $sizeNote = if ([uint64]$fresh.Size -gt [uint64]$script:MaxFat32Partition) { '32 GB (FAT32 limit)' } else { 'whole disk' }
    if ($DryRun) {
        Write-L7Info "[dry run] Would erase disk $($fresh.Number), create $PartitionStyle + one FAT32 partition ($sizeNote), label $Label."
        return $null
    }

    Write-L7Step "Erasing disk $($fresh.Number)..."
    if ($fresh.PartitionStyle -ne 'RAW') {
        Clear-Disk -Number $fresh.Number -RemoveData -RemoveOEM -Confirm:$false
    }
    Initialize-Disk -Number $fresh.Number -PartitionStyle $PartitionStyle
    $partArgs = @{ DiskNumber = $fresh.Number; AssignDriveLetter = $true }
    if ([uint64]$fresh.Size -gt [uint64]$script:MaxFat32Partition) { $partArgs.Size = [uint64]$script:MaxFat32Partition }
    else { $partArgs.UseMaximumSize = $true }
    if ($PartitionStyle -eq 'MBR') { $partArgs.IsActive = $true }
    $part = New-Partition @partArgs
    Write-L7Step "Formatting FAT32 ($sizeNote)..."
    $vol = Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel $Label -Confirm:$false
    Write-L7Ok "USB ready at $($vol.DriveLetter):\"
    return "$($vol.DriveLetter):\"
}

function Copy-L7Tree {
    param([string]$From, [string]$To, [string[]]$ExcludeFiles = @(), [string[]]$ExcludeDirs = @(), [switch]$DryRun)
    if ($DryRun) { Write-L7Info "[dry run] Would copy $From -> $To"; return }
    $args_ = @($From, $To, '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NP')
    if ($ExcludeFiles.Count) { $args_ += '/XF'; $args_ += $ExcludeFiles }
    if ($ExcludeDirs.Count) { $args_ += '/XD'; $args_ += $ExcludeDirs }
    & robocopy @args_ | Out-Host
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed (exit $LASTEXITCODE)" }
}

function Get-L7RemovableVolume {
    Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -and $_.FileSystem }
}

function Select-L7RemovableVolume {
    param([Parameter(Mandatory)][string]$Title)
    $vols = @(Get-L7RemovableVolume)
    if ($vols.Count -eq 0) {
        Write-L7Warn 'No removable USB drive with a file system found. Plug the stick in and try again.'
        return $null
    }
    $items = foreach ($v in $vols) {
        @{ Key = [string]$v.DriveLetter; Label = ("{0}:  {1}" -f $v.DriveLetter, $(if ($v.FileSystemLabel) { $v.FileSystemLabel } else { '(no label)' }));
           Hint = ("{0}, {1:N1} GB used of {2:N1} GB" -f $v.FileSystem, (($v.Size - $v.SizeRemaining) / 1GB), ($v.Size / 1GB)) }
    }
    $letter = Read-L7Menu -Title $Title -Items $items
    if (-not $letter) { return $null }
    return ($vols | Where-Object { [string]$_.DriveLetter -eq $letter })
}

# ---- Recovery USB backups ---------------------------------------------------
# A recovery drive made on the tablet (or HP's own media) is the only way back to
# the factory WIMBoot Windows 8.1, and HP no longer offers this tablet in its
# Cloud Recovery Tool. So Lazarus7 keeps a verified copy on the PC.

$script:ManifestName = 'lazarus7-manifest.json'
$script:SkipDirs = @('System Volume Information', '$RECYCLE.BIN')

function Get-L7BackupRoot {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Lazarus7\Backups'
}

<#
  Pure-ish: hashes every file under Root (except the manifest itself and the
  Windows housekeeping folders) and returns a manifest object.
#>
function New-L7FileManifest {
    param([Parameter(Mandatory)][string]$Root, [string]$Label = '', [string]$Source = '')
    $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\') + '\'
    $files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $rel = $_.FullName.Substring($rootFull.Length)
            $top = $rel.Split('\')[0]
            ($rel -ne $script:ManifestName) -and ($script:SkipDirs -notcontains $top)
        } |
        Sort-Object FullName |
        ForEach-Object {
            [pscustomobject]@{
                Path   = $_.FullName.Substring($rootFull.Length)
                Size   = $_.Length
                Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
            }
        }
    [pscustomobject]@{
        Tool      = 'Lazarus7'
        Version   = (Get-Lazarus7Version)
        Created   = (Get-Date).ToString('o')
        Label     = $Label
        Source    = $Source
        FileCount = @($files).Count
        TotalSize = [int64](($files | Measure-Object -Property Size -Sum).Sum)
        Files     = @($files)
    }
}

<#
  Returns the list of problems (missing / wrong size / wrong hash); empty = OK.
#>
function Test-L7FileManifest {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)]$Manifest)
    $problems = @()
    foreach ($f in $Manifest.Files) {
        $p = Join-Path $Root $f.Path
        if (-not (Test-Path -LiteralPath $p)) { $problems += "missing: $($f.Path)"; continue }
        $item = Get-Item -LiteralPath $p -Force
        if ($item.Length -ne [int64]$f.Size) { $problems += "size differs: $($f.Path)"; continue }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash -ne $f.Sha256) { $problems += "content differs: $($f.Path)" }
    }
    return $problems
}

function Read-L7Manifest {
    param([Parameter(Mandatory)][string]$Folder)
    $m = Join-Path $Folder $script:ManifestName
    if (-not (Test-Path -LiteralPath $m)) { return $null }
    return ([IO.File]::ReadAllText($m, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Get-L7RecoveryBackup {
    $root = Get-L7BackupRoot
    if (-not (Test-Path $root)) { return @() }
    Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending | ForEach-Object {
        $m = Read-L7Manifest $_.FullName
        if ($m) { [pscustomobject]@{ Folder = $_.FullName; Name = $_.Name; Manifest = $m } }
    }
}

<#
  Copies a recovery USB (made on the tablet, or HP's media) to
  Documents\Lazarus7\Backups\<name> and writes a SHA256 manifest.
#>
function Invoke-L7BackupRecoveryUsb {
    param([switch]$DryRun)
    Write-L7Section 'Save a recovery USB to this PC'
    Write-L7Info 'Plug in the recovery drive you made on the tablet (or HP recovery media). Nothing on it is changed.'
    $vol = Select-L7RemovableVolume -Title 'Which stick is the recovery drive?'
    if (-not $vol) { return }
    $src = "$($vol.DriveLetter):\"
    if (-not (Test-L7Ia32Boot $src)) {
        Write-L7Warn 'This stick has no EFI\BOOT\BOOTIA32.EFI, so it may not be a Stream 7 recovery drive.'
        if (-not (Read-L7YesNo 'Back it up anyway?')) { return }
    }
    $usedGb = ($vol.Size - $vol.SizeRemaining) / 1GB
    $name = 'Stream7-Recovery-' + (Get-Date -Format 'yyyyMMdd-HHmm')
    $dest = Join-Path (Get-L7BackupRoot) $name
    Write-L7Info ("About {0:N1} GB will be copied to {1}" -f $usedGb, $dest)
    if ($DryRun) { Write-L7Info '[dry run] Would copy the stick and write a SHA256 manifest.'; return }

    $null = New-Item -ItemType Directory -Force $dest
    Write-L7Step 'Copying (a few minutes)...'
    Copy-L7Tree -From $src -To $dest -ExcludeDirs $script:SkipDirs
    Write-L7Step 'Hashing every file (SHA256)...'
    $manifest = New-L7FileManifest -Root $dest -Label $vol.FileSystemLabel -Source "$src ($($vol.FileSystemLabel))"
    $json = $manifest | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText((Join-Path $dest $script:ManifestName), $json, (New-Object Text.UTF8Encoding($false)))

    Write-L7Step 'Re-reading the stick to confirm the copy matches...'
    $problems = Test-L7FileManifest -Root $src -Manifest $manifest
    if ($problems.Count) {
        Write-L7Fail "The stick and the copy differ ($($problems.Count) files). The stick may be failing:"
        $problems | Select-Object -First 10 | ForEach-Object { Write-L7Info $_ }
        return
    }
    Write-L7Ok ("Saved {0} files ({1:N1} GB), verified: {2}" -f $manifest.FileCount, ($manifest.TotalSize / 1GB), $dest)
    Write-L7Info 'Rebuild a stick from it any time: Restore Windows -> "A recovery backup saved on this PC".'
}

<#
  Copies the tablet-side helpers (and optionally a drivers folder) onto an
  existing USB stick WITHOUT erasing it:  <usb>\lazarus7\windows, <usb>\lazarus7\linux, <usb>\Drivers
#>
function Invoke-L7ToolkitUsb {
    param([Parameter(Mandatory)][string]$PayloadDir, [string]$DriversDir, [switch]$DryRun)
    $vol = Select-L7RemovableVolume -Title 'Copy the Lazarus7 tablet toolkit to which stick? (nothing is erased)'
    if (-not $vol) { return }
    $letter = $vol.DriveLetter
    $root = "${letter}:\"
    Copy-L7Tree -From $PayloadDir -To (Join-Path $root 'lazarus7') -DryRun:$DryRun
    if ($DriversDir) { Copy-L7Tree -From $DriversDir -To (Join-Path $root 'Drivers') -DryRun:$DryRun }
    Write-L7Ok "Toolkit on ${letter}:\lazarus7\"
    Write-L7Section 'Now on the Stream 7 (Windows 8.1 must still boot)'
    Write-L7Info '1. Plug the stick in via the OTG adapter, open File Explorer, go to lazarus7\windows.'
    Write-L7Info '2. Double-tap Stream7-Check.cmd and allow admin. It saves a report to lazarus7\reports'
    Write-L7Info '   (serial, product number, firmware key, WIMBoot, BitLocker) - keep that file private.'
    Write-L7Info '3. Option 2 in the helper: make a recovery drive on a SECOND 8 GB+ stick, ticking'
    Write-L7Info '   "Copy the recovery partition". On a WIMBoot Stream 7 that partition IS Windows 8.1.'
    Write-L7Info '4. Option 1: turn off Fast Startup before you install Linux.'
}

<#
  Main flow for both Windows recovery media and Linux deployment.
  Mode 'windows': folder (HP recovery) or Windows x86 ISO. Splits install.wim if > 4 GB.
  Mode 'linux'  : ISO.
  Both modes add the Lazarus7 tablet-side payload under \lazarus7\ and, if given, \Drivers.
#>
function Invoke-L7BuildUsb {
    param(
        [Parameter(Mandatory)][ValidateSet('windows', 'linux')][string]$Mode,
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$PayloadDir,
        [string]$DriversDir,
        [string]$Label = 'LAZARUS7',
        [switch]$DryRun
    )
    $src = Open-L7Source $SourcePath
    try {
        Write-L7Step "Inspecting $SourcePath"
        # A Lazarus7 backup carries a SHA256 manifest: verify it before wiping anything.
        $manifest = Read-L7Manifest $src.Root
        if ($manifest) {
            Write-L7Step ("Verifying the saved backup ({0} files)..." -f $manifest.FileCount)
            $bad = Test-L7FileManifest -Root $src.Root -Manifest $manifest
            if ($bad.Count) {
                Write-L7Fail "The backup on this PC is damaged ($($bad.Count) files) - not writing it:"
                $bad | Select-Object -First 10 | ForEach-Object { Write-L7Info $_ }
                return
            }
            Write-L7Ok 'Backup verified.'
            if ($manifest.Label) { $Label = $manifest.Label }
        }
        if (Test-L7Ia32Boot $src.Root) {
            Write-L7Ok 'EFI\BOOT\BOOTIA32.EFI found - the Stream 7 can boot this.'
        } else {
            Write-L7Warn 'No EFI\BOOT\BOOTIA32.EFI: the Stream 7 (32-bit UEFI) will NOT boot this media.'
            Write-L7Info '64-bit-only ISOs (Debian 13 amd64, Ubuntu, Windows 11) lack it.'
            if (-not (Read-L7YesNo 'Build it anyway?')) { return }
        }

        $big = @(Get-L7OversizedFile $src.Root)
        $wim = $big | Where-Object { $_.Name -ieq 'install.wim' }
        $other = $big | Where-Object { $_.Name -ine 'install.wim' }
        if ($other) {
            Write-L7Fail ('Files over 4 GB cannot go on FAT32: ' + (($other | ForEach-Object Name) -join ', '))
            return
        }
        if ($wim) { Write-L7Info 'install.wim is over 4 GB - it will be split into .swm parts with DISM.' }

        $disk = Select-L7UsbDisk
        if (-not $disk) { return }
        $phrase = "ERASE $($disk.Number)"
        if (-not (Confirm-L7Danger -What ("Disk {0} ({1}, {2:N1} GB) will be wiped completely." -f $disk.Number, $disk.FriendlyName, ($disk.Size / 1GB)) -Phrase $phrase)) {
            Write-L7Warn 'Cancelled - nothing was changed.'
            return
        }

        $dest = Initialize-L7UsbDisk -Disk $disk -Label $Label -DryRun:$DryRun
        if ($DryRun) { $dest = '<usb>\' }

        Write-L7Step 'Copying files (this takes a few minutes)...'
        $skipFiles = @($wim | ForEach-Object Name) + @($script:ManifestName)
        Copy-L7Tree -From $src.Root -To $dest -ExcludeFiles $skipFiles -ExcludeDirs $script:SkipDirs -DryRun:$DryRun
        if ($wim) {
            $swm = Join-Path $dest 'sources\install.swm'
            if ($DryRun) { Write-L7Info "[dry run] Would run DISM /Split-Image -> $swm" }
            else {
                & dism.exe /Split-Image "/ImageFile:$($wim.FullName)" "/SWMFile:$swm" /FileSize:3800 | Out-Host
                if ($LASTEXITCODE -ne 0) { throw "DISM split failed (exit $LASTEXITCODE)" }
            }
        }
        Copy-L7Tree -From $PayloadDir -To (Join-Path $dest 'lazarus7') -DryRun:$DryRun
        Write-L7Ok 'Added the Lazarus7 tablet helpers under \lazarus7\.'
        if ($DriversDir) {
            Copy-L7Tree -From $DriversDir -To (Join-Path $dest 'Drivers') -DryRun:$DryRun
            Write-L7Ok 'Added drivers under \Drivers (Windows Setup: "Load driver" can use them too).'
        }

        if (-not $DryRun -and -not (Test-L7Ia32Boot $dest)) {
            Write-L7Warn 'Finished, but BOOTIA32.EFI is missing on the stick.'
        }
        if ($manifest) {
            if ($DryRun) { Write-L7Info '[dry run] Would re-read the stick and check every file against the manifest.' }
            else {
                Write-L7Step 'Re-reading the stick to check every file...'
                $bad = Test-L7FileManifest -Root $dest -Manifest $manifest
                if ($bad.Count) {
                    Write-L7Fail "The stick does not match the backup ($($bad.Count) files). Try another stick:"
                    $bad | Select-Object -First 10 | ForEach-Object { Write-L7Info $_ }
                    return
                }
                Write-L7Ok 'Stick verified against the backup - identical.'
            }
        }
        Write-L7Section 'USB done - now on the tablet'
        Write-L7Info '1. Connect stick + keyboard via OTG adapter and a POWERED hub.'
        Write-L7Info '2. Tablet off. Hold Vol-Down, press Power until the HP logo; release Power.'
        Write-L7Info '3. F10 -> System Configuration -> Boot Options -> Secure Boot: Disabled -> F10 save.'
        Write-L7Info '4. Again Vol-Down + Power -> F9 Boot Options -> pick the USB stick.'
        if ($Mode -eq 'linux') {
            Write-L7Info '5. After Debian boots: plug the stick back in and run'
            Write-L7Info '     sudo sh /media/<user>/LAZARUS7/lazarus7/linux/stream7-debian-postinstall.sh --backlight'
        } else {
            Write-L7Info '5. Touch does not work inside Windows Setup - use the keyboard (and a mouse).'
            Write-L7Info '6. After Windows is up: run \lazarus7\windows\Stream7-Check.cmd -> option 3 to install \Drivers.'
        }
        # Callers show follow-up steps only when a stick was really built (or walked through in a dry run).
        return $true
    } finally {
        Close-L7Source $src
    }
}

Export-ModuleMember -Function Get-L7UsbDisk, Select-L7UsbDisk, Open-L7Source, Close-L7Source, Test-L7Ia32Boot,
    Get-L7OversizedFile, Initialize-L7UsbDisk, Copy-L7Tree, Invoke-L7BuildUsb, Get-L7RemovableVolume, Invoke-L7ToolkitUsb,
    Select-L7RemovableVolume, Get-L7BackupRoot, New-L7FileManifest, Test-L7FileManifest, Read-L7Manifest,
    Get-L7RecoveryBackup, Invoke-L7BackupRecoveryUsb
