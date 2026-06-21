#!/usr/bin/env bash

# Copia nel repository i file che NON sono collegati via symlink.
# Le configurazioni in ~/.config (dunst, fuzzel, niri, waybar, kitty,
# swaylock, conky, starship) sono symlink al repository, quindi sono già
# allineate e non vanno sincronizzate. Restano da copiare i file di sistema
# (backupHDD) e quelli fuori da ~/.config (es. .bashrc).

set -euo pipefail

# Radice del repository, ricavata dalla posizione di questo script.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DEST="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colori per il terminale
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Sincronizzazione file non symlinkati nel repository...${NC}"

# Funzione universale per cartelle e file singoli
sync_item() {
    local src=$1
    local target=$2

    if [ -d "$src" ]; then
        mkdir -p "$target"
        cp -ru "$src/." "$target/"
        echo -e " ${GREEN}󰉋 Cartella sincronizzata:${NC} $target"
    elif [ -f "$src" ]; then
        mkdir -p "$(dirname "$target")"
        cp -u "$src" "$target"
        echo -e " ${BLUE}󰈔 File sincronizzato:${NC} $target"
    else
        echo " Sorgente non trovata: $src"
    fi
}

# --- File di sistema del backup HDD ---
sync_item "/usr/local/bin/backup_hdd.sh"            "$DEST/backupHDD/backup_hdd.sh"
sync_item "/etc/udev/rules.d/99-backup-hdd.rules"   "$DEST/backupHDD/99-backup-hdd.rules"
sync_item "/etc/systemd/system/backup-hdd@.service" "$DEST/backupHDD/backup-hdd@.service"

# --- Configurazioni shell fuori da ~/.config ---
sync_item "$HOME/.bashrc" "$DEST/deb/.bashrc"

echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}Sincronizzazione completata!${NC}"
