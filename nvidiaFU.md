L'obiettivo era configurare l'architettura hardware ibrida per dedicare la GPU dedicata esclusivamente al Machine Learning, ma la gestione energetica ha richiesto la risoluzione di comportamenti anomali a livello di firmware.
### 1. Isolamento della GPU e Gestione Energetica
* **Problema iniziale:** `nvidia-smi` non comunicava con il driver e la GPU rimaneva costantemente alimentata.
* **Analisi:** I pacchetti CUDA e i driver proprietari erano già presenti. Tuttavia, la GPU rimaneva bloccata in stato prestazionale P3 (10W di assorbimento in idle) a causa del demone `nvidia-persistenced`, che la teneva costantemente sveglia.
* **Workaround:** Abbiamo disabilitato il demone di persistenza, forzando il driver a rispettare le regole di power management (`NVreg_DynamicPowerManagement=0x02`) e le regole udev. Questo ha permesso al bus PCI di tagliare l'alimentazione (stato D3cold) quando non ci sono calcoli in corso.
### 2. Il Failsafe Termico (Ventole fuori controllo)
* **Problema:** Nonostante le temperature ottimali (CPU a 46°C, GPU a 45°C), la ventola principale girava costantemente a 2363 RPM. Il problema persisteva anche rimuovendo forzatamente i moduli NVIDIA dal kernel (`modprobe -r`).
* **Analisi:** L'Embedded Controller (il chip Lenovo che gestisce l'hardware termico) possiede una logica di emergenza. Mandando in autosospensione profonda la GPU, il sensore termico NVIDIA si spegne. Il BIOS interpreta l'assenza di lettura come un potenziale danno catastrofico e attiva il failsafe termico, spingendo le ventole per precauzione.
* **Workaround:** Abbiamo bypassato il controller hardware inviando il parametro `fan_control=1` al modulo `thinkpad_acpi`. Inviando direttamente il livello `0` al controller, abbiamo interrotto il loop di emergenza, trasferendo la gestione termica allo spazio utente (OS).
### 3. Automazione Fault-Tolerant (Thinkfan)
* **Problema:** Il demone user-space `thinkfan` andava in crash per due motivi: la mancata risoluzione dei collegamenti simbolici di Debian nella cartella `hwmon` e, successivamente, la sparizione dinamica del sensore NVIDIA (`hwmon8`) quando la scheda entrava correttamente in stato di sospensione D3cold.
* **Workaround:** È stato sviluppato uno script di generazione YAML robusto. Utilizzando il globbing della shell per risolvere i percorsi e iniettando il parametro `optional: true` su ogni nodo termico, `thinkfan` ora ignora la temporanea indisponibilità del sensore hardware senza interrompere il servizio.

### 4. Race Condition al Boot (Fans a 0 RPM con CPU a 100°C)
* **Problema:** Nonostante `thinkfan.yaml` correttamente configurato con `optional: true` su tutti i sensori, il servizio falliva sistematicamente all'avvio con `ERROR: /sys/class/hwmon/hwmonN/temp1_input: No such file or directory`. Il sistema restava con `pwm1` bloccato a `0% MANUAL CONTROL` mentre la CPU raggiungeva 98-100°C (Package id 0, Core 3).
* **Analisi:** `thinkfan` apre i file descriptor sui path hwmon una sola volta all'avvio del processo. Se `systemd` lo lancia prima che `udev` abbia finito di popolare completamente i nodi sysfs (in particolare `temp1_input`, che viene scritto dopo la registrazione del device hwmon), il processo esce con `exit-code 1` e systemd non lo riavvia automaticamente per default. `optional: true` previene il crash solo quando il sensore è del tutto assente, non quando il path esiste ma non è ancora popolato — quindi in condizioni di race la protezione non scattava. Un test diretto con `thinkfan -q -v -n` ha inoltre mostrato letture `-128` (valore sentinella di lettura fallita) su tutti e tre i sensori simultaneamente, confermando che nei minuti successivi il fail-safe di thinkfan in assenza di dati validi è `level 0` — il comportamento opposto a quello desiderato in un guasto.
* **Workaround (scartato):** È stato tentato un aggancio via symlink udev stabile (`SYMLINK+="thinkfan-coretemp"` su `ATTR{name}=="coretemp"`) per rendere il path immune a eventuali rinumerazioni degli hwmonN. Il match non si è mai risolto — l'attributo `name` non è affidabile come regola di matching udev nel momento in cui l'evento `add` viene processato per i device hwmon. Abbandonato: il vero bug era solo il timing al boot, non la rinumerazione a runtime (mai osservata empiricamente), quindi il glob esistente su `/sys/class/hwmon` + `name:` nel YAML era già la soluzione corretta e robusta.
* **Fix definitivo:** Override systemd che fa attendere il completamento di udev prima dell'avvio del servizio, con retry automatico come rete di sicurezza residua.
* **Lezione:** in caso di crash imprevisto e prolungato di `thinkfan`, l'Embedded Controller riprende il controllo nativo del fan (comportamento firmware standard, non pericoloso ma non ottimale) — a differenza dello scenario descritto nella sezione 2, dove il fail-safe termico spingeva le ventole al massimo per l'assenza del sensore NVIDIA. Verificare sempre `pwm1` via `sensors` insieme alla temperatura effettiva prima di assumere che `0% MANUAL CONTROL` sia un guasto: può essere una decisione legittima del daemon se le temperature sono davvero sotto soglia.

