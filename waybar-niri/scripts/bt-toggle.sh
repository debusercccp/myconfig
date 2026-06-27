#!/bin/bash
if rfkill list bluetooth | grep -q "Soft blocked: yes\|Hard blocked: yes"; then
    rfkill unblock bluetooth
    sleep 1
    bluetoothctl power on
else
    bluetoothctl power off
    rfkill block bluetooth
fi
