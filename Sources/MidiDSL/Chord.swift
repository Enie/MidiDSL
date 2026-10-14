import Foundation
public enum ArpeggioPattern {
    case up, down, random
    case custom([Int])
    case alternating
    case rootFirst
    case rootLast
}

public enum ChordQuality: Equatable {
    case major, minor, diminished, augmented, dominant7, major7, minor7, add9, sus4, sus2, majorSixth, minorSixth, dominant7sus4, add11, power, halfDiminished, diminished7, dominant9, major9, minor9, minor11, dominant13, sixNine, minorMajor7, augmented7, augmentedMajor7, minorAdd9, dominant11, major11, major13, minor13, dominant9sus4, custom(String)

    var intervals: [UInt32] {
        switch self {
        case .major:
            return [0, 4, 7]
        case .minor:
            return [0, 3, 7]
        case .diminished:
            return [0, 3, 6]
        case .augmented:
            return [0, 4, 8]
        case .dominant7:
            return [0, 4, 7, 10]
        case .major7:
            return [0, 4, 7, 11]
        case .minor7:
            return [0, 3, 7, 10]
        case .add9:
            return [0, 4, 7, 14]
        case .sus4:
            return [0, 5, 7]
        case .sus2: 
            return [0, 2, 7]
        case .majorSixth:
            return [0, 4, 7, 9]
        case .minorSixth:
            return [0, 3, 7, 9]
        case .dominant7sus4:
            return [0, 5, 7, 10]
        case .add11:
            return [0, 4, 7, 17]
        case .power:
            return [0, 7]
        case .halfDiminished:
            return [0, 3, 6, 10]
        case .diminished7:
            return [0, 3, 6, 9]
        case .dominant9:
            return [0, 4, 7, 10, 14]
        case .major9:
            return [0, 4, 7, 11, 14]
        case .minor9:
            return [0, 3, 7, 10, 14]
        case .minor11:
            return [0, 3, 7, 10, 14, 17]
        case .dominant13:
            return [0, 4, 7, 10, 14, 21]
        case .sixNine:
            return [0, 4, 7, 9, 14]
        case .minorMajor7:
            return [0, 3, 7, 11]
        case .augmented7:
            return [0, 4, 8, 10]
        case .augmentedMajor7:
            return [0, 4, 8, 11]
        case .minorAdd9:
            return [0, 3, 7, 14]
        case .dominant11:
            return [0, 7, 10, 14, 17]
        case .major11:
            return [0, 7, 11, 14, 17]
        case .major13:
            return [0, 4, 7, 11, 14, 21]
        case .minor13:
            return [0, 3, 7, 10, 14, 21]
        case .dominant9sus4:
            return [0, 5, 7, 10, 14]
        case .custom(let intervals):
            return intervals.split(separator: ",").compactMap { UInt32($0) }
        }
    }
}

public extension ChordQuality {
    var notation: String {
        switch self {
        case .major:
            return "maj"
        case .minor:
            return "min"
        case .diminished:
            return "dim"
        case .augmented:
            return "aug"
        case .dominant7:
            return "dom7"
        case .major7:
            return "maj7"
        case .minor7:
            return "min7"
        case .add9:
            return "add9"
        case .sus4:
            return "sus4"
        case .sus2:
            return "sus2"
        case .majorSixth:
            return "maj6"
        case .minorSixth:
            return "min6"
        case .dominant7sus4:
            return "7sus4"
        case .add11:
            return "add11"
        case .power:
            return "pow"
        case .halfDiminished:
            return "ø7"
        case .diminished7:
            return "dim7"
        case .dominant9:
            return "dom9"
        case .major9:
            return "maj9"
        case .minor9:
            return "min9"
        case .minor11:
            return "min11"
        case .dominant13:
            return "dom13"
        case .sixNine:
            return "69"
        case .minorMajor7:
            return "mMaj7"
        case .augmented7:
            return "aug7"
        case .augmentedMajor7:
            return "augMaj7"
        case .minorAdd9:
            return "madd9"
        case .dominant11:
            return "dom11"
        case .major11:
            return "maj11"
        case .major13:
            return "maj13"
        case .minor13:
            return "min13"
        case .dominant9sus4:
            return "9sus4"
        case .custom(let intervals):
            return "cus\(intervals)"
        }
    }
}

