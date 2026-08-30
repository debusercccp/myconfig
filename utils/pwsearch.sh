#!/usr/bin/env bash
#
# pwsearch.sh — cerca nel CSV delle password su servizio, username, password o fonte.
# Uso: ./pwsearch.sh <query> [--csv PATH] [--top N] [--all]
#
# Porting in bash+awk di pwsearch.py (compatibile con mawk, no dipendenza da gawk/FPAT)

set -euo pipefail

RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[91m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
CYAN=$'\033[96m'
WHITE=$'\033[97m'

usage() {
    cat <<EOF
Cerca nel vault delle password.

Uso: $0 <query> [--csv PATH] [--top N] [--all]

  query        Testo da cercare (servizio, username, password o fonte)
  --csv PATH   Percorso del CSV (ha la precedenza su \$PWSEARCH_CSV e sul default)
  --top N      Mostra i primi N risultati (default: 5)
  --all        Mostra tutti i risultati senza limite

Esempi:
  $0 spotify
  $0 gmail --top 3
EOF
    exit 1
}

# --- parsing argomenti -------------------------------------------------
QUERY=""
CSV_OVERRIDE=""
TOP=5
SHOW_ALL=0

while [ $# -gt 0 ]; do
    case "$1" in
        --csv)
            CSV_OVERRIDE="$2"; shift 2 ;;
        --top)
            TOP="$2"; shift 2 ;;
        --all)
            SHOW_ALL=1; shift ;;
        -h|--help)
            usage ;;
        -*)
            echo "Opzione sconosciuta: $1" >&2; usage ;;
        *)
            if [ -z "$QUERY" ]; then QUERY="$1"; else echo "Argomento in eccesso: $1" >&2; usage; fi
            shift ;;
    esac
done

[ -z "$QUERY" ] && usage

# --- risoluzione percorso CSV -------------------------------------------
resolve_csv_path() {
    if [ -n "$CSV_OVERRIDE" ]; then
        eval echo "$CSV_OVERRIDE"
        return
    fi
    if [ -n "${PWSEARCH_CSV:-}" ]; then
        eval echo "$PWSEARCH_CSV"
        return
    fi
    echo "$HOME/.local/share/pwsearch/passwords.csv"
}

CSV_PATH_RAW="$(resolve_csv_path)"

if [ ! -f "$CSV_PATH_RAW" ]; then
    echo "${RED}Errore: file non trovato → $CSV_PATH_RAW${RESET}"
    echo "${DIM}Imposta \$PWSEARCH_CSV per indicare il vault.${RESET}"
    exit 1
fi

CSV_PATH="$(cd "$(dirname "$CSV_PATH_RAW")" && pwd)/$(basename "$CSV_PATH_RAW")"

