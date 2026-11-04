import Foundation

/// A position or length in whole notes: `1.0` is one whole note, `.quarter` is `0.25`.
///
/// See <doc:PitchesAndDurations>.
public typealias MusicTimeStamp = Double

@_documentation(visibility: internal)
public let pitchForNote: [String: UInt32] = [
    "C0": 0, "C#0": 1, "Db0": 1, "D0": 2, "D#0": 3, "Eb0": 3, "E0": 4, "F0": 5,
    "F#0": 6, "Gb0": 6, "G0": 7, "G#0": 8, "Ab0": 8, "A0": 9, "A#0": 10, "Bb0": 10, "B0": 11,
    "C1": 12, "C#1": 13, "Db1": 13, "D1": 14, "D#1": 15, "Eb1": 15, "E1": 16, "F1": 17,
    "F#1": 18, "Gb1": 18, "G1": 19, "G#1": 20, "Ab1": 20, "A1": 21, "A#1": 22, "Bb1": 22, "B1": 23,
    "C2": 24, "C#2": 25, "Db2": 25, "D2": 26, "D#2": 27, "Eb2": 27, "E2": 28, "F2": 29,
    "F#2": 30, "Gb2": 30, "G2": 31, "G#2": 32, "Ab2": 32, "A2": 33, "A#2": 34, "Bb2": 34, "B2": 35,
    "C3": 36, "C#3": 37, "Db3": 37, "D3": 38, "D#3": 39, "Eb3": 39, "E3": 40, "F3": 41,
    "F#3": 42, "Gb3": 42, "G3": 43, "G#3": 44, "Ab3": 44, "A3": 45, "A#3": 46, "Bb3": 46, "B3": 47,
    "C4": 48, "C#4": 49, "Db4": 49, "D4": 50, "D#4": 51, "Eb4": 51, "E4": 52, "F4": 53,
    "F#4": 54, "Gb4": 54, "G4": 55, "G#4": 56, "Ab4": 56, "A4": 57, "A#4": 58, "Bb4": 58, "B4": 59,
    "C5": 60, "C#5": 61, "Db5": 61, "D5": 62, "D#5": 63, "Eb5": 63, "E5": 64, "F5": 65,
    "F#5": 66, "Gb5": 66, "G5": 67, "G#5": 68, "Ab5": 68, "A5": 69, "A#5": 70, "Bb5": 70, "B5": 71,
    "C6": 72, "C#6": 73, "Db6": 73, "D6": 74, "D#6": 75, "Eb6": 75, "E6": 76, "F6": 77,
    "F#6": 78, "Gb6": 78, "G6": 79, "G#6": 80, "Ab6": 80, "A6": 81, "A#6": 82, "Bb6": 82, "B6": 83,
    "C7": 84, "C#7": 85, "Db7": 85, "D7": 86, "D#7": 87, "Eb7": 87, "E7": 88, "F7": 89,
    "F#7": 90, "Gb7": 90, "G7": 91, "G#7": 92, "Ab7": 92, "A7": 93, "A#7": 94, "Bb7": 94, "B7": 95,
    "C8": 96, "C#8": 97, "Db8": 97, "D8": 98, "D#8": 99, "Eb8": 99, "E8": 100, "F8": 101,
    "F#8": 102, "Gb8": 102, "G8": 103, "G#8": 104, "Ab8": 104, "A8": 105, "A#8": 106, "Bb8": 106, "B8": 107,
    "C9": 108, "C#9": 109, "Db9": 109, "D9": 110, "D#9": 111, "Eb9": 111, "E9": 112, "F9": 113,
    "F#9": 114, "Gb9": 114, "G9": 115, "G#9": 116, "Ab9": 116, "A9": 117, "A#9": 118, "Bb9": 118, "B9": 119,
    "C10": 120, "C#10": 121, "Db10": 121, "D10": 122, "D#10": 123, "Eb10": 123, "E10": 124, "F10": 125,
    "F#10": 126, "Gb10": 126, "G10": 127,

    "C": 60, "C#": 61, "Db": 61, "D": 62, "D#": 63, "Eb": 63, "E": 64, "F": 65,
    "F#": 66, "Gb": 66, "G": 67, "G#": 68, "Ab": 68, "A": 69, "A#": 70, "Bb": 70, "B": 71,
]

