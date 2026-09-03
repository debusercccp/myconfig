L'obiettivo era configurare l'architettura hardware ibrida per dedicare la GPU dedicata esclusivamente al Machine Learning, ma la gestione energetica ha richiesto la risoluzione di comportamenti anomali a livello di firmware.
### 1. Isolamento della GPU e Gestione Energetica
* **Problema iniziale:** `nvidia-smi` non comunicava con il driver e la GPU rimaneva costantemente alimentata.
* **Analisi:** I pacchetti CUDA e i driver proprietari erano già presenti. Tuttavia, la GPU rimaneva bloccata in stato prestazionale P3 (10W di assorbimento in idle) a causa del demone `nvidia-persistenced`, che la teneva costantemente sveglia.
* **Workaround:** Abbiamo disabilitato il demone di persistenza, forzando il driver a rispettare le regole di power management (`NVreg_DynamicPowerManagement=0x02`) e le regole udev. Questo ha permesso al bus PCI di tagliare l'alimentazione (stato D3cold) quando non ci sono calcoli in corso.
### 1.1. Risoluzione dei Crash ACPI e Isolamento del Compositor (Niri & GRUB)
* **Problema:** Niri registrava un errore DRM all'avvio (`Operation not supported - os error 95`) tentando di caricare la GPU secondaria. Allo spegnimento o chiusura della sessione grafica, il sistema andava in kernel panic/freeze totale (hard reset manuale necessario) con log ACPI che riportavano un timeout irreversibile: `Aborting method \_SB.PCI0.PEG0.PEGP.NVPO due to previous error (AE_AML_LOOP_TIMEOUT)`.
* **Analisi:** Di default, Niri esegue il probing di tutti i dispositivi in `/dev/dri/card*`. Il demone grafico e il kernel entravano in una *race condition* o in un conflitto di gestione energetica cercando di cambiare simultaneamente lo stato della GPU NVIDIA allo spegnimento. L'ACPI firmware del Lenovo andava in loop. Poiché l'accelerazione 3D della NVIDIA è usata esclusivamente per stack AI/ML (es. TensorFlow/PyTorch) e non per il display, l'interfaccia DRM è totalmente superflua.
* **Fix definitivo (Due livelli):**
  1. **Lato Compositor:** Istruito Niri ad agganciarsi esclusivamente alla GPU integrata Intel, ignorando la scansione automatica dei nodi DRM.
  2. **Lato Kernel (GRUB):** Disabilitato il *modesetting* DRM di NVIDIA. Questo rende la GPU dedicata "invisibile" a Wayland e all'ambiente desktop (nessun nodo generato in `/dev/dri/`), mantenendo però intatti e funzionanti i moduli per il calcolo parallelo (`nvidia` e `nvidia-uvm`).
### 2. Il Failsafe Termico (Ventole fuori controllo)
* **Problema:** Nonostante le temperature ottimali (CPU a 46°C, GPU a 45°C), la ventola principale girava costantemente a 2363 RPM. Il problema persisteva anche rimuovendo forzatamente i moduli NVIDIA dal kernel (`modprobe -r`).
* **Analisi:** L'Embedded Controller (il chip Lenovo che gestisce l'hardware termico) possiede una logica di emergenza. Mandando in autosospensione profonda la GPU, il sensore termico NVIDIA si spegne. Il BIOS interpreta l'assenza di lettura come un potenziale danno catastrofico e attiva il failsafe termico, spingendo le ventole per precauzione.
* **Workaround:** Abbiamo bypassato il controller hardware inviando il parametro `fan_control=1` al modulo `thinkpad_acpi`. Inviando direttamente il livello `0` al controller, abbiamo interrotto il loop di emergenza, trasferendo la gestione termica allo spazio utente (OS).
### 3. Automazione Fault-Tolerant (Thinkfan) — Tentativi Iniziali
* **Problema:** Il demone user-space `thinkfan` andava in crash o restava bloccato a `level 0` nonostante temperature elevate, con letture sentinella `-128(0)` mostrate da `thinkfan -q -v -n`.
* **Ipotesi esplorate e poi escluse come causa primaria:** timing al boot rispetto a udev, rinumerazione dinamica degli indici hwmonN a runtime (osservata realmente accadere, ma non era la causa radice del problema di lettura), EPP della CPU (causa reale del *surriscaldamento*, sezione 5, ma indipendente dal bug di lettura di thinkfan).
* **Causa radice reale, trovata con `strace`:** il campo `hwmon:` nel YAML, quando punta alla **directory** del chip (`/sys/class/hwmon/hwmonN`) *senza* combinarla correttamente con `name:`/`indices:`, causa una `read()` diretta sulla directory stessa invece che sul file `tempN_input` al suo interno — risultando in errore `EISDIR` internamente, mascherato dal fail-safe come lettura `-128`. Confermato con:
  ```
  openat(AT_FDCWD, "/sys/class/hwmon/hwmon5", O_RDONLY) = 5
  read(5, ..., 8191) = -1 EISDIR (È una directory)
  ```
