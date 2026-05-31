# 1. Installa tutte le dipendenze
sudo apt install -y \
  build-essential pkg-config libwayland-dev libpango1.0-dev \
  libpipewire-0.3-dev libinput-dev libseat-dev libgbm-dev \
  libxkbcommon-dev libpixman-1-dev libudev-dev libdisplay-info-dev \
  waybar fuzzel dunst swaybg kitty konsole \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
  qt5-wayland qt6-wayland qt5ct qt6ct \
  fonts-noto-color-emoji fonts-font-awesome fonts-ubuntu-nerd fonts-jetbrains-mono fonts-fira-code \
  libgtk-layer-shell0 \
  wl-clipboard cliphist \
  swaylock \
  brightnessctl wpctl pavucontrol slurp grim psmisc \
  dunst \
  blueman rfkill \
  dolphin galculator firefox-esr \
  conky conky-all \
  gammastep

# 2. Setup rfkill
sudo chmod +s /usr/sbin/rfkill

# 3. Compila Niri (opzionale se usi il pacchetto)
git clone https://github.com/YaLTeR/niri.git
cd niri
cargo build --release
sudo install -D target/release/niri /usr/local/bin/niri

# 4. Crea directory di config
mkdir -p ~/.config/niri
mkdir -p ~/.config/waybar/scripts
mkdir -p ~/.config/fuzzel
mkdir -p ~/.config/dunst
mkdir -p ~/.config/conky

# 5. Copia i file di config forniti
# Copia: config.kdl in ~/.config/niri/
# Copia: waybar/config in ~/.config/waybar/
# Copia: waybar/style.css in ~/.config/waybar/
# Copia: fuzzel/fuzzel.ini in ~/.config/fuzzel/
# Copia: dunst/dunstrc in ~/.config/dunst/
# Copia: waybar/scripts/mounts.sh in ~/.config/waybar/scripts/
# Copia: waybar/scripts/nightlight.sh in ~/.config/waybar/scripts/

# 6. Rendi gli script eseguibili
chmod +x ~/.config/waybar/scripts/mounts.sh
chmod +x ~/.config/waybar/scripts/nightlight.sh

# 7. Avvia Niri
niri
