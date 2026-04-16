#!/bin/bash

# Il percorso esatto della tua Cyber Jail
TARGET="/home/noya/MiniSSD/Cyber_Jail"

echo "--- Chiusura e Messa in Sicurezza della Cyber Jail ---"

# Elenco delle cartelle da smontare (in ordine inverso rispetto all'entrata)
dirs=(dev/pts dev sys proc)

for d in "${dirs[@]}"; do
    # Controlla se la cartella è effettivamente montata prima di agire
    if mountpoint -q "$TARGET/$d"; then
        sudo umount -l "$TARGET/$d"
        echo "[ OK ] Smontato $d"
    else
        echo "[ -- ] $d non risultava montato"
    fi
done

echo "--- Isolamento terminato. Il sistema principale è al sicuro e il MiniSSD è libero. ---"