* **Fix intermedio (superato dalla sezione 4.1):** puntare il campo `hwmon:` direttamente al file `tempN_input` risolveva la lettura, ma con indice numerico fisso — fragile rispetto alla rinumerazione hwmon (vedi sezione 4).

### 4. Rinumerazione hwmon a Runtime e Timing al Boot
* **Problema:** oltre al bug di lettura della sezione 3, sono stati osservati due problemi distinti e reali: (a) `thinkfan.service` falliva all'avvio con `No such file or directory` per race condition con udev non ancora completato; (b) l'indice hwmonN dei chip (`coretemp`, `thinkpad`, ecc.) **cambia regolarmente**, sia a runtime senza reboot sia — soprattutto — **ad ogni singolo avvio del sistema**. È stato osservato `coretemp` spostarsi da hwmon10 a hwmon5, e `thinkpad` da hwmon9 a hwmon8, in boot successivi senza alcuna modifica hardware.
* **Causa della rinumerazione (perché succede):** l'indice hwmonN non è un ID fisso legato al device fisico, ma un contatore progressivo (IDA, Index Allocator) assegnato dal kernel nell'ordine in cui i driver si registrano. Questo ordine dipende dal timing di probe asincrono dei driver (specialmente quelli USB-C come `tps6598x` e `ucsi_source_psy`, che si inizializzano in modo non deterministico rispetto al kernel core), da eventuali moduli caricati in ordine leggermente diverso tra un boot e l'altro, e da eventi runtime come sospensione/risveglio della GPU o plug/unplug di periferiche USB-C che liberano e riassegnano indici. Il **nome** del chip (`coretemp`, `thinkpad`, `acpitz`), al contrario, è dichiarato dal driver stesso ed è sempre stabile.
* **Fix (a) — timing al boot:** override systemd che attende `systemd-udev-settle.service` prima dell'avvio, con retry automatico.
* **Fix (b) — rinumerazione:** regola udev che triggera un `try-restart` di thinkfan ad ogni evento `add`/`remove` su un device hwmon, con debounce di 2 secondi per evitare restart nella finestra instabile tra remove e add dello stesso device.

### 4.1. Binding Dinamico per Nome — Fix Definitivo
* **Problema:** il fix della sezione 3 (path a indice numerico fisso, es. `hwmon5/temp1_input`) andava riaggiornato manualmente ad ogni boot in cui la rinumerazione si ripresentava — non sostenibile, e la regola udev della sezione 4 riavvia il processo ma non riscrive da sola il file YAML con i nuovi indici.
* **Fix definitivo:** usare `hwmon:` come cartella **base** (`/sys/class/hwmon`) combinata con `name:` (nome stabile del chip) e `indices:` (quali `tempN_input` leggere, per selezionare un sensore specifico quando il chip ne espone più di uno, come `thinkpad` con CPU e GPU). Con questa sintassi thinkfan, ad ogni proprio avvio, scansiona la cartella base, trova quale hwmonN ha il `name` richiesto in quel momento, e legge i `tempN_input` indicati — indipendentemente da come si sono rinumerati gli indici.
* **Importante — limite del meccanismo:** la risoluzione nome→indice avviene **una sola volta, all'avvio del processo thinkfan** (non è rivalutata ad ogni ciclo di poll). La "dinamicità" reale nasce dalla combinazione di due meccanismi: il binding per nome (sezione 4.1) + il restart automatico via regola udev (sezione 4, fix b) ogni volta che la topologia hwmon cambia. Senza il secondo, il primo da solo risolverebbe comunque solo al boot, non durante l'esecuzione.
* **Verifica label per un chip con più sensori:**
  ```bash
  for f in /sys/class/hwmon/hwmonN/temp*_label; do echo "$f: $(cat $f)"; done  # sostituire N con l'indice attuale
  ```
  Su `orion`: `coretemp` → `temp1_input` = Package id 0; `thinkpad` → `temp1_input` = CPU (via EC), `temp2_input` = GPU; `acpitz` → un solo sensore, nessuna label necessaria.

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

