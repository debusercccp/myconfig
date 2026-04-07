# 🐧 Linux Kernel 6.19.7 — BORE Build

> Kernel personalizzato per Debian/Ubuntu con scheduler BORE, lean config e TCP BBR.  
> Obiettivo: massima reattività desktop e stack di rete ottimizzato.

---

## Indice

- [Obiettivi](#obiettivi)
- [Requisiti](#requisiti)
- [1. Preparazione dell'ambiente](#1-preparazione-dellambiente)
- [2. Applicazione della patch BORE](#2-applicazione-della-patch-bore)
- [3. Configurazione Lean Kernel](#3-configurazione-lean-kernel)
- [4. Compilazione e installazione](#4-compilazione-e-installazione)
- [5. Ottimizzazione TCP BBR](#5-ottimizzazione-tcp-bbr)
- [Verifica del sistema](#verifica-del-sistema)

---

## Obiettivi

| Componente | Intervento | Beneficio |
|---|---|---|
| **Scheduler** | BORE (Burst-Oriented Response Enhancer) | Latenza interattiva ridotta |
| **Dimensione kernel** | `localmodconfig` + no debug symbols | Compilazione più rapida, footprint minore |
| **Stack TCP** | Algoritmo BBR | Throughput e latenza migliorati su reti congestionate |

---

## Requisiti

- Distro Debian/Ubuntu (o derivata)
- Sorgenti kernel `6.19.7` scaricati e decompressi
- Patch `bore.patch` nella directory dei sorgenti

---

## 1. Preparazione dell'ambiente

Installazione delle dipendenze di build:

```bash
sudo apt update
sudo apt install build-essential flex bison libncurses-dev libssl-dev libelf-dev
```

Su Arch Linux:

```bash
sudo pacman -S --needed base-devel bc cpio libelf ncurses openssl pahole python wget grub
```

> `flex` e `bison` sono necessari per la generazione degli analizzatori lessicali usati durante la configurazione del kernel.

---

## 2. Applicazione della patch BORE

BORE modifica lo scheduler **CFS/EEVDF** nativo assegnando una priorità dinamica ai processi in base al loro *burst time*, favorendo le applicazioni interattive rispetto ai carichi CPU-bound in background.

```bash
patch -p1 < bore.patch
```

**File modificati dalla patch:**

- `kernel/sched/fair.c` — logica dello scheduler CFS/EEVDF
- `kernel/sched/bore.c` — nuovo sottosistema BORE (file creato)

---
### 2.5 La Configurazione "Lean"

## 2.5.1 — Localmodconfig

Il comando make localmodconfig funziona analizzando i moduli attualmente caricati nel sistema operativo (lsmod).

    Cosa fa: 
      Disabilita migliaia di driver per hardware che non possiedi.

      Regola d'oro: Prima di lanciarlo, assicurati che tutte le periferiche che usi abitualmente (chiavette USB, mouse, controller, stampanti) siano collegate e accese, altrimenti i relativi driver verranno rimossi.

## 2.5.2 — Risoluzione dei "Blocchi" Debian

I kernel Debian ufficiali sono compilati con chiavi di firma digitali (SYSTEM_TRUSTED_KEYS). Se provi a compilare senza disabilitarle, il processo fallirà con un errore di certificato mancante.
Usiamo ./scripts/config per:

    Rimuovere le chiavi: Impedisce errori di "Missing certs".

    Eliminare il Debug: Rimuovendo DEBUG_INFO, il kernel passa da ~500MB a ~15MB, rendendo il sistema più snello e il boot leggermente più rapido.

4. Approfondimento: Compilazione e Deployment

Qui il codice sorgente C viene trasformato in un binario eseguibile che il tuo processore può comprendere.
4.1 — Parallelismo con -j$(nproc)

La compilazione del kernel è una delle operazioni più pesanti per una CPU. Usando l'argomento -j$(nproc), istruiamo il compilatore a creare un numero di processi pari al numero di core logici della tua CPU.

    Risultato: Se hai 8 core, il kernel verrà compilato fino a 8 volte più velocemente rispetto a una build a thread singolo.

4.2 — La "Tripletta" di installazione su Debian

A differenza di altre distribuzioni, su Debian il Makefile è integrato con gli script di sistema:

    make modules_install: Prende tutti i driver compilati come moduli (.ko) e li organizza in /lib/modules/6.19.7/. Senza questo, al riavvio non avresti Wi-Fi, audio o accelerazione grafica.

    make install: È un comando "magico" che esegue tre operazioni:

        Copia l'immagine del kernel (vmlinuz) in /boot.

        Genera il file Initrd (Initial Ramdisk), un mini-sistema temporaneo che serve al kernel per caricare i driver del disco all'avvio.

        Crea la mappa dei simboli (System.map) per il debug del sistema.

    update-grub: Registra formalmente il nuovo kernel nel menu di avvio, posizionandolo solitamente come prima scelta.

## 3. Configurazione Lean Kernel

### 3.1 — Copia della configurazione corrente

```bash
cp /boot/config-$(uname -r) .config
```

### 3.2 — Rilevamento automatico dell'hardware

```bash
make localmodconfig
```

Analizza i moduli attualmente caricati e disabilita tutto il resto, riducendo drasticamente i tempi di compilazione.

### 3.3 — Disattivazione simboli di debug

I simboli di debug aumentano lo spazio occupato e allungano i tempi di linking. Vengono disabilitati esplicitamente:

```bash
scripts/config --disable DEBUG_INFO
scripts/config --disable DEBUG_INFO_BTF
scripts/config --disable GDB_SCRIPTS
```

> **Nota per Arch Linux:** Se `zcat /proc/config.gz` non è disponibile, la configurazione del kernel corrente può essere recuperata con:
> ```bash
> cp /usr/lib/modules/$(uname -r)/build/.config .config
> ```

---

## 4. Compilazione e installazione

### Compilazione

```bash
make -j$(nproc)
```

Genera i file oggetto (`.o`) e l'immagine compressa `bzImage` sfruttando tutti i thread disponibili.

### Installazione — Debian/Ubuntu

```bash
# Installa i moduli compilati in /lib/modules/6.19.7/
sudo make modules_install

# Copia il kernel in /boot e genera i file initrd
sudo make install

# Aggiorna il bootloader
sudo update-grub
```

### Installazione — Arch Linux

Su Arch l'installazione è manuale e più granulare:

```bash
# 1. Installa i moduli compilati (driver)
sudo make modules_install

# 2. Copia il kernel in /boot
sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-linux-bore

# 3. Genera l'initramfs
# Usa '6.19.7' se la cartella in /lib/modules non ha il suffisso -bore
sudo mkinitcpio -k 6.19.7 -g /boot/initramfs-linux-bore.img

# 4. Aggiorna GRUB
# Se /boot/grub non esiste: sudo mkdir -p /boot/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

---

## 5. Ottimizzazione TCP BBR

**BBR** (Bottleneck Bandwidth and RTT) è un algoritmo di controllo della congestione TCP sviluppato da Google, particolarmente efficace su reti con perdita di pacchetti o alta latenza.

Aggiungere le seguenti righe a `/etc/sysctl.conf`:

```ini
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

Applicare immediatamente senza riavvio:

```bash
sudo sysctl -p
```

---

## Verifica del sistema

Dopo il riavvio, verificare che tutto sia configurato correttamente:

```bash
# Versione kernel
uname -r
# Atteso: 6.19.7 (o 6.19.7-bore se impostato LOCALVERSION)

# Algoritmo TCP attivo
sysctl net.ipv4.tcp_congestion_control
# Atteso: net.ipv4.tcp_congestion_control = bbr

# Presenza del sottosistema BORE
ls /proc/sys/kernel/sched_bore
# Atteso: il file esiste
```

---

> **Risultato:** kernel personalizzato, privo di driver superflui, ottimizzato per uso desktop intensivo con stack di rete avanzato.
