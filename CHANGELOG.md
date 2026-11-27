# Changelog

All notable changes to Lazarus7. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).
The release workflow publishes the matching section below as each GitHub release's notes, and the
[website](https://lance6x5.github.io/Lazarus7/#changelog) shows it too.

## [1.4.0] - 2026-11-27

### Added
- **Save a recovery USB to this PC**: copies a recovery drive (made on the tablet, or HP's media) to
  `Documents\Lazarus7\Backups\`. It writes a SHA256 manifest of every file and re-reads the stick to prove the copy
  matches.
- **Rebuild from a saved backup**: Restore Windows lists your saved backups and verifies the backup before wiping
  the stick. It keeps the original volume label, then re-reads the new stick and checks every file against the
  manifest.
- **Where do I get recovery media?** explains the options for this tablet, in order. HP's Cloud Recovery Tool doesn't
  cover the Stream 7, and the tablet can't be flashed from a PC over USB.

### Changed
- CI: `actions/checkout` bumped to v7.

## [1.3.0] - 2026-11-27

### Changed
- Lazarus7 is now built around the **HP Stream 7 (TSW 7H) with Windows 8.1 with Bing**. The Android Slate 7 tools
  stay available under "Other HP tablets".
- Diagnose asks "which tablet?" with the Stream 7 first, and adds Windows 8.1 symptoms: Automatic Repair loop and
  forgotten sign-in. A working Windows 8.1 now goes to backup first, before any wipe.
- First aid covers F11 "Refresh your PC" / "Reset your PC" and the WIMBoot layout.
- Restore Windows recommends HP recovery media (factory 8.1, WIMBoot, drivers). It warns that Windows 10 is
  unsupported and may not activate with the 8.1 key, and can add a Stream 7 drivers folder to the stick.
- The tablet-side files moved to `lazarus7\windows\` and `lazarus7\linux\` on the stick.

### Added
- **Make a tablet toolkit USB**: copies the helpers onto an existing stick without erasing it.
- `Stream7-Check.cmd`, run on the tablet under Windows 8.1 or 10. It saves a private report (serial, product number,
  firmware Windows key, activation, WIMBoot, BitLocker, partitions). It can also turn off Fast Startup, open the
  Recovery Drive creator (to copy the recovery partition), and install drivers from `\Drivers`.

## [1.2.0] - 2026-11-27

### Added
- Website shows the current release version, its release date and when the site was last updated.
- Changelog section on the website, rendered from this file.
- Release workflow fails if the tag doesn't match the tool's version, and uses this changelog as the release notes.

## [1.1.0] - 2026-11-26

### Added
- GitHub Pages site: Diagnose wizard in the browser, WebUSB tablet identification, first aid, OS compatibility table.
- One-line web launcher: `irm https://lance6x5.github.io/Lazarus7/run.ps1 | iex`. It downloads the latest release,
  verifies its SHA256, installs to `%LOCALAPPDATA%\Lazarus7\<version>` and starts the wizard (`-DryRun` supported).
- Release workflow: pushing a `v*` tag runs the Pester tests, then publishes `Lazarus7.zip` and `Lazarus7.zip.sha256`.

### Fixed
- CI pins the Pester 3.4.0 that ships with Windows, so the tests run the same in CI as on a stock PC.

## [1.0.0] - 2026-11-26

### Added
- Interactive Windows wizard (`Lazarus7.cmd`) for the HP Stream 7 (TSW 7H) and the HP Slate 7 family.
- Diagnose: maps the tablet's symptoms to a concrete next step.
- Identify: read-only USB scan for Rockchip loader, Tegra APX, ADB/fastboot, and missing drivers.
- USB builder for the Stream 7's 32-bit UEFI: FAT32, checks for `BOOTIA32.EFI`, splits `install.wim` over 4 GB.
- Debian 12 i386 deployment with a SHA256-verified download, plus a tablet-side post-install script.
- Android tools: adb/fastboot (Google signature verified), sideload, flash, and the Rockchip flasher flow.
- Dry-run mode, typed confirmations before destructive steps, Pester tests, field guide.

[1.4.0]: https://github.com/lance6x5/Lazarus7/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/lance6x5/Lazarus7/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/lance6x5/Lazarus7/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/lance6x5/Lazarus7/compare/1e4055e...v1.1.0
[1.0.0]: https://github.com/lance6x5/Lazarus7/commit/1e4055e
