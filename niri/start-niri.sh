#!/bin/sh

# Forza il compositor a usare SOLO la GPU Intel
export WLR_DRM_DEVICES=/dev/dri/card0
export AQ_DRM_DEVICES=/dev/dri/card0
export EGL_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1
export XDG_SESSION_TYPE=wayland

# ISOLAMENTO CRITICO: Forza EGL a usare solo Mesa/Intel, 
# impedendo a Niri di interrogare o svegliare la Quadro.
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json

clear

# Avvia la tua build custom di Niri
exec /home/noya/bin/niri/target/release/niri
