L'obiettivo era configurare l'architettura hardware ibrida per dedicare la GPU dedicata esclusivamente al Machine Learning, ma la gestione energetica ha richiesto la risoluzione di comportamenti anomali a livello di firmware.
### 1. Isolamento della GPU e Gestione Energetica
* **Problema iniziale:** `nvidia-smi` non comunicava con il driver e la GPU rimaneva costantemente alimentata.
* **Analisi:** I pacchetti CUDA e i driver proprietari erano già presenti. Tuttavia, la GPU rimaneva bloccata in stato prestazionale P3 (10W di assorbimento in idle) a causa del demone `nvidia-persistenced`, che la teneva costantemente sveglia.
* **Workaround:** Abbiamo disabilitato il demone di persistenza, forzando il driver a rispettare le regole di power management (`NVreg_DynamicPowerManagement=0x02`) e le regole udev. Questo ha permesso al bus PCI di tagliare l'alimentazione (stato D3cold) quando non ci sono calcoli in corso.
### 2. Il Failsafe Termico (Ventole fuori controllo)
* **Problema:** Nonostante le temperature ottimali (CPU a 46°C, GPU a 45°C), la ventola principale girava costantemente a 2363 RPM. Il problema persisteva anche rimuovendo forzatamente i moduli NVIDIA dal kernel (`modprobe -r`).
* **Analisi:** L'Embedded Controller (il chip Lenovo che gestisce l'hardware termico) possiede una logica di emergenza. Mandando in autosospensione profonda la GPU, il sensore termico NVIDIA si spegne. Il BIOS interpreta l'assenza di lettura come un potenziale danno catastrofico e attiva il failsafe termico, spingendo le ventole per precauzione.
* **Workaround:** Abbiamo bypassato il controller hardware inviando il parametro `fan_control=1` al modulo `thinkpad_acpi`. Inviando direttamente il livello `0` al controller, abbiamo interrotto il loop di emergenza, trasferendo la gestione termica allo spazio utente (OS).
### 3. Automazione Fault-Tolerant (Thinkfan) — Tentativi Iniziali
* **Problema:** Il demone user-space `thinkfan` andava in crash o restava bloccato a `level 0` nonostante temperature elevate, con letture sentinella `-128(0)` mostrate da `thinkfan -q -v -n`.
* **Ipotesi esplorate e poi escluse come causa primaria:** timing al boot rispetto a udev, rinumerazione dinamica degli indici hwmonN a runtime (osservata realmente accadere, ma non era la causa radice del problema di lettura), EPP della CPU (causa reale del *surriscaldamento*, sezione 5, ma indipendente dal bug di lettura di thinkfan).
* **Causa radice reale, trovata con `strace`:** il campo `hwmon:` nel YAML, quando punta alla **directory** del chip (`/sys/class/hwmon/hwmonN`) in combinazione con `name:` per la risoluzione, in questa build di thinkfan (Debian 13/trixie, kernel `6.12.107+deb13`) causa una `read()` diretta sulla directory stessa invece che sul file `tempN_input` al suo interno — risultando in errore `EISDIR` internamente, mascherato dal fail-safe come lettura `-128`. Confermato con:
  ```
  openat(AT_FDCWD, "/sys/class/hwmon/hwmon5", O_RDONLY) = 5
  read(5, ..., 8191) = -1 EISDIR (È una directory)
  ```
* **Fix definitivo:** puntare il campo `hwmon:` **direttamente al file `tempN_input`**, non alla directory del chip. Le label si trovano con:
  ```bash
  for f in /sys/class/hwmon/hwmonN/temp*_label; do echo "$f: $(cat $f)"; done
  ```
  Per `orion`: `coretemp` (hwmon5) → `temp1_input` = Package id 0; `thinkpad` (hwmon8) → `temp1_input` = CPU (via EC), `temp2_input` = GPU; `acpitz` (hwmon0) → `temp1_input` (unico sensore).

