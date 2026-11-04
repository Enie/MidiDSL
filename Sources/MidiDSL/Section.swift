import Foundation

public extension Array where Element == Section {
    @_documentation(visibility: internal)
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

/// Layers that sound together.
///
/// Every statement in a `Section {}` starts at the section's start, and the longest one sets its
/// length. A track plays its sections one after another.
///
/// ```swift
/// Track("piano") {
///     Section {
///         "CDEFGABC6".duration(.n8)   // an eighth-note run
///         "[C3 G3]".duration(.n1)     // over a held fifth
///     }
///     Section { "| Am | Fmaj7 |" }     // then two bars of chords
/// }
/// ```
///
/// A statement can be a notation string, a ``DrumLane``, a ``Note``, a ``Chord``, a
/// ``Progression``, a ``NoteSet`` or another `Section`. Every modifier returns a changed copy.
/// See <doc:Sections>.
///
/// ## Topics
///
/// ### Making a section
///
/// - ``init(_:)``
/// - ``random(from:count:duration:velocity:)-9wtbe``
/// - ``random(from:count:duration:velocity:)-3a05n``
///
/// ### Loudness
///
/// - ``velocity(_:)``
/// - ``velocity(scale:)``
/// - ``velocities(_:)``
/// - ``velocity(random:)``
///
/// ### Length
///
/// - ``durations(_:)``
/// - ``noteDuration(_:)``
/// - ``durations(random:)``
///
/// ### Timing and feel
///
/// - ``tempo(_:)``
/// - ``swing(_:)``
/// - ``syncopate(by:)``
///
/// ### Key
///
/// - ``key(_:_:)``
/// - ``key(_:)``
///
/// ### Movement
///
/// - ``automate(_:over:curve:)``
/// - ``automate(_:at:curve:)``
/// - ``automate(_:bars:curve:)``
/// - ``automate(_:beats:curve:)``
///
/// ### When it plays
///
/// - ``active(loops:)-v4wc``
/// - ``active(loops:)-5o37i``
/// - ``active(loops:)-9s43``
/// - ``active(loops:)-mh9d``
/// - ``active(loops:)-6rn3b``
/// - ``active(loops:)-3ixil``
/// - ``active(every:offset:)``
/// - ``pickOne()``
/// - ``mute(_:)``
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

    @_documentation(visibility: internal)
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

    @_documentation(visibility: internal)
    public var id: UUID = UUID()
    @_documentation(visibility: internal)
    public var notes: [Note] = []
    @_documentation(visibility: internal)
    public var activity: LoopActivity? = nil
    @_documentation(visibility: internal)
    public var muted: Bool? = nil
    @_documentation(visibility: internal)
    public var automation: [AutomationCurve]? = nil

    @_documentation(visibility: internal)
    public var isMuted: Bool { muted == true }

    @_documentation(visibility: internal)
    public var duration: MusicTimeStamp { notes.reduce(into: 0) { $0 = max($0, $1.startTime+$1.duration) } }

    /// A section whose statements sound together.
    ///
    /// - Parameter content: The statements, each a layer starting at the section's start.
    public init(@SectionBuilder _ content: () -> Section) {
        self = content()
    }
    
    @_documentation(visibility: internal)
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

    /// Reads the section's degrees in a key.
    ///
    /// The numbers in the section's notation become notes of the key; note names are not moved.
    /// A key written further in, on a line or a nested section, wins over this one.
    ///
    /// - Parameters:
    ///   - root: The key's first degree, as a pitch.
    ///   - mode: The scale built on the root.
    /// - Returns: The section, changed.
    public func key(_ root: Pitch, _ mode: ScaleMode) -> Section { key(Scale(root, mode)) }

    /// Reads the section's degrees in a scale.
    ///
    /// - Parameter scale: The scale the numbers in the section are degrees of.
    /// - Returns: The section, changed.
    public func key(_ scale: Scale) -> Section {
        replacingNotes(notes.keyed(in: scale))
    }

