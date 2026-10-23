#if canImport(UIKit)
import Testing
import SwiftUI
import UIKit
@testable import AgentsUI

@Suite(.serialized)
@MainActor
struct AgentsOverlayWindowTests {
    @Test func emptyOverlayPassesTouchesThrough() {
        let (window, bubble) = makeWindow()
        defer { window.isHidden = true }

        #expect(window.hitTest(CGPoint(x: 20, y: 20), with: nil) == nil)
        #expect(window.hitTest(bubble.center, with: nil)?.isDescendant(of: bubble) == true)
        #expect(!window.canBecomeKey)
    }

    @Test func hitRegionFollowsTheDraggedBubble() {
        let (window, bubble) = makeWindow()
        defer { window.isHidden = true }
        let oldCenter = bubble.center
        bubble.center = CGPoint(x: 70, y: 100)

        #expect(window.hitTest(oldCenter, with: nil) == nil)
        #expect(window.hitTest(bubble.center, with: nil)?.isDescendant(of: bubble) == true)
    }

    @Test func hiddenBubbleDoesNotBlockApp() {
        let (window, bubble) = makeWindow()
        defer { window.isHidden = true }
        bubble.isHidden = true

        #expect(window.hitTest(bubble.center, with: nil) == nil)
    }

    @Test func presentedAgentOwnsWindowUntilCollapsed() {
        let (window, _) = makeWindow()
        defer { window.isHidden = true }
        let point = CGPoint(x: 20, y: 20)
        window.isAgentPresented = true

        #expect(window.canBecomeKey)
        #expect(window.hitTest(point, with: nil) != nil)

        window.isAgentPresented = false
        #expect(!window.canBecomeKey)
        #expect(window.hitTest(point, with: nil) == nil)
    }

    private func makeWindow() -> (AgentsOverlayWindow, UIView) {
        let window = AgentsOverlayWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        let host = UIHostingController(rootView:
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .frame(width: 56, height: 56)
                .background(.blue, in: Circle())
        )
        root.addChild(host)
        let bubble = host.view!
        bubble.frame = CGRect(x: 300, y: 700, width: 56, height: 56)
        bubble.addGestureRecognizer(UITapGestureRecognizer())
        root.view.addSubview(bubble)
        host.didMove(toParent: root)
        window.bubbleView = bubble
        window.isHidden = false
        window.layoutIfNeeded()
        return (window, bubble)
    }
}
#endif
