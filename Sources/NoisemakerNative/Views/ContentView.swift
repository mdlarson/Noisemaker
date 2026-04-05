import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: NoiseViewModel
    private let controlColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.16, green: 0.14, blue: 0.11),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    noisePicker

                    LazyVGrid(columns: controlColumns, alignment: .leading, spacing: 14) {
                        NoiseControlCard(
                            title: "Brightness",
                            value: viewModel.settings.brightness,
                            hint: viewModel.brightnessHint,
                            onChange: viewModel.updateBrightness
                        )

                        NoiseControlCard(
                            title: "Tone Tilt",
                            value: viewModel.settings.tone,
                            hint: viewModel.toneHint,
                            onChange: viewModel.updateTone
                        )

                        NoiseControlCard(
                            title: "Stereo Drift",
                            value: viewModel.settings.stereo,
                            hint: viewModel.stereoHint,
                            onChange: viewModel.updateStereo
                        )

                        NoiseControlCard(
                            title: "Volume",
                            value: viewModel.settings.volume,
                            hint: nil,
                            onChange: viewModel.updateVolume
                        )
                    }

                    Button(action: viewModel.togglePlayback) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PlayButtonStyle(isActive: viewModel.isPlaying))
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                }
                .padding(24)
            }
        }
    }

    private var noisePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.headline)
                .foregroundStyle(.orange)

            HStack(spacing: 10) {
                ForEach(NoiseType.allCases) { noise in
                    Button(action: { viewModel.selectNoise(noise) }) {
                        Text(noise.title)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(NoiseTypeButtonStyle(isSelected: viewModel.settings.noise == noise))
                }
            }

            Text(viewModel.noiseDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct NoiseTypeButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.orange.opacity(0.95) : Color.white.opacity(0.82))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.orange.opacity(configuration.isPressed ? 0.22 : 0.16)
                            : Color.white.opacity(configuration.isPressed ? 0.08 : 0.04)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.orange.opacity(0.7) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            }
            .shadow(color: isSelected ? Color.orange.opacity(0.12) : .clear, radius: 10, y: 4)
    }
}

private struct PlayButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? Color.orange.opacity(0.95) : Color.black.opacity(0.88))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isActive
                            ? AnyShapeStyle(Color.orange.opacity(configuration.isPressed ? 0.24 : 0.18))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.86, green: 0.60, blue: 0.31),
                                        Color(red: 0.74, green: 0.47, blue: 0.22),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isActive ? Color.orange.opacity(0.72) : Color.white.opacity(0.16),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: isActive ? Color.orange.opacity(0.12) : .black.opacity(0.25),
                radius: isActive ? 10 : 20,
                y: isActive ? 4 : 10
            )
            .opacity(configuration.isPressed ? 0.96 : 1)
    }
}
