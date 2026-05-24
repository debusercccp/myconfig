#!/usr/bin/env python3
"""
pwsearch.py — cerca nel CSV delle password su servizio, username, password o fonte.
Uso: python3 pwsearch.py <query> [--top N]
"""

import csv
import sys
import os
import argparse

CSV_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
)

# Colori ANSI
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
WHITE = "\033[97m"
BLUE = "\033[94m"
MAGENTA = "\033[95m"

FONTE_COLOR = {
    "Firefox": "\033[38;5;208m",  # arancione
    "Google": "\033[92m",  # verde
    "WhatsApp": "\033[38;5;40m",  # verde scuro
}


def highlight(text, query):
    """Evidenzia la query nel testo (case-insensitive)."""
    if not query or not text:
        return text
    lower_t = text.lower()
    lower_q = query.lower()
    result = ""
    i = 0
    while i < len(text):
        pos = lower_t.find(lower_q, i)
        if pos == -1:
            result += text[i:]
            break
        result += text[i:pos]
        result += f"{BOLD}{RED}{text[pos : pos + len(query)]}{RESET}"
        i = pos + len(query)
    return result


def load_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def search(rows, query):
    q = query.lower()
    results = []
    for row in rows:
        if any(q in v.lower() for v in row.values() if v):
            results.append(row)
    return results


def print_result(row, query, index):
    fonte = row.get("fonte", "")
    fc = FONTE_COLOR.get(fonte, WHITE)

    servizio = highlight(row.get("servizio", ""), query)
    username = highlight(row.get("username", ""), query)
    password = highlight(row.get("password", ""), query)
    fonte_str = highlight(fonte, query)

    # Box header
    print(
        f"\n  {BOLD}{WHITE}#{index:02d}{RESET}  {BOLD}{CYAN}{servizio}{RESET}  {DIM}[{fc}{fonte_str}{RESET}{DIM}]{RESET}"
    )
    print(f"       {DIM}user :{RESET}  {WHITE}{username if username else '—'}{RESET}")
    print(f"       {DIM}pass :{RESET}  {YELLOW}{password if password else '—'}{RESET}")


def main():
    parser = argparse.ArgumentParser(
        description="Cerca nel vault delle password.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Esempi:\n  python3 pwsearch.py spotify\n  python3 pwsearch.py gmail --top 3\n  python3 pwsearch.py Disintegration03",
    )
    parser.add_argument(
        "query", help="Testo da cercare (servizio, username, password o fonte)"
    )
    parser.add_argument(
        "--top",
        type=int,
        default=5,
        metavar="N",
        help="Mostra i primi N risultati (default: 5)",
    )
    parser.add_argument(
        "--all", action="store_true", help="Mostra tutti i risultati senza limite"
    )
    args = parser.parse_args()

    if not os.path.exists(CSV_PATH):
        print(f"{RED}Errore: file non trovato → {CSV_PATH}{RESET}")
        sys.exit(1)

    rows = load_csv(CSV_PATH)
    results = search(rows, args.query)

    total = len(results)
    limit = total if args.all else args.top

    # Header
    print(
        f"\n{BOLD}{WHITE}  🔍 '{args.query}'{RESET}  —  {GREEN}{total}{RESET} risultat{'o' if total == 1 else 'i'}",
        end="",
    )
    if not args.all and total > limit:
        print(f"  {DIM}(mostro i primi {limit}, usa --all per tutti){RESET}", end="")
    print()
    print(f"  {DIM}{'─' * 52}{RESET}")

    if not results:
        print(f"\n  {DIM}Nessuna corrispondenza trovata.{RESET}\n")
        return

    for i, row in enumerate(results[:limit], 1):
        print_result(row, args.query, i)

    print(f"\n  {DIM}{'─' * 52}{RESET}\n")


if __name__ == "__main__":
    main()
