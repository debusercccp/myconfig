#!/bin/bash
# restore_hdd.sh — Ripristino automatico da HDD/USB (speculare di backup_hdd.sh)
# Uso: restore_hdd.sh <UUID> [destinazione]
#   destinazione: cartella di destinazione locale (default: $HOME/)
exec > /tmp/pipeline_debug.log 2>&1
set -euo pipefail
set -x

UUID_ATTUALE="${1:?Errore: UUID non fornito}"
DEST="${2:-$HOME/}"
[[ "$DEST" != */ ]] && DEST="$DEST/"

# Variabili d'ambiente per notifiche desktop (Wayland/X11)
export DISPLAY=:0
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
export XAUTHORITY="$HOME/.Xauthority"

invia_notifica() {
    notify-send "Pipeline HDD" "$1" --icon="$2" -t 7000 \
        || echo "Notifica fallita: $1"
}

# =========================================================================
# LOCKFILE — prevenzione esecuzioni concorrenti
# =========================================================================
LOCKFILE="/tmp/restore_hdd_dynamic.lock"
if [[ -e "$LOCKFILE" ]]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Ripristino già in corso (PID $PID). Uscita."
        exit 0
    fi
fi
echo $$ > "$LOCKFILE"

# File di progresso letto dal modulo custom/backup di waybar
PROGRESS_FILE="/tmp/restore_hdd_progress"
trap 'rm -f "$LOCKFILE" "$PROGRESS_FILE" "$PROGRESS_FILE.fase"' INT TERM EXIT

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
SOURCE_HDD=""
for ((i = 0; i < 300; i += 2)); do
    SOURCE_HDD=$(lsblk -rn -o UUID,MOUNTPOINT \
        | awk -v uuid="$UUID_ATTUALE" '$1 == uuid {print $2}')
    [[ -n "$SOURCE_HDD" ]] && mountpoint -q "$SOURCE_HDD" && break
    sleep 2
done
if [[ -z "$SOURCE_HDD" ]] || ! mountpoint -q "$SOURCE_HDD"; then
    invia_notifica "Ripristino annullato: disco non montato o sorgente non valida." "dialog-warning"
    exit 1
fi

# =========================================================================
# NOME DISCO (basato su UUID stabili)
# =========================================================================
case "$UUID_ATTUALE" in
    8476*) NOME_DISCO="Disco A (2 TB)" ;;
    6550*) NOME_DISCO="Disco B (500 GB)" ;;
    d8c9*) NOME_DISCO="Disco C (WD 500 GB)" ;;
    *)     NOME_DISCO="Dispositivo volatile (${UUID_ATTUALE:0:8}…)" ;;
esac
invia_notifica "Avvio ripristino da $NOME_DISCO…" "drive-harddisk"

# =========================================================================
# VERIFICA CHE ESISTA UN BACKUP SUL DISCO
# =========================================================================
if [[ ! -d "$SOURCE_HDD/backup_automatico" ]]; then
    invia_notifica "Nessun backup trovato su $NOME_DISCO." "dialog-error"
    exit 1
fi
mkdir -p "$DEST"

# =========================================================================
# RSYNC — Ripristino della home (NIENTE --delete: si aggiunge/aggiorna
# soltanto, non si cancella nulla di già presente sul nuovo laptop)
# =========================================================================
echo "Avvio rsync di ripristino..."
echo "Ripristino home ← $NOME_DISCO" > "$PROGRESS_FILE.fase"
rsync -aHS --info=progress2 --no-inc-recursive --ignore-errors \
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
    --exclude="MiniSSD/"              \
    --exclude="docs_rag"              \
    --exclude="/HDD_Attivo"           \
    --exclude="/TUTTI_I_DATASETS"     \
    --exclude="/TUTTI_I_MODELLI"      \
    --exclude="/TUTTI_I_PACKS"        \
    --exclude="modelli/"              \
    --exclude="docs_rag"              \
    --exclude=".mozilla/"             \
    --exclude="/usb"                  \
    --exclude="noya_packs/"           \
    --exclude="Scaricati/"            \
    "$SOURCE_HDD/backup_automatico/" "$DEST" > "$PROGRESS_FILE"

# =========================================================================
# RSYNC — Ripristino archivi pesanti (accumulo, senza --delete)
# =========================================================================
echo "Ripristino archivi pesanti..."
rsync_archivio() {
    local src="$1" dst="$2" nome="$3"
    [[ -d "$src" ]] || return 0
    echo "Ripristino $nome ← $NOME_DISCO" > "$PROGRESS_FILE.fase"
    mkdir -p "$dst"
    rsync -aHS --info=progress2 --no-inc-recursive "$src/" "$dst/" > "$PROGRESS_FILE"
}
rsync_archivio "$SOURCE_HDD/Datasets_Archivio"   "${DEST}datasets"    "datasets"
rsync_archivio "$SOURCE_HDD/Modelli_Archivio"    "${DEST}modelli"     "modelli"
rsync_archivio "$SOURCE_HDD/noya_packs_Archivio" "${DEST}noya_packs"  "noya_packs"

# =========================================================================
# SYNC FINALE — flush della cache su disco locale
# =========================================================================
echo "Sincronizzazione dati sul nuovo laptop..."
rm -f "$PROGRESS_FILE"
echo "Sincronizzazione finale su $DEST" > "$PROGRESS_FILE.fase"
sync -f "$DEST"

invia_notifica "Ripristino completato da $NOME_DISCO su questo laptop!" "emblem-ok-symbolic"
