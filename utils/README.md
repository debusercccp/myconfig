# utils

## notizie

Legge i titoli dei giornali italiani dal terminale. Scarica i feed RSS con `curl`
e li mostra in `fzf`, con tasti in stile vim.

### Dipendenze

- `bash`, `curl`, `fzf`
- `~/bin/notizie-feed`: converte un feed RSS (da stdin) in righe
  `giornale<TAB>titolo<TAB>link<TAB>descrizione`
- `~/bin/notizie-leggi URL`: apre l'articolo nel terminale
- `xdg-open` per aprire il link nel browser (opzionale)
- `wl-copy` (Wayland) o `xclip` (X11) per copiare il link (opzionale)

`notizie-feed` e `notizie-leggi` non sono in questo repo. Se mancano, usa
[`notyzie`](notyzie): è lo stesso programma in un file solo, con il parser dei
feed e il lettore degli articoli scritti in Python (serve anche `python3` e `less`).

### Installazione

```bash
cp utils/notizie ~/bin/
chmod +x ~/bin/notizie
```

`~/bin` deve essere nel `PATH`.

### Uso

```bash
notizie
```

1. Scegli uno o più giornali (`TAB` per selezionarne più di uno) e conferma con `l` o `INVIO`.
2. I feed vengono scaricati in parallelo e compare la lista delle notizie, con
   titolo, descrizione e link nell'anteprima in basso.
3. Apri una notizia con `l` o `INVIO`. Con `:q` torni alla lista, poi ai giornali;
   con `:qa` esci.

### Tasti

Si parte in modalità normale, come in vim. Il prompt indica la modalità.

| Modalità | Prompt | Tasto | Azione |
|---|---|---|---|
| normale | `> ` | `j` / `k` | giù / su |
| | | `g` / `G` | inizio / fine lista |
| | | `l`, `INVIO` | conferma i giornali / apri la notizia |
| | | `o` | apri la notizia nel browser |
| | | `y` | copia il link |
| | | `/` | nuova ricerca |
| | | `i` | riprendi l'ultima ricerca |
| | | `:` | modalità comando |
| ricerca | `/` | lettere | filtra la lista (parola esatta) |
| | | `ESC`, `INVIO` | torna in normale |
| comando | `:` | `:q` | indietro: dalle notizie ai giornali, dai giornali esce |
| | | `:qa` | esci |
| | | `:o` | apri la notizia nel browser |
| | | `ESC` | annulla |

Un comando sconosciuto mostra `E492` nell'intestazione.

### Giornali

ANSA, Corriere, Il Fatto Quotidiano, Il Manifesto, La Stampa, Repubblica, Il Sole 24 Ore.

Per aggiungerne uno, inserisci il nome e l'URL del feed RSS nell'array `FEEDS`:

```bash
declare -A FEEDS=(
  ...
  [NomeGiornale]="https://esempio.it/feed.xml"
)
```

### Come funziona

`fzf` gira con `--disabled`, così le lettere non finiscono nella query. Ogni
lettera, cifra, `/`, `:`, `ESC` e `INVIO` è legata a `notizie --tasto TASTO LISTA`,
che legge la modalità da `$FZF_PROMPT` e stampa l'azione fzf da eseguire. Quando
entri in modalità comando, la query della ricerca viene salvata in un file
temporaneo e ripristinata quando annulli. La directory temporanea viene cancellata
all'uscita.
