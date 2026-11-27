<p align="center">
  <img src="docs/logo.svg" alt="Lazarus7" width="640">
</p>

<p align="center">
  <b>A guided recovery and deployment wizard for HP's 7-inch tablets.</b><br>
  HP Stream 7 (label <code>TSW 7H</code>) &nbsp;•&nbsp; HP Slate 7 family (2800 / HD / Extreme / Plus)
</p>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-f59e0b">
  <img alt="Windows PowerShell 5.1" src="https://img.shields.io/badge/PowerShell-5.1%2B-ef4444">
  <img alt="Pester tests" src="https://img.shields.io/badge/tests-Pester-7a0b0b">
</p>

---

Your tablet isn't dead, just resting. **Lazarus7** walks you from "it won't turn on" to a working tablet:
it diagnoses the problem, gives first-aid steps, builds bootable USB media the Stream 7's odd **32-bit UEFI**
actually accepts, deploys Debian with tablet-specific fixes, and flashes Android Slates over ADB, fastboot or
Rockchip loader mode.

```
   _          _      _____     _      ____    _   _   ____    _____
  | |        / \    |__  /    / \    |  _ \  | | | | / ___|  |___  |
  | |       / _ \     / /    / _ \   | |_) | | | | | \___ \     / /
  | |___   / ___ \   / /_   / ___ \  |  _ <  | |_| |  ___) |   / /
  |_____| /_/   \_\ /____| /_/   \_\ |_| \_\  \___/  |____/   /_/

  Raise your 7-inch HP tablet from the dead.   v1.1.0
```

## 🌐 Run from the web

**Website: <https://lance6x5.github.io/Lazarus7/>**. The Diagnose wizard, first aid and OS table run right in
the browser, and *Identify my tablet* uses WebUSB in Chrome or Edge.

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
| **Diagnose** | A few questions (which OS, what the tablet does) lead to a concrete recommendation, then a jump to the right tool. |
| **Identify my tablet** | Read-only USB scan that recognises Rockchip loader mode, Tegra APX, ADB/fastboot and missing drivers. |
| **First aid** | Dead-battery revival, the Stream 7 startup menu (F2/F9/F10/F11), and Android recovery key combos. |
| **Build Windows recovery USB** | From HP recovery files or a Windows 10 x86 ISO. Splits `install.wim` over 4 GB with DISM automatically. |
| **Deploy Linux** | Downloads the latest **Debian 12 i386** netinst, **verifies SHA256**, writes a FAT32 stick and checks it has `EFI\BOOT\BOOTIA32.EFI`. It also adds the tablet-side tune-up script. |
| **Flash / recover Android Slate 7** | Fetches Google platform-tools (signature-verified), then: device list, reboot to recovery/bootloader, `adb sideload`, `fastboot boot`/`flash`, and the Rockchip (Slate 7 2800) RKDevTool flow. |

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

After install, `payload/stream7-debian-postinstall.sh` (copied onto the stick at `\lazarus7\`) adds:
WiFi/audio firmware, zram (1 GB RAM!), the rotation sensor, an on-screen keyboard, a GRUB fallback so a
lost UEFI boot entry can't "re-brick" it, and the optional backlight/suspend fix.

The full manual walkthrough is in **[docs/GUIDE.md](docs/GUIDE.md)**.

## Project layout

```
Lazarus7.cmd          double-click launcher (self-elevates)
Lazarus7.ps1          main wizard
src/                  modules: Ui, Detect, Triage, Download, Usb, Android
payload/              files copied to the USB for use on the tablet
docs/                 GitHub Pages site (index.html, run.ps1 launcher), field guide, logo
tests/                Pester tests:  Invoke-Pester .\tests
.github/workflows/    release.yml: tag v* -> tests -> Lazarus7.zip + .sha256 release
```

Releasing: `git tag v1.2.0 && git push --tags`. The workflow runs the tests, then publishes the zip that the web
launcher picks up.

## Contributing

Issues and PRs are welcome, especially reports from real hardware (which sub-model, what worked, what didn't).
Run `Invoke-Pester .\tests` before opening a PR.

## License

[MIT](LICENSE) © 2026 lance6x5. Lazarus7 is an independent project, **not affiliated with HP Inc.**
See [NOTICE.md](NOTICE.md) for trademarks and disclaimers.
