import Combine
import Foundation

@MainActor
final class NoiseViewModel: ObservableObject {
    @Published private(set) var settings: NoiseSettings
    @Published private(set) var isPlaying = false

    private let engine = NoiseEngine()
    private let persistence: SettingsPersistence
    private var pendingSaveTask: Task<Void, Never>?

    init() {
        let persistence = SettingsPersistence()
        self.persistence = persistence
        settings = persistence.load()
        engine.apply(settings: settings, immediate: true)
    }

    func togglePlayback() {
        if isPlaying {
            engine.pause()
            isPlaying = false
        } else {
            do {
                try engine.play()
                isPlaying = true
            } catch {
                print("Unable to start audio engine: \(error)")
            }
        }
    }

    func selectNoise(_ noise: NoiseType) {
        guard settings.noise != noise else { return }
        settings.noise = noise
        persistAndApply()
    }

    func updateBrightness(_ value: Double) {
        settings.brightness = value
        persistAndApply()
    }

    func updateTone(_ value: Double) {
        settings.tone = value
        persistAndApply()
    }

    func updateStereo(_ value: Double) {
        settings.stereo = value
        persistAndApply()
    }

    func updateVolume(_ value: Double) {
        settings.volume = value
        persistAndApply()
    }

    var brightnessHint: String {
        switch settings.brightness {
        case ..<20:
            return "Soften hiss for bedtime listening"
        case 70...:
            return "Boost shimmer to mask chatter"
        default:
            return "Balance for everyday focus"
        }
    }

    var toneHint: String {
        switch settings.tone {
        case ..<45:
            return "Emphasize bass for a cozy wash"
        case 55...:
            return "Add upper detail to mask chatter"
        default:
            return "Balance highs and lows"
        }
    }

    var stereoHint: String {
        if settings.stereo == 0 {
            return "Centered signal, no movement"
        }

        return "Set slow autopan width: \(Int(settings.stereo.rounded()))%"
    }

    var noiseDescription: String {
        switch settings.noise {
        case .white:
            return "Bright and broadband. Best for masking speech and sharp distractions."
        case .pink:
            return "Balanced and gentler on the ear. A strong default for focus or sleep."
        case .brown:
            return "Darker and bass-heavier. Better for a softer, lower rumble."
        }
    }

    private func persistAndApply() {
        engine.apply(settings: settings)
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSaveTask?.cancel()
        let snapshot = settings

        pendingSaveTask = Task { [persistence] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            persistence.save(snapshot)
        }
    }

    deinit {
        pendingSaveTask?.cancel()
    }
}

private struct SettingsPersistence {
    private let defaults = UserDefaults.standard
    private let key = "noiseStudioSettings"

    func load() -> NoiseSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        return (try? JSONDecoder().decode(NoiseSettings.self, from: data)) ?? .default
    }

    func save(_ settings: NoiseSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
