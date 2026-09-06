# Resoconto Architetturale: Gestione Ibrida e Termica su ThinkPad P53 (Linux/Wayland)

L'obiettivo di questa configurazione era domare l'architettura ibrida del ThinkPad P53 (CPU Intel + GPU NVIDIA Quadro T2000), isolando la GPU dedicata per destinarla esclusivamente a carichi di Machine Learning on-demand, risolvendo contemporaneamente gravi anomalie termiche, loop di blocco ACPI allo spegnimento e hard freeze incontrollabili.

## 1. Isolamento della GPU NVIDIA e Risoluzione Hard Freeze (Il deadlock PCIe)

* **Problema Iniziale:** Il sistema andava regolarmente in hard freeze irrecuperabili. L'analisi ha rivelato che la causa era un deadlock sul bus PCIe tra il driver NVIDIA, il compositor Wayland (Niri) e la gestione energetica ACPI del kernel.
* **Analisi del Deadlock:** Nonostante si pensasse che la GPU fosse in idle, `lsof` ha rivelato che `niri` (tramite `libglvnd` ed EGL) eseguiva un probe e teneva aperti decine di handle su `/dev/nvidia0` e `/dev/nvidiactl`. Questo impediva l'entrata in stato `D3cold`. Inoltre, forzare parametri kernel come `acpi_enforce_resources=lax` causava collisioni fatali con il BIOS (Embedded Controller) durante le letture dei sensori, freezando l'hardware. Infine, il driver DRM di NVIDIA, se integrato nel framebuffer di avvio, non rilasciava mai il dispositivo.
* **La Soluzione Definitiva (Unbind e Blacklist):**
Poiché l'accelerazione 3D NVIDIA non è necessaria per l'ambiente desktop Wayland, abbiamo optato per l'isolamento "fisico" tramite ACPI:
1. **Blacklist Assoluta:** Creato `/etc/modprobe.d/blacklist-nvidia.conf` per impedire il caricamento di `nouveau`, `nvidia`, `nvidia_drm`, `nvidia_modeset` e `nvidia_uvm` al boot, aggiornando poi l'initramfs.
2. **Bbswitch per l'Hardware OFF:** Installato `bbswitch-dkms`. Tramite `options bbswitch load_state=0` in `modprobe.d`, il sistema invia un segnale ACPI `OFF` alla porta PCIe della Quadro T2000 fin dal primo secondo di boot.
3. **Boot Pulito (GRUB):** Modificato GRUB con `fbdev=1 nvidia-drm.modeset=0` per impedire a Plymouth o al kernel framebuffer di agganciarsi preventivamente ai driver video.


* **Risultato:** `cat /proc/acpi/bbswitch` restituisce `0000:01:00.0 OFF`. La GPU è fisicamente disalimentata (0W). I kernel panic, i loop `AE_AML_LOOP_TIMEOUT` e gli hard freeze sono scomparsi. Per usare CUDA/ML, basterà ricaricare il modulo e inviare il comando `ON` a bbswitch on-demand.

## 2. Il Failsafe Termico (Ventole fuori controllo) e il Tuning EPP

* **Problema:** Ventole fisse a 2363 RPM con hardware freddo (45°C) e picchi ingiustificati della CPU Intel a 90-100°C in condizioni di idle apparente.
* **Analisi Ventole:** L'assenza di lettura del sensore GPU (spenta) mandava l'Embedded Controller in panico, innescando il failsafe hardware. È stato necessario forzare `fan_control=1` sul modulo `thinkpad_acpi` per trasferire il controllo a livello utente.
* **Analisi Temperature (Causa Radice):** I picchi a 90°C non erano un bug di lettura, ma reali. L'`Energy Performance Preference (EPP)` di `intel_pstate` era impostato su `balance_performance`, forzando il turbo boost (4.2GHz) anche per carichi irrisori, ignorando il governor `powersave`.
* **Fix:** Creato un servizio systemd (`cpu-epp.service`) che ad ogni avvio applica `balance_power` a tutti i core. Risultato immediato: calo da 90°C a 58°C in idle.

## 3. Gestione Sensori Dinamici (Thinkfan e Waybar)

* **Problema:** `thinkfan` andava in crash e restituiva letture sentinella `-128(0)`. Waybar mostrava temperature fisse a 20°C.
* **Causa Radice (Rinumerazione Hwmon):** L'indice `hwmonN` in `/sys/class/hwmon/` non è fisso, ma cambia (es. da `hwmon10` a `hwmon5`) ad ogni boot in base al timing asincrono di `udev` (spesso legato alle porte USB-C/Type-C). Puntare a percorsi statici o peggio, direttamente alla directory (causando errore `EISDIR` in `strace`), mandava in crash il monitoraggio.
* **La Soluzione Fault-Tolerant (Thinkfan):**
1. **Binding Dinamico:** Riscritto `/etc/thinkfan.yaml` usando il campo `name:` (es. `coretemp`, `thinkpad`) combinato con gli `indices:`. In questo modo, thinkfan cerca il sensore per nome anziché per numero di indice.
2. **Timing al Boot:** Aggiunto un override systemd per far attendere `systemd-udev-settle.service` prima dell'avvio di thinkfan.
3. **Resilienza a Runtime:** Creata una regola udev (`/etc/udev/rules.d/91-thinkfan-restart.rules`) che triggera un restart differito (2s) di thinkfan ogni volta che un device hwmon viene aggiunto o rimosso, garantendo letture continue anche dopo hotplug USB-C.


* **Fix Waybar:** Sostituito l'inaffidabile `thermal-zone: 1` con un percorso hardware esplicito verso il sensore `coretemp` (`hwmon-path`). (Nota: essendo Waybar non dinamico, questo percorso va aggiornato se la topologia udev subisce cambiamenti drastici, ma solitamente è stabile).

## 4. Isolamento EGL del Compositor (Niri)

* **Configurazione Finale:** Per garantire che Wayland non tenti mai di comunicare con la NVIDIA (anche quando verrà risvegliata per il ML), lo script di avvio di Niri forza le variabili d'ambiente `WLR_DRM_DEVICES` e `AQ_DRM_DEVICES` su `/dev/dri/card0` (Intel). Cruciale l'aggiunta di `__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json` per impedire a `libglvnd` di caricare il JSON EGL proprietario, bloccando alla radice l'apertura indesiderata dei file descriptor in `/dev/nvidia*`.

## Stato del Sistema

L'architettura è ora stabile e segregata:

* Il calcolo grafico (Wayland/Desktop) è confinato in sicurezza sulla iGPU Intel.
* Il calcolo parallelo (CUDA/ML) è delegato alla Quadro T2000 tramite gestione manuale di `bbswitch`.
* I consumi elettrici sono minimizzati (NVIDIA off-grid).
* Il raffreddamento è gestito dinamicamente in base alle reali temperature del package CPU, senza falsi allarmi hardware e immune alla rinumerazione degli indici `hwmon`.
