import Foundation

/// Deterministic chance for generating a part while you write it.
///
/// `d(stream, bar, step)` answers a number in `0..<1` that depends only on the seed and the
/// coordinates, so the same score produces the same part on every run. See <doc:DiceAndChance>.
public struct Dice {

    // MARK: - Composing: dice you roll while writing the piece

    @_documentation(visibility: internal)
    public let seed: UInt64

    public init(seed: Int = 0) {
        self.seed = UInt64(bitPattern: Int64(seed))
    }

    public func callAsFunction(_ coordinates: Int...) -> Double {
        value(coordinates)
    }

    public func value(_ coordinates: [Int]) -> Double {
        var h = Dice.mix(seed &+ 0x9E3779B97F4A7C15)
        for coordinate in coordinates {
            h = Dice.mix(h ^ UInt64(bitPattern: Int64(coordinate)))
        }
        return Double(h >> 11) * (1.0 / Double(1 << 53))
    }

    public func chance(_ probability: Double, _ coordinates: Int...) -> Bool {
        value(coordinates) < probability
    }

    public func pick<T>(_ options: [T], _ coordinates: Int...) -> T? {
        guard !options.isEmpty else { return nil }
        return options[min(options.count - 1, Int(value(coordinates) * Double(options.count)))]
    }

    public func int(in range: ClosedRange<Int>, _ coordinates: Int...) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + min(span - 1, Int(value(coordinates) * Double(span)))
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
