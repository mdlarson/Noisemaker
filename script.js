const noiseButtons = document.querySelectorAll(".noise-button");
const playToggle = document.getElementById("play-toggle");
const volumeSlider = document.getElementById("volume-slider");
const brightnessSlider = document.getElementById("brightness-slider");
const toneSlider = document.getElementById("tone-slider");
const stereoSlider = document.getElementById("stereo-slider");

const brightnessHint = document.getElementById("brightness-hint");
const toneHint = document.getElementById("tone-hint");
const stereoHint = document.getElementById("stereo-hint");

const AudioContextClass = window.AudioContext || window.webkitAudioContext;

let audioCtx;
let gainNode;
let toneFilter;
let tiltFilter;
let stereoPanner;
let panLfo;
let panDepthGain;
let fadeGain;
let currentSource;
let fadeTimeout;
let isPlaying = false;
let currentNoise = "pink";

const bufferCache = new Map();

const controlValues = {
  brightness: Number(brightnessSlider?.value ?? 25),
  tone: Number(toneSlider?.value ?? 25),
  stereo: Number(stereoSlider?.value ?? 25),
};
const defaultFadeSeconds = 1;

function ensureAudioGraph() {
  if (audioCtx) return true;
  if (!AudioContextClass) {
    alert("Sorry, this browser does not support the Web Audio API.");
    return false;
  }

  audioCtx = new AudioContextClass();

  toneFilter = audioCtx.createBiquadFilter();
  toneFilter.type = "lowpass";
  toneFilter.Q.value = 0.7;

  tiltFilter = audioCtx.createBiquadFilter();
  tiltFilter.type = "peaking";
  tiltFilter.frequency.value = 1000;
  tiltFilter.Q.value = 0.7;
  toneFilter.connect(tiltFilter);

  stereoPanner = audioCtx.createStereoPanner();
  tiltFilter.connect(stereoPanner);

  panDepthGain = audioCtx.createGain();
  panDepthGain.gain.value = 0;
  panLfo = audioCtx.createOscillator();
  panLfo.type = "sine";
  panLfo.frequency.value = 0.08;
  panLfo.connect(panDepthGain).connect(stereoPanner.pan);
  panLfo.start();

  fadeGain = audioCtx.createGain();
  fadeGain.gain.value = 0;
  stereoPanner.connect(fadeGain);

  gainNode = audioCtx.createGain();
  fadeGain.connect(gainNode);
  gainNode.connect(audioCtx.destination);

  applyAllSettings();
  updateVolume();
  return true;
}

function applyAllSettings() {
  applyBrightnessFromSlider();
  applyToneTilt();
  applyStereoDrift();
}

function getBaseVolume() {
  return Number(volumeSlider?.value ?? 50) / 100;
}

function updateVolume() {
  if (!gainNode) return;
  const target = getBaseVolume();
  gainNode.gain.setTargetAtTime(target, audioCtx.currentTime, 0.01);
  if (volumeSlider) {
    volumeSlider.setAttribute("aria-valuenow", volumeSlider.value);
  }
}

function applyBrightnessFromSlider() {
  const value = controlValues.brightness;
  const minFreq = 800;
  const maxFreq = 18000;
  const ratio = value / 100;
  const freq = minFreq * Math.pow(maxFreq / minFreq, ratio);
  if (toneFilter && audioCtx) {
    toneFilter.frequency.setTargetAtTime(freq, audioCtx.currentTime, 0.05);
  }
  if (brightnessHint) {
    let descriptor = "Balanced tone for everyday focus.";
    if (value <= 20) descriptor = "Dark tone softens hiss for bedtime listening.";
    else if (value >= 70) descriptor = "Bright tone boosts shimmer to mask chatter.";
    brightnessHint.textContent = descriptor;
  }
}

function applyToneTilt() {
  const value = controlValues.tone;
  if (tiltFilter && audioCtx) {
    const gain = ((value - 50) / 50) * 8;
    tiltFilter.gain.setTargetAtTime(gain, audioCtx.currentTime, 0.1);
  }
  if (toneHint) {
    if (value < 45) toneHint.textContent = "Warm tilt emphasizes bass for a cozy wash.";
    else if (value > 55) toneHint.textContent = "Crisp tilt adds upper detail to mask chatter.";
    else toneHint.textContent = "Neutral tilt keeps lows and highs balanced.";
  }
}

function applyStereoDrift() {
  const value = controlValues.stereo;
  if (panDepthGain) {
    const depth = (value / 100) * 0.8;
    panDepthGain.gain.setTargetAtTime(depth, audioCtx?.currentTime ?? 0, 0.1);
  }
  if (stereoHint) {
    if (value === 0) stereoHint.textContent = "Centered signal—no movement.";
    else stereoHint.textContent = `Slow autopan width: ${Math.round((value / 100) * 100)}%`;
  }
}

function getFadeDuration() {
  return defaultFadeSeconds;
}

function setNoiseType(type) {
  currentNoise = type;
  noiseButtons.forEach((btn) => {
    const pressed = btn.dataset.noise === type;
    btn.setAttribute("aria-pressed", String(pressed));
  });
  if (isPlaying) {
    startNoise();
  }
}

