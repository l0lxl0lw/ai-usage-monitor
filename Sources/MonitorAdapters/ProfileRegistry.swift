import Foundation
import MonitorCore

public final class ProfileRegistry {
    public private(set) var profiles: [Profile]
    private var identities: [UUID: String] = [:]
    public init(_ profiles: [Profile] = []) throws {
        self.profiles = []
        for profile in profiles { try add(profile) }
    }
    public func add(_ profile: Profile) throws {
        guard !profiles.contains(where: { $0.id == profile.id || ($0.source == profile.source && $0.canonicalHome == profile.canonicalHome) }) else { throw ModelError.duplicateHome }
        profiles.append(profile)
    }
    public func checkIdentity(_ identity: String?, profile: UUID) throws {
        guard let identity, !identity.isEmpty else { throw ModelError.identityMismatch }
        if let old = identities[profile], old != identity { throw ModelError.identityMismatch }
        identities[profile] = identity
    }
}
