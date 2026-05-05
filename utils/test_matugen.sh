#!/usr/bin/env bash
# ================================================
# Matugen Test & Debug Script
# Valida la configurazione e genera report
# ================================================

set -euo pipefail

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Percorsi
CONFIG_DIR="$HOME/.config"
WAYBAR_DIR="$CONFIG_DIR/waybar"
NIRI_DIR="$CONFIG_DIR/niri"
TEMPLATES_DIR="$CONFIG_DIR/matugen/templates"

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════╗
║  Matugen Test & Debug                  ║
║  Validazione setup colori dinamici     ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# ================================================
# TEST 1: Verifica Matugen
# ================================================
echo -e "${BLUE}[TEST 1]${NC} Verifica Matugen installazione"
echo "─────────────────────────────────────────"

if command -v matugen &> /dev/null; then
    VERSION=$(matugen --version 2>&1 || echo "unknown")
    echo -e "${GREEN}✓${NC} Matugen trovato: $VERSION"
else
    echo -e "${RED}✗${NC} Matugen non trovato"
    echo "  Installa con: cargo install matugen"
    exit 1
fi

# ================================================
# TEST 2: Verifica file di configurazione
# ================================================
echo -e "\n${BLUE}[TEST 2]${NC} File di configurazione"
echo "─────────────────────────────────────────"

TESTS=(
    "$CONFIG_DIR/matugen.toml:matugen.toml"
    "$TEMPLATES_DIR/waybar-colors.hbs:Template Waybar"
    "$TEMPLATES_DIR/niri-colors.hbs:Template Niri"
    "$WAYBAR_DIR/style.css:Waybar style.css"
    "$NIRI_DIR/config.kdl:Niri config.kdl"
)

for test in "${TESTS[@]}"; do
    file="${test%:*}"
    name="${test#*:}"
    
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo -e "${GREEN}✓${NC} $name ($lines lines)"
    else
        echo -e "${RED}✗${NC} $name non trovato: $file"
    fi
done

# ================================================
# TEST 3: Verifica output di Matugen
# ================================================
echo -e "\n${BLUE}[TEST 3]${NC} Output Matugen"
echo "─────────────────────────────────────────"

if [ -f "$WAYBAR_DIR/colors.css" ]; then
    lines=$(wc -l < "$WAYBAR_DIR/colors.css")
    echo -e "${GREEN}✓${NC} colors.css ($lines lines)"
    echo -e "  ${CYAN}Variabili CSS rilevate:${NC}"
    grep -o "--[a-z-]*:" "$WAYBAR_DIR/colors.css" | sort | uniq | head -5
    echo "  ..."
else
    echo -e "${YELLOW}⚠${NC} colors.css non trovato (non ancora generato)"
fi

if [ -f "$NIRI_DIR/colors.kdl" ]; then
    lines=$(wc -l < "$NIRI_DIR/colors.kdl")
    echo -e "${GREEN}✓${NC} colors.kdl ($lines lines)"
    echo -e "  ${CYAN}Variabili KDL rilevate:${NC}"
    grep -o '\$[a-z-]*' "$NIRI_DIR/colors.kdl" | sort | uniq | head -5
    echo "  ..."
else
    echo -e "${YELLOW}⚠${NC} colors.kdl non trovato (non ancora generato)"
fi

# ================================================
# TEST 4: Verifica sintassi CSS
# ================================================
echo -e "\n${BLUE}[TEST 4]${NC} Sintassi CSS"
echo "─────────────────────────────────────────"

# Controlla @import
if [ -f "$WAYBAR_DIR/style.css" ]; then
    FIRST_LINE=$(head -1 "$WAYBAR_DIR/style.css")
    
    if [[ "$FIRST_LINE" == "@import"* ]]; then
        echo -e "${GREEN}✓${NC} @import è alla prima riga ✓"
    else
        echo -e "${RED}✗${NC} @import NON è alla prima riga"
        echo -e "  ${YELLOW}Prima riga: $FIRST_LINE${NC}"
        echo -e "  ${CYAN}Sposta @import prima di ogni altro CSS${NC}"
    fi
    
    # Controlla che colors.css sia referenziato
    if grep -q '@import.*colors\.css' "$WAYBAR_DIR/style.css"; then
        echo -e "${GREEN}✓${NC} style.css importa colors.css"
    else
        echo -e "${RED}✗${NC} style.css NON importa colors.css"
        echo -e "  ${CYAN}Aggiungi: @import \"colors.css\";${NC}"
    fi
fi

# ================================================
# TEST 5: Test di generazione colori
# ================================================
echo -e "\n${BLUE}[TEST 5]${NC} Test generazione colori"
echo "─────────────────────────────────────────"

# Cerca un wallpaper di test
WALLPAPER=""
for path in \
    "/usr/share/desktop-base/active-theme/wallpaper/contents/images/1920x1080.svg" \
    "/usr/share/backgrounds/default" \
    "$HOME/.wallpapers/default.jpg" \
    "$HOME/Pictures/wallpaper.jpg"
do
    if [ -f "$path" ]; then
        WALLPAPER="$path"
        break
    fi
done

if [ -z "$WALLPAPER" ]; then
    echo -e "${YELLOW}⚠${NC} Wallpaper di test non trovato"
    echo -e "  ${CYAN}Specifica il percorso: $0 /path/to/wallpaper.jpg${NC}"
