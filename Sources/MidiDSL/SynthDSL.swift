import Foundation

/// The waveform of one oscillator in the built-in synthesizer.
///
/// See <doc:Instruments>.
public enum SynthWaveform: String, Codable {
    case sine
    case square
    case triangle
    case sawtooth
    case noise
}

/// The filter type of the built-in synthesizer.
///
/// See <doc:Instruments>.
public enum SynthFilterType: String, Codable {
    case lowPass
    case highPass
    case bandPass
}

/// How quickly an oscillator's overtones fall away.
///
/// See <doc:Instruments>.
public enum OvertoneDecay: String, Codable {
    case linear
    case exponential
    case custom
}

/// Overtones added to one oscillator of the built-in synthesizer.
///
/// See <doc:Instruments>.
public struct OvertoneConfig: Codable, Equatable {
    @_documentation(visibility: internal)
    public var enabled: Bool
    @_documentation(visibility: internal)
    public var count: Int
    @_documentation(visibility: internal)
    public var mix: Float
    @_documentation(visibility: internal)
    public var decay: OvertoneDecay
    @_documentation(visibility: internal)
    public var customAmplitudes: [Float]?

    public init(enabled: Bool = false, count: Int = 3, mix: Float = 0.5, decay: OvertoneDecay = .exponential, customAmplitudes: [Float]? = nil) {
        self.enabled = enabled
        self.count = min(max(count, 1), 8)
        self.mix = min(max(mix, 0.0), 1.0)
        self.decay = decay
        self.customAmplitudes = customAmplitudes
    }
}

@_documentation(visibility: internal)
public struct OscillatorConfig: Codable, Equatable {
    public var waveform: SynthWaveform
    @_documentation(visibility: internal)
    public var mix: Float
    public var detune: Float
    public var overtones: OvertoneConfig

    public init(waveform: SynthWaveform = .sine, mix: Float = 1.0, detune: Float = 0.0, overtones: OvertoneConfig = OvertoneConfig()) {
        self.waveform = waveform
        self.mix = mix
        self.detune = detune
        self.overtones = overtones
    }
}

/// The shape of the synthesizer's envelope segments.
///
/// See <doc:Instruments>.
public enum EnvelopeCurve: String, Codable {
    case linear
    case exponential
}

@_documentation(visibility: internal)
public struct EnvelopeConfig: Codable, Equatable {
    public var attack: Double
    @_documentation(visibility: internal)
    public var decay: Double
    public var sustain: Float
    public var release: Double
    public var curve: EnvelopeCurve

    public init(attack: Double = 0.01, decay: Double = 0.1, sustain: Float = 0.7, release: Double = 0.3, curve: EnvelopeCurve = .linear) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.curve = curve
    }
}

@_documentation(visibility: internal)
public struct PitchEnvelopeConfig: Codable, Equatable {
    @_documentation(visibility: internal)
    public var enabled: Bool
    public var amount: Float
    @_documentation(visibility: internal)
    public var decay: Double

    public init(enabled: Bool = false, amount: Float = 0.0, decay: Double = 0.05) {
        self.enabled = enabled
        self.amount = amount
        self.decay = max(decay, 0.001)
    }
}

@_documentation(visibility: internal)
public struct FilterConfig: Codable, Equatable {
    @_documentation(visibility: internal)
    public var enabled: Bool
    public var type: SynthFilterType
    public var cutoff: Float
    public var resonance: Float

    public init(enabled: Bool = false, type: SynthFilterType = .lowPass, cutoff: Float = 5000, resonance: Float = 0.5) {
        self.enabled = enabled
        self.type = type
        self.cutoff = cutoff
        self.resonance = resonance
    }
}

@_documentation(visibility: internal)
public struct ReverbConfig: Codable, Equatable {
    @_documentation(visibility: internal)
    public var enabled: Bool
    @_documentation(visibility: internal)
    public var mix: Float

    public init(enabled: Bool = false, mix: Float = 0.3) {
        self.enabled = enabled
        self.mix = mix
    }
}

@_documentation(visibility: internal)
public struct SamplerConfig: Codable, Equatable {
    public var soundFont: String?
    public var program: Int
    public var bank: Int
    public var percussion: Bool?

    public init(soundFont: String? = nil, program: Int = 0, bank: Int = 0, percussion: Bool = false) {
        self.soundFont = soundFont
        self.program = min(max(program, 0), 127)
        self.bank = bank
        self.percussion = percussion ? true : nil
    }
}

