import Foundation

/// Chords named by Roman numerals in a key, played one after another.
///
/// See <doc:ProgressionsAndScales>.
public class Progression {
    @_documentation(visibility: internal)
    public var chords: Chords

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
