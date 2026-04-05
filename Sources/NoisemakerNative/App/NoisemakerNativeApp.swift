import SwiftUI

@main
struct NoisemakerNativeApp: App {
    @StateObject private var viewModel = NoiseViewModel()

    var body: some Scene {
        WindowGroup("Noise Studio") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 500, idealWidth: 560, maxWidth: 640)
        }
        .defaultSize(width: 560, height: 560)
        .windowResizability(.contentSize)
    }
}
