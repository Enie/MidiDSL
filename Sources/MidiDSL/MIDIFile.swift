import Foundation

/// A `Session` as a Standard MIDI File (format 1, 480 ticks per quarter): a conductor track
/// with the tempo and meter, then one track per `Track` on its own channel. Time is musical, so
/// the file is the same whatever the tempo.
///
/// A track's ``Instrument`` opens it: a program change (after a bank select, when the bank is
/// not 0) names the General MIDI sound, and a drum track is written on channel 10, where every
/// General MIDI player keeps its kit. The other tracks take the remaining channels in order.
///
/// Every pass is resolved the way a player hears it: note sets, dice, `.active(...)` gates,
/// shuffled sections, mutes, track and session volume. Slides become pitch-bend curves (a
/// note whose bend would clash with another on the channel is re-attacked instead), a
/// `.volume` curve becomes CC 11, and the track-wide curves their controllers: `.cutoff` CC 74,
/// `.resonance` CC 71, `.reverb` CC 91, `.cc(n)` CC n.
///
/// ```swift
/// let session = Session.build {
///     Session { Track("melody") { Section { "| 1 2 3 5 | 6 5 3 - |" } } }
///         .tempo(96)
/// }
/// try MIDIFile.write(session, to: URL(fileURLWithPath: "piece.mid"))
/// ```
///
/// Build the session with ``Session/build(_:)`` so its bars are read in its own meter.
///
/// ## Topics
///
/// ### Writing a file
///
/// - ``write(_:loops:to:)``
/// - ``data(for:loops:)``
public enum MIDIFile {

    @_documentation(visibility: internal)
    public static let ticksPerQuarter = 480
    private static let ticksPerWholeNote = 4 * ticksPerQuarter
    /// How finely a controller curve is stepped: a 96th of a whole note, about 20 ms at 120 bpm.
    /// Only the steps where the value changes are written.
    private static let controllerStepTicks = 20

    /// Writes the session to a MIDI file.
    ///
    /// - Parameters:
    ///   - session: The piece.
    ///   - loops: How many passes to write. `nil` writes the session's form once: as many
    ///     passes as ``Session/loops(_:)`` says, or as its arrangement needs.
    ///   - url: Where to write the file.
    /// - Throws: The error writing to `url` threw.
    public static func write(_ session: Session, loops: Int? = nil, to url: URL) throws {
        try data(for: session, loops: loops).write(to: url)
    }

    /// The session as the bytes of a MIDI file.
    ///
    /// - Parameters:
    ///   - session: The piece.
    ///   - loopCount: How many passes to write. `nil` writes the session's form once: as many
    ///     passes as ``Session/loops(_:)`` says, or as its arrangement needs.
    /// - Returns: The file's contents.
    public static func data(for session: Session, loops loopCount: Int? = nil) -> Data {
        let loopTicks = loopLengthTicks(for: session)
        let loops = loopTicks > 0 ? max(1, loopCount ?? session.effectiveLoopCount) : 1
        let tempo = session.tempo ?? Session.defaultTempo

        var data = Data()
        data.appendFourCC("MThd")
        data.appendUInt32(6)
        data.appendUInt16(1)
        data.appendUInt16(UInt16(session.tracks.count + 1))
        data.appendUInt16(UInt16(ticksPerQuarter))

        data.append(conductorChunk(for: session, endTick: loopTicks * loops))

        for (track, channel) in zip(session.tracks, channels(for: session.tracks)) {
            data.append(noteChunk(for: track, channel: channel, loops: loops,
                                  loopTicks: loopTicks, tempo: tempo,
                                  seed: session.diceSeedValue,
                                  masterVolume: session.volume ?? 1.0))
        }
        return data
    }

    static let drumChannel: UInt8 = 9

    /// Each track's channel: 10 (index 9) for drums, the others in order around it, wrapping
    /// after sixteen.
    static func channels(for tracks: [Track]) -> [UInt8] {
        var next: UInt8 = 0
        return tracks.map { track in
            if track.instrument?.percussion == true { return drumChannel }
            let channel = next
            next += 1
            if next == drumChannel { next += 1 }
            if next > 15 { next = 0 }
            return channel
        }
    }

