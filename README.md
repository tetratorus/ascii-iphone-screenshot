# ASCII iPhone

Records the phone's screen as positioned text and searchable history.
`install.sh` runs the recorder as a macOS LaunchAgent.

## Set up the `aip` shortcut

Add this shell function to `~/.zshrc` (macOS's default shell). Set `repo` to
your checkout's location. Playback needs `bin/ascii-screen` from the
[recorder sources](#recorder-sources); `--uptime` needs Python 3.10 or later
and recorded history in this checkout's `history/` directory.

```zsh
aip() {
  local repo="$HOME/repo/ai/ascii-iphone-screenshot" # change to your checkout
  if [[ "${1:-}" == "--uptime" ]]; then
    shift
    python3 "$repo/uptime.py" "$@"
    return $?
  fi
  local args=(--play --fit --history "$repo/history")
  if (( $# > 2 )); then
    printf 'Usage: aip [from [to]] | aip --uptime [from [to]] [--once|--json|--watch]\n' >&2
    return 2
  fi
  if (( $# >= 1 )); then
    args+=(--from "$1")
  fi
  if (( $# == 2 )); then
    args+=(--to "$2")
  fi
  "$repo/bin/ascii-screen" "${args[@]}"
}
```

Reload the configuration, or open a new terminal:

```sh
source ~/.zshrc
```

The command is lowercase `aip`. For Mac screen history, see the
[`ap` setup in ASCII Screen](https://github.com/tetratorus/ascii-screenshot#set-up-the-ap-shortcut).

## Playback and capture activity

The local `aip` shell function plays iPhone history with `--fit`, preserving
each frame's proportions as the phone changes between portrait and landscape.

```sh
aip 5m
aip 14:00 14:30
aip --uptime
aip --uptime 24h
aip --uptime --once
aip --uptime --json
```

`--uptime` opens a live chart of the **last hour**, refreshing every five seconds.
Seven labeled ticks mark the timeline (every ten minutes at the default zoom).
The legend gives each cell's time span; dots mean no saved frames, and bar heights
show capture volume and unique words per frame. Recent capture groups underneath
give exact start/end times, down to the second.

Use `+`/`-` to zoom in/out, left/right arrows to move through history, `L` to
return to live, and `Q` to quit. Zoom ranges run from one minute to seven days.
`--once` prints one snapshot; piping output or using `--json` also prints once.
`--watch` remains available to explicitly request refreshes outside a terminal.

An unchanged or locked screen also creates a gap, so these are capture activity
charts, not a measured uptime percentage.

The monitor reads `history/index.sqlite` in read-only mode. It does not read or
display the screen text. Word counts use the search index, which counts each
distinct word once per frame. The recorder buffers history for up to ten seconds.

The monitor is also available without a shell function:

```sh
python3 uptime.py --help
python3 uptime.py 24h --json
```

## Recorder sources

- `phoneframes` (this repository, `Sources/phoneframes`): captures the paired iPhone and
  prints frames for `ascii-screen --frames`. It builds against a pinned
  [LightpinkyCore](https://github.com/tetratorus/lightpinky), which reads lock and display
  state and takes screenshots through macOS's CoreDevice connection. `./install.sh` builds it.
  Full Xcode must be selected and the phone paired with Developer Mode enabled.
  The phone must also be reachable from the recording Mac over USB or local Wi-Fi.
  A paired phone in another location is unavailable; the service waits and retries.
  - Recording pauses while the phone is locked or its display is off, and sends no wake or
    unlock input.
    It checks a paused phone every 3 seconds for the first minute and every 10 seconds
    after that, so capture can take up to 10 seconds to resume.
  - While the lightpinky controller is streaming the display for input, `phoneframes` takes
    that stream's frames instead of screenshots, so the two do not compete for the link.
    Those frames are compressed and stretched by two rows, so detected lines can differ
    until the controller goes idle. The recorder never opens a video stream itself,
    because streaming wakes and holds the phone's display active. The controller closes
    its stream after about 30 seconds without input or video requests; read-only state
    and accessibility queries do not extend that time. The recorder waits through short
    frame gaps before returning to full-resolution lossless PNG screenshots.
  - Passive PNG capture can be slow on weak Wi-Fi. The screenshot service has no
    size or quality option; capture time depends on the screen content and link speed.
    After a slow capture, the recorder leaves the link idle for up to 15 seconds.
    Video uses less bandwidth but changes pixels and can trigger additional OCR even
    on a still screen. Comparative phone battery use has not been measured.
  - Errors on stderr name the failing phase: device connection, state read, or screenshot.
    Power reads retry once on a fresh connection after a transport timeout or disconnect.
    If that fails, recording pauses and the normal failure backoff applies; no input is sent.
  - Test with `swift test -c release`.
- `ascii-screen`: a release build of [ascii-screenshot](https://github.com/tetratorus/ascii-screenshot)
  (`swift build -c release --package-path macos`), copied to `bin/`. It knows nothing about
  phones: it runs `phoneframes` as its `--frames` command and does the OCR, line detection
  and history.
- `bin/` contains local build copies and is ignored by Git.

After rebuilding `ascii-screen`, replace the binary with a new file (do not overwrite running
signed executables in place), then run `./install.sh` to reload the service.
The installer defaults to this Mac's paired iPhone; set `IPHONE_DEVICE` to select
another name or UUID from `xcrun devicectl list devices`.

Screen output, history and logs can contain private phone content. Keep them outside Git.
The installer sets the recorder log to owner-only permissions (`0600`).
