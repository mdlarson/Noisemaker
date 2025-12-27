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
const STORAGE_KEY = "noiseStudioSettings";

const NOISE_TYPES = new Set(["white", "pink", "brown"]);
const defaultSettings = {
  noise: "pink",
  volume: 25,
  brightness: 25,
  tone: 25,
  stereo: 25,
};

const bufferCache = new Map();

let audioCtx;
let toneFilter;
let tiltFilter;
let stereoPanner;
let panLfo;
let panDepthGain;
let gainNode;
let fadeGain;
let fadeTimeout;
let shouldResumeAfterHide = false;
const statusEl = document.getElementById("status-text");
const sliderValueEls = {
  brightness: document.getElementById("brightness-value"),
  tone: document.getElementById("tone-value"),
  stereo: document.getElementById("stereo-value"),
  volume: document.getElementById("volume-value"),
};
const sourceSlots = Array.from({ length: 2 }, () => ({
  source: null,
  gain: null,
}));
let activeSlotIndex = -1;

const state = {
  isPlaying: false,
  currentNoise: defaultSettings.noise,
  controlValues: {
    brightness: defaultSettings.brightness,
    tone: defaultSettings.tone,
    stereo: defaultSettings.stereo,
  },
};

function readStoredSettings() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return null;
    return { ...defaultSettings, ...JSON.parse(saved) };
  } catch {
    return null;
  }
}

function persistSettings() {
  try {
    const payload = {
      noise: state.currentNoise,
      volume: Number(volumeSlider?.value ?? defaultSettings.volume),
      brightness: state.controlValues.brightness,
      tone: state.controlValues.tone,
      stereo: state.controlValues.stereo,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  } catch {
    // best effort; ignore storage errors
  }
}

function initializeControls() {
  const saved = readStoredSettings();
  if (saved) {
    state.currentNoise = saved.noise;
    if (volumeSlider && typeof saved.volume === "number") {
      volumeSlider.value = String(saved.volume);
    }
    ["brightness", "tone", "stereo"].forEach((key) => {
      const slider = getSliderByKey(key);
      if (slider && typeof saved[key] === "number") {
        slider.value = String(saved[key]);
        state.controlValues[key] = saved[key];
      }
    });
  }

  if (volumeSlider) {
    volumeSlider.setAttribute("aria-valuenow", volumeSlider.value);
    updateSliderValueDisplay("volume", Number(volumeSlider.value));
  }

  updateNoiseButtons();
  attachSlider(brightnessSlider, "brightness", applyBrightnessFromSlider);
  attachSlider(toneSlider, "tone", applyToneTilt);
  attachSlider(stereoSlider, "stereo", applyStereoDrift);

  if (volumeSlider) {
    volumeSlider.addEventListener("input", () => {
      volumeSlider.setAttribute("aria-valuenow", volumeSlider.value);
      updateSliderValueDisplay("volume", Number(volumeSlider.value));
      updateVolume();
      persistSettings();
    });
  }
}

function getSliderByKey(key) {
  switch (key) {
    case "brightness":
      return brightnessSlider;
    case "tone":
      return toneSlider;
    case "stereo":
      return stereoSlider;
    default:
      return null;
  }
}

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

  audioCtx.addEventListener("statechange", () => {
    if (audioCtx.state === "suspended" && state.isPlaying) {
      audioCtx.resume().catch((err) => {
        console.error("Unable to resume audio context", err);
      });
    }
  });

  return true;
}

function applyAllSettings() {
  applyBrightnessFromSlider();
  applyToneTilt();
  applyStereoDrift();
}

function getBaseVolume() {
  const raw = Number(volumeSlider?.value ?? defaultSettings.volume) / 100;
  return Math.max(raw, 0.02);
}

function updateVolume() {
  if (!gainNode || !audioCtx) return;
  gainNode.gain.setTargetAtTime(getBaseVolume(), audioCtx.currentTime, 0.01);
}

function applyBrightnessFromSlider() {
  const value = state.controlValues.brightness;
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
  const value = state.controlValues.tone;
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
  const value = state.controlValues.stereo;
  if (panDepthGain && audioCtx) {
    const depth = (value / 100) * 0.8;
    panDepthGain.gain.setTargetAtTime(depth, audioCtx.currentTime, 0.1);
  }
  if (stereoHint) {
    stereoHint.textContent =
      value === 0
        ? "Centered signal—no movement."
        : `Slow autopan width: ${Math.round((value / 100) * 100)}%`;
  }
}

function getFadeDuration() {
  return 1;
}

function updateNoiseButtons() {
  noiseButtons.forEach((btn) => {
    const isActive = btn.dataset.noise === state.currentNoise;
    btn.setAttribute("aria-pressed", String(isActive));
  });
  announceStatus(`Noise color set to ${state.currentNoise}.`);
}

function setNoiseType(type) {
  if (!NOISE_TYPES.has(type)) {
    console.warn(`Unsupported noise type: ${type}`);
    return;
  }
  if (state.currentNoise === type) return;
  state.currentNoise = type;
  updateNoiseButtons();
  persistSettings();
  if (state.isPlaying) {
    startNoise({ crossfade: true });
  }
}