private let semitoneForNoteLetter: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5,
                                                       "G": 7, "A": 9, "B": 11]

@_documentation(visibility: internal)
public func pitchForNoteName(_ name: String) -> UInt32? {
    var i = name.startIndex
    guard i < name.endIndex, let base = semitoneForNoteLetter[name[i]] else { return nil }
    i = name.index(after: i)
    var alteration = 0
    while i < name.endIndex, name[i] == "#" || name[i] == "b" {
        alteration += name[i] == "#" ? 1 : -1
        i = name.index(after: i)
    }
    var digits = ""
    while i < name.endIndex, name[i].isWholeNumber {
        digits.append(name[i])
        i = name.index(after: i)
    }
    guard i == name.endIndex else { return nil }
    let octave = digits.isEmpty ? 5 : (Int(digits) ?? -1)
    guard (0...10).contains(octave) else { return nil }
    let value = octave * 12 + base + alteration
    guard (0...127).contains(value) else { return nil }
    return UInt32(value)
}

@_documentation(visibility: internal)
public typealias NoteNotation = String
public extension NoteNotation {
    @_documentation(visibility: internal)
    var pitch: UInt32? { return pitchForNoteName(self) }

    @_documentation(visibility: internal)
    init(pitch: UInt32?) {
        if let note = pitchForNote.first(where: { $0.value == pitch && $0.key.range(of: "b") == nil })?.key {
            self = note
            if note.range(of: "\\d", options: .regularExpression) == nil {
                self = note + "5"
            }
        } else {   
            self = " "
        }
    }
}

/// How a note set chooses its member on each pass: upward, downward, alternating, or by the dice.
///
/// See <doc:NotesRestsAndNoteSets>.
public enum NoteSetMode: String, Codable {
    case up, down, random, alternating

    @_documentation(visibility: internal)
    public func soundingIndex(count: Int, pass: Int, diceSalt: UInt64, seed: UInt64) -> Int {
        variantIndex(loopIndex: pass, count: count,
                     salt: Dice.salt(diceSalt, for: .pitch, seed: seed))
    }

    @_documentation(visibility: internal)
    public func variantIndex(loopIndex: Int, count: Int, salt: UInt64 = 0) -> Int {
        let n = count
        guard n > 1 else { return 0 }
        switch self {
        case .up:
            return loopIndex % n
        case .down:
            return (n - 1) - (loopIndex % n)
        case .random:
            return Dice.roll(salt: salt, loopIndex: loopIndex, count: n)
        case .alternating:
            let period = (n - 1) * 2
            let pos = loopIndex % period
            return pos < n ? pos : period - pos
        }
    }
}

@_documentation(visibility: internal)
public struct SlideStep: Equatable, Hashable, Codable {
    public var from: Pitch
    public var at: MusicTimeStamp
    public var over: MusicTimeStamp
    public var carry: Double?
    @_documentation(visibility: internal)
    public var degree: ScaleDegree?

    public init(from: Pitch, at: MusicTimeStamp, over: MusicTimeStamp = 0, carry: Double? = nil,
                degree: ScaleDegree? = nil) {
        self.from = from
        self.at = at
        self.over = over
        self.carry = carry
        self.degree = degree
    }
}

@_documentation(visibility: internal)
public struct Fall: Equatable, Hashable, Codable {
    public var semitones: Int
    public var over: MusicTimeStamp

    public init(semitones: Int, over: MusicTimeStamp = 0) {
        self.semitones = semitones
        self.over = over
    }
}

/// What an automation curve moves: volume, filter cutoff and resonance, reverb, or a MIDI controller.
///
/// See <doc:Automation>.
public enum AutomationTarget: Equatable, Hashable, Codable {
    case volume
    case cutoff
    case resonance
    case reverb
    case cc(Int)
    /// A parameter of something a program playing the session runs on the track, such as an
    /// effect plugin: named by the thing as that program's score writes it, and by the parameter's
    /// display name. The value is 0…1 across the parameter's own range. A MIDI file has no word
    /// for it and leaves it out.
    @_documentation(visibility: internal)
    case host(String, parameter: String)

