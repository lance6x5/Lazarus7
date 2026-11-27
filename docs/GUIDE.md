# Lazarus7 field guide: HP Stream 7 (TSW 7H)

The manual version of everything the Lazarus7 tool automates, for the **HP Stream 7** that shipped with
**Windows 8.1 with Bing**. Useful when you want to understand a step or do it by hand.

## 0. Know your tablet

| Spec | HP Stream 7 (label `TSW 7H`) |
|---|---|
| Models | **5701** (most common) and **5709**. Check the back label, because drivers differ. |
| SoC | Intel Atom Z3735G (Bay Trail), 64-bit CPU |
| Firmware | **32-bit UEFI only**: it boots only `EFI\BOOT\BOOTIA32.EFI`, with no legacy/CSM mode |
| RAM / storage | 1 GB / 32 GB eMMC (soldered), micro-SD slot |
| Ports | One micro-USB (charging + OTG host). It **never shows up on a PC.** |
| Stock OS | **Windows 8.1 with Bing**, 32-bit, installed in **WIMBoot** mode. The product key is stored in the firmware. |
| Hardware | Realtek RTL8723BS Wi-Fi/BT (2.4 GHz only), Realtek RT5645 audio, Goodix touch, Kionix accelerometer |

### WIMBoot in one paragraph (read this before you delete anything)
To fit Windows on 32 GB, HP shipped the Stream 7 in **WIMBoot** mode. The C: drive holds only about 4 GB of
pointer files. The real Windows files sit compressed inside `install.wim` and `custom.wim` on the roughly **5 GB
recovery partition**. So that partition isn't just a backup: **it is Windows 8.1**. Delete it, and 8.1 stops booting
and F11 recovery disappears with it. Lazarus7's tablet helper reports whether your tablet is WIMBoot.

---

## 1. Triage: what does "bricked" look like?

| Symptom | Likely cause | Go to |
|---|---|---|
| Totally dead, no charging icon | Deep-discharged battery (very common on this model) | 2a |
| HP logo, then black screen / boot loop | Corrupt Windows, failed Windows 10 upgrade, or a failing eMMC | 2b, 2e, 4 |
| Automatic Repair loop / "Your PC ran into a problem" | Damaged Windows files, often a full or failing eMMC | 2b, 2e |
| Blue BitLocker / recovery-key screen | Device Encryption (on by default with a Microsoft account) | 2c |
| Forgot the Windows sign-in | Microsoft or local account password | 2f |
| "Enter password" **before** the HP logo | BIOS password set | 2d |
| "No bootable device" | Windows wiped (often the WIMBoot partition was deleted) or the UEFI entry was lost | 4 or 5 |
| Nothing after a long charge and a different charger | Battery or board failure: hardware, not software | n/a |

## 2. First aid (no tools needed)

### 2a. Revive a dead battery
1. Use a **2 A** wall charger and a short, good micro-USB cable (not a PC port).
2. Leave it plugged in for **4 hours or more**. A deeply drained Bay Trail tablet can show nothing for the first hour.
3. Hard reset: hold **Power for 15–30 s**, release, then hold Power for 5 s to boot.
4. Still nothing? Try another charger and cable. If you never see a battery icon, the battery is dead.
   It's a cheap part (search "HP Stream 7 battery 5701"), but replacing it means opening the case.

### 2b. The startup menu
With the tablet **off**: hold **Volume Down**, then press **Power** until the HP logo appears, then let go of Power.
The Startup Menu is touch-friendly:

- **F2**: Hardware diagnostics. Run the storage (eMMC) test first; boot loops are often a dying eMMC.
- **F9**: Boot device options (pick a USB stick)
- **F10**: BIOS setup (System Configuration > Boot Options: Secure Boot, boot order with F5/F6)
- **F11**: Windows 8.1 recovery environment (see 2e)

### 2c. BitLocker recovery screen
Windows 8.1 with Bing turns on **Device Encryption** when you sign in with a Microsoft account. The key is saved
there: <https://account.microsoft.com/devices/recoverykey>. Without it the data is gone, but **Reset your PC** (2e)
or a recovery USB (4) still works.

### 2d. BIOS password
Enter a wrong password 3 times and the tablet usually shows a **halt code**. HP Support can generate an
unlock code from that and the serial number if you prove ownership. There's no software bypass.

### 2e. Refresh or Reset Windows 8.1 (F11)
Vol-Down + Power → **F11** → **Troubleshoot**:
- **Refresh your PC** reinstalls Windows but **keeps your files** (desktop apps are removed). Try this first.
- **Reset your PC** erases everything and returns the tablet to the factory Windows 8.1 image.

