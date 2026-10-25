import CoreGraphics
import Foundation
import Testing
@testable import YiyuCore

struct PanelPlacementTests {
    /// Visible frames in AppKit screen coordinates (origin bottom-left).
    let main = CGRect(x: 0, y: 0, width: 1920, height: 1055)
    let right = CGRect(x: 1920, y: 0, width: 1440, height: 875)
    let expanded = CGSize(width: 344, height: 600)
    let margin: CGFloat = 10

    private func frame(_ size: CGSize, anchor: CGPoint?, screens: [CGRect]? = nil) -> CGRect {
        PanelPlacement.frame(size: size, anchor: anchor, screens: screens ?? [main, right], margin: margin)
    }

    @Test func withoutAnAnchorItSitsInTheTopRightOfTheMainScreen() {
        let result = frame(expanded, anchor: nil)
        #expect(result.maxX == main.maxX - margin)
        #expect(result.maxY == main.maxY - margin)
        #expect(result.size == expanded)
    }

    @Test func theAnchorIsTheTopRightCorner() {
        let result = frame(expanded, anchor: CGPoint(x: 900, y: 1000))
        #expect(result.maxX == 900)
        #expect(result.maxY == 1000)
    }

    @Test func collapsingKeepsTheSameTopRightCorner() {
        let anchor = CGPoint(x: 900, y: 1000)
        let strip = frame(CGSize(width: 300, height: 46), anchor: anchor)
        #expect(strip.maxX == 900)
        #expect(strip.maxY == 1000)
    }

    @Test func aPanelThatWouldHangOffTheBottomIsLiftedUp() {
        let result = frame(expanded, anchor: CGPoint(x: 900, y: 200))
        #expect(result.minY == main.minY)
        #expect(result.maxX == 900)
    }

    @Test func aPanelThatWouldHangOffTheLeftIsPushedRight() {
        let result = frame(expanded, anchor: CGPoint(x: 100, y: 1000))
        #expect(result.minX == main.minX)
    }

    @Test func anAnchorOnTheSecondScreenStaysThere() {
        let result = frame(expanded, anchor: CGPoint(x: 3000, y: 800))
        #expect(right.contains(result))
    }

    @Test func anAnchorOnAnUnpluggedScreenComesBackToTheNearestOne() {
        let result = frame(expanded, anchor: CGPoint(x: 5000, y: 800))
        #expect(right.contains(result))
        #expect(frame(expanded, anchor: CGPoint(x: 5000, y: 800), screens: [main]).maxX == main.maxX)
    }

    @Test func aPanelTallerThanTheScreenIsShortened() {
        let tiny = CGRect(x: 0, y: 0, width: 1280, height: 500)
        let result = frame(expanded, anchor: nil, screens: [tiny])
        #expect(result.height == tiny.height - margin * 2)
        #expect(tiny.contains(result))
    }

    @Test func noScreensFallsBackToTheRequestedSize() {
        let result = frame(expanded, anchor: CGPoint(x: 500, y: 500), screens: [])
        #expect(result.size == expanded)
        #expect(result.maxX == 500)
    }
}

struct PanelDragTests {
    @Test func smallMovementsStayAClick() {
        var drag = PanelDrag(mouse: CGPoint(x: 100, y: 100), origin: CGPoint(x: 50, y: 60))
        #expect(drag.update(mouse: CGPoint(x: 102, y: 101)) == nil)
        #expect(drag.isDragging == false)
    }

    @Test func movingPastTheThresholdMovesTheWindowByTheSameAmount() {
        var drag = PanelDrag(mouse: CGPoint(x: 100, y: 100), origin: CGPoint(x: 50, y: 60))
        #expect(drag.update(mouse: CGPoint(x: 140, y: 80)) == CGPoint(x: 90, y: 40))
        #expect(drag.isDragging)
        // Coming back near the start keeps dragging rather than turning into a click again.
        #expect(drag.update(mouse: CGPoint(x: 101, y: 100)) == CGPoint(x: 51, y: 60))
    }
}

struct PanelAnchorStoreTests {
    private func makeStore() -> (PanelAnchorStore, UserDefaults) {
        let suite = "yiyu-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return (PanelAnchorStore(defaults: defaults), defaults)
    }

    @Test func remembersAndForgetsTheAnchor() {
        let (store, _) = makeStore()
        #expect(store.anchor == nil)
        store.anchor = CGPoint(x: 812.5, y: 640)
        #expect(store.anchor == CGPoint(x: 812.5, y: 640))
        store.anchor = nil
        #expect(store.anchor == nil)
    }

    @Test func ignoresMalformedValues() {
        let (store, defaults) = makeStore()
        defaults.set([1.0], forKey: PanelAnchorStore.key)
        #expect(store.anchor == nil)
        defaults.set("oops", forKey: PanelAnchorStore.key)
        #expect(store.anchor == nil)
    }
}
