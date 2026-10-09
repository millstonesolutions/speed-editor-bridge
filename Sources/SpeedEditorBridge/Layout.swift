import Foundation
import SpeedEditorKit

/// Where each key sits on the panel, in key units.
struct KeyTile: Identifiable {
    let key: SpeedEditorKey
    let x: Double
    let y: Double
    var w: Double = 1
    var id: SpeedEditorKey { key }
}

enum PanelLayout {
    static let columns = 10.7
    static let rows = 6.0
    static let wheelCenter = (x: 9.15, y: 4.0)
    static let wheelRadius = 1.45

    static let tiles: [KeyTile] = {
        let L = [0.0, 1.0, 2.0]
        let M = [3.35, 4.35, 5.35, 6.35]
        let R = [7.7, 8.7, 9.7]
        return [
            KeyTile(key: .smartInsert, x: L[0], y: 0), KeyTile(key: .append, x: L[1], y: 0), KeyTile(key: .rippleOverwrite, x: L[2], y: 0),
            KeyTile(key: .escape, x: M[0], y: 0), KeyTile(key: .syncBin, x: M[1], y: 0), KeyTile(key: .audioLevel, x: M[2], y: 0), KeyTile(key: .fullView, x: M[3], y: 0),
            KeyTile(key: .source, x: R[0], y: 0, w: 1.5), KeyTile(key: .timeline, x: R[0] + 1.5, y: 0, w: 1.5),

            KeyTile(key: .closeUp, x: L[0], y: 1), KeyTile(key: .placeOnTop, x: L[1], y: 1), KeyTile(key: .sourceOverwrite, x: L[2], y: 1),
            KeyTile(key: .transition, x: M[0], y: 1), KeyTile(key: .split, x: M[1], y: 1), KeyTile(key: .snap, x: M[2], y: 1), KeyTile(key: .rippleDelete, x: M[3], y: 1),
            KeyTile(key: .shuttle, x: R[0], y: 1), KeyTile(key: .jog, x: R[1], y: 1), KeyTile(key: .scroll, x: R[2], y: 1),

            KeyTile(key: .markIn, x: L[0], y: 2), KeyTile(key: .markOut, x: L[1], y: 2),
            KeyTile(key: .cam7, x: M[0], y: 2), KeyTile(key: .cam8, x: M[1], y: 2), KeyTile(key: .cam9, x: M[2], y: 2), KeyTile(key: .liveOverwrite, x: M[3], y: 2),

            KeyTile(key: .trimIn, x: L[0], y: 3), KeyTile(key: .trimOut, x: L[1], y: 3), KeyTile(key: .roll, x: L[2], y: 3),
            KeyTile(key: .cam4, x: M[0], y: 3), KeyTile(key: .cam5, x: M[1], y: 3), KeyTile(key: .cam6, x: M[2], y: 3), KeyTile(key: .videoOnly, x: M[3], y: 3),

            KeyTile(key: .slipSource, x: L[0], y: 4), KeyTile(key: .slipDestination, x: L[1], y: 4), KeyTile(key: .transitionDuration, x: L[2], y: 4),
            KeyTile(key: .cam1, x: M[0], y: 4), KeyTile(key: .cam2, x: M[1], y: 4), KeyTile(key: .cam3, x: M[2], y: 4), KeyTile(key: .audioOnly, x: M[3], y: 4),

            KeyTile(key: .cut, x: L[0], y: 5), KeyTile(key: .dissolve, x: L[1], y: 5), KeyTile(key: .smoothCut, x: L[2], y: 5),
            KeyTile(key: .stopPlay, x: M[0], y: 5, w: 4),
        ]
    }()
}
