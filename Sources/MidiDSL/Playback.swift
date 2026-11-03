import Foundation

// What sounds on a given pass, resolved once for every reader of a `Session`: a player, a
// MIDI file, an audio render, a highlighter. Each of them must reach the same answer, so
// the answer lives here rather than in any one of them.

// MARK: - Pitch on a pass

extension Note {
    /// The pitch this note sounds on `loopIndex`: its own pitch, or the member of its note
    /// set chosen for that pass. Nil for a rest.
    public func resolvedPitch(loopIndex: Int, seed: UInt64 = 0) -> Pitch? {
        guard let base = pitch else { return nil }
        guard let variants = pitchVariants, variants.count > 1 else { return base }
        return variants[(variantMode ?? .up).soundingIndex(
            count: variants.count, pass: rollPass(loopIndex),
            diceSalt: diceSalt, seed: seed)]
    }
}

// MARK: - Section order on a pass

/// Where a section sits on its track: sections play one after another, so each one starts
/// where the previous ends.
public typealias SectionWindow = (start: Double, duration: Double)

/// The order a `Track.shuffleSections()` track plays its sections in on each pass. Pass 0
/// plays them as written; later passes permute them, seeded only by the pass and the count
/// so tracks of equal length stay aligned with each other.
public enum SectionShuffle {

    public static func isShuffled(_ track: Track, loopIndex: Int) -> Bool {
        guard track.sectionOrder == .shuffled else { return false }
        return track.shuffleLoops?.isActive(loopIndex: loopIndex) ?? true
    }

    public static func permutation(loopIndex: Int, count: Int) -> [Int] {
        var perm = Array(0..<count)
        guard loopIndex > 0, count > 1 else { return perm }
        var state = Dice.mix(UInt64(bitPattern: Int64(loopIndex)) ^ (UInt64(count) &* 0x9E3779B97F4A7C15))
        for i in (1..<count).reversed() {
            state = Dice.mix(state)
            perm.swapAt(i, Int(state % UInt64(i + 1)))
        }
        return perm
    }

    public static func windows(of sections: [Section]) -> [SectionWindow] {
        sections.serialWindows
    }

    /// Where each section (in written order) starts on this pass.
    public static func shuffledStarts(windows: [SectionWindow], loopIndex: Int) -> [Double] {
        let perm = permutation(loopIndex: loopIndex, count: windows.count)
        var starts = [Double](repeating: 0, count: windows.count)
        var cursor: Double = 0
        for original in perm {
            starts[original] = cursor
            cursor += windows[original].duration
        }
        return starts
    }

    /// The written position that sounds at `position` on this pass.
    public static func writtenPosition(_ position: Double, windows: [SectionWindow], loopIndex: Int) -> Double {
        guard windows.count > 1, loopIndex > 0 else { return position }
        let perm = permutation(loopIndex: loopIndex, count: windows.count)
        var cursor: Double = 0
        for (slot, original) in perm.enumerated() {
            let width = windows[original].duration
            if position < cursor + width || slot == perm.count - 1 {
                return position - cursor + windows[original].start
            }
            cursor += width
        }
        return position
    }
}

// MARK: - Pitch and gain while a note rings

/// One breakpoint of a sounding note's ramp: how far from its final pitch it is, in
/// semitones, and the gain its volume curve and legato carries leave it at.
public struct PitchRampPoint: Equatable {
    public let time: Double
    public let semitones: Float
    public var amp: Float

    public init(time: Double, semitones: Float, amp: Float = 1) {
        self.time = time
        self.semitones = semitones
        self.amp = amp
    }
}

/// A note's slides, fall and `.volume` curves as one piecewise-linear ramp, in the same time
/// unit the arguments are given in.
public func pitchRampPoints(slides: [SlideStep]?, fall: Fall? = nil, duration: Double, finalPitch: UInt32,
                            automation: [AutomationCurve]? = nil) -> [PitchRampPoint] {
    let quickGlide = 0.08
    let legatoStep = 0.001
    var points: [PitchRampPoint] = []
    var amp: Float = 1
    if let slides, !slides.isEmpty {
        for (i, step) in slides.enumerated() {
            let offset = Float(Int(step.from) - Int(finalPitch))
            let nextOffset: Float = i + 1 < slides.count
                ? Float(Int(slides[i + 1].from) - Int(finalPitch))
                : 0
            let at = min(max(step.at, points.last?.time ?? 0), duration)
            let nextAt = i + 1 < slides.count ? min(slides[i + 1].at, duration) : duration
            let span = max(nextAt - at, 0.001)
            let over: Double
            if step.carry != nil {
                over = min(legatoStep, span)
            } else {
                over = min(step.over > 0 ? step.over : min(quickGlide, span), span)
            }
            points.append(PitchRampPoint(time: at, semitones: offset, amp: amp))
            if let carry = step.carry { amp *= Float(carry) }
            points.append(PitchRampPoint(time: at + over, semitones: nextOffset, amp: amp))
        }
    }
    if let fall, fall.semitones != 0 {
        let quickFall = min(0.15, duration / 4)
        let over = fall.over > 0 ? fall.over : quickFall
        let start = min(max(points.last?.time ?? 0, duration - over), duration)
        points.append(PitchRampPoint(time: start, semitones: 0, amp: amp))
        points.append(PitchRampPoint(time: max(duration, start + 0.001), semitones: Float(fall.semitones), amp: amp))
    }

    let volumeCurves = (automation ?? []).filter { $0.target == .volume }
    guard !volumeCurves.isEmpty else { return points }

    var times = points.map(\.time)
    var moves = false
    for curve in volumeCurves {
        for point in curve.points { times.append(min(max(point.time, 0), duration)) }
        if curve.points.count > 1 { moves = true }
    }
    if moves { times.append(0); times.append(duration) }
    times.sort()
    var grid: [Double] = []
    for t in times where grid.last.map({ t - $0 > 1e-9 }) ?? true { grid.append(t) }
    if grid.isEmpty { grid = [0] }

    func carryAmp(at t: Double) -> Float {
        var amp: Float = 1
        for point in points {
            if point.time <= t + 1e-12 { amp = point.amp } else { break }
        }
        return amp
    }

    return grid.map { t in
        PitchRampPoint(time: t,
                       semitones: MIDIRamp.rampOffset(points, elapsed: t),
                       amp: carryAmp(at: t) * Float(volumeCurves.gain(at: t)))
    }
}

