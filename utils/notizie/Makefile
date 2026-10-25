# notizie - installa una delle due versioni:
#   bash    notizie + notizie-feed + notizie-leggi (tre file separati)
#   python  notyzie (un file solo, con il Python incorporato)
#
#   make install                          chiede la versione e se aggiungere PREFIX al PATH
#   make install VERSIONE=bash            senza domanda sulla versione
#   make install AGGIUNGI_PATH=si|no      senza domanda sul PATH
#   make install PREFIX=~/.local/bin

PREFIX        ?= $(HOME)/bin
VERSIONE      ?=
AGGIUNGI_PATH ?=
# file di configurazione della shell in cui aggiungere il PATH
RC ?= $(HOME)/$(if $(findstring zsh,$(SHELL_UTENTE)),.zshrc,$(if $(findstring bash,$(SHELL_UTENTE)),.bashrc,.profile))
SHELL_UTENTE := $(notdir $(or $(shell echo $$SHELL),sh))

FILE_bash   := notizie notizie-feed notizie-leggi
FILE_python := notyzie
SEGNO       := \# aggiunto da notizie/Makefile

.PHONY: help install install-bash install-python uninstall check deps

help:
	@echo "make install                 scegli la versione (bash o python) e installala in $(PREFIX)"
	@echo "make install VERSIONE=bash   notizie + notizie-feed + notizie-leggi"
	@echo "make install VERSIONE=python notyzie, tutto in un file"
	@echo "make install AGGIUNGI_PATH=si|no   aggiungi (o no) $(PREFIX) al PATH in $(RC) senza chiedere"
	@echo "make uninstall               rimuove entrambe le versioni da $(PREFIX)"
	@echo "make check                   controlla sintassi e dipendenze"

install-bash:   VERSIONE := bash
install-python: VERSIONE := python
install-bash install-python: install

install: check
	@v="$(VERSIONE)"; \
	if [ -z "$$v" ]; then \
	  echo "Quale versione vuoi installare?"; \
	  echo "  1) bash    notizie + notizie-feed + notizie-leggi (tre file)"; \
	  echo "  2) python  notyzie (un file solo)"; \
	  printf "Scelta [1/2]: "; read r || r=; \
	  case "$$r" in 1|bash) v=bash ;; 2|python) v=python ;; *) echo "Scelta non valida: $$r"; exit 1 ;; esac; \
	fi; \
	case "$$v" in \
	  bash)   file="$(FILE_bash)";   cmd=notizie ;; \
	  python) file="$(FILE_python)"; cmd=notyzie ;; \
	  *) echo "VERSIONE deve essere bash o python, non '$$v'"; exit 1 ;; \
	esac; \
	install -d "$(PREFIX)" && install -m 755 $$file "$(PREFIX)/" || exit 1; \
	echo "Installato in $(PREFIX): $$file"; \
	case ":$$PATH:" in *":$(PREFIX):"*) echo "$(PREFIX) è già nel PATH. Avvia con: $$cmd"; exit 0 ;; esac; \
	if grep -qsF '$(PREFIX)' "$(RC)"; then \
	  echo "$(PREFIX) è già in $(RC): apri un nuovo terminale e avvia con: $$cmd"; exit 0; \
	fi; \
	a="$(AGGIUNGI_PATH)"; \
	if [ -z "$$a" ]; then printf "$(PREFIX) non è nel PATH. Aggiungerlo in $(RC)? [s/N]: "; read a || a=; fi; \
	case "$$a" in \
	  s|S|si|sì|y|yes) \
	    printf '\n%s\nexport PATH="$$PATH:%s"\n' '$(SEGNO)' '$(PREFIX)' >> "$(RC)"; \
	    echo "Aggiunto in $(RC). Apri un nuovo terminale (o: source $(RC)) e avvia con: $$cmd" ;; \
	  *) echo "PATH non modificato. Avvia con: $(PREFIX)/$$cmd" ;; \
	esac

uninstall:
	rm -f $(addprefix "$(PREFIX)"/,$(FILE_bash) $(FILE_python))
	@grep -qsF '$(SEGNO)' "$(RC)" && echo "Nota: la riga del PATH aggiunta in $(RC) è rimasta; toglila a mano se non serve più." || true

check: deps
	@for f in notizie notizie-leggi notyzie; do bash -n $$f || exit 1; done
	@python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' notizie-feed
	@echo "Sintassi OK"

deps:
	@manca=; for c in bash curl fzf python3 less; do command -v $$c >/dev/null || manca="$$manca $$c"; done; \
	if [ -n "$$manca" ]; then echo "Mancano:$$manca"; exit 1; fi; \
	command -v xdg-open >/dev/null || echo "Opzionale: manca xdg-open (apri nel browser)"; \
	command -v wl-copy >/dev/null || command -v xclip >/dev/null || echo "Opzionale: manca wl-copy o xclip (copia link)"