    /// Silences the section while keeping its time.
    ///
    /// The sections after it keep their place. On a section nested inside another, it silences
    /// that one layer.
    ///
    /// - Parameter on: `true` silences the section, `false` plays it.
    /// - Returns: The section, changed.
    public func mute(_ on: Bool = true) -> Section {
        var section = self
        section.muted = on ? true : nil
        return section
    }

    // MARK: - Arrangement

    /// Plays the section only on the passes in a closed range, such as `0...1`.
    ///
    /// Passes count from 0. On the other passes its time stays reserved, so what follows keeps its place.
    ///
    /// - Parameter loops: The passes the section plays on.
    /// - Returns: The section, changed.
    public func active(loops: ClosedRange<Int>) -> Section {
        withActivity(.over(loops))
    }

    /// Plays the section only on the passes in a half-open range, such as `0..<4`.
    ///
    /// Passes count from 0. On the other passes its time stays reserved, so what follows keeps its place.
    ///
    /// - Parameter loops: The passes the section plays on.
    /// - Returns: The section, changed.
    public func active(loops: Range<Int>) -> Section {
        withActivity(.over(loops))
    }

    /// Plays the section only on the passes from one on, such as `2...`.
    ///
    /// Passes count from 0. On the other passes its time stays reserved, so what follows keeps its place.
    ///
    /// - Parameter loops: The passes the section plays on.
    /// - Returns: The section, changed.
    public func active(loops: PartialRangeFrom<Int>) -> Section {
        withActivity(.over(loops))
    }

    /// Plays the section only on the passes up to and including one, such as `...3`.
    ///
    /// Passes count from 0. On the other passes its time stays reserved, so what follows keeps its place.
    ///
    /// - Parameter loops: The passes the section plays on.
    /// - Returns: The section, changed.
    public func active(loops: PartialRangeThrough<Int>) -> Section {
        withActivity(.over(loops))
    }

    /// Plays the section only on the passes before one, such as `..<4`.
    ///
    /// Passes count from 0. On the other passes its time stays reserved, so what follows keeps its place.
    ///
    /// - Parameter loops: The passes the section plays on.
    /// - Returns: The section, changed.
    public func active(loops: PartialRangeUpTo<Int>) -> Section {
        withActivity(.over(loops))
    }

    /// Plays the section only on the passes you list.
    ///
    /// Passes count from 0, so `[0, 1, 4]` plays the first, second and fifth. On the other passes its time stays reserved, so what follows keeps its place.
    ///
    /// - Parameter loops: The passes the section plays on.
    /// - Returns: The section, changed.
    public func active(loops: [Int]) -> Section {
        withActivity(.set(loops))
    }

    /// Plays the section on every `n`th pass.
    ///
    /// `active(every: 2)` plays the even passes, `active(every: 2, offset: 1)` the odd ones.
    /// On the other passes its time stays reserved, so what follows keeps its place.
    ///
    /// - Parameters:
    ///   - n: The period, in passes. `2` is every other pass.
    ///   - offset: Which pass of each period plays, counting from 0.
    /// - Returns: The section, changed.
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

    /// Gives each beat position of the section its own velocity, in order.
    ///
    /// A beat position is a start time; the notes of a chord share one. Positions are counted
    /// layer by layer, in the order the statements are written. Positions past the end of the
    /// list keep their velocity.
    ///
    /// ```swift
    /// Section { "CCGG" }.velocities(110, 70, 90, 70)
    /// ```
    ///
    /// - Parameter velocities: One velocity per beat position, 0…127.
    /// - Returns: The section, changed.
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

    /// Gives each beat position of the section its own duration, in order.
    ///
    /// Beat positions are counted as for ``velocities(_:)``. Start times stay where they are:
    /// only how long each note rings changes. The modifier of the same name on a notation string
    /// also moves the notes back to back.
    ///
    /// - Parameter durations: One duration in whole notes per beat position.
    /// - Returns: The section, changed.
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
    
