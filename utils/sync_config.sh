#!/usr/bin/env bash

# Cartella di destinazione del repository
DEST="$HOME/myconfig"

# Colori per il terminale
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Sincronizzazione configurazioni (README preservati)...${NC}"

# Funzione universale per cartelle e file singoli
sync_item() {
    local src=$1
    local target=$2

    if [ -d "$src" ]; then
        # Se la sorgente è una cartella, assicura che il target esista
        mkdir -p "$target"
        # Copia ricorsiva aggiornata
        cp -ru "$src/." "$target/"
        echo -e " ${GREEN}󰉋 Cartella sincronizzata:${NC} $target"
    elif [ -f "$src" ]; then
        # Se la sorgente è un file singolo, assicura che la cartella padre esista
        mkdir -p "$(dirname "$target")"
        cp -u "$src" "$target"
        echo -e " ${BLUE}󰈔 File sincronizzato:${NC} $target"
    else
        echo " Sorgente non trovata: $src"
    fi
}

# --- Sincronizzazione Cartelle ---
sync_item "$HOME/.config/dunst"    "$DEST/dunst"
sync_item "$HOME/.config/fuzzel"   "$DEST/fuzzel"
sync_item "$HOME/.config/niri"     "$DEST/niri"
sync_item "$HOME/.config/waybar"   "$DEST/waybar-niri"
sync_item "$HOME/.config/kitty"    "$DEST/kitty"
sync_item "$HOME/.config/swaylock" "$DEST/swaylock"
sync_item "$HOME/.config/conky"     "$DEST/conky"

sync_item "/usr/local/bin/backup_hdd.sh"                    "$DEST/backupHDD/backup_hdd.sh"
sync_item "/etc/udev/rules.d/99-backup-hdd.rules"           "$DEST/backupHDD/99-backup-hdd.rules"
sync_item "/etc/systemd/system/backup-hdd@.service"         "$DEST/backupHDD/backup-hdd@.service"

# --- Sincronizzazione File Singoli (Configurazioni Shell) ---
# Gestisce sia se hai una cartella starship sia se hai solo il file .toml diretto
if [ -d "$HOME/.config/starship" ]; then
    sync_item "$HOME/.config/starship" "$DEST/starship"
elif [ -f "$HOME/.config/starship.toml" ]; then
    sync_item "$HOME/.config/starship.toml" "$DEST/starship/starship.toml"
fi

sync_item "$HOME/.bashrc" "$DEST/deb/.bashrc"

echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}Sincronizzazione completata!${NC}"
