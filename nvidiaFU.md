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

L'infrastruttura è ora pronta: il sistema delega il display e Wayland alla GPU integrata e mantiene il blocco ventole in silenzio assoluto sotto i 50°C, lasciando la GPU NVIDIA in autosospensione pronta per il calcolo parallelo.

```
sudo bash -c 'cat > /etc/thinkfan.yaml <<EOF
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
EOF'

```

````
sudo systemctl restart thinkfan
sudo systemctl status thinkfan

```