@_documentation(visibility: internal)
public struct AudioUnitConfig: Codable, Equatable {
    @_documentation(visibility: internal)
    public var name: String
    public var preset: String?

    public init(name: String, preset: String? = nil) {
        self.name = name
        self.preset = preset
    }
}

@_documentation(visibility: internal)
public struct SampleKitConfig: Codable, Equatable {
    public var slices: [Sample]
    public var laneSlices: [Sample]
    public var laneBaseKey: Pitch
    public var baseKey: Pitch
    public var chromatic: Bool
    public var rootKey: Pitch

    public static let laneBase: Pitch = 96

    public init(slices: [Sample], baseKey: Pitch = 36,
                chromatic: Bool = false, rootKey: Pitch = 48,
                laneSlices: [Sample] = [], laneBaseKey: Pitch = SampleKitConfig.laneBase) {
        self.slices = slices
        self.laneSlices = laneSlices
        self.laneBaseKey = laneBaseKey
        self.baseKey = baseKey
        self.chromatic = chromatic
        self.rootKey = rootKey
    }
}

/// A built sound, as a track stores it. Build one with ``Synth``.
///
/// See <doc:Instruments>.
public class SynthPatch: Codable, Equatable {
    @_documentation(visibility: internal)
    public var name: String
    @_documentation(visibility: internal)
    public var oscillatorCount: Int
    @_documentation(visibility: internal)
    public var oscillators: [OscillatorConfig]
    @_documentation(visibility: internal)
    public var filter: FilterConfig
    @_documentation(visibility: internal)
    public var envelope: EnvelopeConfig
    @_documentation(visibility: internal)
    public var pitchEnvelope: PitchEnvelopeConfig
    @_documentation(visibility: internal)
    public var reverb: ReverbConfig
    @_documentation(visibility: internal)
    public var volume: Float
    @_documentation(visibility: internal)
    public var sampler: SamplerConfig?
    @_documentation(visibility: internal)
    public var audioUnit: AudioUnitConfig?
    @_documentation(visibility: internal)
    public var effects: [AudioUnitConfig]?
    @_documentation(visibility: internal)
    public var sampleKit: SampleKitConfig?

    @_documentation(visibility: internal)
    public init(name: String) {
        self.name = name
        self.oscillatorCount = 1
        self.oscillators = [OscillatorConfig()]
        self.filter = FilterConfig()
        self.envelope = EnvelopeConfig()
        self.pitchEnvelope = PitchEnvelopeConfig()
        self.reverb = ReverbConfig()
        self.volume = 0.8
        self.sampler = nil
        self.audioUnit = nil
        self.sampleKit = nil
    }

    @_documentation(visibility: internal)
    public static func == (lhs: SynthPatch, rhs: SynthPatch) -> Bool {
        return lhs.name == rhs.name &&
               lhs.oscillatorCount == rhs.oscillatorCount &&
               lhs.oscillators == rhs.oscillators &&
               lhs.filter == rhs.filter &&
               lhs.envelope == rhs.envelope &&
               lhs.pitchEnvelope == rhs.pitchEnvelope &&
               lhs.reverb == rhs.reverb &&
               lhs.volume == rhs.volume &&
               lhs.sampler == rhs.sampler &&
               lhs.audioUnit == rhs.audioUnit &&
               lhs.effects == rhs.effects &&
               lhs.sampleKit == rhs.sampleKit
    }
}

/// A builder for a track's sound: the built-in synthesizer, a General MIDI sampler, audio files,
/// or an Audio Unit plugin.
///
/// See <doc:Instruments>.
public class Synth {
    private var patch: SynthPatch

    private init(patch: SynthPatch) {
        self.patch = patch
    }

    public static func named(_ name: String) -> Synth {
        return Synth(patch: SynthPatch(name: name))
    }

    public func oscillators(_ count: Int) -> Synth {
        patch.oscillatorCount = min(max(count, 1), 4)
        while patch.oscillators.count < patch.oscillatorCount {
            patch.oscillators.append(OscillatorConfig())
        }
        if patch.oscillators.count > patch.oscillatorCount {
            patch.oscillators = Array(patch.oscillators.prefix(patch.oscillatorCount))
        }
        return self
    }

