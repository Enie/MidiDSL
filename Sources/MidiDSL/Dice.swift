import Foundation

/// Chance that is the same on every run, for generating a part while you write it.
///
/// A `Dice` doesn't hand out numbers one after another. You ask it about a place, and the
/// answer depends only on the seed, the stream and the coordinates you give, so the same
/// score writes the same part every time it runs:
///
/// ```swift
/// let dice = Dice(seed: 7)
/// let ride = dice.stream("ride")
///
/// Lane(.ride, Grid(bars: 4) { step in
///     ride.chance(0.3, at: step) ? "x" : "."
/// })
/// ```
///
/// Give each part a stream of its own (``stream(_:)``). Two parts asking one stream about the
/// same step get the same answer and move together. Change the seed to hear another take.
///
/// These rolls happen while the score is built, so what they write is fixed material. For a
/// choice the music makes again on every pass — a `?` step, a `?(…)` set — see
/// <doc:DiceAndChance>.
///
/// ## Topics
///
/// ### Creating dice
/// - ``init(seed:)``
/// - ``stream(_:)``
///
/// ### Rolling at a grid step
/// - ``chance(_:at:)``
/// - ``pick(_:_:at:)-(T,T...,GridStep)``
/// - ``pick(_:at:)``
/// - ``int(in:at:)``
/// - ``callAsFunction(at:)``
///
/// ### Rolling at coordinates
/// - ``chance(_:_:_:)``
/// - ``pick(_:_:at:_:)``
/// - ``pick(_:_:_:)``
/// - ``int(in:_:_:)``
/// - ``callAsFunction(_:_:)``
/// - ``value(_:)``
public struct Dice {

    // MARK: - Composing: dice you roll while writing the piece

    @_documentation(visibility: internal)
    public let seed: UInt64

    /// Dice for one take.
    ///
    /// - Parameter seed: The take. Neighbouring seeds are unrelated draws, not nearby ones.
    ///   Keep it and the part never changes; change it to hear another.
    public init(seed: Int = 0) {
        self.seed = UInt64(bitPattern: Int64(seed))
    }

    private init(bits: UInt64) { self.seed = bits }

    /// Dice of their own for one part, derived from these.
    ///
    /// Rolls from one stream are independent of rolls from another, even at the same step,
    /// so a ride and a snare generated side by side don't start moving together. The name
    /// is only a label: the same name on the same dice always gives the same stream.
    ///
    /// ```swift
    /// let dice  = Dice(seed: 7)
    /// let ride  = dice.stream("ride")
    /// let snare = dice.stream("snare")
    /// ```
    ///
    /// - Parameter name: Any text that names the part.
    /// - Returns: Dice whose every answer differs from these dice's.
    public func stream(_ name: String) -> Dice {
        var h: UInt64 = 0xCBF29CE484222325          // FNV-1a over the UTF-8: stable everywhere
        for byte in name.utf8 { h = (h ^ UInt64(byte)) &* 0x100000001B3 }
        return Dice(bits: Dice.mix(seed ^ Dice.mix(h)))
    }

    // MARK: Coordinates

    /// A number in `0..<1` for these coordinates.
    ///
    /// The same coordinates give the same number every time, and their order matters:
    /// `dice(1, 2)` and `dice(2, 1)` are unrelated.
    ///
    /// ```swift
    /// let dice = Dice(seed: 3)
    /// let lift = dice(2, 1)     // bar 2, beat 1: the same number on every run
    /// ```
    ///
    /// - Parameters:
    ///   - first: The first coordinate, usually the bar. At least one is required, because
    ///     dice asked about nothing in particular would answer the same everywhere.
    ///   - rest: Further coordinates, such as the step.
    /// - Returns: A number from 0 up to, but not including, 1.
    public func callAsFunction(_ first: Int, _ rest: Int...) -> Double {
        value([first] + rest)
    }

    /// A number in `0..<1` for coordinates you already hold in an array.
    ///
    /// `dice.value([bar, step])` is `dice(bar, step)`.
    ///
    /// - Parameter coordinates: The coordinates, in order.
    /// - Returns: A number from 0 up to, but not including, 1.
    public func value(_ coordinates: [Int]) -> Double {
        var h = Dice.mix(seed &+ 0x9E3779B97F4A7C15)
        for coordinate in coordinates {
            h = Dice.mix(h ^ UInt64(bitPattern: Int64(coordinate)))
        }
        return Double(h >> 11) * (1.0 / Double(1 << 53))
    }

    /// Yes or no, true about `probability` of the time across the places you ask about.
    ///
    /// ```swift
    /// let fills = Dice(seed: 7).stream("fills")
    /// let fillBars = (0..<16).filter { bar in fills.chance(0.25, bar) }   // about one bar in four
    /// ```
    ///
    /// - Parameters:
    ///   - probability: How often the answer is true, from 0 to 1.
    ///   - first: The first coordinate.
    ///   - rest: Further coordinates.
    /// - Returns: Whether the roll at these coordinates came in under `probability`.
    public func chance(_ probability: Double, _ first: Int, _ rest: Int...) -> Bool {
        value([first] + rest) < probability
    }

