# Guida all'Ottimizzazione e Manutenzione di Arch Linux

Questo documento raccoglie le configurazioni e i comandi essenziali per mantenere il sistema stabile, veloce e al riparo da aggiornamenti problematici tramite l'uso integrato di Snapper, GRUB, Reflector, Informant e la gestione dei file `.pacnew`.

---

## 1. Btrfs e Snapper (Gestione Snapshot)
Lo stack `snapper` + `snap-pac` garantisce la creazione di snapshot automatici prima e dopo ogni operazione di `pacman` e la manutenzione temporale del sistema. Il filesystem è strutturato con un subvolume dedicato `@snapshots` montato in `/.snapshots`.

### Comandi utili
* **Vedere tutti gli snapshot disponibili:**
```bash
  snapper -c root list

```

* **Creare uno snapshot manuale protetto (es. prima di modifiche critiche):**
```bash
sudo snapper -c root create --description "Descrizione" --cleanup-algorithm ""

```


* **Vedere cosa è cambiato tra due snapshot (es. tra pre e post aggiornamento):**
```bash
snapper -c root status ID_PRE..ID_POST

```


* **Vedere il diff esatto del testo dei file modificati:**
```bash
sudo snapper -c root diff ID_PRE..ID_POST /etc/

```



---

## 2. Integrazione GRUB e Rollback di Emergenza

Per poter avviare il sistema direttamente da uno snapshot precedente in caso di kernel panic o sistema non avviabile, utilizziamo `grub-btrfs`.

### Installazione e configurazione iniziale (tramite AUR)

L'installazione include il demone `inotify-tools` per aggiornare automaticamente il menu all'avvio:

```bash
# Installazione da AUR con yay
yay -S grub-btrfs inotify-tools

# Abilitazione del demone per aggiornare GRUB in tempo reale
sudo systemctl enable --now grub-btrfsd

# Generazione iniziale del menu di GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

```

### Procedura di Rollback (Se il sistema si rompe)

1. Al riavvio del computer, nel menu di GRUB seleziona **Arch Linux snapshots**.
2. Scegli uno snapshot funzionante (es. l'ultimo snapshot "pre" pacman) e avvialo. Il sistema si avvierà in *sola lettura*.
3. Per rendere il ripristino definitivo, monta la radice del disco e clona lo snapshot sopra il subvolume principale `@`:
```bash
# Monta il top-level Btrfs
sudo mkdir -p /mnt/btrfs-root
sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt/btrfs-root

# Archivia il sistema rotto
sudo mv /mnt/btrfs-root/@ /mnt/btrfs-root/@_bad

# Clona lo snapshot (sostituisci N con l'ID dello snapshot in uso)
sudo btrfs subvolume snapshot /mnt/btrfs-root/@snapshots/N/snapshot /mnt/btrfs-root/@

# Smonta e riavvia
sudo umount /mnt/btrfs-root
sudo rmdir /mnt/btrfs-root
sudo reboot

```



---

## 3. Reflector (Ottimizzazione Mirror)

Reflector interroga l'API di Arch Linux per trovare i mirror più veloci e aggiornati, ignorando quelli andati offline o con latenze elevate.

### Generazione della Mirrorlist

* **Lista mista bilanciata (Italia prioritaria, Germania come fallback):**
```bash
# 1. Server IT in testa
sudo reflector --country Italy --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# 2. Server DE in coda
sudo reflector --country Germany --latest 5 --protocol https --sort rate | sudo tee -a /etc/pacman.d/mirrorlist

```


* **Verificare la provenienza dei server correnti:**
```bash
grep '^Server' /etc/pacman.d/mirrorlist

```



---

## 4. Informant (Sicurezza Aggiornamenti)

Informant impedisce a `pacman` di completare transazioni se ci sono comunicazioni critiche (Breaking Changes) non lette sul sito di Arch Linux.

### Comandi utili

* **Controllare se ci sono news non lette:**
```bash
informant check

```


* **Leggere le news (e sbloccare pacman):**
```bash
informant read

```


* **Resettare lo stato (segna come non lette, utile per testare l'hook):**
```bash
informant reset

```



---

## 5. Gestione file `.pacnew` e Hook Pacman

Quando un aggiornamento di sistema modifica un file di configurazione in `/etc/` che era stato precedentemente alterato, pacman salva la nuova versione con estensione `.pacnew` per non sovrascrivere il setup locale.

### Comandi utili

* **Cercare file .pacnew o .pacsave orfani:**
```bash
pacdiff -o

```


* **Risolvere i conflitti interattivamente con Neovim:**
```bash
sudo DIFFPROG="nvim -d" pacdiff

```


*(Opzioni durante il merge: `[V]`iew, `[M]`erge, `[S]`kip, `[R]`emove pacnew, `[O]`verwrite).*

### Automazione tramite Hook di Pacman

Avviso colorato automatico a fine transazione pacman in caso di conflitti da risolvere. Configurato in `/etc/pacman.d/hooks/99-pacnew-warn.hook`:

```ini
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Controllo presenza file .pacnew o .pacsave...
When = PostTransaction
Exec = /usr/bin/bash -c "if pacdiff -o > /dev/null 2>&1; then echo -e '\n\e[1;31m==> ATTENZIONE: Trovati file .pacnew o .pacsave non gestiti!\e[0m'; pacdiff -o; echo -e '\e[1;33mEsegui: sudo DIFFPROG=\"nvim -d\" pacdiff\e[0m\n'; fi"

```