Both need the WIMBoot recovery partition. If they fail with "a required drive partition is missing", that partition
is damaged or gone: use a recovery USB (section 4).

### 2f. Forgot the Windows sign-in
- **Microsoft account:** reset the password at <https://account.live.com/password/reset> from another device. Then
  connect the tablet to Wi-Fi from the sign-in screen (network icon, bottom right) and sign in with the new one.
- **Local account without a password reset disk:** no safe bypass. **Reset your PC** (2e) erases data and restores 8.1.

---

## 3. Back up Windows 8.1 before you change anything

Do this while Windows still boots. You need a **micro-USB OTG adapter**, a **powered USB hub** and **two USB sticks**
(8 GB+ each).

1. On your PC, launch `Lazarus7.cmd` → **Make a tablet toolkit USB**. This copies the helpers onto stick #1 without
   erasing it.
2. On the tablet, open File Explorer → the stick → `lazarus7\windows` → double-tap **`Stream7-Check.cmd`** and allow
   admin. It shows and saves `lazarus7\reports\Stream7-<serial>-<date>.txt` with:
   model, **product number**, **serial** (both needed to order HP recovery media), **firmware Windows key**,
   activation, **WIMBoot yes/no**, BitLocker status, free space and the partition list. *Keep that file private.*
3. In the helper choose **2 – Make a Windows recovery drive**. Use **stick #2**, because it gets erased. In the wizard,
   **tick "Copy the recovery partition from the PC to the recovery drive"**. That stick now holds your factory
   Windows 8.1 and boots with F9.
4. Before installing another OS, choose **1 – Turn off Fast Startup + hibernation**. Linux needs this, and it also frees
   space on C:.

---

## 4. Restore Windows

**Already made a recovery drive (section 3)?** It boots as-is: Vol-Down + Power → **F9** → the stick.

**Option A: HP recovery media (recommended).** This restores the factory **Windows 8.1 with Bing (WIMBoot) with every
tablet driver**.
1. Order or download it from HP using the **serial + product number** (on the back label, in the F10 BIOS screen, or in
   the Stream7-Check report). Search "HP Recovery Media" + your product number.
2. Launch `Lazarus7.cmd` → **Restore Windows (recovery USB)** → **HP recovery files**.
3. Tablet: Vol-Down + Power → **F9** → the stick.

A generic Windows 8.1 ISO is **not** a substitute. It isn't WIMBoot or compressed, has no tablet drivers, and barely
fits in 32 GB.

**Option B: Windows 10 32-bit (x86).** Go in with eyes open:
- Windows 10 is **out of support since Oct 2025**, and the 1 GB / 32 GB hardware struggles with feature updates.
- Setup reads the 8.1 key from the firmware and installs **Windows 10 Home 32-bit**. But Microsoft **stopped honoring
  Windows 7/8.x keys for upgrades in 2023**, so a clean install may stay unactivated. The best odds come from an
  **in-place upgrade** from a working 8.1 first: check activation under Settings → System → About, *then* do a clean
  install.
- **Touch does not work inside Windows Setup.** Use a keyboard (and mouse) on the powered hub.
- **Drivers:** download HP's packages for the *Stream 7 Tablet – 5701* (or 5709) before you start. Lazarus7 can copy a
  drivers folder to `\Drivers` on the stick, and the tablet helper's option 3 installs them. Install the **chipset /
  Driver Pack first**, then Goodix touch, Realtek audio, Bluetooth and the Kionix sensor. Reboot only at the end.
- Pause Windows Update until touch and audio are confirmed working; some feature updates broke the HP drivers.
- `install.wim` may exceed FAT32's 4 GB limit. Lazarus7 splits it into `.swm` parts with DISM.
- **Windows 11 is impossible**: it's 64-bit only, and this firmware is 32-bit UEFI.

---

## 5. Give it a second life: Linux

The 32-bit UEFI is the main constraint: the boot medium needs `BOOTIA32.EFI`, which most mainstream ISOs lack.
Disable **Secure Boot** in F10 first.