    /// Plays the section at a tempo of its own.
    ///
    /// The tempo is measured against the session's: at `.tempo(60)` in a session at 120, the
    /// section plays at half speed and takes twice as long. The sections after it move to make
    /// room. A tempo of 0 or below changes nothing.
    ///
    /// ```swift
    /// Session {
    ///     Track("lead") {
    ///         Section { "| 1 2 3 5 |" }
    ///         Section { "| 5 3 2 1 |" }.tempo(60)    // the same bar, twice as slow
    ///     }
    /// }
    /// .tempo(120)
    /// ```
    ///
    /// - Parameter tempo: Beats per minute for this section.
    /// - Returns: The section, changed.
    public func tempo(_ tempo: Double) -> Section {
        guard tempo > 0 else { return self }
        return scalingTime(by: SectionBuilder.tempo / tempo)
    }

    /// The section with every time in it multiplied by `factor`: start times, durations, the
    /// durations it may roll, slides, falls and curves.
    ///
    /// A player uses it to turn whole notes into seconds, `scalingTime(by: 240 / bpm)`.
    @_documentation(visibility: internal)
    public func scalingTime(by factor: Double) -> Section {
        var warped = replacingNotes(notes.map { note in
            var n = note
            n.startTime = note.startTime * factor
            n.duration = note.duration * factor
            n.durationChoices = note.durationChoices.map { $0.map { $0 * factor } }
            n.slides = note.slides.map { steps in
                steps.map { SlideStep(from: $0.from, at: $0.at * factor, over: $0.over * factor,
                                      carry: $0.carry, degree: $0.degree) }
            }
            n.fall = note.fall.map { Fall(semitones: $0.semitones, over: $0.over * factor) }
            n.automation = note.automation.map { $0.map { $0.scalingTimes(by: factor) } }
            return n
        })
        warped.automation = automation.map { $0.map { $0.scalingTimes(by: factor) } }
        return warped
    }

