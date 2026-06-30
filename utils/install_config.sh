#!/bin/bash

# Installa i pacchetti del desktop (niri, waybar, dunst, fuzzel, cliphist,
# swaylock, blueman, conky) e collega le configurazioni del repository in
# ~/.config tramite symlink (stile GNU stow), così le modifiche fatte nel
# repository sono immediatamente attive senza dover ricopiare nulla.

set -euo pipefail

# Radice del repository, ricavata dalla posizione di questo script
# (utils/ -> radice). Funziona ovunque sia clonato il repo.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
STOW_DIR="$REPO/stow"

# Colori per il terminale
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Opzioni
# --links-only / -l : collega solo le configurazioni (symlink), senza
#   installare pacchetti né toccare i servizi. Utile per (ri)allineare
#   ~/.config al repository su una macchina già configurata.
LINKS_ONLY=0
for arg in "$@"; do
    case "$arg" in
        -l|--links-only) LINKS_ONLY=1 ;;
        -h|--help)
            echo "Uso: $0 [--links-only]"
            echo "  --links-only, -l   Collega solo le configurazioni (symlink),"
            echo "                     senza installare pacchetti o abilitare servizi."
            exit 0 ;;
        *) echo -e "${RED}Opzione sconosciuta: $arg${NC}" >&2; exit 1 ;;
    esac
done

# Pacchetti da installare (Debian)
# wl-clipboard serve a cliphist; xwayland-satellite serve a niri per le app X11
PACKAGES=(
    niri
    waybar
    dunst
    fuzzel
    cliphist
    wl-clipboard
    swaylock
    blueman
    conky-all
    xwayland-satellite
)

echo -e "${GREEN}=== Repository: $REPO ===${NC}"

if [ "$LINKS_ONLY" -eq 1 ]; then
    echo -e "${YELLOW}=== Modalità --links-only: salto installazione pacchetti ===${NC}"
else
echo -e "${GREEN}=== Installazione pacchetti ===${NC}"

if ! command -v apt-get >/dev/null 2>&1; then
    echo -e "${RED}apt-get non trovato: questo script supporta solo Debian/Ubuntu.${NC}"
    exit 1
fi

sudo apt-get update

TO_INSTALL=()
for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo " Già installato: $pkg"
    elif apt-cache show "$pkg" >/dev/null 2>&1; then
        TO_INSTALL+=("$pkg")
    else
        echo -e "${YELLOW} Pacchetto non disponibile nei repository: $pkg (da installare a mano)${NC}"
    fi
done

if [ ${#TO_INSTALL[@]} -gt 0 ]; then
    echo " Installo: ${TO_INSTALL[*]}"
    sudo apt-get install -y "${TO_INSTALL[@]}"
fi
fi

echo -e "${GREEN}=== Collegamento configurazioni (symlink dal repository) ===${NC}"

# Crea un symlink target -> src, facendo il backup di un'eventuale config reale.
make_link() {
    local src=$1      # sorgente nel repository (può essere essa stessa un symlink stow)
    local target=$2   # destinazione in ~/.config

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

# Per ogni package in stow/, collega i suoi contenuti .config/* in ~/.config/.
# La struttura stow/<pkg>/.config/<nome> codifica già la destinazione finale.
if [ -d "$STOW_DIR" ]; then
    for pkg_dir in "$STOW_DIR"/*/; do
        [ -d "$pkg_dir" ] || continue
        cfg_dir="$pkg_dir/.config"
        [ -d "$cfg_dir" ] || continue
        for src in "$cfg_dir"/*; do
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            make_link "$src" "$HOME/.config/$name"
        done
    done
else
    echo -e "${RED} Cartella stow/ non trovata in $REPO${NC}"
fi

if [ "$LINKS_ONLY" -eq 0 ]; then
echo -e "${GREEN}=== Servizi ===${NC}"

# Bluetooth per blueman
if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
    sudo systemctl enable --now bluetooth.service
    echo " Servizio bluetooth abilitato"
else
    echo -e "${YELLOW} Servizio bluetooth non trovato (manca bluez?)${NC}"
fi
fi

echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}Installazione e collegamento completati!${NC}"
