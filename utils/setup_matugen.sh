#!/usr/bin/env bash
# ================================================
# Matugen Integration Script
# Setup dinamico colori Waybar + Niri dal wallpaper
# ================================================

set -euo pipefail

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Percorsi
CONFIG_DIR="$HOME/.config"
WAYBAR_DIR="$CONFIG_DIR/waybar"
NIRI_DIR="$CONFIG_DIR/niri"
TEMPLATES_DIR="$CONFIG_DIR/matugen/templates"

echo -e "${BLUE}=== Matugen Integration Setup ===${NC}\n"

# ================================================
# STEP 1: Verifica installazione Matugen
# ================================================
if ! command -v matugen &> /dev/null; then
    echo -e "${YELLOW}⚠️  Matugen non trovato!${NC}"
    echo "Installa con: cargo install matugen"
    echo "O scarica da: https://github.com/InioX/matugen"
    exit 1
fi
echo -e "${GREEN}✓${NC} Matugen trovato: $(matugen --version)"

# ================================================
# STEP 2: Crea struttura directory
# ================================================
echo -e "\n${BLUE}→${NC} Creando struttura directory..."
mkdir -p "$TEMPLATES_DIR"
mkdir -p "$WAYBAR_DIR"
mkdir -p "$NIRI_DIR"
echo -e "${GREEN}✓${NC} Directory create"

# ================================================
# STEP 3: Copia template Matugen
# ================================================
echo -e "\n${BLUE}→${NC} Copiando template Matugen..."

cat > "$TEMPLATES_DIR/waybar-colors.hbs" << 'EOF'
/* ================================================
   Waybar Dynamic Colors - Generato da Matugen
   Paletta completa sincronizzata col wallpaper
   ================================================ */

:root {
    /* Colori primari dal wallpaper */
    --bg: {{colors.primary.default.hex}};
    --fg: {{colors.primary.on_default.hex}};
    --accent: {{colors.secondary.default.hex}};
    --accent-fg: {{colors.secondary.on_default.hex}};
    --tertiary: {{colors.tertiary.default.hex}};
    --tertiary-fg: {{colors.tertiary.on_default.hex}};
    
    /* Colori per stati */
    --success: {{colors.primary.default.hex}};
    --warning: {{colors.tertiary.default.hex}};
    --critical: {{colors.error.default.hex}};
    --critical-fg: {{colors.error.on_default.hex}};
    
    /* Colori neutri */
    --bg-secondary: {{colors.secondary.default.hex}};
    --bg-tertiary: {{colors.tertiary.default.hex}};
    
    /* Trasparenze */
    --bg-transparent: rgba({{colors.primary.default.rgb}}, 0.85);
    --bg-semi: rgba({{colors.primary.default.rgb}}, 0.6);
    --bg-light: rgba({{colors.primary.default.rgb}}, 0.3);
    
    /* Colori specifici moduli */
    --color-launcher: {{colors.secondary.default.hex}};
    --color-workspaces: {{colors.tertiary.default.hex}};
    --color-workspaces-active: {{colors.primary.default.hex}};
    --color-clock: {{colors.secondary.default.hex}};
    --color-network: {{colors.secondary.default.hex}};
    --color-network-disconnected: {{colors.error.default.hex}};
    --color-battery: {{colors.primary.default.hex}};
    --color-battery-warning: {{colors.tertiary.default.hex}};
    --color-battery-critical: {{colors.error.default.hex}};
    --color-audio: {{colors.tertiary.default.hex}};
    --color-cpu: {{colors.primary.default.hex}};
    --color-memory: {{colors.secondary.default.hex}};
    --color-disk: {{colors.tertiary.default.hex}};
    --color-temperature: {{colors.tertiary.default.hex}};
    --color-bluetooth: {{colors.secondary.default.hex}};
    --color-bluetooth-connected: {{colors.primary.default.hex}};
    --color-updates: {{colors.secondary.default.hex}};
    --color-power: {{colors.error.default.hex}};
    
    /* Sfondo container barra */
    --bar-bg: var(--bg-transparent);
    --bar-border: var(--accent);
}
EOF

cat > "$TEMPLATES_DIR/niri-colors.hbs" << 'EOF'
/* ================================================
   Niri Dynamic Colors - Generato da Matugen
   Focus-ring e border coordinati col wallpaper
   ================================================ */

let $primary = "{{colors.primary.default.hex}}";
let $primary-fg = "{{colors.primary.on_default.hex}}";
let $accent = "{{colors.secondary.default.hex}}";
let $accent-fg = "{{colors.secondary.on_default.hex}}";
let $tertiary = "{{colors.tertiary.default.hex}}";
let $error = "{{colors.error.default.hex}}";
let $bg-container = "{{colors.surface.default.hex}}";

prefer-no-csd

default-seat "seat0" {
    focus-ring {
        width 4
        active-color $accent
        inactive-color $primary
        active-gradient-from $accent
        active-gradient-to $primary
        active-gradient-angle 45
    }
    
    border {
        width 2
        active-color $accent
        inactive-color $primary
    }
}

