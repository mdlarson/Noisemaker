# Noise Studio

A simple local noise generator (white / pink / brown) with controls for brightness, tone tilt, stereo drift, and volume.

This repo can be used in two ways:

1) As a lightweight local web app (served over HTTP).
2) As a self-contained macOS desktop app (`.app` / `.dmg`) via Electron (no App Store required).

## Features

- White / Pink / Brown noise
- Brightness, Tone Tilt, Stereo Drift, and Volume controls
- Persists settings in `localStorage` (your preferred mix loads on refresh)

## Option A: Run as a local web app (no build step)

1) Clone the repo:
```bash
git clone https://github.com/mdlarson/Noisemaker.git
cd Noisemaker
````

2. Start a simple static file server:

```bash
python3 -m http.server 8080
```

3. Open in your browser:

* [http://localhost:8080/](http://localhost:8080/)

Notes:

* Many browsers require a user gesture (click) before audio starts; click **Play** to begin.

## Option B: Build a macOS desktop app (.app / .dmg) with Electron

This produces a distributable `.dmg` you can copy to other Macs you own.

### Prerequisites

* Node.js (recommended install via Homebrew):

```bash
brew install node
```

### Install dependencies

From the repo root:

```bash
npm install
```

### Run locally (Dev)

```bash
npm start
```

### Build a DMG

```bash
npm run dist
```

Outputs are written to `dist/` (for example: a `.dmg` and a `mac-arm64/` app folder).

### `dist` vs `pack`

* `npm run pack` builds the app into an unpacked directory (useful for quick local testing).
* `npm run dist` builds distributable artifacts (e.g., `.dmg`) for copying to other machines.

### Gatekeeper note (unsigned app)

If you are not code-signing, macOS may warn when opening the app on a machine for the first time.
Typical workaround: Finder → right-click the app → **Open** (one-time per machine), or use **Privacy & Security** → **Open Anyway**.

### Customizing desktop window size

The Electron window defaults are defined in `main.js`:

* `width` / `height` set the initial window size
* `minHeight` (optional) sets a minimum
* `resizable` controls whether the user can resize
* `useContentSize: true` applies sizing to the web content area

After changing `main.js`, rebuild with `npm run dist` to update the packaged app.