    // MARK: - Musical time

    private static func barLength(_ signature: TimeSignature) -> Double {
        Double(signature.beatsPerBar) / Double(signature.noteValue)
    }

    /// One pass, in ticks: `Session.loopBars` if set, else the written material rounded up to whole bars.
    @_documentation(visibility: internal)
    public static func loopLengthTicks(for session: Session) -> Int {
        let bar = barLength(session.timeSignature ?? .fourFour)
        if let bars = session.loopBars {
            return ticks(Double(bars) * bar)
        }
        var lastNoteEnd: Double = 0
        for track in session.tracks {
            for section in track.sections {
                for note in section.notes where note.pitch != nil {
                    lastNoteEnd = max(lastNoteEnd, note.startTime + note.duration)
                }
            }
        }
        guard lastNoteEnd > 0 else { return 0 }
        let barsNeeded = ceil(lastNoteEnd / bar - 1e-9)
        return ticks(barsNeeded * bar)
    }

    private static func ticks(_ dslTime: Double) -> Int {
        Int((dslTime * 4.0 * Double(ticksPerQuarter)).rounded())
    }

    // MARK: - Chunks

    private static func conductorChunk(for session: Session, endTick: Int) -> Data {
        let signature = session.timeSignature ?? .fourFour
        let tempo = session.tempo ?? Session.defaultTempo

        var events = Data()
        events.appendVLQ(0)
        events.append(contentsOf: [0xFF, 0x58, 0x04,
                                   UInt8(clamping: signature.beatsPerBar),
                                   UInt8(clamping: Int(log2(Double(signature.noteValue)).rounded())),
                                   24, 8])
        let usPerQuarter = UInt32(60_000_000.0 / tempo)
        events.appendVLQ(0)
        events.append(contentsOf: [0xFF, 0x51, 0x03,
                                   UInt8((usPerQuarter >> 16) & 0xFF),
                                   UInt8((usPerQuarter >> 8) & 0xFF),
                                   UInt8(usPerQuarter & 0xFF)])
        events.appendVLQ(max(0, endTick))
        events.append(contentsOf: [0xFF, 0x2F, 0x00])

        return trackChunk(events)
    }

    // MARK: - Track event list (pure, inspectable pre-serialization)

    @_documentation(visibility: internal)
    public struct TrackEvent: Equatable {
        public enum Kind: Equatable {
            case noteOn(note: UInt8, velocity: UInt8)
            case noteOff(note: UInt8)
            case controller(number: UInt8, value: UInt8)
            case programChange(program: UInt8)
            case pitchBend(value: UInt16)
        }
        public let tick: Int
        public let kind: Kind

        public init(tick: Int, kind: Kind) {
            self.tick = tick
            self.kind = kind
        }
    }

    private struct RampBreakpoint: Equatable {
        let tick: Int
        let semitones: Float
    }

    private struct ExpressionBreakpoint: Equatable {
        let tick: Int
        let value: UInt8
    }

    private struct NoteOccurrence {
        let onTick: Int
        let offTick: Int
        let note: UInt8
        let velocity: UInt8
        let ramp: [RampBreakpoint]
        let expression: [ExpressionBreakpoint]
        let slides: [SlideStep]?
        let noteStartTime: Double
        let noteDuration: Double
        let loopOffset: Int
    }

    private static let bendStepsPerGlide = 24

