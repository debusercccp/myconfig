#!/usr/bin/env bash
# Installa in /etc i file di sistema versionati in arch/etc/.
# Copia (non symlink): thinkfan, udev e systemd girano come root, un link verso
# un file scrivibile dall'utente equivarrebbe a dare root a quell'utente.
#
# Uso: sudo bash arch/install-system.sh [-n]   (-n = mostra solo le differenze)

set -euo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/etc"
DRY=0; [[ ${1:-} == "-n" ]] && DRY=1
[[ $DRY -eq 1 || $EUID -eq 0 ]] || { echo "Esegui con sudo (oppure -n per l'anteprima)"; exit 1; }

# snapper: le config sono gestite da 'snapper create-config', non sovrascriverle
EXCLUDE='^snapper/'

changed=()
while IFS= read -r rel; do
    [[ $rel =~ $EXCLUDE ]] && continue
    dst="/etc/$rel"
    if [[ -f $dst ]] && cmp -s "$SRC/$rel" "$dst"; then continue; fi
    changed+=("$rel")
    echo -e "\e[1;33m==> $dst\e[0m"
    diff -u "$dst" "$SRC/$rel" 2>/dev/null | tail -n +3 || echo "(nuovo file)"
done < <(cd "$SRC" && find . -type f -printf '%P\n' | sort)

[[ ${#changed[@]} -eq 0 ]] && { echo "Tutto già allineato."; exit 0; }
[[ $DRY -eq 1 ]] && exit 0

read -rp "Installare ${#changed[@]} file? [s/N] " ok
[[ $ok == [sSyY] ]] || exit 1

for rel in "${changed[@]}"; do
    [[ -f /etc/$rel ]] && cp -p "/etc/$rel" "/etc/$rel.pre-dotfiles"
    install -D -m 644 -o root -g root "$SRC/$rel" "/etc/$rel"
    echo " installato /etc/$rel"
done

# Ricarica solo ciò che è stato toccato
printf '%s\n' "${changed[@]}" | grep -q '^systemd/' && systemctl daemon-reload
printf '%s\n' "${changed[@]}" | grep -q '^udev/' && udevadm control --reload
printf '%s\n' "${changed[@]}" | grep -q '^thinkfan.yaml$\|thinkfan.service' && systemctl restart thinkfan.service
printf '%s\n' "${changed[@]}" | grep -q '^mkinitcpio.conf$\|^modprobe.d/' && mkinitcpio -P
printf '%s\n' "${changed[@]}" | grep -q '^modprobe.d/' && echo "modprobe.d cambiato: serve un riavvio"
exit 0
