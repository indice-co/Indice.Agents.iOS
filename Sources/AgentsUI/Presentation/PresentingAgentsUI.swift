#if canImport(UIKit)
//import SwiftUI
//import UIKit
//
//public extension View {
//    /// Adds a draggable Agent bubble above this view's window, including its sheets.
//    /// Apply once to a stable root view in each scene that should show the bubble.
//    @MainActor
//    func presentingAgentsUI(_ handle: AgentsUIHandle) -> some View {
//        background {
//            AgentsWindowAnchor(handle: handle)
//                .frame(width: 0, height: 0)
//                .accessibilityHidden(true)
//        }
//    }
//}
//
//private struct AgentsWindowAnchor: UIViewRepresentable {
//    let handle: AgentsUIHandle
//
//    func makeCoordinator() -> AgentsPresentationCoordinator {
//        AgentsPresentationCoordinator(handle: handle)
//    }
//
//    func makeUIView(context: Context) -> AgentsWindowProbe {
//        let view = AgentsWindowProbe()
//        view.isUserInteractionEnabled = false
//        view.windowChanged = { [weak coordinator = context.coordinator] window in
//            coordinator?.attach(to: window)
//        }
//        return view
//    }
//
//    func updateUIView(_ uiView: AgentsWindowProbe, context: Context) {
//        context.coordinator.update(handle: handle)
//        context.coordinator.attach(to: uiView.window)
//    }
//
//    static func dismantleUIView(_ uiView: AgentsWindowProbe, coordinator: AgentsPresentationCoordinator) {
//        uiView.windowChanged = nil
//        coordinator.detach()
//    }
//}
//
//private final class AgentsWindowProbe: UIView {
//    var windowChanged: ((UIWindow?) -> Void)?
//
//    override func didMoveToWindow() {
//        super.didMoveToWindow()
//        windowChanged?(window)
//    }
//}
//
//@MainActor
//private final class AgentsPresentationCoordinator: NSObject, UIAdaptivePresentationControllerDelegate {
//    
//    private var handle: AgentsUIHandle
//    
//    private weak var sourceWindow: UIWindow?
//    private weak var previousKeyWindow: UIWindow?
//    
//    private var window: AgentsOverlayWindow?
//    private var bubbleController: AgentsBubbleController?
//    private var agentController: UIHostingController<AgentsPresentedContent>?
//
//    init(handle: AgentsUIHandle) {
//        self.handle = handle
//        super.init()
//    }
//
//    func update(handle: AgentsUIHandle) {
//        guard self.handle !== handle else { return }
//        self.handle = handle
//        
//        bubbleController?.update(theme: handle.theme)
//        agentController?.rootView = agentContent()
//    }
//
//    func attach(to sourceWindow: UIWindow?) {
//        guard let sourceWindow, let scene = sourceWindow.windowScene else {
//            detach()
//            return
//        }
//        guard self.sourceWindow !== sourceWindow || window == nil else { return }
//        detach()
//        self.sourceWindow = sourceWindow
//
//        let controller = AgentsBubbleController(theme: handle.theme) { [weak self] in
//            self?.openAgent()
//        }
//        let window = AgentsOverlayWindow(windowScene: scene)
//        window.windowLevel = .init(rawValue: sourceWindow.windowLevel.rawValue + 1)
//        window.backgroundColor = .clear
//        window.rootViewController = controller
//        window.bubbleView = controller.bubbleView
//        self.bubbleController = controller
//        self.window = window
//        window.isHidden = false
//    }
//
//    func detach() {
//        guard let window else { return }
//        window.endEditing(true)
//        restoreKeyWindow()
//        window.isHidden = true
//        bubbleController?.dismiss(animated: false)
//        window.rootViewController = nil
//        agentController = nil
//        bubbleController = nil
//        self.window = nil
//        sourceWindow = nil
//    }
//
//    private func agentContent() -> AgentsPresentedContent {
//        AgentsPresentedContent(handle: handle) { [weak self] in
//            self?.closeAgent()
//        }
//    }
//
//    private func openAgent() {
//        guard let window, let bubbleController, !window.isAgentPresented else { return }
//        previousKeyWindow = window.windowScene?.windows.first(where: { $0.isKeyWindow })
//        previousKeyWindow?.endEditing(true)
//
//        // Reuse the host so collapsing the Agent UI keeps its conversation and draft.
//        let controller = agentController ?? UIHostingController(rootView: agentContent())
//        agentController = controller
//        controller.modalPresentationStyle = .pageSheet
//        
//        if #available(iOS 18.0, *) {
//            controller.preferredTransition = .zoom()) { context in
//                (context.sourceViewController as? AgentsBubbleController)?.bubbleView
//            }
//        }
//        
//        controller.presentationController?.delegate = self
//        window.isAgentPresented = true
//        window.makeKey()
//        bubbleController.present(controller, animated: !UIAccessibility.isReduceMotionEnabled)
//    }
//
//    private func closeAgent() {
//        guard
//            let window, window.isAgentPresented,
//            let controller = agentController,
//            !controller.isBeingDismissed
//        else { return }
//        
//        window.endEditing(true)
//        controller.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { [weak self, weak window] in
//            guard let window else { return }
//            self?.finishDismissal(from: window)
//        }
//    }
//
//    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
//        // Interactive zoom/sheet dismissals do not run closeAgent's completion.
//        // A cancelled gesture never reaches this callback, so the Agent UI stays interactive.
//        
//        guard
//            presentationController
//                .presentedViewController === agentController,
//            let window
//        else { return }
//        
//        finishDismissal(from: window)
//    }
//
//    private func finishDismissal(from window: AgentsOverlayWindow) {
//        guard self.window === window, window.isAgentPresented else { return }
//        window.endEditing(true)
//        restoreKeyWindow()
//        window.isAgentPresented = false
//    }
//
//    private func restoreKeyWindow() {
//        if window?.isKeyWindow == true {
//            let target = previousKeyWindow ?? sourceWindow
//            if let target, !target.isHidden, target.windowScene === window?.windowScene {
//                target.makeKey()
//            }
//        }
//        previousKeyWindow = nil
//    }
//}
//
///// Restrict touches using our own hosted view, independent of SwiftUI's internal hierarchy.
//final class AgentsOverlayWindow: UIWindow {
//    weak var bubbleView: UIView?
//    var isAgentPresented = false
//
//    override var canBecomeKey: Bool { isAgentPresented }
//
//    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
//        if isAgentPresented {
//            return super.hitTest(point, with: event)
//        }
//        guard let bubbleView, !bubbleView.isHidden, bubbleView.alpha > 0.01,
//              bubbleView.isUserInteractionEnabled,
//              bubbleView.point(inside: bubbleView.convert(point, from: self), with: event) else {
//            return nil
//        }
//        return super.hitTest(point, with: event)
//    }
//}
//
//private final class AgentsBubbleController: UIViewController {
//    private let host: UIHostingController<AgentsBubble>
//    private let openAgent: () -> Void
//    private var dragStart = CGPoint.zero
//    private var hasPosition = false
//    private let diameter: CGFloat = 56
//
//    var bubbleView: UIView {
//        loadViewIfNeeded()
//        return host.view
//    }
//
//    init(theme: Theme, openAgent: @escaping () -> Void) {
//        self.openAgent = openAgent
//        host = UIHostingController(rootView: AgentsBubble(theme: theme, openAgent: openAgent))
//        super.init(nibName: nil, bundle: nil)
//    }
//
//    @available(*, unavailable)
//    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        self.view.backgroundColor = .clear
//        self.addChild(host)
//        host.view.backgroundColor = .clear
//        
//        // UIKit uses the source view's shape when morphing the bubble into the sheet.
//        host.view.layer.cornerRadius = diameter / 2
//        host.view.clipsToBounds = true
//        self.view.addSubview(host.view)
//        host.didMove(toParent: self)
//
//        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragBubble(_:)))
//        pan.maximumNumberOfTouches = 1
//        pan.cancelsTouchesInView = true
//        host.view.addGestureRecognizer(pan)
//
//        // A drag must never also trigger the action when the finger lifts.
//        let tap = UITapGestureRecognizer(target: self, action: #selector(tapBubble))
//        tap.require(toFail: pan)
//        host.view.addGestureRecognizer(tap)
//    }
//
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        guard !view.bounds.isEmpty else { return }
//        let area = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 16, dy: 16)
//        let center = hasPosition ? host.view.center : CGPoint(
//            x: area.maxX - diameter / 2,
//            y: area.maxY - diameter / 2
//        )
//        host.view.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
//        host.view.center = clamped(center)
//        hasPosition = true
//    }
//
//    func update(theme: Theme) {
//        host.rootView = AgentsBubble(theme: theme, openAgent: openAgent)
//    }
//
//    @objc private func tapBubble() {
//        openAgent()
//    }
//
//    @objc private func dragBubble(_ gesture: UIPanGestureRecognizer) {
//        switch gesture.state {
//        case .began:
//            dragStart = host.view.center
//            fallthrough
//        case .changed, .ended, .cancelled:
//            let offset = gesture.translation(in: view)
//            let position = clamped(CGPoint(
//                x: dragStart.x + offset.x,
//                y: dragStart.y + offset.y))
//            
//            let duration = gesture.state == .changed ? 0.1 : 0.5
//            
//            UIView.animate(withDuration: duration, animations: { [unowned host] in
//                host.view.center = position
//            })
//        default:
//            break
//        }
//    }
//
//    private func clamped(_ point: CGPoint) -> CGPoint {
//        let area = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 16, dy: 16)
//        let radius = diameter / 2
//        let minX = min(area.minX + radius, area.midX)
//        let maxX = max(area.maxX - radius, area.midX)
//        let minY = min(area.minY + radius, area.midY)
//        let maxY = max(area.maxY - radius, area.midY)
//        
//        return CGPoint(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
//    }
//}
//
//private struct AgentsBubble: View {
//    let theme: Theme
//    let openAgent: () -> Void
//
//    var body: some View {
//        Image(systemName: "bubble.left.and.bubble.right.fill")
//            .font(.system(size: 24))
//            .foregroundStyle(.white)
//            .frame(width: 56, height: 56)
//            .background(theme.primaryColor, in: Circle())
//            .accessibilityElement(children: .ignore)
//            .accessibilityLabel(Text(.utility(.openAgents)))
//            .accessibilityAddTraits(.isButton)
//            .accessibilityAction(.default, openAgent)
//    }
//}
//
//private struct AgentsPresentedContent: View {
//    let handle: AgentsUIHandle
//    let close: () -> Void
//
//    @Environment(\.openURL) var openURLAction
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            AgentsHostScreen(
//                client: handle.client,
//                theme: handle.theme)
//                    .id(ObjectIdentifier(handle.client))
//        }
//        .background(.background)
//        .tint(handle.theme.primaryColor)
//        .accessibilityAction(.escape, close)
//    }
//}
#endif
