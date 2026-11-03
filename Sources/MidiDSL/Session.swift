import Foundation

/// The meter: beats per bar and the note value that gets the beat.
///
/// See <doc:TimeSignatures>.
public struct TimeSignature: Equatable, Codable {
    public let beatsPerBar: Int
    public let noteValue: Int

    public init(_ beatsPerBar: Int, _ noteValue: Int) {
        self.beatsPerBar = beatsPerBar
        self.noteValue = noteValue
    }

    public static let fourFour = TimeSignature(4, 4)
    public static let threeFour = TimeSignature(3, 4)
    public static let sixEight = TimeSignature(6, 8)
    public static let fiveFour = TimeSignature(5, 4)
    public static let sevenEight = TimeSignature(7, 8)
    public static let twoFour = TimeSignature(2, 4)
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
/// See <doc:Sessions>.
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
                    file: SectionBuilder.foreignFile(file)))
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

    public init(@TrackArrayBuilder _ content: () -> [Track]) {
        let outerAdvisories = ScoreAdvisories.collected
        ScoreAdvisories.collected = []
        SampleKitCollector.reset()
        let (measured, needsFill) = LoopFill.measure(content)
        if needsFill {
            ScoreAdvisories.collected = []
            SampleKitCollector.reset()
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

    public func volume(_ level: Double) -> Session {
        return Session(tracks: self.tracks, volume: level, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    public func tempo(_ bpm: Double) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: bpm, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    public func loopBars(_ count: Int) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: count, loops: self.loops, timeSignature: self.timeSignature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

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

    public func timeSignature(_ beatsPerBar: Int, _ noteValue: Int) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: TimeSignature(beatsPerBar, noteValue), diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    public func timeSignature(_ signature: TimeSignature) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: signature, diceSeed: self.diceSeed, advisories: self.advisories).carryingPassBody(of: self)
    }

    public func seed(_ seed: Int) -> Session {
        return Session(tracks: self.tracks, volume: self.volume, tempo: self.tempo, loopBars: self.loopBars, loops: self.loops, timeSignature: self.timeSignature, diceSeed: seed, advisories: self.advisories).carryingPassBody(of: self)
    }

    public func key(_ root: Pitch, _ mode: ScaleMode) -> Session { key(Scale(root, mode)) }

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
