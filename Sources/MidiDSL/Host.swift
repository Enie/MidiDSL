import Foundation

// What a host adds to the language: sounds of its own on an instrument, statements of its own
// in a section, and sounds that take a key of their own on the track that plays them. A score
// reaches these through the host's module; nothing here is a word a score writes.

// MARK: - A sound on the instrument

/// A sound a host makes itself, attached to an ``Instrument``: a synthesizer patch, a plugin.
/// It travels with the session as JSON, and a reader decodes it only when it lists the type in
/// its decoder's `userInfo[.hostSounds]` (see ``HostSounds``).
@_documentation(visibility: internal)
public protocol HostSound: Codable {
    /// A name for the type that stays the same across modules, written beside the sound.
    static var kind: String { get }
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

// MARK: - A statement in a section

/// A value of the host's that a ``Section`` holds as a statement, the way it holds notation:
/// it becomes notes, stamped with the line it was written on.
@_documentation(visibility: internal)
public protocol NoteSource {
    func notes() -> [Note]
}

// MARK: - A sound on a key of its own

/// A sound that takes a key of its own on the track that plays it, such as an audio file a drum
/// lane names. Each distinct sound a track's content claims gets the next key up from
/// ``TrackKeys/firstKey``, and when the track is built the claims are handed to the sound's type
/// to fold into the instrument (``adopt(_:into:track:)``). In a MIDI file they are notes on
/// those keys.
@_documentation(visibility: internal)
public protocol KeyedSound {
    /// What the sound is called in a warning ("\"amen.wav\"").
    var keyName: String { get }
    func isSameSound(as other: any KeyedSound) -> Bool
    /// The instrument a track plays once its content has claimed `claims`, all of this type.
    static func adopt(_ claims: [KeyedClaim], into instrument: Instrument?, track: String) -> Instrument?
}

extension KeyedSound where Self: Equatable {
    @_documentation(visibility: internal)
    public func isSameSound(as other: any KeyedSound) -> Bool {
        (other as? Self).map { $0 == self } ?? false
    }
}

/// A key a ``KeyedSound`` was given on the track being built.
@_documentation(visibility: internal)
public struct KeyedClaim {
    public let key: Pitch
    public let sound: any KeyedSound
}

/// The keys the track being built has handed out. A ``Track`` drains them as it is made, so
/// each track starts again at ``firstKey``.
@_documentation(visibility: internal)
public enum TrackKeys {
    /// The first key a claimed sound plays on, above any General MIDI drum.
    public static let firstKey: Pitch = 96

    nonisolated(unsafe) static var claimed: [KeyedClaim] = []

    /// The key `sound` plays on this track: the one it already has, or the next free one.
    public static func claim(_ sound: some KeyedSound) -> Pitch {
        if let existing = claimed.first(where: { $0.sound.isSameSound(as: sound) }) {
            return existing.key
        }
        let key = firstKey + Pitch(claimed.count)
        claimed.append(KeyedClaim(key: key, sound: sound))
        if key > 127 {
            ScoreAdvisories.note(SessionAdvisory(message:
                "More than \(127 - Int(firstKey) + 1) sounds need a key of their own on one track, so "
                + "\"\(sound.keyName)\" and any after it are silent — the keys run out. Put the rest "
                + "on a track of their own."))
        }
        return key
    }

    /// The track's instrument once each kind of sound its content claimed has folded in.
    static func adopt(into instrument: Instrument?, track: String) -> Instrument? {
        let claims = claimed
        claimed = []
        var result = instrument
        var kinds: [ObjectIdentifier] = []
        for claim in claims {
            let kind = type(of: claim.sound)
            let id = ObjectIdentifier(kind)
            guard !kinds.contains(id) else { continue }
            kinds.append(id)
            result = kind.adopt(claims.filter { ObjectIdentifier(type(of: $0.sound)) == id },
                                into: result, track: track)
        }
        return result
    }

    public static func reset() { claimed = [] }
}

// MARK: - Which file a note was written in

/// What a note records as the file it was written in (`Note.sourceFile`), for a host that maps
/// notes back to the text it is editing. A note written in that text records nil; one written
/// anywhere else records its `#fileID`, so a reader holding the text can tell a line of its own
/// from the same line number in another file.
///
/// By default every file is the text's own. A host names the others when it runs a score:
/// `--sources-elsewhere <prefix>,…` are `#fileID` prefixes written somewhere else, and
/// `--source-here <prefix>` the one inside them that is the text after all.
@_documentation(visibility: internal)
public enum SourceFiles {
    nonisolated(unsafe) public static var elsewhere: [String] = []
    nonisolated(unsafe) public static var here: String? = nil

    /// The file a note written in `file` records.
    public static func stamp(_ file: String) -> String? {
        guard elsewhere.contains(where: { file.hasPrefix($0) }) else { return nil }
        if let here, file.hasPrefix(here) { return nil }
        return file
    }
}
