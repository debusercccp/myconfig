#!/bin/sh

export WLR_DRM_DEVICES=/dev/dri/card0
export AQ_DRM_DEVICES=/dev/dri/card0
export EGL_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1
export XDG_SESSION_TYPE=wayland
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json

clear

exec niri-session
