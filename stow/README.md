# Stow layout (opzionale)

Layout alternativo per gestire i dotfile con [GNU Stow](https://www.gnu.org/software/stow/)
usando **symlink** invece della copia (`sync_config.sh` / `restore_config.sh`).

Questo è **additivo**: i vecchi script di copia restano e continuano a funzionare.
Puoi passare a Stow quando vuoi, senza fretta.

## Come funziona

Ogni pacchetto qui dentro rispecchia la struttura di `$HOME`. I file _non sono
duplicati_: ogni pacchetto è un symlink alla cartella canonica in cima al repo,
quindi la singola fonte di verità resta `niri/`, `waybar/`, ecc.

```text
stow/niri/.config/niri        -> ../../../niri
stow/waybar/.config/waybar    -> ../../../waybar
stow/kitty/.config/kitty      -> ../../../kitty
stow/fuzzel/.config/fuzzel    -> ../../../fuzzel
stow/dunst/.config/dunst      -> ../../../dunst
stow/swaylock/.config/swaylock-> ../../../swaylock
stow/conky/.config/conky      -> ../../../conky
stow/matugen/.config/matugen  -> ../../../matugen
stow/nvim/.config/nvim        -> ../../../nvim
stow/bash/.bashrc             -> ../../arch/.bashrc

```

## Uso

Installa stow:

```bash
sudo apt install stow      # Debian/Ubuntu
sudo pacman -S stow        # Arch

```

Crea i symlink in `$HOME` (esegui dalla radice del repo):

```bash
stow --dir=stow --target="$HOME" niri waybar kitty fuzzel dunst swaylock conky matugen nvim bash

```

Stow creerà p.es. `~/.config/niri -> ~/dotfiles/myconfig/stow/niri/.config/niri -> ~/dotfiles/myconfig/niri`.
Da quel momento modifichi i file direttamente nel repo e sono già attivi: niente
passo di sincronizzazione.

Per rimuovere i link:

```bash
stow --dir=stow --target="$HOME" -D niri waybar ...

```

Per vedere cosa farebbe senza toccare nulla, aggiungi `-n -v`.

## Note

* Se `~/.config/<app>` esiste già come cartella reale, spostala/eliminala prima di
fare stow (altrimenti stow rifiuta per non sovrascrivere).
* I file `README.md`/`*.bak` presenti nelle cartelle vengono linkati anch'essi in
`~/.config/<app>`: sono innocui, le app li ignorano.
* Path fuori da `$HOME` (`/etc/...`) non sono gestiti da Stow: i file di sistema
Arch sono in `arch/etc/` e si installano **per copia** con
`sudo bash arch/install-system.sh` (anteprima: `bash arch/install-system.sh -n`).
Niente symlink in `/etc`: thinkfan, udev e systemd girano come root, e un link
verso un file scrivibile dall'utente darebbe root a quell'utente.
* `ly/` (display manager) segue lo stesso schema: cartella canonica `ly/`, link
`arch/etc/ly -> ../../ly`, installata per copia in `/etc/ly`. Il link sarebbe
pericoloso: ly esegue come root `setup_cmd`, `start_cmd`, `shutdown_cmd`.
* Su `orion` (Arch) lo stow è attivo dal 2026-10-23.

```
