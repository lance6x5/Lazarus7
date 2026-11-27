#!/bin/sh
# Lazarus7 - Copyright (c) 2026 lance6x5
# SPDX-License-Identifier: MIT
#
# Post-install tweaks for Debian 12 (i386) on the HP Stream 7 (Atom Z3735G,
# 1 GB RAM, 32-bit UEFI). Lazarus7 copies this to \lazarus7\ on the USB stick.
# Run as root on the tablet after the first boot:
#
#   sudo sh stream7-debian-postinstall.sh              # safe defaults
#   sudo sh stream7-debian-postinstall.sh --backlight  # also apply the dracut
#                                                      # backlight/suspend fix
#
# Safe to re-run.
set -eu

APPLY_BACKLIGHT_FIX=0
[ "${1:-}" = "--backlight" ] && APPLY_BACKLIGHT_FIX=1

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root (sudo)." >&2
    exit 1
fi

# 1. Make sure the non-free-firmware component is enabled (WiFi RTL8723BS, audio).
if ! grep -rqs 'non-free-firmware' /etc/apt/sources.list /etc/apt/sources.list.d/; then
    echo "Enabling non-free-firmware in apt sources..."
    sed -i -E '/^deb /{/non-free-firmware/! s/$/ non-free-firmware/}' /etc/apt/sources.list
fi
apt-get update

# 2. Firmware, microcode, rotation sensor, on-screen keyboard, compressed swap.
#    zram matters a lot with only 1 GB of RAM.
apt-get install -y \
    firmware-realtek firmware-intel-sound firmware-misc-nonfree \
    intel-microcode alsa-ucm-conf iio-sensor-proxy onboard zram-tools

# zram: use half of RAM as compressed swap.
if [ -f /etc/default/zramswap ]; then
    sed -i -E 's/^#?\s*PERCENT=.*/PERCENT=50/; s/^#?\s*ALGO=.*/ALGO=zstd/' /etc/default/zramswap
    systemctl restart zramswap || true
fi

# 3. Bootloader robustness. This firmware is 32-bit UEFI and sometimes forgets
#    its NVRAM boot entries, which looks like a brick. Also installing GRUB to
#    the removable fallback path (EFI/BOOT/BOOTIA32.EFI) makes it always boot.
if [ "$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null)" = "32" ]; then
    apt-get install -y grub-efi-ia32
    echo "grub-efi-ia32 grub2/force_efi_extra_removable boolean true" | debconf-set-selections
    grub-install --target=i386-efi --efi-directory=/boot/efi --removable
    grub-install --target=i386-efi --efi-directory=/boot/efi
    update-grub
else
    echo "Not booted via 32-bit UEFI; skipping GRUB fallback step."
fi

# 4. Optional: the Debian-wiki fix for backlight control and suspend. It
#    replaces initramfs-tools with dracut and leaves i915 out of the initramfs.
#    Shutdown gets slightly slower. The first boot may drop to a debug shell;
#    hold Power to force off, then boot again.
if [ "$APPLY_BACKLIGHT_FIX" -eq 1 ]; then
    apt-get install -y dracut
    mkdir -p /etc/dracut.conf.d
    echo 'omit_drivers+=" i915 "' > /etc/dracut.conf.d/stream7-no-i915.conf
    dracut -f --regenerate-all
    echo "Backlight fix applied. Reboot to take effect."
fi

echo
echo "Done. Display tip (GNOME): Settings > Display, pick any 4:3 mode WITHOUT"
echo "applying, then pick 800x1280 (16:10) and Apply. This fixes oversized UI."
