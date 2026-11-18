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

- `ascii-screen`: `../ascii-screenshot-iphone-build/macos`. The iPhone build
  includes `--iphone <name-or-UUID>` and `--fit`; saved history retains each frame's dimensions.
  It captures through Apple's `xcrun devicectl` using macOS's paired CoreDevice
  connection. No Go binary, custom network tunnel, or lightpinky installation is needed.
  Xcode must be installed and the phone paired with Developer Mode enabled.
  Recording pauses while locked or with the display off; it never wakes or unlocks.
- `bin/` contains local build copies and is ignored by Git.

After rebuilding, replace the binary with a new file (do not overwrite running
signed executables in place), then run `./install.sh` to reload the service.
The installer defaults to this Mac's paired iPhone; set `IPHONE_DEVICE` to select
another name or UUID from `xcrun devicectl list devices`.