public extension ChordQuality {
    init?(from notation: String) {
        if let exact = ChordQuality.exactMatch(notation) {
            self = exact
            return
        }
        if notation.hasPrefix("cus"), notation.count > 3 {
            self = .custom(String(notation.dropFirst(3)))
            return
        }
        if let altered = ChordQuality.decomposeAlterations(notation) {
            self = altered
            return
        }
        return nil
    }

    private static func decomposeAlterations(_ notation: String) -> ChordQuality? {
        var head = notation[...]
        var groups: [String] = []
        while let match = head.range(of: "(b|#)(5|9|11|13)$", options: .regularExpression) {
            groups.insert(String(head[match]), at: 0)
            head = head[head.startIndex..<match.lowerBound]
        }
        guard !groups.isEmpty else { return nil }

        for split in stride(from: groups.count - 1, through: 0, by: -1) {
            let qualityToken = String(head) + groups[0..<split].joined()
            guard let base = exactMatch(qualityToken) else { continue }

            var intervals = base.intervals
            for token in groups[split...] {
                guard let semitones = Chord.semitones(forExtension: token, baseQuality: base) else { return nil }
                if token == "b5" || token == "#5" {
                    intervals.removeAll { $0 == 7 }
                }
                if !intervals.contains(semitones) { intervals.append(semitones) }
            }
            return .custom(intervals.sorted().map(String.init).joined(separator: ","))
        }
        return nil
    }

    private static func exactMatch(_ notation: String) -> ChordQuality? {
        switch notation {
        case "", "M", "maj":
            return .major
        case "m", "mi", "min", "−":
            return .minor
        case "dim", "o":
            return .diminished
        case "aug", "+":
            return .augmented
        case "7", "dom7", "dom":
            return .dominant7
        case "M7", "maj7", "Δ7", "Δ":
            return .major7
        case "m7", "mi7", "min7", "−7":
            return .minor7
        case "add9":
            return .add9
        case "sus4", "sus":
            return .sus4
        case "sus2":
            return .sus2
        case "maj6", "M6", "6th":
            return .majorSixth
        case "m6", "mi6", "min6", "−6":
            return .minorSixth
        case "7sus4", "dom7sus4":
            return .dominant7sus4
        case "add11":
            return .add11
        case "pow", "no3":
            return .power
        case "ø7", "ø", "m7b5":
            return .halfDiminished
        case "o7", "dim7":
            return .diminished7
        case "dom9":
            return .dominant9
        case "M9", "maj9", "Δ9":
            return .major9
        case "m9", "mi9", "min9", "−9":
            return .minor9
        case "m11", "mi11", "min11", "−11":
            return .minor11
        case "13", "dom13":
            return .dominant13
        case "69", "6/9", "6add9":
            return .sixNine
        case "mMaj7", "mM7", "minMaj7":
            return .minorMajor7
        case "aug7", "+7":
            return .augmented7
        case "augMaj7", "augM7", "+M7":
            return .augmentedMajor7
        case "madd9", "minadd9":
            return .minorAdd9
        case "11", "dom11":
            return .dominant11
        case "maj11", "M11":
            return .major11
        case "maj13", "M13":
            return .major13
        case "m13", "mi13", "min13", "−13":
            return .minor13
        case "9sus4", "dom9sus4":
            return .dominant9sus4
        default:
            return nil
        }
    }
}

public typealias ChordNotation = String
public extension ChordNotation {
    private var rootLength: Int {
        let chars: [Character] = Array(self)
        return chars.count > 1 && (chars[1] == "#" || chars[1] == "b") ? 2 : 1
    }
    var root: NoteNotation {
        String(prefix(rootLength))
    }
    var quality: ChordQuality {
        ChordQuality(from: String(dropFirst(rootLength))) ?? .major
    }
}