    /// One track's events in tick order, before they are encoded: what the file says, in a
    /// form a test (or another writer) can read.
    @_documentation(visibility: internal)
    public static func trackEvents(for track: Track, loops: Int, loopTicks: Int, tempo: Double,
                                   seed: UInt64 = 0, masterVolume: Double = 1.0) -> [TrackEvent] {
        guard !track.isMuted else { return [] }
        let volume = (track.volume ?? 1.0) * masterVolume
        let secondsPerWhole = 240.0 / tempo

        let windows = track.sectionOrder == .shuffled ? SectionShuffle.windows(of: track.sections) : []

        var occurrences: [NoteOccurrence] = []
        var passStarts: [Int] = []
        for loopIndex in 0..<loops {
            passStarts.append(occurrences.count)
            if let activity = track.activity, !activity.isActive(loopIndex: loopIndex) { continue }
            let loopOffset = loopIndex * loopTicks
            let starts = windows.isEmpty || !SectionShuffle.isShuffled(track, loopIndex: loopIndex)
                ? [] : SectionShuffle.shuffledStarts(windows: windows, loopIndex: loopIndex)
            for (sectionIndex, section) in track.sections.enumerated() {
                if section.isMuted { continue }
                if let activity = section.activity, !activity.isActive(loopIndex: loopIndex) { continue }
                let slotShift = starts.isEmpty ? 0 : starts[sectionIndex] - windows[sectionIndex].start
                for note in section.notes {
                    if let activity = note.activity, !activity.isActive(loopIndex: loopIndex) { continue }
                    guard note.rolledOn(loopIndex: loopIndex, seed: seed) else { continue }
                    guard let pitch = note.resolvedPitch(loopIndex: loopIndex, seed: seed) else { continue }
                    let noteNumber = UInt8(min(pitch, 127))
                    let written = note.resolvedVelocity(loopIndex: loopIndex, seed: seed)
                    let velocity = max(1, UInt8(min(UInt32(Double(written) * volume), 127)))
                    let duration = note.resolvedDuration(loopIndex: loopIndex, seed: seed)
                    let startTime = note.startTime + slotShift
                    let onTick = loopOffset + ticks(startTime)
                    var offTick = max(onTick + 1, loopOffset + ticks(startTime + duration))
                    if loopTicks > 0 {
                        offTick = min(offTick, loopOffset + loopTicks)
                    }
                    guard offTick > onTick else { continue }

                    var ramp: [RampBreakpoint] = []
                    var expression: [ExpressionBreakpoint] = []
                    let bends = note.slides?.isEmpty == false || note.fall != nil
                    let fades = note.automation?.contains { $0.target == .volume } ?? false
                    if bends || fades {
                        let stepsInSeconds = (note.slides ?? []).map {
                            SlideStep(from: $0.from, at: $0.at * secondsPerWhole,
                                      over: $0.over == 0 ? 0 : $0.over * secondsPerWhole,
                                      carry: $0.carry)
                        }
                        let fallInSeconds = note.fall.map {
                            Fall(semitones: $0.semitones,
                                 over: $0.over == 0 ? 0 : $0.over * secondsPerWhole)
                        }
                        let curvesInSeconds = note.automation?.map { $0.scalingTimes(by: secondsPerWhole) }
                        let points = pitchRampPoints(slides: stepsInSeconds, fall: fallInSeconds,
                                                     duration: note.duration * secondsPerWhole,
                                                     finalPitch: UInt32(noteNumber),
                                                     automation: curvesInSeconds)
                        if bends {
                            ramp = points.map {
                                RampBreakpoint(tick: loopOffset + ticks(startTime + $0.time / secondsPerWhole),
                                               semitones: $0.semitones)
                            }
                        }
                        if fades {
                            expression = points.map {
                                ExpressionBreakpoint(
                                    tick: loopOffset + ticks(startTime + $0.time / secondsPerWhole),
                                    value: UInt8(max(0, min(127, ($0.amp * 127).rounded()))))
                            }
                        }
                    }
                    occurrences.append(NoteOccurrence(
                        onTick: onTick, offTick: offTick, note: noteNumber, velocity: velocity,
                        ramp: ramp, expression: expression, slides: note.slides,
                        noteStartTime: startTime, noteDuration: note.duration,
                        loopOffset: loopOffset))
                }
            }
        }

        passStarts.append(occurrences.count)
        func passBounds(containing i: Int) -> Range<Int> {
            guard loopTicks > 0 else { return occurrences.indices }
            var pass = 0
            while pass + 1 < passStarts.count && passStarts[pass + 1] <= i { pass += 1 }
            return passStarts[pass]..<passStarts[pass + 1]
        }

        func canUseBend(_ i: Int) -> Bool {
            let occ = occurrences[i]
            guard !occ.ramp.isEmpty else { return false }
            for j in passBounds(containing: i) where j != i {
                let other = occurrences[j]
                guard other.onTick < occ.offTick && occ.onTick < other.offTick else { continue }
                if other.onTick != occ.onTick || other.offTick != occ.offTick || other.ramp != occ.ramp {
                    return false
                }
            }
            return true
        }
        let bendUsers = Set(occurrences.indices.filter(canUseBend))

        let maxSpan = bendUsers.flatMap { occurrences[$0].ramp.map { abs($0.semitones) } }.max() ?? 0
        let bendRange = min(24, max(2, Int(maxSpan.rounded(.up))))

        var pending: [(tick: Int, priority: Int, seq: Int, kind: TrackEvent.Kind)] = []
        func emit(_ tick: Int, _ priority: Int, _ kind: TrackEvent.Kind) {
            pending.append((tick, priority, pending.count, kind))
        }

        if let instrument = track.instrument, let program = instrument.program {
            if instrument.bank != 0 {
                emit(0, 0, .controller(number: 0, value: UInt8((instrument.bank >> 7) & 0x7F)))
                emit(0, 0, .controller(number: 32, value: UInt8(instrument.bank & 0x7F)))
            }
            emit(0, 1, .programChange(program: UInt8(min(max(program, 0), 127))))
        }

        if !bendUsers.isEmpty {
            for (controller, value) in MIDIRamp.bendRangeRPN(range: UInt8(bendRange), closeRPN: false) {
                emit(0, 2, .controller(number: controller, value: value))
            }
        }

        var emittedClusters: [(on: Int, off: Int, ramp: [RampBreakpoint])] = []
        for (i, occ) in occurrences.enumerated() {
            if occ.ramp.isEmpty {
                emit(occ.onTick, 4, .noteOn(note: occ.note, velocity: occ.velocity))
                emit(occ.offTick, 0, .noteOff(note: occ.note))
            } else if bendUsers.contains(i) {
                emit(occ.onTick, 4, .noteOn(note: occ.note, velocity: occ.velocity))
                emit(occ.offTick, 0, .noteOff(note: occ.note))
                if emittedClusters.contains(where: { $0.on == occ.onTick && $0.off == occ.offTick && $0.ramp == occ.ramp }) {
                    continue
                }
                emittedClusters.append((occ.onTick, occ.offTick, occ.ramp))

                var lastTick = -1
                var lastValue = -1
                func emitBend(_ tick: Int, _ semitones: Float) {
                    let t = min(tick, occ.offTick - 1)
                    let value = MIDIRamp.bendValue(semitones: semitones, range: Float(bendRange))
                    if Int(value) == lastValue { return }
                    if t == lastTick { pending.removeLast() }
                    emit(t, 3, .pitchBend(value: value))
                    lastTick = t
                    lastValue = Int(value)
                }
                emitBend(occ.onTick, occ.ramp[0].semitones)
                for k in 1..<occ.ramp.count {
                    let a = occ.ramp[k - 1], b = occ.ramp[k]
                    if a.semitones == b.semitones || b.tick <= a.tick {
                        emitBend(b.tick, b.semitones)
                        continue
                    }
                    for s in 1...bendStepsPerGlide {
                        let f = Float(s) / Float(bendStepsPerGlide)
                        let t = a.tick + Int((Float(b.tick - a.tick) * f).rounded())
                        emitBend(t, a.semitones + (b.semitones - a.semitones) * f)
                    }
                }
                emit(occ.offTick, 1, .pitchBend(value: 8192))
            } else {
                for segment in reattackSegments(occ, loopTicks: loopTicks) {
                    emit(segment.onTick, 4, .noteOn(note: segment.note, velocity: occ.velocity))
                    emit(segment.offTick, 0, .noteOff(note: segment.note))
                }
            }
        }

        let automated = occurrences.indices
            .filter { !occurrences[$0].expression.isEmpty }
            .sorted { occurrences[$0].onTick < occurrences[$1].onTick }
        if !automated.isEmpty {
            var stream: [(tick: Int, value: UInt8)] = []
            for (n, i) in automated.enumerated() {
                let limit = n + 1 < automated.count ? occurrences[automated[n + 1]].onTick : Int.max
                let points = occurrences[i].expression
                for (k, point) in points.enumerated() where point.tick < limit {
                    stream.append((point.tick, point.value))
                    guard k + 1 < points.count else { continue }
                    let next = points[k + 1]
                    let steps = min(127, abs(Int(next.value) - Int(point.value)))
                    guard steps > 1, next.tick > point.tick else { continue }
                    for s in 1..<steps {
                        let f = Double(s) / Double(steps)
                        let tick = point.tick + Int((Double(next.tick - point.tick) * f).rounded())
                        guard tick < limit else { break }
                        let value = Double(point.value) + (Double(next.value) - Double(point.value)) * f
                        stream.append((tick, UInt8(max(0, min(127, value.rounded())))))
                    }
                }
            }
            for occ in occurrences where occ.expression.isEmpty {
                let covered = automated.contains {
                    occurrences[$0].onTick <= occ.onTick && occ.onTick < occurrences[$0].offTick
                }
                if !covered { stream.append((occ.onTick, MIDIRamp.expressionFull)) }
            }
            let lastOff = automated.map { occurrences[$0].offTick }.max() ?? 0
            stream.append((lastOff + 1, MIDIRamp.expressionFull))

            stream.sort { $0.tick < $1.tick }
            var lastValue = -1
            for step in stream where Int(step.value) != lastValue {
                emit(step.tick, 3, .controller(number: MIDIRamp.expressionController, value: step.value))
                lastValue = Int(step.value)
            }
        }

        for (controller, steps) in controllerLanes(for: track, loops: loops, loopTicks: loopTicks) {
            var lastValue = -1
            for step in steps where Int(step.value) != lastValue {
                emit(step.tick, 3, .controller(number: controller, value: step.value))
                lastValue = Int(step.value)
            }
        }

        pending.sort {
            ($0.tick, $0.priority, $0.seq) < ($1.tick, $1.priority, $1.seq)
        }
        return pending.map { TrackEvent(tick: $0.tick, kind: $0.kind) }
    }

