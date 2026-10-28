import AppKit
import SwiftUI
import MonitorCore

/// Preserve actual native clip offsets, independently for each in-popover route.
/// Anchor IDs alone cannot restore a nested SwiftUI stack's scroll position.
struct ScrollMemory: NSViewRepresentable {
    let route: Route
    @Binding var offsets: [Route: Double]
    func makeNSView(context: Context) -> NSView { NSView() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.route != route { coordinator.restoring = true }
        coordinator.save = { route, offset in
            if abs((offsets[route] ?? 0) - offset) > 0.5 { offsets[route] = offset }
        }
        // The representable joins the scroll hierarchy after this update callback.
        DispatchQueue.main.async {
            guard let scroll = view.enclosingScrollView else { return }
            coordinator.attach(scroll)
            guard coordinator.route != route else { return }
            coordinator.restoring = true
            coordinator.route = route
            let target = offsets[route] ?? 0
            DispatchQueue.main.async {
                guard coordinator.route == route else { return }
                scroll.layoutSubtreeIfNeeded()
                let limit = max(0, (scroll.documentView?.bounds.height ?? 0) - scroll.contentView.bounds.height)
                scroll.contentView.scroll(to: NSPoint(x: 0, y: min(limit, max(0, target))))
                scroll.reflectScrolledClipView(scroll.contentView)
                coordinator.restoring = false
            }
        }
    }
    final class Coordinator {
        var route: Route?
        var restoring = false
        var save: ((Route, Double) -> Void)?
        private var observer: NSObjectProtocol?
        private weak var scroll: NSScrollView?
        func attach(_ scroll: NSScrollView) {
            guard self.scroll !== scroll else { return }
            if let observer { NotificationCenter.default.removeObserver(observer) }
            self.scroll = scroll
            scroll.contentView.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self] _ in
                guard let self, !self.restoring, let route = self.route, let scroll = self.scroll else { return }
                self.save?(route, scroll.contentView.bounds.origin.y)
            }
        }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}
