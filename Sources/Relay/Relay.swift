import AppKit
import MonitorPresentation

@main enum RelayApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = PopoverController()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
