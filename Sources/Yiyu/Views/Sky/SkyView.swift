import AppKit
import QuartzCore
import SwiftUI
import YiyuCore

/// What a `SkyView` shows: one kind of weather, painted for the panel or for the badge's moon gate.
struct SkyContent: Equatable {
    enum Surface {
        case panel, gate
    }

    let surface: Surface
    let scene: WeatherScene
    let colors: SkyColors
    /// `false` with Reduce Motion on: one still moment instead.
    let isAnimated: Bool

    func makeLayer(size: CGSize, scale: CGFloat) -> CALayer {
        switch surface {
        case .panel: PanelSkyLayers(scene: scene, colors: colors, isAnimated: isAnimated, scale: scale).make(size: size)
        case .gate: GateSkyLayers(scene: scene, colors: colors, isAnimated: isAnimated, scale: scale).make(size: size)
        }
    }
}

/// Hosts the weather's layers, rebuilding them when the weather, the size or the screen's scale
/// changes. Clicks pass straight through to whatever is underneath.
final class SkyHostView: NSView {
    var content: SkyContent? {
        didSet {
            if content != oldValue { rebuild() }
        }
    }

    private var builtSize: CGSize = .zero
    private var builtScale: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// AppKit then keeps the backing layer's geometry top-down too, which the weather layers expect.
    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        rebuildIfNeeded()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rebuildIfNeeded()
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func rebuildIfNeeded() {
        if bounds.size != builtSize || scale != builtScale { rebuild() }
    }

    private func rebuild() {
        builtSize = bounds.size
        builtScale = scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.sublayers = nil
        if let content, bounds.width > 0, bounds.height > 0 {
            layer?.addSublayer(content.makeLayer(size: bounds.size, scale: scale))
        }
        CATransaction.commit()
    }
}

struct SkyView: NSViewRepresentable {
    let content: SkyContent

    func makeNSView(context: Context) -> SkyHostView {
        SkyHostView(frame: .zero)
    }

    func updateNSView(_ view: SkyHostView, context: Context) {
        view.content = content
    }
}

/// The weather outside, painted behind the expanded panel: drizzle when it rains, sunshine on a
/// clear day. Nothing at all when it is cloudy, or before the weather is set up.
struct PanelSky: View {
    /// Optional, so previews of the panel without weather still draw.
    @Environment(WeatherModel.self) private var weather: WeatherModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let scene = weather?.scene ?? .calm
        ZStack {
            if !scene.isCalm {
                SkyView(content: SkyContent(surface: .panel, scene: scene, colors: .current, isAnimated: !reduceMotion))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.5), value: scene)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The weather in the opening of the badge's moon gate, under `MoonGateMark`'s rim and branch.
struct GateSky: View {
    let scene: WeatherScene

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !scene.isCalm {
            SkyView(content: SkyContent(surface: .gate, scene: scene, colors: .current, isAnimated: !reduceMotion))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
