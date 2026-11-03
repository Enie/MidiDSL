import Foundation

@_documentation(visibility: internal)
public struct LoopStamp: Equatable, Hashable, Codable {
    public let line: Int
    public let column: Int
    public let iteration: Int

    public init(line: Int, column: Int, iteration: Int) {
        self.line = line
        self.column = column
        self.iteration = iteration
    }
}

@_documentation(visibility: internal)
public struct SessionAdvisory: Equatable, Codable {
    public let message: String
    public let line: Int?
    public let column: Int?
    public let file: String?

    public init(message: String, line: Int? = nil, column: Int? = nil, file: String? = nil) {
        self.message = message
        self.line = line
        self.column = column
        self.file = file
    }
}

@_documentation(visibility: internal)
public enum ScoreAdvisories {
    nonisolated(unsafe) public static var collected: [SessionAdvisory] = []

    public static func note(_ advisory: SessionAdvisory) {
        guard !collected.contains(advisory) else { return }
        collected.append(advisory)
    }
}

/// Sections repeated on a grid of their own inside a track.
///
/// The body is handed the round number, so it can vary from one round to the next.
/// See <doc:TracksAndArrangement>.
public struct Loop {
    @_documentation(visibility: internal)
    public let bars: Int
    @_documentation(visibility: internal)
    public let times: Int?

    private let line: Int
    private let column: Int
    private let file: String
    private let body: (Int) -> [Section]

    public init(bars: Int, times: Int? = nil,
                line: Int = #line, column: Int = #column, file: String = #fileID,
                @SectionArrayBuilder body: @escaping (Int) -> [Section]) {
        self.bars = max(1, bars)
        self.times = times.map { max(0, $0) }
        self.line = line
        self.column = column
        self.file = file
        self.body = body
    }

    var iterationLength: MusicTimeStamp {
        Double(bars) * SectionBuilder.timeSignature.barDuration
    }

    func expandedSections() -> [Section] {
        let count = LoopFill.iterationCount(for: self)
        guard count > 0 else { return [] }

        let span = iterationLength
        var result: [Section] = []

        for iteration in 0..<count {
            let stamp = LoopStamp(line: line, column: column, iteration: iteration)
            let written = body(iteration)
            var laidSections = 0
            var base: MusicTimeStamp = 0
            var laid: MusicTimeStamp = 0

            for section in written {
                let writtenEnd = section.duration
                let visibleEnd = min(writtenEnd, span)
                var placed = section
                placed.notes = section.notes.compactMap { note in
                    guard note.startTime < span - 1e-9 else { return nil }
                    var note = note
                    note.duration = min(note.duration, span - note.startTime)
                    if let choices = note.durationChoices {
                        note.durationChoices = choices.map { min($0, span - note.startTime) }
                    }
                    note.startTime -= base
                    note.loop = stamp
                    return note
                }
                placed.notes.append(gridMarker(at: visibleEnd - base, stamp: stamp))
                result.append(placed)
                laidSections += 1
                base = writtenEnd
                laid = visibleEnd
                if writtenEnd >= span - 1e-9 { break }
            }

            if laidSections < written.count {
                let lost = written.count - laidSections
                let first = written[laidSections].notes.first { $0.sourceLine != nil }
                ScoreAdvisories.note(SessionAdvisory(
                    message: "the loop's \(bars)-bar grid is full — "
                        + (lost == 1 ? "1 section after it never sounds. "
                                     : "\(lost) sections after it never sound. ")
                        + "A Loop body is serial, like a track's: layers go inside one Section { }.",
                    line: first?.sourceLine ?? line,
                    column: first?.sourceColumn ?? column,
                    file: first?.sourceFile ?? SectionBuilder.foreignFile(file)))
            }

            if laid < span - 1e-9 {
                result.append(Section(notes: [gridMarker(at: span - laid, stamp: stamp)]))
            }
        }
        return result
    }

    private func gridMarker(at end: MusicTimeStamp, stamp: LoopStamp) -> Note {
        var marker = Note(pitch: nil, velocity: 0, startTime: max(0, end), duration: 0)
        marker.sourceLine = line
        marker.sourceColumn = column
        marker.sourceFile = SectionBuilder.foreignFile(file)
        marker.loop = stamp
        return marker
    }
}

enum LoopFill {
    nonisolated(unsafe) static var pieceLength: MusicTimeStamp? = nil
    nonisolated(unsafe) static var sawFillingLoop = false

    static func iterationCount(for loop: Loop) -> Int {
        if let times = loop.times { return times }
        guard let target = pieceLength else {
            sawFillingLoop = true
            return 0
        }
        let span = loop.iterationLength
        guard span > 0, target > 0 else { return 1 }
        return max(1, Int(ceil(target / span - 1e-9)))
    }

    static func measure<T>(_ build: () -> T) -> (value: T, needsFill: Bool) {
        let savedLength = pieceLength
        let savedSaw = sawFillingLoop
        pieceLength = nil
        sawFillingLoop = false
        let value = build()
        let needsFill = sawFillingLoop
        pieceLength = savedLength
        sawFillingLoop = savedSaw
        return (value, needsFill)
    }

    static func filling<T>(to length: MusicTimeStamp, _ build: () -> T) -> T {
        let savedLength = pieceLength
        let savedSaw = sawFillingLoop
        pieceLength = length
        let value = build()
        pieceLength = savedLength
        sawFillingLoop = savedSaw
        return value
    }
}

enum PassExpansion {

