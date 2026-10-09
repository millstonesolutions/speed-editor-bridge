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

## Installing (no Xcode needed)

1. Download `Speed-Editor-Bridge-<version>.zip` from the
   [Releases](https://github.com/millstonesolutions/speed-editor-bridge/releases) page and unzip it.
2. Move **Speed Editor Bridge** to your Applications folder and open it.
3. macOS will say it cannot verify the developer, because the app is not notarized with Apple.
   Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to
   the message about Speed Editor Bridge. This is needed once per version.
4. Click **Allow keystrokes (Accessibility)** in the app's toolbar and turn on Speed Editor Bridge
   in the list that System Settings shows. The button disappears when the grant is in place.
5. Plug in the Speed Editor. The status dot turns on and the JOG light on the panel lights up.
   Open Final Cut Pro or Logic Pro; the profile switches by itself. Logic installs the Mackie
   Control surface automatically the first time the app is running alongside it.

Use the menu-bar item to turn on **Launch at Login** if you want it always available.

## Building

Requires Xcode 27 or later (Swift 6.4) on macOS 14 or later.

```bash
./make-app.sh release          # builds build/Speed Editor Bridge.app
open "build/Speed Editor Bridge.app"
```

The app needs Accessibility permission to send keystrokes. Ad-hoc signatures change on every
build and make macOS forget that grant, so run `tools/make-signing-cert.sh` once to create a local
signing certificate; `make-app.sh` uses it automatically.

`./make-release.sh` builds and zips the app into `dist/`. Pushing a tag such as `v0.2.0` runs the
GitHub Actions workflow, which builds the same zip on GitHub's macOS runners and attaches it to a
release, so releases do not depend on any one machine.

`swift run seprobe` is a command-line probe that unlocks the device and prints every key and
wheel event, useful for checking a unit.

## Project layout

- `Sources/SpeedEditorKit` — device layer: HID access, the challenge-response unlock, report parsing, LEDs.
- `Sources/SpeedEditorBridge` — the app: engine, keystroke sender, Mackie Control surface, profiles, SwiftUI.
- `Sources/seprobe` — the probe tool.

## License

Speed Editor Bridge is source-available under the Millstone Solutions Church and Ministry Use
License (see [LICENSE](LICENSE)). Christian churches and ministries may download, build and use it
for free. Anyone may read the source, test it and contribute. Other uses need written permission:
open an issue to ask.

The Speed Editor protocol was reimplemented from publicly documented descriptions of the device;
no third-party code is included. DaVinci Resolve and Speed Editor are trademarks of Blackmagic
Design; Final Cut Pro and Logic Pro are trademarks of Apple; Mackie Control is a trademark of
LOUD Technologies. This project is not affiliated with any of them. Built for First Baptist
Church Lake Dallas.
