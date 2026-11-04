import Foundation

/// A General MIDI percussion key: `.kick`, `.snare`, `.closedHat`, `.ride` and the rest of the kit.
///
/// A piece is a key: on a drum track every key plays a different instrument of the kit.
///
/// ```swift
/// Lane(.cowbell, "..x. ..x.")
/// Lane(DrumPiece(key: 82), "x.x. x.x.")   // shaker, a key without a name here
/// ```
///
/// See <doc:Drums>.
public struct DrumPiece: Equatable {
    /// The MIDI key the piece strikes.
    public let midiKey: UInt32

    /// The piece on a MIDI key, for a key without a name here.
    ///
    /// - Parameter key: The MIDI key, 0…127. Larger values clamp to 127.
    public init(key: UInt32) { self.midiKey = min(key, 127) }

    /// The piece on the `n`th key counted from the kick, key 36.
    ///
    /// `slot(0)` is the kick, `slot(2)` the snare. For picking keys by number in generated parts.
    ///
    /// - Parameter n: The offset from key 36, clamped to 0…91.
    public static func slot(_ n: Int) -> DrumPiece {
        DrumPiece(key: UInt32(max(0, min(n, 91)) + 36))
    }

    /// Bass drum, the kit's main kick, General MIDI key 36.
    public static let kick = DrumPiece(key: 36)
    /// Acoustic bass drum, a second kick, General MIDI key 35.
    public static let kick2 = DrumPiece(key: 35)
    /// Side stick, a rim click, General MIDI key 37.
    public static let sideStick = DrumPiece(key: 37)
    /// Acoustic snare, General MIDI key 38.
    public static let snare = DrumPiece(key: 38)
    /// Hand clap, General MIDI key 39.
    public static let clap = DrumPiece(key: 39)
    /// Electric snare, General MIDI key 40.
    public static let snare2 = DrumPiece(key: 40)

    /// Closed hi-hat, General MIDI key 42.
    public static let closedHat = DrumPiece(key: 42)
    /// Pedal hi-hat, the foot closing the hats, General MIDI key 44.
    public static let pedalHat = DrumPiece(key: 44)
    /// Open hi-hat, General MIDI key 46.
    public static let openHat = DrumPiece(key: 46)
    /// Crash cymbal, General MIDI key 49.
    public static let crash = DrumPiece(key: 49)
    /// Second crash cymbal, General MIDI key 57.
    public static let crash2 = DrumPiece(key: 57)
    /// Splash cymbal, General MIDI key 55.
    public static let splash = DrumPiece(key: 55)
    /// China cymbal, General MIDI key 52.
    public static let china = DrumPiece(key: 52)
    /// Ride cymbal, General MIDI key 51.
    public static let ride = DrumPiece(key: 51)
    /// Second ride cymbal, General MIDI key 59.
    public static let ride2 = DrumPiece(key: 59)
    /// Ride bell, General MIDI key 53.
    public static let rideBell = DrumPiece(key: 53)

    /// Low floor tom, General MIDI key 41.
    public static let lowFloorTom = DrumPiece(key: 41)
    /// High floor tom, General MIDI key 43.
    public static let highFloorTom = DrumPiece(key: 43)
    /// Low tom, General MIDI key 45.
    public static let lowTom = DrumPiece(key: 45)
    /// Low-mid tom, General MIDI key 47.
    public static let lowMidTom = DrumPiece(key: 47)
    /// High-mid tom, General MIDI key 48.
    public static let highMidTom = DrumPiece(key: 48)
    /// High tom, General MIDI key 50.
    public static let highTom = DrumPiece(key: 50)

