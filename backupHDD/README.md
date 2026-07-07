# Pipeline Backup HDD

Backup automatico della home su HDD/USB esterno, attivato dall'inserimento del
disco. Il flusso è: **inserisci il disco → udev intercetta l'UUID → systemd avvia
`backup-hdd@<UUID>.service` → `backup_hdd.sh` esegue rsync → notifica "puoi
staccare"**. Lo stato è visibile in tempo reale in Waybar con una barra di
avanzamento.

---

## Dischi supportati

I dischi sono riconosciuti tramite UUID stabile (le prime cifre determinano il nome
mostrato nelle notifiche). Per aggiungerne uno vedi [Aggiungere un disco](#aggiungere-un-disco).

| Disco | Capacità  | UUID                                   |
| ----- | --------- | -------------------------------------- |
| A     | 2 TB      | `84763b78-b0dc-4593-ba3b-cebc88d54dda` |
| B     | 500 GB    | `65505cfd-073a-4f4c-8f8f-cbbec134f2aa` |
| C     | WD 500 GB | `d8c9f8b2-d093-4751-a5c9-469c49361fb4` |

Qualsiasi altro disco viene trattato come "Dispositivo volatile" (backup comunque
eseguito, con nome generico nelle notifiche).

---

## Componenti e percorsi

| File nel repo                             | Destinazione sul sistema                    | Ruolo                                    |
| ----------------------------------------- | ------------------------------------------- | ---------------------------------------- |
| `backup_hdd.sh`                           | `/usr/local/bin/backup_hdd.sh`              | Script principale della pipeline         |
| `backup-hdd@.service`                     | `/etc/systemd/system/backup-hdd@.service`   | Template systemd (oneshot, ionice, noya) |
| `99-backup-hdd.rules`                     | `/etc/udev/rules.d/99-backup-hdd.rules`     | Trigger udev per-UUID + regola JMicron   |
| `../waybar-niri/scripts/backup-status.sh` | `~/.config/waybar/scripts/backup-status.sh` | Stato/barra di avanzamento per Waybar    |
| `../waybar-niri/config` (`custom/backup`) | `~/.config/waybar/config`                   | Modulo Waybar che mostra lo stato        |

---

## Cosa fa lo script

`backup_hdd.sh <UUID>`:

1. Attende il montaggio del disco (fino a 5 minuti).
2. **Mirror della home** su `backup_automatico/` con
   `rsync -aHS --info=progress2 --no-inc-recursive --delete` ed esclusioni
   ottimizzate (`.cache/`, `node_modules/`, `target/`, `.git/`, `datasets/`,
   `modelli/`, `noya_packs/`, `Scaricati/`, i symlink `TUTTI_I_*`, ecc.).
3. **Archiviazione incrementale** (senza `--delete`, accumulo) di
   `datasets` → `Datasets_Archivio`, `modelli` → `Modelli_Archivio`,
   `noya_packs` → `noya_packs_Archivio`.
4. **Link simbolici di comodo** nella home: `HDD_Attivo`, `TUTTI_I_DATASETS`,
   `TUTTI_I_MODELLI`, `TUTTI_I_PACKS`.
5. **`sync -f` finale** per svuotare la cache su disco, così lo smontaggio è
   immediato, poi notifica "Backup completato… puoi smontare e staccare il disco".

> `--no-inc-recursive` forza la scansione completa prima del trasferimento, così la
> percentuale di `--info=progress2` è monotona (la barra non torna indietro).

Un **lockfile** (`/tmp/backup_hdd_dynamic.lock`) evita esecuzioni concorrenti; il log
di debug completo finisce in `/tmp/pipeline_debug.log`.

---

## Barra di avanzamento in Waybar

`backup_hdd.sh` scrive il progresso in due file letti dal modulo `custom/backup`:

- `/tmp/backup_hdd_progress` — output di `rsync --info=progress2` (percentuale).
- `/tmp/backup_hdd_progress.fase` — fase corrente (es. `Mirror home → Disco A`),
  presente anche durante il `sync` finale quando rsync non è più in esecuzione.

`backup-status.sh` (return-type JSON, `interval: 2`) mostra:

- **`󰁯 NN%`** nel testo, con barra `█░` (20 celle) nel tooltip;
- **`󰁯 SYNC`** con tooltip "Sincronizzazione finale — NON staccare il disco" durante
  il flush finale;
- niente (testo vuoto) quando non c'è nessun backup in corso.

Configurazione del modulo (`../waybar-niri/config`):

```jsonc
"custom/backup": {
    "exec": "~/.config/waybar/scripts/backup-status.sh",
    "return-type": "json",
    "interval": 2,
    "tooltip": true
}
```

---

## Adattatore JMicron JMS578

L'adattatore SATA-USB JMicron JMS578 (`152d:0578`) tende a "staccarsi" per via
dell'autosuspend USB. La prima regola di `99-backup-hdd.rules` lo disabilita:

```udev
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="152d", ATTR{idProduct}=="0578", TEST=="power/control", ATTR{power/control}="on"
```

---

## Setup manuale

### 1. Script e file di sistema

Script di backup:

```bash
sudo install -m 755 backup_hdd.sh /usr/local/bin/backup_hdd.sh
```

Servizio systemd (template):

```bash
sudo install -m 644 backup-hdd@.service /etc/systemd/system/backup-hdd@.service
```

Regola udev:

```bash
sudo install -m 644 99-backup-hdd.rules /etc/udev/rules.d/99-backup-hdd.rules
```

Script e modulo Waybar (deploy dei dotfiles utente, es. via stow/symlink):

```bash
# backup-status.sh in ~/.config/waybar/scripts/ e il modulo custom/backup
# nel config di Waybar sono gestiti insieme al resto della cartella waybar-niri.
```

### 2. Ricarica dei daemon

```bash
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## Controllo, test e debug

Avvio manuale del servizio (sostituisci l'UUID):

```bash
sudo systemctl start backup-hdd@84763b78-b0dc-4593-ba3b-cebc88d54dda.service
```

Stato del servizio:

```bash
sudo systemctl status backup-hdd@84763b78-b0dc-4593-ba3b-cebc88d54dda.service
```

Log in tempo reale (tutte le istanze):

```bash
sudo journalctl -u "backup-hdd@*" -f
```

Log di debug dello script:

```bash
cat /tmp/pipeline_debug.log
```

Verifica del punto di montaggio tramite UUID:

```bash
lsblk -rn -o UUID,MOUNTPOINT | grep "<UUID>"
```

---

## Aggiungere un disco

1. Ricava l'UUID: `lsblk -rn -o UUID,NAME,SIZE` oppure `blkid`.
2. Aggiungi una riga in `99-backup-hdd.rules` con quell'UUID (copia una delle regole
   Disco A/B/C esistenti).
3. (Opzionale) Aggiungi un `case` in `backup_hdd.sh` per dargli un nome descrittivo
   nelle notifiche — serve **solo** per l'etichetta, non per il funzionamento.
4. Ricarica le regole: `sudo udevadm control --reload-rules && sudo udevadm trigger`.
