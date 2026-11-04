import Foundation

/// The meter: beats per bar and the note value that gets the beat.
///
/// A bar lasts `beatsPerBar / noteValue` whole notes: 3/4 and 6/8 are both 0.75, 5/4 is 1.25.
/// Bar notation, drum grids, `Loop(bars:)` and `bars:` curves all measure bars in it.
///
/// ```swift
/// Session { … }.timeSignature(.threeFour)
/// Session { … }.timeSignature(13, 16)
/// ```
///
/// See <doc:TimeSignatures>.
///
/// ## Topics
///
/// ### Common meters
///
/// - ``fourFour``
/// - ``threeFour``
/// - ``twoFour``
/// - ``fiveFour``
/// - ``sixEight``
/// - ``sevenEight``
/// - ``twelveEight``
///
/// ### Any meter
///
/// - ``init(_:_:)``
/// - ``beatsPerBar``
/// - ``noteValue``
public struct TimeSignature: Equatable, Codable {
    /// The top number: how many beats a bar has.
    public let beatsPerBar: Int
    /// The bottom number: which note gets the beat. `4` is a quarter, `8` an eighth.
    public let noteValue: Int

    /// A meter from its two numbers.
    ///
    /// - Parameters:
    ///   - beatsPerBar: How many beats a bar has.
    ///   - noteValue: Which note gets the beat: `4` a quarter, `8` an eighth.
    public init(_ beatsPerBar: Int, _ noteValue: Int) {
        self.beatsPerBar = beatsPerBar
        self.noteValue = noteValue
    }

    /// 4/4, common time. A session without a time signature is in 4/4.
    public static let fourFour = TimeSignature(4, 4)
    /// 3/4, a waltz.
    public static let threeFour = TimeSignature(3, 4)
    /// 6/8, two beats of three eighths.
    public static let sixEight = TimeSignature(6, 8)
    /// 5/4.
    public static let fiveFour = TimeSignature(5, 4)
    /// 7/8.
    public static let sevenEight = TimeSignature(7, 8)
    /// 2/4, a march.
    public static let twoFour = TimeSignature(2, 4)
    /// 12/8, four beats of three eighths, as in a slow blues.
    public static let twelveEight = TimeSignature(12, 8)
}

public extension TimeSignature {
    @_documentation(visibility: internal)
    var barDuration: Double { Double(beatsPerBar) / Double(noteValue) }

    @_documentation(visibility: internal)
    func secondsPerBeat(tempo: Double) -> Double {
        (60.0 / tempo) * (4.0 / Double(noteValue))
    }

    @_documentation(visibility: internal)
    func secondsPerBar(tempo: Double) -> Double {
        secondsPerBeat(tempo: tempo) * Double(beatsPerBar)
    }
}

