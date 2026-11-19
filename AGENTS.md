# ascii-iphone-screenshot development

- `phoneframes` (`Sources/phoneframes`) is the only iPhone capture code. `ascii-screen` comes from tetratorus/ascii-screenshot, knows nothing about phones, and runs `phoneframes` as its `--frames` command. Do not add phone code there.
- Build and test: `(umask 077; swift build -c release)` and `swift test -c release`. Check the installer with `bash -n install.sh`; `./install.sh` rebuilds `phoneframes` and reloads the LaunchAgent.
- `Package.swift` pins tetratorus/lightpinky by revision. After changing lightpinky, push it, update the pin, and rebuild.
- Capture must stay passive: never wake, unlock or send input. It runs only when lock state is known false and the display is on.
- Frames, `screen.txt`, `history/` and the log hold whatever was on the phone's screen. Keep them owner-only and out of Git.
