#!/bin/bash
# Calendario TUI interattivo (sola lettura) collegato a Google Calendar via iCal.
# Vista mese a griglia: oggi (blu), giorni con eventi (giallo), cursore (rosa).
# Frecce = muovi cursore | Tab/Shift+Tab = salta tra i giorni con eventi
# Invio = apri gli eventi del giorno in nvim | t = vai a oggi | q = esci
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="$HOME/.config/waybar/.calvenv/bin/python"
SYNC="$SCRIPT_DIR/cal-sync.py"
CACHE="$HOME/.cache/waybar-calendar/events.json"

# Locale italiano per i nomi di mesi/giorni, con fallback automatico.
for L in it_IT.UTF-8 it_IT.utf8 it_IT; do
    if locale -a 2>/dev/null | grep -qix "$L"; then export LC_TIME="$L"; break; fi
done

# --- Colori ----------------------------------------------------------------
RESET=$'\e[0m'; BOLD=$'\e[1m'; DIM=$'\e[2m'
C_TODAY=$'\e[48;5;75m\e[38;5;235m'     # sfondo blu
C_CURSOR=$'\e[48;5;212m\e[38;5;235m'   # sfondo rosa
C_EVENT=$'\e[38;5;221m'                # testo giallo
C_HEAD=$'\e[38;5;245m'

# --- Sincronizzazione ------------------------------------------------------
printf '\e[2J\e[H%sSincronizzazione con Google Calendar...%s\n' "$DIM" "$RESET"
if [ -x "$VENV_PY" ]; then
    "$VENV_PY" "$SYNC" 2>/tmp/cal-sync.err
fi
if [ ! -f "$CACHE" ]; then
    printf 'Nessuna cache disponibile. Configura ~/.config/waybar/calendar.conf\n'
    printf 'con il tuo indirizzo segreto iCal (vedi calendar.conf.example).\n'
    read -rsn1 _; exit 1
fi

# --- Indice eventi per giorno ---------------------------------------------
# count[YYYY-MM-DD] = numero eventi ; EVENT_DAYS = elenco ordinato dei giorni con eventi
declare -A COUNT
while IFS=$'\t' read -r day n; do
    [ -n "$day" ] && COUNT[$day]=$n
done < <(jq -r '.events | group_by(.start[0:10])[] | "\(.[0].start[0:10])\t\(length)"' "$CACHE")

mapfile -t EVENT_DAYS < <(printf '%s\n' "${!COUNT[@]}" | sort)

# --- Stato -----------------------------------------------------------------
TODAY=$(date +%F)
CUR=$TODAY                       # giorno selezionato (YYYY-MM-DD)
VIEW_Y=$(date +%Y); VIEW_M=$(date +%m)

sync_view_to_cur() { VIEW_Y=${CUR:0:4}; VIEW_M=${CUR:5:2}; }