    /// Tambourine, General MIDI key 54.
    public static let tambourine = DrumPiece(key: 54)
    /// Cowbell, General MIDI key 56.
    public static let cowbell = DrumPiece(key: 56)
    /// Vibraslap, General MIDI key 58.
    public static let vibraslap = DrumPiece(key: 58)
    /// High bongo, General MIDI key 60.
    public static let highBongo = DrumPiece(key: 60)
    /// Low bongo, General MIDI key 61.
    public static let lowBongo = DrumPiece(key: 61)
    /// Muted high conga, General MIDI key 62.
    public static let muteConga = DrumPiece(key: 62)
    /// Open high conga, General MIDI key 63.
    public static let openConga = DrumPiece(key: 63)
    /// Low conga, General MIDI key 64.
    public static let lowConga = DrumPiece(key: 64)
    /// High timbale, General MIDI key 65.
    public static let highTimbale = DrumPiece(key: 65)
    /// Low timbale, General MIDI key 66.
    public static let lowTimbale = DrumPiece(key: 66)
    /// High agogô, General MIDI key 67.
    public static let highAgogo = DrumPiece(key: 67)
    /// Low agogô, General MIDI key 68.
    public static let lowAgogo = DrumPiece(key: 68)
    /// Cabasa, General MIDI key 69.
    public static let cabasa = DrumPiece(key: 69)
    /// Maracas, General MIDI key 70.
    public static let maracas = DrumPiece(key: 70)
    /// Short whistle, General MIDI key 71.
    public static let shortWhistle = DrumPiece(key: 71)
    /// Long whistle, General MIDI key 72.
    public static let longWhistle = DrumPiece(key: 72)
    /// Short güiro, General MIDI key 73.
    public static let shortGuiro = DrumPiece(key: 73)
    /// Long güiro, General MIDI key 74.
    public static let longGuiro = DrumPiece(key: 74)
    /// Claves, General MIDI key 75.
    public static let claves = DrumPiece(key: 75)
    /// High wood block, General MIDI key 76.
    public static let highWoodBlock = DrumPiece(key: 76)
    /// Low wood block, General MIDI key 77.
    public static let lowWoodBlock = DrumPiece(key: 77)
    /// Muted cuíca, General MIDI key 78.
    public static let muteCuica = DrumPiece(key: 78)
    /// Open cuíca, General MIDI key 79.
    public static let openCuica = DrumPiece(key: 79)
    /// Muted triangle, General MIDI key 80.
    public static let muteTriangle = DrumPiece(key: 80)
    /// Open triangle, General MIDI key 81.
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
/// Note what interpolating costs, which is not this extension's doing: the notes
/// keep the offsets of the interpolated text, not of the literal as written, so a
/// tool that maps notes back to the source cannot place the tokens after a hole.
/// Inside a `Grid`/`Phrase` closure or a `Markov` training string — text that is
/// generated anyway — it costs nothing. In a hand-written literal,
/// `Lane(.kick, "x... x...")` names the same piece and keeps its steps placed.
public extension String.StringInterpolation {
    @_documentation(visibility: internal)
    mutating func appendInterpolation(_ piece: DrumPiece) {
        appendLiteral(piece.spelling)
    }
}

/// One drum piece played from a step grid, such as `Kick("x... x...")`.
///
/// Each character of the grid is a step:
///
/// | Character | Plays |
/// |---|---|
/// | `x` | a hit, velocity 100 |
/// | `X` | an accent, velocity 120 |
/// | `o` | a ghost note, velocity 55 |
/// | `?` | a hit half the time |
/// | `1`…`9` | a hit that many times in ten |
/// | `.` or `-` | a rest |
///
/// `|` separates bars, and spaces only group steps for the eye. Each bar divides evenly by its
/// own number of steps, so 16 steps are sixteenths and 8 are eighths. A grid without `|` is one bar.
/// The chance steps are rolled by ``Dice``, so they fall the same way on every build.
///
/// ```swift
/// Track("drums", instrument: .drums()) {
///     Section {
///         Kick( "x... .... x.x. ....")
///         Snare(".... x..o .... x...")
///         Hat(  "x.x. x.x. x.x. X.x.").volume(0.6)
///     }
/// }
/// ```
///
/// See <doc:Drums>.
///
/// ## Topics
///
/// ### Making a lane
///
/// - ``init(_:_:)``
/// - ``Lane(_:_:)``
/// - ``Kick(_:)``
/// - ``Snare(_:)``
/// - ``Hat(_:)``
/// - ``OpenHat(_:)``
/// - ``Clap(_:)``
/// - ``Crash(_:)``
/// - ``Ride(_:)``
///
/// ### Shaping a lane
///
/// - ``volume(_:)``
/// - ``mute(_:)``
/// - ``automate(_:over:curve:)``
/// - ``automate(_:at:curve:)``
/// - ``automate(_:bars:curve:)``
/// - ``automate(_:beats:curve:)``
public struct DrumLane {
    @_documentation(visibility: internal)
    public let piece: DrumPiece
    @_documentation(visibility: internal)
    public let grid: String

