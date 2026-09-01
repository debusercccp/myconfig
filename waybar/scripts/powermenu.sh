#!/usr/bin/env bash
# Power / session menu per Niri via fuzzel.
# Voci: blocca, logout (esce da Niri), sospendi, riavvia, spegni.

set -euo pipefail

options="\
󰌾  Blocca
󰍃  Logout
󰒲  Sospendi
󰜉  Riavvia
󰐥  Spegni"

choice="$(printf '%s\n' "$options" | fuzzel --dmenu --prompt 'Power: ' --lines 5)"

case "$choice" in
    *Blocca)   swaylock ;;
    *Logout)   niri msg action quit --skip-confirmation ;;
    *Sospendi) systemctl suspend ;;
    *Riavvia)  systemctl reboot ;;
    *Spegni)   systemctl poweroff ;;
    *)         exit 0 ;;
esac
