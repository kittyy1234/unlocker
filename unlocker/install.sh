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
    printf "  ${C_BOLD}Unlocker Installer${C_RESET}  (macOS FPS unlock – virtual high-Hz display)\n"
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
    log "${C_RED}This installer only runs on macOS.${C_RESET}"
    exit 1
fi
INSTALL_DIR="${HOME}/.local/share/unlocker"
BIN_DIR="/usr/local/bin"
LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"
PLIST_NAME="com.unlocker.fps.plist"
PLIST_PATH="${LAUNCH_AGENTS}/${PLIST_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RATE="${UNLOCKER_RATE:-500}"
spinner_start "checking build tools..."
if ! xcode-select -p >/dev/null 2>&1; then
    spinner_stop fail "Xcode Command Line Tools missing"
    log "Install with: xcode-select --install"
    exit 1
fi
if ! command -v swiftc >/dev/null 2>&1; then
    spinner_stop fail "swiftc not found"
    log "Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi
spinner_stop ok "build tools ready"
spinner_start "stopping any running unlocker..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x unlocker 2>/dev/null || true
sleep 0.4
spinner_stop ok "stopped previous instances"
spinner_start "building unlocker binary..."
TMP="$(mktemp -d /tmp/unlocker-build.XXXXXX)"
cp -R "${SCRIPT_DIR}/src" "$TMP/"
cp "${SCRIPT_DIR}/Makefile" "$TMP/"
cp "${SCRIPT_DIR}/unlocker.entitlements" "$TMP/"
(
    cd "$TMP" || exit 1
    make build SIGN="-" 2>"$TMP/build.err"
) || {
    spinner_stop fail "build failed"
    log "Build error:"
    cat "$TMP/build.err" 2>/dev/null | tail -20
    rm -rf "$TMP"
    exit 1
}
if [[ ! -f "$TMP/.build/unlocker" ]]; then
    spinner_stop fail "binary not produced"
    rm -rf "$TMP"
    exit 1
fi
spinner_stop ok "built unlocker"
spinner_start "installing binary..."
mkdir -p "$INSTALL_DIR" "$BIN_DIR" 2>/dev/null || true
if ! cp "$TMP/.build/unlocker" "$BIN_DIR/unlocker" 2>/dev/null; then
    mkdir -p "${HOME}/.local/bin"
    cp "$TMP/.build/unlocker" "${HOME}/.local/bin/unlocker"
    BIN_DIR="${HOME}/.local/bin"
    export PATH="${BIN_DIR}:$PATH"
fi
chmod +x "${BIN_DIR}/unlocker"
xattr -cr "${BIN_DIR}/unlocker" 2>/dev/null || true
xattr -d com.apple.quarantine "${BIN_DIR}/unlocker" 2>/dev/null || true
codesign --force --sign - --entitlements "${SCRIPT_DIR}/unlocker.entitlements" "${BIN_DIR}/unlocker" 2>/dev/null || true
cp -R "${SCRIPT_DIR}/src" "$INSTALL_DIR/" 2>/dev/null || true
cp "${SCRIPT_DIR}/Makefile" "$INSTALL_DIR/" 2>/dev/null || true
cp "${SCRIPT_DIR}/unlocker.entitlements" "$INSTALL_DIR/" 2>/dev/null || true
rm -rf "$TMP"
spinner_stop ok "installed to ${BIN_DIR}/unlocker"
spinner_start "installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENTS"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.unlocker.fps</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_DIR}/unlocker</string>
        <string>--rate</string>
        <string>${RATE}</string>
        <string>--no-menu</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/unlocker.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/unlocker.err</string>
</dict>
</plist>
EOF
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH" 2>/dev/null || true
launchctl start com.unlocker.fps 2>/dev/null || true
spinner_stop ok "LaunchAgent loaded (auto on login + Roblox watch)"
echo ""
log "${C_GREEN}✔  Unlocker installed${C_RESET}"
echo ""
printf "  Binary:     ${BIN_DIR}/unlocker\n"
printf "  Rate:       ${RATE} Hz (set UNLOCKER_RATE=360 before install to change)\n"
printf "  Behavior:   creates virtual display when Roblox is open\n"
printf "  Resolution: your normal display settings still work\n"
echo ""
printf "  Manual:     unlocker --rate 500\n"
printf "  Always on:  unlocker --always --rate 500\n"
printf "  Quit agent: launchctl unload ~/Library/LaunchAgents/com.unlocker.fps.plist\n"
echo ""
printf "${C_GREEN}✔  All done${C_RESET}\n"
echo ""
printf "  Open Roblox → virtual ${RATE}Hz display activates automatically\n"
echo ""
