import CoreGraphics
import Foundation

enum WindowPlacement {
    static func clamp(_ frame: CGRect, inside screen: CGRect) -> CGRect {
        let bounds = screen.insetBy(dx: 8, dy: 8)
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        let x = min(max(frame.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(frame.minY, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func menu(anchor: CGRect, size: CGSize, screen: CGRect) -> CGRect {
        let proposed = CGRect(x: anchor.midX - size.width / 2,
                              y: anchor.minY - size.height - 6, width: size.width, height: size.height)
        return clamp(proposed, inside: screen)
    }

    static func centered(size: CGSize, screen: CGRect) -> CGRect {
        let proposed = CGRect(x: screen.midX - size.width / 2,
                              y: screen.midY - size.height / 2, width: size.width, height: size.height)
        return clamp(proposed, inside: screen)
    }
}
