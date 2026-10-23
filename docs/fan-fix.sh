#!/usr/bin/env bash
# Restore thinkfan + EPP setup from dotfiles/myconfig/docs on Arch — run with: sudo bash ~/fan-fix.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

step() { printf '\n\e[1;34m==> %s\e[0m\n' "$*"; }

step "1. Install thinkfan (chaotic-aur)"
pacman -S --needed --noconfirm thinkfan

step "2. /etc/thinkfan.yaml (bind by name; GPU sensor optional since it errors while the dGPU sleeps)"
[[ -f /etc/thinkfan.yaml ]] && cp /etc/thinkfan.yaml /etc/thinkfan.yaml.bak
cat > /etc/thinkfan.yaml <<'EOF'
fans:
  - tpacpi: /proc/acpi/ibm/fan
sensors:
  - hwmon: /sys/class/hwmon
    name: coretemp
    indices: [1]
    optional: true
  - hwmon: /sys/class/hwmon
    name: thinkpad
    indices: [1]
    optional: true
  # GPU via EC: only readable while the dGPU is awake (ML workloads)
  - hwmon: /sys/class/hwmon
    name: thinkpad
    indices: [2]
    optional: true
  - hwmon: /sys/class/hwmon
    name: acpitz
    indices: [1]
    optional: true
levels:
  - [0, 0, 42]
  - [1, 38, 50]
  - [2, 45, 58]
  - [4, 52, 65]
  - [7, 60, 80]
  - ["level auto", 75, 32767]
EOF

step "3. Test config in foreground for 8s"
timeout 8 thinkfan -n -v -c /etc/thinkfan.yaml 2>&1 | tail -8 || true

step "4. systemd override: retry, clear stale pidfile"
mkdir -p /etc/systemd/system/thinkfan.service.d
cat > /etc/systemd/system/thinkfan.service.d/override.conf <<'EOF'
[Service]
ExecStartPre=-/usr/bin/rm -f /run/thinkfan.pid
Restart=on-failure
RestartSec=5
EOF

step "5. udev: restart thinkfan when hwmon devices renumber"
cat > /etc/udev/rules.d/91-thinkfan-restart.rules <<'EOF'
SUBSYSTEM=="hwmon", ACTION=="add", RUN+="/usr/bin/systemd-run --no-block --on-active=2 /usr/bin/systemctl try-restart thinkfan.service"
SUBSYSTEM=="hwmon", ACTION=="remove", RUN+="/usr/bin/systemd-run --no-block --on-active=2 /usr/bin/systemctl try-restart thinkfan.service"
EOF
udevadm control --reload

step "6. EPP balance_power at boot (after power-profiles-daemon, which would reset it)"
cat > /etc/systemd/system/cpu-epp.service <<'EOF'
[Unit]
Description=Set CPU EPP to balance_power
After=power-profiles-daemon.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo balance_power | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference >/dev/null'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cpu-epp.service thinkfan.service
sleep 6

step "Result"
systemctl is-active thinkfan.service
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort | uniq -c
grep -E 'speed|level' /proc/acpi/ibm/fan
