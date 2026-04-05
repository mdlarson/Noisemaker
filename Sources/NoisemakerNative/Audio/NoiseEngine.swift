@preconcurrency import AVFoundation
import Foundation
import QuartzCore
import os

final class NoiseEngine: @unchecked Sendable {
    private enum Constants {
        static let fadeDuration: TimeInterval = 1.0
        static let colorCrossfadeDuration: TimeInterval = 0.18
        static let minimumPlaybackVolume: Float = 0.02
        static let stereoLfoFrequency: Float = 0.08
        static let defaultSampleRate: Float = 48_000
    }

    private struct SourceSlot {
        let generator: NoiseGenerator
        let sourceNode: AVAudioSourceNode
        let mixer: AVAudioMixerNode
    }

    private let engine = AVAudioEngine()
    private let sourceMixNode = AVAudioMixerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private let outputMixer = AVAudioMixerNode()
    private let renderFormat = AVAudioFormat(
        standardFormatWithSampleRate: Double(Constants.defaultSampleRate),
        channels: 2
    )!
    private let sourceSlots: [SourceSlot]

    private var currentSettings = NoiseSettings.default
    private var volumeRampTimer: Timer?
    private var sourceCrossfadeTimer: Timer?
    private var isConfigured = false
    private var activeSlotIndex = 0

    private(set) var isPlaying = false

    init() {
        sourceSlots = [
            Self.makeSourceSlot(
                channelSeeds: [0x1234ABCD, 0xCDEF0123],
                initialNoise: NoiseSettings.default.noise
            ),
            Self.makeSourceSlot(
                channelSeeds: [0x0F0F0F0F, 0xF0F0F0F0],
                initialNoise: NoiseSettings.default.noise
            ),
        ]

        configureGraph()
        apply(settings: currentSettings, immediate: true)
    }

    deinit {
        volumeRampTimer?.invalidate()
        sourceCrossfadeTimer?.invalidate()
        engine.stop()
    }

    func apply(settings: NoiseSettings, immediate: Bool = false) {
        let noiseChanged = settings.noise != currentSettings.noise
        currentSettings = settings

        if noiseChanged {
            transitionNoise(to: settings.noise, immediate: immediate || !isPlaying)
        } else {
            sourceSlots[activeSlotIndex].generator.setNoiseType(settings.noise)
        }

        applyBrightness(settings.brightness)
        applyToneTilt(settings.tone)
        applyStereoDrift(settings.stereo)
        setOutputLevel(for: settings.volume, immediate: immediate || !isPlaying)
    }

    func play() throws {
        if !engine.isRunning {
            try AVAudioSessionBootstrap.ensureReadyIfNeeded()
            try engine.start()
        }

        isPlaying = true
        setSourceMixLevels(active: activeSlotIndex, inactiveLevel: 0, immediate: true)
        setOutputLevel(for: currentSettings.volume, immediate: false)
    }

    func pause() {
        guard engine.isRunning else {
            isPlaying = false
            outputMixer.outputVolume = 0
            return
        }

        isPlaying = false
        setOutputLevel(for: 0, immediate: false, pauseWhenDone: true)
    }

    private func configureGraph() {
        guard !isConfigured else { return }

        eqNode.globalGain = 0

        let lowPassBand = eqNode.bands[0]
        lowPassBand.filterType = .lowPass
        lowPassBand.bypass = false
        lowPassBand.bandwidth = 0.5

        let lowShelfBand = eqNode.bands[1]
        lowShelfBand.filterType = .lowShelf
        lowShelfBand.frequency = 220
        lowShelfBand.bypass = false

        let highShelfBand = eqNode.bands[2]
        highShelfBand.filterType = .highShelf
        highShelfBand.frequency = 4_000
        highShelfBand.bypass = false

        outputMixer.outputVolume = 0
        sourceSlots.forEach { $0.mixer.outputVolume = 0 }
        sourceSlots[activeSlotIndex].mixer.outputVolume = 1

        sourceSlots.forEach {
            engine.attach($0.sourceNode)
            engine.attach($0.mixer)
        }
        engine.attach(sourceMixNode)
        engine.attach(eqNode)
        engine.attach(outputMixer)

        sourceSlots.forEach {
            engine.connect($0.sourceNode, to: $0.mixer, format: renderFormat)
            engine.connect($0.mixer, to: sourceMixNode, format: renderFormat)
        }
        engine.connect(sourceMixNode, to: eqNode, format: renderFormat)
        engine.connect(eqNode, to: outputMixer, format: renderFormat)
        engine.connect(outputMixer, to: engine.mainMixerNode, format: renderFormat)

        isConfigured = true
    }

