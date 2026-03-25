#!/bin/bash

# Percorsi
SOURCES=("$HOME/Programmi" "$HOME/.bashrc" "$HOME/.config/kitty" "$HOME/.config/nvim" "$HOME/neural-lib")
DEST="$HOME/MiniSSD/Backup_Sistema"
IGNORE_FILE="$HOME/backupMiniSSD/.backup_ignore"

if [ -d "$HOME/Programmi/.venv" ]; then
    echo "Generazione requirements.txt per l'ambiente virtuale..."
    $HOME/Programmi/.venv/bin/pip freeze > $HOME/Programmi/requirements.txt
fi

# Crea la cartella di destinazione se non esiste
mkdir -p "$DEST"

echo "Inizio backup su MiniSSD..."

for item in "${SOURCES[@]}"; do
    # -a: archivio, -v: verbose, --delete: sincronizza eliminazioni
    rsync -av --delete --exclude-from="$IGNORE_FILE" "$item" "$DEST"
done

echo "Backup completato con successo!"
