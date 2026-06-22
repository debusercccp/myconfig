#!/bin/bash
# Script: ~/.config/waybar/scripts/calendar.sh
# Calendario per Waybar, scritto interamente in Bash (nessuna dipendenza da `cal`).
# Il tooltip disegna il mese con oggi (blu) e i giorni con eventi (giallo) evidenziati.
# Scroll su/giu = mese precedente/successivo, click = apre il TUI interattivo.
# Gli eventi arrivano da Google Calendar via iCal (vedi cal-sync.py / cal-tui.sh).

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-calendar-offset"
TIMER="${XDG_RUNTIME_DIR:-/tmp}/waybar-calendar-timer"

# Secondi di inattività dopo i quali il calendario torna da solo a oggi
# (waybar non ha un evento "mouse uscito", quindi usiamo un timeout).
IDLE_RESET=3

# Offset = numero di mesi di scostamento rispetto al mese corrente (0 = oggi).
read_offset() { [ -f "$STATE" ] && cat "$STATE" || echo 0; }
write_offset() { echo "$1" > "$STATE"; }

# Annulla l'eventuale timer di reset in corso.
cancel_timer() { [ -f "$TIMER" ] && kill "$(cat "$TIMER")" 2>/dev/null; rm -f "$TIMER"; }

# (Ri)avvia il timer: dopo IDLE_RESET secondi senza ulteriori click torna a oggi.
# Ogni click annulla il timer precedente, ottenendo un effetto "debounce".
arm_timer() {
    cancel_timer
    ( sleep "$IDLE_RESET"; echo 0 > "$STATE"; rm -f "$TIMER"; pkill -RTMIN+9 waybar ) &
    echo $! > "$TIMER"
}

# I click aggiornano solo lo stato ed escono: il JSON lo stampa solo "status".
case "$1" in
    next)  write_offset "$(( $(read_offset) + 1 ))"; arm_timer; exit 0 ;;
    prev)  write_offset "$(( $(read_offset) - 1 ))"; arm_timer; exit 0 ;;
    reset) write_offset 0; cancel_timer; exit 0 ;;
esac

OFFSET=$(read_offset)

# Mese/anno da visualizzare nel tooltip (applicando l'offset).
VIEW_YM=$(date -d "$(date +%Y-%m-01) +${OFFSET} month" +%Y-%m)
VIEW_Y=${VIEW_YM%-*}
VIEW_M=${VIEW_YM#*-}

# --- Eventi (cache prodotta da cal-sync.py) -------------------------------
CACHE="$HOME/.cache/waybar-calendar/events.json"
SYNC="$(dirname "$(readlink -f "$0")")/cal-sync.py"
VENV_PY="$HOME/.config/waybar/.calvenv/bin/python"

# Sincronizza in background se la cache manca o ha piu' di 10 minuti.
if [ -x "$VENV_PY" ] && [ -f "$SYNC" ]; then
    cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
    if [ ! -f "$CACHE" ] || [ "$cache_age" -gt 600 ]; then
        ( "$VENV_PY" "$SYNC" >/dev/null 2>&1; pkill -RTMIN+9 waybar ) &
    fi
fi

# Giorni del mese visualizzato che hanno almeno un evento.
declare -A HASEV
if [ -f "$CACHE" ] && command -v jq >/dev/null; then
    while read -r evd; do [ -n "$evd" ] && HASEV[$evd]=1; done < <(
        jq -r --arg ym "$VIEW_YM" \
            '.events[].start | select(startswith($ym)) | (.[8:10]|tonumber)' \
            "$CACHE" 2>/dev/null)
fi

# Primo giorno della settimana del mese (1=lun .. 7=dom) e numero di giorni.
first_dow=$(date -d "${VIEW_Y}-${VIEW_M}-01" +%u)
days_in_month=$(date -d "${VIEW_Y}-${VIEW_M}-01 +1 month -1 day" +%d)
days_in_month=$((10#$days_in_month))

# Giorno di oggi, evidenziato solo se stiamo guardando il mese reale.
TODAY=""
[ "$OFFSET" -eq 0 ] && TODAY=$((10#$(date +%d)))

# Intestazione: settimana che inizia di lunedì.
HEADER="Lu Ma Me Gi Ve Sa Do"

# Costruzione della griglia, una settimana per riga.
BODY=""
week=""
# Spazi vuoti prima del primo giorno.
for ((i = 1; i < first_dow; i++)); do
    week+="   "
done
col=$((first_dow - 1))

for ((d = 1; d <= days_in_month; d++)); do
    if [ "$d" = "$TODAY" ]; then
        # Oggi evidenziato con riquadro colorato (markup Pango, tooltip Waybar).
        cell=$(printf "<span background='#89b4fa' foreground='#1e1e2e'><b>%2d</b></span>" "$d")
    elif [ -n "${HASEV[$d]:-}" ]; then
        # Giorno con eventi: testo giallo.
        cell=$(printf "<span foreground='#f9e2af'><b>%2d</b></span>" "$d")
    else
        cell=$(printf '%2d' "$d")
    fi
    week+="$cell "
    col=$((col + 1))
    if [ "$col" -ge 7 ]; then
        BODY+="${week% }"$'\n'
        week=""
        col=0
    fi
done
[ -n "$week" ] && BODY+="${week% }"

# Calendario completo per il tooltip (intestazione + griglia + suggerimenti).
CAL=$(printf '<b>%s</b>\n%s\n\n<i>Click: apri  ·  Scroll: cambia mese</i>' "$HEADER" "$BODY")

# Conteggio eventi di oggi per la barra.
TODAY_FULL=$(date +%F)
TODAY_COUNT=0
if [ -f "$CACHE" ] && command -v jq >/dev/null; then
    TODAY_COUNT=$(jq -r --arg d "$TODAY_FULL" \
        '[.events[]|select(.start[0:10]==$d)]|length' "$CACHE" 2>/dev/null)
fi

# Testo nella barra: icona, con il numero di eventi di oggi se presenti.
BAR_TEXT='󰃭'
[ "${TODAY_COUNT:-0}" -gt 0 ] && BAR_TEXT="󰃭 ${TODAY_COUNT}"

# Escape per JSON (newline -> \n, doppi apici -> \").
json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

printf '{"text": "%s", "tooltip": "%s", "class": "calendar"}\n' \
    "$(json_escape "$BAR_TEXT")" "$(json_escape "$CAL")"
