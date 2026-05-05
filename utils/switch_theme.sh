#!/bin/bash

if [ -z "$1" ]; then
    echo "Uso: ./switch_theme.sh /percorso/immagine.jpg"
    exit 1
fi

# 1. Chiudi istanze precedenti di swaybg per non accumulare processi
killall swaybg

# 2. Imposta lo sfondo
swaybg -i "$1" -m fill &

# 3. Genera i colori con Matugen
# Aggiungiamo -t per ricaricare i template se necessario
matugen image "$1"

# 4. Ricarica Niri (Fondamentale per i bordi delle finestre!)
niri msg action reload-config

# 5. Riavvia Waybar 
# Usiamo un piccolo sleep per dare tempo a Matugen di scrivere i file
killall waybar
sleep 0.2
waybar &

# 6. Notifica
dunstify "Tema Aggiornato" "Colori estratti da $(basename "$1")" -i "$1"

# 7. Kitty (Opzionale - Funziona se configurato)
# Se vuoi cambiare opacità "al volo" su quelle aperte:
kitty @ set-background-opacity 0.85 2>/dev/null