    @_documentation(visibility: internal)
    public private(set) var volumeScale: Double = 1.0

    @_documentation(visibility: internal)
    public private(set) var muted: Bool = false

    /// A lane that plays a piece from a step grid. ``Lane(_:_:)`` says the same thing.
    ///
    /// - Parameters:
    ///   - piece: The kit piece the lane strikes.
    ///   - grid: The steps, as the table above reads them.
    public init(_ piece: DrumPiece, _ grid: String) {
        self.piece = piece
        self.grid = grid
    }

    /// Plays this lane louder or softer than the others of its groove.
    ///
    /// Every lane of a groove shares one track, so this scales the velocities the lane's steps
    /// play at; hits, accents and ghosts keep their ratio. It multiplies with the section's
    /// `velocity(scale:)` and the track's `volume(_:)`.
    ///
    /// - Parameter level: `1` as written, less to sit back, more to push. Below 0 counts as 0.
    /// - Returns: The lane, changed.
    public func volume(_ level: Double) -> DrumLane {
        var lane = self
        lane.volumeScale = max(0, level)
        return lane
    }

    /// Silences the lane without deleting it.
    ///
    /// The lane's bars still take their time, so muting the longest lane does not shorten the
    /// section under the others.
    ///
    /// - Parameter on: `true` silences the lane, `false` plays it.
    /// - Returns: The lane, changed.
    public func mute(_ on: Bool = true) -> DrumLane {
        var lane = self
        lane.muted = on
        return lane
    }

    var _automation: [PendingCurve] = []

