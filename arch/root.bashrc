export PS1='\[\033[35m\]\t \[\033[31m\]\u\[\033[38;5;213m\]@\h \[\033[33m\]\w\[\033[1;36m\]$(parse_git_branch)\[\033[0m\] '

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
