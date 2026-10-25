# notizie

Legge i titoli dei giornali italiani dal terminale. Scarica i feed RSS con `curl`,
li mostra in `fzf` con tasti in stile vim e apre gli articoli in `less`.

## Versioni

Ci sono due versioni dello stesso programma. Fanno le stesse cose: cambia solo
come sono divisi i file.

| Versione | File | Comando |
|---|---|---|
| `bash` | [`notizie`](notizie), [`notizie-feed`](notizie-feed), [`notizie-leggi`](notizie-leggi) | `notizie` |
| `python` | [`notyzie`](notyzie) | `notyzie` |

- **bash**: lo script principale è in bash e usa due script a parte.
  `notizie-feed` (Python) converte un feed RSS in righe
  `giornale<TAB>titolo<TAB>link<TAB>descrizione`; `notizie-leggi URL` mostra il
  testo di un articolo. I due script si possono usare anche da soli:

  ```bash
  curl -s https://www.ansa.it/sito/notizie/topnews/topnews_rss.xml | notizie-feed ANSA
  notizie-leggi https://www.ansa.it/...
  ```

  `notizie` cerca `notizie-feed` e `notizie-leggi` nella sua stessa cartella,
  quindi i tre file vanno installati insieme.

- **python**: un file solo, con il parser dei feed e il lettore degli articoli
  incorporati come codice Python. Il lettore si usa anche da solo con
  `notyzie --leggi URL`.

Il codice Python è duplicato: una modifica al parser dei feed o al lettore va
fatta sia in `notizie-feed`/`notizie-leggi` sia in `notyzie`.

## Dipendenze

- `bash`, `curl`, `fzf`, `python3` (solo libreria standard), `less`
- `xdg-open` per aprire il link nel browser (opzionale)
- `wl-copy` (Wayland) o `xclip` (X11) per copiare il link (opzionale)

`make check` le controlla.

## Installazione

```bash
make install                   # chiede la versione e, se serve, se aggiungerla al PATH
make install VERSIONE=bash     # notizie + notizie-feed + notizie-leggi
make install VERSIONE=python   # notyzie
make install-bash              # come VERSIONE=bash (e install-python)
make install AGGIUNGI_PATH=si  # aggiunge PREFIX al PATH senza chiedere (no: non lo tocca)
make install PREFIX=~/.local/bin VERSIONE=python
make uninstall                 # rimuove entrambe le versioni
make check                     # sintassi e dipendenze (lo fa anche install)
```

Il `PREFIX` predefinito è `~/bin`. Si possono installare tutte e due le
versioni: hanno nomi diversi.

### PATH

Dopo aver copiato i file, `make install` controlla se `PREFIX` è nel `PATH`:

- se c'è già, non chiede niente;
- se è già scritto nel file della shell ma il terminale è vecchio, dice di aprirne uno nuovo;
- altrimenti chiede `Aggiungerlo in ~/.bashrc? [s/N]`. Con `s` aggiunge in fondo

  ```bash
  # aggiunto da notizie/Makefile
  export PATH="$PATH:/home/utente/bin"
  ```

  Con `INVIO` (o senza terminale, ad esempio in uno script) non modifica niente.

Il file della shell dipende da `$SHELL`: `~/.zshrc` per zsh, `~/.bashrc` per
bash, `~/.profile` per le altre. Si può scegliere con `RC=~/.altro_file`.
`make uninstall` non toglie la riga del PATH: avvisa che è rimasta.

## Uso

1. Scegli uno o più giornali (`TAB` per selezionarne più di uno) e conferma con `l` o `INVIO`.
2. I feed vengono scaricati in parallelo e compare la lista delle notizie, con
   titolo, descrizione e link nell'anteprima in basso.
3. Apri una notizia con `l` o `INVIO`: il testo compare in `less`. Con `:q` torni
   alla lista, poi ai giornali; con `:qa` esci.

## Tasti

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
| articolo | `less` | `j` / `k` | scorri |
| | | `/` | cerca nel testo |
| | | `:q` | torna alla lista |

Un comando sconosciuto mostra `E492` nell'intestazione.

## Giornali

ANSA, Corriere, Il Fatto Quotidiano, Il Manifesto, La Stampa, Repubblica, Il Sole 24 Ore.

Per aggiungerne uno, inserisci il nome e l'URL del feed RSS nell'array `FEEDS`
(in `notizie` e in `notyzie`):

```bash
declare -A FEEDS=(
  ...
  [NomeGiornale]="https://esempio.it/feed.xml"
)
```

Il Manifesto e gli articoli Rep+ di Repubblica sono a pagamento: il lettore
mostra solo l'inizio e lo segnala. La Stampa a volte serve la versione completa
dell'articolo e a volte quella tagliata.

## Come funziona

`fzf` gira con `--disabled`, così le lettere non finiscono nella query. Ogni
lettera, cifra, `/`, `:`, `ESC` e `INVIO` è legata a `notizie --tasto TASTO LISTA`
(o `notyzie --tasto ...`), che legge la modalità da `$FZF_PROMPT` e stampa
l'azione fzf da eseguire. Siccome lo script viene rilanciato a ogni tasto, la
gestione di `--tasto` è in cima al file ed esce prima di caricare il resto: non
chiama `realpath` (fzf passa già il percorso assoluto) e, in `notyzie`, non
carica il codice Python. Costa circa 4-5 ms per tasto. Quando entri in modalità comando, la query della
ricerca viene salvata in un file temporaneo e ripristinata quando annulli. La
directory temporanea viene cancellata all'uscita.

Il lettore degli articoli prende titolo e paragrafi dalla pagina e scarta menu,
script e banner dei cookie. Se la pagina contiene il testo completo nel JSON-LD
(`articleBody`, come Repubblica e Corriere), usa quello.
