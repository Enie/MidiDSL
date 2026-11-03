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
/// See <doc:TracksAndArrangement>.
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

    public func tempo(_ tempo: Double) -> Track {
        return Track.__create(name: name, sections: sections.map { $0.tempo(tempo) }, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    public func instrument(_ instrument: Instrument) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    public func volume(_ level: Double) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: level, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    public func key(_ root: Pitch, _ mode: ScaleMode) -> Track { key(Scale(root, mode)) }

    public func key(_ scale: Scale) -> Track {
        return Track.__create(name: name, sections: sections.map { $0.key(scale) }, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: muted)
    }

    public func automate(_ target: AutomationTarget, over breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Track {
        automating(target, breakpoints, timeScale: duration, curve: curve)
    }
    public func automate(_ target: AutomationTarget, at breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Track {
        automating(target, breakpoints, timeScale: 1, curve: curve)
    }
    public func automate(_ target: AutomationTarget, bars breakpoints: [Double: Double],
                         curve: AutomationShape = .linear) -> Track {
        automating(target, breakpoints, timeScale: SectionBuilder.timeSignature.barDuration, curve: curve)
    }
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

    public func mute(_ on: Bool = true) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: sectionOrder, shuffleLoops: shuffleLoops, muted: on ? true : nil)
    }

    public func shuffleSections() -> Track {
        return withShuffle(nil)
    }

    public func shuffleSections(loops: [Int]) -> Track {
        return withShuffle(.set(loops))
    }

    public func shuffleSections(loops: ClosedRange<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    public func shuffleSections(loops: Range<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    public func shuffleSections(loops: PartialRangeFrom<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    public func shuffleSections(loops: PartialRangeThrough<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    public func shuffleSections(loops: PartialRangeUpTo<Int>) -> Track {
        return withShuffle(.over(loops))
    }

    public func shuffleSections(every n: Int, offset: Int = 0) -> Track {
        return withShuffle(.every(n, offset: offset))
    }

    private func withShuffle(_ loops: LoopActivity?) -> Track {
        return Track.__create(name: name, sections: sections, instrument: instrument, volume: volume, activity: activity, sectionOrder: .shuffled, shuffleLoops: loops, muted: muted)
    }

    // MARK: - Arrangement

    public func active(loops: ClosedRange<Int>) -> Track {
        withActivity(.over(loops))
    }

    public func active(loops: Range<Int>) -> Track {
        withActivity(.over(loops))
    }

    public func active(loops: PartialRangeFrom<Int>) -> Track {
        withActivity(.over(loops))
    }

    public func active(loops: PartialRangeThrough<Int>) -> Track {
        withActivity(.over(loops))
    }

    public func active(loops: PartialRangeUpTo<Int>) -> Track {
        withActivity(.over(loops))
    }

    public func active(loops: [Int]) -> Track {
        withActivity(.set(loops))
    }

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