    @_documentation(visibility: internal)
    public static let fixed: [AutomationTarget] = [.volume, .cutoff, .resonance, .reverb]

    @_documentation(visibility: internal)
    public var isPerVoice: Bool { self == .volume }

    @_documentation(visibility: internal)
    public var neutralValue: Double? { isPerVoice ? 1.0 : nil }

    @_documentation(visibility: internal)
    public var valueRange: ClosedRange<Double> {
        switch self {
        case .volume, .reverb, .cc, .host: return 0...1
        case .cutoff: return 20...20000
        case .resonance: return 0...2.5
        }
    }

    /// The controller a MIDI file or a MIDI port carries a track-wide curve on: 74 for the
    /// cutoff (brightness), 71 for the resonance (timbre), 91 for the reverb send, the number
    /// itself for `.cc`. Nil for volume, which rides each voice as expression (CC 11), and for a
    /// `.host` parameter.
    @_documentation(visibility: internal)
    public var midiController: UInt8? {
        switch self {
        case .cutoff: return 74
        case .resonance: return 71
        case .reverb: return 91
        case .cc(let number): return (0...127).contains(number) ? UInt8(number) : nil
        case .volume, .host: return nil
        }
    }

    /// A value of this target as a controller value, 0…127: the cutoff on a logarithmic scale
    /// across 20 Hz…20 kHz (as the ear hears it), everything else straight across its range.
    @_documentation(visibility: internal)
    public func midiValue(_ value: Double) -> UInt8 {
        let normalized: Double
        switch self {
        case .cutoff:
            let low = log2(20.0), high = log2(20000.0)
            normalized = (log2(max(20.0, min(20000.0, value))) - low) / (high - low)
        default:
            let range = valueRange
            normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        }
        return UInt8(max(0, min(127, (normalized * 127).rounded())))
    }
}

/// How an automation curve travels from one breakpoint to the next.
///
/// See <doc:Automation>.
public enum AutomationShape: String, Equatable, Hashable, Codable, CaseIterable {
    case linear
    case exponential
    case smooth
    case hold

    func fraction(_ x: Double) -> Double {
        switch self {
        case .linear: return x
        case .hold:   return x >= 1 ? 1 : 0
        case .smooth: return 0.5 - 0.5 * cos(x * Double.pi)
        case .exponential:
            let e = exp(-4.0)
            return 1 - (exp(-4 * x) - e) / (1 - e)
        }
    }

    var subdivisions: Int {
        switch self {
        case .linear: return 1
        case .hold:   return 2
        default:      return 16
        }
    }
}

@_documentation(visibility: internal)
public struct AutomationPoint: Equatable, Hashable, Codable {
    public var time: MusicTimeStamp
    public var value: Double

    public init(time: MusicTimeStamp, value: Double) {
        self.time = time
        self.value = value
    }
}

@_documentation(visibility: internal)
public struct AutomationCurve: Equatable, Hashable, Codable {
    public var target: AutomationTarget
    public var points: [AutomationPoint]

    public init(target: AutomationTarget, points: [AutomationPoint]) {
        self.target = target
        self.points = points.sorted { $0.time < $1.time }
    }

    public static func make(_ target: AutomationTarget,
                            _ breakpoints: [Double: Double],
                            timeScale: MusicTimeStamp,
                            curve: AutomationShape = .linear) -> AutomationCurve? {
        guard !breakpoints.isEmpty else { return nil }
        let range = target.valueRange
        let written = breakpoints
            .map { AutomationPoint(time: $0.key * timeScale,
                                   value: min(max($0.value, range.lowerBound), range.upperBound)) }
            .sorted { $0.time < $1.time }
        guard curve != .linear, written.count > 1 else {
            return AutomationCurve(target: target, points: written)
        }

        var expanded: [AutomationPoint] = [written[0]]
        for i in 1..<written.count {
            let a = written[i - 1], b = written[i]
            let span = b.time - a.time
            let steps = span > 0 ? curve.subdivisions : 1
            for s in 1...steps {
                let x = Double(s) / Double(steps)
                let time = curve == .hold && s == 1
                    ? a.time + span * (1 - 1e-6)
                    : a.time + span * x
                expanded.append(AutomationPoint(time: time,
                                                value: a.value + (b.value - a.value) * curve.fraction(x)))
            }
        }
        return AutomationCurve(target: target, points: expanded)
    }

