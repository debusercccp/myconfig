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

### 4. Race Condition e Rinumerazione hwmon a Runtime (Fans a 0 RPM con CPU a 100°C)
* **Problema:** Nonostante `thinkfan.yaml` correttamente configurato con `optional: true` su tutti i sensori, il servizio falliva sistematicamente all'avvio con `ERROR: /sys/class/hwmon/hwmonN/temp1_input: No such file or directory`. Anche dopo il fix del boot, il fan si fermava spontaneamente durante il normale funzionamento (non solo all'avvio) con la CPU a 90-100°C.
* **Analisi (parte 1 — timing al boot):** `thinkfan` apre i file descriptor sui path hwmon una sola volta all'avvio del processo. Se `systemd` lo lancia prima che `udev` abbia finito di popolare completamente i nodi sysfs, il processo esce con `exit-code 1` e non si riavvia da solo.
* **Analisi (parte 2 — causa più profonda, confermata sul campo):** l'indice hwmonN di `coretemp` **non è stabile a runtime**. È stato osservato spostarsi da `hwmon10` a `hwmon5` senza alcun reboot, con `hwmon10` riassegnato a `iwlwifi_1`. `thinkfan` tiene aperti i file descriptor sul path numerico aperto all'avvio; quando l'indice cambia sotto di lui, quel file descriptor punta a un device diverso — da qui le letture sentinella `-128(0)` viste con `thinkfan -q -v -n`, con fail-safe del demone che è `level 0`, l'opposto del comportamento desiderato in un guasto.
* **Workaround (scartato):** aggancio via symlink udev stabile (`SYMLINK+="thinkfan-coretemp"` su `ATTR{name}=="coretemp"`) per rendere il path immune alla rinumerazione. Il match non si è mai risolto — l'attributo `name` non è affidabile come regola di matching udev nel momento in cui l'evento `add` viene processato per i device hwmon.
* **Fix definitivo:** due meccanismi complementari.
  1. Override systemd che fa attendere il completamento iniziale di udev prima dell'avvio del servizio (risolve il crash al boot).
  2. Regola udev che triggera un `try-restart` di thinkfan ad ogni evento `add`/`remove` su un device hwmon, con un debounce di 2 secondi via `systemd-run --on-active=2` per evitare che il restart scatti nella finestra instabile tra remove e add dello stesso device (risolve la rinumerazione a runtime).
* **Lezione:** in caso di crash imprevisto e prolungato di `thinkfan`, l'Embedded Controller riprende il controllo nativo del fan (comportamento firmware standard, non pericoloso ma non ottimale). Verificare sempre `pwm1` via `sensors` insieme alla temperatura effettiva prima di assumere che `0% MANUAL CONTROL` sia un guasto: può essere una decisione legittima del daemon se le temperature sono davvero sotto soglia.

### 5. Causa Radice del Surriscaldamento: EPP Aggressivo (non hardware, non GPU, non thinkfan)
* **Problema:** anche con `thinkfan` che finalmente pilotava il fan correttamente al massimo livello, il Package id 0 restava bloccato tra 90-100°C in condizioni apparentemente di idle (`ps`/`top` non mostravano alcun processo rilevante che consumasse CPU).
* **Analisi:** `cat /proc/cpuinfo | grep MHz` mostrava quasi tutti i core sostenuti a 4.2-4.3GHz — turbo pieno, non idle. I C-states (`intel_idle`, fino a C10) erano tutti abilitati e funzionanti, quindi non era un problema di risparmio energetico mancante a livello di stati di sospensione della CPU. Il governor `scaling_governor` risultava già `powersave` su tutti i core — anche questa pista si è rivelata un vicolo cieco. La vera causa era l'**EPP (Energy Performance Preference)**: con `intel_pstate` in modalità `active` (HWP hardware-managed), è l'EPP a determinare l'aggressività del boost indipendentemente dal governor. Il sistema aveva `energy_performance_preference` impostato su `balance_performance` (12/12 core) — valore che spinge la CPU a salire aggressivamente al turbo anche per carichi minimi o transitori non visibili nei tool standard.
* **Anche la GPU è stata verificata ed esclusa come causa**: `nvidia-persistenced` risultava correttamente `inactive (dead)` e `disabled`, nessun processo aveva file aperti su `/dev/nvidia*` (`lsof` vuoto), e `runtime_status` del device PCI restava `suspended` sia prima che dopo un'interrogazione `nvidia-smi` — la lettura P3/9W momentanea vista durante il test era solo l'effetto del comando stesso che risveglia brevemente la scheda per rispondere, comportamento normale e documentato del driver NVIDIA con runtime PM attivo.
* **Fix:**
  ```bash
  echo balance_power | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
  ```
  Risultato: crollo da 90-100°C a 58°C in idle nell'immediato. Reso persistente al boot con un service systemd dedicato (vedi sotto).