    /// Moves a parameter across the lane, with times as fractions of its length.
    ///
    /// `0` is the start of the lane and `1` its end, so the curve keeps its shape when the lane gets
    /// longer. The value holds before the first breakpoint and after the last, so one breakpoint
    /// is a constant. A value outside the target's range is clamped to it.
    ///
    /// ```swift
    /// Hat("x.x. x.x. x.x. x.x.").automate(.volume, over: [0: 0.3, 1: 1.0])
    /// ```
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time a fraction of the lane's length.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The lane, changed.
    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> DrumLane {
        automating(target, breakpoints, timeScale: nil, curve: curve)
    }
    /// Moves a parameter across the lane, with times in whole notes from its start.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in whole notes from the start of the lane.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The lane, changed.
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> DrumLane {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    /// Moves a parameter across the lane, with times in bars from its start.
    ///
    /// Bars are measured in the session's time signature, the same one bar notation is read in.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in bars from the start of the lane.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The lane, changed.
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> DrumLane {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    /// Moves a parameter across the lane, with times in beats from its start.
    ///
    /// Beats are the session's time signature's note value: quarters in 4/4, eighths in 6/8.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in beats from the start of the lane.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The lane, changed.
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

    @_documentation(visibility: internal)
    public static let hitVelocity: UInt32 = 100
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

/// A drum lane for any kit piece, played from a step grid.
///
/// See <doc:Drums>.
public func Lane(_ piece: DrumPiece, _ grid: String) -> DrumLane { DrumLane(piece, grid) }
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

/// Where a step sits in a generated grid or phrase: its bar, its beat, its place in the beat,
/// and the shape of the whole grid.
///
/// `Grid` and `Phrase` call your closure once per step and hand it one of these. Every count
/// is 0-based.
///
/// ```swift
/// // Accent each bar's first beat, play the other beats, and fill the last bar.
/// Grid(bars: 4) { step in
///     if step.isDownbeat { return "X" }
///     if step.isOnBeat { return "x" }
///     return step.isLastBar && step.sub == 2 ? "o" : "."
/// }
/// ```
///
/// ## Topics
///
/// ### Where the step is
/// - ``bar``
/// - ``beat``
/// - ``sub``
/// - ``stepInBar``
/// - ``index``
///
/// ### What kind of step it is
/// - ``isDownbeat``
/// - ``isOnBeat``
/// - ``isLastBeat``
/// - ``isLastBar``
///
/// ### The grid it belongs to
/// - ``bars``
/// - ``beats``
/// - ``subdivisions``
/// - ``init(bar:beat:sub:bars:beats:subdivisions:)``
public struct GridStep: Equatable {
    /// The bar, from 0.
    public let bar: Int
    /// The beat within the bar, from 0.
    public let beat: Int
    /// The subdivision within the beat, from 0. With 3 subdivisions, 2 is the swung note
    /// just before the next beat; with 4, 2 is the eighth-note offbeat.
    public let sub: Int
    /// The step's position within its bar, from 0: `beat × subdivisions + sub`. It starts
    /// again on every bar.
    public let stepInBar: Int
    /// The step's position in the whole grid, from 0. It never starts again, so it suits
    /// anything that should develop across the bars.
    public let index: Int
    /// How many bars the grid has.
    public let bars: Int
    /// How many beats each bar has.
    public let beats: Int
    /// How many steps each beat has.
    public let subdivisions: Int

    /// A step at a given place in a grid of a given shape.
    ///
    /// `Grid` and `Phrase` make these for you; build one yourself to try a closure out.
    public init(bar: Int, beat: Int, sub: Int, bars: Int, beats: Int = 4, subdivisions: Int = 4) {
        self.bar = bar
        self.beat = beat
        self.sub = sub
        self.bars = max(1, bars)
        self.beats = max(1, beats)
        self.subdivisions = max(1, subdivisions)
        self.stepInBar = beat * self.subdivisions + sub
        self.index = bar * self.beats * self.subdivisions + stepInBar
    }

    /// The position within the bar.
    @available(*, deprecated, renamed: "stepInBar")
    public var step: Int { stepInBar }

    /// True on the first beat of the bar — the downbeat — and nowhere else.
    public var isDownbeat: Bool { beat == 0 && sub == 0 }
    /// True on every beat itself, rather than on a subdivision between beats.
    public var isOnBeat: Bool { sub == 0 }
    /// True on any step of the bar's last beat.
    public var isLastBeat: Bool { beat == beats - 1 }
    /// True on any step of the grid's last bar.
    public var isLastBar: Bool { bar == bars - 1 }
}

/// A drum grid written by code instead of typed.
///
/// `Grid` calls `fill` once for every step of every bar, in order, and joins the bars with
/// `|`. The result is an ordinary grid string, so it goes anywhere a typed one does.
///
/// ```swift
/// let dice = Dice(seed: 7).stream("ride")
/// Lane(.ride, Grid(bars: 8, subdivisions: 3) { step in
///     if step.isOnBeat { return "x" }
///     return dice.chance(0.3, at: step) ? "?" : "."
/// })
/// ```
///
/// - Parameters:
///   - bars: How many bars to write. `0` writes an empty grid.
///   - beats: Beats per bar. Left out, the session's time signature decides.
///   - subdivisions: Steps per beat: 4 gives sixteenths, 3 the triplet eighths a swung ride
///     lands on, 2 eighths.
///   - fill: Answers the character for one step: `x` hit, `X` accent, `o` ghost, `.` rest,
///     `?` a hit on half the passes, `1`–`9` a hit on that many passes in ten.
/// - Returns: The grid, with `beats × subdivisions` characters per bar.
///
/// See <doc:GeneratingParts>.
public func Grid(bars: Int, beats: Int? = nil, subdivisions: Int = 4,
                 _ fill: (GridStep) -> Character) -> String {
    let bars = max(0, bars), subdivisions = max(1, subdivisions)
    let beats = max(1, beats ?? SectionBuilder.timeSignature.beatsPerBar)
    let perBar = beats * subdivisions
    return (0..<bars).map { bar in
        String((0..<perBar).map { step in
            fill(GridStep(bar: bar, beat: step / subdivisions, sub: step % subdivisions,
                          bars: bars, beats: beats, subdivisions: subdivisions))
        })
    }.joined(separator: " | ")
}

/// A General MIDI drum kit, chosen by program number.
///
/// See <doc:Drums>.
public enum DrumKit: Int, Codable {
    /// The standard kit, program 0.
    case standard = 0
    /// The room kit, program 8.
    case room = 8
    /// The power kit, program 16.
    case power = 16
    /// The electronic kit, program 24.
    case electronic = 24
    /// The TR-808 kit, program 25.
    case tr808 = 25
    /// The jazz kit, program 32.
    case jazz = 32
    /// The brush kit, program 40.
    case brush = 40
    /// The orchestra kit, program 48.
    case orchestra = 48
}