| OS | Verdict | Notes |
|---|---|---|
| **Debian 12 i386** | ✅ Recommended (Lazarus7 default) | The Debian wiki has a Stream 7 page. WiFi, touch, audio and display work. Suspend and backlight need the post-install fix. Security support (LTS) runs to mid-2028. |
| Debian 13 amd64 | ❌ Not out of the box | Debian 13 dropped i386 installers, and the amd64 netinst has only `BOOTX64.EFI` (checked on 13.8). |
| Lubuntu / Xubuntu | ⚠️ Works with surgery | The ISO has no `bootia32.efi`; add GRUB ia32 by hand. The installer often forgets `/boot/efi/EFI/ubuntu/grubia32.efi`. |
| Alpine / Arch (with `grub --target=i386-efi`) | ⚠️ DIY | Fine if you're comfortable with a manual install. Light on 1 GB of RAM. |
| Android-x86 / Bliss OS | ⚠️ Experimental | Needs an ia32 GRUB. Touch and rotation are hit-and-miss. |
| ChromeOS Flex, Fedora, Windows 11 | ❌ | No 32-bit UEFI support. |

**Desktop choice for 1 GB RAM:** Xfce or LXQt plus the `onboard` on-screen keyboard is much snappier than GNOME.
The post-install script enables **zram**, which helps a lot.

**Good jobs for a Linux Stream 7:** a Home Assistant or Grafana wall panel (Firefox kiosk mode), a KlipperScreen or
OctoPrint display for a 3D printer, an e-reader (Foliate/KOReader), a digital photo frame, or a serial console.

### Debian install, step by step
1. **Back up Windows 8.1 first (section 3).** Debian's "use entire disk" deletes the WIMBoot recovery partition, which
   *is* Windows 8.1.
2. Launch `Lazarus7.cmd` → **Deploy Linux** → **Debian 12 i386**. It downloads the latest 12.x netinst from
   cdimage.debian.org, verifies the SHA256, checks for `BOOTIA32.EFI`, writes the stick, and adds the tablet helpers
   under `\lazarus7\`.
3. Tablet: Vol-Down + Power → **F10** → System Configuration > Boot Options → **Secure Boot: Disabled** → F10 to save.
4. Vol-Down + Power → **F9** → the stick. Use the hub plus keyboard during install. WiFi is 2.4 GHz only.
5. After first boot, plug the stick back in and run:
   ```bash
   sudo sh /media/$USER/LAZARUS7/lazarus7/linux/stream7-debian-postinstall.sh --backlight
   ```
   This installs firmware, zram, the rotation sensor and the OSK. It also installs GRUB to the removable fallback path,
   so a lost NVRAM entry can't "brick" it again, and applies the backlight/suspend fix.

---

## Appendix: Android HP Slate 7 tablets

Not a Stream 7, but Lazarus7 keeps tools for them under **Other HP tablets: Android Slate 7**. Plug the tablet into
the PC and use **Identify a tablet over USB** while trying the button combos:

| Model | Chip | Recovery mode | Tool |
|---|---|---|---|
| Slate 7 2800 | Rockchip RK3066 (USB VID 2207) | Hold Vol+ (or Vol+ and Vol−) while plugging in USB | Rockchip **DriverAssistant** + **RKDevTool/RKBatchTool** |
| Slate 7 Extreme / Plus | NVIDIA Tegra 4 (VID 0955) | APX: Vol− and Power | NVIDIA `nvflash`. Needs device-specific blobs, so recovery is hard. |
| Any, if ADB/fastboot appears | Google VID 18D1 | Power + Vol+ (+Vol−) for stock recovery | Android platform-tools: `adb sideload` an HP OTA zip |

---

## Sources
- Debian wiki, HP Stream 7 on Bookworm: <https://wiki.debian.org/InstallingDebianOn/HP/Stream%207/Bookworm>
- HP Community, replacing Win 8.1 Bing WIMBoot: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/How-do-I-replace-Win-8-1-Bing-quot-WIMBoot-quot-with/td-p/5010315>
- HP Community, Stream 7 Windows 10 / can't recover 8.1: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/HP-Stream-7-Windows-10-doesn-t-boot-I-can-t-recovery-8-1/td-p/4968314>
- HP Community, Windows 10 fresh install on the Stream tablet: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/Windows-10-fresh-installation-on-the-HP-Stream-tablet/td-p/5190867>
- HP drivers, Stream 7 Tablet 5701: <https://support.hp.com/us-en/drivers/selfservice/hp-stream-tablets/7439994/model/7482041>
- Windows 10 Forums, Stream 7 install: <https://www.tenforums.com/installation-upgrade/42673-windows-10-installation-hp-stream-7-tablet.html>
- Stream 7 install notes: <https://newscrewdriver.com/2022/01/19/miscellaneous-notes-on-hp-stream-7-installation/>
- HP Community, Linux on Stream (grubia32 issue): <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Ready-Only/Linux-on-the-HP-Stream-tablet/td-p/6675613>
- XDA, Slate 7 2800 stock ROM: <https://forum.xda-developers.com/showthread.php?t=2608181>
