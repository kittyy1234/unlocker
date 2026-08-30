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
REPO="${UNLOCKER_REPO:-kittyy1234/unlocker}"
RATE="${UNLOCKER_RATE:-500}"
ARCH="$(uname -m)"
case "$ARCH" in
    arm64|aarch64) ARCH_TAG="arm64" ;;
    x86_64|amd64)  ARCH_TAG="x86_64" ;;
    *) ARCH_TAG="$ARCH" ;;
esac
BIN_NAME="unlocker-${ARCH_TAG}"
INSTALL_DIR="${HOME}/.local/share/unlocker"
BIN_DIR="${HOME}/.local/bin"
LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"
PLIST_PATH="${LAUNCH_AGENTS}/com.unlocker.fps.plist"
TMP="$(mktemp -d /tmp/unlocker-install.XXXXXX)"
mkdir -p "$BIN_DIR" "$INSTALL_DIR" "$LAUNCH_AGENTS"
spinner_start "stopping any running unlocker..."
launchctl bootout "gui/$(id -u)/com.unlocker.fps" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x unlocker 2>/dev/null || true
sleep 0.3
spinner_stop ok "stopped previous instances"
BINARY_PATH=""
spinner_start "downloading prebuilt binary (${ARCH_TAG})..."
DOWNLOAD_URL=""
API="https://api.github.com/repos/${REPO}/releases/latest"
if command -v curl >/dev/null 2>&1; then
    ASSETS=$(curl -fsSL "$API" 2>/dev/null || true)
    if [[ -n "$ASSETS" ]]; then
        DOWNLOAD_URL=$(printf "%s" "$ASSETS" | grep -o "https://[^\"]*${BIN_NAME}[^\"]*" | head -1 || true)
        if [[ -z "$DOWNLOAD_URL" ]]; then
            DOWNLOAD_URL=$(printf "%s" "$ASSETS" | grep -o 'https://[^"]*unlocker[^"]*' | grep -v '\.sh' | head -1 || true)
        fi
    fi
fi
if [[ -z "$DOWNLOAD_URL" ]]; then
    DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${BIN_NAME}"
fi
if curl -fsSL "$DOWNLOAD_URL" -o "$TMP/unlocker" 2>/dev/null && [[ -s "$TMP/unlocker" ]]; then
    chmod +x "$TMP/unlocker"
    if file "$TMP/unlocker" 2>/dev/null | grep -qi 'Mach-O\|executable'; then
        BINARY_PATH="$TMP/unlocker"
        spinner_stop ok "downloaded prebuilt binary"
    else
        rm -f "$TMP/unlocker"
        BINARY_PATH=""
        spinner_stop fail "download was not a valid binary"
    fi
else
    spinner_stop fail "no prebuilt binary on Releases"
fi
if [[ -z "$BINARY_PATH" ]]; then
    spinner_start "trying raw binary from repo..."
    for path in "bin/${BIN_NAME}" "bin/unlocker" "dist/${BIN_NAME}" "dist/unlocker"; do
        RAW="https://raw.githubusercontent.com/${REPO}/main/${path}"
        if curl -fsSL "$RAW" -o "$TMP/unlocker" 2>/dev/null && [[ -s "$TMP/unlocker" ]]; then
            chmod +x "$TMP/unlocker"
            if file "$TMP/unlocker" 2>/dev/null | grep -qi 'Mach-O\|executable'; then
                BINARY_PATH="$TMP/unlocker"
                spinner_stop ok "downloaded from repo (${path})"
                break
            fi
            rm -f "$TMP/unlocker"
        fi
    done
    if [[ -z "$BINARY_PATH" ]]; then
        spinner_stop fail "no binary in repo either"
    fi
fi
if [[ -z "$BINARY_PATH" ]] && command -v swiftc >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
    spinner_start "building from source (tools already present)..."
    SRC_ZIP="$TMP/src.zip"
    if curl -fsSL "https://codeload.github.com/${REPO}/zip/refs/heads/main" -o "$SRC_ZIP" 2>/dev/null; then
        unzip -q "$SRC_ZIP" -d "$TMP" 2>/dev/null || true
        SRC_ROOT=$(find "$TMP" -maxdepth 1 -type d -name "unlocker-*" | head -1)
        if [[ -z "$SRC_ROOT" ]]; then SRC_ROOT=$(find "$TMP" -maxdepth 2 -type d -name "src" | head -1 | xargs dirname 2>/dev/null); fi
        if [[ -n "$SRC_ROOT" && -f "$SRC_ROOT/Makefile" ]]; then
            (
                cd "$SRC_ROOT" || exit 1
                make build SIGN="-" >/dev/null 2>"$TMP/build.err"
            ) && [[ -f "$SRC_ROOT/.build/unlocker" ]] && {
                BINARY_PATH="$SRC_ROOT/.build/unlocker"
                spinner_stop ok "built from source"
            } || {
                spinner_stop fail "source build failed"
                [[ -f "$TMP/build.err" ]] && tail -15 "$TMP/build.err"
            }
        else
            spinner_stop fail "source tree incomplete"
        fi
    else
        spinner_stop fail "could not fetch source"
    fi
fi
if [[ -z "$BINARY_PATH" || ! -f "$BINARY_PATH" ]]; then
    echo ""
    log "${C_RED}Could not get an unlocker binary.${C_RESET}"
    log "Publish a Release asset named: ${BIN_NAME}"
    log "  or put it at: bin/${BIN_NAME} on the main branch"
    log "Releases: https://github.com/${REPO}/releases"
    log "No Xcode install is required for users when a prebuilt binary is available."
    rm -rf "$TMP"
    exit 1
fi
spinner_start "installing binary..."
cp "$BINARY_PATH" "${BIN_DIR}/unlocker"
chmod +x "${BIN_DIR}/unlocker"
xattr -cr "${BIN_DIR}/unlocker" 2>/dev/null || true
xattr -d com.apple.quarantine "${BIN_DIR}/unlocker" 2>/dev/null || true
codesign --force --sign - "${BIN_DIR}/unlocker" 2>/dev/null || true
spinner_stop ok "installed to ${BIN_DIR}/unlocker"
spinner_start "installing LaunchAgent..."
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
launchctl bootout "gui/$(id -u)/com.unlocker.fps" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl load "$PLIST_PATH" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/com.unlocker.fps" 2>/dev/null || launchctl start com.unlocker.fps 2>/dev/null || true
spinner_stop ok "LaunchAgent loaded"
rm -rf "$TMP"
echo ""
log "${C_GREEN}✔  Unlocker installed${C_RESET}"
echo ""
printf "  Binary:     %s/unlocker\n" "$BIN_DIR"
printf "  Rate:       %s Hz\n" "$RATE"
printf "  Behavior:   virtual display when Roblox is open\n"
printf "  PATH tip:   export PATH=\"%s:\$PATH\"\n" "$BIN_DIR"
echo ""
printf "  Manual:     %s/unlocker --rate 500\n" "$BIN_DIR"
printf "  Uninstall:  curl -fsSL https://raw.githubusercontent.com/%s/main/uninstall.sh | bash\n" "$REPO"
echo ""
printf "${C_GREEN}✔  All done${C_RESET}\n"
echo ""
printf "  Open Roblox → virtual %sHz display activates automatically\n" "$RATE"
echo ""
