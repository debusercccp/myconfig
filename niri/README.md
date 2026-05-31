# Niri Setup su Debian Trixie (Testing)

Guida completa per compilare **Niri** (compositor Wayland scrollante), configurare **Waybar** (barr
a di stato) e risolvere i problemi comuni su **Debian Trixie**.

---

## Sommario
1. [Prerequisiti](#prerequisiti)
2. [Librerie e Pacchetti Installati](#librerie-e-pacchetti-installati)
3. [Compilazione di Niri](#compilazione-di-niri)
4. [Configurazione Niri (config.kdl)](#configurazione-niri-configkdl)
5. [Configurazione Waybar](#configurazione-waybar)
6. [Troubleshooting Completo](#troubleshooting-completo)
7. [Quick Start](#quick-start)

---

## Prerequisiti
- **OS**: Debian Trixie (testing)
- **Hardware**: Laptop con monitor integrato (eDP-1) o display esterno
- **Rust**: Cargo installato via rustup
- **Shell**: bash o zsh

---

## Librerie e Pacchetti Installati
### Dipendenze di Build (per compilare Niri da sorgente)
Questi pacchetti permettono a cargo di compilare il codice Rust di Niri:

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
  libdisplay-info-dev \
  gammastep \
  blueman \
  rfkill \
  psmisc
usermod -aG video $USER
chmod +s /usr/sbin/rfkill
```

**Dettagli:**
- build-essential: gcc, make, e strumenti base
- pkg-config: Helper per localizzare librerie di sistema
- libseat-dev: **CRITICO** — gestione sessioni hardware (senza questo Niri non compila)
- libwayland-dev: Protocollo Wayland
- libpipewire-0.3-dev: Audio/video streaming
- libinput-dev: Input device (mouse, tastiera)
- libgbm-dev, libxkbcommon-dev, libpixman-1-dev, libudev-dev, libdisplay-info-dev: Rendering e system utilities

### Componenti Runtime (Desktop Environment)

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

**O**, se compili Niri da sorgente e installi solo i componenti essenziali:
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
  libgtk-layer-shell0
```

**Dettagli:**
- qt5-wayland, qt6-wayland: Rendering nativo Wayland per app Qt/KDE
- qt5ct, qt6ct: Tema grafico per applicazioni Qt
- fonts-*: Font per icone (FontAwesome, Nerd Fonts per Waybar)
- libgtk-layer-shell0: **ESSENZIALE** — permette a Waybar di ancorare le finestre ai bordi dello schermo via wlr-layer-shell protocol

### Clipboard e Gestione Appunti

```bash
sudo apt install \
  wl-clipboard \
  cliphist
```

**Dettagli:**
- wl-clipboard: Fornisce wl-copy e wl-paste, necessari per la clipboard Wayland
- cliphist: Demone che mantiene la history degli appunti; usato con wl-paste --watch cliphist store e richiamato via fuzzel con Mod+A

### Sicurezza e Blocco Schermo

```bash
sudo apt install \
  swaylock
```

**Dettagli:**
- swaylock: Screen locker Wayland; attivato con Mod+L (keybinding allow-when-locked=true)

### Applicazioni Desktop

```bash
sudo apt install \
  dolphin \
  galculator \
  firefox-esr
```

**Dettagli:**
- dolphin: File manager KDE; aperto con Mod+E e XF86MyComputer
- galculator: Calcolatrice GTK; attivata con il tasto XF86Calculator
- firefox-esr: Browser; attivato con il tasto XF86HomePage
**Nota:** firefox-esr è la versione disponibile nei repo Debian. Se preferisci Firefox stabile o nightly, scaricalo dal sito ufficiale Mozilla.

### Matugen (Theming Dinamico)

matugen non e' disponibile nei repo Debian e va installato separatamente. E' il motore che genera la palette colori da un wallpaper e la scrive in colors.kdl (incluso da config.kdl).
**Installazione tramite Cargo:**

```bash
cargo install matugen
```
**O tramite release precompilata (GitHub):**

```bash
# Scarica l'ultimo binario da https://github.com/InioX/matugen/releases
curl -L https://github.com/InioX/matugen/releases/latest/download/matugen-x86_64-unknown-linux-gnu.tar.gz | tar xz
sudo install -D matugen /usr/local/bin/matugen
```

**Utilizzo nel config.kdl:**

```kdl
spawn-at-startup "matugen" "image" "/home/noya/Immagini/blacklodge.jpg"
```

Questo comando genera ~/.config/niri/colors.kdl con i valori della focus-ring ricavati dal wallpaper.

### Utility Optional (ma Consigliato)

```bash
sudo apt install \
  brightnessctl \
  wpctl \
  pavucontrol \
  slurp \
  grim
```

---

## Compilazione di Niri
### Opzione A: Compilare da Sorgente (Versione Piu' Recente)

```bash
# 1. Installa Rust (se non gia' fatto)
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

### Opzione B: Installa dal Pacchetto Debian (se disponibile)

```bash
sudo apt install niri
```

**Nota**: La versione nei repo Trixie potrebbe essere leggermente dietro la HEAD di GitHub, ma e' stabile.

---

## Configurazione Niri (config.kdl)
### File: ~/.config/niri/config.kdl

```kdl
environment {
    GDK_BACKEND "wayland"
    QT_QPA_PLATFORM "wayland"
    XDG_CURRENT_DESKTOP "niri"
    XDG_SESSION_TYPE "wayland"
}
// Propaga le variabili a D-Bus per xdg-desktop-portal
spawn-at-startup "bash" "-c" "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY"
// Riavvia i portal per garantire funzionamento
spawn-at-startup "bash" "-c" "sleep 1 && systemctl --user restart xdg-desktop-portal-gtk.service && sleep 1 && systemctl --user restart xdg-desktop-portal.service"
// Avvia Waybar (con delay di sicurezza)
spawn-at-startup "bash" "-c" "sleep 3 && waybar"
// Gestione notifiche
spawn-at-startup "dunst"
// Sfondo (opzionale, commenta se preferisci uno sfondo diverso)
spawn-at-startup "swaybg" "-i" "/usr/share/desktop-base/active-theme/wallpaper/contents/images/1920x1080.svg" "-m" "fill"
// Window rules
window-rule {
    match app-id="waybar"
    draw-border-with-background false
}
window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}
// Keybindings
binds {
    Mod+Q { spawn "kitty"; }
    Mod+C { close-window; }
    Mod+R { spawn "fuzzel"; }
    Mod+Shift+E { quit; }
    // Navigazione tra colonne
    Mod+Left  { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up    { focus-window-or-workspace-up; }
    Mod+Down  { focus-window-or-workspace-down; }
    // Movimento finestre
    Mod+Ctrl+Left  { move-column-left; }
    Mod+Ctrl+Right { move-column-right; }
    // Layout
    Mod+F { maximize-column; }
    Mod+Comma  { consume-window-into-column; }
    Mod+Period { expel-window-from-column; }
}
```

### Sintassi KDL Importante
- **Stringhe**: Usa "doppi apici" per stringhe, non virgolette singole
- **Blocchi**: spawn-at-startup e' un comando, non un blocco — non serve {}
- **Commenti**: // per linee singole
- **No virgole**: KDL non richiede virgole fra attributi

### Errori Comuni in config.kdl
| Errore | Causa | Soluzione |
|--------|-------|-----------|
| unexpected node 'match-app-id' | Sintassi vecchia (Niri < 26.00) | Usa match app-id="..." invece |
| unexpected node 'block-out-from-margins' | Attributo non esiste in questa versione | Rimuovi completamente |
| error parsing KDL | Virgolette singole usate come 'string' | Usa sempre "doppi apici" |
| unknown variable WAYLAND_DISPLAY | Variabile d'ambiente non definita | Aggiungi a environment { ... } |
---
## Configurazione Waybar
### File: ~/.config/waybar/config

Copia il file JSON fornito (waybar-niri/config). Punti chiave:

```json
{
    "layer": "top",
    "position": "top",
    "exclusive": true,
    "gtk-layer-shell": true,
    "height": 36,
    "output": "eDP-1",
    "modules-left": [ "custom/launcher", "niri/workspaces", "niri/window" ],
    "modules-center": [ "clock" ],
    "modules-right": [ "battery", "pulseaudio", "network", "custom/power" ]
}
```

**Parametri critici:**
- layer: "top" — mette la barra sopra tutte le finestre
- exclusive: true — Niri riserva lo spazio per la barra (non copre le finestre)
- gtk-layer-shell: true — abilita il protocollo wlr-layer-shell
- output: "eDP-1" — specifico per il tuo monitor (vedi sotto come trovarlo)
- modules-* — moduli disponibili per Niri (non usare sway/* o hyprland/*)

### File: ~/.config/waybar/style.css

Copia il file CSS fornito (waybar-niri/style.css). Theme Dracula con colori semantici.

### Trovare il Nome Corretto del Monitor

```bash
# Metodo 1: niri
niri msg outputs
# Output: LG Display 0x0470 Unknown (eDP-1)
# Metodo 2: wlr-randr (se installato)
wlr-randr
# Metodo 3: xrandr (su X11, non funziona su Wayland direttamente)
xrandr
# Metodo 4: /sys
ls /sys/class/drm/
```

Se il tuo monitor si chiama diversamente (es. HDMI-1, DP-2), aggiorna il config di Waybar:

```json
"output": "HDMI-1"
```

### Moduli Supportati in Waybar su Niri
| Modulo | Stato | Note |
|--------|-------|-------|
| niri/workspaces | SI | Mostra i workspace Niri |
| niri/window | SI | Titolo della finestra attiva |
| clock | SI | Orologio e data |
| battery | SI | Batteria (specifiche BAT0/BAT1) |
| pulseaudio | SI | Volume audio |
| network | SI | Stato rete |
| cpu | SI | Utilizzo CPU |
| memory | SI | Utilizzo RAM |
| disk | SI | Spazio disco |
| temperature | SI | Temperatura sensori |
| backlight | SI | Luminosita' schermo |
| tray | SI | System tray |

| custom/* | SI | Script personalizzati |
---

## Compilare conky

```bash
# Clona il codice ed esegui il checkout della versione corretta
git clone https://github.com/brndnmtthws/conky.git
cd conky
git checkout v1.22.2

# Genera la build abilitando esplicitamente Wayland
mkdir build && cd build
cmake .. \
  -DBUILD_WAYLAND=ON \
  -DBUILD_X11=ON \
  -DBUILD_LUA_CAIRO=ON \
  -DBUILD_LUA_IMLIB2=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local

# Compila usando tutti i core disponibili e installa
make -j$(nproc)
sudo make install
```

---

## Troubleshooting Completo
### Problema 1: Niri Non Compila — error: could not find libseat
**Sintomo:**

error: linking with 'cc' failed: exit code 1
  = note: ld: cannot find -lseat

**Causa:** Manca libseat-dev
**Soluzione:**

```bash
sudo apt install libseat-dev
cargo build --release  # Ricompila
```

---

### Problema 2: Waybar Non Appare a Schermo
**Sintomi:**
- Processo Waybar attivo (ps aux | grep waybar)
- Nessun output di errore nel log
- La barra non e' visibile sullo schermo
**Cause Comuni:**

#### A. D-Bus Non Propagato (CAUSA PIU' COMUNE)
Il compositor Niri non propaga automaticamente le variabili d'ambiente a D-Bus, quindi:
1. xdg-desktop-portal fallisce silenziosamente
2. GTK non riesce a creare la surface Wayland
3. Waybar parte ma non renderizza
**Sintomi specifici:**

```bash
waybar 2>&1 | grep -i portal
```

# Output:
# [error] Errore nel chiamare StartServiceByName per org.freedesktop.portal.Desktop: E' stato raggiunto il timeout

**Soluzione:**
Aggiungi nel config.kdl come **primo spawn-at-startup**:

```kdl
spawn-at-startup "bash" "-c" "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY"
spawn-at-startup "bash" "-c" "sleep 1 && systemctl --user restart xdg-desktop-portal-gtk.service && sleep 1 && systemctl --user restart xdg-desktop-portal.service"
spawn-at-startup "bash" "-c" "sleep 3 && waybar"
```

O, per test immediato:

```bash
dbus-update-activation-environment --systemd WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=niri XDG_SESSION_TYPE=wayland DISPLAY=$DISPLAY
systemctl --user restart xdg-desktop-portal-gtk.service
sleep 1
systemctl --user restart xdg-desktop-portal.service
sleep 2
waybar 2>&1
```

#### B. Monitor Output Sbagliato

Se hai piu' monitor, Waybar potrebbe avviarsi su uno non visibile.
**Debug:**

```bash
niri msg outputs
# Leggi il nome corretto (es. eDP-1, HDMI-1, DP-1)
# Aggiorna config
"output": "HDMI-1"  # Cambia nel file config di Waybar
```

#### C. Variabili d'Ambiente Mancanti
Waybar deve avere accesso a WAYLAND_DISPLAY e XDG_RUNTIME_DIR.
**Debug:**

```bash
echo $WAYLAND_DISPLAY  # Deve essere: wayland-1 (o simile)
echo $XDG_RUNTIME_DIR  # Deve essere: /run/user/1000
ls $XDG_RUNTIME_DIR/wayland*  # Deve esistere il socket
```

Se vuote, lancia Waybar con:

```bash
WAYLAND_DISPLAY=wayland-1 waybar 2>&1
```

#### D. GTK Compilation Senza Debug
Se vedi:

Gtk-WARNING **: GTK_DEBUG set but ignored because gtk isn't built with G_ENABLE_DEBUG

Non e' un errore fatale. GTK e' compilato senza debug e non puoi usare GTK_DEBUG=all. Ignora questo warning.
---
### Problema 3: Waybar Crasha con Segmentation Fault
**Sintomo:**

Segmentazione non corretta (core dump creato)

**Causa:** Conflitto tra istanze di xdg-desktop-portal (una gira gia', ne avvii un'altra)
**Soluzione:**

```bash
pkill -f xdg-desktop-portal
sleep 1
systemctl --user restart dbus.service
sleep 1
systemctl --user start xdg-desktop-portal
sleep 1
waybar 2>&1
```

---

### Problema 4: Waybar Timeout su Portal D-Bus
**Sintomo:**

[error] Errore nel chiamare StartServiceByName per org.freedesktop.impl.portal.desktop.gtk: E' stato raggiunto il timeout

**Causa:** xdg-desktop-portal-gtk.service non parte perche' manca l'environment.
**Debug:**

```bash
journalctl --user -xeu xdg-desktop-portal.service --no-pager | tail -30
journalctl --user -xeu xdg-desktop-portal-gtk.service --no-pager | tail -30
```

**Soluzione:** Vedi **Problema 2A** sopra — aggiungi dbus-update-activation-environment.

---

### Problema 5: Moduli Sway/Hyprland Disabilitati
**Sintomo:**

[warning] module sway/workspaces: Disabling module "sway/workspaces", Socket path is empty
[warning] module hyprland/language: Disabling module "hyprland/language", Socket path is empty

**Causa:** Waybar e' configurato per un altro compositor (Sway/Hyprland), non Niri.
**Soluzione:** Usa niri/workspaces al posto di sway/workspaces nel config JSON.

---

### Problema 6: Permessi Denied su Input Devices
**Sintomo:**

[warning] Can't open /dev/input/event* (are you in the input group?): EACCES Permesso negato

**Causa:** L'utente non appartiene al gruppo input (necessario per moduli come keyboard-state).
**Soluzione (opzionale):**

```bash
sudo usermod -aG input $USER
# Logout e login per applicare
```

---

### Problema 7: Batteria Non Rilevata
**Sintomo:**

[warning] No battery named BAT2

**Causa:** Il tuo laptop ha una batteria con nome diverso.
**Debug:**

```bash
ls /sys/class/power_supply/
# Output: ACAD  BAT0
# (non BAT2)
```

**Soluzione:** Aggiorna il config Waybar:

```json
"battery": {
    "bat": "BAT0",
    ...
}
```
---

### Problema 8: Luminosita' (Backlight) Non Funziona
**Sintomo:**

```bash
incbrightness: command not found
decbrightness: command not found
```

**Causa:** Script personalizzati non disponibili. Su Debian si usa brightnessctl.
**Soluzione:**

```bash
sudo apt install brightnessctl
```

# Nel config Waybar, usa:
"backlight": {
    "device": "intel_backlight",
    "on-scroll-up": "brightnessctl set 5%+",
    "on-scroll-down": "brightnessctl set 5%-",
    ...
}

---

### Problema 9: Niri Esce al Riavvio della Sessione
**Sintomo:** Dopo niri msg action quit, quando rientra non carica il config.kdl
**Causa:** File in uso o sintassi errata in config.kdl
**Soluzione:**

```bash
# Verifica la sintassi
cat ~/.config/niri/config.kdl | kdl --validate
# (se kdl-cli e' disponibile)
# O avvia Niri manualmente per vedere gli errori
niri
```

# Nel log comparira' il messaggio d'errore esatto

---

### Problema 10: cliphist Non Salva gli Appunti
**Sintomo:** Mod+A apre fuzzel vuoto o il comando cliphist list non restituisce nulla.
**Causa:** wl-paste --watch cliphist store non e' in esecuzione, oppure cliphist non e' installato.
**Verifica:**

```bash
pgrep -a wl-paste
# Deve mostrare: wl-paste --watch cliphist store
```

**Soluzione:** Assicurati che nel config.kdl sia presente:

```kdl
spawn-at-startup "wl-paste" "--watch" "cliphist" "store"
```

E che entrambi i pacchetti siano installati:

```bash
sudo apt install wl-clipboard cliphist
```

---

## Quick Start
### Setup Veloce (5 minuti)
# 1. Installa dipendenze

```bash
sudo apt install -y \
  build-essential pkg-config libwayland-dev libpango1.0-dev \
  libpipewire-0.3-dev libinput-dev libseat-dev libgbm-dev \
  libxkbcommon-dev libpixman-1-dev libudev-dev libdisplay-info-dev \
  waybar fuzzel dunst swaybg kitty \
  xdg-desktop-portal xdg-desktop-portal-gtk \
  fonts-font-awesome libgtk-layer-shell0 \
  brightnessctl \
  wl-clipboard cliphist \
  swaylock \
  dolphin galculator firefox-esr \
  blueman
```

# 2. Compila Niri (opzionale se usi il pacchetto)

```bash
git clone https://github.com/YaLTeR/niri.git
cd niri
cargo build --release
sudo install -D target/release/niri /usr/local/bin/niri
# 3. Installa matugen
cargo install matugen
# oppure scarica il binario precompilato da GitHub Releases
# 4. Crea config.kdl
mkdir -p ~/.config/niri
# Copia il file config.kdl fornito
# 5. Copia config Waybar
mkdir -p ~/.config/waybar
cp config ~/.config/waybar/config
cp style.css ~/.config/waybar/style.css
# 6. Avvia Niri
niri
# 7. Da un terminale in Niri, testa Waybar
pkill waybar && waybar &
```

---

## File Aggiuntivi
I seguenti file sono forniti nella cartella waybar-niri/:
- config — Config JSON per Waybar (moduli Niri, tema Dracula)
- style.css — CSS con palette Dracula, colori semantici
Copiali:

```bash
cp config ~/.config/waybar/config
cp style.css ~/.config/waybar/style.css
```

---

## Risorse Utili
- **Niri GitHub**: https://github.com/YaLTeR/niri
- **Waybar Wiki**: https://github.com/Alexays/Waybar/wiki
- **KDL Language**: https://kdl.dev/
- **Wayland Protocol**: https://wayland.freedesktop.org/
- **xdg-desktop-portal**: https://github.com/flatpak/xdg-desktop-portal
- **matugen**: https://github.com/InioX/matugen
---
## Contatti e Feedback
Se riscontri problemi non documentati qui:
1. Controlla i log di Niri: journalctl -u niri (se installato come systemd service)
2. Apri un issue su GitHub: https://github.com/YaLTeR/niri/issues
3. Consulta la community: Discord Niri, forum Wayland
---
**Ultima modifica**: Maggio 2026
**Testato su**: Debian Trixie (Testing), Niri 26.04, Waybar 0.12.0
