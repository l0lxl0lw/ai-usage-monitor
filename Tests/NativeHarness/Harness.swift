import AppKit
import Foundation
import MonitorPresentation

// Synthetic-only, separate executable. Never copied into Relay.app or linked by Relay.
@main enum Harness {
    @MainActor static func main() {
        let application = NSApplication.shared
        let defaults = UserDefaults(suiteName: "Relay.NativeHarness")!
        defaults.removePersistentDomain(forName: "Relay.NativeHarness")
        let services = AppServices(defaults: defaults, startInfrastructure: false)
        SyntheticFixtures.populate(services.store)
        let delegate = PopoverController(services: services)
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
