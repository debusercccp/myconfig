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
6. [Calendario Google (Waybar + TUI)](#calendario-google-waybar--tui)
7. [Menu Wi-Fi (Waybar + wpa\_cli)](#menu-wi-fi-waybar--wpa_cli)
8. [Compilare conky](#compilare-conky)
9. [Troubleshooting Completo](#troubleshooting-completo)
10. [Quick Start](#quick-start)

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

### Utility Optional (ma Consigliato)

```bash
sudo apt install \
  brightnessctl \
  wpctl \
  pavucontrol \
  slurp \
  grim
```

### Servizi di Sessione e Idle

Questi pacchetti sono richiesti dagli `spawn-at-startup` e dai keybinding nel `config.kdl` attuale:

```bash
sudo apt install \
  swayidle \
  polkit-kde-agent-1 \
  playerctl \
  network-manager \
  xwayland-satellite
```

**Dettagli:**
- swayidle: gestione idle — blocca a 5 min (`swaylock -f`), spegne i monitor a 10 min, blocca prima della sospensione
- polkit-kde-agent-1: agente PolicyKit, fornisce i prompt grafici di autenticazione (montaggio dischi, ecc.)
- playerctl: controlli multimediali (`XF86AudioPlay/Pause/Next/Prev`)
- xwayland-satellite: server Xwayland on-demand su `:0` per le app X11 (Niri è Wayland-puro)

**Nota WiFi:** se il Wi-Fi è gestito da `wpa_supplicant` direttamente (non da NetworkManager),
il modulo `network` di Waybar usa `wifi-menu.py` + `wpa_cli` invece di `nmtui`.
Vedi la sezione [Menu Wi-Fi (Waybar + wpa_cli)](#menu-wi-fi-waybar--wpa_cli) per il setup.

**Nota:** se `xwayland-satellite` non è nei repo, compilalo da sorgente:

```bash
cargo install xwayland-satellite
```

Inoltre il `config.kdl` lancia diversi script personalizzati in `~/.config/waybar/scripts/`:
- `nightlight.sh` — filtro luce blu (toggle all'avvio e dal modulo Waybar)
- `powermenu.sh` — menù sessione (`Mod+Shift+P`)
- `cal-sync.py` / `cal-tui.sh` / `calendar.sh` — calendario Google (vedi sezione dedicata)

### Calendario Google (Waybar + TUI)

Il modulo calendario sincronizza Google Calendar via indirizzo iCal e mostra un
TUI interattivo. Richiede Python (virtualenv generato da `cal-setup.sh`), `kitty`,
`nvim` per le note del giorno e `blueman` già installato sopra:

```bash
sudo apt install \
  python3-venv \
  nvim
```

Il virtualenv (`~/.config/waybar/.calvenv`) installa le librerie iCal
(`icalendar`, `recurring-ical-events`); vedi [Calendario Google (Waybar + TUI)](#calendario-google-waybar--tui).

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

La configurazione è divisa in due file:
- `config.kdl` — configurazione principale (layout, regole finestre, startup, keybinding, input)
- `colors.kdl` — palette (focus-ring/bordi, Dracula), incluso da `config.kdl` con `include "colors.kdl"`

```kdl
// Salta l'overlay degli hotkey all'avvio
hotkey-overlay { skip-at-startup }

// Cursore esplicito (tema + dimensione)
cursor {
    xcursor-theme "Adwaita"
    xcursor-size 24
}

// Su kernel modificati il piano cursore KMS può non renderizzare:
// forza il compositing software del cursore.
debug { disable-cursor-plane }

include "colors.kdl"

environment {
    GDK_BACKEND "wayland"
    QT_QPA_PLATFORM "wayland"
    XDG_CURRENT_DESKTOP "niri"
    XDG_SESSION_TYPE "wayland"
    XCURSOR_THEME "Adwaita"
    XCURSOR_SIZE "24"
    DISPLAY ":0"            // per le app X11 servite da xwayland-satellite
}

// --- Layer rules ---
// Sfondo (swaybg) dietro alle finestre
layer-rule {
    match namespace="^wallpaper$"
    place-within-backdrop true
}

// --- Window rules ---
window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}
window-rule {
    match app-id="waybar"
    draw-border-with-background false
}
window-rule {
    match app-id="kitty"
    geometry-corner-radius 8
    draw-border-with-background false
    opacity 0.80
}
window-rule {
    match app-id="nmtui"        // impostazioni Wi-Fi da Waybar
    open-floating true
    default-column-width { fixed 720; }
    default-window-height { fixed 480; }
}
window-rule {
    match app-id="cal-tui"      // calendario TUI (click sull'icona Waybar)
    open-floating true
    default-column-width { proportion 0.6; }
    default-window-height { proportion 0.75; }
}
window-rule {
    match app-id="conky"
    open-floating true
}

// --- Startup ---
spawn-at-startup "bash" "-c" "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY > /dev/null 2>&1"
spawn-at-startup "bash" "-c" "sleep 3 && systemctl --user restart xdg-desktop-portal-gtk.service && sleep 1 && systemctl --user restart xdg-desktop-portal.service > /dev/null 2>&1"
spawn-at-startup "bash" "-c" "sleep 3 && waybar > /dev/null 2>&1"
spawn-at-startup "dunst"
spawn-at-startup "swaybg" "-i" "/home/noya/Immagini/blacklodge.jpg" "-m" "fill"
spawn-at-startup "/home/noya/.config/waybar/scripts/nightlight.sh" "toggle"
spawn-at-startup "xwayland-satellite"
spawn-at-startup "swayidle" "-w" \
    "timeout" "300" "swaylock -f" \
    "timeout" "600" "niri msg action power-off-monitors" \
    "resume" "niri msg action power-on-monitors" \
    "before-sleep" "swaylock -f"
spawn-at-startup "blueman-applet"
spawn-at-startup "wl-paste" "--watch" "cliphist" "store"
spawn-at-startup "bash" "-c" "sleep 5 && conky -c ~/.config/conky/conky.conf"

// --- Input ---
input {
    keyboard {
        xkb { layout "it" }     // layout tastiera italiano
        repeat-delay 300
        repeat-rate 40
    }
    touchpad {
        tap                     // tap-to-click
        dwt                     // disabilita il touchpad mentre scrivi
    }
}

// Keybindings (estratto — vedi la tabella completa sotto)
binds {
    Mod+Q { spawn "kitty"; }
    Mod+C { close-window; }
    Mod+R { spawn "fuzzel"; }
    Mod+Shift+E { quit; }
    Mod+Left  { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Ctrl+Left  { move-column-left; }
    Mod+Ctrl+Right { move-column-right; }
    Mod+F { maximize-column; }
}
```

> **Nota:** `swaybg` punta a `/home/noya/Immagini/blacklodge.jpg`. Cambia il percorso
> con il tuo sfondo. La finestra `kitty` usa opacità 0.80 e tema **Tokyo Night** (vedi `kitty.conf`).

### Tabella Keybindings Completa

| Combinazione | Azione |
|--------------|--------|
| `Mod+Q` | Apri terminale (kitty) |
| `Mod+R` | Apri launcher (fuzzel) |
| `Mod+C` | Chiudi finestra |
| `Mod+E` | File manager (dolphin) |
| `Mod+A` | History appunti (cliphist + fuzzel) |
| `Mod+Shift+E` | Esci da Niri |
| `Mod+L` | Blocca schermo (swaylock) |
| `Mod+Shift+P` | Menù sessione (blocca/logout/sospendi/riavvia/spegni) |
| **Navigazione** | |
| `Mod+←/→` | Sposta focus tra colonne |
| `Mod+↑/↓` | Sposta focus tra finestre/workspace |
| `Mod+U` / `Mod+I` | Workspace giù / su |
| `Mod+Page_Down` / `Mod+Page_Up` | Workspace giù / su |
| `Mod+1..9` | Vai al workspace numerato |
| `Mod+Tab` | Overview |
| **Spostamento finestre** | |
| `Mod+Ctrl+←/→` | Sposta colonna a sinistra/destra |
| `Mod+Ctrl+Page_Down` / `Mod+Ctrl+Page_Up` | Sposta colonna al workspace giù/su |
| `Mod+Ctrl+1..9` | Sposta colonna al workspace numerato |
| `Mod+Comma` / `Mod+Period` | Assorbi/espelli finestra dalla colonna |
| **Layout e dimensioni** | |
| `Mod+F` | Massimizza colonna |
| `Mod+Shift+F` | Fullscreen finestra |
| `Mod+Minus` / `Mod+Plus` | Larghezza colonna -/+ 10% |
| `Mod+Shift+Minus` / `Mod+Shift+Plus` | Altezza finestra -/+ 10% |
| `Mod+BracketLeft` | Preset larghezza colonna |
| `Mod+BracketRight` | Espandi colonna alla larghezza disponibile |
| `Mod+Backslash` | Centra colonna |
| `Mod+V` | Alterna focus floating/tiling |
| `Mod+Shift+V` | Rendi finestra floating |
| **Screenshot** | |
| `Print` | Regione selezionata → file (grim + slurp) |
| `Mod+Print` | UI nativa di Niri (regione + appunti) |
| `Ctrl+Print` | Schermo intero |
| `Alt+Print` | Solo finestra a fuoco |
| **Tasti multimediali / Fn** | |
| `XF86MonBrightnessUp/Down` | Luminosità +/- (brightnessctl) |
| `XF86AudioRaise/LowerVolume` | Volume +/- (wpctl) |
| `XF86AudioMute` / `XF86AudioMicMute` | Muta audio / microfono |
| `XF86AudioPlay/Pause/Next/Prev` | Controlli player (playerctl) |
| `XF86HomePage` | Browser (firefox) |
| `XF86Calculator` | Calcolatrice (galculator) |
| `XF86MyComputer` | dolphin su ~/MiniSSD |
| **Aiuto** | |
| `Mod+Shift+Slash` | Mostra hotkey overlay |

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
    "height": 40,
    "output": "eDP-1",
    "modules-left": [ "custom/launcher", "niri/workspaces", "niri/window" ],
    "modules-center": [ "clock", "custom/calendar" ],
    "modules-right": [
        "custom/mounts", "custom/backup", "tray", "custom/updates",
        "temperature", "cpu", "memory", "disk", "custom/nightlight",
        "bluetooth", "pulseaudio#microphone", "pulseaudio",
        "custom/weather", "battery", "network", "custom/power"
    ]
}
```

**Moduli custom (script in `~/.config/waybar/scripts/`):**
- `custom/calendar` — calendario Google (tooltip mese + click apre il TUI); vedi sezione dedicata
- `custom/mounts` — dischi/partizioni montati (`mounts.sh`)
- `custom/backup` — indicatore di backup `rsync` in corso
- `custom/updates` — aggiornamenti di sistema disponibili (`update-sys`)
- `custom/nightlight` — toggle filtro luce blu (`nightlight.sh`)
- `custom/weather` — meteo via wttr.in (`wttr.py`)
- `custom/launcher` / `custom/power` — icone per fuzzel e menù sessione

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
| bluetooth | SI | Stato Bluetooth (toggle / blueman-manager) |
| custom/* | SI | Script personalizzati (calendario, meteo, mounts, ecc.) |
---

## Calendario Google (Waybar + TUI)

Il calendario integra **Google Calendar** in Waybar (modulo `custom/calendar`) e in un
**TUI interattivo** aperto con un click. Funziona in sola lettura tramite l'indirizzo
segreto **iCal** del calendario — nessuna autenticazione OAuth, nessun token.

### Componenti

| File (in `waybar-niri/`) | Ruolo |
|--------------------------|-------|
| `scripts/calendar.sh` | Modulo Waybar in Bash: testo + tooltip del mese (oggi in blu, giorni con eventi in giallo). Scroll = mese prec./succ., click centrale = reset a oggi |
| `scripts/cal-tui.sh` | TUI a tutto schermo: griglia mensile, navigazione con frecce, `Tab`/`Shift+Tab` salta ai giorni con eventi, `Invio` apre le note del giorno in `nvim`, `t` = oggi, `q` = esci |
| `scripts/cal-sync.py` | Scarica gli iCal, espande gli eventi ricorrenti e scrive la cache in `~/.cache/waybar-calendar/events.json` |
| `scripts/cal-setup.sh` | Crea il virtualenv `~/.config/waybar/.calvenv` e installa `icalendar` + `recurring-ical-events` |
| `cal-tui.conf` | Config `kitty` dedicata al TUI (tema Tokyo Night Storm, opacità 0.70, `app-id cal-tui`) |
| `calendar.conf` | Elenco degli iCal da sincronizzare (`ICS_URL=...`) — **non versionato** |
| `calendar.env` | Segreto reale (`GCAL_ICS_URL=...`) — **non versionato** |

I file `calendar.conf` ed `calendar.env` sono in `.gitignore`: nel repo trovi solo i
relativi `*.example`. Le note del giorno sono file Markdown in
`~/.local/share/waybar-calendar/days/` (editabili in `nvim`, reso con `render-markdown`).

### Setup

```bash
# 1. Crea il virtualenv e installa le librerie iCal (una tantum)
~/.config/waybar/scripts/cal-setup.sh

# 2. Trova l'indirizzo segreto iCal:
#    Google Calendar -> Impostazioni -> (scegli il calendario) ->
#    "Integra il calendario" -> "Indirizzo segreto in formato iCal"

# 3. Inserisci il segreto: copia l'esempio e modifica calendar.env
cp ~/.config/waybar/calendar.env.example ~/.config/waybar/calendar.env
$EDITOR ~/.config/waybar/calendar.env        # GCAL_ICS_URL=https://.../basic.ics

# 4. calendar.conf referenzia la variabile (creato in automatico da cal-setup.sh)
#    ICS_URL=$GCAL_ICS_URL     (puoi ripetere la riga per piu' calendari)

# 5. Primo sync di prova
~/.config/waybar/.calvenv/bin/python ~/.config/waybar/scripts/cal-sync.py
```

> Il segreto **non** va scritto in `calendar.conf`: lì si mette solo il *nome* della
> variabile (`$GCAL_ICS_URL`), il cui valore vive in `calendar.env` (caricato in
> automatico da `cal-sync.py`). Così la configurazione resta versionabile senza esporre l'URL.

---

## Menu Wi-Fi (Waybar + wpa\_cli)

Il modulo `network` di Waybar apre un menu **fuzzel** con tutte le reti Wi-Fi disponibili
quando il Wi-Fi è gestito da `wpa_supplicant` direttamente (non da NetworkManager).

### Componenti

| File (in `waybar-niri/`) | Ruolo |
|--------------------------|-------|
| `wifi-menu.py` | Script Python: scansiona via `wpa_cli`, mostra le reti in fuzzel, connette alle reti note o chiede la password per le nuove |
| `wifi-menu.sudoers` | Regola sudoers da installare una tantum per permettere a `wpa_cli` di girare senza password |

### Funzionamento

- **Click sinistro** sul modulo Wi-Fi → apre il menu fuzzel con le reti trovate
- La rete attiva è marcata con `●`; le reti protette mostrano 󰌾
- **Rete nota** (già salvata in wpa_supplicant) → connessione immediata
- **Rete nuova** → fuzzel chiede la password (nascosta con `--password`), poi connette e salva

### Setup (una tantum)

Il socket di `wpa_supplicant` (`/run/wpa_supplicant/wlp4s0`) è creato con gruppo `root`,
non `netdev`, quindi `wpa_cli` ha bisogno di una regola sudoers senza password:

```bash
sudo install -m 440 ~/.config/waybar/wifi-menu.sudoers /etc/sudoers.d/wifi-menu
# Verifica:
sudo -l | grep wpa_cli
# Deve comparire: NOPASSWD: /usr/sbin/wpa_cli -p /run/wpa_supplicant -i wlp4s0 *
```

> Se il nome dell'interfaccia non è `wlp4s0`, aggiorna sia `wifi-menu.py`
> (variabile `WPA`) che `wifi-menu.sudoers` prima di installare.

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
  swaylock swayidle \
  polkit-kde-agent-1 playerctl \
  network-manager xwayland-satellite \
  slurp grim \
  dolphin galculator firefox-esr \
  blueman \
  python3-venv nvim
```

Per il calendario, dopo l'avvio esegui una volta `~/.config/waybar/scripts/cal-setup.sh`
e configura `calendar.env` (vedi [Calendario Google](#calendario-google-waybar--tui)).

# 2. Compila Niri (opzionale se usi il pacchetto)

```bash
git clone https://github.com/YaLTeR/niri.git
cd niri
cargo build --release
sudo install -D target/release/niri /usr/local/bin/niri
# 3. Crea config.kdl
mkdir -p ~/.config/niri
# Copia il file config.kdl fornito
# 4. Copia config Waybar
mkdir -p ~/.config/waybar
cp config ~/.config/waybar/config
cp style.css ~/.config/waybar/style.css
# 5. Avvia Niri
niri
# 6. Da un terminale in Niri, testa Waybar
pkill waybar && waybar &
```

---

## File Aggiuntivi
I seguenti file sono forniti nella cartella `waybar-niri/`:
- `config` — Config JSON per Waybar (moduli Niri + custom, tema Dracula)
- `style.css` — CSS con palette Dracula, colori semantici
- `colors.css` — variabili colore condivise
- `cal-tui.conf` — config kitty per il calendario TUI (Tokyo Night)
- `calendar.conf.example` / `calendar.env.example` — template per il calendario Google
- `wifi-menu.py` — menu Wi-Fi con fuzzel (usa `wpa_cli`; vedi sezione dedicata)
- `wifi-menu.sudoers` — regola sudoers per `wpa_cli` senza password (da installare con `sudo install`)
- `scripts/` — calendario (`calendar.sh`, `cal-tui.sh`, `cal-sync.py`, `cal-setup.sh`),
  `nightlight.sh`, `powermenu.sh`, `mounts.sh`, `update-sys`, `wttr.py`

Copiali (oppure usa `stow`):

```bash
cp config ~/.config/waybar/config
cp style.css ~/.config/waybar/style.css
cp -r scripts ~/.config/waybar/scripts
```

I file lato Niri stanno in `niri/`:
- `config.kdl` — configurazione principale
- `colors.kdl` — palette (incluso da `config.kdl`)

---

**Ultima modifica**: 27 Giugno 2026
**Testato su**: Debian Trixie (Testing), Niri 26.04, Waybar 0.12.0
