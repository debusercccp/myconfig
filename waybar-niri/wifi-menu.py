#!/usr/bin/env python3
"""Menu WiFi con fuzzel per waybar – usa wpa_cli via sudo."""

import subprocess
import sys
import time


WPA = ["sudo", "wpa_cli", "-p", "/run/wpa_supplicant", "-i", "wlp4s0"]


def wpa_run(args):
    return subprocess.run(WPA + args, capture_output=True, text=True)


def notify(msg):
    subprocess.run(["notify-send", "Wi-Fi", msg], check=False)


def wait_connected(ssid, timeout=15):
    for _ in range(timeout):
        r = wpa_run(["status"])
        state, connected_ssid = "", ""
        for line in r.stdout.splitlines():
            if line.startswith("wpa_state="):
                state = line.split("=", 1)[1]
            if line.startswith("ssid="):
                connected_ssid = line.split("=", 1)[1]
        if state == "COMPLETED" and connected_ssid == ssid:
            return True
        time.sleep(1)
    return False


def get_current_ssid():
    r = wpa_run(["status"])
    for line in r.stdout.splitlines():
        if line.startswith("ssid="):
            return line.split("=", 1)[1]
    return None


def get_known_networks():
    """Returns {ssid: network_id} for all saved networks."""
    r = wpa_run(["list_networks"])
    known = {}
    for line in r.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2 and parts[0].isdigit():
            known[parts[1]] = parts[0]
    return known


def scan_networks():
    """Returns list of unique networks sorted by signal."""
    wpa_run(["scan"])
    time.sleep(1.5)
    r = wpa_run(["scan_results"])
    if r.returncode != 0:
        return None, r.stderr.strip()

    networks = []
    seen = set()
    for line in r.stdout.splitlines():
        if line.startswith("bssid") or not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        _bssid, _freq, sig_dbm, flags, ssid = (
            parts[0],
            parts[1],
            parts[2],
            parts[3],
            "\t".join(parts[4:]),
        )
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
        try:
            sig_pct = max(0, min(100, 2 * (int(sig_dbm) + 100)))
        except ValueError:
            sig_pct = 0
        networks.append(
            {
                "ssid": ssid,
                "signal": sig_pct,
                "secured": "[WPA" in flags or "[WEP" in flags,
            }
        )

    return networks, None


def format_line(n, current_ssid):
    marker = "●" if n["ssid"] == current_ssid else "○"
    sig = n["signal"]
    bars = (
        "▂▄▆█"
        if sig >= 75
        else "▂▄▆_"
        if sig >= 50
        else "▂▄__"
        if sig >= 25
        else "▂___"
    )
    lock = " 󰌾" if n["secured"] else ""
    return f"{marker} {n['ssid']}  {bars} {sig}%{lock}"


def fuzzel_pick(items, prompt="Wi-Fi  "):
    r = subprocess.run(
        [
            "fuzzel",
            "--dmenu",
            "--prompt",
            prompt,
            "--width",
            "40",
            "--lines",
            str(len(items)),
        ],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    return r.stdout.strip()


def ask_password(ssid):
    r = subprocess.run(
        [
            "fuzzel",
            "--dmenu",
            "--prompt",
            f"Password per {ssid}:  ",
            "--width",
            "40",
            "--lines",
            "0",
            "--password",
        ],
        capture_output=True,
        text=True,
    )
    return r.stdout.strip()


def main():
    networks, err = scan_networks()

    if networks is None:
        notify(f"Errore wpa_cli:\n{err}\n\nVerifica /etc/sudoers.d/wifi-menu")
        sys.exit(1)

    if not networks:
        notify("Nessuna rete trovata")
        sys.exit(1)

    current_ssid = get_current_ssid()
    known = get_known_networks()

    networks.sort(key=lambda n: (-(n["ssid"] == current_ssid), -n["signal"]))
    display_lines = [format_line(n, current_ssid) for n in networks]

    result = subprocess.run(
        ["fuzzel", "--dmenu", "--prompt", "Wi-Fi  ", "--width", "40", "--lines", "12"],
        input="\n".join(display_lines),
        capture_output=True,
        text=True,
    )

    choice = result.stdout.strip()
    if not choice:
        sys.exit(0)

    selected = next(
        (networks[i] for i, line in enumerate(display_lines) if line == choice), None
    )
    if not selected:
        sys.exit(0)

    ssid = selected["ssid"]
    secured = selected["secured"]

    if ssid in known:
        net_id = known[ssid]
        if secured:
            action = fuzzel_pick(
                [f"  Connetti a «{ssid}»", f"  Nuova password per «{ssid}»..."],
                prompt="Wi-Fi  ",
            )
            if not action:
                sys.exit(0)
            if "Nuova password" in action:
                pwd = ask_password(ssid)
                if not pwd:
                    sys.exit(0)
                wpa_run(["set_network", net_id, "psk", f'"{pwd}"'])
                wpa_run(["save_config"])
        # Connetti con configurazione salvata
        notify(f'Connessione a "{ssid}"…')
        wpa_run(["select_network", net_id])
        if wait_connected(ssid):
            notify(f'Connesso a "{ssid}"')
        else:
            notify(f'Impossibile connettersi a "{ssid}"')
    else:
        # Rete nuova
        if secured:
            pwd = ask_password(ssid)
            if not pwd:
                sys.exit(0)
        else:
            pwd = None

        r = wpa_run(["add_network"])
        net_id = r.stdout.strip().splitlines()[-1]
        if not net_id.isdigit():
            notify("Errore nell'aggiunta della rete")
            sys.exit(1)

        wpa_run(["set_network", net_id, "ssid", f'"{ssid}"'])
        if pwd:
            wpa_run(["set_network", net_id, "psk", f'"{pwd}"'])
        else:
            wpa_run(["set_network", net_id, "key_mgmt", "NONE"])

        r = wpa_run(["enable_network", net_id])
        if r.returncode == 0:
            notify(f'Connessione a "{ssid}"…')
            if wait_connected(ssid):
                notify(f'Connesso a "{ssid}"')
                wpa_run(["save_config"])
            else:
                notify(f'Impossibile connettersi a "{ssid}" (password errata?)')
                wpa_run(["remove_network", net_id])
        else:
            notify(f'Errore connessione a "{ssid}"')
            wpa_run(["remove_network", net_id])


if __name__ == "__main__":
    main()
