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
    param([string]$From, [string]$To, [string[]]$ExcludeFiles = @(), [switch]$DryRun)
    if ($DryRun) { Write-L7Info "[dry run] Would copy $From -> $To"; return }
    $args_ = @($From, $To, '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NP')
    if ($ExcludeFiles.Count) { $args_ += '/XF'; $args_ += $ExcludeFiles }
    & robocopy @args_ | Out-Host
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed (exit $LASTEXITCODE)" }
}

function Get-L7RemovableVolume {
    Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -and $_.FileSystem }
}

<#
  Copies the tablet-side helpers (and optionally a drivers folder) onto an
  existing USB stick WITHOUT erasing it:  <usb>\lazarus7\windows, <usb>\lazarus7\linux, <usb>\Drivers
#>
function Invoke-L7ToolkitUsb {
    param([Parameter(Mandatory)][string]$PayloadDir, [string]$DriversDir, [switch]$DryRun)
    $vols = @(Get-L7RemovableVolume)
    if ($vols.Count -eq 0) {
        Write-L7Warn 'No removable USB drive with a file system found. Plug in a FAT32/exFAT/NTFS stick.'
        return
    }
    $items = foreach ($v in $vols) {
        @{ Key = [string]$v.DriveLetter; Label = ("{0}:  {1}" -f $v.DriveLetter, $(if ($v.FileSystemLabel) { $v.FileSystemLabel } else { '(no label)' }));
           Hint = ("{0}, {1:N1} GB free" -f $v.FileSystem, ($v.SizeRemaining / 1GB)) }
    }
    $letter = Read-L7Menu -Title 'Copy the Lazarus7 tablet toolkit to which stick? (nothing is erased)' -Items $items
    if (-not $letter) { return }
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
        [switch]$DryRun
    )
    $src = Open-L7Source $SourcePath
    try {
        Write-L7Step "Inspecting $SourcePath"
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

        $dest = Initialize-L7UsbDisk -Disk $disk -DryRun:$DryRun
        if ($DryRun) { $dest = '<usb>\' }

        Write-L7Step 'Copying files (this takes a few minutes)...'
        Copy-L7Tree -From $src.Root -To $dest -ExcludeFiles @($wim | ForEach-Object Name) -DryRun:$DryRun
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
    } finally {
        Close-L7Source $src
    }
}

Export-ModuleMember -Function Get-L7UsbDisk, Select-L7UsbDisk, Open-L7Source, Close-L7Source, Test-L7Ia32Boot,
    Get-L7OversizedFile, Initialize-L7UsbDisk, Copy-L7Tree, Invoke-L7BuildUsb, Get-L7RemovableVolume, Invoke-L7ToolkitUsb