    /// Moves a parameter across the section, with times as fractions of its length.
    ///
    /// `0` is the start of the section and `1` its end, so the curve keeps its shape when the section gets
    /// longer. The value holds before the first breakpoint and after the last, so one breakpoint
    /// is a constant. A value outside the target's range is clamped to it.
    ///
    /// ```swift
    /// Section { "| 1 3 5 5 | 5 3 2 1 |" }.automate(.volume, over: [0: 1, 0.75: 1, 1: 0])
    /// ```
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time a fraction of the section's length.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The section, changed.
    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Section {
        automating(target, breakpoints, timeScale: duration, curve: curve)
    }
    /// Moves a parameter across the section, with times in whole notes from its start.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in whole notes from the start of the section.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The section, changed.
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Section {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    /// Moves a parameter across the section, with times in bars from its start.
    ///
    /// Bars are measured in the session's time signature, the same one bar notation is read in.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in bars from the start of the section.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The section, changed.
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Section {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    /// Moves a parameter across the section, with times in beats from its start.
    ///
    /// Beats are the session's time signature's note value: quarters in 4/4, eighths in 6/8.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in beats from the start of the section.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The section, changed.
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

    /// Plays every note of the section at one velocity.
    ///
    /// This flattens accents and ghost notes; ``velocity(scale:)`` keeps them.
    ///
    /// - Parameter velocity: The velocity, 0…127.
    /// - Returns: The section, changed.
    public func velocity(_ velocity: UInt32) -> Section {
        return replacingNotes(notes.map { note in
            var n = note
            n.velocity = min(max(velocity, 0), 127)
            n.velocityChoices = nil
            return n
        })
    }

    /// Gives every note a velocity drawn from a range, drawn again on every pass.
    ///
    /// The draws come from ``Dice``, so they are the same on every build. A reader that does not
    /// roll sees the middle of the range.
    ///
    /// ```swift
    /// Section { "| C E G C |" }.velocity(random: 70...110)
    /// ```
    ///
    /// - Parameter range: The velocities to draw from, within 0…127.
    /// - Returns: The section, changed.
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

    /// Gives every note a duration drawn from a list, drawn again on every pass.
    ///
    /// Start times never move, so the section keeps its shape however the draw goes.
    ///
    /// ```swift
    /// Section { "| C E G C |" }.durations(random: [.n8, .n4])
    /// ```
    ///
    /// - Parameter choices: The durations to draw from, in whole notes. Empty changes nothing.
    /// - Returns: The section, changed.
    public func durations(random choices: [MusicTimeStamp]) -> Section {
        guard !choices.isEmpty else { return self }
        return replacingNotes(notes.map { note in
            var n = note
            n.durationChoices = choices
            n.duration = choices[choices.count / 2]
            return n
        })
    }

    /// Plays exactly one of the section's statements on each pass, chosen by the dice.
    ///
    /// Every statement is a candidate, and the choice is the same on every build.
    ///
    /// ```swift
    /// Section {
    ///     "| C5 E5 G5 - |"
    ///     "| C5 F5 A5 - |"
    ///     "| B4 D5 G5 - |"
    /// }.pickOne()
    /// ```
    ///
    /// - Returns: The section, changed.
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

    /// Multiplies every note's velocity, so accents and ghost notes keep their ratio.
    ///
    /// Results clamp to 0…127.
    ///
    /// - Parameter scale: The factor. `0.5` halves the section, above `1` pushes it.
    /// - Returns: The section, changed.
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

    /// Gives every note one duration and plays the notes back to back.
    ///
    /// Every note takes its own step, so the notes of a chord become a run. Use it on a single
    /// line of single notes.
    ///
    /// ```swift
    /// Section { "CDEFGAB" }.noteDuration(.n8)
    /// ```
    ///
    /// - Parameter duration: The duration in whole notes.
    /// - Returns: The section, changed.
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

    /// Pulls the notes on quarter-note beats earlier, for an anticipated feel.
    ///
    /// Notes off the beat, and a note at the very start of the section, stay where they are.
    ///
    /// - Parameter amount: How much earlier, in whole notes. `.n16` is a sixteenth.
    /// - Returns: The section, changed.
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

    /// Moves the off-beat eighths later in their beat.
    ///
    /// Only notes exactly on an off-beat eighth move.
    ///
    /// ```swift
    /// Section { "CC6ABC6GAF" }.noteDuration(.n8).swing()
    /// ```
    ///
    /// - Parameter ratio: Where in the beat the off-beat eighth lands. `0.5` is straight,
    ///   `0.67` a triplet swing, `0.75` a heavy one.
    /// - Returns: The section, changed.
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

    /// A run of notes drawn from a set of pitches.
    ///
    /// The draw comes from ``Dice``, so the same pitches always give the same run.
    ///
    /// ```swift
    /// Section.random(from: Scale(.C5, .majorPentatonic).pitches, count: 8)
    /// ```
    ///
    /// - Parameters:
    ///   - pitches: The MIDI pitches to draw from. Empty plays C5.
    ///   - count: How many notes, back to back.
    ///   - duration: The duration of each note, in whole notes.
    ///   - velocity: The velocity of every note, 0…127.
    /// - Returns: A section of `count` notes.
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

    /// A run of notes drawn from a set of note names.
    ///
    /// ```swift
    /// Section.random(from: ["C", "D", "E", "G", "A"], count: 8)
    /// ```
    ///
    /// - Parameters:
    ///   - noteNames: The note names to draw from, such as `"C"` or `"F#4"`. Names that are not
    ///     notes are skipped.
    ///   - count: How many notes, back to back.
    ///   - duration: The duration of each note, in whole notes.
    ///   - velocity: The velocity of every note, 0…127.
    /// - Returns: A section of `count` notes.
    public static func random(from noteNames: [String], count: Int, duration: Double = .n8, velocity: UInt32 = 80) -> Section {
        let pitches = noteNames.compactMap { $0.pitch }
        return random(from: pitches, count: count, duration: duration, velocity: velocity)
    }
}