function getNoiseBuffer(type) {
  if (!audioCtx) throw new Error("Audio context not initialized.");
  if (bufferCache.has(type)) {
    return bufferCache.get(type);
  }
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
      break;
  }
  bufferCache.set(type, buffer);
  return buffer;
}

async function startNoise(options = {}) {
  const { crossfade = false } = options;
  if (!ensureAudioGraph()) return;
  try {
    await audioCtx.resume();
  } catch (err) {
    console.error("Unable to resume audio context", err);
    return;
  }

  const wasPlaying = state.isPlaying;
  const previousSlot =
    activeSlotIndex >= 0 ? sourceSlots[activeSlotIndex] : null;
  if (!crossfade && previousSlot?.source) {
    stopSlot(previousSlot);
  }

  const nextIndex = (activeSlotIndex + 1) % sourceSlots.length;
  const slot = sourceSlots[nextIndex];
  if (!slot.gain) {
    slot.gain = audioCtx.createGain();
    slot.gain.connect(toneFilter);
  }

  const source = audioCtx.createBufferSource();
  source.buffer = getNoiseBuffer(state.currentNoise);
  source.loop = true;
  slot.source = source;
  const startGain = crossfade && wasPlaying ? 0 : 1;
  slot.gain.gain.setValueAtTime(startGain, audioCtx.currentTime);
  source.connect(slot.gain);
  source.start();

  if (crossfade && wasPlaying && previousSlot?.source && previousSlot.gain) {
    const now = audioCtx.currentTime;
    const cfDuration = Math.min(getFadeDuration(), 0.4);
    slot.gain.gain.linearRampToValueAtTime(1, now + cfDuration);
    previousSlot.gain.gain.cancelScheduledValues(now);
    previousSlot.gain.gain.setValueAtTime(
      previousSlot.gain.gain.value,
      now
    );
    previousSlot.gain.gain.linearRampToValueAtTime(0, now + cfDuration);
    stopSlot(previousSlot, now + cfDuration + 0.05);
  }

  activeSlotIndex = nextIndex;

  if (!wasPlaying) {
    const now = audioCtx.currentTime;
    const fadeDur = getFadeDuration();
    fadeGain.gain.cancelScheduledValues(now);
    fadeGain.gain.setValueAtTime(0, now);
    fadeGain.gain.linearRampToValueAtTime(1, now + fadeDur);
  }

  state.isPlaying = true;
  playToggle.textContent = "Pause";
  persistSettings();
  playToggle.setAttribute("aria-pressed", "true");
  announceStatus("Noise playback started.");
}

function stopNoise({ immediate = false } = {}) {
  if (!audioCtx) {
    state.isPlaying = false;
    playToggle.textContent = "Play";
    return;
  }
  const now = audioCtx.currentTime;
  const fadeDur = immediate ? 0.02 : getFadeDuration();
  fadeGain.gain.cancelScheduledValues(now);
  fadeGain.gain.setValueAtTime(fadeGain.gain.value, now);
  fadeGain.gain.linearRampToValueAtTime(0, now + fadeDur);

  const finalize = () => {
    sourceSlots.forEach((slot) => stopSlot(slot));
    activeSlotIndex = -1;
    state.isPlaying = false;
    playToggle.textContent = "Play";
    persistSettings();
    playToggle.setAttribute("aria-pressed", "false");
    announceStatus("Noise playback paused.");
};

  if (immediate) {
    finalize();
  } else {
    if (fadeTimeout) clearTimeout(fadeTimeout);
    fadeTimeout = setTimeout(finalize, fadeDur * 1000 + 20);
  }
}

function announceStatus(message) {
  if (statusEl) {
    statusEl.textContent = message;
  }
}

function stopSlot(slot, stopTime) {
  if (!slot) return;
  if (slot.source) {
    try {
      if (typeof stopTime === "number") {
        slot.source.stop(stopTime);
      } else {
        slot.source.stop();
      }
    } catch {
      // ignore
    }
    slot.source.disconnect();
    slot.source = null;
  }
  if (slot.gain && audioCtx) {
    slot.gain.gain.setValueAtTime(0, audioCtx.currentTime);
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
  slider.setAttribute("aria-valuenow", slider.value);
  updateSliderValueDisplay(key, Number(slider.value));
  slider.addEventListener("input", () => {
    state.controlValues[key] = Number(slider.value);
    slider.setAttribute("aria-valuenow", slider.value);
    updateSliderValueDisplay(key, Number(slider.value));
    applyFn();
    persistSettings();
  });
}

function updateSliderValueDisplay(key, value) {
  const target = sliderValueEls[key];
  if (target) {
    target.textContent = `${value}%`;
  }
}

noiseButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const selected = button.dataset.noise;
    setNoiseType(selected);
  });
});

playToggle.addEventListener("click", () => {
  if (state.isPlaying) {
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

initializeControls();
applyAllSettings();
updateVolume();

document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    shouldResumeAfterHide = state.isPlaying;
    if (state.isPlaying) {
      stopNoise();
    }
  } else if (shouldResumeAfterHide) {
    shouldResumeAfterHide = false;
    startNoise();
  }
});
