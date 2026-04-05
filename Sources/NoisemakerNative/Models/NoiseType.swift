import Foundation

enum NoiseType: String, CaseIterable, Codable, Identifiable {
    case white
    case pink
    case brown

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}
