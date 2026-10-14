import Foundation

public extension Array where Element == Section {
    var serialWindows: [(start: MusicTimeStamp, duration: MusicTimeStamp)] {
        var result: [(start: MusicTimeStamp, duration: MusicTimeStamp)] = []
        result.reserveCapacity(count)
        var cursor: MusicTimeStamp = 0
        for section in self {
            let end = Swift.max(cursor, section.duration)
            result.append((start: cursor, duration: end - cursor))
            cursor = end
        }
        return result
    }
}

public struct Section: Equatable, Codable, Identifiable {

    private struct AudibleNote: Hashable {
        let pitch: Pitch?
        let velocity: UInt32
        let startTime: MusicTimeStamp
        let duration: MusicTimeStamp
        let fall: Fall?
        let activity: LoopActivity?
        let slides: [SlideStep]?
        let velocityChoices: ClosedRange<UInt32>?
        let durationChoices: [MusicTimeStamp]?
        let dice: DiceGate?
        let automation: [AutomationCurve]?
        let loop: LoopStamp?

        init(_ note: Note) {
            pitch = note.pitch
            velocity = note.velocity
            startTime = note.startTime
            duration = note.duration
            fall = note.fall
            activity = note.activity
            slides = note.slides
            velocityChoices = note.velocityChoices
            durationChoices = note.durationChoices
            dice = note.dice
            automation = note.automation
            loop = note.loop
        }
    }

    private static func sounds(_ a: Note, like b: Note) -> Bool {
        a.startTime == b.startTime
            && a.duration == b.duration
            && a.velocity == b.velocity
            && a.pitch == b.pitch
            && a.fall == b.fall
            && a.activity == b.activity
            && a.slides == b.slides
            && a.velocityChoices == b.velocityChoices
            && a.durationChoices == b.durationChoices
            && a.dice == b.dice
            && a.automation == b.automation
            && a.loop == b.loop
    }

    public static func == (lhs: Section, rhs: Section) -> Bool {
        guard lhs.notes.count == rhs.notes.count,
              lhs.activity == rhs.activity,
              lhs.muted == rhs.muted,
              lhs.automation == rhs.automation else { return false }
        if lhs.notes.isEmpty { return true }

        var sameOrder = true
        for i in lhs.notes.indices where !sounds(lhs.notes[i], like: rhs.notes[i]) {
            sameOrder = false
            break
        }
        if sameOrder { return true }

        var counts: [AudibleNote: Int] = [:]
        counts.reserveCapacity(lhs.notes.count)
        for note in lhs.notes { counts[AudibleNote(note), default: 0] += 1 }
        for note in rhs.notes {
            let key = AudibleNote(note)
            guard let remaining = counts[key], remaining > 0 else { return false }
            counts[key] = remaining - 1
        }
        return true
    }

    public var id: UUID = UUID()
    public var notes: [Note] = []
    public var activity: LoopActivity? = nil
    public var muted: Bool? = nil
    public var automation: [AutomationCurve]? = nil

    public var isMuted: Bool { muted == true }

    public var duration: MusicTimeStamp { notes.reduce(into: 0) { $0 = max($0, $1.startTime+$1.duration) } }

    public init(@SectionBuilder _ content: () -> Section) {
        self = content()
    }
    
    public init(notes: [Note]) {
        self.notes = notes
    }

    private func replacingNotes(_ newNotes: [Note]) -> Section {
        var section = Section(notes: newNotes)
        section.activity = activity
        section.muted = muted
        section.automation = automation
        return section
    }

    public func key(_ root: Pitch, _ mode: ScaleMode) -> Section { key(Scale(root, mode)) }

    public func key(_ scale: Scale) -> Section {
        replacingNotes(notes.keyed(in: scale))
    }

    public func mute(_ on: Bool = true) -> Section {
        var section = self
        section.muted = on ? true : nil
        return section
    }

    // MARK: - Arrangement

    public func active(loops: ClosedRange<Int>) -> Section {
        withActivity(.over(loops))
    }

    public func active(loops: Range<Int>) -> Section {
        withActivity(.over(loops))
    }

    public func active(loops: PartialRangeFrom<Int>) -> Section {
        withActivity(.over(loops))
    }

