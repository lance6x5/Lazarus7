# Lazarus7 field guide: HP Stream 7 (TSW 7H)

The manual version of everything the Lazarus7 tool automates, for the **HP Stream 7** that shipped with
**Windows 8.1 with Bing**. Useful when you want to understand a step or do it by hand.

> **Use at your own risk.** This guide is for information and help only, provided "as is" without warranty. Recovering,
> flashing or reinstalling a device can erase your data, make it unusable or void its warranty, and some steps here
> come from unconfirmed community reports. The authors are not liable for any damage or loss. Back up first. See
> [DISCLAIMER.md](../DISCLAIMER.md).

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
| HP logo, then a **blank black screen** | Windows failing to start (display driver, damaged WIMBoot files), a failing eMMC, or rarely the backlight | 2g |
| Error **0xc0000225** "Your PC needs to be repaired" (also from F11) | Boot files or the WIMBoot partition unreachable: eMMC, deleted partition, or broken BCD | 2h |
| HP logo keeps coming back (boot loop) | Corrupt Windows, failed Windows 10 upgrade, or a failing eMMC | 2b, 2e, 4 |
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

### 2g. HP logo, then a blank black screen
Work down the list. Each step tells you which part is broken.
1. **Charge and wait.** Charge for 2+ hours, power on, then wait a full **15 minutes**. On this slow eMMC, Windows
   Update or Automatic Repair can run behind a black screen.
2. **Is Windows alive?** With a USB keyboard on the OTG adapter, press **Ctrl+Alt+Del**, then **Win+Ctrl+Shift+B**
   (restarts the graphics driver). If anything appears, Windows works and the display driver is at fault.
3. **Flashlight test.** Shine a torch at the screen at an angle. A faint picture means the **backlight** failed, which
   is hardware.
4. **Startup menu** (Vol-Down + Power). If it shows, the firmware and screen are fine. Then:
   - **F2:** run the storage (eMMC) test. A dying eMMC causes exactly this symptom.
   - **F11 → Troubleshoot → Advanced options:** try **Startup Repair**. Then try **Startup Settings → Enable
     low-resolution video**, or **Safe Mode**, to rule out the display driver. Last resort: **Refresh your PC** (2e).
5. **F11 also black, or "a required drive partition is missing"?** The WIMBoot recovery partition is damaged. Boot from
   USB instead (section 4 or 5). If a Debian stick shows a picture, the hardware is fine and only Windows is broken.
   For **0xc0000225**, see 2h.

### 2h. Error 0xc0000225: "Your PC needs to be repaired, a required device isn't connected or can't be accessed"
The boot manager can't reach the files it needs. If **F11** shows this too, both of Windows' start paths are broken,
so the fix has to come from USB. Causes, most serious first:
- a **failing eMMC**;
- a **damaged or deleted WIMBoot recovery partition** (common after a failed Windows 10 upgrade or a partition tool);
- a **corrupted boot configuration (BCD)**, which is fixable.

