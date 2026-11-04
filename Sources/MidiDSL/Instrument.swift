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

    /// An instrument by name, with the General MIDI program a MIDI file should open it as.
    ///
    /// - Parameters:
    ///   - name: The name the track's sound goes by.
    ///   - program: The General MIDI program, 0…127. `nil` sends no program change.
    ///   - bank: The bank the program is chosen from, 0…16383. 0 is the General MIDI bank.
    ///   - percussion: `true` writes the track on channel 10, as drums.
    public init(_ name: String, program: Int? = nil, bank: Int = 0, percussion: Bool = false) {
        self.init(name: name, program: program, bank: bank, percussion: percussion)
    }

    @_documentation(visibility: internal)
    public init(name: String, program: Int? = nil, bank: Int = 0, percussion: Bool = false,
                sound: (any HostSound)? = nil) {
        self.name = name
        self.program = program.map { min(max($0, 0), 127) }
        self.bank = min(max(bank, 0), 16383)
        self.percussion = percussion
        self.sound = sound
    }

    /// A General MIDI instrument, by its program number (counting from 0).
    ///
    /// - Parameters:
    ///   - program: The program, 0…127: 0 is the acoustic grand piano, 33 the fingered bass.
    ///   - bank: The bank the program is chosen from. 0 is the General MIDI bank.
    /// - Returns: The instrument.
    public static func generalMIDI(_ program: Int, bank: Int = 0) -> Instrument {
        Instrument("program \(program)", program: program, bank: bank)
    }

    /// A General MIDI drum kit, on channel 10.
    ///
    /// - Parameter kit: Which kit plays. Each lane's ``DrumPiece`` picks the key.
    /// - Returns: The instrument.
    public static func drums(_ kit: DrumKit = .standard) -> Instrument {
        Instrument("drums", program: kit.rawValue, percussion: true)
    }

    @_documentation(visibility: internal)
    public static func == (lhs: Instrument, rhs: Instrument) -> Bool {
        guard lhs.name == rhs.name, lhs.program == rhs.program, lhs.bank == rhs.bank,
              lhs.percussion == rhs.percussion
        else { return false }
        switch (lhs.sound, rhs.sound) {
        case (nil, nil): return true
        case (let l?, let r?): return l.isEqual(to: r)
        default: return false
        }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case name, program, bank, percussion, soundKind, sound
    }

    @_documentation(visibility: internal)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        program = try c.decodeIfPresent(Int.self, forKey: .program)
        bank = try c.decodeIfPresent(Int.self, forKey: .bank) ?? 0
        percussion = try c.decodeIfPresent(Bool.self, forKey: .percussion) ?? false
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
        if let sound {
            try c.encode(type(of: sound).kind, forKey: .soundKind)
            try sound.encode(to: c.superEncoder(forKey: .sound))
        }
    }
}
