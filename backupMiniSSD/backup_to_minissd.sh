#!/bin/bash

# --- Configurazione ---
MOUNT_POINT="$HOME/MiniSSD"
DEST="$MOUNT_POINT/Backup_Sistema"
SOURCES=("$HOME/Programmi" "$HOME/.bashrc" "$HOME/.config/kitty" "$HOME/.config/nvim" "$HOME/librerie" "$HOME/modelli" "$HOME/datasets")
IGNORE_FILE="$HOME/backupMiniSSD/.backup_ignore"

# --- 1. Controllo se il MiniSSD è collegato ---
if ! mountpoint -q "$MOUNT_POINT"; then
    echo " ERRORE: Il MiniSSD non è montato su $MOUNT_POINT."
    echo "Inserisci il disco e riprova."
    exit 1
fi

echo " MiniSSD rilevato. Preparazione backup..."

# --- 2. Salvataggio dipendenze Python (se esiste .venv) ---
VENV_PATH="$HOME/Programmi/.venv"
if [ -d "$VENV_PATH" ]; then
    echo " Generazione requirements.txt dalle dipendenze attuali..."
    # Usiamo il binario pip interno al venv per essere sicuri di leggere i pacchetti giusti
    "$VENV_PATH/bin/pip" freeze > "$HOME/Programmi/requirements.txt" 2>/dev/null
fi

# --- 3. Esecuzione Backup ---
mkdir -p "$DEST"
echo " Inizio sincronizzazione su $DEST..."

for item in "${SOURCES[@]}"; do
    if [ -e "$item" ]; then
        echo "Copia di: $item..."
        rsync -av --delete --exclude-from="$IGNORE_FILE" "$item" "$DEST"
    else
        echo "Avviso: $item non trovato, salto..."
    fi
done

echo "------------------------------------------"
echo " Backup completato con successo!"
