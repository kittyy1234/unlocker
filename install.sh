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
    printf "  ${C_BOLD}Unlocker Installer${C_RESET}  (download only – no Xcode)\n"
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
    log "${C_RED}macOS only.${C_RESET}"
    exit 1
fi
REPO="${UNLOCKER_REPO:-kittyy1234/unlocker}"
RATE="${UNLOCKER_RATE:-500}"
ARCH="$(uname -m)"
case "$ARCH" in
    arm64|aarch64) ARCH_TAG="arm64" ;;
    x86_64|amd64)  ARCH_TAG="x86_64" ;;
    *) ARCH_TAG="$ARCH" ;;
esac
BIN_NAME="unlocker-${ARCH_TAG}"
BIN_DIR="${HOME}/.local/bin"
PLIST_PATH="${HOME}/Library/LaunchAgents/com.unlocker.fps.plist"
TMP="$(mktemp -d /tmp/unlocker-install.XXXXXX)"
mkdir -p "$BIN_DIR" "${HOME}/Library/LaunchAgents"
spinner_start "stopping old unlocker..."
launchctl bootout "gui/$(id -u)/com.unlocker.fps" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x unlocker 2>/dev/null || true
sleep 0.3
spinner_stop ok "stopped"
BINARY_PATH=""
spinner_start "downloading ${BIN_NAME}..."
try_url() {
    local url="$1"
    if curl -fsSL "$url" -o "$TMP/unlocker" 2>/dev/null && [[ -s "$TMP/unlocker" ]]; then
        local f
        f=$(file "$TMP/unlocker" 2>/dev/null || true)
        if printf "%s" "$f" | grep -qi 'Mach-O'; then
            chmod +x "$TMP/unlocker"
            BINARY_PATH="$TMP/unlocker"
            return 0
        fi
        rm -f "$TMP/unlocker"
    fi
    return 1
}
API="https://api.github.com/repos/${REPO}/releases/latest"
ASSETS=$(curl -fsSL "$API" 2>/dev/null || true)
URL=""
if [[ -n "$ASSETS" ]]; then
    URL=$(printf "%s" "$ASSETS" | grep -o "https://[^\"]*${BIN_NAME}[^\"]*" | head -1 || true)
fi
[[ -n "$URL" ]] && try_url "$URL" || true
[[ -z "$BINARY_PATH" ]] && try_url "https://github.com/${REPO}/releases/latest/download/${BIN_NAME}" || true
[[ -z "$BINARY_PATH" ]] && try_url "https://github.com/${REPO}/releases/latest/download/unlocker" || true
for path in "bin/${BIN_NAME}" "bin/unlocker" "dist/${BIN_NAME}" "dist/unlocker"; do
    [[ -n "$BINARY_PATH" ]] && break
    try_url "https://raw.githubusercontent.com/${REPO}/main/${path}" || true
done
if [[ -z "$BINARY_PATH" ]]; then
    spinner_stop fail "no binary online"
    echo ""
    log "${C_RED}Nothing to install yet – no Mac binary on GitHub.${C_RESET}"
    log ""
    log "This installer never uses Xcode. It only downloads a ready binary."
    log "You still need to put one online once:"
    log ""
    log "  1. Push source + .github/workflows/build.yml"
    log "  2. GitHub → Actions → run Build → download unlocker-arm64 artifact"
    log "  3. Create a Release and upload the file as: ${BIN_NAME}"
    log "     OR commit it as: bin/${BIN_NAME}"
    log "  4. Re-run this curl install"
    log ""
    log "Releases: https://github.com/${REPO}/releases"
    log "Actions:  https://github.com/${REPO}/actions"
    rm -rf "$TMP"
    exit 1
fi
spinner_stop ok "downloaded binary"
spinner_start "installing..."
cp "$BINARY_PATH" "${BIN_DIR}/unlocker"
chmod +x "${BIN_DIR}/unlocker"
xattr -cr "${BIN_DIR}/unlocker" 2>/dev/null || true
xattr -d com.apple.quarantine "${BIN_DIR}/unlocker" 2>/dev/null || true
codesign --force --sign - "${BIN_DIR}/unlocker" 2>/dev/null || true
spinner_stop ok "installed ${BIN_DIR}/unlocker"
spinner_start "starting always-on ${RATE}Hz..."
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
        <string>--always</string>
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
launchctl bootout "gui/$(id -u)/com.unlocker.fps" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl load "$PLIST_PATH" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/com.unlocker.fps" 2>/dev/null || true
sleep 0.4
if ! pgrep -x unlocker >/dev/null 2>&1; then
    "${BIN_DIR}/unlocker" --rate "$RATE" --always --no-menu >/dev/null 2>&1 &
    disown 2>/dev/null || true
fi
spinner_stop ok "running"
rm -rf "$TMP"
echo ""
log "${C_GREEN}✔  Unlocker installed (no Xcode used)${C_RESET}"
echo ""
printf "  %s/unlocker  – always-on virtual %s Hz\n" "$BIN_DIR" "$RATE"
printf "  Open Roblox and check FPS.\n"
echo ""

#MOGGG
