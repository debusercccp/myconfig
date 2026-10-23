#!/usr/bin/env bash
# Load nvidia after root is mounted, so the runtime-PM udev rule applies — run with: sudo bash ~/nvidia-pm-fix.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

cp -n /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
# nvidia in the initramfs binds before /etc/udev/rules.d exists; it's only needed there for early KMS,
# which isn't used (nvidia_drm is blacklisted, Intel drives the display)
sed -i 's/^MODULES=(nvidia nvidia_uvm)/MODULES=()/' /etc/mkinitcpio.conf
grep ^MODULES /etc/mkinitcpio.conf
mkinitcpio -P

# apply now too, without waiting for the reboot
echo auto > /sys/bus/pci/devices/0000:01:00.0/power/control
sleep 5
echo "runtime_status: $(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status)  (want: suspended)"
