#!/bin/bash
# Stato backup HDD per waybar: percentuale nel testo, barra di avanzamento nel tooltip
# Legge il progresso scritto da backup_hdd.sh (--info=progress2)

PROGRESS_FILE="/tmp/backup_hdd_progress"

if ! pgrep -x rsync > /dev/null; then
    echo '{"text": ""}'
    exit 0
fi

FASE=$(cat "$PROGRESS_FILE.fase" 2>/dev/null || echo "Backup in corso")
PCT=$(tr '\r' '\n' 2>/dev/null < "$PROGRESS_FILE" | grep -oE '[0-9]+%' | tail -1 | tr -d '%')

if [[ -z "$PCT" ]]; then
    printf '{"text": "󰁯 BACKUP", "tooltip": "%s…"}\n' "$FASE"
    exit 0
fi

BARRA=""
for ((i = 0; i < 20; i++)); do
    if (( i < PCT / 5 )); then BARRA+="█"; else BARRA+="░"; fi
done

printf '{"text": "󰁯 %s%%", "tooltip": "%s\\n%s %s%%"}\n' "$PCT" "$FASE" "$BARRA" "$PCT"