    public func active(loops: PartialRangeThrough<Int>) -> Section {
        withActivity(.over(loops))
    }

    public func active(loops: PartialRangeUpTo<Int>) -> Section {
        withActivity(.over(loops))
    }

    public func active(loops: [Int]) -> Section {
        withActivity(.set(loops))
    }

    public func active(every n: Int, offset: Int = 0) -> Section {
        withActivity(.every(n, offset: offset))
    }

    private func withActivity(_ newActivity: LoopActivity) -> Section {
        var section = self
        section.activity = newActivity
        return section
    }

    private func beatGroups() -> [[Int]] {
        var groups: [[Int]] = []
        var lastTime: MusicTimeStamp = -.infinity
        for (i, note) in notes.enumerated() {
            if note.startTime == lastTime {
                groups[groups.count - 1].append(i)
            } else {
                groups.append([i])
                lastTime = note.startTime
            }
        }
        return groups
    }

    public func velocities(_ velocities: UInt32...) -> Section {
        let groups = beatGroups()
        var newNotes = self.notes
        for (beatIndex, velocity) in velocities.enumerated() {
            guard beatIndex < groups.count else { break }
            for noteIndex in groups[beatIndex] {
                newNotes[noteIndex].velocity = min(max(velocity, 0), 127)
                newNotes[noteIndex].velocityChoices = nil
            }
        }
        return replacingNotes(newNotes)
    }

    public func durations(_ durations: Double...) -> Section {
        let groups = beatGroups()
        var newNotes = self.notes
        for (beatIndex, duration) in durations.enumerated() {
            guard beatIndex < groups.count else { break }
            for noteIndex in groups[beatIndex] {
                let old = newNotes[noteIndex].duration
                newNotes[noteIndex] = newNotes[noteIndex].scalingSlides(from: old, to: duration)
                newNotes[noteIndex].duration = duration
                newNotes[noteIndex].durationChoices = nil
            }
        }
        return replacingNotes(newNotes)
    }
    