    public func value(at time: MusicTimeStamp) -> Double {
        guard let first = points.first else { return 0 }
        if time <= first.time { return first.value }
        guard let last = points.last else { return first.value }
        if time >= last.time { return last.value }
        for i in 1..<points.count where points[i].time >= time {
            let a = points[i - 1], b = points[i]
            let span = b.time - a.time
            guard span > 0 else { return b.value }
            return a.value + (b.value - a.value) * ((time - a.time) / span)
        }
        return last.value
    }

    public func maxValue(from: MusicTimeStamp, to: MusicTimeStamp) -> Double {
        var best = max(value(at: from), value(at: to))
        for point in points where point.time > from && point.time < to {
            best = max(best, point.value)
        }
        return best
    }

    public func sliced(from start: MusicTimeStamp, length: MusicTimeStamp) -> AutomationCurve? {
        guard length > 0 else { return nil }
        let end = start + length
        var sliced: [AutomationPoint] = [AutomationPoint(time: 0, value: value(at: start))]
        for point in points where point.time > start && point.time < end {
            sliced.append(AutomationPoint(time: point.time - start, value: point.value))
        }
        sliced.append(AutomationPoint(time: length, value: value(at: end)))

        let first = sliced[0].value
        if sliced.allSatisfy({ abs($0.value - first) < 1e-9 }) {
            if let neutral = target.neutralValue, abs(first - neutral) < 1e-9 { return nil }
            return AutomationCurve(target: target, points: [AutomationPoint(time: 0, value: first)])
        }
        return AutomationCurve(target: target, points: sliced)
    }

    public func shiftingTimes(by delta: MusicTimeStamp) -> AutomationCurve {
        AutomationCurve(target: target,
                        points: points.map { AutomationPoint(time: $0.time + delta, value: $0.value) })
    }

    public func scalingTimes(by factor: Double) -> AutomationCurve {
        AutomationCurve(target: target,
                        points: points.map { AutomationPoint(time: $0.time * factor, value: $0.value) })
    }
}

public extension Array where Element == AutomationCurve {
    @_documentation(visibility: internal)
    func gain(at time: MusicTimeStamp) -> Double {
        reduce(1.0) { $1.target == .volume ? $0 * $1.value(at: time) : $0 }
    }

    @_documentation(visibility: internal)
    func maxGain(from: MusicTimeStamp, to: MusicTimeStamp) -> Double {
        reduce(1.0) { $1.target == .volume ? $0 * $1.maxValue(from: from, to: to) : $0 }
    }
}

@_documentation(visibility: internal)
public enum NotationID {
    public static func of<S: StringProtocol>(_ text: S) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}

/// One sounding note: a pitch, a velocity, a start time and a duration in whole notes.
///
/// Scores usually write notes as notation strings rather than building them. See <doc:NotesRestsAndNoteSets>.
public struct Note: Equatable, Codable, Identifiable {
    @_documentation(visibility: internal)
    public var id: UUID = UUID()
    public var pitch: Pitch?
    public var velocity: UInt32 = 100
    public var startTime: MusicTimeStamp = 0
    public var duration: MusicTimeStamp = .whole
    @_documentation(visibility: internal)
    public var pitchVariants: [Pitch]? = nil
    @_documentation(visibility: internal)
    public var variantMode: NoteSetMode? = nil
    @_documentation(visibility: internal)
    public var slides: [SlideStep]? = nil
    @_documentation(visibility: internal)
    public var fall: Fall? = nil
    @_documentation(visibility: internal)
    public var automation: [AutomationCurve]? = nil
    @_documentation(visibility: internal)
    public var activity: LoopActivity? = nil

