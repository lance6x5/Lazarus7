# Lazarus7 field guide: HP "TSW 7H" tablet recovery and alternative OSes

The manual version of everything the Lazarus7 tool automates. Useful when you want to understand a step,
or do it by hand.

## 0. Which tablet is this?

**TSW 7H is the label code on the HP Stream 7 (model 5701).** That's a *Windows* tablet:

| Spec | HP Stream 7 (TSW 7H) |
|---|---|
| SoC | Intel Atom Z3735G (Bay Trail), 64-bit CPU |
| Firmware | **32-bit UEFI only**: it boots only `EFI\BOOT\BOOTIA32.EFI` |
| RAM / storage | 1 GB / 32 GB eMMC (soldered), micro-SD slot |
| Ports | One micro-USB (charging + OTG host). It **does not show up on a PC.** |
| Stock OS | Windows 8.1 with Bing (upgradable to Windows 10 32-bit) |

The Android "HP Slate 7" tablets (2800 Rockchip, HD, Extreme/Plus Tegra 4) recover in a completely
different way (see section 5). If yours ran Android, not Windows, skip to that section.

---

## 1. Triage: what does "bricked" look like?

| Symptom | Likely cause | Go to |
|---|---|---|
| Totally dead, no charging icon | Deep-discharged battery (very common on this model) | 2a |
| HP logo, then black / boot loop | Corrupt Windows or a failed Win10 upgrade | 2b, 3 |
| Blue BitLocker / recovery-key screen | Device encryption is on | 2c |
| "Enter password" before HP logo | BIOS password set | 2d |
| Boots, but no OS ("No bootable device") | OS wiped or the EFI NVRAM entry was lost | 3 or 4 |
| Nothing at all after a long charge and a different charger | Battery or eMMC failure. Hardware, not software. | n/a |

## 2. First-aid steps (no tools needed)

### 2a. Revive a dead battery
1. Use a **2 A** wall charger and a short, good micro-USB cable (not a PC port).
2. Leave it plugged in for **4 hours or more**. A deeply drained Bay Trail tablet can show nothing for the first hour.
3. Hard reset: hold **Power for 15–30 s**, release, then hold Power for 5 s to boot.
4. Still nothing? Try another charger and cable. If you never see a battery icon, the battery is dead.
   It's a cheap part (search "HP Stream 7 battery 5701"), but replacing it means opening the case.

### 2b. Get into the firmware menus
With the tablet **off**: hold **Volume Down**, then press **Power** until the HP logo appears, then let go of Power.
You'll see a touch-friendly Startup Menu:

- **F9**: Boot device options (pick the USB stick)
- **F10**: BIOS setup (System Configuration > Boot Options: Secure Boot, boot order with F5/F6)
- **F11**: HP System Recovery (factory restore, if the recovery partition still exists)
- **F2**: Hardware diagnostics (run the eMMC/storage test here first)

If **F11** works, use it: it restores Windows 8.1 from the hidden partition and you're done.

### 2c. BitLocker recovery screen
The key is in the Microsoft account that set the tablet up: <https://account.microsoft.com/devices/recoverykey>.
Without the key the data is gone, but you can still reinstall (section 3 or 4).

### 2d. BIOS password
Enter a wrong password 3 times and the tablet usually shows a **halt code**. HP Support can generate an
unlock code from that and the serial number if you prove ownership. There's no software bypass.

---

## 3. Restore Windows (stock)

What you need: **micro-USB OTG adapter**, a **powered USB hub**, a USB keyboard (helps), and a USB stick of 8 GB or more.

**Option A: HP recovery image (official, Windows 8.1)**
1. Order or download recovery media from HP's support site using the tablet's **serial + product number**
   (on the back label or the F10 BIOS screen). Search "HP Recovery Media" + your product number.
2. Build the stick: launch `Lazarus7.cmd` → **Build Windows recovery USB** → **HP recovery files**.
3. On the tablet: Vol-Down + Power → **F9** → USB stick.

**Option B: Windows 10 32-bit (x86) ISO.** It works, but Windows 10 is out of support now (since Oct 2025;
consumer ESU ended Oct 2026). Install drivers from HP's Stream 7 SoftPaqs afterwards. With 1 GB RAM and 32 GB eMMC
it's slow and fills up after updates. **Windows 11 is impossible** (64-bit only, and this firmware is 32-bit UEFI).
`install.wim` may exceed FAT32's 4 GB limit. Lazarus7 detects this and splits it into `.swm` parts with DISM.

---

## 4. Alternative OSes: what actually works

The 32-bit UEFI is the main constraint: the boot medium needs `BOOTIA32.EFI`. Most mainstream ISOs
lack it. Disable **Secure Boot** in F10 first.

