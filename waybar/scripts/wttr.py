#!/usr/bin/env python3

import json
import os
import time
from datetime import datetime
import requests

LOCATION = "Bari"
CACHE_DETAIL = os.path.expanduser("~/.cache/waybar-weather-detail.txt")

ICONS = {
    "113": "",
    "116": "",
    "119": "",
    "122": "",
    "143": "",
    "176": "󰼳",
    "179": "󰼴",
    "182": "󰼵",
    "185": "󰖗",
    "200": "",
    "227": "",
    "230": "",
    "248": "",
    "260": "",
    "263": "",
    "266": "",
    "281": "",
    "284": "",
    "293": "󰖗",
    "296": "󰖗",
    "299": "",
    "302": "",
    "305": "",
    "308": "",
    "311": "",
    "314": "",
    "317": "",
    "320": "",
    "323": "",
    "326": "",
    "329": "",
    "332": "",
    "335": "",
    "338": "",
    "350": "󰼩",
    "353": "",
    "356": "",
    "359": "",
    "362": "",
    "365": "",
    "368": "󰖘",
    "371": "",
    "374": "",
    "377": "",
    "386": "",
    "389": "",
    "392": "",
    "395": "",
}

CHANCES = {
    "chanceofrain": "Pioggia",
    "chanceofsnow": "Neve",
    "chanceofthunder": "Fulmini",
    "chanceoffog": "Nebbia",
    "chanceofovercast": "Nuvoloso",
    "chanceofsunshine": "Soleggiato",
    "chanceofwindy": "Vento",
    "chanceoffrost": "Ghiaccio",
}


def fetch_weather():
    for _ in range(5):
        try:
            r = requests.get(f"https://wttr.in/{LOCATION}?format=j1", timeout=5)
            if r.status_code == 200:
                data = r.json()
                if "current_condition" in data and "weather" in data:
                    return data
        except Exception:
            pass
        time.sleep(2)
    return None


def hour_of(time_str):
    return int(time_str) // 100


def chances_str(hour):
    parts = [
        f"{label} {hour[key]}%"
        for key, label in CHANCES.items()
        if int(hour.get(key, 0)) > 0
    ]
    return "  ·  ".join(parts)


def build_detail(weather):
    """Testo plain (senza HTML) per il popup fuzzel al click."""
    cur = weather["current_condition"][0]
    icon = ICONS.get(cur["weatherCode"], "")
    lines = [
        f"{icon}  {cur['weatherDesc'][0]['value']}  {cur['temp_C']}°  (percepiti {cur['FeelsLikeC']}°)",
        f"   Vento {cur['windspeedKmph']} km/h  ·  Umidità {cur['humidity']}%",
    ]

    now = datetime.now().hour
    for i, day in enumerate(weather["weather"]):
        label = ["Oggi", "Domani"][i] if i < 2 else ""
        astro = day["astronomy"][0]
        header = f"{label}  {day['date']}" if label else day["date"]
        lines += [
            "",
            f"  {header}   ▲ {day['maxtempC']}°  ▼ {day['mintempC']}°"
            f"     {astro['sunrise']}     {astro['sunset']}",
        ]
        for hour in day.get("hourly", []):
            h = hour_of(hour.get("time", "0"))
            if i == 0 and h < now - 2:
                continue
            h_icon = ICONS.get(hour["weatherCode"], "")
            desc = hour["weatherDesc"][0]["value"]
            extra = chances_str(hour)
            suffix = f"  ·  {extra}" if extra else ""
            lines.append(
                f"  {h:02d}:00  {h_icon}  {hour['FeelsLikeC']}°  {desc}{suffix}"
            )

    return "\n".join(lines)


weather = fetch_weather()

if not weather:
    print(
        json.dumps(
            {
                "text": "󰖪 --°",
                "tooltip": "Impossibile connettersi a wttr.in",
            }
        )
    )
    raise SystemExit(0)

cur = weather["current_condition"][0]
icon = ICONS.get(cur["weatherCode"], "")

detail = build_detail(weather)
os.makedirs(os.path.dirname(CACHE_DETAIL), exist_ok=True)
with open(CACHE_DETAIL, "w") as f:
    f.write(detail)

print(
    json.dumps(
        {
            "text": f"{icon} {cur['FeelsLikeC']}°",
            "tooltip": f"{icon} {cur['weatherDesc'][0]['value']}  {cur['temp_C']}°"
            f"  ·  vento {cur['windspeedKmph']} km/h  ·  umidità {cur['humidity']}%",
        }
    )
)
