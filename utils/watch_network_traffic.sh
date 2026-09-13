#!/bin/bash
# watch_network_traffic.sh - TUI Network Monitor in Bash

set -euo pipefail

# Entra nel buffer alternativo, nasconde il cursore
printf "\033[?1049h\033[?25l"

cleanup() {
    # Ripristina cursore, buffer primario ed esce pulito
    printf "\033[?25h\033[?1049l"
    exit 0
}
trap cleanup INT TERM EXIT

INTERVAL=1
declare -A PREV_RX PREV_TX

# Prende dimensioni terminale
LINES=$(tput lines)
COLS=$(tput cols)

while true; do
    # 1. Posiziona cursore in cima e pulisce
    printf "\033[H\033[J"

    # Header
    printf "\033[7m %-$((${COLS} - 2))s \033[0m\n" "NETWORK TRAFFIC MONITOR  [$(date +'%T')]  ('q' per uscire)"
    echo ""

    # Sezione 1: Statistiche Connessioni
    tcp_est=$(ss -Htan state established 2>/dev/null | wc -l)
    tcp_listen=$(ss -Htan state listening 2>/dev/null | wc -l)
    udp_open=$(ss -Huan 2>/dev/null | wc -l)

    printf "\033[1m%-24s\033[0m TCP Established: \033[32m%d\033[0m  |  TCP Listen: \033[34m%d\033[0m  |  UDP: \033[33m%d\033[0m\n" \
        "--- CONNESSIONI ---" "$tcp_est" "$tcp_listen" "$udp_open"
    echo ""

    # Sezione 2: Throughput Interfacce
    printf "\033[1m%-24s\033[0m\n" "--- THROUGHPUT INTERFACCE (KB/s) ---"
    printf "  \033[4m%-12s %14s %14s\033[0m\n" "IFACE" "RX (KB/s)" "TX (KB/s)"

    if [ -r /proc/net/dev ]; then
        while read -r iface rx_bytes _ _ _ _ _ _ tx_bytes _; do
            iface="${iface%:}"
            # Salta loopback se vuoi una vista più pulita (opzionale)
            # [[ "$iface" == "lo" ]] && continue

            if [[ -n "${PREV_RX[$iface]:-}" ]]; then
                rx_rate=$(awk -v cur="$rx_bytes" -v prev="${PREV_RX[$iface]}" -v dt="$INTERVAL" \
                    'BEGIN { printf "%10.2f", (cur - prev) / dt / 1024 }')
                tx_rate=$(awk -v cur="$tx_bytes" -v prev="${PREV_TX[$iface]}" -v dt="$INTERVAL" \
                    'BEGIN { printf "%10.2f", (cur - prev) / dt / 1024 }')
                printf "  %-12s \033[36m%s\033[0m \033[35m%s\033[0m\n" "$iface" "$rx_rate" "$tx_rate"
            else
                printf "  %-12s %14s %14s\n" "$iface" "campionamento..." "campionamento..."
            fi

            PREV_RX["$iface"]="$rx_bytes"
            PREV_TX["$iface"]="$tx_bytes"
        done < <(awk 'NR > 2 {print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}' /proc/net/dev)
    fi
    echo ""

    # Sezione 3: Top Socket in Ascolto (max 8 righe)
    printf "\033[1m%-24s\033[0m\n" "--- SOCKET IN ASCOLTO (TOP 8) ---"
    printf "  \033[4m%-6s %-22s %-20s\033[0m\n" "PROTO" "LOCAL ADDR:PORT" "PROCESS/INFO"
    
    ss -tulnp 2>/dev/null | awk 'NR>1 {
        proto=$1; local=$5; proc=$7;
        sub(/.*users:\(\("/, "", proc); sub(/".*/, "", proc);
        if (proc == "") proc = "-";
        printf "  %-6s %-22s %-20s\n", proto, local, proc
    }' | head -n 8

    # Input non bloccante: esce con 'q' o 'Q'
    read -rsn1 -t "$INTERVAL" key || true
    if [[ "${key:-}" == "q" || "${key:-}" == "Q" ]]; then
        break
    fi
done