# --- controlli di sicurezza ----------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$CSV_PATH" in
    "$REPO_DIR"/*|"$REPO_DIR")
        echo "${RED}Rifiuto: il CSV è dentro il repository ($CSV_PATH).${RESET}"
        echo "${DIM}Spostalo fuori e indica il percorso con \$PWSEARCH_CSV.${RESET}"
        exit 1
        ;;
esac

PERM_OCTAL=$(stat -c '%a' "$CSV_PATH" 2>/dev/null || stat -f '%Lp' "$CSV_PATH")
PERM_DEC=$((8#$PERM_OCTAL))
if [ $((PERM_DEC & 8#077)) -ne 0 ]; then
    echo "${RED}Rifiuto: permessi troppo aperti su $CSV_PATH (0$PERM_OCTAL).${RESET}"
    echo "${DIM}Proteggilo con: chmod 600 $CSV_PATH${RESET}"
    exit 1
fi

# --- ricerca + stampa con awk --------------------------------------------
LIMIT=$TOP
[ "$SHOW_ALL" -eq 1 ] && LIMIT=-1

awk -v query="$QUERY" -v limit="$LIMIT" -v show_all="$SHOW_ALL" \
    -v RESET="$RESET" -v BOLD="$BOLD" -v DIM="$DIM" -v RED="$RED" \
    -v GREEN="$GREEN" -v YELLOW="$YELLOW" -v CYAN="$CYAN" -v WHITE="$WHITE" '
BEGIN {
    q_lower = tolower(query)
    fonte_color["Firefox"]  = "\033[38;5;208m"
    fonte_color["Google"]   = "\033[92m"
    fonte_color["WhatsApp"] = "\033[38;5;40m"
}

# split manuale di una riga CSV in campi, rispettando le virgolette;
# popola arr[1..n], ritorna il numero di campi. Non richiede FPAT (gawk-only).
function csv_split(line, arr,    n, i, c, field, in_quotes, len) {
    n = 0
    field = ""
    in_quotes = 0
    len = length(line)
    for (i = 1; i <= len; i++) {
        c = substr(line, i, 1)
        if (in_quotes) {
            if (c == "\"") {
                if (substr(line, i + 1, 1) == "\"") {
                    field = field "\""
                    i++
                } else {
                    in_quotes = 0
                }
            } else {
                field = field c
            }
        } else {
            if (c == "\"") {
                in_quotes = 1
            } else if (c == ",") {
                n++
                arr[n] = field
                field = ""
            } else {
                field = field c
            }
        }
    }
    n++
    arr[n] = field
    return n
}

# evidenzia (case-insensitive) tutte le occorrenze di query in text
function highlight(text,    result, lower_t, lower_q, i, pos, qlen) {
    if (query == "" || text == "") return text
    lower_t = tolower(text)
    lower_q = q_lower
    qlen = length(query)
    result = ""
    i = 1
    while (i <= length(text)) {
        pos = index(substr(lower_t, i), lower_q)
        if (pos == 0) {
            result = result substr(text, i)
            break
        }
        pos += i - 1
        result = result substr(text, i, pos - i)
        result = result BOLD RED substr(text, pos, qlen) RESET
        i = pos + qlen
    }
    return result
}

NR == 1 {
    nf = csv_split($0, hdr)
    for (i = 1; i <= nf; i++) col[hdr[i]] = i
    next
}

{
    nf = csv_split($0, f)
    servizio = f[col["servizio"]]
    username = f[col["username"]]
    password = f[col["password"]]
    fonte    = f[col["fonte"]]

    riga = servizio " " username " " password " " fonte
    if (index(tolower(riga), q_lower) > 0) {
        total++
        match_servizio[total] = servizio
        match_username[total] = username
        match_password[total] = password
        match_fonte[total]    = fonte
    }
}

END {
    n = (show_all == 1) ? total : ((limit < total) ? limit : total)

    suffix = (total == 1) ? "o" : "i"
    printf "\n%s%s  🔍 %s'\''%s'\''%s  —  %s%d%s risultat%s", BOLD, WHITE, RESET, query, RESET, GREEN, total, RESET, suffix
    if (show_all != 1 && total > limit) {
        printf "  %s(mostro i primi %d, usa --all per tutti)%s", DIM, limit, RESET
    }
    printf "\n"
    bar = ""
    for (i = 0; i < 52; i++) bar = bar "─"
    printf "  %s%s%s\n", DIM, bar, RESET

    if (total == 0) {
        printf "\n  %sNessuna corrispondenza trovata.%s\n\n", DIM, RESET
        exit
    }

    for (i = 1; i <= n; i++) {
        fonte = match_fonte[i]
        fc = (fonte in fonte_color) ? fonte_color[fonte] : WHITE
        s = highlight(match_servizio[i])
        u = highlight(match_username[i])
        p = highlight(match_password[i])
        f2 = highlight(fonte)

        printf "\n  %s%s#%02d%s  %s%s%s%s  %s[%s%s%s%s]%s\n", BOLD, WHITE, i, RESET, BOLD, CYAN, s, RESET, DIM, fc, f2, RESET, DIM, RESET
        printf "       %suser :%s  %s%s%s\n", DIM, RESET, WHITE, (u != "" ? u : "—"), RESET
        printf "       %spass :%s  %s%s%s\n", DIM, RESET, YELLOW, (p != "" ? p : "—"), RESET
    }
    printf "\n  %s%s%s\n\n", DIM, bar, RESET
}
' "$CSV_PATH"
