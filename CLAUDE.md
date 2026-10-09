# CLAUDE.md — Speed Editor Bridge

macOS app (Swift 6, SwiftUI, Apple silicon) that drives Final Cut Pro and Logic Pro from a
DaVinci Resolve Speed Editor. Owner: Heath (church AV/IT). Church-use license; the protocol was
reimplemented from public write-ups, no third-party code is included.

## Layout
- `Sources/SpeedEditorKit` — device layer. `Auth.swift` is the challenge-response unlock,
  `Device.swift` wraps IOHIDManager/IOHIDDevice, `Keys.swift` has key codes, LEDs, jog modes.
- `Sources/seprobe` — CLI probe: handshake, echo keys and wheel, mode keys switch wheel modes.
- `Sources/SpeedEditorBridge` — the app. `Engine.swift` maps device events to actions,
  `KeySender.swift` posts CGEvents, `MackieControl.swift` is a virtual Mackie Control surface
  over CoreMIDI, `Profiles.swift` holds the FCP/Logic/Generic defaults and the JSON overrides in
  `~/Library/Application Support/Speed Editor Bridge/profiles/`.
- `make-app.sh [debug|release]` builds and wraps `build/Speed Editor Bridge.app` (ad-hoc signed,
  bundle id `church.fbcld.speed-editor-bridge`). There is no Xcode project; SwiftPM only.

## Device facts (measured on Heath's USB-C unit, 2026-10-09)
- USB VID 0x1edb PID 0xda0e, vendor-specific HID usage page. No Input Monitoring prompt was
  needed to open it from a terminal. Only Accessibility is needed, for posting keystrokes.
- Handshake on feature report 6 works first time; the device answers timeout 600 s and the
  device class re-runs it at half that.
- Key report is ID 4 (six LE16 slots). All 43 key codes matched the published table.
- Wheel report ID 3: relative modes give 360 units per encoder tick, ~4600 ticks per revolution,
  reports every ~16 ms. Modes 0 and 2 are identical in scale. Absolute modes (1 and 3) report a
  position clamped to ±4096 (about 16 units per tick), mode 3 has a ~±250 dead band. The wheel
  has no stops or spring: re-sending the jog-mode output report re-zeroes the position, which
  the engine uses when STOP/PLAY is hit mid-shuttle.
- LED report 2 (18 bits) and jog-LED report 4 (JOG=1, SHTL=2, SCRL=4) both work.

## Target apps
- Final Cut and Logic on this Mac are the "Creator Studio" builds: bundle ids
  `com.apple.FinalCutApp` and `com.apple.mobilelogic` (v12.4). The classic ids are matched too.
- Resolve is `com.blackmagic-design.DaVinciResolve`; the app releases the device when Resolve is
  frontmost and takes it back when FCP or Logic comes to the front.

## Behaviour decisions
- FCP: keystrokes only, Apple default shortcuts. JOG = arrow keys (coalesced to Shift+arrow per 10
  frames), SHTL = J/K/L speed levels (half speed is hold K + tap L), SCRL = Up/Down (previous/next
  edit). Holding TRIM IN / TRIM OUT / ROLL while turning sends comma/period nudges; the key's own
  action fires on release only if the wheel did not move.
- Logic: Mackie Control where it exists (transport, jog, Cycle+Rewind/FF for locators, Select 1-8
  for CAM keys, Record for LIVE O/WR), keystrokes otherwise. Logic discovers the surface by sysex
  query; we answer as a Mackie Control with serial SEB0001. **Logic never sends the 0x02 host
  connection reply** - after our 0x01 answer it goes straight to configuring the surface (0x21
  global meter mode, 0x20 channel meters, 0x0b backlight timeout), and that is how we know it is
  installed. Verified in Control Surfaces > Setup on 2026-10-09. SCRL taps Rewind/Fast Fwd (one
  bar per step); shuttle emits jog ticks at a rate.
- Keys that flash the screen are unbound in the target app (macOS alert flash). FCP's Up/Down
  arrows are browser selection moves, not edit navigation; `;` and `'` are previous/next edit.
  Logic has no default for Option-comma/period. Check the real default before assuming.
- FCP's authoritative shortcut list is inside the bundle:
  `Contents/Resources/en.lproj/Default.commandset` (plist; `plutil -convert json`). Apple's web
  page truncates. Half speed is PlayRateHalf = Option-L / PlayRateMinusHalf = Option-J.
- Signing: `tools/make-signing-cert.sh` makes a local "Speed Editor Bridge Dev" identity so the
  Accessibility grant survives rebuilds (ad-hoc signatures lose it every build). Homebrew
  OpenSSL 4's default PKCS12 is unreadable by `security import`; the script forces SHA-1/3DES.
- No red anywhere in the UI (brand rule). Accent is brand cyan `#02CAF2`.
