#!/bin/bash
# backup_hdd.sh — Backup automatico su HDD/USB
# Uso: backup_hdd.sh <UUID>

exec > /tmp/pipeline_debug.log 2>&1
set -euo pipefail
set -x

UUID_ATTUALE="${1:?Errore: UUID non fornito}"
SOURCE="/home/noya/"

# Variabili d'ambiente per notifiche desktop (Wayland/X11)
export DISPLAY=:0
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
export XAUTHORITY="/home/noya/.Xauthority"

invia_notifica() {
    notify-send "Pipeline HDD" "$1" --icon="$2" -t 7000 \
        || echo "Notifica fallita: $1"
}

# =========================================================================
# LOCKFILE — prevenzione esecuzioni concorrenti
# =========================================================================
LOCKFILE="/tmp/backup_hdd_dynamic.lock"
if [[ -e "$LOCKFILE" ]]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Backup già in corso (PID $PID). Uscita."
        exit 0
    fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' INT TERM EXIT

# =========================================================================
# IDENTIFICAZIONE DISPOSITIVO
# =========================================================================
DEVICE_NODE=$(lsblk -rn -o UUID,NAME | awk -v uuid="$UUID_ATTUALE" '$1 == uuid {print "/dev/"$2}')

if [[ -z "$DEVICE_NODE" ]]; then
    invia_notifica "Dispositivo con UUID $UUID_ATTUALE non trovato." "dialog-error"
    exit 1
fi

# =========================================================================
# ATTESA MOUNT
# =========================================================================
echo "Attendo montaggio di $DEVICE_NODE..."
TARGET=""
for ((i = 0; i < 60; i += 2)); do
    TARGET=$(lsblk -rn -o UUID,MOUNTPOINT \
        | awk -v uuid="$UUID_ATTUALE" '$1 == uuid {print $2}')
    [[ -n "$TARGET" ]] && mountpoint -q "$TARGET" && break
    sleep 2
done

if [[ -z "$TARGET" ]] || ! mountpoint -q "$TARGET"; then
    invia_notifica "Backup annullato: disco non montato o target non valido." "dialog-warning"
    exit 1
fi

# =========================================================================
# NOME DISCO (basato su UUID stabili)
# =========================================================================
case "$UUID_ATTUALE" in
    8476*) NOME_DISCO="Disco A (2 TB)" ;;
    6550*) NOME_DISCO="Disco B (500 GB)" ;;
    *)     NOME_DISCO="Dispositivo volatile (${UUID_ATTUALE:0:8}…)" ;;
esac

invia_notifica "Avvio backup su $NOME_DISCO…" "drive-harddisk"

# =========================================================================
# PREPARAZIONE DIRECTORY DI DESTINAZIONE
# =========================================================================
mkdir -p \
    "$TARGET/backup_automatico" \
    "$TARGET/Datasets_Archivio" \
    "$TARGET/Modelli_Archivio" \
    "$TARGET/noya_packs_Archivio"

# =========================================================================
# RSYNC — Mirror della home (esclusioni ottimizzate)
# =========================================================================
echo "Avvio rsync mirror..."
rsync -avHS --delete \
    --exclude="target/"               \
    --exclude="node_modules/"         \
    --exclude=".cache/"               \
    --exclude=".dbus/"                \
    --exclude=".local/share/Trash/"   \
    --exclude=".git/"                 \
    --exclude="*.lock"                \
    --exclude="HDD_Attivo"            \
    --exclude="TUTTI_I_*"             \
    --exclude="backupHDD/"            \
    --exclude="lost+found/"           \
    --exclude=".var/app/"             \
    --exclude=".aider"                \
    --exclude="datasets/"             \
    --exclude="modelli/"              \
    --exclude=".mozilla/"             \
    --exclude="/usb"                  \
    --exclude="noya_packs/"           \
    --exclude="Scaricati/"            \
    "$SOURCE" "$TARGET/backup_automatico/"

# =========================================================================
# RSYNC — Archiviazione file pesanti (accumulo, senza --delete)
# =========================================================================
echo "Archiviazione file pesanti..."
rsync_archivio() {
    local src="$1" dst="$2"
    [[ -d "$src" ]] && rsync -avHS "$src/" "$dst/"
}

rsync_archivio "${SOURCE}datasets"   "$TARGET/Datasets_Archivio"
rsync_archivio "${SOURCE}modelli"    "$TARGET/Modelli_Archivio"
rsync_archivio "${SOURCE}noya_packs" "$TARGET/noya_packs_Archivio"

# =========================================================================
# LINK SIMBOLICI — scorciatoie nella home
# =========================================================================
echo "Aggiornamento link simbolici..."
ln -sfn "$TARGET/backup_automatico"  "${SOURCE}HDD_Attivo"
ln -sfn "$TARGET/Datasets_Archivio"  "${SOURCE}TUTTI_I_DATASETS"
ln -sfn "$TARGET/Modelli_Archivio"   "${SOURCE}TUTTI_I_MODELLI"
ln -sfn "$TARGET/noya_packs_Archivio" "${SOURCE}TUTTI_I_PACKS"

invia_notifica "Backup completato su $NOME_DISCO!" "emblem-ok-symbolic"
