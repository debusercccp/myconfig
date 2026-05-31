# Niri + Waybar Setup su Debian Trixie (Testing)

Guida completa per compilare **Niri** (compositor Wayland scrollante), configurare **Waybar** (barra di stato) e risolvere i problemi comuni su **Debian Trixie**.

---

## Sommario

1. [Prerequisiti](#prerequisiti)
2. [Librerie e Pacchetti Installati](#librerie-e-pacchetti-installati)
3. [Compilazione di Niri](#compilazione-di-niri)
4. [Configurazione Niri (config.kdl)](#configurazione-niri-configkdl)
5. [Configurazione Waybar](#configurazione-waybar)
6. [Componenti Aggiuntivi](#componenti-aggiuntivi)
7. [Troubleshooting Completo](#troubleshooting-completo)
8. [Quick Start](#quick-start)

---

## Prerequisiti

- **OS**: Debian Trixie (testing)
- **Hardware**: Laptop con monitor integrato (eDP-1) o display esterno
- **Rust**: Cargo installato via `rustup`
- **Shell**: bash o zsh

---

## Librerie e Pacchetti Installati

### Dipendenze di Build (per compilare Niri da sorgente)

Questi pacchetti permettono a `cargo` di compilare il codice Rust di Niri:

```bash
sudo apt install \
  build-essential \
  pkg-config \
  libwayland-dev \
  libpango1.0-dev \
  libpipewire-0.3-dev \
  libinput-dev \
  libseat-dev \
  libgbm-dev \
  libxkbcommon-dev \
  libpixman-1-dev \
  libudev-dev \
  libdisplay-info-dev
```

**Dettagli:**
- `build-essential`: gcc, make, e strumenti base
- `pkg-config`: Helper per localizzare librerie di sistema
- `libseat-dev`: **CRITICO** — gestione sessioni hardware (senza questo Niri non compila)
- `libwayland-dev`: Protocollo Wayland
- `libpipewire-0.3-dev`: Audio/video streaming
- `libinput-dev`: Input device (mouse, tastiera)
- `libgbm-dev`, `libxkbcommon-dev`, `libpixman-1-dev`, `libudev-dev`, `libdisplay-info-dev`: Rendering e system utilities

### Core Desktop Components

```bash
sudo apt install \
  niri \
  waybar \
  fuzzel \
  dunst \
  swaybg \
  kitty \
  konsole \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-wlr
```

**Oppure**, se compili Niri da sorgente e installi solo i componenti essenziali:

```bash
sudo apt install \
  waybar \
  fuzzel \
  dunst \
  swaybg \
  kitty \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk
```

### Supporto Grafico e Icone

```bash
sudo apt install \
  qt5-wayland \
  qt6-wayland \
  qt5ct \
  qt6ct \
  fonts-noto-color-emoji \
  fonts-font-awesome \
  fonts-ubuntu-nerd \
  fonts-jetbrains-mono \
  fonts-fira-code \
  libgtk-layer-shell0
```

**Dettagli:**
- `qt5-wayland`, `qt6-wayland`: Rendering nativo Wayland per app Qt/KDE
- `qt5ct`, `qt6ct`: Tema grafico per applicazioni Qt
- `fonts-*`: Font per icone (FontAwesome, Nerd Fonts per Waybar)
- `libgtk-layer-shell0`: **ESSENZIALE** — permette a Waybar di ancorare le finestre ai bordi dello schermo via `wlr-layer-shell` protocol

### Clipboard e Gestione Appunti

```bash
sudo apt install \
  wl-clipboard \
  cliphist
```

**Dettagli:**
- `wl-clipboard`: Fornisce `wl-copy` e `wl-paste`, necessari per la clipboard Wayland
- `cliphist`: Demone che mantiene la history degli appunti; usato con `wl-paste --watch cliphist store`

### Sicurezza e Blocco Schermo

```bash
sudo apt install \
  swaylock
```

**Dettagli:**
- `swaylock`: Screen locker Wayland; attivato con `Mod+L`

### Controllo Audio, Video e Sistema

```bash
sudo apt install \
  brightnessctl \
  wpctl \
  pavucontrol \
  slurp \
  grim \
  psmisc
```

**Dettagli:**
- `brightnessctl`: Controllo luminosità schermo (XF86MonBrightnessUp/Down)
- `wpctl`: Controllo volume audio via pipewire (XF86AudioRaiseVolume/LowerVolume/Mute)
- `pavucontrol`: Mixer audio GUI
- `slurp`: Selettore regione per screenshot
- `grim`: Screenshot tool per Wayland
- `psmisc`: Fornisce `pkill`, `pgrep` per process management

### Sistema di Notifiche

```bash
sudo apt install \
  dunst
```

**Nota:** Se preferisci un notification daemon alternativo, puoi usare `mako-notifier`:
```bash
sudo apt install mako
```

### Bluetooth e Wireless

```bash
sudo apt install \
  blueman \
  rfkill
```

**Dettagli:**
- `blueman`: Applet Bluetooth nel system tray
- `rfkill`: Utility per abilitare/disabilitare radio (WiFi, Bluetooth)

**Setup aggiuntivo per rfkill:**
```bash
sudo chmod +s /usr/sbin/rfkill
```

### Theming Dinamico e Colori

```bash
sudo apt install \
  matugen
```

**Nota:** `matugen` non è disponibile direttamente nei repo Debian. Installazione opzioni:

**Opzione A: Build da sorgente con Cargo (consigliato)**
```bash
cargo install matugen
```

**Opzione B: Binario precompilato da GitHub**
```bash
curl -L https://github.com/InioX/matugen/releases/latest/download/matugen-x86_64-unknown-linux-gnu.tar.gz | tar xz
sudo install -D matugen /usr/local/bin/matugen
rm matugen
```

### Applicazioni Desktop

```bash
sudo apt install \
  dolphin \
  galculator \
  firefox-esr \
  conky \
  conky-all
```

**Dettagli:**
- `dolphin`: File manager KDE (Mod+E, XF86MyComputer)
- `galculator`: Calcolatrice GTK (XF86Calculator)
- `firefox-esr`: Browser (XF86HomePage)
- `conky`: System monitor configurabile
- `conky-all`: Plugin aggiuntivi per conky

### Nightlight (Filtro Luce Blu)

Per usare il filtro notturno, puoi usare `gammastep` o `redshift`:

```bash
sudo apt install \
  gammastep
```

**Oppure:**
```bash
sudo apt install \
  redshift
```

---

## Compilazione di Niri

### Opzione A: Compilare da Sorgente (Versione Più Recente)

```bash
# 1. Installa Rust (se non già fatto)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 2. Clona la repository Niri
git clone https://github.com/YaLTeR/niri.git
cd niri

# 3. Compila con ottimizzazioni
cargo build --release

# 4. Installa l'eseguibile
sudo install -D target/release/niri /usr/local/bin/niri

# 5. Crea il file di sessione per SDDM/GDM
sudo tee /usr/share/wayland-sessions/niri.desktop > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Name=Niri
Exec=/usr/local/bin/niri
Comment=Niri: A scrollable-tiling Wayland compositor
DesktopNames=niri
EOF

# 6. Verifica
niri --version
```

**Tempo di compilazione**: 5-15 minuti a seconda del processore.

### Opzione B: Installa dal Pacchetto Debian

```bash
sudo apt install niri
```

**Nota**: La versione nei repo Trixie potrebbe essere leggermente dietro la HEAD di GitHub, ma è stabile.

---

## Configurazione Niri (config.kdl)

### File: `~/.config/niri/config.kdl`

Il tuo config include:

```kdl
environment {
    GDK_BACKEND "wayland"
    QT_QPA_PLATFORM "wayland"
    XDG_CURRENT_DESKTOP "niri"
    XDG_SESSION_TYPE "wayland"
}

/* D-Bus environment propagation — ESSENZIALE per Waybar */
spawn-at-startup "bash" "-c" "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE"
spawn-at-startup "bash" "-c" "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY > /dev/null 2>&1"

/* XDG Desktop Portal */
spawn-at-startup "bash" "-c" "sleep 3 && systemctl --user restart xdg-desktop-portal-gtk.service && sleep 1 && systemctl --user restart xdg-desktop-portal.service > /dev/null 2>&1"

/* Waybar */
spawn-at-startup "bash" "-c" "sleep 3 && waybar > /dev/null 2>&1"

/* Notifications */
spawn-at-startup "dunst"

/* Wallpaper */
spawn-at-startup "swaybg" "-i" "/home/noya/Immagini/blacklodge.jpg" "-m" "fill"

/* Nightlight (blue light filter) */
spawn-at-startup "/home/noya/.config/waybar/scripts/nightlight.sh" "toggle"

/* Bluetooth applet */
spawn-at-startup "blueman-applet"

/* Dynamic theming from wallpaper */
spawn-at-startup "matugen" "image" "/home/noya/Immagini/blacklodge.jpg"

/* Clipboard history */
spawn-at-startup "wl-paste" "--watch" "cliphist" "store"

/* System monitor */
spawn-at-startup "conky" "-c" "~/.config/conky/conky.conf"

/* Include generated colors from matugen */
include "colors.kdl"

/* Layout, window rules, binds ... */
```

### File: `~/.config/niri/colors.kdl`

Questo file viene generato automaticamente da `matugen`:

```kdl
// Generated by matugen from wallpaper
layout {
    focus-ring {
        width 4
        active-color "#<color-from-wallpaper>"
    }
}
```

Non modificare manualmente — `matugen` lo rigenera ogni volta che cambia il wallpaper.

### Sintassi KDL Importante

- **Stringhe**: Usa `"doppi apici"` per stringhe, non virgolette singole
- **Blocchi**: `spawn-at-startup` è un comando, non un blocco — non serve `{}`
- **Commenti**: `//` per linee singole, `/* */` per blocchi
- **No virgole**: KDL non richiede virgole fra attributi

### Errori Comuni in config.kdl

| Errore | Causa | Soluzione |
|--------|-------|-----------|
| `unexpected node 'match-app-id'` | Sintassi vecchia (Niri < 26.00) | Usa `match app-id="..."` invece |
| `unexpected node 'block-out-from-margins'` | Attributo non esiste | Rimuovi completamente |
| `error parsing KDL` | Virgolette singole `'string'` | Usa sempre `"doppi apici"` |
| `include: file not found: colors.kdl` | File non esiste | Esegui manualmente `matugen image <wallpaper>` |

---

## Configurazione Waybar

### File: `~/.config/waybar/config`

JSON config per Waybar con moduli Niri-compatibili e custom script per mounts:

```json
{
    "layer": "top",
    "position": "top",
    "exclusive": true,
    "gtk-layer-shell": true,
    "height": 36,
    "output": "eDP-1",
    "modules-left": [
        "custom/launcher",
        "niri/workspaces",
        "niri/window"
    ],
    "modules-center": [
        "clock"
    ],
    "modules-right": [
        "custom/mounts",
        "tray",
        "battery",
        "pulseaudio",
        "network",
        "custom/power"
    ]
}
```

### File: `~/.config/waybar/style.css`

Tema Dracula con colori semantici.

### Custom Module: Montaggio Dischi

Aggiungi nel config JSON:

```json
"custom/mounts": {
    "format": "{}",
    "exec": "~/.config/waybar/scripts/mounts.sh waybar",
    "interval": 5,
    "on-click": "~/.config/waybar/scripts/mounts.sh toggle",
    "tooltip": true
}
```

Copia lo script `/path/to/mounts.sh` in `~/.config/waybar/scripts/mounts.sh` e rendilo eseguibile:

```bash
chmod +x ~/.config/waybar/scripts/mounts.sh
```

---

## Componenti Aggiuntivi

### Matugen — Dynamic Theming

**Cosa fa:**
Genera una palette colori dal wallpaper corrente e scrive i valori in `~/.config/niri/colors.kdl`. Questo consente al `focus-ring` di adattarsi automaticamente al wallpaper.

**Setup:**
```bash
# Nel config.kdl
spawn-at-startup "matugen" "image" "/percorso/al/wallpaper.jpg"

# Includi il file generato
include "colors.kdl"
```

**Test:**
```bash
matugen image /home/noya/Immagini/blacklodge.jpg
cat ~/.config/niri/colors.kdl
```

### Clipboard History — cliphist

**Cosa fa:**
Mantiene una history degli appunti (testo copiato). Accessibile via `Mod+A`.

**Setup:**
```kdl
spawn-at-startup "wl-paste" "--watch" "cliphist" "store"

# Nel binds:
Mod+A { spawn "bash" "-c" "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"; }
```

**Test:**
```bash
# Copia del testo
echo "test" | wl-copy

# Lista clipboard
cliphist list

# Incolla da history
cliphist list | fuzzel --dmenu | cliphist decode | wl-copy
```

### Conky — System Monitor

**Cosa fa:**
Monitor di sistema (CPU, RAM, temperatura, disco) personalizzabile. Puoi posizionarlo come finestra floating o sul desktop.

**Setup:**
```kdl
spawn-at-startup "conky" "-c" "~/.config/conky/conky.conf"

window-rule {
    match app-id="conky"
    open-floating true
}
```

**Config minimale `~/.config/conky/conky.conf`:**
```
conky.config = {
    alignment = 'top_right',
    background = true,
    border_width = 0,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    gap_x = 10,
    gap_y = 10,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_argb_visual = true,
    own_window_transparent = true,
    own_window_type = 'desktop',
    text_buffer_size = 32768,
    update_interval = 1.0,
    uppercase = false,
    use_spacer = 'none',
    use_xft = true,
};

conky.text = [[
CPU: $cpu%
RAM: $memperc%
Temp: ${hwmon 0 temp 1}°C
Disk: ${fs_used /}/${fs_size /}
]];
```

### Nightlight — Filtro Luce Blu

Script personalizzato per abilitare/disabilitare `gammastep`:

**File: `~/.config/waybar/scripts/nightlight.sh`**

```bash
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
```

Rendi eseguibile:
```bash
chmod +x ~/.config/waybar/scripts/nightlight.sh
```

---

## Configurazione Waybar Moduli

### Moduli Disponibili per Niri

| Modulo | Stato | Note |
|--------|-------|-------|
| `niri/workspaces` | ✅ | Mostra i workspace Niri |
| `niri/window` | ✅ | Titolo della finestra attiva |
| `clock` | ✅ | Orologio e data |
| `battery` | ✅ | Batteria (BAT0, BAT1) |
| `pulseaudio` | ✅ | Volume audio |
| `network` | ✅ | Stato rete |
| `cpu` | ✅ | Utilizzo CPU |
| `memory` | ✅ | Utilizzo RAM |
| `disk` | ✅ | Spazio disco |
| `temperature` | ✅ | Temperatura sensori |
| `backlight` | ✅ | Luminosità schermo |
| `tray` | ✅ | System tray |
| `custom/*` | ✅ | Script personalizzati |
| `sway/workspaces` | ❌ | Solo Sway |
| `hyprland/workspaces` | ❌ | Solo Hyprland |

---

## Troubleshooting Completo

### Problema 1: Niri Non Compila — `error: could not find libseat`

**Sintomo:**
```
error: linking with 'cc' failed: exit code 1
  = note: ld: cannot find -lseat
```

**Causa:** Manca `libseat-dev`

**Soluzione:**
```bash
sudo apt install libseat-dev
cargo build --release
```

---

### Problema 2: Waybar Non Appare a Schermo

**Sintomi:**
- Processo Waybar attivo (`ps aux | grep waybar`)
- Nessun output di errore nel log
- La barra non è visibile sullo schermo

**Soluzione (come trattato nel README base):**

Aggiungi nel `config.kdl`:
```kdl
spawn-at-startup "bash" "-c" "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY"
spawn-at-startup "bash" "-c" "sleep 3 && systemctl --user restart xdg-desktop-portal-gtk.service && sleep 1 && systemctl --user restart xdg-desktop-portal.service"
spawn-at-startup "bash" "-c" "sleep 3 && waybar"
```

---

### Problema 3: matugen Non Genera colors.kdl

**Sintomo:**
```
error: include: file not found: colors.kdl
```

**Causa:** `matugen` non è installato o non è stato eseguito

**Soluzione:**
```bash
# Installa matugen
cargo install matugen

# Esegui manualmente per testare
matugen image /home/noya/Immagini/blacklodge.jpg

# Verifica che il file sia stato creato
cat ~/.config/niri/colors.kdl

# Se non esiste ancora, crea un placeholder
touch ~/.config/niri/colors.kdl
```

---

### Problema 4: cliphist Non Salva gli Appunti

**Sintomo:**
```
Mod+A apre fuzzel vuoto
cliphist list restituisce nulla
```

**Causa:** `wl-paste --watch cliphist store` non è in esecuzione

**Verifica:**
```bash
pgrep -a wl-paste
```

**Soluzione:**
```bash
# Assicurati che nel config.kdl sia presente
# spawn-at-startup "wl-paste" "--watch" "cliphist" "store"

# Verifica i pacchetti
sudo apt install wl-clipboard cliphist

# Riavvia Niri
niri msg action quit
niri &
```

---

### Problema 5: Conky Non Appare

**Sintomo:**
```
Conky non è visibile, o è nascosto dietro le finestre
```

**Causa:** Window rule mancante o posizionamento sbagliato

**Soluzione:**
```kdl
window-rule {
    match app-id="conky"
    open-floating true
}
```

Se conky è ancora nascosto, prova a modificare il percorso della config:
```bash
conky -c ~/.config/conky/conky.conf
```

---

### Problema 6: Bluetooth Applet Non Appare

**Sintomo:**
```
blueman-applet non compare nel tray
```

**Causa:** Dipendenze mancanti o D-Bus non configurato

**Soluzione:**
```bash
sudo apt install blueman
pkill blueman-applet
blueman-applet &
```

---

## Quick Start

### Setup Veloce (10 minuti)

```bash
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
  brightnessctl wpctl pavucontrol slurp grim \
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

# 4. Installa matugen
cargo install matugen

# 5. Crea directory di config
mkdir -p ~/.config/niri
mkdir -p ~/.config/waybar/scripts
mkdir -p ~/.config/fuzzel
mkdir -p ~/.config/dunst
mkdir -p ~/.config/conky

# 6. Copia i file di config forniti
# Copia: config.kdl, waybar/config, waybar/style.css, fuzzel/fuzzel.ini, dunst/dunstrc
# Copia: waybar/scripts/mounts.sh, waybar/scripts/nightlight.sh

# 7. Genera colori iniziali
matugen image /percorso/al/wallpaper.jpg

# 8. Avvia Niri
niri
```

---

## Comandi Utili

```bash
# Verificare versione Niri
niri --version

# Controllare output monitor
niri msg outputs

# Visualizzare event stream
niri msg event-stream

# Inviare azioni via IPC
niri msg action quit

# Riavviare Waybar
pkill waybar && sleep 1 && waybar &

# Debug D-Bus
systemctl --user status xdg-desktop-portal

# Verificare batteria
cat /sys/class/power_supply/BAT0/capacity

# Luminosità
brightnessctl get
brightnessctl set 50%

# Clipboard history
cliphist list

# Generare colori da wallpaper
matugen image /home/noya/Immagini/wallpaper.jpg

# Testare nightlight
~/.config/waybar/scripts/nightlight.sh toggle

# Montare dischi
~/.config/waybar/scripts/mounts.sh list
~/.config/waybar/scripts/mounts.sh toggle

# Reload config.kdl (riavvia Niri)
niri msg action quit && niri &
```

---

## Risorse Utili

- **Niri GitHub**: https://github.com/YaLTeR/niri
- **Waybar Wiki**: https://github.com/Alexays/Waybar/wiki
- **KDL Language**: https://kdl.dev/
- **matugen**: https://github.com/InioX/matugen
- **Conky**: https://github.com/brndnmtthws/conky
- **Blueman**: https://github.com/blueman-project/blueman

---

**Ultima modifica**: Maggio 2026
**Testato su**: Debian Trixie (Testing), Niri 26.04+, Waybar 0.12.0
