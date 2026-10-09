# Speed Editor Bridge

Use a DaVinci Resolve Speed Editor with Final Cut Pro and Logic Pro on Apple silicon Macs.

The app unlocks the Speed Editor over USB, then turns its keys and wheel into keystrokes for
Final Cut Pro and into a Mackie Control surface for Logic Pro. Mappings stay as close to the
Resolve legends as the target app allows: IN and OUT mark in and out, CUT cuts, RIPL DEL ripple
deletes, and SHTL / JOG / SCRL drive the wheel the way they do in Resolve. Every key can be
overridden per application from the mapping window.

## Features

- Three wheel modes. In Final Cut, JOG steps frames, SHTL drives J / K / L speed levels, and
  SCRL walks edit points. In Logic, JOG is the Mackie jog wheel, SHTL shuttles, SCRL moves by bar.
- Hold TRIM IN, TRIM OUT or ROLL and turn the wheel to trim that edge in Final Cut.
- Logic installs the Mackie Control surface by itself when the app is running.
- Profile follows the frontmost app. The device is released when DaVinci Resolve comes to the
  front and taken back for Final Cut or Logic.
- Mapping window shows the panel with each key's action, click to change, per-key and per-profile
  reset, export and import. Only overrides are stored, so updated defaults still arrive.
- Menu-bar status item with profile lock and Launch at Login.

## Building

Requires Xcode 27 or later (Swift 6.4) on macOS 14 or later.

```bash
./make-app.sh release          # builds build/Speed Editor Bridge.app
open "build/Speed Editor Bridge.app"
```

The app needs Accessibility permission to send keystrokes. Ad-hoc signatures change on every
build and make macOS forget that grant, so run `tools/make-signing-cert.sh` once to create a local
signing certificate; `make-app.sh` uses it automatically.

`swift run seprobe` is a command-line probe that unlocks the device and prints every key and
wheel event, useful for checking a unit.

## Project layout

- `Sources/SpeedEditorKit` — device layer: HID access, the challenge-response unlock, report parsing, LEDs.
- `Sources/SpeedEditorBridge` — the app: engine, keystroke sender, Mackie Control surface, profiles, SwiftUI.
- `Sources/seprobe` — the probe tool.

## Notes

The Speed Editor protocol was reimplemented from publicly documented descriptions of the device;
no third-party code is included. Built for First Baptist Church Lake Dallas.