    private func applyBrightness(_ value: Double) {
        let minFrequency = 800.0
        let maxFrequency = 18_000.0
        let ratio = max(0, min(value / 100, 1))
        let frequency = minFrequency * pow(maxFrequency / minFrequency, ratio)
        eqNode.bands[0].frequency = Float(frequency)
    }

    private func applyToneTilt(_ value: Double) {
        let normalizedTilt = Float((value - 50) / 50)
        let shelfGain = normalizedTilt * 8
        eqNode.bands[1].gain = -shelfGain
        eqNode.bands[2].gain = shelfGain
    }

    private func applyStereoDrift(_ value: Double) {
        let depth = Float((value / 100) * 0.8)
        sourceSlots.forEach {
            $0.generator.setStereoDepth(depth)
            $0.generator.setStereoRate(Constants.stereoLfoFrequency)
        }
    }

    private func setOutputLevel(for value: Double, immediate: Bool, pauseWhenDone: Bool = false) {
        let normalizedValue = Float(max(0, min(value / 100, 1)))
        let target = pauseWhenDone ? 0 : max(normalizedValue, Constants.minimumPlaybackVolume)
        rampOutputVolume(
            to: target,
            duration: immediate ? 0 : Constants.fadeDuration,
            pauseWhenDone: pauseWhenDone
        )
    }

    private func transitionNoise(to noise: NoiseType, immediate: Bool) {
        if immediate {
            sourceCrossfadeTimer?.invalidate()
            sourceCrossfadeTimer = nil
            sourceSlots[activeSlotIndex].generator.setNoiseType(noise)
            sourceSlots[activeSlotIndex].generator.setShouldRender(true)
            setSourceMixLevels(active: activeSlotIndex, inactiveLevel: 0, immediate: true)
            return
        }

        let currentSlotIndex = prepareCurrentSourceForTransition()
        let nextSlotIndex = (currentSlotIndex + 1) % sourceSlots.count
        sourceSlots[nextSlotIndex].generator.setNoiseType(noise)
        sourceSlots[nextSlotIndex].generator.setShouldRender(true)
        crossfadeSources(
            from: currentSlotIndex,
            to: nextSlotIndex,
            duration: Constants.colorCrossfadeDuration
        )
        activeSlotIndex = nextSlotIndex
    }

    private func setSourceMixLevels(active: Int, inactiveLevel: Float, immediate: Bool) {
        for index in sourceSlots.indices {
            sourceSlots[index].mixer.outputVolume = index == active ? 1 : inactiveLevel
            sourceSlots[index].generator.setShouldRender(index == active || inactiveLevel > 0)
        }

        if immediate {
            sourceCrossfadeTimer?.invalidate()
            sourceCrossfadeTimer = nil
        }
    }