    /// The track-wide curves a file can carry (cutoff, resonance, reverb, `.cc`), as controller
    /// values in tick order, one lane per controller. A section's curve counts from the section's
    /// start, wherever this pass's section order puts it, and is gated as its notes are.
    private static func controllerLanes(for track: Track, loops: Int,
                                        loopTicks: Int) -> [(UInt8, [(tick: Int, value: UInt8)])] {
        let windows = SectionShuffle.windows(of: track.sections)
        var lanes: [UInt8: [(tick: Int, value: UInt8)]] = [:]
        var order: [UInt8] = []
        for loopIndex in 0..<loops {
            if let activity = track.activity, !activity.isActive(loopIndex: loopIndex) { continue }
            let loopOffset = loopIndex * loopTicks
            let starts = SectionShuffle.isShuffled(track, loopIndex: loopIndex)
                ? SectionShuffle.shuffledStarts(windows: windows, loopIndex: loopIndex) : []
            for (sectionIndex, section) in track.sections.enumerated() {
                guard let curves = section.automation, !curves.isEmpty, !section.isMuted else { continue }
                if let activity = section.activity, !activity.isActive(loopIndex: loopIndex) { continue }
                let start = starts.isEmpty ? windows[sectionIndex].start : starts[sectionIndex]
                for curve in curves {
                    guard let controller = curve.target.midiController,
                          let first = curve.points.first, let last = curve.points.last else { continue }
                    if lanes[controller] == nil { order.append(controller) }
                    let firstTick = ticks(start + first.time), lastTick = ticks(start + last.time)
                    var tick = firstTick
                    while true {
                        let at = Double(tick - firstTick) / Double(ticksPerWholeNote) + first.time
                        var absolute = loopOffset + tick
                        if loopTicks > 0 { absolute = min(absolute, loopOffset + loopTicks - 1) }
                        lanes[controller, default: []].append(
                            (absolute, curve.target.midiValue(curve.value(at: min(at, last.time)))))
                        if tick >= lastTick { break }
                        tick = min(tick + controllerStepTicks, lastTick)
                    }
                }
            }
        }
        return order.map { controller in
            (controller, (lanes[controller] ?? []).enumerated()
                .sorted { ($0.element.tick, $0.offset) < ($1.element.tick, $1.offset) }
                .map(\.element))
        }
    }

