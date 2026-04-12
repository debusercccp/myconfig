## Configurazione Pipeline Backup HDD

1. Creazione Script e File di Sistema

Script di backup:
```
sudo nvim /usr/local/bin/backup_hdd.sh
sudo chmod +x /usr/local/bin/backup_hdd.sh
```

Servizio Systemd (Template):
```
sudo nvim /etc/systemd/system/backup-hdd@.service
```

Regola Udev:
```
sudo nvim /etc/udev/rules.d/99-backup-hdd.rules
```

2. Gestione Daemon e Configurazione

Ricaricare configurazione Systemd:
```
sudo systemctl daemon-reload
```

Ricaricare regole Udev:
```
sudo udevadm control --reload-rules
sudo udevadm trigger
```

3. Comandi di Controllo e Test

Avvio manuale del servizio (sostituire UUID):
```
sudo systemctl start backup-hdd@84763b78-b0dc-4593-ba3b-cebc88d54dda.service
```
Verifica stato del servizio:
```
sudo systemctl status backup-hdd@84763b78-b0dc-4593-ba3b-cebc88d54dda.service
```
Monitoraggio log in tempo reale:
```
sudo journalctl -u "backup-hdd@*" -f
```

4. Debug e Log Locali

Visualizzare log di debug dello script:
```
cat /tmp/pipeline_debug.log
```
Verifica punto di montaggio tramite UUID:
```
lsblk -rn -o UUID,MOUNTPOINT | grep "INSERIRE_UUID"
```
