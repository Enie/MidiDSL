import Foundation

public enum SampleEffect: Equatable, Codable {
    case bitCrush(bits: Int, rate: Double?)
    case drive(Double)
    case ringMod(Double)

    public static let names = ["bitCrush", "drive", "ringMod"]
}

public struct SampleBound: Equatable, Codable {
    public enum Unit: String, Equatable, Codable {
        case seconds
        case fraction
        case beats
        case bars
    }
    public var unit: Unit
    public var value: Double

    public init(_ unit: Unit, _ value: Double) {
        self.unit = unit
        self.value = max(0, value)
    }

    public static func seconds(_ v: Double) -> SampleBound { SampleBound(.seconds, v) }
    public static func fraction(_ v: Double) -> SampleBound { SampleBound(.fraction, min(max(v, 0), 1)) }
    public static func beats(_ v: Double) -> SampleBound { SampleBound(.beats, v) }
    public static func bars(_ v: Double) -> SampleBound { SampleBound(.bars, v) }
}

public struct Sample: Equatable, Codable {
    public let file: String
    public private(set) var start: SampleBound?
    public private(set) var end: SampleBound?

    public private(set) var gain: Double = 1.0
    public private(set) var tune: Double = 0
    public private(set) var speed: Double = 1.0
    public private(set) var reversed: Bool = false
    public private(set) var fadeIn: Double = 0
    public private(set) var fadeOut: Double = 0
    public private(set) var effects: [SampleEffect] = []

    public init(_ file: String) {
        self.file = file
    }

    // MARK: - Slicing

    public func slice(from: Double, to: Double) -> Sample {
        windowed(.seconds(from), .seconds(to))
    }

    public func slice(fraction: Double, to: Double) -> Sample {
        windowed(.fraction(fraction), .fraction(to))
    }

    public func slice(beats: Double, count: Double = 1) -> Sample {
        windowed(.beats(beats), .beats(beats + count))
    }

    public func slice(bars: Double, count: Double = 1) -> Sample {
        windowed(.bars(bars), .bars(bars + count))
    }

    public func slices(_ count: Int) -> [Sample] {
        let count = max(1, count)
        let unit = start?.unit ?? .fraction
        let lower = start?.value ?? 0
        let upper = end?.value ?? 1
        let step = (upper - lower) / Double(count)
        return (0..<count).map { i in
            windowed(SampleBound(unit, lower + Double(i) * step),
                     SampleBound(unit, lower + Double(i + 1) * step))
        }
    }

    private func windowed(_ from: SampleBound, _ to: SampleBound) -> Sample {
        var s = self
        s.start = from
        s.end = to
        return s
    }

    // MARK: - Shaping

    public func fade(in fadeIn: Double = 0, out fadeOut: Double = 0) -> Sample {
        var s = self
        s.fadeIn = max(0, fadeIn)
        s.fadeOut = max(0, fadeOut)
        return s
    }

    public func gain(_ level: Double) -> Sample {
        var s = self
        s.gain = max(0, level)
        return s
    }

    public func tune(_ semitones: Double) -> Sample {
        var s = self
        s.tune = semitones
        return s
    }

    public func speed(_ rate: Double) -> Sample {
        var s = self
        s.speed = max(0.01, rate)
        return s
    }

    public func reverse(_ on: Bool = true) -> Sample {
        var s = self
        s.reversed = on
        return s
    }

    // MARK: - Insert chain

    public func bitCrush(bits: Int, rate: Double? = nil) -> Sample {
        appending(.bitCrush(bits: min(max(bits, 1), 24), rate: rate.map { max(1, $0) }))
    }

    public func drive(_ amount: Double) -> Sample {
        appending(.drive(max(0, amount)))
    }

    public func ringMod(_ hz: Double) -> Sample {
        appending(.ringMod(max(0, hz)))
    }

    private func appending(_ effect: SampleEffect) -> Sample {
        var s = self
        s.effects.append(effect)
        return s
    }
}

