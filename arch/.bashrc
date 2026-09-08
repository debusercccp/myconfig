# shellcheck shell=bash
# ~/.bashrc
#
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# don't put duplicate lines or lines starting with space in the history
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command
shopt -s checkwinsize

# colored ls / grep
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# --- Pacman equivalents of the old apt aliases ---
alias aggiorna='sudo pacman -Syu'
alias pulisci='sudo pacman -Sc && [[ -n $(pacman -Qdtq) ]] && sudo pacman -Rs $(pacman -Qdtq)'
alias orphans='[[ -n $(pacman -Qdt) ]] && sudo pacman -Rs $(pacman -Qdtq) || echo "no orphans to remove"'
alias pacchetti='pacman -Qe'
alias cestino='sudo rm -rf ~/.local/share/Trash/*'
alias activate='source ~/.venv/bin/activate'
alias nonascii='LC_CTYPE=C grep --color=auto -n -P "[\x80-\xFF]"'

# ~/.bash_aliases, if present
# shellcheck disable=SC1090
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# bash completion (Arch package: bash-completion)
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    fi
fi

# --- Git branch info per il prompt ---
parse_git_branch() {
    # 1. Recupera il branch corrente. Se è vuoto (non è un repo Git), esci subito per eliminare l'overhead.
    local branch
    branch=$(git branch --show-current 2>/dev/null)

    if [[ -z "$branch" ]]; then
        # Gestione del "detached HEAD" (quando fai checkout su un commit o tag specifico)
        branch=$(git rev-parse --short HEAD 2>/dev/null)
        [[ -z "$branch" ]] && return
    fi

    local status_info=""
    # 2. Rilevamento delle modifiche locali
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        status_info+=" !"
    fi

    # 3. Controllo dello stato di tracciamento remoto (GitHub)
    local upstream_counts
    upstream_counts=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)

    if [[ -n "$upstream_counts" ]]; then
        local ahead behind
        read -r ahead behind <<< "$upstream_counts"

        [[ "$ahead" -gt 0 ]] && status_info+=" ⇡${ahead}"
        [[ "$behind" -gt 0 ]] && status_info+=" ⇣${behind}"
    fi

    # 4. Restituisce il valore formattato con parentesi da passare a PS1
    echo " ($branch$status_info)"
}

# --- cd con listing troncato automatico ---
cd() {
    builtin cd "$@" || return $?
    local term_lines
    local term_cols
    term_lines=$(tput lines 2>/dev/null || echo 24)
    term_cols=$(tput cols 2>/dev/null || echo 80)
    local reserved=5
    local limit=$(( term_lines - reserved ))
    [ "$limit" -lt 5 ] && limit=5
    ls -aC --color=always -w "$term_cols" | awk -v max="$limit" '
        NR <= max { print $0 }
        END {
            if (NR > max) {
                print "\033[90m...e altre " (NR - max) " righe omesse\033[0m"
            }
        }
    '
}

# --- Prompt ---
export PS1='\[\033[35m\]\t \[\033[37m\]\u\[\033[38;5;213m\]@\h \[\033[33m\]\w\[\033[1;36m\]$(parse_git_branch)\[\033[0m\] '

# --- PATH ---
export QT_QPA_PLATFORMTHEME=qt6ct
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.pyenv/bin:$PATH"
export PATH=$PATH:/usr/sbin

# --- nvm ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# --- pyenv ---
eval "$(pyenv init -)"

# --- cargo ---
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --- GitHub token ---
if [ -r ~/dotfiles/github/tokenGH.txt ]; then
    GH_TOKEN="$(cat ~/dotfiles/github/tokenGH.txt)"
    export GH_TOKEN
fi

# --- OpenRouter / Anthropic-compatible endpoint ---
if [ -r ~/dotfiles/openrouter/key.txt ]; then
    OPENROUTER_API_KEY="$(cat ~/dotfiles/openrouter/key.txt)"
    export OPENROUTER_API_KEY
fi
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
export ANTHROPIC_API_KEY=""
export ANTHROPIC_DEFAULT_OPUS_MODEL="nvidia/nemotron-3-ultra-550b-a55b:free"
export ANTHROPIC_DEFAULT_SONNET_MODEL="nvidia/nemotron-3-ultra-550b-a55b:free"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="nvidia/nemotron-3-nano-30b-a3b:free"
export ANTHROPIC_DEFAULT_FABLE_MODEL="nvidia/nemotron-3-nano-30b-a3b:free"
export CLAUDE_CODE_SUBAGENT_MODEL="nvidia/nemotron-3-nano-30b-a3b:free"

# --- Flatpak XDG data dirs ---
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS"

# --- Aider / Ollama ---
alias jarvis='OLLAMA_API_BASE=http://127.0.0.1:11434 nice -n 15 aider --model ollama/llama3.2:latest'
alias jarvis-kb='cd ~/progetti/_kb && OLLAMA_API_BASE=http://127.0.0.1:11434 nice -n 15 aider --model ollama/llama3.2:latest'
