#!/usr/bin/env bash

if fprintd-verify -f right-little-finger "$USER" | grep -q "verify-match"; then
    notify-send "Duress trigger" "Esecuzione completata con successo."
    
    kitty bash -c "awk -F , '{print \$1 , \$2 , \$3}' /home/noya/ml/datasets/mercurioMurgia.csv; exec bash" &
fi