1. **Vol-Down + Power → F2 → storage test.** If the eMMC fails, stop: no software fixes that.
2. **Make a repair stick.** Get Microsoft's **Windows 10 32-bit (x86)** ISO (Media Creation Tool), then use
   `Lazarus7.cmd` → **Restore Windows → Windows 10 x86 ISO**. Every Lazarus7 stick carries the repair helper in
   `\lazarus7\windows\`.
3. **Boot it** (Vol-Down + Power → **F9**, with a USB keyboard because touch doesn't work). Choose **Repair your
   computer** (*not* Install) → Troubleshoot → **Startup Repair**.
4. **Still failing?** Troubleshoot → **Command Prompt**, then run the helper (the stick may be `E:` or `F:`, check with
   `dir D:\lazarus7`):
   ```bat
   D:\lazarus7\windows\Stream7-Repair.cmd
   ```
   It **only looks** until the last step:
   1. it lists the eMMC's partitions;
   2. it finds Windows (or tells you BitLocker has locked it: `manage-bde -unlock C: -RecoveryPassword <key>`);
   3. it checks the **WIMBoot** links with `dism /Get-WIMBootEntry`;
   4. it checks the EFI partition and the **BCD** store, with an optional read-only `chkdsk`;
   5. only if you type `REPAIR`, it runs `bcdboot <Windows>\Windows /s S: /f UEFI`.

   Everything is logged to `\lazarus7\reports\` on the stick.
5. **Reading the result:**
   - **BCD missing, Windows and WIMBoot partition present:** step 5 should bring normal boot back.
   - **WIMBoot partition gone:** Windows 8.1 can't start again, and rebuilding boot files won't help. Restore from
     recovery media (section 4) or install a new OS (Windows 10 x86, or Debian, section 5).
   - **No Windows volume and no BitLocker:** Windows was erased, so it's the same choice.

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

### Can a Windows PC recover the Stream 7 over a USB cable?
**No, not directly.** On Windows-only Bay Trail tablets like the Stream 7, the micro-USB port works only for
charging and as a **host** (OTG) port. The external "device/gadget mode" PHY is missing, so the tablet never shows up
on a PC. Intel's DnX flashing mode may appear on screen on some Bay Trail tablets, but it doesn't work on these units,
and HP documents no PC-to-tablet flashing tool. The eMMC is soldered, so it can't be pulled and written on a PC either.

What *does* work, and what Lazarus7 automates: the **PC prepares a USB stick**, and the **tablet boots it** through
the OTG adapter (Vol-Down + Power → **F9**). For Windows recovery, that stick is your recovery drive or HP media.

### Keep a verified copy of your recovery drive on the PC
Recovery sticks fail, and replacement media for this tablet is hard to get. Once you've made the recovery drive
(section 3), plug it into the PC and run `Lazarus7.cmd` → **Restore Windows** → **Save a recovery USB to this PC**.
Lazarus7 copies it to `Documents\Lazarus7\Backups\Stream7-Recovery-<date>`, hashes every file (SHA256), and re-reads
the stick to prove the copy matches. Later, **Restore Windows → A recovery backup saved on this PC** writes a fresh
stick. It verifies the backup before wiping anything, keeps the original volume label, and checks every file on
the new stick afterwards.

### Getting recovery media
**Already made a recovery drive (section 3)?** It boots as-is: Vol-Down + Power → **F9** → the stick.

**Option A: factory recovery media (recommended).** This restores the factory **Windows 8.1 with Bing (WIMBoot)
with every tablet driver**. Where to get it, best first:
1. **Your own recovery drive** (section 3), and the verified backup Lazarus7 keeps of it on your PC. This is the only
   source you fully control, so make it while Windows 8.1 still boots.
2. **HP Support.** HP supplied USB recovery media for its tablets through support channels. Ask with the **serial +
   product number** (back label, F10 BIOS screen, or the Stream7-Check report). Don't count on it for a 2014 tablet.
3. **Third-party "Stream 7 recovery kits"** are sold online. Buyers report mixed results, including kits meant for a
   different model, so check the exact model (5701 vs 5709) and the refund terms.
4. **Not available:** HP's **Cloud Recovery Tool**. Its supported-platforms list has no Stream 7 and no Windows 8.x
   images (only Windows 7/10/11), so it can't produce media for this tablet. Lazarus7 won't fetch images from
   file-sharing sites, because their contents can't be verified.

Then: `Lazarus7.cmd` → **Restore Windows** → **HP recovery media / a recovery drive (folder)**, or
**A recovery backup saved on this PC**. On the tablet: Vol-Down + Power → **F9** → the stick.

**Official links** (Lazarus7 deliberately doesn't link to copies of HP or Microsoft images. They can't legally be
redistributed, and unofficial copies can't be verified):
- HP Support (recovery media, BIOS unlock codes): <https://support.hp.com/us-en/contact>
- HP Stream 7 Tablet 5701 drivers and software: <https://support.hp.com/us-en/drivers/selfservice/hp-stream-tablets/7439994/model/7482041>
- Microsoft Windows 10 download, Media Creation Tool → 32-bit (x86) → ISO: <https://www.microsoft.com/en-us/software-download/windows10>
  (Microsoft's Windows 8.1 download page is gone; it returns 404.)
- Debian 12 i386 images (Lazarus7 fetches these itself): <https://cdimage.debian.org/cdimage/archive/>

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

## 5. Give it a second life: other operating systems

The 32-bit UEFI is the main constraint: the boot medium needs `BOOTIA32.EFI`, which most mainstream ISOs lack.
Disable **Secure Boot** in F10 first. Every entry below was checked against the actual image or package archive,
not just forum posts.

| OS | Verdict | Notes |
|---|---|---|
| **Debian 12 i386** (desktop) | ✅ Recommended (Lazarus7 default) | The Debian wiki has a Stream 7 page. WiFi, touch, audio and display work. Suspend and backlight need the post-install fix. Security support (LTS) runs to mid-2028. |
| **Debian 12 i386 + Kodi** (media center) | ✅ Best media option | Kodi 20.1, `i965-va-driver` (Bay Trail VA-API) and lightdm are all in Debian 12 i386. Lazarus7's script boots straight into Kodi in landscape. See 5b. |
| **Android-x86 9.0-r2, 32-bit** | ⚠️ Experimental | The ISO ships `EFI/BOOT/bootia32.efi` (checked), so it boots. Touch, Wi-Fi, sound and rotation are unconfirmed on a Stream 7. Android 9 gets no security updates. See 5c. |
| LibreELEC (Kodi OS) | ❌ | No official 32-bit-UEFI support; only a 2016 community build. Use Debian + Kodi instead. |
| Bliss OS / PrimeOS | ❌ | 64-bit Android builds. A 2026 report on a same-class Z3735F tablet shows boot freezes and dead touch. |
| Debian 13 amd64 | ❌ Not out of the box | Debian 13 dropped i386 installers, and the amd64 netinst has only `BOOTX64.EFI` (checked on 13.8). |
| Lubuntu / Xubuntu | ⚠️ Works with surgery | The ISO has no `bootia32.efi`; add GRUB ia32 by hand. The installer often forgets `/boot/efi/EFI/ubuntu/grubia32.efi`. |
| Alpine / Arch (with `grub --target=i386-efi`) | ⚠️ DIY | Fine if you're comfortable with a manual install. Light on 1 GB of RAM. |
| ChromeOS Flex, Fedora, Windows 11, Batocera | ❌ | No 32-bit UEFI support. |

**Desktop choice for 1 GB RAM:** Xfce or LXQt plus the `onboard` on-screen keyboard is much snappier than GNOME.
The post-install script enables **zram**, which helps a lot.

**Good jobs for a Linux Stream 7:** a Home Assistant or Grafana wall panel (Firefox kiosk mode), a KlipperScreen or
OctoPrint display for a 3D printer, an e-reader (Foliate/KOReader), a digital photo frame, or a serial console.

### Debian install, step by step
1. **Back up Windows 8.1 first (section 3).** Debian's "use entire disk" deletes the WIMBoot recovery partition, which
   *is* Windows 8.1.
2. Launch `Lazarus7.cmd` → **Deploy an OS** → **Debian 12 i386 - desktop**. It downloads the latest 12.x netinst from
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

### 5b. Media center: Debian 12 + Kodi
Turns the Stream 7 into a small Kodi box that boots straight into Kodi, in landscape, with touch working.
1. `Lazarus7.cmd` → **Deploy an OS** → **Debian 12 i386 - Kodi media center** (the same verified Debian stick).
2. Install Debian as in 5 (back up Windows first). At **Software selection**, *untick* the desktop and keep
   **standard system utilities**. Kodi brings its own interface, and skipping a desktop saves a lot of the 1 GB RAM.
3. Log in on the text console, mount the stick (there's no desktop to do it for you) and run both scripts:
   ```bash
   sudo mount /dev/sda1 /mnt
   sudo sh /mnt/lazarus7/linux/stream7-debian-postinstall.sh --backlight
   sudo sh /mnt/lazarus7/linux/stream7-media-center.sh
   sudo reboot
   ```
4. It boots into Kodi. The script:
   - installs Kodi 20 and `inputstream-adaptive`;
   - installs `i965-va-driver`, so H.264, MPEG-2 and VC-1 decode in hardware;
   - sets up lightdm auto-login into a **Lazarus7 Kodi** session, which rotates the portrait 800×1280 panel to
     landscape and maps the Goodix touchscreen to match.

Options: `--rotate left` (picture upside down), `--no-autologin` (choose the Kodi session at the login screen),
`--user NAME`. To undo auto-login: `sudo rm /etc/lightdm/lightdm.conf.d/50-lazarus7-kodi.conf`.

**Expectations:** 720p–1080p **H.264** plays smoothly with hardware decoding (check with `vainfo`). **HEVC/H.265 and
VP9** have no hardware support on this chip, so they will stutter: pick H.264 versions, or let your media server
transcode. Kodi works as a client for Jellyfin, Plex and DLNA/SMB shares, and for IPTV through add-ons. Sound is the
single mono speaker, or the headphone jack. Use Bluetooth or the jack for anything better.

### 5c. Android: Android-x86 9.0 (32-bit), experimental
Android-x86 9.0-r2 is the last Android-x86 release, and its 32-bit ISO carries a 32-bit EFI loader, so the Stream 7 can
boot it. **Nobody has confirmed touch, Wi-Fi (RTL8723BS), sound (RT5645) or rotation on a Stream 7 yet.** Android 9
(2018) gets no security updates, and a growing number of apps no longer support it.
1. `Lazarus7.cmd` → **Deploy an OS** → **Android-x86 9.0 (32-bit)**. It downloads `android-x86-9.0-r2.iso` from
   SourceForge and checks it against **two independent checksums**: SHA-1 from android-x86.org's release note and MD5
   from SourceForge. It deletes the file if either fails, then writes the stick.
2. Tablet: F10 → Secure Boot off, then F9 → the stick → **"Live CD - Run Android without installation"**. Live mode
   changes nothing on the tablet, so check touch, Wi-Fi and sound there first.
3. Black screen or hang? Reboot, highlight the entry, press **e**, add `nomodeset` to the `linux` line, and boot with
   **Ctrl+X** (or F10). The **Debug mode** entry shows where it stops.
4. Only if live mode works well, use **Installation** from the same menu. It erases Windows, so back up the recovery
   partition first (section 3).
5. Please report what worked (Lazarus7 → **Report a problem / request a feature** → *Tell us what worked*). That's how
   this entry gets upgraded from "experimental".

For Kodi under Android, install Kodi's Android build inside Android-x86. On this hardware, though, 5b is the more
dependable media setup.

---

## Appendix: Android HP Slate 7 tablets

Not a Stream 7, but Lazarus7 keeps tools for them under **Other HP tablets: Android Slate 7**. Plug the tablet into
the PC and use **Identify a tablet over USB** while trying the button combos:

| Model | Chip | Recovery mode | Tool |
|---|---|---|---|
| Slate 7 2800 | Rockchip RK3066 (USB VID 2207) | Hold Vol+ (or Vol+ and Vol−) while plugging in USB | Rockchip **DriverAssistant** + **RKDevTool/RKBatchTool** |
| Slate 7 Extreme / Plus | NVIDIA Tegra 4 (VID 0955) | APX: Vol− and Power | NVIDIA `nvflash`. Needs device-specific blobs, so recovery is hard. |
| Any, if ADB/fastboot appears | Google VID 18D1 | Power + Vol+ (+Vol−) for stock recovery | Android platform-tools: `adb sideload` an HP OTA zip |

### Button combos by model
All combos start with the tablet **off**. Confidence: **HP** = HP Support Community, **reported** = owners or
third-party guides, **generic** = standard Android or chip behavior, not confirmed on that model. The same data
(`docs/keycombos.json`) drives Lazarus7 → **Other HP tablets → Button combos** and the website.

| Model | Recovery | Flashing mode | Factory reset |
|---|---|---|---|
| Slate 7 **2800** (Rockchip) | Vol− + Vol+ + Power, release at HP logo *(HP)*; else Power + Vol+ | **Loader:** hold Vol+ while plugging USB into the PC, about 5 s *(reported)* | Recovery → wipe data/factory reset *(HP)* |
| Slate 7 **Extreme** 4400/4450 (Tegra 4) | Vol+ + Power, release at logo → boot menu *(reported)* | **Fastboot:** boot menu → Vol− → Power *(reported)*; `fastboot -i 0x03F0 devices`. **APX:** hold Vol+, press Power, release Vol+ *(generic)* | via recovery |
| Slate 7 **Plus** 4200 (Tegra 4) | Vol+ + Power, release at logo *(reported)* | Fastboot / APX as Extreme *(generic)* | via recovery |
| Slate 7 **4600/4601** | Vol+ + Vol− + Power, release at logo *(reported)* | – | via recovery |
| Slate 7 **VoiceTab** (Marvell) | Power + Vol+ until logo + vibration *(HP)* | – | Recovery → Vol− to Wipe data/factory reset → Power → Yes *(HP)* |
| Slate 7 **HD** (Marvell) | Try Power + Vol+, then Vol+ + Vol− + Power *(generic)* | – | via recovery |

**All models:** in recovery, Vol+/Vol− moves and Power selects (touch is off). On a **"No command"** screen, hold Power
and tap Vol+. Force restart: hold **Power 10–15 s**. Safe mode: hold Power → long-press **Power off** → OK.
Screenshot: **Power + Vol−**. From a PC with USB debugging: `adb reboot recovery` / `adb reboot bootloader`.
Leave APX by holding Power 10+ s. A factory reset may trigger the Google account lock (FRP).

---

## Sources
- Android-x86 9.0-r2 release note (SHA-1 checksums): <https://www.android-x86.org/releases/releasenote-9-0-r2.html>
- Android-x86 release files (SourceForge): <https://sourceforge.net/projects/android-x86/files/Release%209.0/>
- Debian package archive (kodi, i965-va-driver, lightdm for bookworm i386): <https://packages.debian.org/bookworm/kodi>
- LibreELEC forum, 32-bit UEFI support: <https://forum.libreelec.tv/thread/6602-32bit-efi-uefi-support-for-le/>
- CNX Software, 2016 LibreELEC community build for 32-bit UEFI: <https://www.cnx-software.com/2016/09/19/libreelec-8-for-intel-atom-bay-trail-and-cherry-trail-devices-with-32-bit-uefi-binary/>
- XDA, Z3735F tablet with Bliss OS / Android-x86 (boot freeze, touch): <https://xdaforums.com/t/sqool-tablet-intel-atom-z3735f-2gb-ram-silead-gsl1680-bcm43340-need-compatible-rom-android-x86-blissos-linux.4780720/>
- Hans de Goede, unbricking Bay/Cherry Trail tablets (DnX and the missing device-mode PHY): <https://hansdegoede.livejournal.com/25342.html>
- HP Stream 7 maintenance and service manual: <https://www.manualslib.com/manual/2199305/Hp-Stream-7.html>
- HP Cloud Recovery Tool supported platforms: <https://ftp.hp.com/pub/caps-softpaq/CloudRecovery/crsupportedplatform.html>
- Debian wiki, HP Stream 7 on Bookworm: <https://wiki.debian.org/InstallingDebianOn/HP/Stream%207/Bookworm>
- HP Community, replacing Win 8.1 Bing WIMBoot: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/How-do-I-replace-Win-8-1-Bing-quot-WIMBoot-quot-with/td-p/5010315>
- HP Community, Stream 7 Windows 10 / can't recover 8.1: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/HP-Stream-7-Windows-10-doesn-t-boot-I-can-t-recovery-8-1/td-p/4968314>
- HP Community, Windows 10 fresh install on the Stream tablet: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/Windows-10-fresh-installation-on-the-HP-Stream-tablet/td-p/5190867>
- HP drivers, Stream 7 Tablet 5701: <https://support.hp.com/us-en/drivers/selfservice/hp-stream-tablets/7439994/model/7482041>
- Windows 10 Forums, Stream 7 install: <https://www.tenforums.com/installation-upgrade/42673-windows-10-installation-hp-stream-7-tablet.html>
- Stream 7 install notes: <https://newscrewdriver.com/2022/01/19/miscellaneous-notes-on-hp-stream-7-installation/>
- HP Community, Linux on Stream (grubia32 issue): <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Ready-Only/Linux-on-the-HP-Stream-tablet/td-p/6675613>
- XDA, Slate 7 2800 stock ROM: <https://forum.xda-developers.com/showthread.php?t=2608181>
- HP Community, Slate 7 2800 recovery from the Android system recovery screen: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/Slate-7-2800-how-to-recover-from-Android-System-recovery/td-p/6361765>
- HP Community, Slate 7 (VoiceTab) recovery and factory reset steps: <https://h30434.www3.hp.com/t5/Tablets-and-Mobile-Devices-Archive-Read-Only/slate-7/td-p/6342385>
- XDA, Slate 7 Extreme root/flash (fastboot, HP vendor ID): <https://xdaforums.com/t/q-slate-7-extreme-root-flash-question.2752604/>
- XDA, Slate 7 Extreme stuck in APX mode: <https://xdaforums.com/t/hp-slate-7-extreme-stuck-in-apx-mode.3276011/>
- Open Surface RT, Tegra special boot modes (generic APX combo): <https://open-rt.gitbook.io/open-surfacert/common/boot-sequence/special-boot-modes>
- iFixit, HP Slate 7 4601 troubleshooting: <https://www.ifixit.com/Wiki/HP_Slate_7_4601_Troubleshooting>
- Droid Recovery, Slate 7 Plus recovery mode: <https://droidrecovery.com/hp-slate-7-plus-recovery-mode/>
