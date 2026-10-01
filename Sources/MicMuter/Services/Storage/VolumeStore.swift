import Foundation

@MainActor
protocol VolumeStoring: AnyObject {
    func fallbackState(forDeviceUID uid: String) -> VolumeFallbackState?
    func saveFallbackState(_ state: VolumeFallbackState, forDeviceUID uid: String) throws
    func clearFallbackState(forDeviceUID uid: String)
}

@MainActor
final class VolumeStore: VolumeStoring {
    private let fallbackMutePrefix = "mutedByInputVolume."
    private let savedVolumePrefix = "savedInputVolume."
    private let restorePendingPrefix = "inputVolumeRestorePending."
    private let statePrefix = "inputVolumeFallback."
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fallbackState(forDeviceUID uid: String) -> VolumeFallbackState? {
        if let data = defaults.data(forKey: statePrefix + uid) {
            return try? JSONDecoder().decode(VolumeFallbackState.self, from: data)
        }
        guard let data = defaults.data(forKey: savedVolumePrefix + uid) else { return nil }
        guard let saved = try? JSONDecoder().decode(SavedVolume.self, from: data) else { return nil }
        let phase: VolumeFallbackState.Phase =
            defaults.bool(forKey: restorePendingPrefix + uid) ? .restoring : .muted
        return VolumeFallbackState(values: saved.values, phase: phase)
    }

    func saveFallbackState(_ state: VolumeFallbackState, forDeviceUID uid: String) throws {
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: statePrefix + uid)
        clearLegacyState(forDeviceUID: uid)
    }

    func clearFallbackState(forDeviceUID uid: String) {
        defaults.removeObject(forKey: statePrefix + uid)
        clearLegacyState(forDeviceUID: uid)
    }

    private func clearLegacyState(forDeviceUID uid: String) {
        defaults.removeObject(forKey: savedVolumePrefix + uid)
        defaults.removeObject(forKey: fallbackMutePrefix + uid)
        defaults.removeObject(forKey: restorePendingPrefix + uid)
    }
}

private struct SavedVolume: Codable {
    let values: [VolumeSnapshot]
}