    private static func reattackSegments(_ occ: NoteOccurrence,
                                         loopTicks: Int) -> [(onTick: Int, offTick: Int, note: UInt8)] {
        var stages: [(start: Double, end: Double, pitch: Pitch)] = []
        var prev = 0.0
        for step in occ.slides ?? [] {
            let boundary = min(step.at + step.over / 2, occ.noteDuration)
            if boundary > prev { stages.append((prev, boundary, step.from)) }
            prev = max(prev, boundary)
        }
        if occ.noteDuration > prev { stages.append((prev, occ.noteDuration, Pitch(occ.note))) }

        var segments: [(onTick: Int, offTick: Int, note: UInt8)] = []
        for stage in stages {
            let onTick = occ.loopOffset + ticks(occ.noteStartTime + stage.start)
            var offTick = max(onTick + 1, occ.loopOffset + ticks(occ.noteStartTime + stage.end))
            if loopTicks > 0 { offTick = min(offTick, occ.loopOffset + loopTicks) }
            guard offTick > onTick else { continue }
            segments.append((onTick, offTick, UInt8(min(stage.pitch, 127))))
        }
        return segments
    }

    private static func noteChunk(for track: Track, channel: UInt8, loops: Int,
                                  loopTicks: Int, tempo: Double, seed: UInt64,
                                  masterVolume: Double = 1.0) -> Data {
        var events = Data()
        events.appendVLQ(0)
        events.appendMeta(0x03, text: track.name)

        var lastTick = 0
        for event in trackEvents(for: track, loops: loops, loopTicks: loopTicks, tempo: tempo,
                                 seed: seed, masterVolume: masterVolume) {
            events.appendVLQ(event.tick - lastTick)
            lastTick = event.tick
            let ch = channel & 0x0F
            switch event.kind {
            case .noteOn(let note, let velocity):
                events.append(contentsOf: [0x90 | ch, note & 0x7F, velocity & 0x7F])
            case .noteOff(let note):
                events.append(contentsOf: [0x80 | ch, note & 0x7F, 0])
            case .controller(let number, let value):
                events.append(contentsOf: [0xB0 | ch, number & 0x7F, value & 0x7F])
            case .programChange(let program):
                events.append(contentsOf: [0xC0 | ch, program & 0x7F])
            case .pitchBend(let value):
                events.append(contentsOf: [0xE0 | ch, UInt8(value & 0x7F), UInt8((value >> 7) & 0x7F)])
            }
        }

        events.appendVLQ(0)
        events.append(contentsOf: [0xFF, 0x2F, 0x00])
        return trackChunk(events)
    }

    private static func trackChunk(_ events: Data) -> Data {
        var chunk = Data()
        chunk.appendFourCC("MTrk")
        chunk.appendUInt32(UInt32(events.count))
        chunk.append(events)
        return chunk
    }
}

// MARK: - SMF byte helpers

private extension Data {
    mutating func appendFourCC(_ code: String) {
        append(contentsOf: Array(code.utf8))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(contentsOf: [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF),
                            UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)])
    }

    mutating func appendUInt16(_ value: UInt16) {
        append(contentsOf: [UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)])
    }

    mutating func appendVLQ(_ value: Int) {
        var v = UInt32(Swift.max(0, value))
        var bytes: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            bytes.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        append(contentsOf: bytes.reversed())
    }

    mutating func appendMeta(_ type: UInt8, text: String) {
        let bytes = Array(text.utf8)
        append(contentsOf: [0xFF, type])
        appendVLQ(bytes.count)
        append(contentsOf: bytes)
    }
}