public enum SampleKitCollector {
    nonisolated(unsafe) public static var claimed: [Sample] = []

    static func key(for sample: Sample, base: Pitch = SampleKitConfig.laneBase) -> Pitch {
        if let existing = claimed.firstIndex(of: sample) {
            return base + Pitch(existing)
        }
        claimed.append(sample)
        let key = base + Pitch(claimed.count - 1)
        if key > 127 {
            ScoreAdvisories.note(SessionAdvisory(message:
                "More than \(127 - Int(base) + 1) slices are playing on one track, so \"\(sample.file)\" "
                + "and any after it are silent — the keys run out. Chop the break more coarsely, "
                + "or put the rest on a track of their own."))
        }
        return key
    }

    static func drain() -> [Sample] {
        defer { claimed = [] }
        return claimed
    }

    public static func reset() { claimed = [] }
}

public struct SampleReel {
    indirect enum Part {
        case take(Sample, slot: MusicTimeStamp)
        case reel(SampleReel)
    }
    var parts: [Part]
    var _automation: [PendingCurve] = []

    init(_ parts: [Part]) { self.parts = parts }

    static func take(_ sample: Sample) -> Part {
        .take(sample, slot: SectionBuilder.timeSignature.barDuration)
    }

    var joinable: [Part] { _automation.isEmpty ? parts : [.reel(self)] }

    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> SampleReel {
        automating(target, breakpoints, timeScale: nil, curve: curve)
    }
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> SampleReel {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> SampleReel {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    public func automate(_ target: AutomationTarget, beats breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> SampleReel {
        automating(target, breakpoints, timeScale: 1.0 / Double(SectionBuilder.timeSignature.noteValue),
                   curve: curve)
    }

    private func automating(_ target: AutomationTarget, _ breakpoints: [Double: Double],
                            timeScale: MusicTimeStamp?, curve: AutomationShape) -> SampleReel {
        guard !breakpoints.isEmpty else { return self }
        var r = self
        r._automation.append(PendingCurve(
            target: target, breakpoints: breakpoints, timeScale: timeScale, shape: curve))
        return r
    }

    func notes() -> [Note] {
        var result: [Note] = []
        var cursor: MusicTimeStamp = 0
        for part in parts {
            switch part {
            case .take(let sample, let slot):
                result.append(Note(pitch: SampleKitCollector.key(for: sample),
                                   velocity: DrumLane.hitVelocity,
                                   startTime: cursor, duration: slot))
                cursor += slot
            case .reel(let inner):
                let notes = inner.notes()
                let span = notes.reduce(0.0) { max($0, $1.startTime + $1.duration) }
                result += notes.map { var n = $0; n.startTime += cursor; return n }
                cursor += span
            }
        }
        return PendingCurve.applying(_automation, to: result)
    }
}

extension Sample {
    // MARK: - Time in the score

    public func hold(bars: Double) -> SampleReel {
        held(bars * SectionBuilder.timeSignature.barDuration)
    }
    public func hold(beats: Double) -> SampleReel {
        held(beats / Double(SectionBuilder.timeSignature.noteValue))
    }
    public func hold(_ whole: Double) -> SampleReel {
        held(whole)
    }

    private func held(_ slot: MusicTimeStamp) -> SampleReel {
        SampleReel([.take(self, slot: max(0, slot))])
    }

    var reel: SampleReel { SampleReel([SampleReel.take(self)]) }
}

// MARK: - Laying samples end to end

public func + (lhs: Sample, rhs: Sample) -> SampleReel {
    SampleReel(lhs.reel.parts + rhs.reel.parts)
}
public func + (lhs: Sample, rhs: SampleReel) -> SampleReel {
    SampleReel(lhs.reel.parts + rhs.joinable)
}
public func + (lhs: SampleReel, rhs: Sample) -> SampleReel {
    SampleReel(lhs.joinable + rhs.reel.parts)
}
public func + (lhs: SampleReel, rhs: SampleReel) -> SampleReel {
    SampleReel(lhs.joinable + rhs.joinable)
}
