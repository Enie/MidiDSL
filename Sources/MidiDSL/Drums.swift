import Foundation

/// A General MIDI percussion key: `.kick`, `.snare`, `.closedHat`, `.ride` and the rest of the kit.
///
/// See <doc:Drums>.
public struct DrumPiece: Equatable {
    public let midiKey: UInt32

    public init(key: UInt32) { self.midiKey = min(key, 127) }

    public static func slot(_ n: Int) -> DrumPiece {
        DrumPiece(key: UInt32(max(0, min(n, 91)) + 36))
    }

    public static let kick = DrumPiece(key: 36)
    public static let kick2 = DrumPiece(key: 35)
    public static let sideStick = DrumPiece(key: 37)
    public static let snare = DrumPiece(key: 38)
    public static let clap = DrumPiece(key: 39)
    public static let snare2 = DrumPiece(key: 40)

    public static let closedHat = DrumPiece(key: 42)
    public static let pedalHat = DrumPiece(key: 44)
    public static let openHat = DrumPiece(key: 46)
    public static let crash = DrumPiece(key: 49)
    public static let crash2 = DrumPiece(key: 57)
    public static let splash = DrumPiece(key: 55)
    public static let china = DrumPiece(key: 52)
    public static let ride = DrumPiece(key: 51)
    public static let ride2 = DrumPiece(key: 59)
    public static let rideBell = DrumPiece(key: 53)

    public static let lowFloorTom = DrumPiece(key: 41)
    public static let highFloorTom = DrumPiece(key: 43)
    public static let lowTom = DrumPiece(key: 45)
    public static let lowMidTom = DrumPiece(key: 47)
    public static let highMidTom = DrumPiece(key: 48)
    public static let highTom = DrumPiece(key: 50)

    public static let tambourine = DrumPiece(key: 54)
    public static let cowbell = DrumPiece(key: 56)
    public static let vibraslap = DrumPiece(key: 58)
    public static let highBongo = DrumPiece(key: 60)
    public static let lowBongo = DrumPiece(key: 61)
    public static let muteConga = DrumPiece(key: 62)
    public static let openConga = DrumPiece(key: 63)
    public static let lowConga = DrumPiece(key: 64)
    public static let highTimbale = DrumPiece(key: 65)
    public static let lowTimbale = DrumPiece(key: 66)
    public static let highAgogo = DrumPiece(key: 67)
    public static let lowAgogo = DrumPiece(key: 68)
    public static let cabasa = DrumPiece(key: 69)
    public static let maracas = DrumPiece(key: 70)
    public static let shortWhistle = DrumPiece(key: 71)
    public static let longWhistle = DrumPiece(key: 72)
    public static let shortGuiro = DrumPiece(key: 73)
    public static let longGuiro = DrumPiece(key: 74)
    public static let claves = DrumPiece(key: 75)
    public static let highWoodBlock = DrumPiece(key: 76)
    public static let lowWoodBlock = DrumPiece(key: 77)
    public static let muteCuica = DrumPiece(key: 78)
    public static let openCuica = DrumPiece(key: 79)
    public static let muteTriangle = DrumPiece(key: 80)
    public static let openTriangle = DrumPiece(key: 81)

    /// The piece written the way notation spells a pitch — the kick is "C3".
    ///
    /// A bare number in notation is a *degree*, so a piece written into a
    /// string has to arrive as a name: "36" would read as the thirty-sixth
    /// degree of whatever key is in force, while a name is read absolutely
    /// and no `.key(...)` at any level touches it.
    public var spelling: NoteNotation { NoteNotation(pitch: midiKey) }
}

/// Writes a piece into notation by name: `"\(.kick) \(.closedHat)"`.
///
/// The bare leading dot resolves because this overload is what gives `.kick`
/// its contextual type — `DefaultStringInterpolation`'s generic
/// `appendInterpolation` cannot infer one, so this is the only candidate.
///
/// Note what interpolating costs, which is not this extension's doing: a hole
/// that is not a `let name = "…"` declaration is opaque to the editor's source
/// mapping, so every token past it lights the whole statement, and LivePatcher
/// declines an interpolated literal outright. Inside a `Grid`/`Phrase` closure
/// or a `Markov` training string — text that is generated anyway, and already
/// declines on both counts — it is free. In a hand-written literal,
/// `Lane(.kick, "x... x...")` names the same piece and keeps its steps lit.
public extension String.StringInterpolation {
    @_documentation(visibility: internal)
    mutating func appendInterpolation(_ piece: DrumPiece) {
        appendLiteral(piece.spelling)
    }
}

/// One drum piece played from a step grid, such as `Kick("x... x...")`.
///
/// See <doc:Drums>.
public struct DrumLane {
    @_documentation(visibility: internal)
    public let piece: DrumPiece
    @_documentation(visibility: internal)
    public let grid: String

    @_documentation(visibility: internal)
    public let sample: Sample?

    @_documentation(visibility: internal)
    public private(set) var volumeScale: Double = 1.0

    @_documentation(visibility: internal)
    public private(set) var muted: Bool = false

    public init(_ piece: DrumPiece, _ grid: String) {
        self.piece = piece
        self.grid = grid
        self.sample = nil
    }

    public init(_ sample: Sample, _ grid: String) {
        self.piece = DrumPiece(key: SampleKitCollector.key(for: sample))
        self.grid = grid
        self.sample = sample
    }

    public func volume(_ level: Double) -> DrumLane {
        var lane = self
        lane.volumeScale = max(0, level)
        return lane
    }

