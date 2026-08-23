#!/usr/bin/env bash
# Toggle "caffeine": mette in pausa swayidle (SIGSTOP) per inibire lock/sospensione

status() {
    local pid
    pid=$(pgrep -x swayidle)
    if [[ -z "$pid" ]]; then
        echo '{"text": "󰾪", "class": "inactive", "tooltip": "swayidle non attivo"}'
        return
    fi
    local state
    state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null)
    if [[ "$state" == "T" ]]; then
        echo '{"text": "󰅶", "class": "active", "tooltip": "Caffeine attivo (swayidle in pausa)"}'
    else
        echo '{"text": "󰾪", "class": "inactive", "tooltip": "Caffeine spento"}'
    fi
}

toggle() {
    local pid
    pid=$(pgrep -x swayidle)
    [[ -z "$pid" ]] && { notify-send "Caffeine" "swayidle non trovato"; exit 1; }

    local state
    state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null)
    if [[ "$state" == "T" ]]; then
        kill -CONT "$pid"
        notify-send "Caffeine" "Spento — swayidle riattivato"
    else
        kill -STOP "$pid"
        notify-send "Caffeine" "Attivo — swayidle in pausa"
    fi
}

case "$1" in
    toggle) toggle ;;
    status|*) status ;;
esac
