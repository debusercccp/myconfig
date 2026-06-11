# Stow layout (opzionale)

Layout alternativo per gestire i dotfile con [GNU Stow](https://www.gnu.org/software/stow/)
usando **symlink** invece della copia (`sync_config.sh` / `restore_config.sh`).

Questo è **additivo**: i vecchi script di copia restano e continuano a funzionare.
Puoi passare a Stow quando vuoi, senza fretta.

## Come funziona

Ogni pacchetto qui dentro rispecchia la struttura di `$HOME`. I file _non sono
duplicati_: ogni pacchetto è un symlink alla cartella canonica in cima al repo,
quindi la singola fonte di verità resta `niri/`, `waybar-niri/`, ecc.

```
stow/niri/.config/niri        -> ../../../niri
stow/waybar/.config/waybar    -> ../../../waybar-niri   (rinominato in waybar)
stow/kitty/.config/kitty      -> ../../../kitty
stow/fuzzel/.config/fuzzel    -> ../../../fuzzel
stow/dunst/.config/dunst      -> ../../../dunst
stow/swaylock/.config/swaylock-> ../../../swaylock
stow/conky/.config/conky      -> ../../../conky
stow/starship/.config/starship.toml -> ../../../starship/starship.toml
```

## Uso

Installa stow:

```bash
sudo apt install stow      # Debian/Ubuntu
sudo pacman -S stow        # Arch
```

Crea i symlink in `$HOME` (esegui dalla radice del repo):

```bash
stow --dir=stow --target="$HOME" niri waybar kitty fuzzel dunst swaylock conky starship
```

Stow creerà p.es. `~/.config/niri -> ~/myconfig/stow/niri/.config/niri -> ~/myconfig/niri`.
Da quel momento modifichi i file direttamente nel repo e sono già attivi: niente
passo di sincronizzazione.

Per rimuovere i link:

```bash
stow --dir=stow --target="$HOME" -D niri waybar ...
```

Per vedere cosa farebbe senza toccare nulla, aggiungi `-n -v`.

## Note

- Se `~/.config/<app>` esiste già come cartella reale, spostala/eliminala prima di
  fare stow (altrimenti stow rifiuta per non sovrascrivere).
- I file `README.md`/`*.bak` presenti nelle cartelle vengono linkati anch'essi in
  `~/.config/<app>`: sono innocui, le app li ignorano.
- Path fuori da `$HOME` (`/usr/local/bin`, `/etc/...`, kernel) non sono gestiti da
  Stow: restano coperti dagli script esistenti.
