import Foundation

@resultBuilder
public struct TrackArrayBuilder {
    public static func buildBlock(_ components: [Track]...) -> [Track] {
        return components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: Track) -> [Track] {
        return [expression]
    }

    public static func buildExpression(_ expression: [Track]) -> [Track] {
        return expression
    }

    public static func buildArray(_ components: [[Track]]) -> [Track] {
        return components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [Track]?) -> [Track] {
        return component ?? []
    }

    public static func buildEither(first component: [Track]) -> [Track] {
        return component
    }

    public static func buildEither(second component: [Track]) -> [Track] {
        return component
    }
}

@resultBuilder
public enum SectionArrayBuilder {
    public static func buildBlock(_ components: [Section]...) -> [Section] {
        let allSections = components.flatMap { $0 }
        var currentTime: MusicTimeStamp = 0

        return allSections.map { section in
            var newSection = section
            newSection.notes = section.notes.map {
                var n = $0
                n.startTime = $0.startTime + currentTime
                return n
            }
            currentTime += section.duration
            return newSection
        }
    }

    public static func buildExpression(_ expression: [Section], line: Int = #line, column: Int = #column, file: String = #fileID) -> [Section] {
        return expression.map { stampUnmapped($0, line: line, column: column, file: file) }
    }

    public static func buildExpression(_ expression: Section, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Section] {
        return [stampUnmapped(expression, line: line, column: column, file: file)]
    }

    private static func stampUnmapped(_ section: Section, line: Int, column: Int, file: String) -> Section {
        var newSection = section
        newSection.notes = section.notes.map {
            var n = $0
            if n.sourceLine == nil {
                n.sourceLine = line; n.sourceColumn = column
                n.sourceFile = SectionBuilder.foreignFile(file)
            }
            return n
        }
        return newSection
    }
    
    public static func buildArray(_ components: [[Section]]) -> [Section] {
        return components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [Section]?) -> [Section] {
        return component ?? []
    }

    public static func buildEither(first component: [Section]) -> [Section] {
        return component
    }

    public static func buildEither(second component: [Section]) -> [Section] {
        return component
    }

    public static func buildExpression(_ loop: Loop) -> [Section] {
        return loop.expandedSections()
    }
}

struct PendingCurve {
    let target: AutomationTarget
    let breakpoints: [Double: Double]
    let timeScale: MusicTimeStamp?
    let shape: AutomationShape

    static func applying(_ pending: [PendingCurve], to notes: [Note]) -> [Note] {
        var result = notes
        guard !pending.isEmpty, !result.isEmpty else { return result }
        let span = result.reduce(0.0) { max($0, $1.startTime + $1.duration) }
        for pending in pending {
            guard let curve = AutomationCurve.make(pending.target, pending.breakpoints,
                                                   timeScale: pending.timeScale ?? span,
                                                   curve: pending.shape) else { continue }
            if pending.target.isPerVoice {
                result = result.map { note in
                    guard let slice = curve.sliced(from: note.startTime, length: note.duration) else { return note }
                    var n = note
                    n.automation = (note.automation ?? []) + [slice]
                    return n
                }
            } else {
                guard let carrier = result.indices.min(by: { result[$0].startTime < result[$1].startTime })
                else { continue }
                let base = result[carrier].startTime
                result[carrier].automation =
                    (result[carrier].automation ?? []) + [curve.shiftingTimes(by: -base)]
            }
        }
        return result
    }
}

public struct NotationExpression {
    let notation: String
    var _velocity: UInt32? = nil
    var _velocities: [UInt32]? = nil
    var _duration: MusicTimeStamp? = nil
    var _durations: [MusicTimeStamp]? = nil
    var _arpeggioPattern: ArpeggioPattern? = nil
    var _arpeggioDelay: MusicTimeStamp = 0.05
    var _arpeggioFill: Bool = false
    var _arpeggioOver: MusicTimeStamp? = nil
    var _transpose: Int? = nil
    var _key: Scale? = nil
    var _automation: [PendingCurve] = []

    init(_ notation: String) { self.notation = notation }

    public func key(_ root: Pitch, _ mode: ScaleMode) -> NotationExpression {
        var c = self; c._key = Scale(root, mode); return c
    }
    public func key(_ scale: Scale) -> NotationExpression {
        var c = self; c._key = scale; return c
    }

    public func velocity(_ v: UInt32) -> NotationExpression {
        var c = self; c._velocity = v; return c
    }
    func withVelocities(_ vs: [UInt32]) -> NotationExpression {
        var c = self; c._velocities = vs; return c
    }
    public func velocities(_ vs: UInt32...) -> NotationExpression { withVelocities(vs) }

    public func duration(_ d: MusicTimeStamp) -> NotationExpression {
        var c = self; c._duration = d; return c
    }
    func withDurations(_ ds: [MusicTimeStamp]) -> NotationExpression {
        var c = self; c._durations = ds; return c
    }
    public func durations(_ ds: MusicTimeStamp...) -> NotationExpression { withDurations(ds) }

    public func arpeggio(_ pattern: ArpeggioPattern = .up, delay: MusicTimeStamp = 0.05) -> NotationExpression {
        var c = self; c._arpeggioPattern = pattern; c._arpeggioDelay = delay; return c
    }

    public func arpeggioFill(_ pattern: ArpeggioPattern = .up) -> NotationExpression {
        var c = self; c._arpeggioPattern = pattern; c._arpeggioFill = true; return c
    }

    public func arpeggio(over duration: MusicTimeStamp, pattern: ArpeggioPattern = .up) -> NotationExpression {
        var c = self; c._arpeggioPattern = pattern; c._arpeggioOver = duration; return c
    }

    public func transpose(_ semitones: Int) -> NotationExpression {
        var c = self; c._transpose = (c._transpose ?? 0) + semitones; return c
    }