    private func crossfadeSources(from oldIndex: Int, to newIndex: Int, duration: TimeInterval) {
        sourceCrossfadeTimer?.invalidate()
        sourceCrossfadeTimer = nil

        let oldMixer = sourceSlots[oldIndex].mixer
        let newMixer = sourceSlots[newIndex].mixer
        let oldStart = oldMixer.outputVolume
        let newStart = newMixer.outputVolume

        guard duration > 0 else {
            oldMixer.outputVolume = 0
            newMixer.outputVolume = 1
            sourceSlots[oldIndex].generator.setShouldRender(false)
            sourceSlots[newIndex].generator.setShouldRender(true)
            return
        }

        let beganAt = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let progress = min((CACurrentMediaTime() - beganAt) / duration, 1)
            let easedProgress = Float(1 - pow(1 - progress, 3))
            oldMixer.outputVolume = oldStart + ((0 - oldStart) * easedProgress)
            newMixer.outputVolume = newStart + ((1 - newStart) * easedProgress)

            if progress >= 1 {
                timer.invalidate()
                oldMixer.outputVolume = 0
                newMixer.outputVolume = 1
                self.sourceSlots[oldIndex].generator.setShouldRender(false)
                self.sourceSlots[newIndex].generator.setShouldRender(true)
                self.sourceCrossfadeTimer = nil
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        sourceCrossfadeTimer = timer
    }

    private func prepareCurrentSourceForTransition() -> Int {
        sourceCrossfadeTimer?.invalidate()
        sourceCrossfadeTimer = nil

        let currentVolumes = sourceSlots.map { $0.mixer.outputVolume }
        let maxVolume = currentVolumes.max() ?? 0

        let dominantSlotIndex: Int
        if maxVolume < 0.01 {
            dominantSlotIndex = activeSlotIndex
        } else {
            dominantSlotIndex = currentVolumes[0] >= currentVolumes[1] ? 0 : 1
        }

        for index in sourceSlots.indices {
            sourceSlots[index].mixer.outputVolume = index == dominantSlotIndex ? 1 : 0
            sourceSlots[index].generator.setShouldRender(index == dominantSlotIndex)
        }

        return dominantSlotIndex
    }

    private func rampOutputVolume(to target: Float, duration: TimeInterval, pauseWhenDone: Bool) {
        volumeRampTimer?.invalidate()

        guard duration > 0 else {
            outputMixer.outputVolume = target
            if pauseWhenDone && target == 0 {
                engine.pause()
            }
            return
        }

        let startVolume = outputMixer.outputVolume
        let beganAt = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let progress = min((CACurrentMediaTime() - beganAt) / duration, 1)
            let easedProgress = 1 - pow(1 - progress, 3)
            self.outputMixer.outputVolume = startVolume + (target - startVolume) * Float(easedProgress)

            if progress >= 1 {
                timer.invalidate()
                self.volumeRampTimer = nil
                if pauseWhenDone && target == 0 {
                    self.engine.pause()
                }
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        volumeRampTimer = timer
    }

    private static func makeSourceSlot(channelSeeds: [UInt64], initialNoise: NoiseType) -> SourceSlot {
        let generator = NoiseGenerator(channelSeeds: channelSeeds, noiseType: initialNoise)
        let sourceNode = AVAudioSourceNode { [generator] _, timestamp, frameCount, audioBufferList -> OSStatus in
            generator.render(
                frameCount: frameCount,
                timestamp: timestamp.pointee,
                into: audioBufferList
            )
            return noErr
        }
        let mixer = AVAudioMixerNode()
        return SourceSlot(generator: generator, sourceNode: sourceNode, mixer: mixer)
    }
}

private enum AVAudioSessionBootstrap {
    static func ensureReadyIfNeeded() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        #endif
    }
}

private struct NoiseGeneratorConfig {
    var noiseType: NoiseType
    var shouldRender: Bool
    var stereoDepth: Float
    var stereoRate: Float
}

private final class NoiseGenerator: @unchecked Sendable {
    private let configLock: OSAllocatedUnfairLock<NoiseGeneratorConfig>
    private var renderState: NoiseGeneratorState

    init(channelSeeds: [UInt64], noiseType: NoiseType) {
        configLock = OSAllocatedUnfairLock(
            initialState: NoiseGeneratorConfig(
                noiseType: noiseType,
                shouldRender: true,
                stereoDepth: 0.2,
                stereoRate: 0.08
            )
        )
        renderState = NoiseGeneratorState(
            randomGenerators: channelSeeds.map(SeededRandom.init(seed:)),
            pinkStates: channelSeeds.map { _ in PinkNoiseState() },
            brownStates: channelSeeds.map { _ in BrownNoiseState() }
        )
    }