    static func merge(times: Int, built: [[Track]], line: Int, column: Int, file: String) -> [Track] {
        var order: [String] = []
        var slots: [String: TrackSlot] = [:]

        for (pass, tracks) in built.enumerated() {
            for track in tracks {
                if slots[track.name] == nil {
                    order.append(track.name)
                    slots[track.name] = TrackSlot(first: track, firstPass: pass)
                }
                slots[track.name]?.absorb(track, pass: pass, line: line, column: column, file: file)
            }
        }

        return order.compactMap { slots[$0]?.merged(line: line, column: column, file: file) }
    }

    private struct TrackSlot {
        let first: Track
        let firstPass: Int
        var positions: [SectionSlot] = []
        init(first: Track, firstPass: Int) {
            self.first = first
            self.firstPass = firstPass
        }

        mutating func absorb(_ track: Track, pass: Int, line: Int, column: Int, file: String) {
            reportDisagreement(track, pass: pass, line: line, column: column, file: file)

            var base: MusicTimeStamp = 0
            for (index, section) in track.sections.enumerated() {
                let end = section.duration
                if index == positions.count { positions.append(SectionSlot()) }
                positions[index].absorb(section, pass: pass,
                                        base: base, line: line, column: column, file: file)
                base = end
            }
        }

        private func reportDisagreement(_ track: Track, pass: Int, line: Int, column: Int, file: String) {
            guard pass != firstPass else { return }
            var differing: [String] = []
            if track.instrument != first.instrument { differing.append("instrument") }
            if track.volume != first.volume { differing.append("volume") }
            if track.sectionOrder != first.sectionOrder { differing.append("section order") }
            if track.activity != first.activity { differing.append("arrangement") }
            if track.muted != first.muted { differing.append("mute") }
            guard !differing.isEmpty else { return }
            ScoreAdvisories.note(SessionAdvisory(
                message: "pass \(pass) gives \(track.name) a different "
                    + differing.joined(separator: " and ")
                    + " than pass \(firstPass) does — that belongs to the track rather than to "
                    + "the pass, so pass \(firstPass)'s is what plays. Vary the material "
                    + "between passes, and write the track once.",
                line: line, column: column,
                file: SectionBuilder.foreignFile(file)))
        }

        func merged(line: Int, column: Int, file: String) -> Track {
            PassExpansion.reportRagged(positions, of: first.name, line: line, column: column, file: file)
            var laid: [Section] = []
            var start: MusicTimeStamp = 0
            for slot in positions {
                var section = slot.section
                let length = section.duration
                section.notes = section.notes.map { note in
                    var n = note
                    n.startTime += start
                    return n
                }
                laid.append(section)
                start += length
            }
            return first.replacingSections(laid)
        }
    }

    private struct SectionSlot {
        var section = Section(notes: [])
        var lengths: [(pass: Int, length: MusicTimeStamp)] = []
        var laneOwners: [AutomationTarget: Int] = [:]

        mutating func absorb(_ source: Section, pass: Int,
                             base: MusicTimeStamp, line: Int, column: Int, file: String) {
            lengths.append((pass, source.duration - base))

            section.notes.append(contentsOf: source.notes.map { note in
                var n = note
                n.startTime -= base
                n.activity = PassExpansion.gate(note, in: source, on: pass)
                return n
            })

            for lane in source.automation ?? [] {
                guard let owner = laneOwners[lane.target] else {
                    laneOwners[lane.target] = pass
                    section.automation = (section.automation ?? []) + [lane]
                    continue
                }
                guard owner != pass,
                      !(section.automation ?? []).contains(lane) else { continue }
                ScoreAdvisories.note(SessionAdvisory(
                    message: "pass \(pass) moves \(lane.target) where pass \(owner) already "
                        + "does — a track parameter is one thing the whole track shares, so it "
                        + "has no per-pass setting and pass \(owner)'s curve is the one that "
                        + "plays. Automate .volume instead, which is per-voice, or move the "
                        + "sweep outside the pass body.",
                    line: line, column: column,
                file: SectionBuilder.foreignFile(file)))
            }
        }
    }

    private static func gate(_ note: Note, in section: Section, on pass: Int) -> LoopActivity {
        if section.isMuted { return .set([]) }
        for existing in [section.activity, note.activity] {
            if let existing, !existing.isActive(loopIndex: pass) { return .set([]) }
        }
        return .set([pass])
    }

    private static func reportRagged(_ positions: [SectionSlot], of trackName: String,
                                         line: Int, column: Int, file: String) {
        for (index, slot) in positions.enumerated() {
            guard index + 1 < positions.count,
                  !positions[(index + 1)...].allSatisfy({ $0.section.notes.isEmpty })
            else { continue }
            guard let longest = slot.lengths.max(by: { $0.length < $1.length }),
                  let shortest = slot.lengths.min(by: { $0.length < $1.length }),
                  longest.length - shortest.length > 1e-9 else { continue }
            ScoreAdvisories.note(SessionAdvisory(
                message: "the passes disagree about how long \(trackName)'s section "
                    + "\(index + 1) is — pass \(shortest.pass) writes \(bars(shortest.length)) "
                    + "where pass \(longest.pass) writes \(bars(longest.length)). Passes are "
                    + "aligned section by section, so what follows starts at the longer one's "
                    + "end on every pass. Keep each pass's sections the same length and vary "
                    + "what is inside them.",
                line: line, column: column,
                file: SectionBuilder.foreignFile(file)))
        }
    }

    private static func bars(_ length: MusicTimeStamp) -> String {
        let bar = SectionBuilder.timeSignature.barDuration
        guard bar > 0, length / bar > 1e-9 else { return "nothing" }
        let count = (length / bar * 100).rounded() / 100
        let text = count == count.rounded() ? String(Int(count)) : String(count)
        return "\(text) bar\(count == 1 ? "" : "s")"
    }
}
