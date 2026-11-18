#!/bin/bash
# Install the iPhone screen recorder as a per-user background service (LaunchAgent).
# phoneframes (this repository) captures the paired phone over macOS CoreDevice and
# feeds frames to ascii-screen --frames, so the phone's screen lands in ./screen.txt
# and ./history/ exactly like the Mac's does in ~/.ascii-screen. No Mac Screen
# Recording permission is needed.
#
#   ./install.sh              build phoneframes, install the LaunchAgent and start it
#   ./install.sh --uninstall  stop and remove the service (data is kept)
#
# bin/ascii-screen is a release build of github.com/tetratorus/ascii-screenshot
# (swift build -c release --package-path macos). To update it, rm the old file
# first, then cp: overwriting a signed Mach-O in place gets it killed by the
# kernel as tainted. Then run this script again.
set -euo pipefail
LABEL=com.tetratorus.ascii-iphone-screen
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$DIR/bin"
ASCII="$BIN_DIR/ascii-screen"
FRAMES="$BIN_DIR/phoneframes"
DEVICE="${IPHONE_DEVICE:-E4AF0765-388E-5F38-BA32-50727F5FB2CA}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/ascii-iphone-screen.log"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
# bootout may return before launchd finishes removing the old job.
for ((attempt = 0; attempt < 50; attempt++)); do
  launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 || break
  sleep 0.1
done
if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$PLIST"
  echo "Removed. Output in $DIR and log $LOG were kept."
  exit 0
fi

[[ -x "$ASCII" ]] || { echo "missing ascii-screen in $BIN_DIR (see the top of this script)"; exit 1; }
# Frames can contain whatever was on the phone's screen; keep build output private too.
(umask 077; xcrun swift build -c release --package-path "$DIR")
rm -f "$FRAMES"
install -m 755 "$DIR/.build/release/phoneframes" "$FRAMES"
mkdir -p "$DIR/history" "$(dirname "$PLIST")" "$(dirname "$LOG")"
chmod 700 "$DIR/history"

xml() { local s=${1//&/&amp;}; s=${s//</&lt;}; printf '%s' "${s//>/&gt;}"; }
# ascii-screen runs the frame command through sh, so quote each word for it.
quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }
COMMAND="$(quote "$FRAMES") $(quote "$DEVICE") --interval 1"
# Frames and history contain whatever was on the phone's screen: owner-only.
chmod -R go-rwx "$DIR/history" "$DIR/screen.txt" 2>/dev/null || true

# CoreDevice owns transport selection and reconnects across USB/Wi-Fi changes.
{
  cat <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$(xml "$ASCII")</string>
    <string>--frames</string>
    <string>$(xml "$COMMAND")</string>
    <string>--width</string><string>100</string>
    <string>--height</string><string>40</string>
    <string>--fit</string>
    <string>--out</string><string>$(xml "$DIR/screen.txt")</string>
    <string>--history</string><string>$(xml "$DIR/history")</string>
    <string>--stats</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Background</string>
  <key>LowPriorityIO</key><true/>
  <key>Nice</key><integer>10</integer>
  <key>StandardErrorPath</key><string>$(xml "$LOG")</string>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
PL
} > "$PLIST"
plutil -lint "$PLIST" >/dev/null
launchctl bootstrap "$DOMAIN" "$PLIST"

echo "Running as $LABEL. Output: $DIR/screen.txt  History: $DIR/history  Log: $LOG"
echo "Query it with the ascii-screen CLI: ascii-screen --search <query> --history $DIR/history"
