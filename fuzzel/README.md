# Fuzzel Configuration Guide
## Application Launcher per Niri

---

## Installazione

```bash
sudo apt install fuzzel
```

---

## Setup Configurazione

Fuzzel legge la config da:
```
~/.config/fuzzel/fuzzel.ini
/etc/fuzzel/fuzzel.ini
```

Crea la directory se non esiste:
```bash
mkdir -p ~/.config/fuzzel
```

---

## Parametri Principali

### [main] — Comportamento Generale

| Parametro | Default | Descrizione |
|-----------|---------|-------------|
| `terminal` | xterm | Emulatore di terminale (kitty, konsole, alacritty) |
| `font` | monospace | Font da usare (con Nerd Font per icone) |
| `width` | 40 | Larghezza finestra (% dello schermo) |
| `height` | 10 | Altezza finestra (numero righe) |
| `lines` | 10 | Righe visibili prima di scroll |
| `horizontal-pad` | 0 | Padding orizzontale (px) |
| `vertical-pad` | 0 | Padding verticale (px) |
| `inner-pad` | 4 | Spazio interno elementi |
| `outer-pad` | 4 | Spazio esterno finestra |
| `border-width` | 0 | Spessore bordo (px) |
| `corner-radius` | 0 | Arrotondamento angoli (px) |
| `match-mode` | prefix | Come matchare: `prefix`, `fuzzy`, `contains` |
| `sticky-distance` | 0 | Px prima che il cursore "attacchi" la finestra |

### [colors] — Palette Colori

Formato: `RRGGBBAA` (hex + alpha channel)

```ini
[colors]
background=282a36ff          # Sfondo principale
foreground=f8f8f2ff          # Testo predefinito
# Match highlight (lettere digitate)
selection-match-background=44475aff
selection-match-foreground=f1fa8cff
# Item selezionato
selection-background=bd93f9ff
selection-foreground=21222cff
# Bordo
border=bd93f9ff
```

**Hex Colors Reference:**
- `ff` = opaco
- `80` = semi-trasparente (50%)
- `00` = completamente trasparente

### [prompt] — Testo Input

```ini
[prompt]
text= 󰍉              # Icon + spazio
# Altre opzioni:
# text=» 
# text=λ 
# text=/
```

### [border] — Stile Bordo

```ini
[border]
width=2                      # Spessore (0 = no bordo)
# Color definito in [colors] → border=...
```

### [scrollbar] — Barra di Scroll

```ini
[scrollbar]
width=0                      # 0 = disabilita, >0 = mostra
```

### [cursor] — Cursore di Input

```ini
[cursor]
style=blink                  # blink, block, underline, none
color=f8f8f2ff              # Colore cursore
```

---

## Config Predefinite

### Opzione 1: Dracula + Large (lo consiglio per te)

```ini
[main]
terminal=kitty
font=JetBrainsMono Nerd Font:size=11
width=50
height=20
lines=10
inner-pad=8
outer-pad=12
border-width=2
corner-radius=12
match-mode=fuzzy

[colors]
background=282a36ff
foreground=f8f8f2ff
selection-match-background=44475aff
selection-match-foreground=f1fa8cff
selection-background=bd93f9ff
selection-foreground=21222cff
border=bd93f9ff

[prompt]
text= 

[border]
width=2

[cursor]
style=blink
color=f8f8f2ff
```

### Opzione 2: Nord + Minimalist

```ini
[main]
terminal=kitty
font=MonaspaceNeon Nerd Font:size=10
width=45
height=15
lines=8
inner-pad=6
outer-pad=8
border-width=1
corner-radius=6
match-mode=fuzzy

[colors]
background=2e3440ff
foreground=eceff4ff
selection-match-background=3b4252ff
selection-match-foreground=eceff4ff
selection-background=88c0d0ff
selection-foreground=2e3440ff
border=81a1c1ff

[prompt]
text=>

[border]
width=1

[cursor]
style=none
```

### Opzione 3: Gruvbox + Retro

```ini
[main]
terminal=kitty
font=Inconsolata Nerd Font:size=9
width=60
height=25
lines=12
inner-pad=10
outer-pad=15
border-width=3
corner-radius=0
match-mode=fuzzy

[colors]
background=282828ff
foreground=ebdbb2ff
selection-match-background=504945ff
selection-match-foreground=fabd2fff
selection-background=b8bb26ff
selection-foreground=282828ff
border=d79921ff

[prompt]
text=» 

[border]
width=3

[cursor]
style=block
color=fabd2fff
```

### Opzione 4: Catppuccin Mocha + Modern

```ini
[main]
terminal=kitty
font=FiraCode Nerd Font:size=11
width=55
height=18
lines=9
inner-pad=7
outer-pad=10
border-width=2
corner-radius=10
match-mode=fuzzy

[colors]
background=1e1e2eff
foreground=cdd6f4ff
selection-match-background=313244ff
selection-match-foreground=f38ba8ff
selection-background=f38ba8ff
selection-foreground=1e1e2eff
border=f38ba8ff

[prompt]
text= 

[border]
width=2

[cursor]
style=blink
color=cdd6f4ff
```

---

## Font Consigliati con Nerd Font Icons

