#!/bin/bash
SOURCE="/home/noya/"
TARGET="/media/noya/72e5f1d0-55d1-4dd5-b0c7-644fbc342fcc"

# --- Configurazione Notifiche ---
# Recuperiamo l'ID del tuo utente per connetterci al desktop corretto
USER_ID=$(id -u noya)
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus

# Funzione rapida per inviare pop-up
# Cambia questa funzione nello script:
invia_notifica() {
    notify-send "Pipeline HDD" "$1" --icon="$2" -t 5000
}

# --- Inizio Pipeline ---
sleep 5 # Aspettiamo che il mount sia stabile

if mountpoint -q "$TARGET"; then
    invia_notifica "Sincronizzazione in corso... Non scollegare il disco." "drive-harddisk"
    
    if rsync -av --delete "$SOURCE" "$TARGET/backup_automatico/"; then
        invia_notifica "Backup completato con successo!" "emblem-ok-symbolic"
        echo "Successo: $(date)" >> "$TARGET/pipeline_log.txt"
    else
        invia_notifica "Errore durante la sincronizzazione!" "dialog-error"
        echo "Errore Rsync: $(date)" >> "$TARGET/pipeline_log.txt"
    fi
else
    invia_notifica "Errore: Disco non montato correttamente. :(" "dialog-warning"
fi