### 6. Temperatura Bloccata su Waybar (20°C fisso)
* **Problema:** il modulo `temperature` di Waybar mostrava sempre 20°C, indipendentemente dal carico reale.
* **Analisi:** Waybar legge di default da `/sys/class/thermal/thermal_zoneN`, un namespace di indici **completamente separato** da quello hwmon e soggetto alla stessa instabilità di numerazione. Il config puntava a `thermal-zone: 1`, che su `orion` corrisponde a `INT3400 Thermal` — una zona ferma a 20°C — invece che a `x86_pkg_temp` (la zona reale del Package CPU).
* **Fix:** invece di affidarsi a un indice `thermal-zone` (soggetto alla stessa fragilità hwmon vista nelle sezioni precedenti), puntare direttamente il modulo al file hwmon di `coretemp` già verificato e usato da thinkfan, tramite il parametro `hwmon-path`.
* **Nota:** questo binding in Waybar è a indice fisso, non dinamico per nome come in thinkfan (sezione 4.1) — soggetto quindi alla stessa fragilità di rinumerazione. Se la temperatura in Waybar torna a mostrare un valore fisso o sbagliato dopo un riavvio, riverificare l'indice hwmon corrente con il comando della sezione 4 e aggiornare `hwmon-path` di conseguenza.

L'infrastruttura è ora pronta e verificata end-to-end: il sistema delega il display e Wayland alla GPU integrata, isola completamente NVIDIA dal nodo DRM evitando i kernel panic ACPI allo spegnimento, mantiene la GPU in autosospensione reale, applica un EPP bilanciato per evitare boost inutili in idle, e affida il controllo termico a `thinkfan` con binding dinamico per nome — risolto ad ogni avvio e mantenuto aggiornato dalla regola udev, resistente sia al timing di boot sia alla rinumerazione hwmon.

#### Configurazione finale — `/etc/thinkfan.yaml`
```yaml
fans:
  - tpacpi: /proc/acpi/ibm/fan
sensors:
  - hwmon: /sys/class/hwmon
    name: coretemp
    indices: [1]
    optional: true
  - hwmon: /sys/class/hwmon
    name: thinkpad
    indices: [1, 2]
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

#### Configurazione Waybar — modulo `temperature`
```json
"temperature": {
    "hwmon-path": "/sys/class/hwmon/hwmon5/temp1_input",
    "format": "󰔏",
    "format-alt-click": "click-right",
    "format-alt": "󰔏 {temperatureC}°C",
    "critical-threshold": 70,
    "format-critical": "󰸁 {temperatureC}°C",
    "tooltip": true,
    "tooltip-format": "Temperatura: {temperatureC}°C"
}
```
Ricaricare dopo la modifica:
```bash
pkill -RTMIN+9 waybar
```

#### Configurazione Niri — `~/.config/niri/config.kdl` e GRUB
```kdl
# Forza l'uso esclusivo della GPU Intel integrata per il rendering Wayland
debug {
    render-drm-device "/dev/dri/renderD128"
}
```
```
# Disabilita il modesetting per isolare NVIDIA dal display server
GRUB_CMDLINE_LINUX_DEFAULT="quiet nvidia-drm.modeset=0"
```
Verifica:
```bash
# 1. Verifica che il parametro modeset sia applicato nel kernel corrente
cat /proc/cmdline | grep nvidia-drm.modeset=0
# 2. Verifica i nodi DRM esposti (se il fix funziona, la scheda NVIDIA non deve apparire qui)
ls -la /dev/dri/by-path/
# 3. Verifica funzionamento CUDA/ML indipendente dal server grafico
nvidia-smi
```

#### Runbook di diagnosi e fix
```bash
# 1. Mitigazione immediata in caso di temperature critiche
sudo bash -c 'echo level 7 > /proc/acpi/ibm/fan'

# 2. Verifica se thinkfan legge davvero (il test decisivo)
sudo systemctl stop thinkfan
sudo thinkfan -q -v -n -c /etc/thinkfan.yaml
# Ctrl+C dopo 10-15s. Se vedi "Temperatures(bias): -128(0)...", verificare con strace se e' un
# binding sbagliato (directory invece di file, vedi sezione 3):
sudo strace -e trace=openat,read -f thinkfan -q -v -n -c /etc/thinkfan.yaml 2>&1 | grep -B1 -A1 EISDIR
sudo systemctl start thinkfan

# 3. Trovare i nomi e i path corretti per ogni sensore
for h in /sys/class/hwmon/hwmon*; do echo "$h -> $(cat $h/name)"; done
for f in /sys/class/hwmon/hwmonN/temp*_label; do echo "$f: $(cat $f)"; done  # sostituire N

# 4. Verifica rinumerazione hwmon (utile solo se si e' tornati a un binding per indice fisso,
#    es. in Waybar - con thinkfan configurato per nome/sezione 4.1 non serve piu' controllarlo)
for h in /sys/class/hwmon/hwmon*; do echo "$h -> $(cat $h/name)"; done

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
