# Arch su `orion` (ThinkPad P53) — stato al 2026-10-23

Port su Arch della configurazione descritta in `nvidiaFU.md` e `hardFreeze.md`
(scritti su Debian). Qui solo ciò che è cambiato o diverso su Arch.
I file di sistema citati sono versionati in `arch/etc/` e si installano con
`sudo bash arch/install-system.sh`.

## 1. NVIDIA solo per ML (runtime D3, niente bbswitch)

* **bbswitch non serve più:** il driver `nvidia-open-dkms` con
  `NVreg_DynamicPowerManagement=0x02` spegne la Quadro T2000 da solo quando nessun
  processo CUDA la usa. Si risveglia automaticamente all'avvio di un job CUDA
  (PyTorch, ollama) e torna `suspended` pochi secondi dopo.
* **Problema trovato:** la GPU restava `active` perché `power/control` era `on`.
  Due cause:
  1. mancava la regola udev che mette `power/control=auto` → `etc/udev/rules.d/80-nvidia-pm.rules`;
  2. `nvidia` e `nvidia_uvm` erano in `MODULES=()` di `mkinitcpio.conf`: il driver si
     agganciava dentro l'initramfs, prima che `/etc/udev/rules.d` esistesse, quindi la
     regola non scattava mai. Rimossi (servivano solo per il KMS precoce, inutile qui).
* `nvidia_drm` resta in blacklist (`etc/modprobe.d/nvidia-pm.conf`), `nvidia-persistenced`
  disabilitato, niri renderizza su `/dev/dri/renderD128` (Intel).
* **Limite:** sul P53 HDMI e USB-C/TB video sono cablati sulla NVIDIA → con `nvidia_drm`
  in blacklist i monitor esterni non funzionano.
* **Verifica senza svegliare la GPU** (`nvidia-smi` la sveglia):
  ```bash
  cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # suspended
  ```

## 2. Ventole e EPP

* Su Arch c'era solo `fan_control=1`: mancavano thinkfan e `cpu-epp.service`, quindi l'EC
  restava in failsafe (~1950 RPM a 38°C, sensore GPU `temp2` illeggibile con GPU sospesa).
* **thinkfan 2.0.0** da chaotic-aur, config `etc/thinkfan.yaml`. Differenza dalla versione
  Debian: il sensore GPU (`thinkpad` indice 2) è un blocco `optional` separato, così con GPU
  sospesa viene saltato e con GPU attiva (ML) entra nella curva.
* Override `etc/systemd/system/thinkfan.service.d/override.conf`: pulizia pidfile + restart.
  Niente attesa su `systemd-udev-settle` (deprecato), copre la regola udev 91.
* **EPP:** `cpu-epp.service` ora parte `After=power-profiles-daemon.service`, altrimenti ppd
  rimette `balance_performance` al boot. Cambiare profilo da ppd lo sovrascrive fino al
  prossimo avvio.
* Alias in `.bashrc`: `fan-quiet` / `fan-auto` toccano solo il turbo (`no_turbo`), la
  ventola la gestisce sempre thinkfan; `fan-status` mostra velocità, livello e turbo.

## 3. Waybar: temperatura con path stabile

Sostituito `hwmon-path` a indice fisso (era finito su `pch_cannonlake`) con il path del
device, che non cambia tra i boot:
```json
"hwmon-path-abs": "/sys/devices/platform/coretemp.0/hwmon",
"input-filename": "temp1_input",
```

## 4. Manutenzione sistema

* `systemd-networkd-wait-online` con `--any --timeout=10` (prima timeout di 2 min al boot):
  `etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf`.
* Timer attivi: `paccache.timer`, `fstrim.timer`, `reflector.timer`
  (`etc/xdg/reflector/reflector.conf`: Italia + vicini, ordinati per velocità).
* `ParallelDownloads = 10` in `pacman.conf`.
* Snapper anche su `/home` (config `home`, timeline ridotta).
* Pacchetti aggiunti: `thinkfan`, `fwupd`, `fzf`, `zoxide`, `eza`, `fd`, `pkgfile`, `man-db`.

## 5. Dotfile con Stow

`~/.config/{niri,waybar,kitty,fuzzel,dunst,swaylock,conky,matugen,nvim}` e `~/.bashrc` sono
symlink al repo (vedi `stow/README.md`): si modifica il repo e l'effetto è immediato.
`/etc` invece è per copia via `arch/install-system.sh`.
