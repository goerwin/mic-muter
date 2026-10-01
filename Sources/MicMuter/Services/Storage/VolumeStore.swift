import Foundation

/// Persists fallback-mute state (input level zeroed because the device
/// has no writable mute control) and the saved pre-mute levels.
@MainActor
protocol VolumeStoring: AnyObject {
    func saveInputLevel(_ values: [VolumeSnapshot], forDeviceUID uid: String)
    func savedInputLevel(forDeviceUID uid: String) -> [VolumeSnapshot]?
    func clearSavedInputLevel(forDeviceUID uid: String)
    func isFallbackMuteActive(forDeviceUID uid: String) -> Bool
    func setFallbackMuteActive(_ isActive: Bool, forDeviceUID uid: String)
    func isRestorePending(forDeviceUID uid: String) -> Bool
    func setRestorePending(_ isPending: Bool, forDeviceUID uid: String)
}

@MainActor
final class VolumeStore: VolumeStoring {
    private let fallbackMutePrefix = "mutedByInputVolume."
    private let savedVolumePrefix = "savedInputVolume."
    private let restorePendingPrefix = "inputVolumeRestorePending."
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveInputLevel(_ values: [VolumeSnapshot], forDeviceUID uid: String) {
        let saved = SavedVolume(values: values)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: savedVolumePrefix + uid)
    }

    func savedInputLevel(forDeviceUID uid: String) -> [VolumeSnapshot]? {
        guard let data = defaults.data(forKey: savedVolumePrefix + uid) else { return nil }
        guard let saved = try? JSONDecoder().decode(SavedVolume.self, from: data) else { return nil }
        return saved.values
    }

    func clearSavedInputLevel(forDeviceUID uid: String) {
        defaults.removeObject(forKey: savedVolumePrefix + uid)
        defaults.removeObject(forKey: fallbackMutePrefix + uid)
        defaults.removeObject(forKey: restorePendingPrefix + uid)
    }

    func isFallbackMuteActive(forDeviceUID uid: String) -> Bool {
        defaults.bool(forKey: fallbackMutePrefix + uid)
    }

    func setFallbackMuteActive(_ isActive: Bool, forDeviceUID uid: String) {
        defaults.set(isActive, forKey: fallbackMutePrefix + uid)
    }

    func isRestorePending(forDeviceUID uid: String) -> Bool {
        defaults.bool(forKey: restorePendingPrefix + uid)
    }

    func setRestorePending(_ isPending: Bool, forDeviceUID uid: String) {
        defaults.set(isPending, forKey: restorePendingPrefix + uid)
    }
}

private struct SavedVolume: Codable {
    let values: [VolumeSnapshot]
}
