#!/usr/bin/env bash

USER="debusercccp"
BASE_URL="https://github.com/${USER}"

REPOS=(
  "RFCellClassificator"
  "convFqFa"
  "BioToolKit"
  "PantherTUI"
  "serum_builder"
  "Music-gen"
  "ftui"
  "sqlViewer"
  "grrs"
  "libNN"
  "myconfig"
  "raspyDisplay"
  "raspyWeb"
  "raspyVideo"
)

selected=()
for i in "${!REPOS[@]}"; do
  selected+=("false")
done

# Colors
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"
CURSOR_UP="\033[A"
CLEAR_LINE="\033[2K"

hide_cursor() { tput civis; }
show_cursor() { tput cnorm; }
trap show_cursor EXIT

print_menu() {
  local cur=$1
  echo -e "${BOLD}${CYAN}  Select repos to clone  ${RESET}${DIM}(↑↓ move · space toggle · a all · n none · enter confirm)${RESET}"
  echo ""
  for i in "${!REPOS[@]}"; do
    local mark="[ ]"
    local color="${RESET}"
    [[ "${selected[$i]}" == "true" ]] && mark="[${GREEN}✓${RESET}]" && color="${GREEN}"
    if [[ $i -eq $cur ]]; then
      echo -e "  ${BOLD}${CYAN}▶ ${mark} ${color}${REPOS[$i]}${RESET}"
    else
      echo -e "    ${mark} ${color}${REPOS[$i]}${RESET}"
    fi
  done
  echo ""
  local count=0
  for s in "${selected[@]}"; do [[ "$s" == "true" ]] && ((count++)); done
  echo -e "  ${DIM}${count}/${#REPOS[@]} selected${RESET}"
}

clear_menu() {
  local lines=$(( ${#REPOS[@]} + 4 ))
  for ((i=0; i<lines; i++)); do
    echo -ne "${CURSOR_UP}${CLEAR_LINE}"
  done
}

interactive_select() {
  local cur=0
  hide_cursor
  print_menu $cur

  while true; do
    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
      read -rsn2 -t 0.1 key2
      key+="$key2"
    fi

    case "$key" in
      $'\x1b[A'|k) ((cur > 0)) && ((cur--)) ;;
      $'\x1b[B'|j) ((cur < ${#REPOS[@]}-1)) && ((cur++)) ;;
      ' ')
        if [[ "${selected[$cur]}" == "true" ]]; then
          selected[$cur]="false"
        else
          selected[$cur]="true"
        fi
        ;;
      a) for i in "${!selected[@]}"; do selected[$i]="true"; done ;;
      n) for i in "${!selected[@]}"; do selected[$i]="false"; done ;;
      ''|$'\n') break ;;
    esac

    clear_menu
    print_menu $cur
  done

  show_cursor
  echo ""
}

clone_selected() {
  local dest="${1:-.}"
  mkdir -p "$dest"

  local to_clone=()
  for i in "${!REPOS[@]}"; do
    [[ "${selected[$i]}" == "true" ]] && to_clone+=("${REPOS[$i]}")
  done

  if [[ ${#to_clone[@]} -eq 0 ]]; then
    echo -e "${YELLOW}Nothing selected.${RESET}"
    exit 0
  fi

  echo -e "${BOLD}Cloning ${#to_clone[@]} repo(s) into ${CYAN}${dest}${RESET}${BOLD}...${RESET}\n"

  for repo in "${to_clone[@]}"; do
    local url="${BASE_URL}/${repo}.git"
    local target="${dest}/${repo}"
    if [[ -d "$target/.git" ]]; then
      echo -e "  ${YELLOW}⚠ ${repo}${RESET} already exists, skipping"
    else
      echo -ne "  ${CYAN}⬇ ${repo}${RESET} ... "
      if git clone --quiet "$url" "$target" 2>/dev/null; then
        echo -e "${GREEN}done${RESET}"
      else
        echo -e "\033[31mfailed${RESET} (check URL or SSH access)"
      fi
    fi
  done

  echo -e "\n${GREEN}${BOLD}Done.${RESET}"
}

# --- main ---
DEST="."
if [[ -n "$1" ]]; then
  DEST="$1"
fi

echo ""
interactive_select
clone_selected "$DEST"
