#!/usr/bin/env bash
# ==============================================================================
# Confronta e sincronizza selettivamente tra ~/dotfiles/myconfig/ e ~/.config/
# Target specifici: matugen, nvim, waybar, dunst, fuzzel, kitty, conky, niri, swaylock
# ==============================================================================

set -euo pipefail

DOTFILES_DIR="${HOME}/dotfiles/myconfig"
CONFIG_DIR="${HOME}/.config"

# Colori ANSI per output leggibile
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Gli 8 target dell'ecosistema theming + Swaylock
TARGETS=(
    "matugen"
    "nvim"
    "waybar"
    "dunst"
    "fuzzel"
    "kitty"
    "conky"
    "niri"
    "swaylock"
)

# File temporanei, lockfile o file generati da non tracciare
EXCLUDES=(
    "*.git*"
    "*lazy-lock.json*"
    "*.swp"
    "*.swo"
    "*undo*"
    "*.socket"
)

SHOW_DIFF=false
INTERACTIVE=false

for arg in "$@"; do
    case "$arg" in
        -d|--diff) SHOW_DIFF=true ;;
        -i|--interactive) INTERACTIVE=true ;;
        -di|-id) SHOW_DIFF=true; INTERACTIVE=true ;;
        -h|--help)
            echo -e "${BOLD}Uso:${RESET} $0 [OPZIONI]"
            echo -e "  -d, --diff         Mostra il diff riga per riga per i file modificati"
            echo -e "  -i, --interactive  Sincronizza selettivamente ogni file con prompt"
            echo -e "  -di, -id           Mostra il diff e avvia la sincronizzazione interattiva"
            exit 0
            ;;
        *)
            echo -e "${RED}Argomento sconosciuto: $arg${RESET}" >&2
            exit 1
            ;;
    esac
done

DIFF_EXCLUDE_FLAGS=()
for pattern in "${EXCLUDES[@]}"; do
    DIFF_EXCLUDE_FLAGS+=( "-x" "$pattern" )
done

MODIFIED=()
ONLY_IN_DOTFILES=()
ONLY_IN_CONFIG=()

echo -e "${BOLD}${BLUE}==> Scansione componenti:${RESET} ${TARGETS[*]}\n"

for target in "${TARGETS[@]}"; do
    d_path="${DOTFILES_DIR}/${target}"
    c_path="${CONFIG_DIR}/${target}"

    # Caso 1: Presente in entrambi -> controllo ricorsivo differenze
    if [[ -d "$d_path" && -d "$c_path" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^Files\ (.*)\ and\ (.*)\ differ$ ]]; then
                f1="${BASH_REMATCH[1]}"
                rel="${f1#$DOTFILES_DIR/}"
                rel="${rel#$CONFIG_DIR/}"
                MODIFIED+=( "$rel" )
            elif [[ "$line" =~ ^Only\ in\ (.*):\ (.*)$ ]]; then
                dir="${BASH_REMATCH[1]}"
                entry="${BASH_REMATCH[2]}"
                full="${dir}/${entry}"

                if [[ "$dir" == "$DOTFILES_DIR"* ]]; then
                    rel="${full#$DOTFILES_DIR/}"
                    ONLY_IN_DOTFILES+=( "$rel" )
                else
                    rel="${full#$CONFIG_DIR/}"
                    ONLY_IN_CONFIG+=( "$rel" )
                fi
            fi
        done < <(diff -rq "${DIFF_EXCLUDE_FLAGS[@]}" "$d_path" "$c_path" 2>/dev/null || true)

    # Caso 2: Solo nei dotfiles
    elif [[ -e "$d_path" && ! -e "$c_path" ]]; then
        ONLY_IN_DOTFILES+=( "$target" )

    # Caso 3: Solo in .config
    elif [[ ! -e "$d_path" && -e "$c_path" ]]; then
        ONLY_IN_CONFIG+=( "$target" )
    fi
done

# ------------------------------------------------------------------------------
# Report Rilevamenti
# ------------------------------------------------------------------------------