    public func oscillator(_ index: Int, waveform: SynthWaveform? = nil, mix: Float? = nil, detune: Float? = nil, overtones: OvertoneConfig? = nil) -> Synth {
        while index >= patch.oscillators.count {
            patch.oscillators.append(OscillatorConfig())
        }

        if let waveform = waveform {
            patch.oscillators[index].waveform = waveform
        }
        if let mix = mix {
            patch.oscillators[index].mix = mix
        }
        if let detune = detune {
            patch.oscillators[index].detune = detune
        }
        if let overtones = overtones {
            patch.oscillators[index].overtones = overtones
        }

        if index >= patch.oscillatorCount {
            patch.oscillatorCount = index + 1
        }

        return self
    }

    public func filter(_ type: SynthFilterType, cutoff: Float? = nil, resonance: Float? = nil, enabled: Bool = true) -> Synth {
        patch.filter.enabled = enabled
        patch.filter.type = type
        if let cutoff = cutoff {
            patch.filter.cutoff = cutoff
        }
        if let resonance = resonance {
            patch.filter.resonance = resonance
        }
        return self
    }

    public func envelope(attack: Double? = nil, decay: Double? = nil, sustain: Float? = nil, release: Double? = nil, curve: EnvelopeCurve? = nil) -> Synth {
        if let attack = attack {
            patch.envelope.attack = attack
        }
        if let decay = decay {
            patch.envelope.decay = decay
        }
        if let sustain = sustain {
            patch.envelope.sustain = sustain
        }
        if let release = release {
            patch.envelope.release = release
        }
        if let curve = curve {
            patch.envelope.curve = curve
        }
        return self
    }

    public func pitchEnvelope(_ semitones: Float, decay: Double = 0.05) -> Synth {
        patch.pitchEnvelope = PitchEnvelopeConfig(enabled: semitones != 0, amount: semitones, decay: decay)
        return self
    }

    public func reverb(enabled: Bool = true, mix: Float? = nil) -> Synth {
        patch.reverb.enabled = enabled
        if let mix = mix {
            patch.reverb.mix = mix
        }
        return self
    }

    /// An installed effect plugin after the instrument. Several run in the order they're written.
    /// Plays on plugin and sampled tracks; the oscillator engine has no plugin graph to put it in.
    public func effect(_ name: String, preset: String? = nil) -> Synth {
        patch.effects = (patch.effects ?? []) + [AudioUnitConfig(name: name, preset: preset)]
        return self
    }

    public func volume(_ level: Float) -> Synth {
        patch.volume = min(max(level, 0.0), 1.0)
        return self
    }

    public func overtones(_ count: Int, mix: Float = 0.5, decay: OvertoneDecay = .exponential) -> Synth {
        let config = OvertoneConfig(enabled: true, count: count, mix: mix, decay: decay)
        for i in 0..<patch.oscillators.count {
            patch.oscillators[i].overtones = config
        }
        return self
    }

    public func overtonesLinear(_ count: Int = 3, mix: Float = 0.5) -> Synth {
        return overtones(count, mix: mix, decay: .linear)
    }

    public func overtonesExponential(_ count: Int = 3, mix: Float = 0.5) -> Synth {
        return overtones(count, mix: mix, decay: .exponential)
    }

    public func overtonesCustom(_ amplitudes: [Float], mix: Float = 1.0) -> Synth {
        let config = OvertoneConfig(enabled: true, count: amplitudes.count, mix: mix, decay: .custom, customAmplitudes: amplitudes)
        for i in 0..<patch.oscillators.count {
            patch.oscillators[i].overtones = config
        }
        return self
    }

    public func build() -> SynthPatch {
        return patch
    }
}

// MARK: - Presets
public extension Synth {
    static func kick() -> Synth {
        Synth.named("kick")
            .oscillators(1)
            .oscillator(0, waveform: .sine, mix: 1.0)
            .pitchEnvelope(26, decay: 0.045)
            .envelope(attack: 0.001, decay: 0.28, sustain: 0.0, release: 0.05, curve: .exponential)
            .filter(.lowPass, cutoff: 220, resonance: 0.4)
            .volume(1.0)
    }

    static func snare() -> Synth {
        Synth.named("snare")
            .oscillators(2)
            .oscillator(0, waveform: .noise, mix: 0.65)
            .oscillator(1, waveform: .triangle, mix: 0.35)
            .pitchEnvelope(9, decay: 0.03)
            .envelope(attack: 0.001, decay: 0.16, sustain: 0.0, release: 0.08, curve: .exponential)
            .filter(.highPass, cutoff: 350, resonance: 0.6)
            .volume(0.9)
    }