### 4. Rinumerazione hwmon a Runtime e Timing al Boot (problemi secondari, ancora validi)
* **Problema:** oltre al bug di lettura risolto sopra, sono stati osservati due problemi realmente accaduti e distinti: (a) `thinkfan.service` falliva all'avvio con `No such file or directory` per race condition con udev non ancora completato; (b) l'indice hwmonN di `coretemp` si è spostato spontaneamente a runtime (es. da hwmon10 a hwmon5, senza reboot), rompendo qualunque binding basato su indice numerico fisso.
* **Fix (a):** override systemd che attende `systemd-udev-settle.service` prima dell'avvio, con retry automatico.
* **Fix (b):** regola udev che triggera un `try-restart` di thinkfan ad ogni evento `add`/`remove` su un device hwmon, con debounce di 2 secondi per evitare restart nella finestra instabile tra remove e add dello stesso device.
* **Nota importante non ancora risolta:** poiché il fix definitivo della sezione 3 usa path con indice numerico esplicito (`hwmon5`, `hwmon8`, `hwmon0`), una rinumerazione a runtime rompe di nuovo il binding — il restart automatico via udev riavvia il processo ma non riscrive il file YAML con i nuovi indici. Se il problema si ripresenta, verificare prima di tutto se gli indici in `/etc/thinkfan.yaml` corrispondono ancora a quelli reali con `for h in /sys/class/hwmon/hwmon*; do echo "$h -> $(cat $h/name)"; done`.

### 5. Causa Radice del Surriscaldamento Reale: EPP Aggressivo
* **Problema:** anche a prescindere dai bug di thinkfan, il Package id 0 restava bloccato tra 90-100°C in condizioni apparentemente di idle (nessun processo rilevante in `ps`/`top`).
* **Analisi:** `cat /proc/cpuinfo | grep MHz` mostrava quasi tutti i core sostenuti a 4.2-4.3GHz — turbo pieno, non idle. I C-states e il `scaling_governor` (già `powersave`) sono stati esclusi come causa. La causa reale era l'**EPP (Energy Performance Preference)**: con `intel_pstate` in modalità `active` (HWP), è l'EPP a determinare l'aggressività del boost indipendentemente dal governor. Il sistema aveva `energy_performance_preference` su `balance_performance` (12/12 core), che spinge il turbo anche per carichi minimi.
* **GPU esclusa come causa:** `nvidia-persistenced` era correttamente `inactive`/`disabled`, nessun processo aveva file aperti su `/dev/nvidia*`, `runtime_status` del device PCI restava `suspended` a riposo — la lettura P3/9W vista durante un test era solo l'effetto momentaneo di `nvidia-smi` che risveglia brevemente la scheda per rispondere (comportamento normale del driver).
* **Fix:**
  ```bash
  echo balance_power | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
  ```
  Risultato: crollo da 90-100°C a 58°C in idle nell'immediato. Persistito al boot con un service systemd dedicato.
* **Lezione:** su CPU Intel con `intel_pstate` in modalità `active`/HWP, il `scaling_governor` da solo non basta a diagnosticare o controllare il boost — va sempre controllato anche `energy_performance_preference` per ogni core.

L'infrastruttura è ora pronta e verificata end-to-end: il sistema delega il display e Wayland alla GPU integrata, mantiene la GPU NVIDIA in autosospensione reale, applica un EPP bilanciato per evitare boost inutili in idle, e affida il controllo termico a `thinkfan` con binding diretto ai file `tempN_input` corretti — confermato reagire in autonomia (72% pwm a 59-73°C) senza intervento manuale.