    @_documentation(visibility: internal)
    public var degree: ScaleDegree? = nil
    @_documentation(visibility: internal)
    public var scale: Scale? = nil
    @_documentation(visibility: internal)
    public var variantDegrees: [ScaleDegree?]? = nil

    @_documentation(visibility: internal)
    public var velocityChoices: ClosedRange<UInt32>? = nil
    @_documentation(visibility: internal)
    public var durationChoices: [MusicTimeStamp]? = nil
    @_documentation(visibility: internal)
    public var dice: DiceGate? = nil
    @_documentation(visibility: internal)
    public var layerIndex: Int? = nil

    @_documentation(visibility: internal)
    public var loop: LoopStamp? = nil

    @_documentation(visibility: internal)
    public var sourceLine: Int? = nil
    @_documentation(visibility: internal)
    public var sourceColumn: Int? = nil
    @_documentation(visibility: internal)
    public var sourceFile: String? = nil
    @_documentation(visibility: internal)
    public var sourceOffset: Int? = nil
    @_documentation(visibility: internal)
    public var sourceLength: Int? = nil
    @_documentation(visibility: internal)
    public var notationID: UInt64? = nil
    @_documentation(visibility: internal)
    public var variantSourceOffsets: [Int]? = nil
    @_documentation(visibility: internal)
    public var variantSourceLengths: [Int]? = nil
    @_documentation(visibility: internal)
    public var slideSourceOffsets: [Int]? = nil
    @_documentation(visibility: internal)
    public var slideSourceLengths: [Int]? = nil

    public init(pitch: Pitch?, velocity: UInt32, startTime: MusicTimeStamp, duration: MusicTimeStamp) {
        self.pitch = pitch
        self.velocity = min(max(velocity, 0), 127)
        self.startTime = startTime
        self.duration = duration
    }

    public init(pitch: Pitch?) {
        self.pitch = pitch
        self.velocity = 100
        self.startTime = 0
        self.duration = .quarter
    }

    public init(pitch: Pitch?, duration: MusicTimeStamp) {
        self.pitch = pitch
        self.velocity = 100
        self.startTime = 0
        self.duration = duration
    }

    public init(pitch: Pitch?, velocity: UInt32, duration: MusicTimeStamp) {
        self.pitch = pitch
        self.velocity = min(max(velocity, 0), 127)
        self.startTime = 0
        self.duration = duration
    }
}

public extension Note {
    @_documentation(visibility: internal)
    func scalingSlides(from oldDuration: MusicTimeStamp, to newDuration: MusicTimeStamp) -> Note {
        guard slides != nil || fall != nil || automation != nil,
              oldDuration > 0, newDuration != oldDuration else { return self }
        let factor = newDuration / oldDuration
        var n = self
        if let steps = slides {
            n.slides = steps.map { step in
                SlideStep(from: step.from,
                          at: step.at * factor,
                          over: step.over == 0 ? 0 : step.over * factor,
                          carry: step.carry,
                          degree: step.degree)
            }
        }
        if let f = fall, f.over != 0 {
            n.fall = Fall(semitones: f.semitones, over: f.over * factor)
        }
        n.automation = automation.map { $0.map { $0.scalingTimes(by: factor) } }
        return n
    }
}

/// A silent note that holds its time.
///
/// See <doc:NotesRestsAndNoteSets>.
public typealias Rest = Note
extension Rest {
    public init() {
        self.startTime = 0
        self.duration = 1
    }
    public init(startTime: MusicTimeStamp, duration: MusicTimeStamp) {
        self.startTime = startTime
        self.duration = duration
    }
}

/// Pitches that take turns: a different member sounds on each pass.
///
/// See <doc:NotesRestsAndNoteSets>.
public struct NoteSet {
    @_documentation(visibility: internal)
    public let pitches: [Pitch]
    @_documentation(visibility: internal)
    public let mode: NoteSetMode
    @_documentation(visibility: internal)
    public let duration: MusicTimeStamp

