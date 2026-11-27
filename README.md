<p align="center">
  <img src="docs/logo.svg" alt="Lazarus7" width="640">
</p>

<p align="center">
  <b>A guided recovery and deployment wizard for the HP Stream 7.</b><br>
  Label <code>TSW 7H</code> &nbsp;•&nbsp; shipped with Windows 8.1 with Bing &nbsp;•&nbsp; Android HP Slate 7 as a bonus
</p>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-f59e0b">
  <img alt="Windows PowerShell 5.1" src="https://img.shields.io/badge/PowerShell-5.1%2B-ef4444">
  <img alt="Pester tests" src="https://img.shields.io/badge/tests-Pester-7a0b0b">
</p>

---

Your Stream 7 isn't dead, just resting. **Lazarus7** walks you from "it won't turn on" to a working tablet.
It diagnoses the problem and gives Windows 8.1 first aid (F11 Refresh/Reset). It **backs up the WIMBoot Windows**
before anything gets wiped, and restores factory 8.1 from HP recovery media. It also builds bootable USB media the
Stream 7's odd **32-bit UEFI** actually accepts, and deploys Debian with tablet-specific fixes. Android HP Slate 7
tablets get ADB, fastboot and Rockchip tools as a secondary path.

```
   _          _      _____     _      ____    _   _   ____    _____
  | |        / \    |__  /    / \    |  _ \  | | | | / ___|  |___  |
  | |       / _ \     / /    / _ \   | |_) | | | | | \___ \     / /
  | |___   / ___ \   / /_   / ___ \  |  _ <  | |_| |  ___) |   / /
  |_____| /_/   \_\ /____| /_/   \_\ |_| \_\  \___/  |____/   /_/

  Raise your 7-inch HP tablet from the dead.   v1.6.0
```

## 🌐 Run from the web

**Website: <https://lance6x5.github.io/Lazarus7/>**. The Diagnose wizard, first aid and OS table run right in
the browser, and the Android scan uses WebUSB in Chrome or Edge.

To launch the full tool, paste one line into **PowerShell**. It downloads the latest release, verifies the SHA256,
and starts the wizard:

```powershell
irm https://lance6x5.github.io/Lazarus7/run.ps1 | iex
```

Dry run (nothing is erased or flashed):

```powershell
& ([scriptblock]::Create((irm https://lance6x5.github.io/Lazarus7/run.ps1))) -DryRun
```

The launcher installs to `%LOCALAPPDATA%\Lazarus7\<version>`. Read [`docs/run.ps1`](docs/run.ps1) before piping it
if you like, since it's short.

## Quick start (from a clone)

1. Download or clone this repo onto a Windows 10/11 PC.
2. Double-click **`Lazarus7.cmd`** and accept the admin prompt. Admin is needed only to write USB sticks.
3. Pick **Diagnose**. Lazarus7 asks what the tablet does and sends you to the right tool.

To look around without touching anything:

```bash
Lazarus7.cmd --dry-run
```

Nothing else to install: it runs on the Windows PowerShell 5.1 that every Windows PC already has.

## What it does

| Menu | What happens |
|---|---|
| **Diagnose** | Which tablet, and what does it do? Covers Windows 8.1 cases like the Automatic Repair loop, BitLocker and a forgotten sign-in. Gives a concrete recommendation, then jumps to the right tool. |
| **First aid** | Dead-battery revival, the startup menu (F2/F9/F10/F11), **Refresh vs Reset your PC**, and why you mustn't delete the WIMBoot partition. |
| **Make a tablet toolkit USB** | Copies the tablet helpers onto any stick **without erasing it**. On the tablet, `Stream7-Check.cmd` saves a private report (serial, product number, firmware key, activation, WIMBoot, BitLocker). It can also turn off Fast Startup, start a **recovery drive** that copies the recovery partition, and install drivers. Every stick also carries `Stream7-Repair.cmd` for **0xc0000225** / black-screen boots, run from a Windows setup stick's Command Prompt. |
| **Restore Windows** | From HP recovery media (factory 8.1 WIMBoot + drivers, recommended) or a Windows 10 x86 ISO, with honest activation and support warnings. It can add a Stream 7 drivers folder and splits `install.wim` over 4 GB with DISM. |
| **Deploy Linux** | Downloads the latest **Debian 12 i386** netinst, **verifies SHA256**, writes a FAT32 stick and checks it has `EFI\BOOT\BOOTIA32.EFI`. It also adds the tablet-side tune-up script. |
| **Identify a tablet over USB** / **Other HP tablets** | For Android Slate 7s: **button combos per model** (recovery, fastboot, loader/APX, reset), a read-only USB scan, plus Google platform-tools (signature-verified), `adb sideload`, `fastboot boot`/`flash` and the Rockchip flow. |