| OS | Verdict | Notes |
|---|---|---|
| **Debian 12 i386** | ✅ Recommended (Lazarus7 default) | Debian wiki has a Stream 7 page. WiFi, touch, audio, display work. Suspend and backlight need the fix in the post-install script. Security support (LTS) runs to mid-2028. |
| Debian 13 amd64 | ❌ Not out of the box | Debian 13 dropped i386 installers, and the amd64 netinst has only `BOOTX64.EFI` (checked on 13.8). It needs a hand-built ia32 GRUB to boot. |
| Lubuntu / Xubuntu | ⚠️ Works with surgery | ISO has no `bootia32.efi`, so you add GRUB ia32 by hand. Installer often forgets `/boot/efi/EFI/ubuntu/grubia32.efi`. |
| Alpine / Arch (with `grub --target=i386-efi`) | ⚠️ DIY | Fine if you're comfortable with a manual install. Light on 1 GB of RAM. |
| Android-x86 / Bliss OS | ⚠️ Experimental | Needs an ia32 GRUB. Touch and rotation are hit-and-miss. |
| ChromeOS Flex, Fedora, Windows 11 | ❌ | No 32-bit UEFI support. |

**Desktop choice for 1 GB RAM:** Xfce or LXQt plus the `onboard` on-screen keyboard is much snappier than GNOME.
Phosh is touch-native but heavy. The post-install script enables **zram**, which helps a lot.

**Good jobs for a Linux Stream 7:** Home Assistant or Grafana wall panel (Firefox kiosk mode), KlipperScreen or OctoPrint
display for a 3D printer, e-reader (Foliate/KOReader), digital photo frame, or a serial/USB console
for embedded work.

### Debian install, step by step
1. Launch `Lazarus7.cmd` → **Deploy Linux** → **Debian 12 i386**. It downloads the latest 12.x netinst from
   cdimage.debian.org, verifies the SHA256, writes the stick, and copies the post-install script to `\lazarus7\`.
2. (Lazarus7 checks that the stick has `EFI\BOOT\BOOTIA32.EFI`.)
3. If Windows still boots, turn off **Fast Startup** first (Control Panel > Power Options).
4. Tablet: Vol-Down + Power → **F10** → System Configuration > Boot Options → **Secure Boot: Disabled**. Then F10 to save.
5. Vol-Down + Power → **F9** → USB stick. Use the hub plus keyboard during install. WiFi is 2.4 GHz only.
6. Partitioning: "use entire disk" is fine. **This deletes the Windows recovery partition**, so you can't go back to
   Windows without an HP recovery stick. Make one first if you care.
7. After first boot, plug the stick back in and run the script Lazarus7 put on it:
   ```bash
   sudo sh /media/$USER/LAZARUS7/lazarus7/stream7-debian-postinstall.sh --backlight
   ```
   This installs firmware, zram, the rotation sensor and the OSK. It also installs GRUB to the removable fallback path,
   so a lost NVRAM entry can't "brick" it again, and applies the backlight/suspend fix.

---

## 5. If it's actually an Android HP Slate 7

Plug it into the PC and use Lazarus7 → **Identify my tablet** while trying the button combos. It tells you which
chip is talking, and **Flash / recover Android Slate 7** wraps adb, fastboot and the Rockchip flasher:

| Model | Chip | Recovery mode | Tool |
|---|---|---|---|
| Slate 7 2800 | Rockchip RK3066 (USB VID 2207) | Hold Vol+ (or Vol+ and Vol−) while plugging in USB | Rockchip **DriverAssistant** + **RKDevTool/RKBatchTool** (Windows), `rkdeveloptool` / `upgrade_tool` (Linux) |
| Slate 7 Extreme / Plus | NVIDIA Tegra 4 (VID 0955) | APX: Vol− and Power | NVIDIA `nvflash`. Needs device-specific blobs, so recovery is hard. |
| Any, if ADB/fastboot appears | Google VID 18D1 | Power + Vol+ (+Vol−) for stock recovery | Android platform-tools: `adb sideload` an HP OTA zip |

HP's original Slate 7 2800 firmware links are mostly dead. Third-party mirrors exist. Verify checksums, and match
the exact board revision before flashing.

---

## Sources
- Debian wiki, HP Stream 7 on Bookworm: <https://wiki.debian.org/InstallingDebianOn/HP/Stream%207/Bookworm>
- Stream 7 install notes: <https://newscrewdriver.com/2022/01/19/miscellaneous-notes-on-hp-stream-7-installation/>
- HP Community, Stream 7 recovery image: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/Does-anybody-have-a-recovery-image-of-Stream-7/td-p/4708928>
- HP Community, Linux on Stream (grubia32 issue): <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Ready-Only/Linux-on-the-HP-Stream-tablet/td-p/6675613>
- Zorin forum, Secure Boot / USB boot on Stream 7: <https://zoringroup.com/forum/5/14670/>
- XDA, Slate 7 2800 stock ROM: <https://forum.xda-developers.com/showthread.php?t=2608181>
- CNX Software, Rockchip flashing on Linux: <https://www.cnx-software.com/2013/11/19/how-to-flash-rockchip-rk3066-rk3188-firmware-in-linux/>
