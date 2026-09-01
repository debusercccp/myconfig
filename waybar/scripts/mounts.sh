#!/bin/bash
# Script: ~/.config/waybar/scripts/mounts.sh

# Icone Nerd Font per Hard Disk
ICON_HDD="󰋊"

notify() {
    notify-send -u "$1" -t 3000 "USB Tool" "$2"
}

get_removable_devices() {
    # Cerca dischi rimovibili o su bus USB
    lsblk -dno NAME,RM,TRAN | awk '$2=="1" || $3=="usb" {print "/dev/"$1}'
}

is_mounted() {
    # Controlla se una qualsiasi partizione del disco è montata
    if lsblk -rpo MOUNTPOINT "$1" | grep -q /; then echo "true"; else echo "false"; fi
}

toggle_device() {
    local dev=$(get_removable_devices | head -1)
    if [ -z "$dev" ]; then
        notify "critical" "Nessun disco USB trovato"
        exit 1
    fi

    sync

    if [ "$(is_mounted "$dev")" = "true" ]; then
        # Prende tutte le partizioni montate
        local partitions=$(lsblk -rpo NAME,TYPE,MOUNTPOINT "$dev" | awk '$2=="part" && $3!="" {print $1}')
        
        for part in $partitions; do
            # Se lo smontaggio fallisce (||), notifica ed esce dallo script
            udisksctl unmount -b "$part" &> /dev/null || { notify "critical" "Errore: Disco occupato!"; exit 1; }
        done
        
        # Se arriva qui, ha smontato tutto correttamente
        udisksctl power-off -b "$dev" &> /dev/null
        notify "normal" "Disco rimosso in sicurezza "
    else
        # Prova a montare la prima partizione trovata
        local part=$(lsblk -rpo NAME,TYPE "$dev" | awk '$2=="part" {print $1}' | head -1)
        if [ -n "$part" ]; then
            udisksctl mount -b "$part" &> /dev/null && notify "normal" "Disco montato con successo 󰋊"
        else
            notify "critical" "Errore: Nessuna partizione trovata"
        fi
    fi
}

waybar_output() {
    local dev=$(get_removable_devices | head -1)
    
    if [ -z "$dev" ]; then
        # Stato: Nessun disco inserito (Grigio nel CSS)
        echo "{\"text\": \"$ICON_HDD\", \"class\": \"empty\", \"tooltip\": \"Nessun dispositivo USB\"}"
    else
        if [ "$(is_mounted "$dev")" = "true" ]; then
            # Stato: Montato (Verde nel CSS)
            echo "{\"text\": \"$ICON_HDD USB\", \"class\": \"mounted\", \"tooltip\": \"Montato: $dev\"}"
        else
            # Stato: Inserito ma non montato (Arancione nel CSS)
            echo "{\"text\": \"$ICON_HDD USB\", \"class\": \"unmounted\", \"tooltip\": \"Rilevato: $dev\nClick per montare\"}"
        fi
    fi
}

case "$1" in
    waybar) waybar_output ;;
    toggle) toggle_device ;;
    *) echo "Usa waybar o toggle" ;;
esac
