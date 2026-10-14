import Foundation

public enum ScaleMode: String, Codable, CaseIterable, Hashable {
    case major, minor, dorian, phrygian, lydian, mixolydian, locrian
    case harmonicMinor, melodicMinor
    case majorPentatonic, minorPentatonic, blues, wholeTone, chromatic

    public var steps: [Int] {
        switch self {
        case .major:           return [0, 2, 4, 5, 7, 9, 11]
        case .minor:           return [0, 2, 3, 5, 7, 8, 10]
        case .dorian:          return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian:        return [0, 1, 3, 5, 7, 8, 10]
        case .lydian:          return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian:      return [0, 2, 4, 5, 7, 9, 10]
        case .locrian:         return [0, 1, 3, 5, 6, 8, 10]
        case .harmonicMinor:   return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:    return [0, 2, 3, 5, 7, 9, 11]
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .blues:           return [0, 3, 5, 6, 7, 10]
        case .wholeTone:       return [0, 2, 4, 6, 8, 10]
        case .chromatic:       return Array(0...11)
        }
    }

    public var degreeCount: Int { steps.count }
}

public struct ScaleDegree: Equatable, Hashable, Codable {
    public var degree: Int
    public var octave: Int
    public var alteration: Int

    public init(degree: Int, octave: Int = 0, alteration: Int = 0) {
        self.degree = degree
        self.octave = octave
        self.alteration = alteration
    }
}

public struct Scale: Equatable, Hashable, Codable {
    public var root: Pitch
    public var mode: ScaleMode

    public init(_ root: Pitch, _ mode: ScaleMode) {
        self.root = root
        self.mode = mode
    }

    public init(_ root: NoteNotation, _ mode: ScaleMode) {
        self.init(pitchForNoteName(root) ?? 60, mode)
    }

    public func pitch(_ written: ScaleDegree) -> Pitch {
        let steps = mode.steps
        let count = steps.count
        let index = written.degree - 1
        let wraps = Int(floor(Double(index) / Double(count)))
        let within = index - wraps * count
        let value = Int(root) + steps[within] + 12 * (wraps + written.octave) + written.alteration
        return Pitch(min(max(value, 0), 127))
    }

    public var pitches: [Pitch] {
        (1...mode.degreeCount).map { pitch(ScaleDegree(degree: $0)) }
    }

    public static let unkeyed = Scale(60, .major)

    // MARK: Note names (the older, string-shaped API)

    public static let noteSequence: [NoteNotation] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    public static func generateScale(root: String, intervals: [Int]) -> [String] {
        guard let rootPitch = pitchForNoteName(root), !intervals.isEmpty else {
            return []
        }

        var currentIndex = Int(rootPitch) % noteSequence.count
        var scale = [noteSequence[currentIndex]]

        for interval in intervals.dropLast() {
            currentIndex = (currentIndex + interval) % noteSequence.count
            scale.append(noteSequence[currentIndex])
        }

        return scale
    }

    public static func majorScale(for root: String) -> [String] {
        return generateScale(root: root, intervals: [2, 2, 1, 2, 2, 2, 1])
    }

    public static func minorScale(for root: String) -> [String] {
        return generateScale(root: root, intervals: [2, 1, 2, 2, 1, 2, 2])
    }

    public static func dorianScale(for root: String) -> [String] {
        return generateScale(root: root, intervals: [2, 1, 2, 2, 2, 1, 2])
    }
}
