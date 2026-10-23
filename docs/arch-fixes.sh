#!/usr/bin/env bash
# Arch tune-up — run with: sudo bash ~/arch-fixes.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

step() { printf '\n\e[1;34m==> %s\e[0m\n' "$*"; }

step "1. networkd-wait-online: wait for any one link, 10s timeout"
mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
cat > /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any --timeout=10
EOF
systemctl daemon-reload
systemctl reset-failed systemd-networkd-wait-online.service || true

step "2. Clean pacman cache + enable weekly paccache"
paccache -rk2
paccache -ruk0
systemctl enable --now paccache.timer

step "3. Enable weekly TRIM"
systemctl enable --now fstrim.timer

step "4. Snapper config for /home"
if snapper list-configs | grep -qw home; then
  echo "home config already exists"
else
  snapper -c home create-config /home
  # fewer timeline snapshots for /home than the defaults
  snapper -c home set-config TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 \
    TIMELINE_LIMIT_WEEKLY=2 TIMELINE_LIMIT_MONTHLY=1 TIMELINE_LIMIT_YEARLY=0
fi

step "5. Reflector: Italy + neighbours, fastest HTTPS mirrors, weekly"
cp -n /etc/xdg/reflector/reflector.conf /etc/xdg/reflector/reflector.conf.bak
cat > /etc/xdg/reflector/reflector.conf <<'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--country Italy,Switzerland,Austria,France,Germany
--latest 10
--sort rate
EOF
systemctl enable reflector.timer
systemctl start reflector.service || echo "reflector run failed; mirrorlist left unchanged"

step "6. pacman: ParallelDownloads 5 -> 10"
sed -i 's/^ParallelDownloads = .*/ParallelDownloads = 10/' /etc/pacman.conf

step "7. Install packages (fwupd, CLI tools)"
pacman -S --needed --noconfirm fwupd fzf zoxide eza fd pkgfile man-db
pkgfile -u
mandb -q || true

step "8. Firmware: check what's available (does NOT flash)"
fwupdmgr refresh --force || true
fwupdmgr get-updates || true

step "9. NVIDIA dGPU: allow runtime suspend (compute-only, sleeps when idle)"
cat > /etc/udev/rules.d/80-nvidia-pm.rules <<'EOF'
# Runtime PM for the NVIDIA GPU so it powers off when no CUDA process is using it
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
EOF
udevadm control --reload
echo auto > /sys/bus/pci/devices/0000:01:00.0/power/control
systemctl disable --now nvidia-persistenced.service 2>/dev/null || true  # keeps the GPU awake
sleep 5
echo "runtime_status: $(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status)  (want: suspended)"

printf '\n\e[1;32mDone.\e[0m Firmware was only checked; apply with: fwupdmgr update\n'