    static func hihat(open: Bool = false) -> Synth {
        Synth.named(open ? "hihat-open" : "hihat")
            .oscillators(1)
            .oscillator(0, waveform: .noise, mix: 1.0)
            .envelope(attack: 0.001, decay: open ? 0.35 : 0.05, sustain: 0.0,
                      release: open ? 0.15 : 0.03, curve: .exponential)
            .filter(.highPass, cutoff: 8500, resonance: 0.3)
            .volume(0.55)
    }

    static func bass() -> Synth {
        Synth.named("bass")
            .oscillators(2)
            .oscillator(0, waveform: .sine, mix: 0.72)
            .oscillator(1, waveform: .sawtooth, mix: 0.28)
            .envelope(attack: 0.004, decay: 0.3, sustain: 0.5, release: 0.12, curve: .exponential)
            .filter(.lowPass, cutoff: 550, resonance: 0.4)
            .volume(0.9)
    }

    static func guitar() -> Synth {
        Synth.named("guitar")
            .oscillators(2)
            .oscillator(0, waveform: .sawtooth, mix: 0.55)
            .oscillator(1, waveform: .triangle, mix: 0.45)
            .overtonesCustom([0.45, 0.25, 0.14, 0.08], mix: 0.5)
            .pitchEnvelope(2, decay: 0.012)
            .envelope(attack: 0.002, decay: 0.6, sustain: 0.0, release: 0.18, curve: .exponential)
            .filter(.lowPass, cutoff: 2600, resonance: 0.4)
            .reverb(enabled: true, mix: 0.18)
            .volume(0.8)
    }

    static func pad() -> Synth {
        Synth.named("pad")
            .oscillators(3)
            .oscillator(0, waveform: .sawtooth, mix: 0.38)
            .oscillator(1, waveform: .sawtooth, mix: 0.32, detune: 0.12)
            .oscillator(2, waveform: .triangle, mix: 0.30, detune: -0.09)
            .envelope(attack: 0.7, decay: 0.4, sustain: 0.8, release: 1.6)
            .filter(.lowPass, cutoff: 1500, resonance: 0.3)
            .reverb(enabled: true, mix: 0.5)
            .volume(0.7)
    }

    static func sampled(_ name: String, soundFont: String? = nil, program: Int = 0, bank: Int = 0) -> Synth {
        let synth = Synth.named(name)
        synth.patch.sampler = SamplerConfig(soundFont: soundFont, program: program, bank: bank)
        return synth
    }

    static func audioUnit(_ name: String, preset: String? = nil) -> Synth {
        let synth = Synth.named(name)
        synth.patch.audioUnit = AudioUnitConfig(name: name, preset: preset)
        return synth
    }

    static func drums(_ kit: DrumKit = .standard, soundFont: String? = nil) -> Synth {
        let synth = Synth.named("drums")
        synth.patch.sampler = SamplerConfig(soundFont: soundFont, program: kit.rawValue,
                                            percussion: true)
        return synth
    }

    static func piano() -> Synth {
        Synth.sampled("piano", program: 0)
            .reverb(enabled: true, mix: 0.2)
            .volume(0.85)
    }

    static func acousticGuitar() -> Synth {
        Synth.sampled("acoustic guitar", program: 25)
            .reverb(enabled: true, mix: 0.18)
            .volume(0.8)
    }

    static func kit(_ slices: [Sample], from key: Pitch = 36) -> Synth {
        let synth = Synth.named("kit")
        synth.patch.sampleKit = SampleKitConfig(slices: slices, baseKey: key)
        return synth.envelope(attack: 0.0, decay: 0.0, sustain: 1.0, release: 0.01)
    }

    static func sample(_ sample: Sample, root: Pitch = 48) -> Synth {
        let synth = Synth.named("sample")
        synth.patch.sampleKit = SampleKitConfig(slices: [sample], chromatic: true,
                                                rootKey: root)
        return synth.envelope(attack: 0.0, decay: 0.0, sustain: 1.0, release: 0.01)
    }

    static func lead() -> Synth {
        Synth.named("lead")
            .oscillators(2)
            .oscillator(0, waveform: .sawtooth, mix: 0.6)
            .oscillator(1, waveform: .square, mix: 0.4, detune: 0.15)
            .overtonesExponential(3, mix: 0.25)
            .envelope(attack: 0.015, decay: 0.2, sustain: 0.7, release: 0.25, curve: .exponential)
            .filter(.lowPass, cutoff: 3200, resonance: 0.4)
            .reverb(enabled: true, mix: 0.15)
            .volume(0.75)
    }
}