    /// One of the options, each as likely as the others.
    ///
    /// Write an option twice to make it twice as likely.
    ///
    /// ```swift
    /// let accents = Dice(seed: 7).stream("accents")
    /// let hit = accents.pick("x", "x", "X", at: 3, 2)   // bar 3, beat 2
    /// ```
    ///
    /// - Parameters:
    ///   - first: An option.
    ///   - rest: The other options.
    ///   - coordinate: The first coordinate.
    ///   - more: Further coordinates.
    /// - Returns: The option the roll at these coordinates landed on.
    public func pick<T>(_ first: T, _ rest: T..., at coordinate: Int, _ more: Int...) -> T {
        let options = [first] + rest
        return options[index(count: options.count, value([coordinate] + more))]
    }

    /// One element of an array, each as likely as the others, or `nil` if it is empty.
    ///
    /// Use this form when the options are computed; ``pick(_:_:at:_:)`` takes them written out
    /// and never answers `nil`.
    ///
    /// - Parameters:
    ///   - options: The options.
    ///   - first: The first coordinate.
    ///   - rest: Further coordinates.
    /// - Returns: The element the roll at these coordinates landed on, or `nil` for an empty array.
    public func pick<T>(_ options: [T], _ first: Int, _ rest: Int...) -> T? {
        guard !options.isEmpty else { return nil }
        return options[index(count: options.count, value([first] + rest))]
    }

    /// A whole number in a range, both ends included.
    ///
    /// ```swift
    /// let shifts = Dice(seed: 2).stream("shift")
    /// let shift = shifts.int(in: -5...5, 4)    // a transposition for bar 4
    /// ```
    ///
    /// - Parameters:
    ///   - range: The numbers to choose from.
    ///   - first: The first coordinate.
    ///   - rest: Further coordinates.
    /// - Returns: A number in `range`.
    public func int(in range: ClosedRange<Int>, _ first: Int, _ rest: Int...) -> Int {
        integer(in: range, value([first] + rest))
    }

    // MARK: At a grid step

    /// A number in `0..<1` for a step of a `Grid` or `Phrase`.
    ///
    /// The same as asking at the step's bar and its position in the bar,
    /// `dice(step.bar, step.stepInBar)`.
    ///
    /// - Parameter step: The step a `Grid` or `Phrase` closure was handed.
    /// - Returns: A number from 0 up to, but not including, 1.
    public func callAsFunction(at step: GridStep) -> Double {
        value([step.bar, step.stepInBar])
    }

    /// Yes or no for a step of a `Grid` or `Phrase`, true about `probability` of the time.
    ///
    /// ```swift
    /// let ride = Dice(seed: 7).stream("ride")
    /// let grid = Grid(bars: 2) { step in ride.chance(0.3, at: step) ? "x" : "." }
    /// ```
    ///
    /// - Parameters:
    ///   - probability: How often the answer is true, from 0 to 1.
    ///   - step: The step a `Grid` or `Phrase` closure was handed.
    /// - Returns: Whether the roll at this step came in under `probability`.
    public func chance(_ probability: Double, at step: GridStep) -> Bool {
        callAsFunction(at: step) < probability
    }

    /// One of the options for a step of a `Grid` or `Phrase`.
    ///
    /// ```swift
    /// let hats = Dice(seed: 7).stream("hats")
    /// let grid = Grid(bars: 2) { step in step.isOnBeat ? "x" : hats.pick("o", ".", ".", at: step) }
    /// ```
    ///
    /// - Parameters:
    ///   - first: An option.
    ///   - rest: The other options.
    ///   - step: The step a `Grid` or `Phrase` closure was handed.
    /// - Returns: The option the roll at this step landed on.
    public func pick<T>(_ first: T, _ rest: T..., at step: GridStep) -> T {
        let options = [first] + rest
        return options[index(count: options.count, callAsFunction(at: step))]
    }

    /// One element of an array for a step of a `Grid` or `Phrase`, or `nil` if it is empty.
    ///
    /// - Parameters:
    ///   - options: The options.
    ///   - step: The step a `Grid` or `Phrase` closure was handed.
    /// - Returns: The element the roll at this step landed on, or `nil` for an empty array.
    public func pick<T>(_ options: [T], at step: GridStep) -> T? {
        guard !options.isEmpty else { return nil }
        return options[index(count: options.count, callAsFunction(at: step))]
    }

    /// A whole number in a range for a step of a `Grid` or `Phrase`, both ends included.
    ///
    /// - Parameters:
    ///   - range: The numbers to choose from.
    ///   - step: The step a `Grid` or `Phrase` closure was handed.
    /// - Returns: A number in `range`.
    public func int(in range: ClosedRange<Int>, at step: GridStep) -> Int {
        integer(in: range, callAsFunction(at: step))
    }

    private func index(count: Int, _ unit: Double) -> Int {
        min(count - 1, Int(unit * Double(count)))
    }