func arpeggiatedNotes(_ notes: [Note], pattern: ArpeggioPattern,
                      delay: MusicTimeStamp, rootPitch: Pitch? = nil) -> [Note] {
    guard !notes.isEmpty else { return notes }

    let sorted = notes.sorted { $0.pitch ?? 0 < $1.pitch ?? 0 }
    func rootIndex() -> Int {
        guard let rootPitch else { return 0 }
        return sorted.firstIndex { note in note.pitch.map { $0 % 12 == rootPitch % 12 } == true } ?? 0
    }

    let orderedNotes: [Note]
    switch pattern {
    case .up:
        orderedNotes = sorted

    case .down:
        orderedNotes = sorted.reversed()

    case .random:
        orderedNotes = Dice.shuffled(notes, salt: Dice.salt(notes.map { UInt64($0.pitch ?? 0) }))

    case .custom(let indices):
        orderedNotes = indices.compactMap { index in
            index >= 0 && index < notes.count ? notes[index] : nil
        }

    case .alternating:
        guard sorted.count >= 3 else {
            orderedNotes = sorted
            break
        }
        orderedNotes = [sorted.first!, sorted.last!] + sorted[1..<sorted.count - 1]

    case .rootFirst:
        var rest = sorted
        let root = rest.remove(at: rootIndex())
        orderedNotes = [root] + rest

    case .rootLast:
        var rest = sorted
        let root = rest.remove(at: rootIndex())
        orderedNotes = rest + [root]
    }

    return orderedNotes.enumerated().map { index, note in
        var n = note
        n.startTime = note.startTime + (MusicTimeStamp(index) * delay)
        return n
    }
}

public class Chord {
    public var notes: [Note] = []
    public var root: NoteNotation
    public var quality: ChordQuality
    public var duration: MusicTimeStamp { notes.reduce(into: 0) { $0 = max($0, $1.startTime+$1.duration) } }
    
    public init(_ root: NoteNotation, _ quality: ChordQuality, _ duration: MusicTimeStamp = 1.0) {
        self.root = root
        self.quality = quality
        self.notes = Chord.buildNotes(root: root, quality: quality, duration: duration)
    }
    
    public init?(_ notation: ChordNotation, _ duration: MusicTimeStamp = 1.0) {
        root = notation.root
        quality = notation.quality

        guard root.pitch != nil else { return nil }

        notes = Chord.buildNotes(root: root, quality: quality, duration: duration)
    }
    
    public static func buildNotes(root: NoteNotation, quality: ChordQuality = .major, duration: MusicTimeStamp = 1.0) -> [Note] {
        guard let rootPitch = root.pitch else {
            return []
        }
        
        var notes = [Note]()
        for interval in quality.intervals {
            let pitch = rootPitch + interval
            notes.append(Note(pitch: pitch, duration: duration))
        }
        
        return notes
    }
    
    public static let majorChordTypes: [String: ChordQuality] = [
        "I": .major, "ii": .minor, "iii": .minor, "IV": .major, "V": .major, "vi": .minor, "vii": .diminished
    ]
    
    public static let minorChordTypes: [String: ChordQuality] = [
        "i": .minor, "ii": .diminished, "III": .major, "iv": .minor, "v": .minor, "VI": .major, "VII": .major
    ]
    
    public func copy() -> Chord {
        let chord = Chord(root, quality)
        chord.notes = notes
        return chord
    }

    public var notation: ChordNotation {
        return "\(root)\(quality.notation)"
    }
    
    public var noteNotations: [NoteNotation] {
        return notes.map{NoteNotation(pitch: $0.pitch)}
    }
    
    public static let romanNumeralToScaleDegree: [String: Int] = [
        "I": 0, "II": 1, "III": 2, "IV": 3, "V": 4, "VI": 5, "VII": 6,
        "i": 0, "ii": 1, "iii": 2, "iv": 3, "v": 4, "vi": 5, "vii": 6
    ]
    
    public class func transformRomanNumeral(_ romanNumeral: String, inKey root: String, isMinor: Bool = false) -> String? {
        let core = String(romanNumeral.prefix(while: { "IiVv".contains($0) }))
        let suffix = String(romanNumeral.dropFirst(core.count))
        guard let scaleDegree = romanNumeralToScaleDegree[core] else {
            return nil
        }

        let scale = isMinor ? Scale.minorScale(for: root) : Scale.majorScale(for: root)

        let type: ChordQuality
        if suffix.isEmpty {
            let table = isMinor ? minorChordTypes : majorChordTypes
            type = table[core] ?? (core.first?.isUppercase == true ? .major : .minor)
        } else {
            guard let explicit = ChordQuality(from: suffix) else {
                return nil
            }
            type = explicit
        }

