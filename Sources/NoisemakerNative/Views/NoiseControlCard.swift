import SwiftUI

struct NoiseControlCard: View {
    let title: String
    let value: Double
    let hint: String?
    let onChange: @MainActor @Sendable (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.orange)

                Spacer()

                Text("\(Int(value.rounded()))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            NoiseSlider(
                title: title,
                value: Binding(
                    get: { value },
                    set: { newValue in
                        onChange(newValue)
                    }
                )
            )

            if let hint {
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}
