#!/bin/bash
# 1. Cambia wallpaper
swaybg -i "$1" -m fill &
# 2. Genera colori
matugen image "$1"
# 3. Comunica a Niri di ricaricare i colori (se hai incluso il file)
niri msg action reload-config
