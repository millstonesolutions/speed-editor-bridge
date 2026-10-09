import Foundation
import AppKit
import ApplicationServices

/// Posts synthetic keystrokes to the frontmost application.
final class KeySender {
    private let source = CGEventSource(stateID: .hidSystemState)

    static var isTrusted: Bool { AXIsProcessTrusted() }
    private static let functionKeys: Set<String> = ["left", "right", "up", "down", "home", "end", "pageup", "pagedown", "forwarddelete"]

    static func requestTrust() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private func flags(for combo: KeyCombo) -> CGEventFlags {
        var f = CGEventFlags()
        if combo.command { f.insert(.maskCommand) }
        if combo.shift { f.insert(.maskShift) }
        if combo.option { f.insert(.maskAlternate) }
        if combo.control { f.insert(.maskControl) }
        if Self.functionKeys.contains(combo.key) { f.insert(.maskSecondaryFn); f.insert(.maskNumericPad) }
        return f
    }

    private func post(_ combo: KeyCombo, down: Bool) {
        guard let code = KeyCodes.code(for: combo.key),
              let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
        event.flags = flags(for: combo)
        event.post(tap: .cghidEventTap)
    }

    func keyDown(_ combo: KeyCombo) { post(combo, down: true) }
    func keyUp(_ combo: KeyCombo) { post(combo, down: false) }

    func press(_ combo: KeyCombo) {
        post(combo, down: true)
        post(combo, down: false)
    }

    func press(_ combos: [KeyCombo]) { combos.forEach(press) }

    /// Hold `held`, tap `tapped`, release `held`.
    func pressWhileHolding(_ held: KeyCombo, tap tapped: KeyCombo) {
        keyDown(held)
        press(tapped)
        keyUp(held)
    }
}