    public func mute(_ on: Bool = true) -> DrumLane {
        var lane = self
        lane.muted = on
        return lane
    }

    var _automation: [PendingCurve] = []

    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> DrumLane {
        automating(target, breakpoints, timeScale: nil, curve: curve)
    }
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> DrumLane {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> DrumLane {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    public func automate(_ target: AutomationTarget, beats breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> DrumLane {
        automating(target, breakpoints, timeScale: 1.0 / Double(SectionBuilder.timeSignature.noteValue),
                   curve: curve)
    }

    private func automating(_ target: AutomationTarget, _ breakpoints: [Double: Double],
                            timeScale: MusicTimeStamp?, curve: AutomationShape) -> DrumLane {
        guard !breakpoints.isEmpty else { return self }
        var lane = self
        lane._automation.append(PendingCurve(target: target, breakpoints: breakpoints,
                                             timeScale: timeScale, shape: curve))
        return lane
    }

    static let hitVelocity: UInt32 = 100
    static let accentVelocity: UInt32 = 120
    static let ghostVelocity: UInt32 = 55

    func notes(barDuration: MusicTimeStamp) -> [Note] {
        var bars: [[(char: Character, offset: Int)]] = [[]]
        for (offset, char) in grid.enumerated() {
            if char == "|" { bars.append([]) }
            else if !char.isWhitespace { bars[bars.count - 1].append((char, offset)) }
        }

        var result: [Note] = []
        var barStart: MusicTimeStamp = 0
        for steps in bars {
            defer { barStart += barDuration }
            guard !steps.isEmpty, !muted else { continue }
            let stepDuration = barDuration / Double(steps.count)
            for (index, step) in steps.enumerated() {
                let written: UInt32
                var chance: Double? = nil
                switch step.char {
                case "x": written = DrumLane.hitVelocity
                case "X": written = DrumLane.accentVelocity
                case "o": written = DrumLane.ghostVelocity
                case "?": written = DrumLane.hitVelocity; chance = 0.5
                case "1"..."9":
                    written = DrumLane.hitVelocity
                    chance = Double(step.char.wholeNumberValue ?? 5) / 10.0
                default: continue
                }
                let velocity = UInt32(min(max((Double(written) * volumeScale).rounded(), 0), 127))
                var note = Note(pitch: piece.midiKey, velocity: velocity,
                                startTime: barStart + Double(index) * stepDuration,
                                duration: stepDuration)
                note.sourceOffset = step.offset
                note.sourceLength = 1
                if let chance { note.dice = .chance(chance) }
                result.append(note)
            }
        }
        result.append(Note(pitch: nil, velocity: 0, startTime: barStart, duration: 0))
        return PendingCurve.applying(_automation, to: result)
    }
}

/// A drum lane for any kit piece or sample slice, played from a step grid.
///
/// See <doc:Drums>.
public func Lane(_ piece: DrumPiece, _ grid: String) -> DrumLane { DrumLane(piece, grid) }
/// A drum lane that plays a sample slice from a step grid. See <doc:Samples>.
public func Lane(_ sample: Sample, _ grid: String) -> DrumLane { DrumLane(sample, grid) }
/// A kick-drum lane. See <doc:Drums>.
public func Kick(_ grid: String) -> DrumLane { DrumLane(.kick, grid) }
/// A snare lane. See <doc:Drums>.
public func Snare(_ grid: String) -> DrumLane { DrumLane(.snare, grid) }
/// A closed hi-hat lane. See <doc:Drums>.
public func Hat(_ grid: String) -> DrumLane { DrumLane(.closedHat, grid) }
/// An open hi-hat lane. See <doc:Drums>.
public func OpenHat(_ grid: String) -> DrumLane { DrumLane(.openHat, grid) }
/// A hand-clap lane. See <doc:Drums>.
public func Clap(_ grid: String) -> DrumLane { DrumLane(.clap, grid) }
/// A crash-cymbal lane. See <doc:Drums>.
public func Crash(_ grid: String) -> DrumLane { DrumLane(.crash, grid) }
/// A ride-cymbal lane. See <doc:Drums>.
public func Ride(_ grid: String) -> DrumLane { DrumLane(.ride, grid) }

/// Where a step sits in a generated grid or phrase: its bar, beat, subdivision and index.
///
/// See <doc:GeneratingParts>.
public struct GridStep {
    public let bar: Int
    public let beat: Int
    public let sub: Int
    public let step: Int
    public let index: Int

    public var isDownbeat: Bool { sub == 0 }
}

/// A drum grid computed step by step instead of typed.
///
/// See <doc:GeneratingParts>.
public func Grid(bars: Int, beats: Int = 4, subdivisions: Int = 4,
                 _ fill: (GridStep) -> Character) -> String {
    let bars = max(0, bars), beats = max(1, beats), subdivisions = max(1, subdivisions)
    let perBar = beats * subdivisions
    return (0..<bars).map { bar in
        String((0..<perBar).map { step in
            fill(GridStep(bar: bar,
                          beat: step / subdivisions,
                          sub: step % subdivisions,
                          step: step,
                          index: bar * perBar + step))
        })
    }.joined(separator: " | ")
}

/// A General MIDI drum kit, chosen by program number.
///
/// See <doc:Drums>.
public enum DrumKit: Int, Codable {
    case standard = 0
    case room = 8
    case power = 16
    case electronic = 24
    case tr808 = 25
    case jazz = 32
    case brush = 40
    case orchestra = 48
}