echo -e "${BOLD}${YELLOW}=== File Modificati [${#MODIFIED[@]}] ===${RESET}"
if [ ${#MODIFIED[@]} -eq 0 ]; then
    echo -e "  ${GREEN}Nessuna discrepanza trovata.${RESET}"
else
    for f in "${MODIFIED[@]}"; do
        echo -e "  ${YELLOW}MOD:${RESET} $f"
        if [ "$SHOW_DIFF" = true ] && [ "$INTERACTIVE" = false ]; then
            echo -e "${MAGENTA}------------------------------------------------------------${RESET}"
            diff -u --color=always "$DOTFILES_DIR/$f" "$CONFIG_DIR/$f" || true
            echo -e "${MAGENTA}------------------------------------------------------------${RESET}\n"
        fi
    done
fi
echo ""

echo -e "${BOLD}${BLUE}=== Solo nei Dotfiles (Mancanti in ~/.config) [${#ONLY_IN_DOTFILES[@]}] ===${RESET}"
if [ ${#ONLY_IN_DOTFILES[@]} -eq 0 ]; then
    echo -e "  Nessuno."
else
    for f in "${ONLY_IN_DOTFILES[@]}"; do
        echo -e "  ${BLUE}+ DOTFILES:${RESET} $f"
    done
fi
echo ""

echo -e "${BOLD}${RED}=== Solo in ~/.config (Non tracciati nel repo) [${#ONLY_IN_CONFIG[@]}] ===${RESET}"
if [ ${#ONLY_IN_CONFIG[@]} -eq 0 ]; then
    echo -e "  Nessuno."
else
    for f in "${ONLY_IN_CONFIG[@]}"; do
        echo -e "  ${RED}+ LOCAL ONLY:${RESET} $f"
    done
fi
echo ""

if [ "$INTERACTIVE" = false ]; then
    if [ ${#MODIFIED[@]} -gt 0 ] || [ ${#ONLY_IN_DOTFILES[@]} -gt 0 ] || [ ${#ONLY_IN_CONFIG[@]} -gt 0 ]; then
        echo -e "${BOLD}Suggerimento:${RESET} usa ${GREEN}-i${RESET} per sincronizzare o ${GREEN}-d${RESET} per vedere il diff."
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# Sincronizzazione Interattiva
# ------------------------------------------------------------------------------

sync_file_modified() {
    local rel="$1"
    local dot_f="$DOTFILES_DIR/$rel"
    local cfg_f="$CONFIG_DIR/$rel"

    while true; do
        echo -e "\n${BOLD}${YELLOW}[MODIFICATO]${RESET} ${CYAN}$rel${RESET}"
        read -r -p "$(echo -e "${BOLD}Azione:${RESET} [c]opia su dotfiles, [d]otfiles su config, [v]iew diff, [s]kip, [q]uit: ")" act
        case "$act" in
            c|C)
                mkdir -p "$(dirname "$dot_f")"
                cp -a "$cfg_f" "$dot_f"
                echo -e "${GREEN}✓ Salvato nel repo dotfiles.${RESET}"
                break
                ;;
            d|D)
                mkdir -p "$(dirname "$cfg_f")"
                cp -a "$dot_f" "$cfg_f"
                echo -e "${GREEN}✓ Ripristinato in ~/.config.${RESET}"
                break
                ;;
            v|V)
                echo -e "${MAGENTA}------------------------------------------------------------${RESET}"
                diff -u --color=always "$dot_f" "$cfg_f" || true
                echo -e "${MAGENTA}------------------------------------------------------------${RESET}"
                ;;
            s|S|"")
                echo -e "${BLUE}Saltato.${RESET}"
                break
                ;;
            q|Q)
                echo -e "${RED}Uscita.${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Scelta non valida.${RESET}"
                ;;
        esac
    done
}

sync_only_dot() {
    local rel="$1"
    local dot_f="$DOTFILES_DIR/$rel"
    local cfg_f="$CONFIG_DIR/$rel"

    while true; do
        echo -e "\n${BOLD}${BLUE}[SOLO IN DOTFILES]${RESET} ${CYAN}$rel${RESET}"
        read -r -p "$(echo -e "${BOLD}Azione:${RESET} [i]nstalla in .config, [r]imuovi dal repo, [s]kip, [q]uit: ")" act
        case "$act" in
            i|I)
                mkdir -p "$(dirname "$cfg_f")"
                cp -a "$dot_f" "$cfg_f"
                echo -e "${GREEN}✓ Installato in ~/.config.${RESET}"
                break
                ;;
            r|R)
                rm -rf "$dot_f"
                echo -e "${RED}✓ Rimosso dai dotfiles.${RESET}"
                break
                ;;
            s|S|"")
                echo -e "${BLUE}Saltato.${RESET}"
                break
                ;;
            q|Q)
                echo -e "${RED}Uscita.${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Scelta non valida.${RESET}"
                ;;
        esac
    done
}

sync_only_cfg() {
    local rel="$1"
    local dot_f="$DOTFILES_DIR/$rel"
    local cfg_f="$CONFIG_DIR/$rel"

    while true; do
        echo -e "\n${BOLD}${RED}[SOLO IN .CONFIG]${RESET} ${CYAN}$rel${RESET}"
        read -r -p "$(echo -e "${BOLD}Azione:${RESET} [a]ggiungi al repo, [s]kip, [q]uit: ")" act
        case "$act" in
            a|A)
                mkdir -p "$(dirname "$dot_f")"
                cp -a "$cfg_f" "$dot_f"
                echo -e "${GREEN}✓ Aggiunto al repo dotfiles.${RESET}"
                break
                ;;
            s|S|"")
                echo -e "${BLUE}Saltato.${RESET}"
                break
                ;;
            q|Q)
                echo -e "${RED}Uscita.${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Scelta non valida.${RESET}"
                ;;
        esac
    done
}

echo -e "\n${BOLD}${MAGENTA}==> Sincronizzazione guidata${RESET}"

for f in "${MODIFIED[@]}"; do
    sync_file_modified "$f"
done

for f in "${ONLY_IN_DOTFILES[@]}"; do
    sync_only_dot "$f"
done

for f in "${ONLY_IN_CONFIG[@]}"; do
    sync_only_cfg "$f"
done

echo -e "\n${BOLD}${GREEN}==> Operazione terminata.${RESET}"
