#!/bin/bash
set -u
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_GRAY="\033[90m"
get_time() {
    local s="" mot="Unlocker"
    local couleurs=("180;220;255" "150;200;255" "120;180;255" "90;160;255" "70;140;245" "50;120;230" "40;110;220" "30;100;210")
    for ((i=0; i<${#mot}; i++)); do
        s+="\033[38;2;${couleurs[$((i % ${#couleurs[@]}))]}m${mot:$i:1}"
    done
    s+="${C_RESET}"
    printf "%b" "${s}${C_GRAY}::${C_RESET}${C_GREEN}[$(date +%H:%M:%S)]${C_RESET}"
}
log() { printf "%b %b\n" "$(get_time)" "$1"; }
banner() {
    echo ""
    printf "  ${C_BOLD}Unlocker Uninstaller${C_RESET}\n"
    printf "${C_GRAY}────────────────────────────────────────────${C_RESET}\n"
    echo ""
}
SPIN_FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
SPINNER_PID=""
SPINNER_MSG=""
spinner_start() {
    SPINNER_MSG="$1"
    printf "\033[?25l\033[?7l"
    ( local i=0; while true; do
        printf "\r\033[2K%b %s  %s" "$(get_time)" "${SPIN_FRAMES[$((i % ${#SPIN_FRAMES[@]}))]}" "$SPINNER_MSG"
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
        ok)   printf "%b ${C_GREEN}✔${C_RESET}  %b\n" "$(get_time)" "$msg" ;;
        fail) printf "%b ${C_RED}✖${C_RESET}  %b\n" "$(get_time)" "$msg" ;;
        *)    printf "%b    %b\n" "$(get_time)" "$msg" ;;
    esac
    printf "\033[?7h\033[?25h"
}
cleanup() { [[ -n "$SPINNER_PID" ]] && kill "$SPINNER_PID" 2>/dev/null; printf "\033[?7h\033[?25h"; }
trap cleanup EXIT INT TERM
banner
if [[ "$(uname -s)" != "Darwin" ]]; then
    log "${C_RED}This uninstaller only runs on macOS.${C_RESET}"
    exit 1
fi
PLIST_PATH="${HOME}/Library/LaunchAgents/com.unlocker.fps.plist"
INSTALL_DIR="${HOME}/.local/share/unlocker"
spinner_start "stopping unlocker..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl remove com.unlocker.fps 2>/dev/null || true
pkill -x unlocker 2>/dev/null || true
sleep 0.4
spinner_stop ok "stopped"
spinner_start "removing LaunchAgent..."
rm -f "$PLIST_PATH"
spinner_stop ok "LaunchAgent removed"
spinner_start "removing binary..."
rm -f /usr/local/bin/unlocker
rm -f "${HOME}/.local/bin/unlocker"
rm -rf "$INSTALL_DIR"
rm -f "${HOME}/Library/Logs/unlocker.log" "${HOME}/Library/Logs/unlocker.err"
spinner_stop ok "files removed"
echo ""
log "${C_GREEN}✔  Unlocker fully uninstalled${C_RESET}"
echo ""
printf "  Virtual display and mirroring are cleared.\n"
printf "  Your normal display settings are restored.\n"
echo ""