    public func octave(_ n: Int) -> NotationExpression {
        return transpose((n - 5) * 12)
    }

    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> NotationExpression {
        automating(target, breakpoints, timeScale: nil, curve: curve)
    }
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> NotationExpression {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> NotationExpression {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    public func automate(_ target: AutomationTarget, beats breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> NotationExpression {
        automating(target, breakpoints, timeScale: 1.0 / Double(SectionBuilder.timeSignature.noteValue), curve: curve)
    }

    private func automating(_ target: AutomationTarget, _ breakpoints: [Double: Double],
                            timeScale: MusicTimeStamp?, curve: AutomationShape) -> NotationExpression {
        guard !breakpoints.isEmpty else { return self }
        var c = self
        c._automation.append(PendingCurve(target: target, breakpoints: breakpoints,
                                          timeScale: timeScale, shape: curve))
        return c
    }

    func applying(to notes: [Note]) -> [Note] {
        var result = notes

        if let key = _key { result = result.keyed(in: key) }

        if let v = _velocity {
            result = result.map { var n = $0; n.velocity = v; return n }
        } else if let vs = _velocities {
            result = result.enumerated().map { i, n in
                var n = n; n.velocity = i < vs.count ? vs[i] : n.velocity; return n
            }
        }

        if _duration != nil || _durations != nil {
            var groupStarts: [MusicTimeStamp] = []
            for n in result {
                if let last = groupStarts.last, n.startTime >= last, n.startTime - last < 0.5 { continue }
                groupStarts.append(n.startTime)
            }
            let isUnitGrid = groupStarts.enumerated().allSatisfy { abs($1 - MusicTimeStamp($0)) < 1e-9 }

            func groupDuration(_ index: Int, fallback: MusicTimeStamp) -> MusicTimeStamp {
                if let d = _duration { return d }
                if let ds = _durations, index < ds.count { return ds[index] }
                return fallback
            }

            var newNotes: [Note] = []
            newNotes.reserveCapacity(result.count)
            var groupIndex = -1
            var groupOriginalStart: MusicTimeStamp = -.infinity
            var groupStart: MusicTimeStamp = 0
            var nextGroupStart: MusicTimeStamp = 0
            for note in result {
                if note.startTime < groupOriginalStart || note.startTime - groupOriginalStart >= 0.5 {
                    groupIndex += 1
                    groupOriginalStart = note.startTime
                    groupStart = nextGroupStart
                    nextGroupStart = groupStart + groupDuration(groupIndex, fallback: note.duration)
                }
                var n = note.scalingSlides(from: note.duration,
                                           to: groupDuration(groupIndex, fallback: note.duration))
                n.duration = groupDuration(groupIndex, fallback: note.duration)
                if isUnitGrid {
                    n.startTime = groupStart + (note.startTime - groupOriginalStart)
                }
                newNotes.append(n)
            }
            result = newNotes
        }

        if let shift = _transpose, shift != 0 {
            result = result.map { note in
                var n = note
                if let pitch = note.pitch {
                    let shifted = Int(pitch) + shift
                    n.pitch = shifted >= 0 ? UInt32(min(shifted, 127)) : nil
                }
                if let variants = note.pitchVariants {
                    n.pitchVariants = variants.map { UInt32(max(0, min(127, Int($0) + shift))) }
                }
                if let steps = note.slides {
                    n.slides = steps.map { step in
                        var s = step
                        s.from = UInt32(max(0, min(127, Int(step.from) + shift)))
                        return s
                    }
                }
                return n
            }
        }

        if let pattern = _arpeggioPattern {
            var seen: [MusicTimeStamp] = []
            var groups: [MusicTimeStamp: [Note]] = [:]
            for note in result {
                if groups[note.startTime] == nil { seen.append(note.startTime); groups[note.startTime] = [] }
                groups[note.startTime]!.append(note)
            }
            result = seen.flatMap { t -> [Note] in
                let group = groups[t]!
                guard group.count > 1 else { return group }
                let delay: MusicTimeStamp
                if let over = _arpeggioOver {
                    delay = over / MusicTimeStamp(group.count)
                } else if _arpeggioFill {
                    let duration = group.map { $0.duration }.max() ?? 1.0
                    delay = duration / MusicTimeStamp(group.count)
                } else {
                    delay = _arpeggioDelay
                }
                return arpeggiatedNotes(group, pattern: pattern, delay: delay)
            }
        }

        result = PendingCurve.applying(_automation, to: result)

        return result
    }
}

extension NotationExpression: CustomStringConvertible {
    public var description: String { notation }
}

public struct JoinedNotation {
    var parts: [NotationExpression]
    var _automation: [PendingCurve] = []

    init(_ parts: [NotationExpression]) { self.parts = parts }

    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> JoinedNotation {
        automating(target, breakpoints, timeScale: nil, curve: curve)
    }
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> JoinedNotation {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> JoinedNotation {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    public func automate(_ target: AutomationTarget, beats breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> JoinedNotation {
        automating(target, breakpoints, timeScale: 1.0 / Double(SectionBuilder.timeSignature.noteValue),
                   curve: curve)
    }

    private func automating(_ target: AutomationTarget, _ breakpoints: [Double: Double],
                            timeScale: MusicTimeStamp?, curve: AutomationShape) -> JoinedNotation {
        guard !breakpoints.isEmpty else { return self }
        var c = self
        c._automation.append(PendingCurve(
            target: target, breakpoints: breakpoints, timeScale: timeScale, shape: curve))
        return c
    }

    func notes() -> [Note] {
        var result: [Note] = []
        var cursor: MusicTimeStamp = 0
        for (index, part) in parts.enumerated() {
            var notes = part.applying(to: SectionBuilder.parseNotation(part.notation))
            let span = notes.reduce(0.0) { max($0, $1.startTime + $1.duration) }
            if index > 0 {
                notes = notes.map {
                    var n = $0
                    n.sourceOffset = nil; n.sourceLength = nil
                    n.variantSourceOffsets = nil; n.variantSourceLengths = nil
                    n.slideSourceOffsets = nil; n.slideSourceLengths = nil
                    return n
                }
            }
            result += notes.map { var n = $0; n.startTime += cursor; return n }
            cursor += span
        }
        return PendingCurve.applying(_automation, to: result)
    }
}

public func + (lhs: NotationExpression, rhs: NotationExpression) -> JoinedNotation {
    JoinedNotation([lhs, rhs])
}
public func + (lhs: NotationExpression, rhs: String) -> JoinedNotation {
    JoinedNotation([lhs, NotationExpression(rhs)])
}
public func + (lhs: String, rhs: NotationExpression) -> JoinedNotation {
    JoinedNotation([NotationExpression(lhs), rhs])
}
public func + (lhs: JoinedNotation, rhs: NotationExpression) -> JoinedNotation {
    JoinedNotation(lhs.parts + [rhs])
}
public func + (lhs: JoinedNotation, rhs: String) -> JoinedNotation {
    JoinedNotation(lhs.parts + [NotationExpression(rhs)])
}
public func + (lhs: NotationExpression, rhs: JoinedNotation) -> JoinedNotation {
    JoinedNotation([lhs] + rhs.parts)
}
public func + (lhs: String, rhs: JoinedNotation) -> JoinedNotation {
    JoinedNotation([NotationExpression(lhs)] + rhs.parts)
}

public extension String {
    func key(_ root: Pitch, _ mode: ScaleMode) -> NotationExpression { NotationExpression(self).key(root, mode) }
    func key(_ scale: Scale) -> NotationExpression { NotationExpression(self).key(scale) }
    func velocity(_ v: UInt32) -> NotationExpression { NotationExpression(self).velocity(v) }
    func velocities(_ vs: UInt32...) -> NotationExpression { NotationExpression(self).withVelocities(vs) }
    func duration(_ d: MusicTimeStamp) -> NotationExpression { NotationExpression(self).duration(d) }
    func durations(_ ds: MusicTimeStamp...) -> NotationExpression { NotationExpression(self).withDurations(ds) }
    func arpeggio(_ pattern: ArpeggioPattern = .up, delay: MusicTimeStamp = 0.05) -> NotationExpression {
        NotationExpression(self).arpeggio(pattern, delay: delay)
    }
    func arpeggioFill(_ pattern: ArpeggioPattern = .up) -> NotationExpression {
        NotationExpression(self).arpeggioFill(pattern)
    }
    func arpeggio(over duration: MusicTimeStamp, pattern: ArpeggioPattern = .up) -> NotationExpression {
        NotationExpression(self).arpeggio(over: duration, pattern: pattern)
    }
    func transpose(_ semitones: Int) -> NotationExpression { NotationExpression(self).transpose(semitones) }
    func octave(_ n: Int) -> NotationExpression { NotationExpression(self).octave(n) }
    func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                  curve: AutomationShape = .linear) -> NotationExpression {
        NotationExpression(self).automate(target, over: breakpoints, curve: curve)
    }
    func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                  curve: AutomationShape = .linear) -> NotationExpression {
        NotationExpression(self).automate(target, at: breakpoints, curve: curve)
    }
    func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                  curve: AutomationShape = .linear) -> NotationExpression {
        NotationExpression(self).automate(target, bars: breakpoints, curve: curve)
    }
    func automate(_ target: AutomationTarget, beats breakpoints: [Double: Double],
                  curve: AutomationShape = .linear) -> NotationExpression {
        NotationExpression(self).automate(target, beats: breakpoints, curve: curve)
    }
}

public struct ParseWarning: Equatable {
    public let token: String
    public let offset: Int
    public let length: Int
    public let message: String

    public init(token: String, offset: Int, length: Int, message: String) {
        self.token = token
        self.offset = offset
        self.length = length
        self.message = message
    }
}

@resultBuilder
public enum SectionBuilder {
    public static var timeSignature: TimeSignature = .fourFour
    private static var barDuration: MusicTimeStamp { timeSignature.barDuration }

    private static func stamped(_ notes: [Note], line: Int, column: Int, file: String,
                                notation: String? = nil) -> [Note] {
        let id = notation.map(NotationID.of)
        let foreign = Self.foreignFile(file)
        return notes.map { var n = $0; n.sourceLine = line; n.sourceColumn = column
                           n.sourceFile = foreign
                           n.notationID = id; return n }
    }

    public static let libraryModulePrefix = "ComponiumLibrary/"
    public static let scoreModulePrefix = "Score/"
    public static let scoreFilePrefix = "Score/userDSL_"
    public static func foreignFile(_ file: String) -> String? {
        if file.hasPrefix(libraryModulePrefix) { return file }
        if file.hasPrefix(scoreModulePrefix), !file.hasPrefix(scoreFilePrefix) { return file }
        return nil
    }

    private static func stampedToken(_ notes: [Note], offset: Int, length: Int) -> [Note] {
        notes.map { var n = $0; n.sourceOffset = offset; n.sourceLength = length; return n }
    }

    public static func buildOptional(_ component: [Note]?) -> [Note] {
        return component ?? []
    }

    public static func buildEither(first component: [Note]) -> [Note] {
        return component
    }

    public static func buildEither(second component: [Note]) -> [Note] {
        return component
    }

    public static func buildArray(_ components: [[Note]]) -> [Note] {
        return components.flatMap { $0 }
    }

    public static func buildBlock(_ components: [Note]...) -> [Note] {
        var allNotes: [Note] = []
        for (layer, notes) in components.enumerated() {
            allNotes.append(contentsOf: notes.map { note in
                var n = note
                n.layerIndex = layer
                return n
            })
        }
        return allNotes
    }

    public static func buildFinalResult(_ notes: [Note]) -> Section {
        return hoistingTrackCurves(notes)
    }

    private static func hoistingTrackCurves(_ notes: [Note]) -> Section {
        var lanes: [AutomationCurve] = []
        let cleaned = notes.map { note -> Note in
            guard let curves = note.automation,
                  curves.contains(where: { !$0.target.isPerVoice }) else { return note }
            var n = note
            let kept = curves.filter { $0.target.isPerVoice }
            n.automation = kept.isEmpty ? nil : kept
            for curve in curves where !curve.target.isPerVoice {
                let lifted = curve.shiftingTimes(by: note.startTime)
                guard let existing = lanes.firstIndex(where: { $0.target == curve.target }) else {
                    lanes.append(lifted)
                    continue
                }
                let from = lifted.points.first?.time ?? 0
                let to = lifted.points.last?.time ?? 0
                let kept = lanes[existing].points.filter { $0.time < from || $0.time > to }
                lanes[existing] = AutomationCurve(target: curve.target, points: kept + lifted.points)
            }
            return n
        }
        var section = Section(notes: cleaned)
        if !lanes.isEmpty { section.automation = lanes }
        return section
    }
    public static func buildExpression(_ expression: Progression, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        let hasExplicitStartTimes = expression.chords.contains {
            $0.notes.contains { $0.startTime != 0.0 }
        }
        if hasExplicitStartTimes {
            return stamped(expression.chords.flatMap { $0.notes }, line: line, column: column, file: file)
        }

        var currentTime: MusicTimeStamp = 0
        var allNotes: [Note] = []

        for chord in expression.chords {
            let positionedNotes = chord.notes.map { note -> Note in
                var n = note
                n.startTime = currentTime
                return n
            }
            allNotes.append(contentsOf: positionedNotes)
            let chordDuration = chord.notes.map { $0.duration }.max() ?? 0
            currentTime += chordDuration
        }

        return stamped(allNotes, line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: Chord, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        return stamped(expression.notes, line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: Note, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        return stamped([expression], line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: NoteSet, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        return stamped([expression.asNote()], line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: NotationExpression, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        stamped(expression.applying(to: parseNotation(expression.notation)), line: line, column: column, file: file,
                notation: expression.notation)
    }
    public static func buildExpression(_ expression: String, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        stamped(parseNotation(expression), line: line, column: column, file: file, notation: expression)
    }
    public static func buildExpression(_ expression: JoinedNotation, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        stamped(expression.notes(), line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: Section, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        var carried = expression.notes
        if let lanes = expression.automation, !lanes.isEmpty,
           let carrier = carried.indices.min(by: { carried[$0].startTime < carried[$1].startTime }) {
            let base = carried[carrier].startTime
            carried[carrier].automation =
                (carried[carrier].automation ?? []) + lanes.map { $0.shiftingTimes(by: -base) }
        }
        return carried.map { note in
            var n = note
            if expression.isMuted { n.activity = .set([]) }
            else { n.activity = n.activity ?? expression.activity }
            return n
        }
    }
    public static func buildExpression(_ expression: Sample, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        stamped(expression.reel.notes(), line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: SampleReel, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        stamped(expression.notes(), line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: [Sample], line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        stamped(expression.reduce(SampleReel([])) { $0 + $1 }.notes(), line: line, column: column, file: file)
    }
    public static func buildExpression(_ expression: DrumLane, line: Int = #line, column: Int = #column, file: String = #fileID) -> [Note] {
        stamped(expression.notes(barDuration: barDuration), line: line, column: column, file: file,
                notation: expression.grid)
    }
    public static func parseNotation(_ expression: String) -> [Note] {
        var warnings: [ParseWarning] = []
        return parseNotation(expression, warnings: &warnings)
    }

    public static func parseNotationWithWarnings(_ expression: String) -> (notes: [Note], warnings: [ParseWarning]) {
        var warnings: [ParseWarning] = []
        let notes = parseNotation(expression, warnings: &warnings)
        return (notes, warnings)
    }

    private static func parseNotation(_ expression: String, warnings: inout [ParseWarning]) -> [Note] {
        if expression.contains("|") {
            return parseBarNotation(expression, warnings: &warnings)
        }

        let tokens = tokenizeExpression(expression)

        if tokens.count == 1,
           let (rawSingle, offset) = tokens.first,
           case let (single, singleFall) = parseFallSuffix(rawSingle),
           !single.hasPrefix("["), !single.hasPrefix(">"), !single.hasPrefix("^"),
           single.range(of: "^[A-Ga-g#b0-9R_>=.^-]+$", options: .regularExpression) != nil {
            var run = parseCompactNotes(single, tokenOffset: offset)
            if !run.isEmpty {
                if let singleFall { attachFall(singleFall, to: &run, indices: run.indices) }
                return run
            }
        }

        var notes: [Note] = []
        var currentTime: MusicTimeStamp = 0
        var heldIndices: [Int] = []
        var heldChord: (root: NoteNotation, quality: ChordQuality)? = nil
        var lastSounded: (pitch: Pitch, degree: ScaleDegree?)? = nil

        func extendHeld(to slotEnd: MusicTimeStamp) {
            for i in heldIndices {
                notes[i].duration = max(notes[i].duration, slotEnd - notes[i].startTime)
            }
        }

        for (rawToken, tokenOffset) in tokens {
            guard !rawToken.isEmpty else { continue }
            let (token, tokenFall) = parseFallSuffix(rawToken)
            let tokenLength = rawToken.count

            if token == "-" {
                extendHeld(to: currentTime + 1.0)
                if let tokenFall { attachFall(tokenFall, to: &notes, indices: heldIndices) }
                currentTime += 1.0
                continue
            }
            if token.hasPrefix("+") {
                extendHeld(to: currentTime + 1.0)
                let heldPitches = Set(heldIndices.compactMap { notes[$0].pitch })
                let (added, chordContext) = additiveNotes(String(token.dropFirst()), heldChord: heldChord,
                                                          heldPitches: heldPitches, startTime: currentTime, duration: 1.0)
                let base = notes.count
                notes.append(contentsOf: stampedToken(added, offset: tokenOffset, length: tokenLength))
                heldIndices.append(contentsOf: base..<notes.count)
                if let chordContext { heldChord = chordContext }
                if let tokenFall { attachFall(tokenFall, to: &notes, indices: base..<notes.count) }
                if let i = (base..<notes.count).last(where: { notes[$0].pitch != nil }) { lastSounded = (notes[i].pitch!, notes[i].degree) }
                currentTime += 1.0
                continue
            }
            if token.hasPrefix(">") || token.hasPrefix("^") {
                let (newHeld, chordContext) = slideHeldNotes(&notes, heldIndices: heldIndices,
                                                            payload: String(token.dropFirst()),
                                                            slotStart: currentTime, slotDuration: 1.0,
                                                            tokenOffset: tokenOffset, tokenLength: tokenLength,
                                                            lastSounded: lastSounded,
                                                            legato: token.hasPrefix("^"),
                                                            warnings: &warnings)
                heldIndices = newHeld
                heldChord = chordContext
                if let tokenFall { attachFall(tokenFall, to: &notes, indices: newHeld) }
                if let i = newHeld.last(where: { notes[$0].pitch != nil }) { lastSounded = (notes[i].pitch!, notes[i].degree) }
                currentTime += 1.0
                continue
            }

            let tokenBase = notes.count
            let tokenStartTime = currentTime
            heldChord = nil

            let (cleanToken, arpeggioPattern, arpeggioSpread) = parseArpeggioSpec(token)

            func appendCompactRun() -> Bool {
                guard cleanToken.range(of: "^[A-Ga-g#b0-9R_>=.^-]+$", options: .regularExpression) != nil else { return false }
                let base = token.hasSuffix(cleanToken) ? tokenOffset + (token.count - cleanToken.count) : tokenOffset
                let compactNotes = parseCompactNotes(cleanToken, tokenOffset: base)
                guard let maxEnd = compactNotes.map({ $0.startTime + $0.duration }).max() else { return false }
                for note in compactNotes {
                    var n = note
                    n.startTime = currentTime + note.startTime
                    notes.append(n)
                }
                currentTime += maxEnd
                return true
            }

            if cleanToken.uppercased() == "R" || cleanToken == "_" {
                notes.append(Note(pitch: nil, velocity: 0, startTime: currentTime, duration: 1.0))
                currentTime += 1.0
            } else if cleanToken.hasPrefix("[") && cleanToken.hasSuffix("]") && !hasTopLevelSlide(cleanToken) {
                let inner = String(cleanToken.dropFirst().dropLast())
                let parts = inner.split(separator: " ").map(String.init)
                var chordNotes: [Note]
                if !parts.isEmpty, parts.allSatisfy({ parseDegreeToken($0) != nil }) {
                    chordNotes = parts.compactMap(parseDegreeToken).map {
                        degreeNote($0, startTime: currentTime)
                    }
                    if let pattern = arpeggioPattern {
                        applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: 1.0, tokenOffset: tokenOffset)
                    }
                } else if let first = parts.first, let spec = parseDegreeChord(first) {
                    let tones = degreeChordTones(root: spec.root, quality: spec.quality,
                                                 extensions: Array(parts.dropFirst()))
                    chordNotes = tones.map { degreeNote($0, startTime: currentTime) }
                    chordNotes += parts.dropFirst().compactMap(forcedPitch).map {
                        Note(pitch: $0, velocity: 100, startTime: currentTime, duration: 1.0)
                    }
                    if let pattern = arpeggioPattern {
                        applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: 1.0, tokenOffset: tokenOffset)
                    }
                } else if let first = parts.first, let chord = parseNamedChord(first) {
                    chord.addExtensions(Array(parts.dropFirst()))
                    let stackDuration = chord.notes.map { $0.duration }.max() ?? 1.0
                    for pitch in parts.dropFirst().compactMap(forcedPitch) {
                        chord.notes.append(Note(pitch: pitch, duration: stackDuration))
                    }
                    heldChord = (chord.root, chord.quality)
                    if let pattern = arpeggioPattern {
                        switch arpeggioSpread {
                        case .fill:        _ = chord.arpeggio(over: 1.0, pattern: pattern)
                        case .over(let d): _ = chord.arpeggio(over: d,   pattern: pattern)
                        case .tight:       _ = chord.arpeggio(pattern)
                        }
                    }
                    chordNotes = chord.notes.map {
                        Note(pitch: $0.pitch, velocity: $0.velocity, startTime: currentTime + $0.startTime, duration: 1.0)
                    }
                } else if parts.contains(where: { $0.hasPrefix("'") || parseDegreeToken($0) != nil }) {
                    chordNotes = parts.compactMap(stackElement).map {
                        var note = Note(pitch: $0.pitch, velocity: 100, startTime: currentTime, duration: 1.0)
                        note.degree = $0.degree
                        return note
                    }
                    if let pattern = arpeggioPattern {
                        applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: 1.0, tokenOffset: tokenOffset)
                    }
                } else {
                    chordNotes = parseCompactNotes(inner).map {
                        Note(pitch: $0.pitch, velocity: $0.velocity, startTime: currentTime, duration: 1.0)
                    }
                    if let pattern = arpeggioPattern {
                        applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: 1.0, tokenOffset: tokenOffset)
                    }
                }
                chordNotes = stampedToken(chordNotes, offset: tokenOffset, length: tokenLength)
                notes.append(contentsOf: chordNotes)
                if !chordNotes.isEmpty { currentTime += 1.0 }
            } else if cleanToken.hasPrefix("(") && cleanToken.hasSuffix(")") {
                let set = noteSetNotes(cleanToken, token: token, tokenOffset: tokenOffset,
                                       tokenLength: tokenLength, mode: noteSetMode(arpeggioPattern),
                                       startTime: currentTime, duration: 1.0, warnings: &warnings)
                if !set.isEmpty {
                    notes.append(contentsOf: set)
                    currentTime += 1.0
                }
            } else if cleanToken.hasPrefix("{") && cleanToken.hasSuffix("}") {
                warnArpeggioOnRunGroup(arpeggioPattern, token: token, tokenOffset: tokenOffset,
                                       tokenLength: tokenLength, warnings: &warnings)
                let run = runGroupNotes(cleanToken, startTime: currentTime, slotDuration: 1.0,
                                        tokenOffset: tokenOffset, warnings: &warnings)
                if !run.isEmpty {
                    notes.append(contentsOf: run)
                    currentTime += 1.0
                }
            } else if cleanToken.hasPrefix("'"), let pitch = pitchForNoteName(String(cleanToken.dropFirst())) {
                var note = Note(pitch: pitch, velocity: 100, startTime: currentTime, duration: 1.0)
                note.sourceOffset = tokenOffset
                note.sourceLength = tokenLength
                notes.append(note)
                currentTime += 1.0
            } else if let pitch = pitchForNoteName(cleanToken) {
                var note = Note(pitch: pitch, velocity: 100, startTime: currentTime, duration: 1.0)
                note.sourceOffset = tokenOffset
                note.sourceLength = tokenLength
                notes.append(note)
                currentTime += 1.0
            } else if let written = parseDegreeToken(cleanToken) {
                var note = degreeNote(written, startTime: currentTime)
                note.sourceOffset = tokenOffset
                note.sourceLength = tokenLength
                notes.append(note)
                currentTime += 1.0
            } else if let spec = parseDegreeChord(cleanToken) {
                var chordNotes = degreeChordTones(root: spec.root, quality: spec.quality).map {
                    degreeNote($0, startTime: currentTime)
                }
                if let pattern = arpeggioPattern {
                    applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: 1.0, tokenOffset: tokenOffset)
                }
                notes.append(contentsOf: stampedToken(chordNotes, offset: tokenOffset, length: tokenLength))
                if !chordNotes.isEmpty { currentTime += 1.0 }
            } else if let chord = parseNamedChord(cleanToken) {
                heldChord = (chord.root, chord.quality)
                if let pattern = arpeggioPattern {
                    switch arpeggioSpread {
                    case .fill:        _ = chord.arpeggio(over: 1.0, pattern: pattern)
                    case .over(let d): _ = chord.arpeggio(over: d,   pattern: pattern)
                    case .tight:       _ = chord.arpeggio(pattern)
                    }
                }
                let chordNotes = chord.notes.map {
                    Note(pitch: $0.pitch, velocity: $0.velocity, startTime: currentTime + $0.startTime, duration: 1.0)
                }
                notes.append(contentsOf: stampedToken(chordNotes, offset: tokenOffset, length: tokenLength))
                if !chordNotes.isEmpty { currentTime += 1.0 }
            } else if appendCompactRun() {
            } else if cleanToken.contains(">") || cleanToken.contains("^") {
                let fused = parseSlideFusion(cleanToken, startTime: currentTime, slotDuration: 1.0)
                if !fused.isEmpty {
                    notes.append(contentsOf: stampedToken(fused, offset: tokenOffset, length: tokenLength))
                    currentTime += 1.0
                }
            }

            if currentTime == tokenStartTime && notes.count == tokenBase {
                warnings.append(ParseWarning(token: rawToken, offset: tokenOffset, length: tokenLength,
                                             message: "Unrecognized token \"\(rawToken)\" — substituted a rest"))
                var rest = Note(pitch: nil, velocity: 0, startTime: currentTime, duration: 1.0)
                rest.sourceOffset = tokenOffset
                rest.sourceLength = tokenLength
                notes.append(rest)
                currentTime += 1.0
            }

            if let tokenFall { attachFall(tokenFall, to: &notes, indices: tokenBase..<notes.count) }
            if let i = (tokenBase..<notes.count).last(where: { notes[$0].pitch != nil }) { lastSounded = (notes[i].pitch!, notes[i].degree) }

            heldIndices = (tokenBase..<notes.count).filter {
                notes[$0].pitch != nil && notes[$0].startTime + notes[$0].duration + 1e-9 >= currentTime
            }
        }

        return notes
    }

    private static func additiveNotes(_ content: String,
                                      heldChord: (root: NoteNotation, quality: ChordQuality)?,
                                      heldPitches: Set<Pitch>,
                                      startTime: MusicTimeStamp,
                                      duration: MusicTimeStamp) -> (notes: [Note], chord: (root: NoteNotation, quality: ChordQuality)?) {
        let (clean, pattern, spread) = parseArpeggioSpec(content)
        var candidates: [Note] = []
        var chordContext: (root: NoteNotation, quality: ChordQuality)? = nil

        func positioned(_ chord: Chord) -> [Note] {
            return chord.notes.map {
                Note(pitch: $0.pitch, velocity: $0.velocity, startTime: startTime, duration: duration)
            }
        }
        func extensionNotes(_ tokens: [String]) -> [Note]? {
            guard !tokens.isEmpty, let held = heldChord, let rootPitch = held.root.pitch else { return nil }
            let resolved = tokens.compactMap { token in
                Chord.semitones(forExtension: token, baseQuality: held.quality).map {
                    Note(pitch: rootPitch + $0, velocity: 100, startTime: startTime, duration: duration)
                }
            }
            return resolved.count == tokens.count ? resolved : nil
        }

        func degreeCandidates(_ degrees: [ScaleDegree]) -> [Note] {
            degrees.map { degreeNote($0, startTime: startTime, duration: duration) }
        }

        if clean.hasPrefix("[") && clean.hasSuffix("]") {
            let inner = String(clean.dropFirst().dropLast())
            let parts = inner.split(separator: " ").map(String.init)
            if let first = parts.first, let chord = parseNamedChord(first, duration: duration) {
                chord.addExtensions(Array(parts.dropFirst()))
                for pitch in parts.dropFirst().compactMap(forcedPitch) {
                    chord.notes.append(Note(pitch: pitch, duration: duration))
                }
                chordContext = (chord.root, chord.quality)
                candidates = positioned(chord)
            } else if let resolved = extensionNotes(parts) {
                candidates = resolved
            } else if let first = parts.first, let spec = parseDegreeChord(first) {
                candidates = degreeCandidates(degreeChordTones(root: spec.root, quality: spec.quality,
                                                               extensions: Array(parts.dropFirst())))
            } else {
                candidates = parts.compactMap(stackElement).map {
                    var note = Note(pitch: $0.pitch, velocity: 100, startTime: startTime, duration: duration)
                    note.degree = $0.degree
                    return note
                }
            }
        } else if let resolved = extensionNotes([clean]) {
            candidates = resolved
        } else if let pitch = lookupPitch(clean) {
            candidates = [Note(pitch: pitch, velocity: 100, startTime: startTime, duration: duration)]
        } else if let degree = parseDegreeToken(clean) {
            candidates = degreeCandidates([degree])
        } else if let spec = parseDegreeChord(clean) {
            candidates = degreeCandidates(degreeChordTones(root: spec.root, quality: spec.quality))
        } else if let chord = parseNamedChord(clean, duration: duration) {
            chordContext = (chord.root, chord.quality)
            candidates = positioned(chord)
        } else if clean.range(of: "^[A-Ga-g#b0-9]+$", options: .regularExpression) != nil {
            candidates = parseCompactNotes(clean).compactMap { note in
                note.pitch.map { Note(pitch: $0, velocity: note.velocity, startTime: startTime, duration: duration) }
            }
        }

        var attacked = candidates.filter { note in note.pitch.map { !heldPitches.contains($0) } ?? false }

        if let pattern = pattern, attacked.count > 1 {
            let stripped = attacked.map { note -> Note in var n = note; n.startTime = 0; return n }
            let delay: MusicTimeStamp
            switch spread {
            case .fill:        delay = duration / MusicTimeStamp(stripped.count)
            case .over(let d): delay = d / MusicTimeStamp(stripped.count)
            case .tight:       delay = 0.05
            }
            attacked = arpeggiatedNotes(stripped, pattern: pattern, delay: delay).map {
                var n = $0; n.startTime += startTime; return n
            }
        }

        return (attacked, chordContext)
    }

    // MARK: - Slides (">")

    private static func slideSpec(_ s: String) -> (rest: String, over: MusicTimeStamp, fill: Bool) {
        if s.hasPrefix("=") { return (String(s.dropFirst()), 0, true) }
        if namesDegree(s) { return (s, 0, false) }
        if let (value, rest) = parseLeadingDouble(s) { return (rest, value, false) }
        return (s, 0, false)
    }

    private static let defaultFallSemitones = -5

    private static func parseSignedInterval(_ s: String) -> (interval: Int, rest: String)? {
        guard let first = s.first, first == "+" || first == "-" else { return nil }
        var i = s.index(after: s.startIndex)
        var digits = ""
        while i < s.endIndex, s[i].isNumber { digits.append(s[i]); i = s.index(after: i) }
        guard let value = Int(digits) else { return nil }
        return (first == "-" ? -value : value, String(s[i...]))
    }

    private static func parseFallSuffix(_ token: String) -> (base: String, fall: Fall?) {
        guard let gt = token.lastIndex(of: ">"), gt != token.startIndex else { return (token, nil) }
        let suffix = String(token[token.index(after: gt)...])
        guard !suffix.isEmpty else { return (token, nil) }
        let base = String(token[..<gt])
        var over: MusicTimeStamp = 0
        var rest = suffix
        if let (value, remainder) = parseLeadingDouble(suffix) { over = value; rest = remainder }
        if rest == "_" { return (base, Fall(semitones: defaultFallSemitones, over: over)) }
        guard let (interval, tail) = parseSignedInterval(rest), tail.isEmpty else { return (token, nil) }
        return (base, Fall(semitones: interval, over: over))
    }

    private static func attachFall(_ fall: Fall, to notes: inout [Note], indices: some Sequence<Int>) {
        let pitched = indices.filter { notes[$0].pitch != nil }
        guard let maxEnd = pitched.map({ notes[$0].startTime + notes[$0].duration }).max() else { return }
        for i in pitched where notes[i].startTime + notes[i].duration + 1e-9 >= maxEnd {
            notes[i].fall = fall
        }
    }

    private struct SlideStage {
        var pitches: [Pitch]
        var degrees: [ScaleDegree?]
        var chord: (root: NoteNotation, quality: ChordQuality)?

        init(pitches: [Pitch], degrees: [ScaleDegree?]? = nil,
             chord: (root: NoteNotation, quality: ChordQuality)? = nil) {
            self.pitches = pitches
            self.degrees = degrees ?? Array(repeating: nil, count: pitches.count)
            self.chord = chord
        }

        init(degrees: [ScaleDegree], chord: (root: NoteNotation, quality: ChordQuality)? = nil) {
            self.init(pitches: degrees.map { Scale.unkeyed.pitch($0) }, degrees: degrees, chord: chord)
        }

        var isEmpty: Bool { pitches.isEmpty }

        func sorted() -> SlideStage {
            let order = pitches.indices.sorted { pitches[$0] < pitches[$1] }
            return SlideStage(pitches: order.map { pitches[$0] },
                              degrees: order.map { degrees[$0] },
                              chord: chord)
        }
    }

    private static func slideStage(_ s: String) -> SlideStage? {
        if s.hasPrefix("[") && s.hasSuffix("]") {
            let parts = s.dropFirst().dropLast().split(separator: " ").map(String.init)
            if !parts.isEmpty, parts.allSatisfy({ parseDegreeToken($0) != nil }) {
                return SlideStage(degrees: parts.compactMap(parseDegreeToken)).sorted()
            }
            if let first = parts.first, let spec = parseDegreeChord(first) {
                let tones = degreeChordTones(root: spec.root, quality: spec.quality,
                                             extensions: Array(parts.dropFirst()))
                var stage = SlideStage(degrees: tones)
                for pitch in parts.dropFirst().compactMap(forcedPitch) {
                    stage.pitches.append(pitch)
                    stage.degrees.append(nil)
                }
                return stage.isEmpty ? nil : stage.sorted()
            }
            if let first = parts.first, let chord = parseNamedChord(first) {
                chord.addExtensions(Array(parts.dropFirst()))
                var pitches = chord.notes.compactMap { $0.pitch }
                pitches.append(contentsOf: parts.dropFirst().compactMap(forcedPitch))
                guard !pitches.isEmpty else { return nil }
                return SlideStage(pitches: pitches, chord: (chord.root, chord.quality)).sorted()
            }
            let resolved = parts.compactMap(stackElement)
            guard !resolved.isEmpty else { return nil }
            return SlideStage(pitches: resolved.map { $0.pitch }, degrees: resolved.map { $0.degree }).sorted()
        }
        if let pitch = lookupPitch(s) { return SlideStage(pitches: [pitch]) }
        if let degree = parseDegreeToken(s) { return SlideStage(degrees: [degree]) }
        if let spec = parseDegreeChord(s) {
            return SlideStage(degrees: degreeChordTones(root: spec.root, quality: spec.quality)).sorted()
        }
        if let chord = parseNamedChord(s) {
            let pitches = chord.notes.compactMap { $0.pitch }
            guard !pitches.isEmpty else { return nil }
            return SlideStage(pitches: pitches, chord: (chord.root, chord.quality)).sorted()
        }
        return nil
    }

    private static func stackElement(_ part: String) -> (pitch: Pitch, degree: ScaleDegree?)? {
        if let degree = parseDegreeToken(part) { return (Scale.unkeyed.pitch(degree), degree) }
        return lookupPitch(part).map { ($0, nil) }
    }

    private static func slideHeldNotes(_ notes: inout [Note], heldIndices: [Int], payload: String,
                                       slotStart: MusicTimeStamp, slotDuration: MusicTimeStamp,
                                       tokenOffset: Int, tokenLength: Int,
                                       lastSounded: (pitch: Pitch, degree: ScaleDegree?)?,
                                       legato: Bool = false,
                                       warnings: inout [ParseWarning])
        -> (held: [Int], chord: (root: NoteNotation, quality: ChordQuality)?) {
        let connector = legato ? "^" : ">"
        let rest: String
        let over: MusicTimeStamp
        let carry: Double?
        if legato {
            let (c, r) = legatoSpec(payload)
            rest = r
            over = 0
            carry = c
        } else {
            let (r, explicitOver, fill) = slideSpec(payload)
            rest = r
            over = fill ? slotDuration : explicitOver
            carry = nil
        }

        if !legato, let (interval, targetStr) = parseSignedInterval(rest) {
            guard let stage = slideStage(targetStr) else {
                warnings.append(ParseWarning(token: connector + payload, offset: tokenOffset, length: tokenLength,
                                             message: "Unresolved scoop target \"\(targetStr)\""))
                return (heldIndices, nil)
            }
            var newHeld: [Int] = []
            for (i, target) in stage.pitches.enumerated() {
                var note = Note(pitch: target, velocity: 100, startTime: slotStart, duration: slotDuration)
                let source = UInt32(max(0, min(127, Int(target) + interval)))
                var step = SlideStep(from: source, at: 0, over: over)
                if let degree = stage.degrees[i] {
                    note.degree = degree
                    step.degree = ScaleDegree(degree: degree.degree, octave: degree.octave,
                                              alteration: degree.alteration + interval)
                }
                note.slides = [step]
                note.sourceOffset = tokenOffset
                note.sourceLength = tokenLength
                notes.append(note)
                newHeld.append(notes.count - 1)
            }
            return (newHeld, stage.chord)
        }
        func rejectHolding(_ message: String) -> (held: [Int], chord: (root: NoteNotation, quality: ChordQuality)?) {
            warnings.append(ParseWarning(token: connector + payload, offset: tokenOffset, length: tokenLength,
                                         message: message))
            let slotEnd = slotStart + slotDuration
            for i in heldIndices {
                notes[i].duration = max(notes[i].duration, slotEnd - notes[i].startTime)
            }
            return (heldIndices, nil)
        }
        if rest.hasPrefix("(") {
            return rejectHolding("Note set \"\(rest)\" isn't supported as a \(legato ? "legato" : "slide") target — held instead")
        }
        if parseArpeggioSpec(rest).1 != nil {
            return rejectHolding("Arpeggiated target \"\(rest)\" isn't supported as a \(legato ? "legato" : "slide") target — held instead")
        }
        guard let stage = slideStage(rest) else {
            warnings.append(ParseWarning(token: connector + payload, offset: tokenOffset, length: tokenLength,
                                         message: "Unresolved \(legato ? "legato" : "slide") target \"\(rest)\" — held notes end here"))
            return (heldIndices, nil)
        }
        let targets = stage.pitches
        let chordContext = stage.chord
        let slotEnd = slotStart + slotDuration
        let sources = heldIndices.filter { notes[$0].pitch != nil }
            .sorted { notes[$0].pitch! < notes[$1].pitch! }
        if sources.isEmpty {
            if targets.count == 1, let from = lastSounded {
                var note = Note(pitch: targets[0], velocity: 100, startTime: slotStart, duration: slotDuration)
                note.degree = stage.degrees[0]
                note.slides = [SlideStep(from: from.pitch, at: 0, over: over, carry: carry, degree: from.degree)]
                note.sourceOffset = tokenOffset
                note.sourceLength = tokenLength
                notes.append(note)
                return ([notes.count - 1], chordContext)
            }
            warnings.append(ParseWarning(token: connector + payload, offset: tokenOffset, length: tokenLength,
                                         message: lastSounded == nil
                                            ? "Nothing to scoop \"\(rest)\" from — attacked plain; name the source with a signed interval, e.g. \">-3\(rest)\""
                                            : "Chord scoops need a signed interval (e.g. \">-3\(rest)\") — attacked plain"))
        }
        var newHeld: [Int] = []
        let paired = min(sources.count, targets.count)
        for i in 0..<paired {
            let idx = sources[i]
            let fromPitch = notes[idx].pitch!
            var steps = notes[idx].slides ?? []
            steps.append(SlideStep(from: fromPitch, at: slotStart - notes[idx].startTime, over: over,
                                   carry: carry, degree: notes[idx].degree))
            var spanOffsets = notes[idx].slideSourceOffsets ?? []
            var spanLengths = notes[idx].slideSourceLengths ?? []
            while spanOffsets.count < steps.count - 1 {
                spanOffsets.append(notes[idx].sourceOffset ?? tokenOffset)
                spanLengths.append(notes[idx].sourceLength ?? tokenLength)
            }
            spanOffsets.append(tokenOffset)
            spanLengths.append(tokenLength)
            notes[idx].slideSourceOffsets = spanOffsets
            notes[idx].slideSourceLengths = spanLengths
            notes[idx].slides = steps
            notes[idx].pitch = targets[i]
            notes[idx].degree = stage.degrees[i]
            notes[idx].duration = slotEnd - notes[idx].startTime
            newHeld.append(idx)
        }
        for i in paired..<targets.count {
            var note = Note(pitch: targets[i], velocity: 100, startTime: slotStart, duration: slotDuration)
            note.degree = stage.degrees[i]
            note.sourceOffset = tokenOffset
            note.sourceLength = tokenLength
            notes.append(note)
            newHeld.append(notes.count - 1)
        }
        return (newHeld, chordContext)
    }

    private static func splitTopLevel(_ s: String, on separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for ch in s {
            if ch == "[" || ch == "(" { depth += 1; current.append(ch) }
            else if ch == "]" || ch == ")" { depth = max(0, depth - 1); current.append(ch) }
            else if ch == separator && depth == 0 { parts.append(current); current = "" }
            else { current.append(ch) }
        }
        parts.append(current)
        return parts
    }

    private static func hasTopLevelSlide(_ s: String) -> Bool {
        return splitTopLevel(s, on: ">").count > 1 || splitTopLevel(s, on: "^").count > 1
    }

    private static func parseSlideFusion(_ token: String, startTime: MusicTimeStamp, slotDuration: MusicTimeStamp) -> [Note] {
        let (rawParts, connectors) = splitTopLevelConnectors(token)
        guard rawParts.count >= 2 else { return [] }
        var stages: [SlideStage] = []
        var overs: [MusicTimeStamp] = []
        var fills: [Bool] = []
        var carries: [Double?] = []
        for (k, raw) in rawParts.enumerated() {
            var body = raw
            if k > 0 {
                if connectors[k - 1] == "^" {
                    let (carry, rest) = legatoSpec(raw)
                    body = rest
                    overs.append(0)
                    fills.append(false)
                    carries.append(carry)
                } else {
                    let (rest, over, fill) = slideSpec(raw)
                    body = rest
                    overs.append(over)
                    fills.append(fill)
                    carries.append(nil)
                }
            }
            guard let stage = slideStage(body) else { return [] }
            stages.append(stage)
        }
        let transitions = stages.count - 1
        let stageSpan = slotDuration / Double(transitions)
        let voiceCount = stages.map { $0.pitches.count }.max() ?? 0
        var result: [Note] = []
        for v in 0..<voiceCount {
            func voice(_ k: Int) -> (pitch: Pitch, degree: ScaleDegree?) {
                let stage = stages[k]
                let i = min(v, stage.pitches.count - 1)
                return (stage.pitches[i], stage.degrees[i])
            }
            let last = voice(transitions)
            var note = Note(pitch: last.pitch, velocity: 100, startTime: startTime, duration: slotDuration)
            note.degree = last.degree
            var steps: [SlideStep] = []
            for k in 0..<transitions {
                let over = fills[k] ? stageSpan : overs[k]
                let stage = voice(k)
                steps.append(SlideStep(from: stage.pitch, at: stageSpan * Double(k), over: over,
                                       carry: carries[k], degree: stage.degree))
            }
            note.slides = steps
            result.append(note)
        }
        return result
    }

    private static func splitTopLevelConnectors(_ s: String) -> (parts: [String], connectors: [Character]) {
        var parts: [String] = []
        var connectors: [Character] = []
        var current = ""
        var depth = 0
        for ch in s {
            if ch == "[" || ch == "(" { depth += 1; current.append(ch) }
            else if ch == "]" || ch == ")" { depth = max(0, depth - 1); current.append(ch) }
            else if (ch == ">" || ch == "^") && depth == 0 { parts.append(current); connectors.append(ch); current = "" }
            else { current.append(ch) }
        }
        parts.append(current)
        return (parts, connectors)
    }

    static let defaultLegatoCarry = 0.9

    private static func legatoSpec(_ payload: String) -> (carry: Double, rest: String) {
        if namesDegree(payload) { return (defaultLegatoCarry, payload) }
        if let (value, rest) = parseLeadingDouble(payload) {
            return (min(max(value, 0), 1), rest)
        }
        return (defaultLegatoCarry, payload)
    }

    private static func tokenizeExpression(_ expression: String) -> [(token: String, offset: Int)] {
        var tokens: [(token: String, offset: Int)] = []
        var current = ""
        var currentStart = 0
        var inBracket = false
        var inParen = false
        var braceDepth = 0
        var groupJustClosed = false
        var idx = -1
        var pendingRestIdx: Int? = nil

        func endsWithSlideConnector(_ s: String) -> Bool {
            guard let gt = s.lastIndex(where: { $0 == ">" || $0 == "^" }) else { return false }
            var spec = s[s.index(after: gt)...]
            if spec.first == "=" {
                spec = spec.dropFirst()
            } else {
                while let c = spec.first, c.isNumber || c == "." { spec = spec.dropFirst() }
            }
            if let c = spec.first, c == "+" || c == "-" {
                spec = spec.dropFirst()
                while let c = spec.first, c.isNumber { spec = spec.dropFirst() }
            }
            return spec.isEmpty
        }

        func appendToken(_ token: String, _ offset: Int) {
            if let restIdx = pendingRestIdx {
                let isExplicitRest = { (t: String?) in t == "R" || t == "r" || t == "_" }
                if !token.hasPrefix("-") && !token.hasPrefix("+") && !token.hasPrefix(">") && !token.hasPrefix("^")
                    && !isExplicitRest(token) && !tokens.isEmpty && !isExplicitRest(tokens.last?.token) {
                    tokens.append(("R", restIdx))
                }
                pendingRestIdx = nil
            }
            tokens.append((token, offset))
        }

        for char in expression {
            idx += 1
            if groupJustClosed {
                groupJustClosed = false
                if char == ">" || char == "^" {
                    current += String(char)
                    continue
                }
                appendToken(current, currentStart)
                current = ""
            }
            if braceDepth > 0 {
                current += String(char)
                if char == "{" { braceDepth += 1 }
                else if char == "}" {
                    braceDepth -= 1
                    if braceDepth == 0 {
                        appendToken(current, currentStart)
                        current = ""
                    }
                }
                continue
            }
            if char == "{" && !inBracket && !inParen {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { appendToken(trimmed, currentStart) }
                currentStart = idx
                current = "{"
                braceDepth = 1
                continue
            }
            if char == "[" && !inParen {
                if endsWithSlideConnector(current) {
                    current += "["
                    inBracket = true
                    continue
                }
                let (prefix, rest) = splitArpeggioPrefix(current)
                let trimmedRest = rest.trimmingCharacters(in: .whitespaces)
                if !trimmedRest.isEmpty {
                    var partOffset = currentStart
                    for part in trimmedRest.split(separator: " ") {
                        appendToken(String(part), partOffset)
                        partOffset += part.count + 1
                    }
                }
                currentStart = idx - prefix.count
                current = prefix + "["
                inBracket = true
            } else if char == "]" && inBracket {
                current += "]"
                inBracket = false
                groupJustClosed = true
            } else if char == "(" && !inBracket {
                if endsWithSlideConnector(current) {
                    current += "("
                    inParen = true
                    continue
                }
                let (prefix, rest) = splitArpeggioPrefix(current)
                let trimmedRest = rest.trimmingCharacters(in: .whitespaces)
                if !trimmedRest.isEmpty {
                    var partOffset = currentStart
                    for part in trimmedRest.split(separator: " ") {
                        appendToken(String(part), partOffset)
                        partOffset += part.count + 1
                    }
                }
                currentStart = idx - prefix.count
                current = prefix + "("
                inParen = true
            } else if char == ")" && inParen {
                current += ")"
                appendToken(current, currentStart)
                current = ""
                inParen = false
            } else if char == " " && !inBracket && !inParen {
                if !current.isEmpty {
                    appendToken(current, currentStart)
                    current = ""
                }
                if pendingRestIdx == nil { pendingRestIdx = idx }
            } else {
                if current.isEmpty { currentStart = idx }
                current += String(char)
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { appendToken(tail, currentStart) }
        if let restIdx = pendingRestIdx, !tokens.isEmpty,
           let last = tokens.last?.token, last != "R", last != "r", last != "_" {
            tokens.append(("R", restIdx))
        }
        return tokens
    }

    private enum ArpeggioSpread {
        case tight
        case fill
        case over(MusicTimeStamp)
    }

    private static func parseLeadingDouble(_ s: String) -> (Double, String)? {
        var i = s.startIndex
        guard i != s.endIndex else { return nil }
        if s[i] == "." {
            i = s.index(after: i)
            guard i != s.endIndex && s[i].isNumber else { return nil }
        } else if s[i].isNumber {
        } else {
            return nil
        }
        while i != s.endIndex && (s[i].isNumber || s[i] == ".") { i = s.index(after: i) }
        guard let value = Double(String(s[s.startIndex..<i])) else { return nil }
        return (value, String(s[i...]))
    }

    private static func parseTrailingSpread(_ s: String) -> (String, ArpeggioPattern, ArpeggioSpread)? {
        var i = s.endIndex
        while i > s.startIndex {
            let prev = s.index(before: i)
            if s[prev].isNumber || s[prev] == "." { i = prev } else { break }
        }
        guard i < s.endIndex else { return nil }
        let numStr = String(s[i...])
        guard let value = Double(numStr) else { return nil }
        let before = String(s[..<i])
        if before.hasSuffix("~~") { return (String(before.dropLast(2)), .down,        .over(value)) }
        if before.hasSuffix("~*") { return (String(before.dropLast(2)), .alternating, .over(value)) }
        if before.hasSuffix("~")  { return (String(before.dropLast(1)), .up,          .over(value)) }
        if before.hasSuffix("?")  { return (String(before.dropLast(1)), .random,      .over(value)) }
        return nil
    }

    private static func parseArpeggioSpec(_ token: String) -> (String, ArpeggioPattern?, ArpeggioSpread) {
        if token.hasPrefix("~~=") { return (String(token.dropFirst(3)), .down,        .fill) }
        if token.hasPrefix("~*=") { return (String(token.dropFirst(3)), .alternating, .fill) }
        if token.hasPrefix("~=")  { return (String(token.dropFirst(2)), .up,          .fill) }
        if token.hasPrefix("?=")  { return (String(token.dropFirst(2)), .random,      .fill) }

        func numericSpread(_ pattern: ArpeggioPattern, after prefix: String) -> (String, ArpeggioPattern?, ArpeggioSpread)? {
            guard token.hasPrefix(prefix) else { return nil }
            let rest = String(token.dropFirst(prefix.count))
            guard let (dur, chord) = parseLeadingDouble(rest) else { return nil }
            return (chord, pattern, .over(dur))
        }
        if let r = numericSpread(.down,        after: "~~") { return r }
        if let r = numericSpread(.alternating, after: "~*") { return r }
        if let r = numericSpread(.up,          after: "~")  { return r }
        if let r = numericSpread(.random,      after: "?")  { return r }

        if token.hasPrefix("~~") { return (String(token.dropFirst(2)), .down,        .tight) }
        if token.hasPrefix("~*") { return (String(token.dropFirst(2)), .alternating, .tight) }
        if token.hasPrefix("~")  { return (String(token.dropFirst(1)), .up,          .tight) }
        if token.hasPrefix("?")  { return (String(token.dropFirst(1)), .random,      .tight) }

        if token.hasSuffix("~~=") { return (String(token.dropLast(3)), .down,        .fill) }
        if token.hasSuffix("~*=") { return (String(token.dropLast(3)), .alternating, .fill) }
        if token.hasSuffix("~=")  { return (String(token.dropLast(2)), .up,          .fill) }

        if let (chord, pattern, spread) = parseTrailingSpread(token) { return (chord, pattern, spread) }

        if token.hasSuffix("~~") { return (String(token.dropLast(2)), .down,        .tight) }
        if token.hasSuffix("~*") { return (String(token.dropLast(2)), .alternating, .tight) }
        if token.hasSuffix("~")  { return (String(token.dropLast(1)), .up,          .tight) }
        if token.hasSuffix("?")  { return (String(token.dropLast(1)), .random,      .tight) }
        return (token, nil, .tight)
    }

    private static func applyStackArpeggio(_ notes: inout [Note], pattern: ArpeggioPattern,
                                           spread: ArpeggioSpread, slotDuration: MusicTimeStamp,
                                           tokenOffset: Int) {
        let count = notes.count
        guard count > 1 else { return }
        let order: [Int]
        switch pattern {
        case .down:        order = Array((0..<count).reversed())
        case .random:
            let salt = Dice.salt([UInt64(bitPattern: Int64(tokenOffset))]
                                 + notes.map { UInt64($0.pitch ?? 0) })
            order = Dice.shuffled(Array(0..<count), salt: salt)
        case .alternating: order = count >= 3 ? [0, count - 1] + Array(1..<(count - 1)) : Array(0..<count)
        default:           order = Array(0..<count)
        }
        let delay: MusicTimeStamp
        switch spread {
        case .fill:        delay = slotDuration / MusicTimeStamp(count)
        case .over(let d): delay = d / MusicTimeStamp(count)
        case .tight:       delay = 0.05
        }
        for (rank, idx) in order.enumerated() {
            notes[idx].startTime += MusicTimeStamp(rank) * delay
        }
    }

    private static func splitArpeggioPrefix(_ s: String) -> (String, String) {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let body = trimmed.hasPrefix("+") ? String(trimmed.dropFirst()) : trimmed
        let (clean, pattern, _) = parseArpeggioSpec(body)
        if clean.isEmpty && (pattern != nil || body.isEmpty) && !trimmed.isEmpty {
            return (trimmed, "")
        }
        return ("", s)
    }

    static func parseDegreeToken(_ s: String) -> ScaleDegree? {
        guard let (degree, rest) = splitDegreePrefix(s) else { return nil }
        if rest.isEmpty { return degree }
        guard let trailing = trailingMarks(rest) else { return nil }
        return ScaleDegree(degree: degree.degree,
                           octave: degree.octave + trailing.octave,
                           alteration: degree.alteration + trailing.alteration)
    }

    private static func trailingMarks(_ s: String) -> (octave: Int, alteration: Int)? {
        var octave = 0
        var alteration = 0
        for c in s {
            switch c {
            case "#": alteration += 1
            case "b": alteration -= 1
            case "'": octave += 1
            case ",": octave -= 1
            default:  return nil
            }
        }
        return (octave, alteration)
    }

    static func splitDegreePrefix(_ s: String) -> (degree: ScaleDegree, rest: String)? {
        guard !s.isEmpty else { return nil }
        var i = s.startIndex
        var alteration = 0
        while i < s.endIndex, s[i] == "#" || s[i] == "b" {
            alteration += s[i] == "#" ? 1 : -1
            i = s.index(after: i)
        }
        var digits = ""
        while i < s.endIndex, s[i].isNumber {
            digits.append(s[i])
            i = s.index(after: i)
        }
        guard let degree = Int(digits), degree > 0 else { return nil }
        var octave = 0
        while i < s.endIndex, s[i] == "'" || s[i] == "," {
            octave += s[i] == "'" ? 1 : -1
            i = s.index(after: i)
        }
        return (ScaleDegree(degree: degree, octave: octave, alteration: alteration), String(s[i...]))
    }

    static func parseDegreeChord(_ s: String) -> (root: ScaleDegree, quality: ChordQuality)? {
        guard let (root, rest) = splitDegreePrefix(s), !rest.isEmpty else { return nil }
        if let quality = ChordQuality(from: rest) { return (root, quality) }
        var alteration = 0
        var i = rest.startIndex
        while i < rest.endIndex, rest[i] == "#" || rest[i] == "b" {
            alteration += rest[i] == "#" ? 1 : -1
            i = rest.index(after: i)
        }
        guard i != rest.startIndex, let quality = ChordQuality(from: String(rest[i...])) else { return nil }
        return (ScaleDegree(degree: root.degree, octave: root.octave,
                            alteration: root.alteration + alteration), quality)
    }

    static func degreeChordTones(root: ScaleDegree, quality: ChordQuality,
                                 extensions: [String] = []) -> [ScaleDegree] {
        var intervals = quality.intervals
        for token in extensions {
            guard let semitones = Chord.semitones(forExtension: token, baseQuality: quality) else { continue }
            if token == "b5" || token == "#5" || token == "s5" { intervals.removeAll { $0 == 7 } }
            if !intervals.contains(semitones) { intervals.append(semitones) }
        }
        return intervals.map {
            ScaleDegree(degree: root.degree, octave: root.octave, alteration: root.alteration + Int($0))
        }
    }

    static func namesDegree(_ s: String) -> Bool {
        parseDegreeToken(s) != nil || parseDegreeChord(s) != nil
    }

    static func degreeNote(_ written: ScaleDegree, startTime: MusicTimeStamp,
                           duration: MusicTimeStamp = 1.0, velocity: UInt32 = 100) -> Note {
        var note = Note(pitch: Scale.unkeyed.pitch(written), velocity: velocity,
                        startTime: startTime, duration: duration)
        note.degree = written
        return note
    }

    private static func lookupPitch(_ s: String) -> Pitch? {
        if s.hasPrefix("'") { return pitchForNoteName(String(s.dropFirst())) }
        return pitchForNoteName(s)
    }

    private static func forcedPitch(_ s: String) -> Pitch? {
        guard s.hasPrefix("'") else { return nil }
        return pitchForNoteName(String(s.dropFirst()))
    }

    private static func warnArpeggioOnRunGroup(_ pattern: ArpeggioPattern?, token: String,
                                               tokenOffset: Int, tokenLength: Int,
                                               warnings: inout [ParseWarning]) {
        guard pattern != nil else { return }
        warnings.append(ParseWarning(
            token: token, offset: tokenOffset, length: tokenLength,
            message: "an arpeggio mark on a run group has no effect — mark the chords inside it"))
    }

    private static func noteSetMode(_ pattern: ArpeggioPattern?) -> NoteSetMode {
        switch pattern {
        case .down: return .down
        case .random: return .random
        case .alternating: return .alternating
        default: return .up
        }
    }

    private static func noteSetMembers(_ cleanToken: String) -> [(text: String, start: Int)] {
        let inner = String(cleanToken.dropFirst().dropLast())
        var members: [(text: String, start: Int)] = []
        var element = ""
        var elementStart = 1
        var depth = 0
        var pos = 1
        func flush() {
            if !element.isEmpty { members.append((element, elementStart)) }
            element = ""
        }
        for ch in inner {
            switch ch {
            case "(", "[", "{":
                if element.isEmpty { elementStart = pos }
                depth += 1
                element.append(ch)
            case ")", "]", "}":
                if element.isEmpty { elementStart = pos }
                depth -= 1
                element.append(ch)
            case " " where depth <= 0:
                flush()
            default:
                if element.isEmpty { elementStart = pos }
                element.append(ch)
            }
            pos += 1
        }
        flush()
        return members
    }

    private static func parseNoteSetGroup(_ cleanToken: String, token: String, tokenOffset: Int)
        -> (pitches: [Pitch], degrees: [ScaleDegree?], offsets: [Int]?, lengths: [Int]?) {
        let base: Int? = token.hasSuffix(cleanToken) ? tokenOffset + (token.count - cleanToken.count) : nil
        var pitches: [Pitch] = []
        var degrees: [ScaleDegree?] = []
        var offsets: [Int] = []
        var lengths: [Int] = []
        for (element, elementStart) in noteSetMembers(cleanToken) {
            let resolved: (pitch: Pitch, degree: ScaleDegree?)?
            if let pitch = lookupPitch(element) {
                resolved = (pitch, nil)
            } else if let written = parseDegreeToken(element) {
                resolved = (Scale.unkeyed.pitch(written), written)
            } else {
                resolved = nil
            }
            if let resolved {
                pitches.append(resolved.pitch)
                degrees.append(resolved.degree)
                offsets.append((base ?? 0) + elementStart)
                lengths.append(element.count)
            }
        }
        guard base != nil else { return (pitches, degrees, nil, nil) }
        return (pitches, degrees, offsets, lengths)
    }

    private static func noteSetNotes(_ cleanToken: String, token: String, tokenOffset: Int,
                                     tokenLength: Int, mode: NoteSetMode,
                                     startTime: MusicTimeStamp, duration: MusicTimeStamp,
                                     warnings: inout [ParseWarning]) -> [Note] {
        let members = noteSetMembers(cleanToken)
        let simple = members.allSatisfy { lookupPitch($0.text) != nil || parseDegreeToken($0.text) != nil }
        if simple {
            let (pitches, variantDegrees, variantOffsets, variantLengths) =
                parseNoteSetGroup(cleanToken, token: token, tokenOffset: tokenOffset)
            guard !pitches.isEmpty else { return [] }
            var note = Note(pitch: pitches[0], velocity: 100, startTime: startTime, duration: duration)
            note.pitchVariants = pitches
            note.variantMode = mode
            if variantDegrees.contains(where: { $0 != nil }) {
                note.variantDegrees = variantDegrees
                note.degree = variantDegrees.first ?? nil
            }
            note.sourceOffset = tokenOffset
            note.sourceLength = tokenLength
            note.variantSourceOffsets = variantOffsets
            note.variantSourceLengths = variantLengths
            return [note]
        }

        let factor = duration / barDuration
        var resolved: [[Note]] = []
        for (text, start) in members {
            var memberWarnings: [ParseWarning] = []
            let parsed = parseBarNotation("|" + text + "|", warnings: &memberWarnings)
            let sounding = parsed.filter { $0.pitch != nil }
            guard !sounding.isEmpty else {
                warnings.append(ParseWarning(
                    token: text, offset: tokenOffset + start, length: text.count,
                    message: "\"\(text)\" is not a note or chord — dropped from the set"))
                continue
            }
            warnings.append(contentsOf: memberWarnings.map { shifted($0, by: tokenOffset + start - 1) })
            resolved.append(sounding)
        }
        guard resolved.count > 1 else {
            return (resolved.first ?? []).map { note in
                var n = note.scalingSlides(from: note.duration, to: note.duration * factor)
                n.duration = note.duration * factor
                n.startTime = startTime + note.startTime * factor
                n.sourceOffset = tokenOffset
                n.sourceLength = tokenLength
                n.variantSourceOffsets = nil
                n.variantSourceLengths = nil
                n.slideSourceOffsets = nil
                return n
            }
        }
        return resolved.enumerated().flatMap { member, notes in
            notes.map { note in
                var n = note.scalingSlides(from: note.duration, to: note.duration * factor)
                n.duration = note.duration * factor
                n.startTime = startTime + note.startTime * factor
                n.sourceOffset = tokenOffset
                n.sourceLength = tokenLength
                n.variantSourceOffsets = nil
                n.variantSourceLengths = nil
                n.slideSourceOffsets = nil
                n.dice = .noteSet(member: member, of: resolved.count, mode: mode)
                return n
            }
        }
    }

    // MARK: - Run groups ("{ … }")

    private static func runGroupNotes(_ cleanToken: String, startTime: MusicTimeStamp,
                                      slotDuration: MusicTimeStamp, tokenOffset: Int,
                                      warnings: inout [ParseWarning]) -> [Note] {
        let inner = String(cleanToken.dropFirst().dropLast())
        guard !inner.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        var innerWarnings: [ParseWarning] = []
        let parsed = parseBarNotation("|" + inner + "|", warnings: &innerWarnings)
        guard !parsed.isEmpty else {
            warnings.append(contentsOf: innerWarnings.map { shifted($0, by: tokenOffset) })
            return []
        }
        let bars = max(1, inner.split(separator: "|").filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }.count)
        let factor = slotDuration / (barDuration * MusicTimeStamp(bars))
        warnings.append(contentsOf: innerWarnings.map { shifted($0, by: tokenOffset) })
        return parsed.map { note in
            var n = note.scalingSlides(from: note.duration, to: note.duration * factor)
            n.duration = note.duration * factor
            n.startTime = startTime + note.startTime * factor
            n.sourceOffset = note.sourceOffset.map { $0 + tokenOffset }
            n.variantSourceOffsets = note.variantSourceOffsets.map { $0.map { $0 + tokenOffset } }
            n.slideSourceOffsets = note.slideSourceOffsets.map { $0.map { $0 + tokenOffset } }
            return n
        }
    }

    private static func shifted(_ warning: ParseWarning, by offset: Int) -> ParseWarning {
        ParseWarning(token: warning.token, offset: warning.offset + offset,
                     length: warning.length, message: warning.message)
    }

    private static func parseNamedChord(_ token: String, duration: MusicTimeStamp = 1.0) -> Chord? {
        guard !token.isEmpty else { return nil }
        let chars: [Character] = Array(token)
        guard "ABCDEFGabcdefg".contains(chars[0]) else { return nil }
        var rootLen = 1
        while chars.count > rootLen && (chars[rootLen] == "#" || chars[rootLen] == "b") { rootLen += 1 }
        guard chars.count > rootLen else { return nil }
        let root = String(chars.prefix(rootLen))
        let qualitySuffix = String(chars.dropFirst(rootLen))
        guard let quality = ChordQuality(from: qualitySuffix) else { return nil }
        return Chord(root, quality, duration)
    }

    public static func barTokens(_ bar: String) -> [String] {
        tokenizeBar(bar, barOffset: 0).map(\.token)
    }

    private static func tokenizeBar(_ bar: String, barOffset: Int) -> [(token: String, offset: Int)] {
        var tokens: [(token: String, offset: Int)] = []
        var current = ""
        var currentStart = 0
        var depth = 0
        var idx = -1

        for char in bar {
            idx += 1
            if char == "(" || char == "[" || char == "{" {
                if current.isEmpty { currentStart = idx }
                depth += 1
                current += String(char)
            } else if char == ")" || char == "]" || char == "}" {
                if current.isEmpty { currentStart = idx }
                depth -= 1
                current += String(char)
            } else if char == " " && depth == 0 {
                if !current.isEmpty { tokens.append((current, barOffset + currentStart)); current = "" }
            } else {
                if current.isEmpty { currentStart = idx }
                current += String(char)
            }
        }
        if !current.isEmpty { tokens.append((current, barOffset + currentStart)) }
        return tokens.filter { !$0.token.isEmpty }
    }

    private static func parseBarNotation(_ expression: String, warnings: inout [ParseWarning]) -> [Note] {
        var bars: [(text: String, offset: Int)] = []
        var segment = ""
        var segmentStart = 0
        var idx = -1
        func flushSegment() {
            if !segment.isEmpty {
                let leading = segment.prefix(while: { $0.isWhitespace }).count
                bars.append((segment.trimmingCharacters(in: .whitespaces), segmentStart + leading))
            }
            segment = ""
        }
        for char in expression {
            idx += 1
            if char == "|" {
                flushSegment()
                segmentStart = idx + 1
            } else {
                segment += String(char)
            }
        }
        flushSegment()

        var allNotes: [Note] = []
        var currentTime: MusicTimeStamp = 0
        let barDur = barDuration
        var heldIndices: [Int] = []
        var heldChord: (root: NoteNotation, quality: ChordQuality)? = nil
        var lastSounded: (pitch: Pitch, degree: ScaleDegree?)? = nil

        for (bar, barOffset) in bars {
            let tokens = tokenizeBar(bar, barOffset: barOffset)
            guard !tokens.isEmpty else {
                allNotes.append(Note(pitch: nil, velocity: 0, startTime: currentTime, duration: barDur))
                currentTime += barDur
                heldIndices = []
                heldChord = nil
                continue
            }
            let chordDuration = barDur / Double(tokens.count)
            var barTime = currentTime

            for (rawToken, tokenOffset) in tokens {
                let (token, tokenFall) = parseFallSuffix(rawToken)
                let tokenLength = rawToken.count

                let slotStart = barTime
                let slotBase = allNotes.count
                defer {
                    if allNotes.count == slotBase && heldIndices.isEmpty {
                        allNotes.append(Note(pitch: nil, velocity: 0,
                                             startTime: slotStart, duration: chordDuration))
                    }
                }

                if token == "-" {
                    let slotEnd = barTime + chordDuration
                    for i in heldIndices {
                        allNotes[i].duration = max(allNotes[i].duration, slotEnd - allNotes[i].startTime)
                    }
                    if let tokenFall { attachFall(tokenFall, to: &allNotes, indices: heldIndices) }
                    barTime += chordDuration
                    continue
                }
                if token.hasPrefix("+") {
                    let slotEnd = barTime + chordDuration
                    for i in heldIndices {
                        allNotes[i].duration = max(allNotes[i].duration, slotEnd - allNotes[i].startTime)
                    }
                    let heldPitches = Set(heldIndices.compactMap { allNotes[$0].pitch })
                    let (added, chordContext) = additiveNotes(String(token.dropFirst()), heldChord: heldChord,
                                                              heldPitches: heldPitches, startTime: barTime, duration: chordDuration)
                    let base = allNotes.count
                    allNotes.append(contentsOf: stampedToken(added, offset: tokenOffset, length: tokenLength))
                    heldIndices.append(contentsOf: base..<allNotes.count)
                    if let chordContext { heldChord = chordContext }
                    if let tokenFall { attachFall(tokenFall, to: &allNotes, indices: base..<allNotes.count) }
                    if let i = (base..<allNotes.count).last(where: { allNotes[$0].pitch != nil }) { lastSounded = (allNotes[i].pitch!, allNotes[i].degree) }
                    barTime += chordDuration
                    continue
                }
                if token.hasPrefix(">") || token.hasPrefix("^") {
                    let (newHeld, chordContext) = slideHeldNotes(&allNotes, heldIndices: heldIndices,
                                                                 payload: String(token.dropFirst()),
                                                                 slotStart: barTime, slotDuration: chordDuration,
                                                                 tokenOffset: tokenOffset, tokenLength: tokenLength,
                                                                 lastSounded: lastSounded,
                                                                 legato: token.hasPrefix("^"),
                                                                 warnings: &warnings)
                    heldIndices = newHeld
                    heldChord = chordContext
                    if let tokenFall { attachFall(tokenFall, to: &allNotes, indices: newHeld) }
                    if let i = newHeld.last(where: { allNotes[$0].pitch != nil }) { lastSounded = (allNotes[i].pitch!, allNotes[i].degree) }
                    barTime += chordDuration
                    continue
                }

                let tokenBase = allNotes.count
                heldChord = nil

                let (cleanToken, arpeggioPattern, arpeggioSpread) = parseArpeggioSpec(token)
                func warnDropped() {
                    warnings.append(ParseWarning(token: rawToken, offset: tokenOffset, length: tokenLength,
                                                 message: "Unrecognized token \"\(rawToken)\" — slot left as a rest"))
                }
                func appendCompactRun() -> Bool {
                    guard cleanToken.range(of: "^[A-Ga-g#b0-9R_>=.^-]+$", options: .regularExpression) != nil else { return false }
                    let base = token.hasSuffix(cleanToken) ? tokenOffset + (token.count - cleanToken.count) : tokenOffset
                    let runNotes = parseCompactNotes(cleanToken, tokenOffset: base)
                    guard let runLength = runNotes.map({ $0.startTime + $0.duration }).max(), runLength > 0 else { return false }
                    let factor = chordDuration / runLength
                    for note in runNotes {
                        var n = note.scalingSlides(from: note.duration, to: note.duration * factor)
                        n.duration = note.duration * factor
                        n.startTime = barTime + note.startTime * factor
                        allNotes.append(n)
                    }
                    return true
                }
                if cleanToken.uppercased() == "R" || cleanToken == "_" {
                } else if cleanToken.hasPrefix("(") && cleanToken.hasSuffix(")") && !hasTopLevelSlide(cleanToken) {
                    let set = noteSetNotes(cleanToken, token: token, tokenOffset: tokenOffset,
                                           tokenLength: tokenLength, mode: noteSetMode(arpeggioPattern),
                                           startTime: barTime, duration: chordDuration, warnings: &warnings)
                    if set.isEmpty { warnDropped() }
                    allNotes.append(contentsOf: set)
                } else if cleanToken.hasPrefix("[") && cleanToken.hasSuffix("]") && !hasTopLevelSlide(cleanToken) {
                    let inner = String(cleanToken.dropFirst().dropLast())
                    let parts = inner.split(separator: " ").map(String.init)
                    var chordNotes: [Note]
                    if !parts.isEmpty, parts.allSatisfy({ parseDegreeToken($0) != nil }) {
                        chordNotes = parts.compactMap(parseDegreeToken).map {
                            degreeNote($0, startTime: barTime, duration: chordDuration)
                        }
                        if let pattern = arpeggioPattern {
                            applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: chordDuration, tokenOffset: tokenOffset)
                        }
                    } else if let first = parts.first, let spec = parseDegreeChord(first) {
                        let tones = degreeChordTones(root: spec.root, quality: spec.quality,
                                                     extensions: Array(parts.dropFirst()))
                        chordNotes = tones.map { degreeNote($0, startTime: barTime, duration: chordDuration) }
                        chordNotes += parts.dropFirst().compactMap(forcedPitch).map {
                            Note(pitch: $0, velocity: 100, startTime: barTime, duration: chordDuration)
                        }
                        if let pattern = arpeggioPattern {
                            applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: chordDuration, tokenOffset: tokenOffset)
                        }
                    } else if let first = parts.first, let chord = parseNamedChord(first, duration: chordDuration) {
                        chord.addExtensions(Array(parts.dropFirst()))
                        for pitch in parts.dropFirst().compactMap(forcedPitch) {
                            chord.notes.append(Note(pitch: pitch, duration: chordDuration))
                        }
                        heldChord = (chord.root, chord.quality)
                        if let pattern = arpeggioPattern {
                            switch arpeggioSpread {
                            case .fill:        _ = chord.arpeggio(over: chordDuration, pattern: pattern)
                            case .over(let d): _ = chord.arpeggio(over: d,             pattern: pattern)
                            case .tight:       _ = chord.arpeggio(pattern)
                            }
                        }
                        chordNotes = chord.notes.map {
                            Note(pitch: $0.pitch, velocity: $0.velocity, startTime: barTime + $0.startTime, duration: $0.duration)
                        }
                    } else {
                        chordNotes = parts.compactMap(stackElement).map {
                            var note = Note(pitch: $0.pitch, velocity: 100, startTime: barTime, duration: chordDuration)
                            note.degree = $0.degree
                            return note
                        }
                        if let pattern = arpeggioPattern {
                            applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: chordDuration, tokenOffset: tokenOffset)
                        }
                    }
                    if chordNotes.isEmpty { warnDropped() }
                    allNotes.append(contentsOf: stampedToken(chordNotes, offset: tokenOffset, length: tokenLength))
                } else if cleanToken.hasPrefix("{") && cleanToken.hasSuffix("}") {
                    warnArpeggioOnRunGroup(arpeggioPattern, token: token, tokenOffset: tokenOffset,
                                           tokenLength: tokenLength, warnings: &warnings)
                    let run = runGroupNotes(cleanToken, startTime: barTime, slotDuration: chordDuration,
                                            tokenOffset: tokenOffset, warnings: &warnings)
                    if run.isEmpty { warnDropped() }
                    allNotes.append(contentsOf: run)
                } else if cleanToken.hasPrefix("'"), let pitch = pitchForNoteName(String(cleanToken.dropFirst())) {
                    var note = Note(pitch: pitch, velocity: 100, startTime: barTime, duration: chordDuration)
                    note.sourceOffset = tokenOffset
                    note.sourceLength = tokenLength
                    allNotes.append(note)
                } else if cleanToken.contains(">") || cleanToken.contains("^") {
                    let fused = parseSlideFusion(cleanToken, startTime: barTime, slotDuration: chordDuration)
                    if fused.isEmpty {
                        if !appendCompactRun() { warnDropped() }
                    } else {
                        allNotes.append(contentsOf: stampedToken(fused, offset: tokenOffset, length: tokenLength))
                    }
                } else if let written = parseDegreeToken(cleanToken) {
                    var note = degreeNote(written, startTime: barTime, duration: chordDuration)
                    note.sourceOffset = tokenOffset
                    note.sourceLength = tokenLength
                    allNotes.append(note)
                } else if let spec = parseDegreeChord(cleanToken) {
                    var chordNotes = degreeChordTones(root: spec.root, quality: spec.quality).map {
                        degreeNote($0, startTime: barTime, duration: chordDuration)
                    }
                    if let pattern = arpeggioPattern {
                        applyStackArpeggio(&chordNotes, pattern: pattern, spread: arpeggioSpread, slotDuration: chordDuration, tokenOffset: tokenOffset)
                    }
                    allNotes.append(contentsOf: stampedToken(chordNotes, offset: tokenOffset, length: tokenLength))
                } else if let chord = parseNamedChord(cleanToken, duration: chordDuration) {
                    heldChord = (chord.root, chord.quality)
                    if let pattern = arpeggioPattern {
                        switch arpeggioSpread {
                        case .fill:        _ = chord.arpeggio(over: chordDuration, pattern: pattern)
                        case .over(let d): _ = chord.arpeggio(over: d,             pattern: pattern)
                        case .tight:       _ = chord.arpeggio(pattern)
                        }
                    }
                    let positioned = chord.notes.map { note in
                        Note(pitch: note.pitch, velocity: note.velocity,
                             startTime: barTime + note.startTime, duration: note.duration)
                    }
                    allNotes.append(contentsOf: stampedToken(positioned, offset: tokenOffset, length: tokenLength))
                } else if let pitch = pitchForNoteName(cleanToken) {
                    var note = Note(pitch: pitch, velocity: 100, startTime: barTime, duration: chordDuration)
                    note.sourceOffset = tokenOffset
                    note.sourceLength = tokenLength
                    allNotes.append(note)
                } else if appendCompactRun() {
                } else {
                    warnDropped()
                }
                barTime += chordDuration

                if let tokenFall { attachFall(tokenFall, to: &allNotes, indices: tokenBase..<allNotes.count) }
                if let i = (tokenBase..<allNotes.count).last(where: { allNotes[$0].pitch != nil }) { lastSounded = (allNotes[i].pitch!, allNotes[i].degree) }

                heldIndices = (tokenBase..<allNotes.count).filter {
                    allNotes[$0].pitch != nil && allNotes[$0].startTime + allNotes[$0].duration + 1e-9 >= barTime
                }
            }

            currentTime += barDur
        }

        return allNotes
    }

    private static func parseCompactNotes(_ token: String, tokenOffset: Int? = nil) -> [Note] {
        var notes: [Note] = []
        var currentTime: MusicTimeStamp = 0
        var lastNoteIndex: Int? = nil
        var i = token.startIndex
        var charPos = 0
        var pendingSlide: (over: MusicTimeStamp, fill: Bool, carry: Double?)? = nil
        var slideOvers: [MusicTimeStamp] = []
        var slideFills: [Bool] = []

        func respaceSlides(_ idx: Int) {
            guard var steps = notes[idx].slides, !steps.isEmpty else { return }
            let stageSpan = notes[idx].duration / Double(steps.count)
            for j in 0..<steps.count {
                steps[j].at = stageSpan * Double(j)
                steps[j].over = steps[j].carry != nil ? 0 : (slideFills[j] ? stageSpan : slideOvers[j])
            }
            notes[idx].slides = steps
        }

        while i < token.endIndex {
            if token[i] == "-" {
                i = token.index(after: i)
                charPos += 1
                if let last = lastNoteIndex {
                    notes[last].duration += 1.0
                    respaceSlides(last)
                }
                currentTime += 1.0
                continue
            }
            if token[i] == ">" {
                i = token.index(after: i)
                charPos += 1
                var fill = false
                var over: MusicTimeStamp = 0
                if i < token.endIndex && token[i] == "=" {
                    fill = true
                    i = token.index(after: i)
                    charPos += 1
                } else {
                    var numStr = ""
                    while i < token.endIndex && (token[i].isNumber || token[i] == ".") {
                        numStr += String(token[i])
                        i = token.index(after: i)
                        charPos += 1
                    }
                    if let value = Double(numStr) { over = value }
                }
                pendingSlide = (over, fill, nil)
                continue
            }
            if token[i] == "^" {
                i = token.index(after: i)
                charPos += 1
                var carry = defaultLegatoCarry
                var numStr = ""
                while i < token.endIndex && (token[i].isNumber || token[i] == ".") {
                    numStr += String(token[i])
                    i = token.index(after: i)
                    charPos += 1
                }
                if let value = Double(numStr) { carry = min(max(value, 0), 1) }
                pendingSlide = (0, false, carry)
                continue
            }
            let noteStart = charPos
            var noteStr = String(token[i])
            i = token.index(after: i)
            charPos += 1
            while i < token.endIndex && (token[i] == "#" || token[i] == "b") {
                noteStr += String(token[i])
                i = token.index(after: i)
                charPos += 1
            }
            while i < token.endIndex && token[i].isNumber {
                noteStr += String(token[i])
                i = token.index(after: i)
                charPos += 1
            }
            if noteStr.uppercased() == "R" || noteStr == "_" {
                notes.append(Note(pitch: nil, velocity: 0, startTime: currentTime, duration: 1.0))
                lastNoteIndex = nil
                pendingSlide = nil
                currentTime += 1.0
            } else if let pitch = noteStr.pitch {
                if let slide = pendingSlide, let last = lastNoteIndex, let fromPitch = notes[last].pitch {
                    var steps = notes[last].slides ?? []
                    steps.append(SlideStep(from: fromPitch, at: 0, over: 0, carry: slide.carry))
                    notes[last].slides = steps
                    slideOvers.append(slide.over)
                    slideFills.append(slide.fill)
                    notes[last].pitch = pitch
                    if let base = tokenOffset, let start = notes[last].sourceOffset {
                        notes[last].sourceLength = base + noteStart + noteStr.count - start
                    }
                    respaceSlides(last)
                    pendingSlide = nil
                } else {
                    pendingSlide = nil
                    var note = Note(pitch: pitch, velocity: 100, startTime: currentTime, duration: 1.0)
                    if let base = tokenOffset {
                        note.sourceOffset = base + noteStart
                        note.sourceLength = noteStr.count
                    }
                    notes.append(note)
                    lastNoteIndex = notes.count - 1
                    slideOvers = []
                    slideFills = []
                    currentTime += 1.0
                }
            }
        }
        return notes
    }
}

@resultBuilder
public enum SessionBuilder {
    public static func buildBlock(_ tracks: Track...) -> Session {
        let session = Session {
            return tracks
        }
        return session
    }
}
