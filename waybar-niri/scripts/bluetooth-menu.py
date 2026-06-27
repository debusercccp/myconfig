#!/usr/bin/env python3
"""Menu Bluetooth completo con fuzzel: connessi, abbinati, vicini."""

import subprocess
import time


def bt(args, timeout=6):
    r = subprocess.run(
        ["bluetoothctl"] + args, capture_output=True, text=True, timeout=timeout
    )
    return r.stdout.strip()


def notify(msg):
    subprocess.run(["notify-send", "Bluetooth", msg], check=False)


def is_powered():
    for line in bt(["show"]).splitlines():
        if "Powered:" in line:
            return "yes" in line
    return False


def parse_devices(raw):
    """Restituisce {mac: name} da output di 'bluetoothctl devices [filter]'."""
    result = {}
    for line in raw.splitlines():
        parts = line.split(" ", 2)
        if len(parts) == 3 and parts[0] == "Device":
            result[parts[1]] = parts[2]
    return result


def get_state():
    all_devs = parse_devices(bt(["devices"]))
    paired = set(parse_devices(bt(["devices", "Paired"])).keys())
    connected = set(parse_devices(bt(["devices", "Connected"])).keys())
    return all_devs, paired, connected


def fuzzel(items, prompt="Bluetooth  "):
    visible = [item for item in items if item is not None]
    r = subprocess.run(
        [
            "fuzzel",
            "--dmenu",
            "--prompt",
            prompt,
            "--width",
            "42",
            "--lines",
            str(len(visible)),
        ],
        input="\n".join(visible),
        capture_output=True,
        text=True,
    )
    return r.stdout.strip()


def open_pair_terminal(mac, name):
    subprocess.Popen(
        [
            "kitty",
            "--app-id",
            "bt-pair",
            "-e",
            "bash",
            "-c",
            f'echo "Abbinamento con: {name}"; echo ""; '
            f'bluetoothctl pair {mac}; echo ""; '
            f'read -p "Premi Invio per chiudere…"',
        ]
    )


def main():
    if not is_powered():
        choice = fuzzel(["  Attiva Bluetooth"], prompt="Bluetooth  ")
        if choice:
            bt(["power", "on"])
            notify("Bluetooth attivato")
        return

    # Scan breve in background per trovare dispositivi vicini
    subprocess.Popen(
        ["bluetoothctl", "--timeout", "12", "scan", "on"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(2)

    all_devs, paired, connected = get_state()

    # Categorie
    connected_devs = {m: n for m, n in all_devs.items() if m in connected}
    paired_only = {
        m: n for m, n in all_devs.items() if m in paired and m not in connected
    }
    nearby = {m: n for m, n in all_devs.items() if m not in paired}

    # Costruisci voci del menu
    lines = []  # testo mostrato in fuzzel
    actions = {}  # testo → (tipo, mac)

    def add_section(label, devs, kind):
        if not devs:
            return
        lines.append(f"── {label} ──")
        for mac, name in devs.items():
            icon = {"connected": "󰂱", "paired": "󰂯", "nearby": "󰆢"}[kind]
            hint = {"connected": "connesso", "paired": "abbinato", "nearby": "vicino"}[
                kind
            ]
            entry = f"{icon}  {name}  ·  {hint}"
            lines.append(entry)
            actions[entry] = (kind, mac, name)

    add_section("Connessi", connected_devs, "connected")
    add_section("Abbinati", paired_only, "paired")
    add_section("Vicini", nearby, "nearby")

    # Separatore e azioni globali
    lines.append("──────────────────────")
    lines.append("󰂲  Disattiva Bluetooth")
    lines.append("⚙   Impostazioni (blueman)")

    choice = fuzzel(lines)
    if not choice:
        return

    if choice == "󰂲  Disattiva Bluetooth":
        bt(["power", "off"])
        notify("Bluetooth disattivato")
        return

    if choice == "⚙   Impostazioni (blueman)":
        subprocess.Popen(["blueman-manager"])
        return

    action = actions.get(choice)
    if not action:
        return  # separatore selezionato

    kind, mac, name = action

    if kind == "connected":
        notify(f"Disconnessione da {name}…")
        bt(["disconnect", mac], timeout=10)

    elif kind == "paired":
        notify(f"Connessione a {name}…")
        r = bt(["connect", mac], timeout=15)
        if "Failed" in r or "not available" in r:
            notify(f"Errore: impossibile connettersi a {name}")
        else:
            notify(f"Connesso a {name}")

    elif kind == "nearby":
        open_pair_terminal(mac, name)


if __name__ == "__main__":
    main()
