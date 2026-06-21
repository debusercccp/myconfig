#!/bin/bash

# Collega le configurazioni del repository in ~/.config tramite symlink
# (stile GNU stow). Equivale alla sezione di collegamento di install_config.sh,
# ma senza installare pacchetti: utile per ripristinare solo i link.

set -euo pipefail

# Radice del repository, ricavata dalla posizione di questo script.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
STOW_DIR="$REPO/stow"

# Colori per il terminale
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Collegamento configurazioni dal repository ($REPO)...${NC}"

# Crea un symlink target -> src, facendo il backup di un'eventuale config reale.
make_link() {
    local src=$1
    local target=$2

    if [ -L "$target" ]; then
        if [ "$(readlink -f "$target")" = "$(readlink -f "$src")" ]; then
            echo " Già collegato: $target"
            return
        fi
        rm "$target"
    elif [ -e "$target" ]; then
        local bak
        bak="$target.pre-stow-bak-$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$bak"
        echo -e "${YELLOW} Backup config esistente -> $bak${NC}"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$src" "$target"
    echo " Collegato: $target -> $src"
}

if [ -d "$STOW_DIR" ]; then
    for pkg_dir in "$STOW_DIR"/*/; do
        [ -d "$pkg_dir" ] || continue
        cfg_dir="$pkg_dir/.config"
        [ -d "$cfg_dir" ] || continue
        for src in "$cfg_dir"/*; do
            [ -e "$src" ] || continue
            make_link "$src" "$HOME/.config/$(basename "$src")"
        done
    done
else
    echo -e "${RED} Cartella stow/ non trovata in $REPO${NC}"
    exit 1
fi

echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}Collegamento completato!${NC}"
