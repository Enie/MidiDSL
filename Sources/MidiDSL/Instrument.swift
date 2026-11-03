import Foundation

/// What a track plays, as far as a MIDI file can say it: a General MIDI program, its bank, and
/// whether the track is drums.
///
/// A MIDI file carries no sound of its own. It names an instrument by number and leaves the
/// sound to whatever plays the file, so this is all a track needs to open in a DAW as a bass, a
/// string section or a drum kit rather than as a piano:
///
/// ```swift
/// Track("Bass", instrument: .generalMIDI(33)) { … }
/// Track("Drums", instrument: .drums(.room)) { … }
/// ```
///
/// Program numbers count from 0, as the byte in the file does: 0 is the acoustic grand piano,
/// 33 the fingered electric bass, 48 the string ensemble. A General MIDI chart that counts
/// from 1 is one higher.
///
/// A host that makes its own sounds, a synthesizer or a plugin, attaches them to the same
/// instrument, and a MIDI file simply leaves them out.
///
/// See <doc:Instruments>.
public struct Instrument: Codable, Equatable {
    /// The name the track's sound goes by.
    public var name: String
    /// The General MIDI program, 0–127, sent as a program change at the top of the track.
    /// Nil sends none.
    public var program: Int?
    /// The bank the program is chosen from, sent as bank select before it. 0 is the General
    /// MIDI bank.
    public var bank: Int
    /// Whether the track is drums: it is written on channel 10, where every General MIDI
    /// player keeps its kit, and `program` picks the kit.
    public var percussion: Bool

    @_documentation(visibility: internal)
    public var sound: (any HostSound)?
    @_documentation(visibility: internal)
    public var sampleKit: SampleKitConfig?

    /// An instrument by name, with the General MIDI program a MIDI file should open it as.
    public init(_ name: String, program: Int? = nil, bank: Int = 0, percussion: Bool = false) {
        self.init(name: name, program: program, bank: bank, percussion: percussion)
    }

    @_documentation(visibility: internal)
    public init(name: String, program: Int? = nil, bank: Int = 0, percussion: Bool = false,
                sound: (any HostSound)? = nil, sampleKit: SampleKitConfig? = nil) {
        self.name = name
        self.program = program.map { min(max($0, 0), 127) }
        self.bank = min(max(bank, 0), 16383)
        self.percussion = percussion
        self.sound = sound
        self.sampleKit = sampleKit
    }

    /// A General MIDI instrument, by its program number (counting from 0).
    public static func generalMIDI(_ program: Int, bank: Int = 0) -> Instrument {
        Instrument("program \(program)", program: program, bank: bank)
    }

    /// A General MIDI drum kit, on channel 10.
    public static func drums(_ kit: DrumKit = .standard) -> Instrument {
        Instrument("drums", program: kit.rawValue, percussion: true)
    }

    @_documentation(visibility: internal)
    public static func == (lhs: Instrument, rhs: Instrument) -> Bool {
        guard lhs.name == rhs.name, lhs.program == rhs.program, lhs.bank == rhs.bank,
              lhs.percussion == rhs.percussion, lhs.sampleKit == rhs.sampleKit
        else { return false }
        switch (lhs.sound, rhs.sound) {
        case (nil, nil): return true
        case (let l?, let r?): return l.isEqual(to: r)
        default: return false
        }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case name, program, bank, percussion, sampleKit, soundKind, sound
    }

    @_documentation(visibility: internal)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        program = try c.decodeIfPresent(Int.self, forKey: .program)
        bank = try c.decodeIfPresent(Int.self, forKey: .bank) ?? 0
        percussion = try c.decodeIfPresent(Bool.self, forKey: .percussion) ?? false
        sampleKit = try c.decodeIfPresent(SampleKitConfig.self, forKey: .sampleKit)
        // A host sound is decoded only by a reader that registered its kind; any other reader
        // keeps the MIDI half and passes over the rest.
        if let kind = try c.decodeIfPresent(String.self, forKey: .soundKind),
           let type = (decoder.userInfo[.hostSounds] as? HostSounds)?.types
               .first(where: { $0.kind == kind }),
           c.contains(.sound) {
            sound = try type.init(from: c.superDecoder(forKey: .sound))
        } else {
            sound = nil
        }
    }

    @_documentation(visibility: internal)
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(program, forKey: .program)
        try c.encode(bank, forKey: .bank)
        try c.encode(percussion, forKey: .percussion)
        try c.encodeIfPresent(sampleKit, forKey: .sampleKit)
        if let sound {
            try c.encode(type(of: sound).kind, forKey: .soundKind)
            try sound.encode(to: c.superEncoder(forKey: .sound))
        }
    }
}

/// A sound a host makes itself, attached to an ``Instrument``: a synthesizer patch, a plugin.
/// It travels with the session as JSON, and a reader decodes it only when it lists the type in
/// its decoder's `userInfo[.hostSounds]` (see ``HostSounds``).
@_documentation(visibility: internal)
public protocol HostSound: Codable {
    /// A name for the type that stays the same across modules, written beside the sound.
    static var kind: String { get }
    /// The sound a track's own samples would replace, named for the warning that says so
    /// ("sampled instrument", "plugin"); nil when the two play together.
    var replacedBySamples: String? { get }
    func isEqual(to other: any HostSound) -> Bool
}

extension HostSound where Self: Equatable {
    @_documentation(visibility: internal)
    public func isEqual(to other: any HostSound) -> Bool {
        (other as? Self).map { $0 == self } ?? false
    }
}

/// The ``HostSound`` types a decoder recognises:
/// `decoder.userInfo[.hostSounds] = HostSounds([MySound.self])`.
@_documentation(visibility: internal)
public struct HostSounds: @unchecked Sendable {
    // Metatypes are immutable; nothing here is shared state.
    public let types: [any HostSound.Type]
    public init(_ types: [any HostSound.Type]) { self.types = types }
}

extension CodingUserInfoKey {
    /// Where a decoder finds the ``HostSounds`` it should recognise.
    @_documentation(visibility: internal)
    public static let hostSounds = CodingUserInfoKey(rawValue: "MidiDSL.hostSounds")!
}

/// The audio files a track plays, and the keys they sit on: the slices a kit was built from,
/// and the samples its drum lanes named.
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
