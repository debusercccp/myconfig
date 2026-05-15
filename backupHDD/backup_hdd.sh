#!/bin/bash
exec > /tmp/pipeline_debug.log 2>&1
set -x

UUID_ATTUALE=$1
SOURCE="/home/noya/"

TARGET=$(lsblk -rn -o UUID,MOUNTPOINT | grep "$UUID_ATTUALE" | awk '{print $2}')
TARGET=$(echo "$TARGET" | tr -d '\n' | tr -d '\r')

export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export XAUTHORITY="/home/noya/.Xauthority"

invia_notifica() {
    notify-send "Pipeline HDD" "$1" --icon="$2" -t 5000 || echo "Notifica fallita"
}

LOCKFILE="/tmp/backup_hdd_${UUID_ATTUALE}.lock"
if [ -e "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT

echo "Attendo montaggio..."
ATTESA=0
while [ $ATTESA -lt 60 ]; do
    TARGET=$(lsblk -rn -o UUID,MOUNTPOINT | grep "$UUID_ATTUALE" | awk '{print $2}')
    TARGET=$(echo "$TARGET" | tr -d '\n' | tr -d '\r')
    if [ -n "$TARGET" ] && mountpoint -q "$TARGET"; then break; fi
    sleep 2
    ATTESA=$((ATTESA + 2))
done

if [ -z "$TARGET" ] || ! mountpoint -q "$TARGET"; then
    invia_notifica "Backup annullato: disco non montato" "dialog-warning"
    exit 1
fi

case "$UUID_ATTUALE" in
    72e5*) NOME_DISCO="Disco A (500Gb)" ;;
    8476*) NOME_DISCO="Disco B (2Tb)" ;;
    6550*) NOME_DISCO="Disco C (500Gb)" ;;
    *)     NOME_DISCO="Disco Ignoto" ;;
esac

invia_notifica "Avvio backup su $NOME_DISCO..." "drive-harddisk"

# 1. Preparazione cartelle (Nomi coerenti)
mkdir -p "$TARGET/backup_automatico"
mkdir -p "$TARGET/Datasets_Archivio"
mkdir -p "$TARGET/Modelli_Archivio"
mkdir -p "$TARGET/noya_packs_Archivio"

echo "4. Inizio Rsync Mirror..."
# Aggiunto noya_packs agli exclude per gestirlo separatamente come archivio
rsync -avS --delete \
    --exclude="target/" --exclude="node_modules/" --exclude=".cache/" \
    --exclude=".dbus/" --exclude=".local/share/Trash/" --exclude=".git/" \
    --exclude="*.lock" --exclude="HDD_Attivo" --exclude="backupHDD/" \
    --exclude="lost+found/" --exclude=".var/app/" --exclude=".aider" \
    --exclude="datasets/" --exclude="modelli/" --exclude=".mozilla/" \
    --exclude="noya_packs/" \
    "$SOURCE" "$TARGET/backup_automatico/"

echo "4b. Archiviazione file pesanti (Accumulo)..."
[ -d "${SOURCE}datasets" ] && rsync -avS "${SOURCE}datasets/" "$TARGET/Datasets_Archivio/"
[ -d "${SOURCE}modelli" ] && rsync -avS "${SOURCE}modelli/" "$TARGET/Modelli_Archivio/"
[ -d "${SOURCE}noya_packs" ] && rsync -avS "${SOURCE}noya_packs/" "$TARGET/noya_packs_Archivio/"

echo "5. Aggiornamento Link Simbolici..."
ln -sfn "$TARGET/backup_automatico" /home/noya/HDD_Attivo
ln -sfn "$TARGET/Datasets_Archivio" /home/noya/TUTTI_I_DATASETS
ln -sfn "$TARGET/Modelli_Archivio" /home/noya/TUTTI_I_MODELLI
# ECCO IL COMANDO MANCANTE:
ln -sfn "$TARGET/noya_packs_Archivio" /home/noya/TUTTI_I_PACKS

invia_notifica "Backup e Archivi pronti su $NOME_DISCO!" "emblem-ok-symbolic"