function getNoiseBuffer(type) {
  if (bufferCache.has(type)) {
    return bufferCache.get(type);
  }
  if (!audioCtx) throw new Error("Audio context not initialized.");
  let buffer;
  switch (type) {
    case "pink":
      buffer = createPinkNoiseBuffer(audioCtx);
      break;
    case "brown":
      buffer = createBrownNoiseBuffer(audioCtx);
      break;
    case "white":
    default:
      buffer = createWhiteNoiseBuffer(audioCtx);
  }
  bufferCache.set(type, buffer);
  return buffer;
}

async function startNoise() {
  if (!ensureAudioGraph()) return;
  try {
    await audioCtx.resume();
  } catch (err) {
    console.error("Unable to resume audio context", err);
    return;
  }
  stopNoise({ immediate: true });
  const source = audioCtx.createBufferSource();
  source.buffer = getNoiseBuffer(currentNoise);
  source.loop = true;
  source.connect(toneFilter);
  source.start();
  currentSource = source;

  const now = audioCtx.currentTime;
  const fadeDur = getFadeDuration();
  if (fadeGain) {
    fadeGain.gain.cancelScheduledValues(now);
    fadeGain.gain.setValueAtTime(0, now);
    fadeGain.gain.linearRampToValueAtTime(1, now + fadeDur);
  }

  isPlaying = true;
  playToggle.textContent = "Pause";
}

function stopNoise({ immediate = false } = {}) {
  if (!audioCtx) {
    isPlaying = false;
    return;
  }
  const now = audioCtx.currentTime;
  const fadeDur = immediate ? 0.02 : getFadeDuration();
  if (fadeGain) {
    fadeGain.gain.cancelScheduledValues(now);
    fadeGain.gain.setValueAtTime(fadeGain.gain.value, now);
    fadeGain.gain.linearRampToValueAtTime(0, now + fadeDur);
  }

  const finalize = () => {
    if (currentSource) {
      try {
        currentSource.stop();
      } catch (_) {
        // already stopped
      }
      currentSource.disconnect();
      currentSource = null;
    }
    isPlaying = false;
  playToggle.textContent = "Play";
  };

  if (immediate) {
    finalize();
  } else {
    if (fadeTimeout) clearTimeout(fadeTimeout);
    fadeTimeout = setTimeout(finalize, fadeDur * 1000 + 20);
  }
}

function createWhiteNoiseBuffer(context) {
  const duration = 3;
  const channels = 2;
  const frameCount = Math.floor(duration * context.sampleRate);
  const buffer = context.createBuffer(channels, frameCount, context.sampleRate);
  for (let channel = 0; channel < channels; channel += 1) {
    const data = buffer.getChannelData(channel);
    for (let i = 0; i < frameCount; i += 1) {
      data[i] = Math.random() * 2 - 1;
    }
  }
  return buffer;
}

function createPinkNoiseBuffer(context) {
  const duration = 3;
  const channels = 2;
  const frameCount = Math.floor(duration * context.sampleRate);
  const buffer = context.createBuffer(channels, frameCount, context.sampleRate);

  for (let channel = 0; channel < channels; channel += 1) {
    const data = buffer.getChannelData(channel);
    let b0 = 0;
    let b1 = 0;
    let b2 = 0;
    let b3 = 0;
    let b4 = 0;
    let b5 = 0;
    let b6 = 0;

    for (let i = 0; i < frameCount; i += 1) {
      const white = Math.random() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.969 * b2 + white * 0.153852;
      b3 = 0.8665 * b3 + white * 0.3104856;
      b4 = 0.55 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.016898;
      b6 = white * 0.115926;
      const pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
      data[i] = pink * 0.11;
    }
  }
  return buffer;
}

function createBrownNoiseBuffer(context) {
  const duration = 3;
  const channels = 2;
  const frameCount = Math.floor(duration * context.sampleRate);
  const buffer = context.createBuffer(channels, frameCount, context.sampleRate);

  for (let channel = 0; channel < channels; channel += 1) {
    const data = buffer.getChannelData(channel);
    let lastOut = 0;
    for (let i = 0; i < frameCount; i += 1) {
      const white = Math.random() * 2 - 1;
      lastOut = (lastOut + 0.02 * white) / 1.02;
      data[i] = lastOut * 3.5;
    }
  }
  return buffer;
}

function attachSlider(slider, key, applyFn) {
  if (!slider) return;
  slider.addEventListener("input", () => {
    controlValues[key] = Number(slider.value);
    slider.setAttribute("aria-valuenow", slider.value);
    applyFn();
  });
}

noiseButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const selected = button.dataset.noise;
    setNoiseType(selected);
  });
});

playToggle.addEventListener("click", () => {
  if (isPlaying) {
    stopNoise();
  } else {
    startNoise();
  }
});

playToggle.addEventListener(
  "pointerdown",
  () => {
    if (!ensureAudioGraph()) return;
    audioCtx.resume().catch((err) => {
      console.error("Unable to prime audio context", err);
    });
  },
  { once: true }
);

if (volumeSlider) {
  volumeSlider.addEventListener("input", () => updateVolume());
}

attachSlider(brightnessSlider, "brightness", applyBrightnessFromSlider);
attachSlider(toneSlider, "tone", applyToneTilt);
attachSlider(stereoSlider, "stereo", applyStereoDrift);

applyAllSettings();

document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    stopNoise();
  }
});
