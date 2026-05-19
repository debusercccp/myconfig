#!/usr/bin/env bash

# Configurazione delle soglie
BATTERY_THRESHOLD=10
BATTERY_PATH="/sys/class/power_supply/BAT0"

# Verifica se la directory della batteria esiste
if [ ! -d "$BATTERY_PATH" ]; then
    echo "Errore: Batteria non trovata in $BATTERY_PATH" >&2
    exit 1
fi

# Legge la percentuale corrente e lo stato (Charging/Discharging)
capacity=$(cat "$BATTERY_PATH/capacity")
status=$(cat "$BATTERY_PATH/status")

# Se la batteria è sotto la soglia e si sta scaricando, invia la notifica
if [ "$capacity" -le "$BATTERY_THRESHOLD" ] && [ "$status" = "Discharging" ]; then
    notify-send -u critical \
                -i battery-low \
                "Porcamadonna la batteria è scarica" \
                "Il livello della batteria è al $capacity%. Collega il caricabatterie."
fi