// MARK: - A ramp as MIDI

/// A ramp spelled in MIDI's terms: pitch bend values, the RPN that widens the bend range,
/// and CC 11 (expression) for a volume curve. Shared by the MIDI file and any live MIDI
/// output, so both bend a slide the same way.
public enum MIDIRamp {

    public struct Bend: Equatable {
        public let time: Double
        public let value: UInt16
        public init(time: Double, value: UInt16) {
            self.time = time
            self.value = value
        }
    }

    public struct Expression: Equatable {
        public let time: Double
        public let value: UInt8
        public init(time: Double, value: UInt8) {
            self.time = time
            self.value = value
        }
    }

    public static let bendRangeSemitones: Float = 24.0
    public static let center: UInt16 = 8192
    public static let stepInterval: Double = 0.005
    public static let expressionController: UInt8 = 11
    public static let expressionFull: UInt8 = 127

    public static func bendValue(semitones: Float, range: Float = bendRangeSemitones) -> UInt16 {
        let clamped = max(-range, min(range, semitones))
        let scaled = Int((clamped / range * 8192.0).rounded())
        return UInt16(max(0, min(16383, 8192 + scaled)))
    }

    /// RPN 0 (pitch bend sensitivity) set to `range` semitones, as controller/value pairs.
    public static func bendRangeRPN(range: UInt8 = UInt8(bendRangeSemitones),
                                    closeRPN: Bool = true) -> [(controller: UInt8, value: UInt8)] {
        var pairs: [(controller: UInt8, value: UInt8)] = [
            (101, 0),
            (100, 0),
            (6, range),
            (38, 0),
        ]
        if closeRPN {
            pairs.append((101, 127))
            pairs.append((100, 127))
        }
        return pairs
    }

    // Read per render chunk on the audio thread, so inlinable across the module boundary.
    @inlinable
    public static func rampOffset(_ ramp: [PitchRampPoint], elapsed: Double) -> Float {
        guard let first = ramp.first else { return 0 }
        if elapsed <= first.time { return first.semitones }
        for i in 1..<ramp.count {
            let b = ramp[i]
            if elapsed < b.time {
                let a = ramp[i - 1]
                let f = Float((elapsed - a.time) / max(b.time - a.time, 1e-9))
                return a.semitones + f * (b.semitones - a.semitones)
            }
        }
        return ramp.last!.semitones
    }

    @inlinable
    public static func rampAmp(_ ramp: [PitchRampPoint], elapsed: Double) -> Float {
        guard let first = ramp.first else { return 1 }
        if elapsed <= first.time { return first.amp }
        for i in 1..<ramp.count {
            let b = ramp[i]
            if elapsed < b.time {
                let a = ramp[i - 1]
                let f = Float((elapsed - a.time) / max(b.time - a.time, 1e-9))
                return a.amp + f * (b.amp - a.amp)
            }
        }
        return ramp.last!.amp
    }

    /// The ramp's pitch stepped into bend values every `interval`, consecutive repeats dropped.
    /// Empty for a ramp that never moves the pitch.
    public static func bendEvents(ramp: [PitchRampPoint],
                                  interval: Double = stepInterval) -> [Bend] {
        guard let last = ramp.last else { return [] }
        guard ramp.contains(where: { $0.semitones != 0 }) else { return [] }
        var events: [Bend] = []
        var step = 0
        while true {
            let t = Double(step) * interval
            guard t < last.time else { break }
            let value = bendValue(semitones: rampOffset(ramp, elapsed: t))
            if events.last?.value != value {
                events.append(Bend(time: t, value: value))
            }
            step += 1
        }
        let finalValue = bendValue(semitones: last.semitones)
        if events.last?.value != finalValue {
            events.append(Bend(time: last.time, value: finalValue))
        }
        return events
    }

    /// The ramp's gain stepped into CC 11 values every `interval`, consecutive repeats dropped.
    /// Empty for a ramp that never moves the gain.
    public static func expressionEvents(ramp: [PitchRampPoint],
                                        interval: Double = stepInterval) -> [Expression] {
        guard let last = ramp.last, ramp.contains(where: { $0.amp != 1 }) else { return [] }
        func value(at t: Double) -> UInt8 {
            let scaled = (rampAmp(ramp, elapsed: t) * 127).rounded()
            return UInt8(max(0, min(127, scaled)))
        }
        var events: [Expression] = []
        var step = 0
        while true {
            let t = Double(step) * interval
            guard t < last.time else { break }
            let v = value(at: t)
            if events.last?.value != v { events.append(Expression(time: t, value: v)) }
            step += 1
        }
        let finalValue = value(at: last.time)
        if events.last?.value != finalValue {
            events.append(Expression(time: last.time, value: finalValue))
        }
        return events
    }
}
