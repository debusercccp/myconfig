#!/bin/bash

# Installa i pacchetti del desktop (niri, waybar, dunst, fuzzel, cliphist,
# swaylock, blueman, conky) e ripristina le configurazioni dal repository,
# come utils/restore_config.sh.

# Cartella sorgente (il repository delle config)
SRC="$HOME/myconfig"

# Colori per il terminale
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

echo -e "${GREEN}=== Ripristino configurazioni (README preservati) ===${NC}"

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

# 1. Niri
restore_folder "$SRC/niri" "$HOME/.config/niri"

# 2. Waybar (da waybar-niri alla cartella standard di waybar)
restore_folder "$SRC/waybar-niri" "$HOME/.config/waybar"

# 3. Dunst
restore_folder "$SRC/dunst" "$HOME/.config/dunst"

# 4. Fuzzel
restore_folder "$SRC/fuzzel" "$HOME/.config/fuzzel"

# 5. Swaylock
restore_folder "$SRC/swaylock" "$HOME/.config/swaylock"

# 6. Conky
restore_folder "$SRC/conky" "$HOME/.config/conky"

# Nota: cliphist e blueman non hanno cartelle di config nel repository.

echo -e "${GREEN}=== Servizi ===${NC}"

# Bluetooth per blueman
if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
    sudo systemctl enable --now bluetooth.service
    echo " Servizio bluetooth abilitato"
else
    echo -e "${YELLOW} Servizio bluetooth non trovato (manca bluez?)${NC}"
fi

echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}Installazione e ripristino completati!${NC}"
