import Foundation

extension CoreAudioDeviceManager {
    func saveInputLevel(_ values: [VolumeValue], for device: AudioInputDevice) {
        let saved = SavedVolume(values: values)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: savedVolumePrefix + device.uid)
    }

    func savedVolume(for device: AudioInputDevice) -> SavedVolume? {
        guard let data = UserDefaults.standard.data(forKey: savedVolumePrefix + device.uid) else { return nil }
        return try? JSONDecoder().decode(SavedVolume.self, from: data)
    }

    func clearSavedInputLevel(for device: AudioInputDevice) {
        UserDefaults.standard.removeObject(forKey: savedVolumePrefix + device.uid)
        UserDefaults.standard.removeObject(forKey: fallbackMutePrefix + device.uid)
    }
}
