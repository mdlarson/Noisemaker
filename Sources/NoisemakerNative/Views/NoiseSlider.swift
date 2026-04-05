import SwiftUI

struct NoiseSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let normalizedValue = min(max(value / 100, 0), 1)
            let thumbDiameter: CGFloat = 20
            let leadingInset = thumbDiameter / 2
            let availableWidth = max(width - thumbDiameter, 1)
            let thumbOffset = availableWidth * normalizedValue

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 10)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.80, green: 0.56, blue: 0.28),
                                Color(red: 0.67, green: 0.41, blue: 0.18),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: leadingInset + thumbOffset, height: 10)

                Circle()
                    .fill(Color(red: 0.93, green: 0.74, blue: 0.49))
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 8, y: 3)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .offset(x: thumbOffset)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let position = min(max(gesture.location.x - leadingInset, 0), availableWidth)
                        value = Double(position / availableWidth) * 100
                    }
            )
        }
        .frame(height: 28)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value.rounded())) percent")
    }
}
