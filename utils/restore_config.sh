#!/bin/bash

# Cartella sorgente (il repository delle config)
SRC="$HOME/myconfig"

# Colori per il terminale
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Ripristino configurazioni da repository a locale (README preservati)...${NC}"

# Funzione per copiare i file preservando i file locali non presenti nella sorgente
restore_folder() {
    local repo_src=$1
    local local_target=$2
    
    if [ -d "$repo_src" ]; then
        # Crea la cartella di destinazione se non esiste
        mkdir -p "$local_target"
        
        # Copia tutto il contenuto del repository nella cartella locale .config
        # --recursive: copia sottocartelle
        # --update: copia solo se il file sorgente è più recente o mancante nella destinazione
        cp -ru "$repo_src/." "$local_target/"
        echo " Ripristinato: $local_target"
    else
        echo " Sorgente nel repository non trovata: $repo_src"
    fi
}

# 1. Dunst
restore_folder "$SRC/dunst" "$HOME/.config/dunst"

# 2. Fuzzel
restore_folder "$SRC/fuzzel" "$HOME/.config/fuzzel"

# 3. Niri
restore_folder "$SRC/niri" "$HOME/.config/niri"

# 4. Waybar (da waybar-niri alla cartella standard di waybar)
restore_folder "$SRC/waybar-niri" "$HOME/.config/waybar"

# 5. Kitty
restore_folder "$SRC/kitty" "$HOME/.config/kitty"

# 6. Neovim (Aggiunto al posto di Matugen)
restore_folder "$SRC/nvim" "$HOME/.config/nvim"

echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}Ripristino completato!${NC}"
