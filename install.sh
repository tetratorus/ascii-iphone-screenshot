#!/bin/bash
# Install the iPhone screen recorder as a per-user background service (LaunchAgent).
# Feeds lightpinky's phoneframes stream into ascii-screen's --frames mode, so the
# phone's screen lands in ./screen.txt and ./history/ exactly like the Mac's does
# in ~/.ascii-screen. No Screen Recording permission needed: frames arrive on a pipe.
#
#   ./install.sh              install bin/ binaries' LaunchAgent and start it
#   ./install.sh --uninstall  stop and remove the service (data is kept)
#
# bin/ holds copies of ascii-screen (release build of ../ascii-screenshot/macos)
# and phoneframes (build of ../lightpinky/cmd/phoneframes). Rebuild there, then
# replace the files in bin/.
#
# To update the binaries: replace the files in bin/ (rm first, then cp — overwriting
# a signed Mach-O in place gets it killed by the kernel as tainted), then
#   launchctl kickstart -k gui/$(id -u)/com.tetratorus.ascii-iphone-screen
set -euo pipefail
LABEL=com.tetratorus.ascii-iphone-screen
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$DIR/bin"
ASCII="$BIN_DIR/ascii-screen"
FRAMES="$BIN_DIR/phoneframes"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/ascii-iphone-screen.log"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$PLIST"
  echo "Removed. Output in $DIR and log $LOG were kept."
  exit 0
fi

[[ -x "$ASCII" && -x "$FRAMES" ]] || { echo "missing binaries in $BIN_DIR"; exit 1; }
mkdir -p "$DIR/history" "$(dirname "$PLIST")" "$(dirname "$LOG")"
chmod 700 "$DIR/history"

xml() { local s=${1//&/&amp;}; s=${s//</&lt;}; printf '%s' "${s//>/&gt;}"; }
# Frames and history contain whatever was on the phone's screen: owner-only.
chmod -R go-rwx "$DIR/history" "$DIR/screen.txt" 2>/dev/null || true

CMD="$FRAMES -interval 1s"
{
  cat <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$(xml "$ASCII")</string>
    <string>--frames</string>
    <string>$(xml "$CMD")</string>
    <string>--interval</string><string>1s</string>
    <string>--width</string><string>100</string>
    <string>--height</string><string>40</string>
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
