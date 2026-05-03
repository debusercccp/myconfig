#!/bin/bash
# Script: ~/.config/waybar/scripts/nightlight.sh

# Coordinate per l'attivazione automatica (Es. Roma)
LAT="41.90"
LON="12.49"
# Temperatura giorno e notte
TEMP_DAY="6500"
TEMP_NIGHT="3500"

# Controlla se il processo è attivo
is_running() {
    pgrep -x "gammastep" > /dev/null
}

case "$1" in
    toggle)
        if is_running; then
            # Se è acceso, lo killa (forza disattivazione)
            killall gammastep
        else
            # Se è spento, lo avvia in background in modalità automatica
            gammastep -l $LAT:$LON -t $TEMP_DAY:$TEMP_NIGHT &
        fi
        ;;
    status)
        if is_running; then
            # Icona accesa (Luce calda)
            echo '{"text": "󰛑", "class": "on", "tooltip": "Filtro Attivo (Automatico)\nTemperatura: '$TEMP_NIGHT'K"}'
        else
            # Icona spenta (Luce fredda/normale)
            echo '{"text": "󰛨", "class": "off", "tooltip": "Filtro Disattivato\nClick per attivare"}'
        fi
        ;;
esac
