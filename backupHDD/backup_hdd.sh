#!/bin/bash
# Reindirizza tutto l'output in un log per debug
exec > /tmp/pipeline_debug.log 2>&1
set -x

UUID_ATTUALE=$1
SOURCE="/home/noya/"

# 1. Recupero punto di montaggio
TARGET=$(lsblk -rn -o UUID,MOUNTPOINT | grep "$UUID_ATTUALE" | awk '{print $2}')
TARGET=$(echo "$TARGET" | tr -d '\n' | tr -d '\r')

# --- Ambiente Notifiche ---
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export XAUTHORITY="/home/noya/.Xauthority"

invia_notifica() {
    notify-send "Pipeline HDD" "$1" --icon="$2" -t 5000 || echo "Notifica fallita"
}

# --- Meccanismo Anti-Doppio Avvio ---
LOCKFILE="/tmp/backup_hdd_${UUID_ATTUALE}.lock"
if [ -e "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null; then
        echo "Script già in esecuzione. Esco."
        exit 0
    fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT

# --- Controllo Montaggio ---
if [ -z "$TARGET" ]; then
    echo "Target vuoto, attendo montaggio..."
    sleep 5
    TARGET=$(lsblk -rn -o UUID,MOUNTPOINT | grep "$UUID_ATTUALE" | awk '{print $2}')
    TARGET=$(echo "$TARGET" | tr -d '\n' | tr -d '\r')
fi

# --- Identificazione Disco ---
case "$UUID_ATTUALE" in
    72e5*) NOME_DISCO="Disco A (500Gb)" ;;
    8476*) NOME_DISCO="Disco B (2Tb)" ;;
    6550*) NOME_DISCO="Disco C (500Gb)" ;;
    *)     NOME_DISCO="Disco Ignoto" ;;
esac

# --- Esecuzione Operazioni ---
if [ -n "$TARGET" ] && mountpoint -q "$TARGET"; then
    invia_notifica "Avvio backup su $NOME_DISCO..." "drive-harddisk"
    
    # Crea le cartelle nel disco se non esistono
    mkdir -p "$TARGET/backup_automatico"
    mkdir -p "$TARGET/Datasets_Archivio"
    mkdir -p "$TARGET/Modelli_Archivio"

    echo "4. Inizio Rsync Mirror (Home)..."
    rsync -avS --delete \
        --exclude="target/" --exclude="node_modules/" --exclude=".cache/" \
        --exclude=".dbus/" --exclude=".local/share/Trash/" --exclude=".git/" \
        --exclude="*.lock" --exclude="HDD_Attivo" --exclude="backupHDD/" \
        --exclude="lost+found/" --exclude=".var/app/" --exclude=".aider" \
        --exclude="datasets/" --exclude="modelli/" \
        "$SOURCE" "$TARGET/backup_automatico/"

    echo "4b. Archiviazione Datasets e Modelli (Senza delete)..."
    # Sincronizza datasets se esiste, ma non cancella mai dal disco
    if [ -d "${SOURCE}datasets" ]; then
        rsync -avS "${SOURCE}datasets/" "$TARGET/Datasets_Archivio/"
    fi

    # Sincronizza modelli se esiste, ma non cancella mai dal disco
    if [ -d "${SOURCE}modelli" ]; then
        rsync -avS "${SOURCE}modelli/" "$TARGET/Modelli_Archivio/"
    fi
        
    echo "5. Operazioni completate."
    
    # 6. AGGIORNAMENTO LINK SIMBOLICI (Importante!)
    # Questi comandi "riparano" i link nella tua Home puntandoli al disco attuale
    ln -sfn "$TARGET/backup_automatico" /home/noya/HDD_Attivo
    ln -sfn "$TARGET/Datasets_Archivio" /home/noya/TUTTI_I_DATASETS
    ln -sfn "$TARGET/Modelli_Archivio" /home/noya/TUTTI_I_MODELLI
    
    invia_notifica "Backup e Archivi pronti su $NOME_DISCO!" "emblem-ok-symbolic"

else
    echo "ERRORE: $TARGET non è un mountpoint."
    invia_notifica "Errore backup: disco non montato" "dialog-error"
fi