    public init(_ pitches: Pitch..., duration: MusicTimeStamp = .quarter) {
        self.mode = .up
        self.pitches = Array(pitches)
        self.duration = duration
    }

    public init(_ mode: NoteSetMode, _ pitches: Pitch..., duration: MusicTimeStamp = .quarter) {
        self.mode = mode
        self.pitches = Array(pitches)
        self.duration = duration
    }

    func asNote() -> Note {
        guard !pitches.isEmpty else { return Note(pitch: nil, duration: duration) }
        var note = Note(pitch: pitches[0], velocity: 100, duration: duration)
        note.pitchVariants = pitches
        note.variantMode = mode
        return note
    }
}

public extension MusicTimeStamp {
    @_documentation(visibility: internal)
    static let sixtyfourth = 1.0/64.0
    @_documentation(visibility: internal)
    static let thirtysecond = 1.0/32.0
    @_documentation(visibility: internal)
    static let sixteenth = 1.0/16.0
    @_documentation(visibility: internal)
    static let semiquaver = 1.0/16.0
    @_documentation(visibility: internal)
    static let eighth = 1.0/8.0
    @_documentation(visibility: internal)
    static let quaver = 1.0/8.0
    @_documentation(visibility: internal)
    static let quarter = 1.0/4.0
    @_documentation(visibility: internal)
    static let crotchet = 1.0/4.0
    @_documentation(visibility: internal)
    static let half = 1.0/2.0
    @_documentation(visibility: internal)
    static let minim = 1.0/2.0
    @_documentation(visibility: internal)
    static let whole = 1.0
    @_documentation(visibility: internal)
    static let semibreve = 1.0
    @_documentation(visibility: internal)
    static let doubleWhole = 2.0
    @_documentation(visibility: internal)
    static let breve = 2.0
    @_documentation(visibility: internal)
    static let longa = 4.0
    @_documentation(visibility: internal)
    static let maxima = 8.0

    @_documentation(visibility: internal)
    static let n64 = 1.0/64.0
    @_documentation(visibility: internal)
    static let n32 = 1.0/32.0
    @_documentation(visibility: internal)
    static let n16 = 1.0/16.0
    @_documentation(visibility: internal)
    static let n8 = 1.0/8.0
    @_documentation(visibility: internal)
    static let n4 = 1.0/4.0
    @_documentation(visibility: internal)
    static let n2 = 1.0/2.0
    @_documentation(visibility: internal)
    static let n1 = 1.0

    @_documentation(visibility: internal)
    static let n8d = 1.0/8.0 * 1.5
    @_documentation(visibility: internal)
    static let n4d = 1.0/4.0 * 1.5
    @_documentation(visibility: internal)
    static let n2d = 1.0/2.0 * 1.5

    @_documentation(visibility: internal)
    static let n8t = 1.0/8.0 * 2.0/3.0
    @_documentation(visibility: internal)
    static let n4t = 1.0/4.0 * 2.0/3.0
}

// MARK: - Reading degrees in a key

public extension Note {
    @_documentation(visibility: internal)
    var isUnkeyed: Bool {
        guard scale == nil else { return false }
        return degree != nil
            || slides?.contains(where: { $0.degree != nil }) == true
            || variantDegrees?.contains(where: { $0 != nil }) == true
    }

    @_documentation(visibility: internal)
    func keyed(in scale: Scale) -> Note {
        guard isUnkeyed else { return self }
        var n = self
        n.scale = scale
        if let degree { n.pitch = scale.pitch(degree) }
        if let steps = n.slides {
            n.slides = steps.map { step in
                guard let d = step.degree else { return step }
                var s = step
                s.from = scale.pitch(d)
                return s
            }
        }
        if let degrees = n.variantDegrees, var variants = n.pitchVariants {
            for i in variants.indices where i < degrees.count {
                if let d = degrees[i] { variants[i] = scale.pitch(d) }
            }
            n.pitchVariants = variants
        }
        return n
    }
}

public extension Array where Element == Note {
    @_documentation(visibility: internal)
    func keyed(in scale: Scale) -> [Note] { map { $0.keyed(in: scale) } }
}
