import AppKit
import SwiftUI

@main enum RelayApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = PopoverController()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor final class PopoverController: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private let services = AppServices()
    private var outsideClick: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◉ Relay"
        item.button?.setAccessibilityLabel("Open Relay usage and agent monitor")
        item.button?.target = self; item.button?.action = #selector(toggle)
        popover.behavior = .applicationDefined; popover.delegate = self
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
        popover.contentViewController = NSHostingController(rootView: PopoverRoot(services: services, close: { [weak self] in self?.popover.performClose(nil) }))
        if CommandLine.arguments.contains("--show") { DispatchQueue.main.async { if !self.popover.isShown { self.toggle() } } }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { toggle() }
        return false
    }
    @objc func toggle() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        let height = min(660, max(300, (button.window?.screen?.visibleFrame.height ?? 700) - 64))
        popover.contentSize = NSSize(width: 420, height: height)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        if let window = popover.contentViewController?.view.window {
            window.setAccessibilityElement(true)
            window.setAccessibilityRole(.window)
            window.setAccessibilityLabel("Relay popover")
            window.makeKey()
            NSAccessibility.post(element: window, notification: .created)
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        services.shutdown()
    }
}
