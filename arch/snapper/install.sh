#!/usr/bin/env bash
# Applica le config snapper versionate e installa il timer "ogni 3 giorni".
# Uso: sudo bash arch/snapper/install.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

# 1. Config: ogni KEY="VAL" di configs/<nome> -> snapper set-config
for f in configs/*; do
    cfg=$(basename "$f")
    mapfile -t kv < <(grep -E '^[A-Z_]+=' "$f" | grep -vE '^(SUBVOLUME|FSTYPE)=' | sed 's/"//g')
    snapper -c "$cfg" set-config "${kv[@]}"
    echo "config $cfg aggiornata (${#kv[@]} chiavi)"
done

# 2. Script + unità systemd (copia, non symlink: girano come root)
install -m 755 snapper-3giorni /usr/local/bin/snapper-3giorni
install -m 644 snapper-3giorni.service snapper-3giorni.timer /etc/systemd/system/
systemctl daemon-reload

# 3. Timer: il nostro al posto di quello orario di snapper
systemctl disable --now snapper-timeline.timer
systemctl enable --now snapper-3giorni.timer
systemctl start snapper-3giorni.service    # primo snapshot subito se manca
systemctl status snapper-3giorni.service --no-pager | tail -4