| Font | Stile | Installazione |
|------|-------|--------------|
| JetBrainsMono Nerd Font | Moderno, monospaziato | `sudo apt install fonts-jetbrains-mono` |
| FiraCode Nerd Font | Elegante, with ligatures | `sudo apt install fonts-fira-code` |
| Inconsolata Nerd Font | Retro, small | `sudo apt install fonts-inconsolata` |
| MonaspaceNeon Nerd Font | Minimalist | `sudo apt install fonts-monospace-nerd` |
| Ubuntu Mono Nerd Font | Pulito | `sudo apt install fonts-ubuntu` |

**Per icone avanzate:**
```bash
sudo apt install fonts-ubuntu-nerd fonts-font-awesome
```

---

## Icon Prompt Recommendations

| Icon | Unicode | Uso |
|------|---------|-----|
| ` ` | U+F002 | Search generic (magnifying glass) |
| ` 󰍉` | U+F744 | Terminal |
| ` » ` | ASCII | Minimalist |
| ` λ ` | ASCII | Functional |
| ` / ` | ASCII | Simple |
| ` ▶ ` | ASCII | Play |
| ` ❯ ` | ASCII | Arrow |

---

## Keybindings (Default)

Fuzzel non ha file keybinding separato, usa i standard:

| Tasto | Azione |
|-------|--------|
| Enter | Esegui selected |
| Ctrl+Enter | Esegui in terminale |
| Esc | Annulla |
| Ctrl+C | Annulla |
| Ctrl+U | Cancella input |
| Ctrl+W | Cancella parola |
| Frecce ↑↓ | Navigazione |
| PgUp/PgDn | Scroll rapido |
| Mouse Scroll | Scroll risultati |
| Backspace | Cancella carattere |

---

## Integrazione con Niri

Nel tuo `config.kdl`:

```kdl
binds {
    Mod+R { spawn "fuzzel"; }
}
```

Per fuzzel con opzioni custom:
```kdl
Mod+R { spawn "fuzzel" "--lines=15" "--width=60"; }
```

---

## Tips & Tricks

### 1. Applicazioni da Terminale

Per app che richiedono terminale (ncurses, etc), usa:
```ini
[main]
terminal=kitty
# Fuzzel aprirà automaticamente in kitty se app richiede it
```

### 2. File Browser Alternativo

```ini
[main]
terminal=kitty
# Per inserire un file browser personalizzato
# (fuzzel non ha integrato, ma puoi creare script)
```

### 3. Tema Scuro su Laptop Brillante

Aumenta l'opacità dello sfondo:
```ini
[colors]
# background=282a36ff (opaco)
background=282a3655  # 33% trasparente → blur sottostante
```

### 4. Fuzzy vs Prefix Matching

```ini
[main]
# match-mode=prefix   # "f" → "firefox" (deve iniziare)
match-mode=fuzzy     # "fx" → "firefox" (qualsiasi posizione)
```

### 5. Velocità di Ricerca

```ini
[main]
search-timeout-ms=200  # Millisecondi prima di aggiornare
# Aumenta se il sistema è lento, riduci per responsività
```

---

## Setup Completo per Te (Mbarocc)

Basato sul tuo stile (Dracula, terminal-centric, minimalist):

```bash
mkdir -p ~/.config/fuzzel

cat > ~/.config/fuzzel/fuzzel.ini << 'EOF'
[main]
terminal=kitty
font=JetBrainsMono Nerd Font:size=11
width=50
height=20
lines=10
inner-pad=8
outer-pad=12
border-width=2
corner-radius=12
match-mode=fuzzy
search-timeout-ms=150

[colors]
background=282a36ff
foreground=f8f8f2ff
selection-match-background=44475aff
selection-match-foreground=f1fa8cff
selection-background=bd93f9ff
selection-foreground=21222cff
border=bd93f9ff

[prompt]
text= 

[border]
width=2

[cursor]
style=blink
color=f8f8f2ff
EOF

echo "Fuzzel config created at ~/.config/fuzzel/fuzzel.ini"
```

Poi nel `config.kdl`:
```kdl
binds {
    Mod+R { spawn "fuzzel"; }
    # Oppure con opzioni custom:
    # Mod+R { spawn "sh" "-c" "fuzzel --lines=15"; }
}
```

Test:
```bash
fuzzel &
```

---

## Troubleshooting

### Fuzzel non appare

```bash
# Verifica di essere su Wayland
echo $WAYLAND_DISPLAY  # Deve avere un valore

# Verifica config syntax
fuzzel --version
fuzzel  # Dovrebbe aprirsi

# Debug con verbose (se disponibile)
RUST_LOG=debug fuzzel
```

### Font errati o icone non cariche

```bash
# Installa Nerd Font
sudo apt install fonts-jetbrains-mono fonts-font-awesome

# Verifica font disponibili
fc-list | grep -i jetbrains
```

### Fuzzel lento

```ini
[main]
# Aumenta timeout se sistema è lento
search-timeout-ms=500
# Riduci numero linee
lines=5
```

---

## Risorse

- **Fuzzel GitHub**: https://codeberg.org/dnkl/fuzzel
- **Wayland Launcher List**: https://wiki.archlinux.org/title/Dmenu
- **Nerd Fonts**: https://www.nerdfonts.com/
