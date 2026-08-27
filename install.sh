#!/bin/bash
set -u

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_GRAY="\033[90m"

get_time() {
    local s="" mot="kitty123"
    local couleurs=("180;220;255" "150;200;255" "120;180;255" "90;160;255" "70;140;245" "50;120;230" "40;110;220" "30;100;210")
    for ((i=0; i<${#mot}; i++)); do
        s+="\033[38;2;${couleurs[$((i % ${#couleurs[@]}))]}m${mot:$i:1}"
    done
    s+="${C_RESET}"
    printf "%b" "${s}${C_GRAY}::${C_RESET}${C_GREEN}[$(date +%H:%M:%S)]${C_RESET}  "
}

banner() {
    printf "${C_GRAY}────────────────────────────────────${C_RESET}\n"
    printf " Installer \n"
    printf "${C_GRAY}────────────────────────────────────${C_RESET}\n"
    echo ""
}

SPIN_FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
SPINNER_PID=""
SPINNER_MSG=""

spinner_start() {
    SPINNER_MSG="$1"
    printf "\033[?25l\033[?7l"
    ( local i=0; while true; do
        printf "\r\033[2K%b${C_GREEN}%s${C_RESET}  %s" "$(get_time)" "${SPIN_FRAMES[$((i % ${#SPIN_FRAMES[@]}))]}" "$SPINNER_MSG"
        i=$((i+1)); sleep 0.08
    done ) &
    SPINNER_PID=$!; disown "$SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
    local status="${1:-ok}" msg="${2:-$SPINNER_MSG}"
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null; wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    printf "\r\033[2K"
    case "$status" in
        ok)   printf "%b${C_GREEN}✔${C_RESET}  %b\n" "$(get_time)" "$msg" ;;
        fail) printf "%b${C_RED}✖${C_RESET}  %b\n" "$(get_time)" "$msg" ;;
        *)    printf "%b    %b\n" "$(get_time)" "$msg" ;;
    esac
    printf "\033[?7h\033[?25h"
}

handle_fail() {
    spinner_stop fail "$1"
    echo ""
    printf "${C_RED}✖  Build Failed${C_RESET}\n"
    echo ""
    exit 1
}

cleanup() { [[ -n "$SPINNER_PID" ]] && kill "$SPINNER_PID" 2>/dev/null; printf "\033[?7h\033[?25h"; }
trap cleanup EXIT INT TERM

banner

spinner_start "Killing old roblox"
pkill -f "launcher.sh" 2>/dev/null || true
pkill -f "virtual_display_engine" 2>/dev/null || true
sleep 0.4
spinner_stop ok "Killing old roblox"

spinner_start "killed..."
sleep 0.4
spinner_stop ok "killed..."

GITHUB_USERNAME="kittyy1234"
REPO_NAME="unlocker"
REPO_RAW="https://raw.githubusercontent.com/kittyy1234/unlocker/main"
INSTALL_DIR="$HOME/.custom_360hz"

spinner_start "downloading files..."
rm -rf "$INSTALL_DIR" 2>/dev/null || handle_fail "failed workspace reset"
mkdir -p "$INSTALL_DIR" 2>/dev/null || handle_fail "failed workspace creation"
cd "$INSTALL_DIR" || handle_fail "failed directory change"

curl -fsSL "$REPO_RAW/main.swift" -o main.swift || handle_fail "download failed"
curl -fsSL "$REPO_RAW/uncap_fps.sh" -o uncap_fps.sh || handle_fail "download failed"
curl -fsSL "$REPO_RAW/launcher.sh" -o launcher.sh || handle_fail "download failed"
chmod +x uncap_fps.sh launcher.sh 2>/dev/null || handle_fail "failed permissions configuration"
spinner_stop ok "done"

spinner_start "finalizing"
swiftc main.swift -o main > /dev/null 2>&1 || handle_fail "compilation failed"
spinner_stop ok "finalizing"

spinner_start "build complete"
sleep 0.2
spinner_stop ok "build complete"

echo ""
printf "${C_GREEN}✔ All done${C_RESET}\n"
echo ""
printf "ᗢ developed by kittyy123 :3\n"
echo ""