* **Lezione:** su CPU Intel con `intel_pstate` in modalità `active`/HWP, il `scaling_governor` da solo non è sufficiente a diagnosticare o controllare il comportamento del boost — va sempre controllato anche `energy_performance_preference` per ogni core. Un EPP aggressivo lasciato di default (o resettato da un aggiornamento kernel/pacchetto) può mascherarsi da problema hardware (pasta termica, dissipazione) quando in realtà è puro software.

L'infrastruttura è ora pronta: il sistema delega il display e Wayland alla GPU integrata, mantiene la GPU NVIDIA in autosospensione reale e verificata, applica un EPP bilanciato per evitare boost inutili in idle, e affida il controllo termico a `thinkfan` reso resiliente sia al timing di boot sia alla rinumerazione hwmon a runtime.

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
  - [0, 0, 42]
  - [1, 38, 50]
  - [2, 45, 58]
  - [4, 52, 65]
  - [7, 60, 80]
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

# 2. Diagnosi thinkfan — stato del servizio e log storici
systemctl status thinkfan
sudo journalctl -u thinkfan
sudo journalctl -b -u thinkfan

# 3. Verifica mapping hwmon -> nome sensore (attenzione: può cambiare a runtime)
for h in /sys/class/hwmon/hwmon*; do echo "$h -> $(cat $h/name)"; done

# 4. Verifica che fan_control sia persistito
cat /etc/modprobe.d/thinkpad_acpi.conf
cat /sys/module/thinkpad_acpi/parameters/fan_control   # deve dare "Y"

# 5. Test diretto in foreground (output non bufferizzato, su file, per vedere tutte le righe di polling)
sudo systemctl stop thinkfan
sudo stdbuf -oL thinkfan -q -v -n > /tmp/thinkfan_test.log 2>&1 &
sleep 8
sudo kill -9 $(pgrep -f "thinkfan -q -v -n")
cat /tmp/thinkfan_test.log
sudo rm -f /run/thinkfan.pid
sudo systemctl start thinkfan

# 6. Diagnosi surriscaldamento senza causa apparente — controllare in quest'ordine:
cat /proc/cpuinfo | grep MHz                                          # frequenze reali sostenute
cat /sys/module/intel_idle/parameters/max_cstate                      # C-states disponibili
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c
cat /sys/devices/system/cpu/intel_pstate/status                       # active = HWP, EPP conta più del governor
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort | uniq -c
nvidia-smi --query-gpu=pstate,power.draw,temperature.gpu --format=csv
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status             # deve essere "suspended" a riposo
sudo lsof /dev/nvidia* 2>/dev/null                                     # deve essere vuoto se la GPU non è in uso

# 7. Fix EPP se energy_performance_preference risulta balance_performance o performance
echo balance_power | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference

# 8. Applicare tutto e verificare
sudo systemctl daemon-reload
sudo systemctl restart thinkfan
systemctl status thinkfan --no-pager
sensors | grep -E "Package|pwm1|fan1"

# 9. Test finale — reboot completo per validare tutti i fix insieme
sudo reboot
# dopo il riavvio:
systemctl status thinkfan --no-pager
sudo journalctl -b -u thinkfan --no-pager
cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference | sort | uniq -c
sensors | grep -E "Package|pwm1"
```

