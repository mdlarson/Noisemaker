import Foundation

struct NoiseSettings: Codable, Equatable {
    var noise: NoiseType
    var volume: Double
    var brightness: Double
    var tone: Double
    var stereo: Double

    static let `default` = NoiseSettings(
        noise: .pink,
        volume: 25,
        brightness: 25,
        tone: 25,
        stereo: 25
    )
}
