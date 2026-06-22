#!/bin/bash
# Crea il virtualenv Python e installa le librerie iCal usate dal calendario.
# Da eseguire una volta (o dopo aver clonato i dotfiles su una nuova macchina).
set -euo pipefail

VENV="$HOME/.config/waybar/.calvenv"

echo "Creazione virtualenv in $VENV ..."
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --disable-pip-version-check --upgrade pip
"$VENV/bin/pip" install --quiet --disable-pip-version-check icalendar recurring-ical-events
echo "Fatto."

CONF="$HOME/.config/waybar/calendar.conf"
if [ ! -f "$CONF" ]; then
    cp "$HOME/.config/waybar/calendar.conf.example" "$CONF"
    echo
    echo "Creato $CONF: aprilo e inserisci il tuo indirizzo segreto iCal di Google Calendar."
fi