### Safety rails
- Only **USB-attached, non-boot, non-system** disks can be selected, and the disk is re-checked right before wiping.
- Every destructive step needs you to **type a confirmation phrase** (`ERASE 3`, `FLASH`).
- `--dry-run` walks every flow and prints what *would* happen.
- Downloads go to `*.part` first and are only kept if the checksum or signature matches.

## Why the Stream 7 is tricky

The Atom Z3735G is a 64-bit CPU, but HP shipped it with **32-bit-only UEFI**. It boots only media that contains
`EFI\BOOT\BOOTIA32.EFI`. Most modern ISOs don't have that file: Debian 13 amd64, Ubuntu, Fedora, ChromeOS Flex
and Windows 11 all lack it. **Debian 12 i386** does have it, has a Stream 7 page on the Debian wiki, and keeps
security support (LTS) until mid-2028. That's why it's the default.

The stock **Windows 8.1 with Bing** runs in **WIMBoot** mode. C: holds about 4 GB and the rest of Windows lives in the
~5 GB recovery partition, so deleting that partition breaks Windows. Lazarus7 makes you back it up first.

After a Linux install, `payload/linux/stream7-debian-postinstall.sh` (copied onto the stick at `\lazarus7\linux\`) adds:
WiFi/audio firmware, zram (1 GB RAM!), the rotation sensor, an on-screen keyboard, a GRUB fallback so a
lost UEFI boot entry can't "re-brick" it, and the optional backlight/suspend fix.

The full manual walkthrough is in **[docs/GUIDE.md](docs/GUIDE.md)**.

## Project layout

```
Lazarus7.cmd          double-click launcher (self-elevates)
Lazarus7.ps1          main wizard
src/                  modules: Ui, Detect, Triage, Download, Usb, Android
payload/windows/      Stream7-Check helper, runs on the tablet under Windows 8.1 / 10
payload/linux/        Debian post-install tune-up, runs on the tablet under Debian
docs/                 GitHub Pages site (index.html, run.ps1 launcher), triage.json (shared Diagnose rules), field guide, logo
tests/                Pester tests:  Invoke-Pester .\tests
.github/workflows/    release.yml: tag v* -> tests -> Lazarus7.zip + .sha256 release
```

Releasing: bump `Lazarus7Version` in `src/Lazarus7.Ui.psm1` and the site's `data-version`. Then add a
`## [x.y.z] - date` section to [CHANGELOG.md](CHANGELOG.md), and run `git tag vx.y.z && git push --tags`. The workflow
refuses a tag that doesn't match the code. It runs the tests and publishes the zip that the web launcher picks up, with
that changelog section as the release notes. The website shows the latest version, its release date, when the
site was last updated, and the full changelog.

## Report a problem or request a feature

Use GitHub Issues. The forms ask the right questions, and each issue arrives labelled for triage:

- **[Report a problem](https://github.com/lance6x5/Lazarus7/issues/new?template=bug_report.yml)**: wrong advice, an error, a crash
- **[Request a feature](https://github.com/lance6x5/Lazarus7/issues/new?template=feature_request.yml)**: a new tablet, a new OS, a better way
- **[Tell us what worked](https://github.com/lance6x5/Lazarus7/issues/new?template=device_report.yml)**: real-hardware results, which turn "generic" button combos into confirmed ones

You can also file from inside the tool (**Report a problem / request a feature**, which pre-fills your version and PC OS)
or from any Diagnose result on the website (which pre-fills the diagnosis path). You'll need a free GitHub account.
**Never paste your Windows product key or serial number**: the Stream7-Check report contains both.

## Contributing

Pull requests are welcome. Run `Invoke-Pester .\tests` before opening one.

## License

[MIT](LICENSE) © 2026 lance6x5. Lazarus7 is an independent project, **not affiliated with HP Inc.**
See [NOTICE.md](NOTICE.md) for trademarks and disclaimers.