#### Configurazione finale — `/etc/thinkfan.yaml`
```yaml
fans:
  - tpacpi: /proc/acpi/ibm/fan
sensors:
  - hwmon: /sys/class/hwmon/hwmon5/temp1_input
    optional: true
  - hwmon: /sys/class/hwmon/hwmon8/temp1_input
    optional: true
  - hwmon: /sys/class/hwmon/hwmon8/temp2_input
    optional: true
  - hwmon: /sys/class/hwmon/hwmon0/temp1_input
    optional: true
levels:
  - [0, 0, 42]
  - [1, 38, 50]
  - [2, 45, 58]
  - [4, 52, 65]
  - [7, 60, 80]
  - ["level auto", 75, 32767]
```
Nota: gli indici hwmon5/8/0 sono quelli osservati su `orion` al momento della scrittura — vanno riverificati con il comando della sezione 4 se il fan smette di reagire dopo un evento hwmon (sospensione GPU, dock USB-C, riavvio).

#### Override systemd — `/etc/systemd/system/thinkfan.service.d/override.conf`
```ini
[Unit]
After=systemd-udev-settle.service

[Service]
Restart=on-failure
RestartSec=5
```

#### Regola udev — `/etc/udev/rules.d/91-thinkfan-restart.rules`
```
SUBSYSTEM=="hwmon", ACTION=="add", RUN+="/usr/bin/systemd-run --no-block --on-active=2 /usr/bin/systemctl try-restart thinkfan.service"
SUBSYSTEM=="hwmon", ACTION=="remove", RUN+="/usr/bin/systemd-run --no-block --on-active=2 /usr/bin/systemctl try-restart thinkfan.service"
```

#### Servizio systemd EPP — `/etc/systemd/system/cpu-epp.service`
```ini
[Unit]
Description=Set CPU EPP to balance_power
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo balance_power | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference'

[Install]
WantedBy=multi-user.target
```
Abilitato con:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cpu-epp.service
```

#### Runbook di diagnosi e fix
```bash
# 1. Mitigazione immediata in caso di temperature critiche
sudo bash -c 'echo level 7 > /proc/acpi/ibm/fan'

# 2. Verifica se thinkfan legge davvero (il test decisivo)
sudo systemctl stop thinkfan
sudo thinkfan -q -v -n -c /etc/thinkfan.yaml
# Ctrl+C dopo 10-15s. Se vedi "Temperatures(bias): -128(0)...", NON e' un problema di
# sensore assente: e' quasi certamente un binding sbagliato (directory invece di file).
# Verifica con strace:
sudo strace -e trace=openat,read -f thinkfan -q -v -n -c /etc/thinkfan.yaml 2>&1 | grep -B1 -A1 EISDIR
sudo systemctl start thinkfan

# 3. Trovare i path corretti (file, non directory!) per ogni sensore
for h in /sys/class/hwmon/hwmon*; do echo "$h -> $(cat $h/name)"; done
for f in /sys/class/hwmon/hwmonN/temp*_label; do echo "$f: $(cat $f)"; done  # sostituire N

# 4. Verifica rinumerazione hwmon (se il fan smette di reagire dopo aver funzionato)
for h in /sys/class/hwmon/hwmon*; do echo "$h -> $(cat $h/name)"; done
# confrontare con gli indici scritti in /etc/thinkfan.yaml

# 5. Diagnosi surriscaldamento senza causa apparente
cat /proc/cpuinfo | grep MHz
cat /sys/devices/system/cpu/intel_pstate/status
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort | uniq -c
nvidia-smi --query-gpu=pstate,power.draw,temperature.gpu --format=csv
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
sudo lsof /dev/nvidia* 2>/dev/null

# 6. Fix EPP se energy_performance_preference risulta balance_performance o performance
echo balance_power | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference

# 7. Generare carico controllato per testare la curva fan (senza installare pacchetti)
for i in $(seq 1 6); do yes > /dev/null & done
watch -n1 'sensors | grep -E "Package|pwm1"'
kill $(jobs -p)   # per fermare — attenzione a job multipli, usare $! se si lanciano altri processi nel mezzo

# 8. Test finale — reboot completo per validare tutti i fix insieme
sudo reboot
systemctl status thinkfan --no-pager
sudo journalctl -b -u thinkfan --no-pager
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort | uniq -c
sensors | grep -E "Package|pwm1"
```
