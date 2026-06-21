#!/bin/bash
# Script: ~/.config/waybar/scripts/calendar.sh
# Calendario per Waybar, scritto interamente in Bash (nessuna dipendenza da `cal`).
# Mostra la data nella barra; il tooltip disegna il mese corrente con oggi evidenziato.
# Click sinistro = mese successivo, click destro = mese precedente, click centrale = torna a oggi.

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-calendar-offset"

# Offset = numero di mesi di scostamento rispetto al mese corrente (0 = oggi).
read_offset() { [ -f "$STATE" ] && cat "$STATE" || echo 0; }
write_offset() { echo "$1" > "$STATE"; }

case "$1" in
    next)  write_offset "$(( $(read_offset) + 1 ))" ;;
    prev)  write_offset "$(( $(read_offset) - 1 ))" ;;
    reset) write_offset 0 ;;
esac

OFFSET=$(read_offset)

# Mese/anno da visualizzare nel tooltip (applicando l'offset).
VIEW_YM=$(date -d "$(date +%Y-%m-01) +${OFFSET} month" +%Y-%m)
VIEW_Y=${VIEW_YM%-*}
VIEW_M=${VIEW_YM#*-}

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

# Calendario completo per il tooltip (solo intestazione giorni + griglia).
CAL=$(printf '<b>%s</b>\n%s' "$HEADER" "$BODY")

# Testo mostrato nella barra: solo l'icona del calendario.
BAR_TEXT='󰃭'

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
