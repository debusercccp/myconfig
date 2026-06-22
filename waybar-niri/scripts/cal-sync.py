#!/usr/bin/env python3
"""Scarica uno o piu calendari Google in formato iCal (URL segreto, sola lettura),
espande gli eventi ricorrenti e salva una cache JSON usata dal TUI e dalla waybar.

Configurazione: ~/.config/waybar/calendar.conf con una o piu righe:
    ICS_URL=https://calendar.google.com/calendar/ical/.../basic.ics
(le righe vuote e quelle che iniziano con '#' sono ignorate).

La cache viene scritta in ~/.cache/waybar-calendar/events.json.
"""

import json
import os
import sys
import urllib.request
from datetime import date, datetime, time, timedelta, timezone

import icalendar
import recurring_ical_events

CONF = os.path.expanduser("~/.config/waybar/calendar.conf")
CACHE_DIR = os.path.expanduser("~/.cache/waybar-calendar")
CACHE = os.path.join(CACHE_DIR, "events.json")

# Finestra di espansione: da un mese fa a un anno avanti.
WINDOW_BACK = 31
WINDOW_FWD = 366


def read_urls():
    urls = []
    if not os.path.exists(CONF):
        return urls
    with open(CONF, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("ICS_URL="):
                line = line.split("=", 1)[1].strip()
            if line:
                urls.append(line)
    return urls


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "waybar-calendar"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def to_local_iso(value):
    """Normalizza un valore DTSTART/DTEND in (iso_string, all_day)."""
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            value = value.astimezone()  # ora locale
        return value.replace(tzinfo=None).isoformat(timespec="minutes"), False
    if isinstance(value, date):
        return value.isoformat(), True
    return str(value), False


def attendees(component):
    out = []
    raw = component.get("ATTENDEE")
    if raw is None:
        return out
    items = raw if isinstance(raw, list) else [raw]
    for att in items:
        email = str(att).replace("mailto:", "").replace("MAILTO:", "")
        status = ""
        try:
            status = att.params.get("PARTSTAT", "")
        except AttributeError:
            pass
        out.append({"email": email, "status": str(status).lower() if status else ""})
    return out


def main():
    urls = read_urls()
    if not urls:
        sys.stderr.write(
            f"Nessun ICS_URL configurato in {CONF}. "
            "Copia calendar.conf.example e inserisci l'indirizzo segreto iCal.\n"
        )
        # Scrive comunque una cache vuota cosi' la waybar non rompe.
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(CACHE, "w", encoding="utf-8") as fh:
            json.dump({"generated": datetime.now().isoformat(), "events": []}, fh)
        return 1

    start = datetime.combine(date.today() - timedelta(days=WINDOW_BACK), time.min)
    end = datetime.combine(date.today() + timedelta(days=WINDOW_FWD), time.min)

    events = []
    errors = []
    for url in urls:
        try:
            cal = icalendar.Calendar.from_ical(fetch(url))
            for comp in recurring_ical_events.of(cal).between(start, end):
                s_iso, all_day = to_local_iso(comp.get("DTSTART").dt)
                end_prop = comp.get("DTEND")
                e_iso = to_local_iso(end_prop.dt)[0] if end_prop is not None else s_iso
                events.append(
                    {
                        "start": s_iso,
                        "end": e_iso,
                        "all_day": all_day,
                        "summary": str(comp.get("SUMMARY", "(senza titolo)")),
                        "location": str(comp.get("LOCATION", "")),
                        "description": str(comp.get("DESCRIPTION", "")),
                        "attendees": attendees(comp),
                    }
                )
        except Exception as exc:  # noqa: BLE001 - riportiamo l'errore senza interrompere
            errors.append(f"{url}: {exc}")

    events.sort(key=lambda e: e["start"])

    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(CACHE, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "generated": datetime.now(timezone.utc).astimezone().isoformat(),
                "events": events,
            },
            fh,
            ensure_ascii=False,
        )

    if errors:
        sys.stderr.write("Errori durante il fetch:\n" + "\n".join(errors) + "\n")
        return 2 if not events else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
