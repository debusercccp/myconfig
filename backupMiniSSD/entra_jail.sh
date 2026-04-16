#!/bin/bash
TARGET="/home/noya/MiniSSD/Cyber_Jail"

echo "--- Preparazione Cyber Jail ---"
# Montiamo solo lo stretto indispensabile
sudo mount -t proc proc "$TARGET/proc"
sudo mount -t sysfs sys "$TARGET/sys"
sudo mount --bind /dev "$TARGET/dev"
sudo mount --bind /dev/pts "$TARGET/dev/pts"

# Copiamo la configurazione DNS per farti usare internet (e apt!)
sudo cp /etc/resolv.conf "$TARGET/etc/resolv.conf"

echo "--- Entrata nel sistema isolato ---"
sudo chroot "$TARGET" /bin/bash