        let chordRoot = scale[scaleDegree]
        return chordRoot + type.notation
    }
    
    public func velocities(_ velocities: UInt32...) -> Chord {
        for (index, velocity) in velocities.enumerated() {
            if index < notes.count {
                notes[index].velocity = min(max(velocity, 0), 127)
            }
        }
        return self
    }
    
    public func natural() -> Chord {
        let chordSalt = Dice.salt([UInt64(root.pitch ?? 0)] + quality.intervals.map(UInt64.init))
        let sortedNotes = notes.sorted { $0.pitch ?? 0 < $1.pitch ?? 0 }
        notes = sortedNotes.enumerated().map { index, note in
            let baseVelocity: UInt32 = 80
            let variation = UInt32(Dice.roll(salt: Dice.mix(chordSalt ^ UInt64(index)),
                                             loopIndex: 0, count: 11))
            let rootEmphasis: UInt32 = index == 0 ? 15 : 0
            let velocity = min(127, baseVelocity + variation + rootEmphasis)

            var n = note
            n.velocity = velocity
            return n
        }
        return self
    }

    public func durations(_ durations: Double...) -> Chord {
        for (index, duration) in durations.enumerated() {
            if index < notes.count {
                notes[index].duration = duration
            }
        }
        return self
    }
    
    public func duration(_ duration: MusicTimeStamp) -> Chord {
        notes = notes.map { note in
            var n = note
            n.duration = duration
            return n
        }
        return self
    }
    
    public func arpeggio(_ pattern: ArpeggioPattern = .up, delay: MusicTimeStamp = 0.05) -> Chord {
        notes = arpeggiatedNotes(notes, pattern: pattern, delay: delay, rootPitch: root.pitch)
        return self
    }
    
    public func arpeggio(over totalDuration: MusicTimeStamp, pattern: ArpeggioPattern = .up) -> Chord {
        let delay = notes.isEmpty ? 0 : totalDuration / MusicTimeStamp(notes.count)
        return arpeggio(pattern, delay: delay)
    }

    public func arpeggioUp(delay: MusicTimeStamp = 0.05) -> Chord {
        return arpeggio(.up, delay: delay)
    }
    
    public func arpeggioDown(delay: MusicTimeStamp = 0.05) -> Chord {
        return arpeggio(.down, delay: delay)
    }
    
    public func arpeggioCustom(_ order: [Int], delay: MusicTimeStamp = 0.05) -> Chord {
        return arpeggio(.custom(order), delay: delay)
    }

    static func semitones(forExtension token: String, baseQuality: ChordQuality) -> UInt32? {
        switch token {
        case "7":
            guard !baseQuality.intervals.contains(where: { $0 == 9 || $0 == 10 || $0 == 11 }) else { return nil }
            switch baseQuality {
            case .major, .augmented, .add9: return 11
            case .minor, .sus4:             return 10
            case .diminished:               return 9
            default:                        return 10
            }
        case "b7":          return 10
        case "maj7", "M7":  return 11
        case "b5":          return 6
        case "#5", "s5":    return 8
        case "9":           return 14
        case "b9":          return 13
        case "#9", "s9":    return 15
        case "11":          return 17
        case "#11", "s11":  return 18
        case "13":          return 21
        case "b13":         return 20
        default:            return nil
        }
    }

    @discardableResult
    public func addExtensions(_ tokens: [String]) -> Chord {
        guard let rootPitch = root.pitch else { return self }
        var seen = Set(quality.intervals)
        let dur = notes.map { $0.duration }.max() ?? 1.0
        for token in tokens {
            guard let s = Chord.semitones(forExtension: token, baseQuality: quality) else { continue }
            if token == "b5" || token == "#5" || token == "s5" {
                notes.removeAll { $0.pitch == rootPitch + 7 }
                seen.remove(7)
            }
            guard seen.insert(s).inserted else { continue }
            notes.append(Note(pitch: rootPitch + s, duration: dur))
        }
        return self
    }

    @discardableResult
    public func ext(_ extensions: String...) -> Chord {
        return addExtensions(extensions)
    }
}

public typealias Chords = [Chord]
