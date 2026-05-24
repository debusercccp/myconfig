#!/usr/bin/env python3

import json
import time
from datetime import datetime
import requests

WEATHER_CODES = {
    "113": "",
    "116": "",
    "119": "",
    "122": "",
    "143": "",
    "176": "󰼳",
    "179": "󰼴",
    "182": "󰼵",
    "185": "󰖗",
    "200": "",
    "227": "",
    "230": "",
    "248": "",
    "260": "",
    "263": "",
    "266": "",
    "281": "",
    "284": "",
    "293": "󰖗",
    "296": "󰖗",
    "299": "",
    "302": "",
    "305": "",
    "308": "",
    "311": "",
    "314": "",
    "317": "",
    "320": "",
    "323": "",
    "326": "",
    "329": "",
    "332": "",
    "335": "",
    "338": "",
    "350": "󰼩",
    "353": "",
    "356": "",
    "359": "",
    "362": "",
    "365": "",
    "368": "󰖘",
    "371": "",
    "374": "",
    "377": "",
    "386": "",
    "389": "",
    "392": "",
    "395": "",
}

data = {}

# Tentativi di connessione all'avvio (gestisce la race condition della rete)
weather = None
for _ in range(5):
    try:
        response = requests.get("https://wttr.in/Bari?format=j1", timeout=5)
        if response.status_code == 200:
            weather = response.json()
            # Verifica strutturale minima per evitare KeyError successivi
            if "current_condition" in weather and "weather" in weather:
                break
    except Exception:
        pass
    time.sleep(2)

# Se dopo 5 tentativi fallisce, restituisce l'output di errore senza crashare
if not weather:
    data["text"] = "󰖪 --°"
    data["tooltip"] = "Impossibile connettersi a wttr.in (Rete non disponibile)"
    print(json.dumps(data))
    exit(0)  # Evita di stampare lo stacktrace in Waybar


def format_time(time_str):
    # wttr.in restituisce i tempi come "0", "300", "1200", etc.
    return time_str.replace("00", "").zfill(2)


def format_temp(temp):
    return (str(temp) + "°").ljust(3)


def format_chances(hour_data):
    chances = {
        "chanceoffog": "Nebbia",
        "chanceoffrost": "Ghiaccio",
        "chanceofovercast": "Nuvoloso",
        "chanceofrain": "Pioggia",
        "chanceofsnow": "Neve",
        "chanceofsunshine": "Soleggiato",
        "chanceofthunder": "Fulmini",
        "chanceofwindy": "Vento",
    }

    conditions = []
    for event, label in chances.items():
        if event in hour_data and int(hour_data[event]) > 0:
            conditions.append(f"{label} {hour_data[event]}%")
    return ", ".join(conditions)


current = weather["current_condition"][0]
tempint = int(current["FeelsLikeC"])
extrachar = ""

if 0 < tempint < 10:
    extrachar = "+"

# Output principale sulla barra di Waybar
data["text"] = (
    f"{WEATHER_CODES.get(current['weatherCode'], '')} {extrachar}{current['FeelsLikeC']}°"
)

# Tooltip (Finestra pop-up al passaggio del mouse)
data["tooltip"] = f"<b>{current['weatherDesc'][0]['value']} {current['temp_C']}°</b>\n"
data["tooltip"] += f"Percepiti: {current['FeelsLikeC']}°\n"
data["tooltip"] += f"Vento: {current['windspeedKmph']} Km/h\n"
data["tooltip"] += f"Umidità: {current['humidity']}%\n"

for i, day in enumerate(weather["weather"]):
    data["tooltip"] += "\n<b>"
    if i == 0:
        data["tooltip"] += "Oggi, "
    elif i == 1:
        data["tooltip"] += "Domani, "

    data["tooltip"] += f"{day['date']}</b>\n"
    data["tooltip"] += f" {day['maxtempC']}°  {day['mintempC']}° "
    data["tooltip"] += (
        f" {day['astronomy'][0]['sunrise']}  {day['astronomy'][0]['sunset']}\n"
    )

    # Corretto: wttr.in usa la "h" minuscola ('hourly')
    hourly_data = day.get("hourly", day.get("Hourly", []))

    for hour in hourly_data:
        # Corretto: la chiave corretta nel JSON standard di wttr.in è 'time', non 'Tempo'
        raw_time = hour.get("time", hour.get("Tempo", "0"))
        hour_time = int(format_time(raw_time))

        if i == 0 and hour_time < datetime.now().hour - 2:
            continue

        data["tooltip"] += (
            f"{str(hour_time).zfill(2)}:00 {WEATHER_CODES.get(hour['weatherCode'], '')} "
            f"{format_temp(hour['FeelsLikeC'])} {hour['weatherDesc'][0]['value']}"
        )

        chances_str = format_chances(hour)
        if chances_str:
            data["tooltip"] += f", {chances_str}\n"
        else:
            data["tooltip"] += "\n"

print(json.dumps(data))
