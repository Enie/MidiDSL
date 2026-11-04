import Foundation

@_documentation(visibility: internal)
public enum LoopActivity: Equatable, Hashable, Codable {
    case range(from: Int?, through: Int?)
    case set([Int])
    case every(Int, offset: Int)

    public func isActive(loopIndex: Int) -> Bool {
        switch self {
        case .range(let from, let through):
            if let from, loopIndex < from { return false }
            if let through, loopIndex > through { return false }
            return true
        case .set(let loops):
            return loops.contains(loopIndex)
        case .every(let n, let offset):
            guard n > 0 else { return true }
            return loopIndex % n == ((offset % n) + n) % n
        }
    }
}

extension LoopActivity {
    static func over(_ loops: ClosedRange<Int>) -> LoopActivity {
        .range(from: loops.lowerBound, through: loops.upperBound)
    }
    static func over(_ loops: Range<Int>) -> LoopActivity {
        .range(from: loops.lowerBound, through: loops.upperBound - 1)
    }
    static func over(_ loops: PartialRangeFrom<Int>) -> LoopActivity {
        .range(from: loops.lowerBound, through: nil)
    }
    static func over(_ loops: PartialRangeThrough<Int>) -> LoopActivity {
        .range(from: nil, through: loops.upperBound)
    }
    static func over(_ loops: PartialRangeUpTo<Int>) -> LoopActivity {
        .range(from: nil, through: loops.upperBound - 1)
    }
}

@_documentation(visibility: internal)
public enum SectionOrder: String, Equatable, Codable {
    case written
    case shuffled
}