/// The whole piece: its tracks, tempo, meter, form, key and seed.
///
/// ```swift
/// Session {
///     Track("drums", instrument: .drums()) {
///         Loop(bars: 1) { _ in Section { Kick("x... x..."); Snare(".... x...") } }
///     }
///     Track("bass", instrument: .generalMIDI(33)) {
///         Section { "| 1 1 5 5 | 4 4 5 5 |" }
///     }
/// }
/// .tempo(96)
/// .key(.C3, .minor)
/// ```
///
/// Every modifier returns a changed copy, so they chain after the closing brace.
/// To build a session in your own code, rather than in a ``Score``, use ``build(_:)``.
/// See <doc:Sessions>.
///
/// ## Topics
///
/// ### Making a session
///
/// - ``init(_:)``
/// - ``init(line:column:file:_:)``
/// - ``build(_:)``
///
/// ### Time
///
/// - ``tempo(_:)``
/// - ``defaultTempo``
/// - ``timeSignature(_:)``
/// - ``timeSignature(_:_:)``
///
/// ### Form
///
/// - ``loops(_:)``
/// - ``loopBars(_:)``
///
/// ### The rest
///
/// - ``key(_:_:)``
/// - ``key(_:)``
/// - ``volume(_:)``
/// - ``seed(_:)``
public struct Session: Equatable, Codable, Identifiable {
    @_documentation(visibility: internal)
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.volume == rhs.volume &&
        lhs.tempo == rhs.tempo &&
        lhs.loopBars == rhs.loopBars &&
        lhs.loops == rhs.loops &&
        lhs.timeSignature == rhs.timeSignature &&
        lhs.diceSeed == rhs.diceSeed &&
        lhs.advisories == rhs.advisories &&
        lhs.tracks == rhs.tracks
    }

    @_documentation(visibility: internal)
    public var id: UUID = UUID()
    @_documentation(visibility: internal)
    public let tracks: [Track]
    @_documentation(visibility: internal)
    public let volume: Double?
    @_documentation(visibility: internal)
    public let tempo: Double?
    @_documentation(visibility: internal)
    public let loopBars: Int?
    @_documentation(visibility: internal)
    public let loops: Int?
    @_documentation(visibility: internal)
    public let timeSignature: TimeSignature?
    @_documentation(visibility: internal)
    public let diceSeed: Int?
    @_documentation(visibility: internal)
    public let advisories: [SessionAdvisory]

    // MARK: - The pass body

    private var passBody: ((Int) -> [Track])? = nil
    private var passesBuilt: Int? = nil
    private var passKey: Scale? = nil
    private var passLine: Int = 0
    private var passColumn: Int = 0
    private var passFile: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, tracks, volume, tempo, loopBars, loops, timeSignature, diceSeed, advisories
    }

    /// A session whose body is read once per pass, so what plays can change from one time
    /// through the piece to the next.
    ///
    /// ```swift
    /// Session { pass in
    ///     Track("bass") {
    ///         Section { pass < 2 ? "| 1 1 5 5 |" : "| 1 b3 4 5 |" }
    ///     }
    /// }
    /// .loops(4)
    /// ```
    ///
    /// Say how many passes there are with ``loops(_:)``; without it the form is one pass long.
    /// A track's instrument, volume and section order belong to the track, not to a pass.
    ///
    /// - Parameters:
    ///   - line: Filled in for you, to place warnings in the source.
    ///   - column: Filled in for you, to place warnings in the source.
    ///   - file: Filled in for you, to place warnings in the source.
    ///   - content: The tracks, handed the pass number, counting from 0.
    public init(line: Int = #line, column: Int = #column, file: String = #fileID,
                @TrackArrayBuilder _ content: @escaping (Int) -> [Track]) {
        let built = Session.readPasses(content, times: nil, line: line, column: column, file: file)
        self.tracks = built.tracks
        self.advisories = built.advisories
        self.passBody = content
        self.passesBuilt = built.passes
        self.passLine = line
        self.passColumn = column
        self.passFile = file
        self.volume = nil
        self.tempo = nil
        self.loopBars = nil
        self.loops = nil
        self.timeSignature = nil
        self.diceSeed = nil
    }

    private static func readPasses(_ content: (Int) -> [Track], times: Int?,
                                   line: Int, column: Int, file: String)
        -> (tracks: [Track], advisories: [SessionAdvisory], passes: Int) {
        let outer = ScoreAdvisories.collected
        ScoreAdvisories.collected = []
        defer { ScoreAdvisories.collected = outer }

        let first = readOnePass(content, pass: 0)
        var count = times ?? Session.declaredPasses(in: first)

        if times == nil, count == 1 {
            let kept = ScoreAdvisories.collected
            let second = readOnePass(content, pass: 1)
            ScoreAdvisories.collected = kept
            if second != first {
                ScoreAdvisories.note(SessionAdvisory(
                    message: "the session body varies with the pass, but nothing says how many "
                        + "passes there are — so the form is one pass long and every pass is "
                        + "pass 0. Write .loops(n) to say how long the form is; the piece still "
                        + "plays round and round, cycling through those n passes.",
                    line: line, column: column,
                    file: SourceFiles.stamp(file)))
            }
        }
        count = max(1, count)

        var built = [first]
        for pass in 1..<count { built.append(readOnePass(content, pass: pass)) }
        let merged = PassExpansion.merge(times: count, built: built, line: line, column: column, file: file)
        return (merged, ScoreAdvisories.collected, count)
    }

    private static func readOnePass(_ content: (Int) -> [Track], pass: Int) -> [Track] {
        let before = ScoreAdvisories.collected
        let (measured, needsFill) = LoopFill.measure { content(pass) }
        guard needsFill else { return measured }
        let written = measured.reduce(0.0) { longest, track in
            max(longest, track.sections.map(\.duration).max() ?? 0)
        }
        ScoreAdvisories.collected = before
        return LoopFill.filling(to: written) { content(pass) }
    }

    /// A session of tracks that play together.
    ///
    /// - Parameter content: The tracks.
    public init(@TrackArrayBuilder _ content: () -> [Track]) {
        let outerAdvisories = ScoreAdvisories.collected
        ScoreAdvisories.collected = []
        TrackKeys.reset()
        let (measured, needsFill) = LoopFill.measure(content)
        if needsFill {
            ScoreAdvisories.collected = []
            TrackKeys.reset()
            let written = measured.reduce(0.0) { longest, track in
                max(longest, track.sections.map(\.duration).max() ?? 0)
            }
            self.tracks = LoopFill.filling(to: written, content)
        } else {
            self.tracks = measured
        }
        self.advisories = ScoreAdvisories.collected
        ScoreAdvisories.collected = outerAdvisories
        self.volume = nil
        self.tempo = nil
        self.loopBars = nil
        self.loops = nil
        self.timeSignature = nil
        self.diceSeed = nil
    }

    /// The tempo a session plays at when it names none.
    public static let defaultTempo: Double = 120

    /// Builds a session in its own meter and tempo.
    ///
    /// Bar notation, `Loop(bars:)`, a `bars:` curve and `Section.tempo(_:)` all need the session's
    /// time signature and tempo while the score is being built, but a session states them after
    /// its body, as modifiers. So `make` is run once to learn them, and once more if they are not
    /// the ones it was built under. A score is a pure function of its source, so the second run
    /// is the same score read with the right bar length. ``Score`` does this for you; call it
    /// when you build a session in your own code.
    ///
    /// ```swift
    /// let waltz = Session.build {
    ///     Session { Track("melody") { Section { "| 1 2 3 | 5 - - |" } } }
    ///         .timeSignature(.threeFour)
    /// }
    /// ```
    ///
    /// - Parameter make: Builds the session. It may run twice.
    /// - Returns: The session, built in its own meter and tempo.
    public static func build(_ make: () -> Session) -> Session {
        let meter = SectionBuilder.timeSignature, tempo = SectionBuilder.tempo
        defer { SectionBuilder.timeSignature = meter; SectionBuilder.tempo = tempo }
        var session = make()
        let wantedMeter = session.timeSignature ?? .fourFour
        let wantedTempo = session.tempo ?? defaultTempo
        if wantedMeter != SectionBuilder.timeSignature || wantedTempo != SectionBuilder.tempo {
            SectionBuilder.timeSignature = wantedMeter
            SectionBuilder.tempo = wantedTempo
            session = make()
        }
        return session
    }

    /// Sets the master level.
    ///
    /// It multiplies every track's volume and lands on the notes' velocities, so a MIDI file
    /// carries it too.
    ///
    /// - Parameter level: `0` silent, `1` as written.
    /// - Returns: The session, changed.
    public func volume(_ level: Double) -> Session {
        return Session(tracks: self.tracks, volume: level, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    /// Sets the tempo, in quarter notes per minute.
    ///
    /// The tempo counts quarter notes in every meter: at 120, a bar of 6/8 lasts 1.5 seconds.
    /// A session without a tempo plays at ``defaultTempo``.
    ///
    /// - Parameter bpm: Quarter notes per minute.
    /// - Returns: The session, changed.
    public func tempo(_ bpm: Double) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: bpm, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    /// Sets how many bars one pass lasts.
    ///
    /// Without it, a pass is as long as the longest track.
    ///
    /// - Parameter count: The length of a pass, in bars.
    /// - Returns: The session, changed.
    public func loopBars(_ count: Int) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: count, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    /// Sets how many passes the form has.
    ///
    /// A player goes round and round through them. Without it, the form is as long as the
    /// arrangement asks for: `active(loops: 3...)` needs four passes. A session read once per
    /// pass, `Session { pass in … }`, is read this many times.
    ///
    /// - Parameter count: The number of passes, at least 1.
    /// - Returns: The session, changed.
    public func loops(_ count: Int) -> Session {
        let wanted = max(1, count)
        guard let body = passBody else {
            return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: count, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
        }
        let rebuilt = Session.readPasses(body, times: wanted, line: passLine, column: passColumn,
                                        file: passFile)
        let keyed = passKey.map { scale in rebuilt.tracks.map { $0.key(scale) } } ?? rebuilt.tracks
        var session = Session(tracks: keyed, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: count, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: rebuilt.advisories)
        session = session.carryingPassBody(of: self)
        session.passesBuilt = wanted
        return session
    }

    /// Sets the meter from its two numbers.
    ///
    /// Bar notation, drum grids, `Loop(bars:)` and `bars:` curves all follow it.
    /// Build the session with ``build(_:)``, or in a ``Score``, so they are read in it.
    ///
    /// - Parameters:
    ///   - beatsPerBar: How many beats a bar has.
    ///   - noteValue: Which note gets the beat: `4` a quarter, `8` an eighth.
    /// - Returns: The session, changed.
    public func timeSignature(_ beatsPerBar: Int, _ noteValue: Int) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: TimeSignature(beatsPerBar, noteValue), diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    /// Sets the meter.
    ///
    /// Bar notation, drum grids, `Loop(bars:)` and `bars:` curves all follow it.
    /// Build the session with ``build(_:)``, or in a ``Score``, so they are read in it.
    ///
    /// - Parameter signature: The meter, such as `.threeFour`.
    /// - Returns: The session, changed.
    public func timeSignature(_ signature: TimeSignature) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: signature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    /// Picks another performance: a different set of rolls for everything the dice decide.
    ///
    /// Note sets, chance steps, `pickOne()`, drawn velocities and durations all roll again
    /// under a new seed. Each seed plays the same way every time. A session without a seed keeps
    /// the rolls it always had.
    ///
    /// - Parameter seed: Any number.
    /// - Returns: The session, changed.
    public func seed(_ seed: Int) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: seed, advisories: self.advisories).carryingPassBody(of: self)
    }

    /// Reads the session's degrees in a key.
    ///
    /// A key written further in, on a track, a section or a line, wins over this one.
    ///
    /// - Parameters:
    ///   - root: The key's first degree, as a pitch.
    ///   - mode: The scale built on the root.
    /// - Returns: The session, changed.
    public func key(_ root: Pitch, _ mode: ScaleMode) -> Session { key(Scale(root, mode)) }

    /// Reads the session's degrees in a scale.
    ///
    /// - Parameter scale: The scale the numbers in the session are degrees of.
    /// - Returns: The session, changed.
    public func key(_ scale: Scale) -> Session {
        var session = Session(tracks: tracks.map { $0.key(scale) }, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories)
        session = session.carryingPassBody(of: self)
        session.passKey = scale
        return session
    }

    private func carryingPassBody(of source: Session) -> Session {
        var copy = self
        copy.passBody = source.passBody
        copy.passesBuilt = source.passesBuilt
        copy.passKey = source.passKey
        copy.passLine = source.passLine
        copy.passColumn = source.passColumn
        copy.passFile = source.passFile
        return copy
    }

    @_documentation(visibility: internal)
    public var diceSeedValue: UInt64 {
        diceSeed.map { UInt64(bitPattern: Int64($0)) } ?? 0
    }

    @_documentation(visibility: internal)
    public func replacingTracks(_ newTracks: [Track]) -> Session {
        return Session(tracks: newTracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories)
    }

    @_documentation(visibility: internal)
    public var effectiveLoopCount: Int {
        if let loops { return max(1, loops) }
        return Session.declaredPasses(in: tracks)
    }

    static func declaredPasses(in tracks: [Track]) -> Int {
        var needed = 1
        func consider(_ activity: LoopActivity?) {
            switch activity {
            case .range(let from, let through):
                if let last = through ?? from { needed = max(needed, last + 1) }
            case .set(let indices):
                if let last = indices.max() { needed = max(needed, last + 1) }
            case .every(let n, let offset):
                guard n > 0 else { break }
                needed = max(needed, n, ((offset % n) + n) % n + 1)
            case nil:
                break
            }
        }
        for track in tracks {
            consider(track.activity)
            for section in track.sections {
                consider(section.activity)
                for note in section.notes { consider(note.activity) }
            }
        }
        return needed
    }

    private init(tracks: [Track], volume: Double?, tempo: Double?, loopBars: Int?, loops: Int?, timeSignature: TimeSignature?, diceSeed: Int?, advisories: [SessionAdvisory] = []) {
        self.advisories = advisories
        self.tracks = tracks
        self.volume = volume
        self.tempo = tempo
        self.loopBars = loopBars
        self.loops = loops
        self.timeSignature = timeSignature
        self.diceSeed = diceSeed
    }
}
