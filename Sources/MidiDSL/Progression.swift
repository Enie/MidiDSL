import Foundation

/// Chords named by Roman numerals in a key, played one after another.
///
/// Inside a section the chords play back to back, each a whole note unless
/// ``durations(_:)`` says otherwise.
///
/// ```swift
/// Section {
///     Progression("ii - V - I", for: .C4)
///         .qualities(.minor7, .dominant7, .major7)
///         .durations(0.5, 0.5, 1)
/// }
/// ```
///
/// Every modifier returns a changed copy. See <doc:ProgressionsAndScales>.
///
/// ## Topics
///
/// ### Making a progression
///
/// - ``init(_:for:minor:)``
///
/// ### Shaping it
///
/// - ``qualities(_:)``
/// - ``durations(_:)``
/// - ``velocities(_:)``
/// - ``startTimes(_:)``
/// - ``syncopate(by:)``
public class Progression {
    @_documentation(visibility: internal)
    public var chords: Chords

    /// A progression read from Roman numerals in a key.
    ///
    /// A numeral in the key's table takes the table's quality: in a major key `ii` is minor and
    /// `vii` diminished. Outside the table, the case decides: uppercase is major, lowercase minor,
    /// so `"II"` in C is D major. A suffix sets the quality outright: `"V7"`, `"iim7"`,
    /// `"Imaj7"`. A chord symbol such as `"Fmaj7"` can stand in for a numeral. A step that is
    /// neither is left out.
    ///
    /// ```swift
    /// Progression("I - vi - IV - V", for: .C4)
    /// Progression("i - iv - V", for: .A4, minor: true)   // V is major: the harmonic-minor dominant
    /// ```
    ///
    /// - Parameters:
    ///   - progression: The steps, separated by `" - "`.
    ///   - pitch: The key's tonic. Only its note name counts: the chords' roots are in octave 5.
    ///   - minor: `false` reads the numerals in the major table, `true` in the natural minor one
    ///     (i, ii°, III, iv, v, VI, VII).
    public init(_ progression: String, for pitch: Pitch, minor: Bool = false) {
        let key = NoteNotation(pitch: pitch)
        chords = Progression.transformProgression(progression, inKey: key, isMinor: minor)
            .split(separator: " - ")
            .compactMap { Chord(ChordNotation($0)) }
    }

    @_documentation(visibility: internal)
    public init(chords: Chords) {
        self.chords = chords
    }

    private func copied() -> Progression {
        Progression(chords: chords.map { $0.copy() })
    }

    /// Places each chord at a start time of its own, instead of back to back.
    ///
    /// Chords can overlap or leave gaps. A chord past the end of the list starts at 0.
    ///
    /// - Parameter startTimes: One start time per chord, in whole notes from the progression's start.
    /// - Returns: A changed copy.
    public func startTimes(_ startTimes: Double...) -> Progression {
        let newProgression = copied()
        for (index, startTime) in startTimes.enumerated() {
            if index < chords.count {
                newProgression.chords[index].notes = chords[index].notes.map {
                    Note(pitch: $0.pitch, velocity: $0.velocity, startTime: startTime, duration: $0.duration)
                }
            }
        }
        return newProgression
    }
    
    /// Gives each chord its own velocity, in order.
    ///
    /// - Parameter velocities: One velocity per chord, 0…127. Chords past the end keep theirs.
    /// - Returns: A changed copy.
    public func velocities(_ velocities: UInt32...) -> Progression {
        let newProgression = copied()
        for (index, velocity) in velocities.enumerated() {
            if index < chords.count {
                newProgression.chords[index].notes = chords[index].notes.map {
                    Note(pitch: $0.pitch, velocity: velocity, startTime: $0.startTime, duration: $0.duration)
                }
            }
        }
        return newProgression
    }

    /// Replaces each chord's quality, in order.
    ///
    /// - Parameter qualities: One quality per chord. Chords past the end keep theirs.
    /// - Returns: A changed copy.
    public func qualities(_ qualities: ChordQuality...) -> Progression {
        let newProgression = copied()
        for (index, quality) in qualities.enumerated() {
            if index < chords.count {
                let chord = chords[index]
                let duration = chord.notes.map { $0.duration }.max() ?? 1.0
                newProgression.chords[index].quality = quality
                newProgression.chords[index].notes = Chord.buildNotes(root: chord.root, quality: quality, duration: duration)
            }
        }
        return newProgression
    }

    /// Pulls every chord after the first earlier, so it arrives ahead of the beat.
    ///
    /// It sets the start times from the chords' durations, so call it after ``durations(_:)``.
    ///
    /// - Parameter amount: How much earlier, in whole notes. `.n16` is a sixteenth.
    /// - Returns: A changed copy.
    public func syncopate(by amount: MusicTimeStamp = .n16) -> Progression {
        let noteDurations = chords.map { $0.notes.map { $0.duration }.max() ?? 1.0 }
        var currentTime: MusicTimeStamp = 0
        let newProgression = copied()
        for (index, chord) in chords.enumerated() {
            let shiftedTime = index == 0 ? currentTime : max(0, currentTime - amount)
            newProgression.chords[index].notes = chord.notes.map {
                Note(pitch: $0.pitch, velocity: $0.velocity, startTime: shiftedTime, duration: $0.duration)
            }
            currentTime += noteDurations[index]
        }
        return newProgression
    }

    /// Gives each chord its own duration, in order.
    ///
    /// The chords follow one another, so this changes how long the progression lasts.
    ///
    /// - Parameter durations: One duration per chord, in whole notes. Chords past the end keep theirs.
    /// - Returns: A changed copy.
    public func durations(_ durations: Double...) -> Progression {
        let newProgression = copied()
        for (index, duration) in durations.enumerated() {
            if index < chords.count {
                newProgression.chords[index].notes = chords[index].notes.map {
                    Note(pitch: $0.pitch, velocity: $0.velocity, startTime: $0.startTime, duration: duration)
                }
            }
        }
        return newProgression
    }
    
    class func transformProgression(_ progression: String, inKey root: String, isMinor: Bool = false) -> String {
        let romanNumerals = progression.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        var chords = [String]()
        
        for numeral in romanNumerals {
            if let chord = Chord.transformRomanNumeral(numeral, inKey: root, isMinor: isMinor) {
                chords.append(chord)
            } else {
                chords.append(numeral)
            }
        }
        
        return chords.joined(separator: " - ")
    }
}