else
    echo -e "${CYAN}Wallpaper: $(basename "$WALLPAPER")${NC}"
    
    # Genera i colori
    echo -e "${CYAN}Generando colori...${NC}"
    if matugen image "$WALLPAPER" 2>&1 | grep -q "Generated"; then
        echo -e "${GREEN}✓${NC} Generazione riuscita"
        
        # Verifica file generati
        if [ -f "$WAYBAR_DIR/colors.css" ] && [ -f "$NIRI_DIR/colors.kdl" ]; then
            echo -e "${GREEN}✓${NC} File generati correttamente"
        else
            echo -e "${YELLOW}⚠${NC} File non trovati dopo generazione"
        fi
    else
        echo -e "${RED}✗${NC} Errore nella generazione"
        matugen image "$WALLPAPER" 2>&1 | head -10
    fi
fi

# ================================================
# TEST 6: Verifica Waybar
# ================================================
echo -e "\n${BLUE}[TEST 6]${NC} Status Waybar"
echo "─────────────────────────────────────────"

if pgrep -x waybar > /dev/null; then
    echo -e "${GREEN}✓${NC} Waybar è in esecuzione"
    
    # Prova il reload
    echo -e "${CYAN}Testando reload...${NC}"
    if pkill -SIGUSR2 waybar 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Reload signal inviato"
        sleep 1
    fi
else
    echo -e "${YELLOW}⚠${NC} Waybar non è in esecuzione"
    echo -e "  ${CYAN}Avvia con: waybar &${NC}"
fi

# ================================================
# TEST 7: Verifica Niri
# ================================================
echo -e "\n${BLUE}[TEST 7]${NC} Status Niri"
echo "─────────────────────────────────────────"

if [ -f "$NIRI_DIR/colors.kdl" ]; then
    echo -e "${GREEN}✓${NC} colors.kdl è presente"
    
    # Verifica che sia incluso
    if grep -q 'include "colors.kdl"' "$NIRI_DIR/config.kdl"; then
        echo -e "${GREEN}✓${NC} colors.kdl è incluso in config.kdl"
    else
        echo -e "${RED}✗${NC} colors.kdl NON è incluso in config.kdl"
        echo -e "  ${CYAN}Aggiungi in config.kdl: include \"colors.kdl\"${NC}"
    fi
else
    echo -e "${YELLOW}⚠${NC} colors.kdl non trovato"
fi

# ================================================
# TEST 8: Analisi variabili CSS
# ================================================
echo -e "\n${BLUE}[TEST 8]${NC} Analisi variabili CSS"
echo "─────────────────────────────────────────"

if [ -f "$WAYBAR_DIR/colors.css" ]; then
    echo -e "${CYAN}Variabili trovate:${NC}"
    VARS=$(grep -o '\-\-[a-z\-]*:' "$WAYBAR_DIR/colors.css" | wc -l)
    echo -e "  Total: $VARS variabili"
    
    # Campionare alcune variabili
    echo -e "\n${CYAN}Esempi:${NC}"
    grep '^[[:space:]]*--' "$WAYBAR_DIR/colors.css" | head -8 | sed 's/^/  /'
    
    # Verifica valori hex
    echo -e "\n${CYAN}Valori hex trovati:${NC}"
    grep -o '#[0-9a-fA-F]\{6\}' "$WAYBAR_DIR/colors.css" | head -5 | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠${NC} colors.css non trovato"
fi

# ================================================
# REPORT DIAGNOSTICO
# ================================================
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}REPORT DIAGNOSTICO${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}\n"

# Crea un report file
REPORT="/tmp/matugen_debug_$(date +%s).txt"
{
    echo "Matugen Debug Report - $(date)"
    echo "========================================"
    echo ""
    echo "System:"
    uname -a
    echo ""
    echo "Directories:"
    echo "  Config: $CONFIG_DIR"
    echo "  Waybar: $WAYBAR_DIR"
    echo "  Niri: $NIRI_DIR"
    echo ""
    echo "Files:"
    ls -la "$WAYBAR_DIR/colors.css" 2>/dev/null || echo "  colors.css: NOT FOUND"
    ls -la "$NIRI_DIR/colors.kdl" 2>/dev/null || echo "  colors.kdl: NOT FOUND"
    echo ""
    echo "Recent logs:"
    journalctl --user -u matugen.service -n 20 2>/dev/null || echo "  (matugen.service not available)"
} > "$REPORT"

echo -e "${GREEN}✓${NC} Report salvato: $REPORT"
echo ""

# ================================================
# SUMMARY
# ================================================
echo -e "${CYAN}═════════════════════════════════════════${NC}"
echo -e "${CYAN}TEST COMPLETATI${NC}"
echo -e "${CYAN}═════════════════════════════════════════${NC}\n"

echo "Prossimi step:"
echo ""
echo -e "1. ${CYAN}Se i test sono passed:${NC}"
echo "   → Tutti i file sono configurati correttamente"
echo "   → Waybar dovrebbe mostrare i nuovi colori"
echo ""
echo -e "2. ${CYAN}Se ci sono errori:${NC}"
echo "   → Leggi il report: cat $REPORT"
echo "   → Segui le istruzioni per correggere"
echo ""
echo -e "3. ${CYAN}Per auto-update su cambio wallpaper:${NC}"
echo "   → matugen watch /path/to/wallpaper"
echo "   → O installa il systemd service"
echo ""
echo -e "${CYAN}═════════════════════════════════════════${NC}\n"