    public func tempo(_ tempo: Double) -> Section {
        let timeWarp = 240.0 / tempo
        var warped = replacingNotes(notes.map { note in
            var n = note
            n.startTime = note.startTime * timeWarp
            n.duration = note.duration * timeWarp
            n.durationChoices = note.durationChoices.map { $0.map { $0 * timeWarp } }
            n.slides = note.slides.map { steps in
                steps.map { SlideStep(from: $0.from, at: $0.at * timeWarp, over: $0.over * timeWarp,
                                      carry: $0.carry, degree: $0.degree) }
            }
            n.fall = note.fall.map { Fall(semitones: $0.semitones, over: $0.over * timeWarp) }
            n.automation = note.automation.map { $0.map { $0.scalingTimes(by: timeWarp) } }
            return n
        })
        warped.automation = automation.map { $0.map { $0.scalingTimes(by: timeWarp) } }
        return warped
    }

    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Section {
        automating(target, breakpoints, timeScale: duration, curve: curve)
    }
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Section {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Section {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    public func automate(_ target: AutomationTarget, beats breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Section {
        automating(target, breakpoints, timeScale: 1.0 / Double(SectionBuilder.timeSignature.noteValue), curve: curve)
    }

    private func automating(_ target: AutomationTarget, _ breakpoints: [Double: Double],
                            timeScale: MusicTimeStamp, curve shape: AutomationShape) -> Section {
        guard let curve = AutomationCurve.make(target, breakpoints, timeScale: timeScale, curve: shape)
        else { return self }
        guard target.isPerVoice else {
            guard !(automation ?? []).contains(where: { $0.target == target }) else { return self }
            var section = self
            section.automation = (automation ?? []) + [curve]
            return section
        }
        return replacingNotes(notes.map { note in
            guard let slice = curve.sliced(from: note.startTime, length: note.duration) else { return note }
            var n = note
            n.automation = (note.automation ?? []) + [slice]
            return n
        })
    }

    public func velocity(_ velocity: UInt32) -> Section {
        return replacingNotes(notes.map { note in
            var n = note
            n.velocity = min(max(velocity, 0), 127)
            n.velocityChoices = nil
            return n
        })
    }

    public func velocity(random range: ClosedRange<UInt32>) -> Section {
        let low  = min(max(range.lowerBound, 0), 127)
        let high = min(max(range.upperBound, low), 127)
        return replacingNotes(notes.map { note in
            var n = note
            n.velocityChoices = low...high
            n.velocity = (low + high) / 2
            return n
        })
    }

    public func durations(random choices: [MusicTimeStamp]) -> Section {
        guard !choices.isEmpty else { return self }
        return replacingNotes(notes.map { note in
            var n = note
            n.durationChoices = choices
            n.duration = choices[choices.count / 2]
            return n
        })
    }

    public func pickOne() -> Section {
        let layers = Set(notes.compactMap { $0.layerIndex }).sorted()
        guard layers.count > 1 else { return self }
        let stamps = Set(notes.map { ($0.sourceLine ?? 0) &* 10_000 &+ ($0.sourceColumn ?? 0) }).sorted()
        let salt = Dice.salt(stamps.map { UInt64(bitPattern: Int64($0)) })
        return replacingNotes(notes.map { note in
            guard let layer = note.layerIndex, let member = layers.firstIndex(of: layer) else { return note }
            var n = note
            n.dice = .member(member, of: layers.count, salt: Dice.salt(salt, for: .gate))
            return n
        })
    }

    public func velocity(scale: Double) -> Section {
        return replacingNotes(notes.map { note in
            var n = note
            n.velocity = UInt32(min(max((Double(note.velocity) * scale).rounded(), 0), 127))
            n.velocityChoices = note.velocityChoices.map { range in
                let low  = UInt32(min(max((Double(range.lowerBound) * scale).rounded(), 0), 127))
                let high = UInt32(min(max((Double(range.upperBound) * scale).rounded(), Double(low)), 127))
                return low...high
            }
            return n
        })
    }

    public func noteDuration(_ duration: Double) -> Section {
        var currentTime: Double = 0
        let newNotes = notes.map { note -> Note in
            var n = note.scalingSlides(from: note.duration, to: duration)
            n.startTime = currentTime
            n.duration = duration
            n.durationChoices = nil
            currentTime += duration
            return n
        }
        return replacingNotes(newNotes)
    }

    public func syncopate(by amount: MusicTimeStamp = .n16) -> Section {
        let n4 = MusicTimeStamp.n4
        let tolerance = 0.001
        let newNotes = notes.map { note -> Note in
            guard note.startTime > tolerance else { return note }
            let beatPhase = note.startTime / n4
            guard abs(beatPhase - beatPhase.rounded()) < tolerance else { return note }
            var n = note
            n.startTime = max(0, note.startTime - amount)
            return n
        }
        return replacingNotes(newNotes)
    }

    public func swing(_ ratio: Double = 0.67) -> Section {
        let n4 = MusicTimeStamp.n4
        let n8 = MusicTimeStamp.n8
        let tolerance = 0.001
        let newNotes = notes.map { note -> Note in
            let slot = (note.startTime / n8).rounded()
            guard Int(slot) % 2 == 1 else { return note }
            guard abs(note.startTime - slot * n8) < tolerance else { return note }
            let beat = floor(note.startTime / n4)
            let swungTime = beat * n4 + ratio * n4
            var n = note
            n.startTime = swungTime
            return n
        }
        return replacingNotes(newNotes)
    }

    public static func random(from pitches: [UInt32], count: Int, duration: Double = .n8, velocity: UInt32 = 80) -> Section {
        var notes: [Note] = []
        var currentTime: Double = 0
        let poolSalt = Dice.salt(pitches.map(UInt64.init))

        for index in 0..<count {
            let pitch = pitches.isEmpty ? 60
                : pitches[Dice.roll(salt: Dice.mix(poolSalt ^ UInt64(index)),
                                    loopIndex: 0, count: pitches.count)]
            notes.append(Note(pitch: pitch, velocity: velocity, startTime: currentTime, duration: duration))
            currentTime += duration
        }

        return Section(notes: notes)
    }

    public static func random(from noteNames: [String], count: Int, duration: Double = .n8, velocity: UInt32 = 80) -> Section {
        let pitches = noteNames.compactMap { $0.pitch }
        return random(from: pitches, count: count, duration: duration, velocity: velocity)
    }
}
