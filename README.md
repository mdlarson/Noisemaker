# Noise Studio

Noise Studio is a native macOS ambient noise app built with SwiftUI and AVFoundation.

It replaces the original Electron/web version of Noisemaker with a lightweight desktop app that generates white, pink, and brown noise in-process using `AVAudioSourceNode`.

## Features

- White, pink, and brown noise
- Brightness, tone tilt, stereo drift, and volume controls
- Smooth play/pause fades
- Fast color crossfades
- Local settings persistence with `UserDefaults`
- Universal macOS build support for Apple Silicon and Intel Macs

## Requirements

- macOS 14 or later
- Xcode 26 or later

## Run In Xcode

1. Open `NoisemakerNative.xcodeproj`.
2. Select the `NoisemakerNative` scheme.
3. Select `My Mac`.
4. Press `Cmd-R`.

## Package A Release Build

Use the included packaging script:

```bash
cd path/to/Noisemaker
./scripts/package-macos.sh
```

That produces:

- `dist/Noise Studio.app`
- `dist/Noise-Studio-macOS.zip`

The script builds a universal Release app for both `arm64` and `x86_64`.

## Install On Your Macs

1. Copy `dist/Noise-Studio-macOS.zip` to the target Mac.
2. Unzip it.
3. Move `Noise Studio.app` into `/Applications`.
4. Launch it.

If macOS blocks the first launch on another machine, either right-click the app and choose `Open`, or run:

```bash
xattr -dr com.apple.quarantine "/Applications/Noise Studio.app"
```

## Project Layout

- `Sources/NoisemakerNative/App`: app entry and window setup
- `Sources/NoisemakerNative/Audio`: noise generation and DSP
- `Sources/NoisemakerNative/Models`: persisted settings and noise types
- `Sources/NoisemakerNative/ViewModels`: app state and persistence
- `Sources/NoisemakerNative/Views`: SwiftUI interface
- `scripts/package-macos.sh`: universal release packaging

## Notes

- The current packaging flow is intended for personal distribution across your own Macs.
- The app is not notarized or App Store packaged.
- For frictionless first-launch installs on any Mac, the next step would be Developer ID signing and notarization.
