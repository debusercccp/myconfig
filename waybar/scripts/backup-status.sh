#!/bin/bash
# Stato backup HDD per waybar: percentuale nel testo, barra di avanzamento nel tooltip
# Legge il progresso scritto da backup_hdd.sh (--info=progress2); il file .fase
# copre anche il sync finale, quando rsync non è più in esecuzione.

PROGRESS_FILE="/tmp/backup_hdd_progress"
FASE_FILE="$PROGRESS_FILE.fase"

if [[ -e "$FASE_FILE" ]]; then
    FASE=$(cat "$FASE_FILE" 2>/dev/null)
elif pgrep -x rsync > /dev/null; then
    FASE="Backup in corso"
else
    echo '{"text": ""}'
    exit 0
fi

PCT=$(tr '\r' '\n' 2>/dev/null < "$PROGRESS_FILE" | grep -oE '[0-9]+%' | tail -1 | tr -d '%')

if [[ -z "$PCT" ]]; then
    case "$FASE" in
        Sincronizzazione*)
            printf '{"text": "󰁯 SYNC", "tooltip": "%s — NON staccare il disco"}\n' "$FASE" ;;
        *)
            printf '{"text": "󰁯 BACKUP", "tooltip": "%s…"}\n' "$FASE" ;;
    esac
    exit 0
fi

BARRA=""
for ((i = 0; i < 20; i++)); do
    if (( i < PCT / 5 )); then BARRA+="█"; else BARRA+="░"; fi
done

printf '{"text": "󰁯 %s%%", "tooltip": "%s\\n%s %s%%"}\n' "$PCT" "$FASE" "$BARRA" "$PCT"
