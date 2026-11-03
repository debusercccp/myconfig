# Snapper

Snapshot Btrfs per `/` (config `root`) e `/home` (config `home`).

| Cosa | Quando | Quanti ne tiene |
|---|---|---|
| `ogni-3-giorni` (root + home) | ogni 3 giorni, dal timer `snapper-3giorni.timer` | ultimi 10 (~1 mese) |
| pre/post `pacman` (snap-pac, solo root) | a ogni aggiornamento | fino a 50, minimo 14 giorni |

La timeline oraria di snapper è disattivata (`TIMELINE_CREATE=no`, `snapper-timeline.timer` disabilitato).

## File

- `configs/root`, `configs/home`: valori desiderati. Non si copiano in `/etc`, `install.sh` li applica con `snapper set-config`.
- `snapper-3giorni`: script installato in `/usr/local/bin`. Crea lo snapshot (algoritmo di pulizia `timeline`) solo se l'ultimo ha almeno 3 giorni.
- `snapper-3giorni.service` / `.timer`: controllo giornaliero con `Persistent=true`, così se il PC era spento parte al boot. Un `OnCalendar=*-*-1/3` ripartirebbe ogni inizio mese.
- La pulizia la fa `snapper-cleanup.timer`: con `TIMELINE_LIMIT_DAILY=10` e gli altri limiti a 0 restano gli ultimi 10.

## Installare / aggiornare

```bash
sudo bash arch/snapper/install.sh
```

Si può rilanciare dopo ogni modifica a questa cartella.

## Controllare

```bash
snapper -c root list | tail -5
systemctl list-timers snapper-3giorni.timer
journalctl -u snapper-3giorni.service -n 20
```

Comandi utili e rollback: vedi `../mantenance.md`.