# --- Rendering -------------------------------------------------------------
draw() {
    local buf="" first_dow days_in_month d cell day_str daycount
    local title status

    title=$(LC_TIME=${LC_TIME:-C} date -d "${VIEW_Y}-${VIEW_M}-01" "+%B %Y")
    first_dow=$(date -d "${VIEW_Y}-${VIEW_M}-01" +%u)
    days_in_month=$(date -d "${VIEW_Y}-${VIEW_M}-01 +1 month -1 day" +%d)
    days_in_month=$((10#$days_in_month))

    buf+=$'\e[2J\e[H'
    buf+=$(printf '   %s%s%s\n\n' "$BOLD" "$title" "$RESET")$'\n'
    buf+="${C_HEAD}Lu Ma Me Gi Ve Sa Do${RESET}"$'\n'

    local col=0 i
    for ((i = 1; i < first_dow; i++)); do buf+="   "; col=$((col+1)); done

    for ((d = 1; d <= days_in_month; d++)); do
        day_str=$(printf '%s-%s-%02d' "$VIEW_Y" "$VIEW_M" "$d")
        daycount=${COUNT[$day_str]:-0}
        cell=$(printf '%2d' "$d")
        if [ "$day_str" = "$CUR" ]; then
            cell="${C_CURSOR}${BOLD}${cell}${RESET}"
        elif [ "$day_str" = "$TODAY" ]; then
            cell="${C_TODAY}${BOLD}${cell}${RESET}"
        elif [ "$daycount" -gt 0 ]; then
            cell="${C_EVENT}${BOLD}${cell}${RESET}"
        fi
        buf+="$cell "
        col=$((col+1))
        if [ "$col" -ge 7 ]; then buf+=$'\n'; col=0; fi
    done
    [ "$col" -ne 0 ] && buf+=$'\n'

    buf+=$'\n'
    buf+="${C_TODAY}  ${RESET} oggi   ${C_EVENT}${BOLD}■${RESET} eventi   ${C_CURSOR}  ${RESET} cursore"$'\n\n'
    buf+="${DIM}Frecce: muovi   Tab/Shift+Tab: salta tra eventi${RESET}"$'\n'
    buf+="${DIM}Invio: apri in nvim   t: oggi   q: esci${RESET}"$'\n\n'

    daycount=${COUNT[$CUR]:-0}
    status=$(date -d "$CUR" "+%a %-d %b")
    if [ "$daycount" -gt 0 ]; then
        local plural="evento"; [ "$daycount" -gt 1 ] && plural="eventi"
        buf+="${BOLD}${status}: ${daycount} ${plural}${RESET} — Invio per vedere"$'\n'
    else
        buf+="${BOLD}${status}${RESET}: nessun evento"$'\n'
    fi

    printf '%s' "$buf"
}

# --- Apertura eventi del giorno in nvim -----------------------------------
open_day() {
    [ "${COUNT[$CUR]:-0}" -eq 0 ] && return
    local md heading
    md=$(mktemp --suffix=.md /tmp/cal-day-XXXXXX)
    heading=$(date -d "$CUR" "+%A %-d %B %Y")
    {
        printf '# Eventi di %s\n\n' "$heading"
        jq -r --arg d "$CUR" '
            .events
            | map(select(.start[0:10]==$d))
            | sort_by(.start)
            | .[]
            | "## \(.summary)\n"
              + (if .all_day then "**Orario:** Tutto il giorno\n"
                 else "**Orario:** \(.start[11:16]) - \(.end[11:16])\n" end)
              + (if .location != "" then "**Luogo:** \(.location)\n" else "" end)
              + (if .description != "" then "\n\(.description)\n" else "" end)
              + (if (.attendees | length) > 0 then
                    "\n**Partecipanti:**\n"
                    + (.attendees | map("- \(.email)" + (if .status != "" then " (\(.status))" else "" end)) | join("\n"))
                    + "\n"
                 else "" end)
              + "\n"
        ' "$CACHE"
    } > "$md"
    nvim -R "$md"        # -R: sola lettura (gli eventi non tornano su Google)
    rm -f "$md"
}

# --- Navigazione ----------------------------------------------------------
move_days() { CUR=$(date -d "$CUR $1 day" +%F); sync_view_to_cur; }

jump_event() {  # $1 = next|prev
    local d found=""
    if [ "$1" = "next" ]; then
        for d in "${EVENT_DAYS[@]}"; do [[ "$d" > "$CUR" ]] && { found=$d; break; }; done
    else
        for d in "${EVENT_DAYS[@]}"; do [[ "$d" < "$CUR" ]] && found=$d; done
    fi
    [ -n "$found" ] && { CUR=$found; sync_view_to_cur; }
}

# --- Loop principale -------------------------------------------------------
cleanup() { printf '\e[?25h\e[2J\e[H'; }
trap cleanup EXIT
printf '\e[?25l'

while true; do
    draw
    IFS= read -rsn1 key
    case "$key" in
        $'\t') jump_event next ;;
        q|Q) break ;;
        t|T) CUR=$TODAY; sync_view_to_cur ;;
        $'\e')
            read -rsn2 -t 0.01 rest
            case "$rest" in
                '[A') move_days -7 ;;   # su
                '[B') move_days +7 ;;   # giu
                '[C') move_days +1 ;;   # destra
                '[D') move_days -1 ;;   # sinistra
                '[Z') jump_event prev ;; # Shift+Tab
                '') break ;;            # ESC da solo = esci
            esac
            ;;
        '') open_day ;;                 # Invio
    esac
done