/// One instrument's part: sections played one after another, with its sound and arrangement.
///
/// A track is one instrument on one MIDI channel. Its sections play back to back, and a
/// ``Loop`` inside it repeats a few bars under the parts that do not repeat.
///
/// ```swift
/// Track("bass", instrument: .generalMIDI(33)) {
///     Loop(bars: 4) { _ in Section { "| 1 1 5 5 | 4 4 5 5 |" } }
/// }
/// .key(.C3, .minor)
/// .volume(0.8)
/// ```
///
/// Every modifier returns a changed copy. See <doc:TracksAndArrangement>.
///
/// ## Topics
///
/// ### Making a track
///
/// - ``init(_:_:)``
/// - ``init(_:instrument:_:)``
///
/// ### Sound
///
/// - ``instrument(_:)``
/// - ``volume(_:)``
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
/// - ``active(loops:)-dsxp``
/// - ``active(loops:)-6znzo``
/// - ``active(loops:)-wqz9``
/// - ``active(loops:)-2cwxr``
/// - ``active(loops:)-1s2tp``
/// - ``active(loops:)-6nasn``
/// - ``active(every:offset:)``
/// - ``mute(_:)``
///
/// ### Section order
///
/// - ``shuffleSections()``
/// - ``shuffleSections(loops:)-4i8nk``
/// - ``shuffleSections(loops:)-1zgrg``
/// - ``shuffleSections(loops:)-5d6xe``
/// - ``shuffleSections(loops:)-7cjnk``
/// - ``shuffleSections(loops:)-7kt0x``
/// - ``shuffleSections(loops:)-lbdd``
/// - ``shuffleSections(every:offset:)``
public struct Track: Equatable, Codable, Identifiable {
    @_documentation(visibility: internal)
    public static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.name == rhs.name &&
        lhs.sections == rhs.sections &&
        lhs.instrument == rhs.instrument
        && lhs.volume == rhs.volume
        && lhs.activity == rhs.activity
        && lhs.sectionOrder == rhs.sectionOrder
        && lhs.shuffleLoops == rhs.shuffleLoops
        && lhs.muted == rhs.muted
    }

    @_documentation(visibility: internal)
    public var id: UUID = UUID()
    @_documentation(visibility: internal)
    public let name: String
    @_documentation(visibility: internal)
    public let sections: [Section]
    @_documentation(visibility: internal)
    public let instrument: Instrument?
    @_documentation(visibility: internal)
    public let volume: Double?
    @_documentation(visibility: internal)
    public let activity: LoopActivity?
    @_documentation(visibility: internal)
    public let sectionOrder: SectionOrder?
    @_documentation(visibility: internal)
    public let shuffleLoops: LoopActivity?
    @_documentation(visibility: internal)
    public let muted: Bool?

    @_documentation(visibility: internal)
    public var isMuted: Bool { muted == true }

    @_documentation(visibility: internal)
    public var duration: MusicTimeStamp {
        sections.serialWindows.last.map { $0.start + $0.duration } ?? 0
    }

    /// A track without an instrument of its own.
    ///
    /// A player uses its default sound, and a MIDI file sends no program change.
    ///
    /// - Parameters:
    ///   - name: What the track is called. A MIDI file names the track with it, so keep it distinct.
    ///   - content: The sections and loops, played one after another.
    public init(_ name: String, @SectionArrayBuilder _ content: () -> [Section]) {
        self.init(name: name, content)
    }

    @_documentation(visibility: internal)
    public init(name: String, @SectionArrayBuilder _ content: () -> [Section]) {
        self.name = name
        self.sections = content()
        self.instrument = TrackKeys.adopt(into: nil, track: name)
        self.volume = nil
        self.activity = nil
        self.sectionOrder = nil
        self.shuffleLoops = nil
        self.muted = nil
    }

    /// A track with an instrument.
    ///
    /// ```swift
    /// Track("drums", instrument: .drums(.tr808)) { Section { Kick("x... x...") } }
    /// ```
    ///
    /// - Parameters:
    ///   - name: What the track is called. A MIDI file names the track with it, so keep it distinct.
    ///   - instrument: What plays the track. See ``Instrument``.
    ///   - content: The sections and loops, played one after another.
    public init(_ name: String, instrument: Instrument,
                @SectionArrayBuilder _ content: () -> [Section]) {
        self.init(name: name, instrument: instrument, content)
    }

    @_documentation(visibility: internal)
    public init(name: String, instrument: Instrument,
                @SectionArrayBuilder _ content: () -> [Section]) {
        self.name = name
        self.sections = content()
        self.instrument = TrackKeys.adopt(into: instrument, track: name)
        self.volume = nil
        self.activity = nil
        self.sectionOrder = nil
        self.shuffleLoops = nil
        self.muted = nil
    }

    /// Gives the track its instrument after the block, instead of in the initializer.
    ///
    /// - Parameter instrument: What plays the track.
    /// - Returns: The track, changed.
    public func instrument(_ instrument: Instrument) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    /// Sets the track's level against the other tracks.
    ///
    /// It multiplies into every note's velocity, together with the session's volume.
    ///
    /// - Parameter level: `0` silent, `1` as written.
    /// - Returns: The track, changed.
    public func volume(_ level: Double) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: level, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    /// Reads the track's degrees in a key.
    ///
    /// A key written further in, on a section or a line, wins over this one.
    ///
    /// - Parameters:
    ///   - root: The key's first degree, as a pitch.
    ///   - mode: The scale built on the root.
    /// - Returns: The track, changed.
    public func key(_ root: Pitch, _ mode: ScaleMode) -> Track { key(Scale(root, mode)) }

    /// Reads the track's degrees in a scale.
    ///
    /// - Parameter scale: The scale the numbers in the track are degrees of.
    /// - Returns: The track, changed.
    public func key(_ scale: Scale) -> Track {
        return Track.__create(name: name, sections: sections.map { $0.key(scale) }, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    /// Moves a parameter across the track, with times as fractions of its length.
    ///
    /// `0` is the start of the track and `1` its end, so the curve keeps its shape when the track gets
    /// longer. The value holds before the first breakpoint and after the last, so one breakpoint
    /// is a constant. A value outside the target's range is clamped to it.
    ///
    /// ```swift
    /// Track("pad") { Section { "| Am | F | C | G |" } }.automate(.cutoff, over: [0: 400, 1: 6000])
    /// ```
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time a fraction of the track's length.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The track, changed.
    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Track {
        automating(target, breakpoints, timeScale: duration, curve: curve)
    }
    /// Moves a parameter across the track, with times in whole notes from its start.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in whole notes from the start of the track.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The track, changed.
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Track {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    /// Moves a parameter across the track, with times in bars from its start.
    ///
    /// Bars are measured in the session's time signature, the same one bar notation is read in.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in bars from the start of the track.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The track, changed.
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Track {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
    /// Moves a parameter across the track, with times in beats from its start.
    ///
    /// Beats are the session's time signature's note value: quarters in 4/4, eighths in 6/8.
    ///
    /// - Parameters:
    ///   - target: What moves. See ``AutomationTarget``.
    ///   - breakpoints: `[time: value]`, the time in beats from the start of the track.
    ///   - curve: How the value travels from one breakpoint to the next. See ``AutomationShape``.
    /// - Returns: The track, changed.
    public func automate(_ target: AutomationTarget, beats breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Track {
        automating(target, breakpoints, timeScale: 1.0 / Double(SectionBuilder.timeSignature.noteValue),
                   curve: curve)
    }

    private func automating(_ target: AutomationTarget, _ breakpoints: [Double: Double],
                            timeScale: MusicTimeStamp, curve shape: AutomationShape) -> Track {
        guard let curve = AutomationCurve.make(target, breakpoints, timeScale: timeScale, curve: shape)
        else { return self }

        guard target.isPerVoice else {
            let windows = sections.serialWindows
            return replacingSections(zip(sections, windows).map { section, window in
                guard !(section.automation ?? []).contains(where: { $0.target == target })
                else { return section }
                guard let slice = curve.sliced(from: window.start, length: window.duration)
                else { return section }
                var s = section
                s.automation = (section.automation ?? []) + [slice]
                return s
            })
        }

        return replacingSections(sections.map { section in
            var s = section
            s.notes = section.notes.map { note in
                guard let slice = curve.sliced(from: note.startTime, length: note.duration)
                else { return note }
                var n = note
                n.automation = (note.automation ?? []) + [slice]
                return n
            }
            return s
        })
    }

    /// Silences the track.
    ///
    /// The track keeps its place in the session, so the MIDI channels of the others do not move.
    ///
    /// - Parameter on: `true` silences the track, `false` plays it.
    /// - Returns: The track, changed.
    public func mute(_ on: Bool = true) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: on ? true : nil)
    }

    /// Plays the track's sections in a new order on every pass after the first.
    ///
    /// The first pass plays them as written. The order comes from ``Dice``, so it is the same on
    /// every build, and tracks with the same number of sections shuffle alike.
    ///
    /// - Returns: The track, changed.
    public func shuffleSections() -> Track {
        return withShuffle(nil)
    }

    /// Shuffles the order of the track's sections only on the passes you list.
    ///
    /// The other passes play the sections as written, so a fixed opener and closer can bracket
    /// the passes that move.
    ///
    /// - Parameter loops: The passes that shuffle, counting from 0.
    /// - Returns: The track, changed.
    public func shuffleSections(loops: [Int]) -> Track {
        return withShuffle(.set(loops))
    }

    /// Shuffles the order of the track's sections only on the passes in a closed range, such as `0...1`.
    ///
    /// The other passes play the sections as written.
    ///
    /// - Parameter loops: The passes that shuffle, counting from 0.
    /// - Returns: The track, changed.
    public func shuffleSections(loops: ClosedRange<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    /// Shuffles the order of the track's sections only on the passes in a half-open range, such as `0..<4`.
    ///
    /// The other passes play the sections as written.
    ///
    /// - Parameter loops: The passes that shuffle, counting from 0.
    /// - Returns: The track, changed.
    public func shuffleSections(loops: Range<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    /// Shuffles the order of the track's sections only on the passes from one on, such as `2...`.
    ///
    /// The other passes play the sections as written.
    ///
    /// - Parameter loops: The passes that shuffle, counting from 0.
    /// - Returns: The track, changed.
    public func shuffleSections(loops: PartialRangeFrom<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    /// Shuffles the order of the track's sections only on the passes up to and including one, such as `...3`.
    ///
    /// The other passes play the sections as written.
    ///
    /// - Parameter loops: The passes that shuffle, counting from 0.
    /// - Returns: The track, changed.
    public func shuffleSections(loops: PartialRangeThrough<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    /// Shuffles the order of the track's sections only on the passes before one, such as `..<4`.
    ///
    /// The other passes play the sections as written.
    ///
    /// - Parameter loops: The passes that shuffle, counting from 0.
    /// - Returns: The track, changed.
    public func shuffleSections(loops: PartialRangeUpTo<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    /// Shuffles the order of the track's sections on every `n`th pass.
    ///
    /// - Parameters:
    ///   - n: The period, in passes.
    ///   - offset: Which pass of each period shuffles, counting from 0.
    /// - Returns: The track, changed.
    public func shuffleSections(every n: Int, offset: Int = 0) -> Track {
        return withShuffle(.every(n, offset: offset))
    }

    private func withShuffle(_ loops: LoopActivity?) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: .shuffled, shuffleLoops: loops, muted: muted)
    }

    // MARK: - Arrangement

    /// Plays the track only on the passes in a closed range, such as `0...1`.
    ///
    /// Passes count from 0. On the other passes it is silent and the other tracks play on.
    ///
    /// - Parameter loops: The passes the track plays on.
    /// - Returns: The track, changed.
    public func active(loops: ClosedRange<Int>) -> Track {
        withActivity(.over(loops))
    }

    /// Plays the track only on the passes in a half-open range, such as `0..<4`.
    ///
    /// Passes count from 0. On the other passes it is silent and the other tracks play on.
    ///
    /// - Parameter loops: The passes the track plays on.
    /// - Returns: The track, changed.
    public func active(loops: Range<Int>) -> Track {
        withActivity(.over(loops))
    }

    /// Plays the track only on the passes from one on, such as `2...`.
    ///
    /// Passes count from 0. On the other passes it is silent and the other tracks play on.
    ///
    /// - Parameter loops: The passes the track plays on.
    /// - Returns: The track, changed.
    public func active(loops: PartialRangeFrom<Int>) -> Track {
        withActivity(.over(loops))
    }

    /// Plays the track only on the passes up to and including one, such as `...3`.
    ///
    /// Passes count from 0. On the other passes it is silent and the other tracks play on.
    ///
    /// - Parameter loops: The passes the track plays on.
    /// - Returns: The track, changed.
    public func active(loops: PartialRangeThrough<Int>) -> Track {
        withActivity(.over(loops))
    }

    /// Plays the track only on the passes before one, such as `..<4`.
    ///
    /// Passes count from 0. On the other passes it is silent and the other tracks play on.
    ///
    /// - Parameter loops: The passes the track plays on.
    /// - Returns: The track, changed.
    public func active(loops: PartialRangeUpTo<Int>) -> Track {
        withActivity(.over(loops))
    }

    /// Plays the track only on the passes you list.
    ///
    /// Passes count from 0, so `[0, 1, 4]` plays the first, second and fifth. On the other passes it is silent and the other tracks play on.
    ///
    /// - Parameter loops: The passes the track plays on.
    /// - Returns: The track, changed.
    public func active(loops: [Int]) -> Track {
        withActivity(.set(loops))
    }

    /// Plays the track on every `n`th pass.
    ///
    /// `active(every: 2)` plays the even passes, `active(every: 2, offset: 1)` the odd ones.
    /// On the other passes it is silent and the other tracks play on.
    ///
    /// - Parameters:
    ///   - n: The period, in passes. `2` is every other pass.
    ///   - offset: Which pass of each period plays, counting from 0.
    /// - Returns: The track, changed.
    public func active(every n: Int, offset: Int = 0) -> Track {
        withActivity(.every(n, offset: offset))
    }

    private func withActivity(_ activity: LoopActivity) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    @_documentation(visibility: internal)
    public func replacingSections(_ newSections: [Section]) -> Track {
        return Track.__create(name: name, sections: newSections, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    private static func __create(name: String, sections: [Section], instrument: Instrument? = nil, volume: Double? = nil, activity: LoopActivity? = nil, sectionOrder: SectionOrder? = nil, shuffleLoops: LoopActivity? = nil, muted: Bool? = nil) -> Track {
        return Track(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    private init(name: String, sections: [Section], instrument: Instrument? = nil, volume: Double? = nil, activity: LoopActivity? = nil, sectionOrder: SectionOrder? = nil, shuffleLoops: LoopActivity? = nil, muted: Bool? = nil) {
        self.name = name
        self.sections = sections
        self.instrument = instrument
        self.volume = volume
        self.activity = activity
        self.sectionOrder = sectionOrder
        self.shuffleLoops = shuffleLoops
        self.muted = muted
    }
}
