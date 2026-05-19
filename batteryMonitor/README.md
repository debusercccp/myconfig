# Configurazione Monitor Batteria

Sistema di monitoraggio automatico del livello batteria con notifiche critiche tramite systemd timer.

## File necessari

1. `monitor_battery.sh` - Script di verifica batteria
2. `battery-check.service` - Unit file systemd (servizio)
3. `battery-check.timer` - Unit file systemd (timer)

## Posizionamento file

### Script eseguibile
```
~/.local/bin/monitor_battery.sh
```

Assicurati che lo script sia eseguibile:
```bash
chmod +x ~/.local/bin/monitor_battery.sh
```

### File systemd per l'utente corrente
```
~/.config/systemd/user/battery-check.service
~/.config/systemd/user/battery-check.timer
```

Crea la directory se non esiste:
```bash
mkdir -p ~/.config/systemd/user/
```

## Installazione

1. Posiziona lo script:
```bash
cp monitor_battery.sh ~/.local/bin/
chmod +x ~/.local/bin/monitor_battery.sh
```

2. Posiziona i file systemd:
```bash
cp battery-check.service ~/.config/systemd/user/
cp battery-check.timer ~/.config/systemd/user/
```

3. Ricarica la configurazione systemd:
```bash
systemctl --user daemon-reload
```

4. Abilita e avvia il timer:
```bash
systemctl --user enable battery-check.timer
systemctl --user start battery-check.timer
```

## Verifica

Controlla lo stato del timer:
```bash
systemctl --user status battery-check.timer
```

Visualizza gli ultimi controlli eseguiti:
```bash
journalctl --user -u battery-check.service -n 20
```

## Configurazione

Modifica la soglia di avviso nel file `monitor_battery.sh`:
```bash
BATTERY_THRESHOLD=10  # Percentuale (default: 10%)
```

Cambia l'intervallo di controllo in `battery-check.timer`:
```
OnUnitActiveSec=1m  # Frequenza (default: ogni minuto)
```

## Dipendenze

- `notify-send` (per le notifiche)
- systemd (per i timer e i service)
- Accesso in lettura a `/sys/class/power_supply/BAT0`

## Note

- Il percorso della batteria `/sys/class/power_supply/BAT0` dipende dall'hardware. Verifica che sia corretto sul tuo sistema:
```bash
ls /sys/class/power_supply/
```
- Se la batteria ha un nome diverso (es. `BAT1`), aggiorna il percorso nel file `monitor_battery.sh`
