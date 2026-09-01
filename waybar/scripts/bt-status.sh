#!/bin/bash
if rfkill list bluetooth | grep -q "Soft blocked: yes\|Hard blocked: yes"; then
    echo '{"text":"󰂲","tooltip":"Bluetooth disattivato\nClick: attiva  |  Click-dx: gestione"}'
    exit 0
fi

connected=$(bluetoothctl devices Connected 2>/dev/null | wc -l)

if [ "$connected" -gt 0 ]; then
    names=$(bluetoothctl devices Connected 2>/dev/null | awk '{$1=$2=""; print substr($0,3)}' | paste -sd', ')
    echo "{\"text\":\"󰂱 ${connected}\",\"tooltip\":\"${names}\nClick: disattiva  |  Click-dx: gestione\"}"
else
    echo '{"text":"󰂯","tooltip":"Bluetooth attivo, nessun dispositivo connesso\nClick: disattiva  |  Click-dx: gestione"}'
fi
