import CoreGraphics
import Foundation

/// Where the floating panel goes on screen. The saved anchor is the panel's top-right corner,
/// so collapsing and expanding grow and shrink the panel away from that corner.
/// All rectangles use AppKit screen coordinates (origin at the bottom-left).
public enum PanelPlacement {
    /// - Parameters:
    ///   - anchor: the remembered top-right corner, or `nil` for the default corner.
    ///   - screens: the screens' visible frames; the first one is the main screen.
    public static func frame(size: CGSize, anchor: CGPoint?, screens: [CGRect], margin: CGFloat) -> CGRect {
        guard let main = screens.first else {
            let corner = anchor ?? CGPoint(x: size.width, y: size.height)
            return CGRect(x: corner.x - size.width, y: corner.y - size.height, width: size.width, height: size.height)
        }
        let corner = anchor ?? CGPoint(x: main.maxX - margin, y: main.maxY - margin)
        let screen = screens.first { $0.contains(corner) } ?? nearest(to: corner, among: screens)

        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height - margin * 2)
        let x = clamp(corner.x - width, from: screen.minX, to: screen.maxX - width)
        let y = clamp(corner.y - height, from: screen.minY, to: screen.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public static func anchor(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.maxX, y: frame.maxY)
    }

    private static func nearest(to point: CGPoint, among screens: [CGRect]) -> CGRect {
        screens.min { distance(from: point, to: $0) < distance(from: point, to: $1) } ?? screens[0]
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func clamp(_ value: CGFloat, from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}

/// Tells a click from a drag and works out where the window should follow the pointer.
public struct PanelDrag: Sendable {
    /// Pointer movement, in points, before a press counts as a drag rather than a click.
    public static let threshold: CGFloat = 4

    private let startMouse: CGPoint
    private let startOrigin: CGPoint
    public private(set) var isDragging = false

    public init(mouse: CGPoint, origin: CGPoint) {
        startMouse = mouse
        startOrigin = origin
    }

    /// The window's new origin, or `nil` while the movement is still small enough to be a click.
    public mutating func update(mouse: CGPoint) -> CGPoint? {
        let dx = mouse.x - startMouse.x
        let dy = mouse.y - startMouse.y
        if !isDragging {
            guard (dx * dx + dy * dy).squareRoot() >= Self.threshold else { return nil }
            isDragging = true
        }
        return CGPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
    }
}

/// Remembers the panel's position between launches.
public struct PanelAnchorStore {
    public static let key = "panelAnchor"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var anchor: CGPoint? {
        get {
            guard let values = defaults.array(forKey: Self.key) as? [Double], values.count == 2 else { return nil }
            return CGPoint(x: values[0], y: values[1])
        }
        nonmutating set {
            guard let point = newValue else {
                defaults.removeObject(forKey: Self.key)
                return
            }
            defaults.set([Double(point.x), Double(point.y)], forKey: Self.key)
        }
    }
}