    private func integer(in range: ClosedRange<Int>, _ unit: Double) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + min(span - 1, Int(unit * Double(span)))
    }

    // MARK: - Varying: dice the machine rolls per pass

    @_documentation(visibility: internal)
    public static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    @_documentation(visibility: internal)
    public static func roll(salt: UInt64, loopIndex: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let value = mix(salt ^ mix(UInt64(bitPattern: Int64(loopIndex))))
        return Int(value % UInt64(count))
    }

    @_documentation(visibility: internal)
    public static func unit(salt: UInt64, loopIndex: Int) -> Double {
        let value = mix(salt ^ mix(UInt64(bitPattern: Int64(loopIndex))))
        return Double(value >> 11) * (1.0 / Double(1 << 53))
    }

    @_documentation(visibility: internal)
    public static func roll(salt: UInt64, loopIndex: Int, in range: ClosedRange<UInt32>) -> UInt32 {
        let span = Int(range.upperBound - range.lowerBound) + 1
        return range.lowerBound + UInt32(roll(salt: salt, loopIndex: loopIndex, count: span))
    }

    @_documentation(visibility: internal)
    public static func salt(_ parts: [UInt64], seed: UInt64 = 0x436F6D706F6E6975) -> UInt64 {
        var h = seed
        for part in parts { h = mix(h ^ part) }
        return h
    }

    @_documentation(visibility: internal)
    public enum Purpose: UInt64 {
        case pitch     = 0
        case velocity  = 0x76656C6F63697479
        case duration  = 0x6475726174696F6E
        case gate      = 0x67617465
    }

    @_documentation(visibility: internal)
    public static func salt(_ base: UInt64, for purpose: Purpose, seed: UInt64 = 0) -> UInt64 {
        var salt = purpose == .pitch ? base : mix(base ^ purpose.rawValue)
        if seed != 0 { salt = mix(salt ^ mix(seed)) }
        return salt
    }

    @_documentation(visibility: internal)
    public static func shuffled<T>(_ items: [T], salt: UInt64) -> [T] {
        guard items.count > 1 else { return items }
        var result = items
        var h = salt
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            h = mix(h)
            result.swapAt(i, Int(h % UInt64(i + 1)))
        }
        return result
    }
}

@_documentation(visibility: internal)
public enum DiceGate: Equatable, Hashable, Codable {
    case chance(Double, salt: UInt64? = nil)
    case member(Int, of: Int, salt: UInt64? = nil)
    case noteSet(member: Int, of: Int, mode: NoteSetMode)

    public func passes(loopIndex: Int, noteSalt: UInt64) -> Bool {
        switch self {
        case .chance(let probability, let salt):
            return Dice.unit(salt: salt ?? noteSalt, loopIndex: loopIndex) < probability
        case .member(let member, let count, let salt):
            return Dice.roll(salt: salt ?? noteSalt, loopIndex: loopIndex, count: count) == member
        case .noteSet(let member, let count, let mode):
            return mode.variantIndex(loopIndex: loopIndex, count: count, salt: noteSalt) == member
        }
    }
}

public extension Note {

    @_documentation(visibility: internal)
    func rolledOn(loopIndex: Int, seed: UInt64 = 0) -> Bool {
        guard let gate = dice else { return true }
        return gate.passes(loopIndex: rollPass(loopIndex),
                           noteSalt: Dice.salt(diceSalt, for: .gate, seed: seed))
    }

    @_documentation(visibility: internal)
    func resolvedVelocity(loopIndex: Int, seed: UInt64 = 0) -> UInt32 {
        guard let range = velocityChoices else { return velocity }
        return Dice.roll(salt: Dice.salt(diceSalt, for: .velocity, seed: seed),
                         loopIndex: rollPass(loopIndex), in: range)
    }

    @_documentation(visibility: internal)
    func resolvedDuration(loopIndex: Int, seed: UInt64 = 0) -> MusicTimeStamp {
        guard let choices = durationChoices, !choices.isEmpty else { return duration }
        let index = Dice.roll(salt: Dice.salt(diceSalt, for: .duration, seed: seed),
                              loopIndex: rollPass(loopIndex), count: choices.count)
        return choices[index]
    }

    @_documentation(visibility: internal)
    var longestDuration: MusicTimeStamp {
        max(duration, durationChoices?.max() ?? 0)
    }

    @_documentation(visibility: internal)
    var diceSalt: UInt64 {
        var parts: [UInt64] = [
            UInt64(bitPattern: Int64(sourceLine ?? 0)),
            UInt64(bitPattern: Int64(sourceColumn ?? 0)),
            UInt64(bitPattern: Int64(sourceOffset ?? -1)),
        ]
        if let loop {
            parts.append(contentsOf: [
                UInt64(bitPattern: Int64(loop.line)),
                UInt64(bitPattern: Int64(loop.column)),
                UInt64(bitPattern: Int64(loop.iteration)),
            ])
        }
        parts.append(contentsOf: (pitchVariants ?? []).map { UInt64($0) })
        return Dice.salt(parts)
    }

    @_documentation(visibility: internal)
    func rollPass(_ loopIndex: Int) -> Int {
        loopIndex &+ (loop?.iteration ?? 0)
    }
}
