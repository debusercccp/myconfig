#!/bin/bash

# Cartella di destinazione
DEST="$HOME/myconfig"

# Colori per il terminale
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Sincronizzazione configurazioni (README preservati)...${NC}"

# Funzione per copiare file evitando di cancellare i README.md
sync_folder() {
    local src=$1
    local target=$2
    
    if [ -d "$src" ]; then
        # Copia tutto il contenuto della sorgente nella destinazione
        # --recursive: copia sottocartelle (es. scripts di waybar)
        # --update: copia solo se il file sorgente è più recente o mancante
        cp -ru "$src/." "$target/"
        echo " Sincronizzato: $target"
    else
        echo " Sorgente non trovata: $src"
    fi
}

# 1. Dunst
sync_folder "$HOME/.config/dunst" "$DEST/dunst"

# 2. Fuzzel
sync_folder "$HOME/.config/fuzzel" "$DEST/fuzzel"

# 3. Niri
sync_folder "$HOME/.config/niri" "$DEST/niri"

# 4. Waybar (verso waybar-niri come richiesto)
sync_folder "$HOME/.config/waybar" "$DEST/waybar-niri"

sync_folder "$HOME/.config/matugen" "$DEST/matugen"

sync_folder "$HOME/.config/kitty" "$DEST/kitty"

echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}Sincronizzazione completata!${NC}"
