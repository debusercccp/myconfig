#!/bin/bash
# Script: ~/.config/waybar/scripts/nightlight.sh

is_running() {
    pgrep -x "gammastep" > /dev/null
}

case "$1" in
    toggle)
        if is_running; then
            killall gammastep
        else
            # Valori inseriti direttamente per evitare errori di espansione Bash
            gammastep -m wayland -l 41.90:12.49 -t 6500:3500 &
        fi
        ;;
    status)
        if is_running; then
            echo '{"text": "󰛑", "class": "on", "tooltip": "Luce Notturna: ATTIVATA\nTemperatura: 3500K"}'
        else
            echo '{"text": "󰛨", "class": "off", "tooltip": "Luce Notturna: DISATTIVATA\nClick per attivare"}'
        fi
        ;;
esac
