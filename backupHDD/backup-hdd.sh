#!/bin/bash

# ==========================================
# 1. CONFIGURAZIONE PERCORSI
# ==========================================
SOURCE="/home/noya/"
TARGET="/media/noya/72e5f1d0-55d1-4dd5-b0c7-644fbc342fcc"
LOG_FILE="$TARGET/pipeline_log.txt"

# ==========================================
# 2. CONFIGURAZIONE NOTIFICHE (Ambiente Systemd)
# ==========================================
USER_ID=$(id -u)
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"

invia_notifica() {
    # Invia un pop-up che dura 5 secondi
    notify-send "Pipeline HDD" "$1" --icon="$2" -t 5000
}

# ==========================================
# 3. AVVIO PIPELINE
# ==========================================
# Diamo il tempo a udev e al sistema di montare fisicamente il volume
sleep 5

# Verifichiamo che la cartella esista e sia effettivamente il disco montato
if mountpoint -q "$TARGET"; then
    invia_notifica "Sincronizzazione in corso... Non scollegare il disco." "drive-harddisk"
    
    # Esecuzione Rsync Ottimizzata:
    # -a: Archive (mantiene permessi e date)
    # -v: Verbose (per leggere i log con journalctl)
    # -S: Sparse (gestisce i file vuoti o le VM senza sprecare spazio)
    # (Nessun -z per la compressione, nessun -c per il checksum)
    
    if rsync -avS --delete \
        --exclude="target/" \
        --exclude="node_modules/" \
        --exclude=".cache/" \
        --exclude=".dbus/" \
        --exclude=".local/share/Trash/" \
        --exclude=".git/" \
        --exclude="*.lock" \
        --exclude="HDD_Esterno" \
        --exclude="I_Miei_Backup" \
        "$SOURCE" "$TARGET/backup_automatico/"; then
        
        invia_notifica "Backup completato con successo!" "emblem-ok-symbolic"
        echo "[ OK ] Sincronizzazione completata: $(date)" >> "$LOG_FILE"
    else
        # Se rsync incontra errori (es. Code 23 per file bloccati)
        invia_notifica "Backup terminato con errori minori (vedi log)." "dialog-error"
        echo "[ WARNING ] Errore parziale Rsync: $(date)" >> "$LOG_FILE"
    fi
else
    # Fallback se il disco non è pronto
    invia_notifica "Errore: Disco non rilevato correttamente." "dialog-warning"
    echo "[ ERROR ] Disco non montato al tentativo del $(date)" >> /tmp/backup_error.log
fi
