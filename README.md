# Noise Studio

Simple local web app that generates adjustable white, pink, and brown noise with brightness, tone, stereo, and volume controls.

## Getting Started

1. Clone or download this folder.
2. Serve the files over HTTP (any static server works):

```bash
python3 -m http.server 8080
```

3. Visit `http://localhost:8080/` in your browser (Arc/Chrome/Safari).

## Usage

- Select a noise color, then click **Play** to start audio.
- Adjust sliders:
  - **Brightness** boosts or softens high frequencies.
  - **Tone Tilt** biases the mix toward lows or highs.
  - **Stereo Drift** adds slow autopan for a wider image.
  - **Volume** sets the overall level.
- Settings persist in `localStorage`, so your preferred mix loads on refresh.

## Notes

- Best experienced with headphones in a quiet workspace.
- Built with vanilla HTML, CSS, and JS—no build step required.
