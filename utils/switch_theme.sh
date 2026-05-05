#!/bin/bash

if [ -z "$1" ]; then
    echo "Uso: ./switch_theme.sh /usr/share/desktop-base/active-theme/wallpaper/contents/images/1920x1080.jpg"
    exit 1
fi

# 1. Imposta lo sfondo
swaybg -i "$1" -m fill &

# 2. Genera i colori con Matugen
matugen image "$1"

# 3. Riavvia Waybar per caricare il nuovo colors.css
killall waybar && waybar &

# 4. Notifica (opzionale)
dunstify "Tema Aggiornato" "Colori estratti da $(basename "$1")" -i "$1"
