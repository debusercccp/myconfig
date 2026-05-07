#!/usr/bin/env bash
# ================================================
# Matugen Master Script: Applica Tema & Testa
# ================================================

# Colori per l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════╗
║  Matugen Theme Manager & Validator           ║
║  Imposta Sfondo, Genera Colori e Testa Setup ║
╚══════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ================================================
# PRELIMINARI: Controllo Input
# ================================================
if [ -z "${1:-}" ]; then
    echo -e "${RED}✗ Errore: Nessun wallpaper specificato.${NC}"
    echo -e "${YELLOW}Uso: $0 /percorso/immagine.jpg${NC}"
    exit 1
fi

WALLPAPER="$1"

if [ ! -f "$WALLPAPER" ]; then
    echo -e "${RED}✗ Errore: Il file '$WALLPAPER' non esiste.${NC}"
    exit 1
fi

# ================================================
# FASE 1: APPLICAZIONE DEL TEMA
# ================================================
echo -e "${BLUE}[FASE 1]${NC} Applicazione Tema..."
echo "─────────────────────────────────────────"

echo -e " ${CYAN}➤${NC} Impostando lo sfondo: $(basename "$WALLPAPER")"
killall swaybg 2>/dev/null || true
swaybg -i "$WALLPAPER" -m fill &

echo -e " ${CYAN}➤${NC} Generazione colori con Matugen..."
# Eseguiamo matugen. Se richiede interazione, l'utente vedrà il prompt
matugen image "$WALLPAPER"

echo -e " ${CYAN}➤${NC} Ricaricando Niri..."
niri msg action load-config-file || echo -e "${YELLOW}  Attenzione: Errore nel ricaricare Niri${NC}"

echo -e " ${CYAN}➤${NC} Riavviando Waybar..."
killall waybar 2>/dev/null || true
sleep 0.5
waybar > /dev/null 2>&1 &

# Notifica e Kitty (opzionale)
command -v dunstify &> /dev/null && dunstify "Tema Aggiornato" "Sfondo: $(basename "$WALLPAPER")" -i "$WALLPAPER" || true
kitty @ set-background-opacity 0.85 2>/dev/null || true

echo -e "${GREEN}✓ Tema applicato!${NC}\n"

# ================================================
# FASE 2: TEST E VALIDAZIONE (EX test_matugen.sh)
# ================================================
echo -e "${BLUE}[FASE 2]${NC} Validazione Setup"
echo "─────────────────────────────────────────"

CONFIG_DIR="$HOME/.config"
WAYBAR_DIR="$CONFIG_DIR/waybar"
NIRI_DIR="$CONFIG_DIR/niri"
TEMPLATES_DIR="$CONFIG_DIR/matugen/templates"

# 1. Verifica file generati
echo -e "\n${CYAN}1. Controllo File Generati${NC}"
if [ -f "$WAYBAR_DIR/colors.css" ]; then
    lines=$(wc -l < "$WAYBAR_DIR/colors.css")
    echo -e "  ${GREEN}✓${NC} colors.css ($lines lines)"
else
    echo -e "  ${RED}✗${NC} colors.css non trovato!"
fi

if [ -f "$NIRI_DIR/colors.kdl" ]; then
    lines=$(wc -l < "$NIRI_DIR/colors.kdl")
    echo -e "  ${GREEN}✓${NC} colors.kdl ($lines lines)"
else
    echo -e "  ${RED}✗${NC} colors.kdl non trovato!"
fi

# 2. Analisi Variabili CSS
echo -e "\n${CYAN}2. Analisi Variabili Waybar (GTK)${NC}"
if [ -f "$WAYBAR_DIR/colors.css" ]; then
    VARS=$(grep -c "@define-color" "$WAYBAR_DIR/colors.css" || echo "0")
    if [ "$VARS" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Trovate $VARS variabili valide"
        echo -e "  ${YELLOW}Esempi estratti:${NC}"
        grep '@define-color' "$WAYBAR_DIR/colors.css" | head -4 | sed 's/^/    /'
    else
        echo -e "  ${RED}✗${NC} Nessuna variabile @define-color trovata in colors.css"
    fi
fi

# 3. Controllo Sintassi Waybar
echo -e "\n${CYAN}3. Controllo Import Waybar${NC}"
if [ -f "$WAYBAR_DIR/style.css" ]; then
    FIRST_LINE=$(head -1 "$WAYBAR_DIR/style.css")
    if [[ "$FIRST_LINE" == "@import"* ]]; then
        echo -e "  ${GREEN}✓${NC} @import è alla prima riga"
    else
        echo -e "  ${RED}✗${NC} @import NON è alla prima riga (Spostalo in cima!)"
    fi
fi

# 4. Controllo Niri
echo -e "\n${CYAN}4. Status Niri & Waybar${NC}"
if grep -q 'include "colors.kdl"' "$NIRI_DIR/config.kdl"; then
    echo -e "  ${GREEN}✓${NC} Niri include correttamente colors.kdl"
else
    echo -e "  ${RED}✗${NC} Niri NON include colors.kdl in config.kdl"
fi

if pgrep -x waybar > /dev/null; then
    echo -e "  ${GREEN}✓${NC} Processo Waybar è in esecuzione"
else
    echo -e "  ${RED}✗${NC} Waybar ha fallito l'avvio (controlla gli errori CSS)"
fi

echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Procedura completata! Goditi il nuovo tema. ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
