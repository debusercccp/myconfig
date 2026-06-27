#!/usr/bin/env python3
"""Menu Bluetooth completo in fuzzel: connessi, abbinati, vicini, impostazioni."""

import subprocess
import time


def bt(args, stdin=None, timeout=8):
    r = subprocess.run(
        ["bluetoothctl"] + args,
        input=stdin,
        capture_output=True,
        text=True,
        timeout=timeout,
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
    trusted = set()
    for mac in all_devs:
        info = bt(["info", mac])
        if any("Trusted: yes" in line for line in info.splitlines()):
            trusted.add(mac)
    return all_devs, paired, connected, trusted


def is_discoverable():
    for line in bt(["show"]).splitlines():
        if "Discoverable:" in line:
            return "yes" in line
    return False


def fuzzel_pick(items, prompt="Bluetooth  "):
    r = subprocess.run(
        [
            "fuzzel",
            "--dmenu",
            "--prompt",
            prompt,
            "--width",
            "44",
            "--lines",
            str(len(items)),
        ],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    return r.stdout.strip()


def device_submenu(mac, name, kind, trusted):
    """Sottomenu per un dispositivo specifico. Ritorna True se tornare al menu principale."""
    options = [f"  {name}"]  # intestazione non azione
    if kind == "connected":
        options += ["  Disconnetti", "  Rimuovi dispositivo"]
    elif kind == "paired":
        options += ["  Connetti", "  Rimuovi dispositivo"]
    elif kind == "nearby":
        options += ["  Abbina"]

    is_trusted = mac in trusted
    options.append("  Rimuovi dai fidati" if is_trusted else "  Segna come fidato")
    options.append("← Torna indietro")

    choice = fuzzel_pick(options, prompt=f"{name}  ")

    if not choice or choice == "← Torna indietro" or choice == f"  {name}":
        return True  # torna al menu principale

    if choice == "  Disconnetti":
        notify(f"Disconnessione da {name}…")
        bt(["disconnect", mac], timeout=12)

    elif choice == "  Connetti":
        notify(f"Connessione a {name}…")
        r = bt(["connect", mac], timeout=15)
        if "Failed" in r or "not available" in r:
            notify(f"Errore: impossibile connettersi a {name}")
        else:
            notify(f"Connesso a {name}")

    elif choice == "  Abbina":
        notify(f"Abbinamento con {name}…")
        r = bt(["pair", mac], stdin="yes\n", timeout=20)
        if "Failed" in r or "not available" in r:
            notify(f"Errore: abbinamento con {name} fallito")
        else:
            notify(f"Abbinato a {name}")
            bt(["trust", mac])
            bt(["connect", mac], timeout=10)

    elif choice == "  Rimuovi dispositivo":
        bt(["remove", mac])
        notify(f"{name} rimosso")

    elif choice == "  Segna come fidato":
        bt(["trust", mac])
        notify(f"{name} segnato come fidato")

    elif choice == "  Rimuovi dai fidati":
        bt(["untrust", mac])
        notify(f"{name} rimosso dai fidati")

    return False


def main():
    if not is_powered():
        choice = fuzzel_pick(["  Attiva Bluetooth"])
        if choice:
            bt(["power", "on"])
            notify("Bluetooth attivato")
        return

    # Scan breve per trovare dispositivi vicini
    subprocess.Popen(
        ["bluetoothctl", "--timeout", "12", "scan", "on"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(2)

    all_devs, paired, connected, trusted = get_state()

    connected_devs = {m: n for m, n in all_devs.items() if m in connected}
    paired_only = {
        m: n for m, n in all_devs.items() if m in paired and m not in connected
    }
    nearby = {m: n for m, n in all_devs.items() if m not in paired}

    lines = []
    actions = {}  # riga → (kind, mac, name)

    def add_section(label, devs, kind):
        if not devs:
            return
        lines.append(f"── {label} ──")
        for mac, name in devs.items():
            icon = {"connected": "󰂱", "paired": "󰂯", "nearby": "󰆢"}[kind]
            hint = {"connected": "connesso", "paired": "abbinato", "nearby": "vicino"}[
                kind
            ]
            star = "  ★" if mac in trusted else ""
            entry = f"{icon}  {name}  ·  {hint}{star}"
            lines.append(entry)
            actions[entry] = (kind, mac, name)

    add_section("Connessi", connected_devs, "connected")
    add_section("Abbinati", paired_only, "paired")
    add_section("Vicini", nearby, "nearby")

    disc = is_discoverable()
    lines += [
        "──────────────────────────────",
        "󰂲  Disattiva Bluetooth",
        "󰤷  Smetti di essere scopribile" if disc else "󰤴  Rendi scopribile",
        "󰑐  Aggiorna lista",
    ]

    choice = fuzzel_pick(lines)
    if not choice:
        return

    if choice == "󰂲  Disattiva Bluetooth":
        bt(["power", "off"])
        notify("Bluetooth disattivato")
        return

    if choice in ("󰤷  Smetti di essere scopribile", "󰤴  Rendi scopribile"):
        bt(["discoverable", "off" if disc else "on"])
        return

    if choice == "󰑐  Aggiorna lista":
        main()
        return

    action = actions.get(choice)
    if not action:
        return

    kind, mac, name = action
    back = device_submenu(mac, name, kind, trusted)
    if back:
        main()


if __name__ == "__main__":
    main()
