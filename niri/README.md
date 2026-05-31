NIRI + WAYBAR QUICK START
==================================================

STEP 1: INSTALLA DIPENDENZE
==================================================

Copia questo INTERO blocco e incollalo nel terminale:

sudo apt install -y build-essential pkg-config libwayland-dev libpango1.0-dev libpipewire-0.3-dev libinput-dev libseat-dev libgbm-dev libxkbcommon-dev libpixman-1-dev libudev-dev libdisplay-info-dev waybar fuzzel dunst swaybg kitty konsole xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr qt5-wayland qt6-wayland qt5ct qt6ct fonts-noto-color-emoji fonts-font-awesome fonts-ubuntu-nerd fonts-jetbrains-mono fonts-fira-code libgtk-layer-shell0 wl-clipboard cliphist swaylock brightnessctl wpctl pavucontrol slurp grim psmisc dunst blueman rfkill dolphin galculator firefox-esr conky conky-all gammastep


STEP 2: SETUP RFKILL
==================================================

sudo chmod +s /usr/sbin/rfkill


STEP 3: CREA DIRECTORY
==================================================

mkdir -p ~/.config/niri
mkdir -p ~/.config/waybar/scripts
mkdir -p ~/.config/fuzzel
mkdir -p ~/.config/dunst
mkdir -p ~/.config/conky


STEP 4: COPIA I FILE
==================================================

Scarica questi file dal repo e copiali:

  niri-config.kdl    -->    ~/.config/niri/config.kdl
  waybar-config      -->    ~/.config/waybar/config
  waybar-style.css   -->    ~/.config/waybar/style.css
  fuzzel.ini         -->    ~/.config/fuzzel/fuzzel.ini
  dunstrc            -->    ~/.config/dunst/dunstrc
  conky.conf         -->    ~/.config/conky/conky.conf
  mounts.sh          -->    ~/.config/waybar/scripts/mounts.sh


STEP 5: CREA nightlight.sh
==================================================

Apri un editor e crea questo file:

  ~/.config/waybar/scripts/nightlight.sh

Con questo contenuto:

#!/bin/bash

if [ "$1" = "toggle" ]; then
    if pgrep -x "gammastep" > /dev/null; then
        killall gammastep
        notify-send "Nightlight" "Disabilitato"
    else
        gammastep -O 3000 &
        notify-send "Nightlight" "Abilitato (3000K)"
    fi
fi


STEP 6: RENDI GLI SCRIPT ESEGUIBILI
==================================================

chmod +x ~/.config/waybar/scripts/mounts.sh
chmod +x ~/.config/waybar/scripts/nightlight.sh


STEP 7: AVVIA NIRI
==================================================

niri


SE NON FUNZIONA
==================================================

Se Niri esce subito, esegui:

  niri 2>&1

E leggi l'errore.

Se dice "file not found: colors.kdl":

  touch ~/.config/niri/colors.kdl

Se Waybar non appare:

  pkill waybar
  dbus-update-activation-environment --systemd WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=niri XDG_SESSION_TYPE=wayland
  systemctl --user restart xdg-desktop-portal
  sleep 2
  waybar &


KEYBINDINGS
==================================================

Mod = Super (Windows key)

  Mod+Q           = Terminal
  Mod+R           = App launcher
  Mod+E           = File manager
  Mod+C           = Close window
  Mod+A           = Clipboard history
  Mod+L           = Lock screen
  Mod+Shift+E     = Exit Niri

  Frecce                = Navigate
  Mod+Ctrl+Frecce      = Move window
  Mod+F                = Maximize

  Fn+Brightness Up     = Increase brightness
  Fn+Brightness Down   = Decrease brightness
  Fn+Volume Up         = Volume up
  Fn+Volume Down       = Volume down
  Fn+Mute              = Mute


COMANDI UTILI
==================================================

niri --version
niri msg outputs
niri msg action quit

pkill waybar && waybar &

brightnessctl get
brightnessctl set 50%

cliphist list

~/.config/waybar/scripts/mounts.sh list
~/.config/waybar/scripts/mounts.sh toggle


DONE!
==================================================

Se tutto funziona, goditi Niri!

Fine.
