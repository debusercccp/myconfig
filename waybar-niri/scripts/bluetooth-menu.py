#!/usr/bin/env python3
"""Menu Bluetooth con fuzzel per waybar."""

import subprocess


def bt(args, timeout=5):
    r = subprocess.run(
        ["bluetoothctl"] + args, capture_output=True, text=True, timeout=timeout
    )
    return r.stdout.strip()


def notify(msg):
    subprocess.run(["notify-send", "Bluetooth", msg], check=False)


def is_powered():
    out = bt(["show"])
    for line in out.splitlines():
        if "Powered:" in line:
            return "yes" in line
    return False


def get_devices():
    """Restituisce lista di {name, mac, connected}."""
    devices = []
    for line in bt(["devices"]).splitlines():
        parts = line.split(" ", 2)
        if len(parts) < 3:
            continue
        mac, name = parts[1], parts[2]
        info = bt(["info", mac])
        connected = any("Connected: yes" in line for line in info.splitlines())
        devices.append({"name": name, "mac": mac, "connected": connected})
    devices.sort(key=lambda d: -d["connected"])
    return devices


def fuzzel_menu(items, prompt="Bluetooth  "):
    result = subprocess.run(
        [
            "fuzzel",
            "--dmenu",
            "--prompt",
            prompt,
            "--width",
            "36",
            "--lines",
            str(len(items)),
        ],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def main():
    powered = is_powered()

    if not powered:
        choice = fuzzel_menu(["  Attiva Bluetooth"], prompt="Bluetooth  ")
        if choice:
            bt(["power", "on"])
            notify("Bluetooth attivato")
        return

    devices = get_devices()

    # Voci del menu
    toggle_line = "󰂲  Disattiva Bluetooth"
    scan_line = "󰂰  Cerca nuovi dispositivi…"
    device_lines = []
    for d in devices:
        marker = "󰂱 " if d["connected"] else "󰂯 "
        action = "(connesso)" if d["connected"] else ""
        device_lines.append(f"{marker}{d['name']}  {action}".rstrip())

    all_lines = device_lines + ["", toggle_line, scan_line]
    choice = fuzzel_menu([item for item in all_lines if item != ""])

    if not choice:
        return

    if choice == toggle_line:
        bt(["power", "off"])
        notify("Bluetooth disattivato")
        return

    if choice == scan_line:
        subprocess.Popen(
            [
                "kitty",
                "--class",
                "nmtui",
                "-e",
                "bash",
                "-c",
                "bluetoothctl scan on; read",
            ]
        )
        return

    # Dispositivo selezionato
    for i, line in enumerate(device_lines):
        if line == choice:
            d = devices[i]
            if d["connected"]:
                notify(f"Disconnessione da {d['name']}…")
                bt(["disconnect", d["mac"]], timeout=10)
            else:
                notify(f"Connessione a {d['name']}…")
                r = bt(["connect", d["mac"]], timeout=15)
                if "Failed" in r or "not available" in r:
                    notify(f"Errore: impossibile connettersi a {d['name']}")
                else:
                    notify(f"Connesso a {d['name']}")
            break


if __name__ == "__main__":
    main()