window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
    focus-ring {
        width 4
        active-color $accent
        inactive-color $tertiary
    }
}

window-rule {
    match app-id="waybar"
    draw-border-with-background false
}

window-rule {
    match is-active=false
    opacity 0.9
}
EOF

echo -e "${GREEN}✓${NC} Template copiati"

# ================================================
# STEP 4: Crea matugen.toml
# ================================================
echo -e "\n${BLUE}→${NC} Creando matugen.toml..."

cat > "$CONFIG_DIR/matugen.toml" << 'EOF'
[config]
color_system = "okhsl"
saturation = 0.8
lightness = 0.55

[[templates]]
name = "waybar_colors"
input = "templates/waybar-colors.hbs"
output = "waybar/colors.css"

[[templates]]
name = "niri_colors"
input = "templates/niri-colors.hbs"
output = "niri/colors.kdl"

[image_analysis]
use_dominant_colors = true
color_count = 8
EOF

echo -e "${GREEN}✓${NC} matugen.toml creato"

# ================================================
# STEP 5: Genera colori iniziali
# ================================================
echo -e "\n${BLUE}→${NC} Generando colori iniziali dal wallpaper..."

WALLPAPER="${WALLPAPER:-/usr/share/desktop-base/active-theme/wallpaper/contents/images/1920x1080.svg}"

if [ ! -f "$WALLPAPER" ]; then
    WALLPAPER=$(find "$HOME/.wallpapers" -type f -name "*.jpg" -o -name "*.png" | head -1)
    if [ -z "$WALLPAPER" ]; then
        echo -e "${YELLOW}⚠️  Wallpaper non trovato. Usando sfondo default...${NC}"
        WALLPAPER="/usr/share/backgrounds/default"
    fi
fi

if matugen image "$WALLPAPER" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Colori generati da: $(basename "$WALLPAPER")"
else
    echo -e "${RED}✗${NC} Errore nella generazione dei colori"
    echo "Verifica che il file wallpaper esista: $WALLPAPER"
fi

# ================================================
# STEP 6: Verifica i file generati
# ================================================
echo -e "\n${BLUE}→${NC} Verificando file generati..."

if [ -f "$WAYBAR_DIR/colors.css" ]; then
    echo -e "${GREEN}✓${NC} Waybar colors.css creato"
    echo "   $(wc -l < "$WAYBAR_DIR/colors.css") righe"
else
    echo -e "${RED}✗${NC} Waybar colors.css non trovato"
fi

if [ -f "$NIRI_DIR/colors.kdl" ]; then
    echo -e "${GREEN}✓${NC} Niri colors.kdl creato"
    echo "   $(wc -l < "$NIRI_DIR/colors.kdl") righe"
else
    echo -e "${RED}✗${NC} Niri colors.kdl non trovato"
fi

# ================================================
# STEP 7: Verifica sintassi CSS e KDL
# ================================================
echo -e "\n${BLUE}→${NC} Verificando sintassi..."

if command -v stylelint &> /dev/null; then
    stylelint "$WAYBAR_DIR/colors.css" 2>/dev/null && echo -e "${GREEN}✓${NC} CSS sintassi valida" || echo -e "${YELLOW}⚠️  CSS warnings${NC}"
else
    echo -e "${YELLOW}⚠️  stylelint non installato, saltando validazione CSS${NC}"
fi

# ================================================
# STEP 8: Reload Waybar
# ================================================
echo -e "\n${BLUE}→${NC} Ricaricando Waybar..."

if pgrep -x waybar > /dev/null; then
    pkill -SIGUSR2 waybar
    sleep 1
    echo -e "${GREEN}✓${NC} Waybar ricaricato"
else
    echo -e "${YELLOW}⚠️  Waybar non è in esecuzione${NC}"
    echo "   Avvia con: waybar"
fi

# ================================================
# STEP 9: Reload Niri (se possibile)
# ================================================
if command -v niri &> /dev/null; then
    if pgrep -x niri > /dev/null; then
        # Niri leggerà automaticamente il file colors.kdl all'avvio
        echo -e "${YELLOW}⚠️  Niri richiede restart manuale per i nuovi colori${NC}"
        echo "   Ricarica con: niri msg action restart-niri"
    fi
fi

# ================================================
# SUMMARY
# ================================================
echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ✓ Setup completato!                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

echo "File generati:"
echo -e "  ${GREEN}~/.config/waybar/colors.css${NC}"
echo -e "  ${GREEN}~/.config/niri/colors.kdl${NC}"
echo -e "  ${GREEN}~/.config/matugen.toml${NC}\n"

echo "Prossimi step:"
echo -e "  1. ${BLUE}Verifica:${NC}"
echo -e "     cat $WAYBAR_DIR/colors.css"
echo -e "     cat $NIRI_DIR/colors.kdl\n"

echo -e "  2. ${BLUE}Per auto-update al cambio wallpaper:${NC}"
echo -e "     matugen watch /percorso/wallpaper\n"

echo -e "  3. ${BLUE}Systemd service (opzionale):${NC}"
echo "     See setup_matugen_service.sh"

# ================================================
# FINE SCRIPT
# ================================================