L'infrastruttura è ora pronta: il sistema delega il display e Wayland alla GPU integrata e mantiene il blocco ventole in silenzio assoluto sotto i 50°C, lasciando la GPU NVIDIA in autosospensione pronta per il calcolo parallelo.

#### Configurazione finale — `/etc/thinkfan.yaml`
```yaml
fans:
  - tpacpi: /proc/acpi/ibm/fan
sensors:
  - hwmon: /sys/class/hwmon
    name: coretemp
    optional: true
  - hwmon: /sys/class/hwmon
    name: thinkpad
    optional: true
  - hwmon: /sys/class/hwmon
    name: acpitz
    optional: true
levels:
  - [0, 0, 50]
  - [1, 48, 60]
  - [3, 55, 70]
  - [6, 65, 80]
  - ["level auto", 75, 32767]
```

#### Override systemd — `/etc/systemd/system/thinkfan.service.d/override.conf`
```ini
[Unit]
After=systemd-udev-settle.service

[Service]
Restart=on-failure
RestartSec=5
```

#### Runbook di diagnosi e fix (sezione 4)
```bash
# 1. Mitigazione immediata — portare il fan al massimo mentre si diagnostica
sudo bash -c 'echo level 7 > /proc/acpi/ibm/fan'
# oppure, come tampone via BIOS:
sudo bash -c 'echo level auto > /proc/acpi/ibm/fan'

# 2. Diagnosi — stato del servizio e log storici
systemctl status thinkfan
sudo journalctl -u thinkfan          # mostra tutti i boot precedenti
sudo journalctl -b -u thinkfan       # solo il boot corrente

# 3. Verifica mapping hwmon -> nome sensore
for h in /sys/class/hwmon/hwmon*; do echo "$h -> $(cat $h/name)"; done

# 4. Verifica che il parametro kernel sia persistito correttamente
cat /etc/modprobe.d/thinkpad_acpi.conf
cat /sys/module/thinkpad_acpi/parameters/fan_control   # deve dare "Y"

# 5. Test diretto in foreground per vedere le letture live (senza killare il servizio attivo)
sudo systemctl stop thinkfan
sudo thinkfan -q -v -n
# Ctrl+C per uscire
sudo systemctl start thinkfan

# 6. Fix strutturale - override systemd per il timing al boot
sudo systemctl edit thinkfan.service
# (incollare il contenuto di override.conf sopra)

# 7. Ripristino del thinkfan.yaml pulito
sudo tee /etc/thinkfan.yaml <<'EOF'
fans:
  - tpacpi: /proc/acpi/ibm/fan
sensors:
  - hwmon: /sys/class/hwmon
    name: coretemp
    optional: true
  - hwmon: /sys/class/hwmon
    name: thinkpad
    optional: true
  - hwmon: /sys/class/hwmon
    name: acpitz
    optional: true
levels:
  - [0, 0, 50]
  - [1, 48, 60]
  - [3, 55, 70]
  - [6, 65, 80]
  - ["level auto", 75, 32767]
EOF

# 8. Applicare tutto e verificare
sudo systemctl daemon-reload
sudo systemctl restart thinkfan
systemctl status thinkfan --no-pager

# 9. Test finale - l'unico che conta davvero, perche' il bug si manifestava solo al boot
sudo reboot
# dopo il riavvio:
systemctl status thinkfan --no-pager
sudo journalctl -b -u thinkfan --no-pager
```