    func setNoiseType(_ type: NoiseType) {
        configLock.withLock { $0.noiseType = type }
    }

    func setShouldRender(_ shouldRender: Bool) {
        configLock.withLock { $0.shouldRender = shouldRender }
    }

    func setStereoDepth(_ depth: Float) {
        configLock.withLock { $0.stereoDepth = depth }
    }

    func setStereoRate(_ rate: Float) {
        configLock.withLock { $0.stereoRate = rate }
    }

    func render(
        frameCount: AVAudioFrameCount,
        timestamp: AudioTimeStamp,
        into audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let config = configLock.withLock { $0 }

        guard config.shouldRender else {
            zero(buffers: buffers, frameCount: Int(frameCount))
            return
        }

        let channelCount = buffers.count
        let leftPointer = buffers[0].mData!.assumingMemoryBound(to: Float.self)
        let rightPointer = buffers[min(1, channelCount - 1)].mData!.assumingMemoryBound(to: Float.self)
        let sampleRate: Float = 48_000
        let baseSampleTime = timestamp.mSampleTime.isFinite ? timestamp.mSampleTime : 0

        for frame in 0..<Int(frameCount) {
            let leftNoise = renderState.sample(for: 0, noiseType: config.noiseType)
            let rightNoise = renderState.sample(for: min(1, channelCount - 1), noiseType: config.noiseType)

            let frameSampleTime = Float(baseSampleTime + Double(frame))
            let phase = (frameSampleTime / sampleRate) * (2 * .pi) * config.stereoRate
            let pan = sin(phase) * config.stereoDepth
            let leftGain = sqrt(max(0, (1 - pan) * 0.5))
            let rightGain = sqrt(max(0, (1 + pan) * 0.5))

            if channelCount == 1 {
                leftPointer[frame] = (leftNoise + rightNoise) * 0.5
            } else {
                leftPointer[frame] = leftNoise * leftGain
                rightPointer[frame] = rightNoise * rightGain
            }
        }

        if channelCount > 2 {
            for channel in 2..<channelCount {
                let pointer = buffers[channel].mData!.assumingMemoryBound(to: Float.self)
                for frame in 0..<Int(frameCount) {
                    pointer[frame] = 0
                }
            }
        }
    }

    private func zero(buffers: UnsafeMutableAudioBufferListPointer, frameCount: Int) {
        for channel in 0..<buffers.count {
            let pointer = buffers[channel].mData!.assumingMemoryBound(to: Float.self)
            for frame in 0..<frameCount {
                pointer[frame] = 0
            }
        }
    }
}

private struct NoiseGeneratorState {
    var randomGenerators: [SeededRandom]
    var pinkStates: [PinkNoiseState]
    var brownStates: [BrownNoiseState]

    mutating func sample(for channel: Int, noiseType: NoiseType) -> Float {
        let safeChannel = min(channel, randomGenerators.count - 1)
        let white = randomGenerators[safeChannel].nextSignedUnitFloat()

        switch noiseType {
        case .white:
            return white
        case .pink:
            return pinkStates[safeChannel].next(white: white)
        case .brown:
            return brownStates[safeChannel].next(white: white)
        }
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextSignedUnitFloat() -> Float {
        state = 6364136223846793005 &* state &+ 1
        let upperBits = UInt32(truncatingIfNeeded: state >> 32)
        let normalized = Float(upperBits) / Float(UInt32.max)
        return (normalized * 2) - 1
    }
}

private struct PinkNoiseState {
    var b0: Float = 0
    var b1: Float = 0
    var b2: Float = 0
    var b3: Float = 0
    var b4: Float = 0
    var b5: Float = 0
    var b6: Float = 0

    mutating func next(white: Float) -> Float {
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        b6 = white * 0.115926

        let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        return pink * 0.11
    }
}

private struct BrownNoiseState {
    var lastOutput: Float = 0

    mutating func next(white: Float) -> Float {
        lastOutput = (lastOutput + (0.02 * white)) / 1.02
        return lastOutput * 3.5
    }
}
