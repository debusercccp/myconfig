#!/bin/bash
# Reindirizza tutto l'output in un log per capire dove si blocca
exec > /tmp/pipeline_debug.log 2>&1
set -x
# -----------------------------------

UUID_ATTUALE=$1
echo "1. Inizio script. UUID passato da systemd: '$UUID_ATTUALE'"

SOURCE="/home/noya/"
TARGET=$(lsblk -rn -o UUID,MOUNTPOINT | grep "$UUID_ATTUALE" | awk '{print $2}')
echo "2. Il target rilevato è: '$TARGET'"

# --- Ambiente Notifiche (Specifico per KDE/Debian) ---
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export XAUTHORITY="/home/noya/.Xauthority"

# --- Meccanismo Anti-Doppio Avvio ---
LOCKFILE="/tmp/backup_hdd_${UUID_ATTUALE}.lock"

# Se il file di lock esiste ed è associato a un processo attivo, esci
if [ -e "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null; then
        echo "Script già in esecuzione (PID: $PID). Esco per evitare doppie notifiche."
        exit 0
    fi
fi

# Crea il file di lock con il PID attuale
echo $$ > "$LOCKFILE"

# Assicurati di cancellare il lock quando lo script finisce (anche in caso di errore)
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT
# ------------------------------------

invia_notifica() {
    notify-send "Pipeline HDD" "$1" --icon="$2" -t 5000 || echo "Notifica fallita"
}

# --- Logica di Controllo ---
if [ -z "$TARGET" ]; then
    echo "ERRORE: Target vuoto. Aspetto 5 secondi e riprovo..."
    sleep 5
    TARGET=$(lsblk -rn -o UUID,MOUNTPOINT | grep "$UUID_ATTUALE" | awk '{print $2}')
    if [ -z "$TARGET" ]; then
        echo "ERRORE FATALE: Il disco non risulta montato."
        exit 1
    fi
fi

# Rimuovo l'eventuale "a capo" dalla stringa TARGET
TARGET=$(echo "$TARGET" | tr -d '\n' | tr -d '\r')

UUID_ATTUALE=$1

# Definizione del nome "umano" basata sull'UUID
if [[ "$UUID_ATTUALE" == 8476* ]]; then
    NOME_DISCO="Disco da 2T"
else
    NOME_DISCO="Disco da 500G"
fi

# Poi nella parte della notifica:
if mountpoint -q "$TARGET"; then
    echo "3. Il target è un mountpoint valido. Lancio notifica iniziale..."
    invia_notifica "Avvio sincronizzazione $NOME_DISCO..." "drive-harddisk"
    
    echo "4. Inizio Rsync..."
    rsync -avS --delete \
        --exclude="target/" --exclude="node_modules/" --exclude=".cache/" \
        --exclude=".dbus/" --exclude=".local/share/Trash/" --exclude=".git/" \
        --exclude="*.lock" --exclude="HDD_Esterno" --exclude="I_Miei_Backup" \
        --exclude="backupHDD/" --exclude="lost+found/" --exclude=".var/app/" \
        --exclude=".mozilla/" --exclude=".config/google-chrome*/" \
        --exclude=".config/chromium/" --exclude=".aider" \
        "$SOURCE" "$TARGET/backup_automatico/"
        
    echo "5. Rsync completato con codice uscita $?"
    invia_notifica "Backup completato su $NOME_DISCO!" "emblem-ok-symbolic"
    
    ln -sfn "$TARGET/backup_automatico" /home/noya/HDD_Attivo
    echo "6. Link simbolico aggiornato in Home come HDD_Attivo."

else
       
    echo "ERRORE: $TARGET esiste ma non è un mountpoint riconosciuto."

    invia_notifica "Errore backup: disco non montato correttamente" "dialog-error"
fi