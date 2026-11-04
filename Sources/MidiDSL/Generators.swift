import Foundation

// MARK: - Phrase

/// Bar notation computed slot by slot, one token per slot.
///
/// `Phrase` calls `fill` once for every slot of every bar, in order, and writes the answers as
/// bar notation. The result is an ordinary notation string.
///
/// ```swift
/// let notes = Dice(seed: 4).stream("melody")
/// let line = Phrase(bars: 4, subdivisions: 2) { step in
///     if step.isLastBar && step.isLastBeat { return step.isOnBeat ? "1" : "-" }
///     return notes.pick("1", "2", "3", "5", "6", at: step)
/// }
/// ```
///
/// An answer with a space in it, such as `"[1 3 5]"` or `"1 3"`, is one slot: a space inside
/// brackets is a chord, and anything else is grouped so it shares the slot. An empty answer is
/// a rest.
///
/// - Parameters:
///   - bars: How many bars to write. `0` writes an empty string.
///   - beats: Beats per bar. Left out, the session's time signature decides.
///   - subdivisions: Slots per beat. `1` gives one token per beat, `2` two.
///   - fill: Answers the token for one slot: a degree, a note name, a chord, `-` to hold or `R`.
/// - Returns: Bar notation with `beats × subdivisions` tokens per bar.
///
/// See <doc:GeneratingParts>.
public func Phrase(bars: Int, beats: Int? = nil, subdivisions: Int = 1,
                   _ fill: (GridStep) -> String) -> String {
    let bars = max(0, bars), subdivisions = max(1, subdivisions)
    let beats = max(1, beats ?? SectionBuilder.timeSignature.beatsPerBar)
    let perBar = beats * subdivisions
    let slots = (0..<(bars * perBar)).map { index in
        NotationToken.slot(fill(GridStep(bar: index / perBar,
                                         beat: (index % perBar) / subdivisions,
                                         sub: index % subdivisions,
                                         bars: bars, beats: beats, subdivisions: subdivisions)))
    }
    return NotationToken.barred(slots, perBar: perBar)
}

enum NotationToken {

    static func slot(_ answer: String) -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "R" }
        return hasTopLevelSpace(trimmed) ? "{\(trimmed)}" : trimmed
    }

    static func barred(_ tokens: [String], perBar: Int) -> String {
        guard !tokens.isEmpty else { return "" }
        let bars = stride(from: 0, to: tokens.count, by: perBar).map { start in
            tokens[start..<min(start + perBar, tokens.count)].joined(separator: " ")
        }
        return "| " + bars.joined(separator: " | ") + " |"
    }

    static func hasTopLevelSpace(_ text: String) -> Bool {
        var depth = 0
        for character in text {
            switch character {
            case "(", "[", "{": depth += 1
            case ")", "]", "}": depth -= 1
            case " " where depth <= 0: return true
            default: break
            }
        }
        return false
    }

    static func canJoinSet(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        if ["-", "R", "r", "_"].contains(token) { return false }
        if token.contains(">") || token.contains("^") { return false }
        if token.hasPrefix("?") || token.hasPrefix("(") || token.hasPrefix("{") || token.hasPrefix("~") {
            return false
        }
        let parsed = SectionBuilder.parseNotationWithWarnings("|" + token + "|")
        return parsed.warnings.isEmpty && parsed.notes.contains { $0.pitch != nil }
    }
}

extension Array where Element: Hashable {
    func reduced() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Markov

/// A melody generator that learns from a phrase you write.
///
/// Give it a phrase in notation and it counts which token followed which; ``melody(bars:slots:seed:open:ending:)``
/// then walks that table and writes new notation in the same idiom. The states are tokens, not
/// pitches, so a tie or a rest is learned like a note, and the rhythm comes along with the shape.
///
/// ```swift
/// let theme = Markov(from: "| 1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 - |", order: 2)
///
/// Track("lead") {
///     Section { theme.melody(bars: 8, seed: 7, ending: ["1"]) }.key(.D5, .dorian)
/// }
/// ```
///
/// The same seed writes the same melody every time. Write the phrase in degrees and `.key(…)`
/// still moves the result. To set the transitions yourself instead of learning them, state the
/// table (``init(_:start:slots:)-(_,Int?,_)``), or print a learned one with ``chart`` and edit it.
///
/// See <doc:GeneratingMelodies>.
///
/// ## Topics
///
/// ### Learning from a phrase
/// - ``init(from:order:)``
///
/// ### Stating the table
/// - ``init(_:start:slots:)-(_,Int?,_)``
/// - ``init(_:starts:slots:)-([Int:[Int]],_,_)``
/// - ``init(_:start:slots:)-(_,String?,_)``
/// - ``init(_:starts:slots:)-([String:[String]],_,_)``
///
/// ### Writing a melody
/// - ``melody(bars:slots:seed:open:ending:)``
/// - ``melody(bars:slots:dice:open:ending:)``
///
/// ### Reading it back
/// - ``chart``
/// - ``order``
/// - ``slots``
public struct Markov: CustomStringConvertible {

    /// How many tokens of history each choice looks at: 1 to 4.
    public let order: Int

    /// Notes per bar the chain writes unless told otherwise: the commonest bar length in the
    /// phrase it learned from, or the `slots:` a stated table gave.
    public let slots: Int

    private let table: [[String]: [String]]

    private let starts: [[String]]

    private let settable: Set<String>

    private let alphabet: [String]

    // MARK: Learning from notation

    /// A chain learned from a phrase.
    ///
    /// ```swift
    /// let m = Markov(from: "| 1 2 3 5 | 5 3 2 1 | 1 3 5 3 - - |", order: 2)
    /// ```
    ///
    /// - Parameters:
    ///   - notation: The phrase, in ordinary notation. Its tokens are the only ones the chain can
    ///     write, how often each follows another is the weighting, and its `|` set the bar length
    ///     and where a melody may begin.
    ///   - order: How many tokens of history a choice looks at, 1 to 4. 1 wanders, 2 keeps the
    ///     phrase's turns, 3 nearly quotes it. A value outside 1…4 is brought into range and the
    ///     score warns.
    public init(from notation: String, order: Int = 1) {
        if order < 1 || order > 4 {
            ScoreAdvisories.note(SessionAdvisory(message:
                "Markov(order: \(order)) is outside 1…4, so the chain uses order \(max(1, min(order, 4)))."))
        }
        let order = max(1, min(order, 4))
        let bars = Markov.bars(of: notation)

        var table: [[String]: [String]] = [:]
        var starts: [[String]] = []
        var alphabet: [String] = []
        var barLengths: [Int] = []

        var stream: [String] = []
        var openings: [String] = []
        for bar in bars {
            guard !bar.isEmpty else { continue }
            barLengths.append(bar.count)
            if bar.count >= order {
                starts.append(Array(bar.prefix(order)))
            }
            openings.append(bar[0])   // reduced below: how it opens, not how often
            stream.append(contentsOf: bar)
        }
        alphabet = stream

        // The stream is read straight through, and its end is a phrase ending
        // rather than a wrap. Reading it as a circle put one edge in the chain
        // that the source never played — its last token back to its first —
        // and wherever that token appeared nowhere else that edge was the only
        // way out, so every walk arriving there left the same way, every time.
        // What a source that has run out does instead is open another phrase,
        // so the last token continues to the openings the source used — each
        // distinct one once, because the source ended once and what it knows
        // is how to open, not how often. A source that opens every bar the
        // same way therefore reads exactly as it did before; one that opens
        // them differently now has a choice where it used to have an edge.
        let count = stream.count
        let restarts = openings.reduced()
        for index in 0..<count {
            let next = index + 1 < count ? [stream[index + 1]] : restarts
            for length in 1...min(order, index + 1) {
                let context = Array(stream[(index - length + 1)...index])
                table[context, default: []].append(contentsOf: next)
            }
        }

        self.order = order
        self.table = table
        self.starts = starts.isEmpty ? (stream.isEmpty ? [] : [[stream[0]]]) : starts
        self.alphabet = alphabet
        self.settable = Markov.settable(in: alphabet)
        self.slots = Markov.commonest(barLengths) ?? 4
    }

    // MARK: Stating the table

    /// A chain over degrees, stated as a table.
    ///
    /// Each degree lists the degrees that may follow it. Listing one twice makes it twice as
    /// likely; there is no other way to weight a transition.
    ///
    /// ```swift
    /// Markov([1: [2, 2, 3],
    ///         2: [1, 3],
    ///         3: [1]], start: 1)
    /// ```
    ///
    /// - Parameters:
    ///   - transitions: Each degree, and the degrees that may follow it.
    ///   - start: The degree every melody begins on. Left out, the seed picks among the
    ///     degrees you listed.
    ///   - slots: Notes per bar, since a table has no bars to learn it from.
    public init(_ transitions: [Int: [Int]], start: Int? = nil, slots: Int = 4) {
        self.init(transitions, starts: start.map { [$0] } ?? [], slots: slots)
    }

    /// A chain over degrees, stated as a table, with a choice of where to begin.
    ///
    /// ```swift
    /// Markov([1: [2, 3], 2: [1, 3], 3: [1]], starts: [1, 1, 3])   // 1 twice as often as 3
    /// ```
    ///
    /// - Parameters:
    ///   - transitions: Each degree, and the degrees that may follow it.
    ///   - starts: The degrees a melody may begin on, each as likely as the next.
    ///     List one twice to make it likelier. Empty, the seed picks among the degrees you listed.
    ///   - slots: Notes per bar, since a table has no bars to learn it from.
    public init(_ transitions: [Int: [Int]], starts: [Int], slots: Int = 4) {
        var tokens: [String: [String]] = [:]
        for (from, to) in transitions {
            tokens[String(from)] = to.map(String.init)
        }
        self.init(tokens, starts: starts.map(String.init), slots: slots)
    }

    /// A chain over any notation tokens, stated as a table: note names, chords, stacks, ties.
    ///
    /// ```swift
    /// Markov(["Cm7": ["Fm7", "Bbdom7"], "Fm7": ["Bbdom7"], "Bbdom7": ["Cm7"]], start: "Cm7")
    /// ```
    ///
    /// - Parameters:
    ///   - transitions: Each token, and the tokens that may follow it.
    ///   - start: The token every melody begins on. Left out, the seed picks among the
    ///     tokens you listed.
    ///   - slots: Notes per bar, since a table has no bars to learn it from.
    public init(_ transitions: [String: [String]], start: String? = nil, slots: Int = 4) {
        self.init(transitions, starts: start.map { [$0] } ?? [], slots: slots)
    }

    /// A chain over any notation tokens, stated as a table, with a choice of where to begin.
    ///
    /// - Parameters:
    ///   - transitions: Each token, and the tokens that may follow it.
    ///   - starts: The tokens a melody may begin on, each as likely as the next.
    ///     List one twice to make it likelier. Empty, the seed picks among the tokens you listed.
    ///   - slots: Notes per bar, since a table has no bars to learn it from.
    public init(_ transitions: [String: [String]], starts: [String], slots: Int = 4) {
        var table: [[String]: [String]] = [:]
        var alphabet: [String] = []
        var stated: [[String]] = []
        for key in transitions.keys.sorted() {
            let successors = transitions[key] ?? []
            guard !successors.isEmpty else { continue }
            table[[key]] = successors
            stated.append([key])
            alphabet.append(key)
            alphabet.append(contentsOf: successors)
        }
        self.order = 1
        self.table = table
        self.starts = starts.isEmpty ? stated : starts.map { [$0] }
        self.alphabet = alphabet
        self.settable = Markov.settable(in: alphabet)
        self.slots = max(1, slots)
    }

    // MARK: Writing a melody

    /// Walks the chain and writes a melody, as bar notation.
    ///
    /// ```swift
    /// let m = Markov(from: "| 1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 - |")
    /// let fixed = m.melody(bars: 8, seed: 7)                  // a fixed melody
    /// let home  = m.melody(bars: 8, seed: 7, ending: ["1"])   // …that comes home
    /// let open  = m.melody(bars: 8, seed: 7, open: 0.25)      // …with a quarter left to each pass
    /// ```
    ///
    /// - Parameters:
    ///   - bars: How many bars to write.
    ///   - slots: Notes per bar. Left out, the chain's own ``slots``. Changing it re-bars the same
    ///     tokens rather than writing different ones.
    ///   - seed: The take. The same seed writes the same melody every time.
    ///   - open: How much of the melody to leave undecided, from 0 to 1. An open slot is written
    ///     as a `?(…)` set of the chain's likeliest choices, and a different member sounds on
    ///     each pass. Only a slot with alternatives can open, so 1 doesn't open every slot.
    ///   - ending: Tokens the melody must end on, such as `["1", "1'"]`. The last slot is chosen
    ///     among them — from what the chain would play there if it can, otherwise directly.
    ///     Empty, the melody ends wherever the walk is.
    /// - Returns: Bar notation, `bars × slots` tokens long.
    public func melody(bars: Int, slots: Int? = nil, seed: Int = 0, open: Double = 0,
                       ending: [String] = []) -> String {
        melody(bars: bars, slots: slots, dice: Dice(seed: seed), open: open, ending: ending)
    }

    /// Walks the chain and writes a melody, rolling from dice you give it.
    ///
    /// Use this to draw a melody from a stream the rest of the score also uses:
    ///
    /// ```swift
    /// let dice  = Dice(seed: 7)
    /// let chain = Markov(from: "| 1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 - |")
    /// let lead  = chain.melody(bars: 8, dice: dice.stream("lead"))
    /// ```
    ///
    /// - Parameters:
    ///   - bars: How many bars to write.
    ///   - slots: Tokens per bar. Left out, the chain's own ``slots``.
    ///   - dice: The dice to roll from.
    ///   - open: How much of the melody to leave undecided, from 0 to 1. An open slot is written
    ///     as a `?(…)` set of the chain's likeliest choices, and a different member sounds on
    ///     each pass.
    ///   - ending: Tokens the melody must end on, such as `["1", "1'"]`. Empty, the melody ends
    ///     wherever the walk is.
    /// - Returns: Bar notation, `bars × slots` tokens long.
    public func melody(bars: Int, slots: Int? = nil, dice: Dice, open: Double = 0,
                       ending: [String] = []) -> String {
        let bars = max(0, bars)
        let perBar = max(1, slots ?? self.slots)
        let total = bars * perBar
        guard total > 0 else { return "" }
        guard !alphabet.isEmpty else {
            return NotationToken.barred(Array(repeating: "R", count: total), perBar: perBar)
        }

        var written: [String] = []
        var walked: [String] = []

        let start = dice.pick(starts, 1, 0) ?? [alphabet[0]]
        for token in start.prefix(total) {
            written.append(token)
            walked.append(token)
        }

        while written.count < total {
            let index = written.count
            let isLast = index == total - 1
            var candidates = successors(after: walked)
            if isLast, !ending.isEmpty {
                let fitting = candidates.filter(ending.contains)
                candidates = fitting.isEmpty ? ending : fitting
            }
            let chosen = dice.pick(candidates, 2, index) ?? alphabet[0]
            if open > 0, !(isLast && !ending.isEmpty), dice.value([3, index]) < open,
               let set = openSet(from: successors(after: walked, remembering: 1), including: chosen) {
                written.append(set)
            } else {
                written.append(chosen)
            }
            walked.append(chosen)
        }

        if !ending.isEmpty, let last = written.last, !ending.contains(last) {
            // The opening filled the whole melody before the walk could choose an ending.
            written[written.count - 1] = dice.pick(ending, 2, written.count - 1) ?? last
        }
        return NotationToken.barred(written, perBar: perBar)
    }

    /// The chain's ``chart``.
    public var description: String { chart }

    // MARK: Reading the chain back

    /// The chain printed as a table you can paste back into the score and edit.
    ///
    /// Sketch with a phrase, print its chart, paste it over the `Markov(from:)` line, and adjust
    /// the weights by hand — something a phrase can't do, since it can only add whole paths.
    ///
    /// ```swift
    /// print(Markov(from: "| 1 2 1 2 | 1 2 1 3 |").chart)
    /// // Markov([1: [2, 2, 2, 3],
    /// //         2: [1, 1, 1],
    /// //         3: [1]], start: 1, slots: 4)
    /// ```
    ///
    /// A table is order 1 by nature, so a chain of a higher order prints as its order-1
    /// version, with a comment saying so.
    public var chart: String {
        var notes: [String] = []
        if order > 1 {
            notes.append("// order \(order) chain, printed as its order-1 chart:")
            notes.append("// the longer contexts it was keying on are not preserved")
        }

        var rows: [(key: String, successors: [String])] = []
        for token in orderedKeys() {
            guard let successors = table[[token]], !successors.isEmpty else { continue }
            rows.append((token, successors))
        }
        guard !rows.isEmpty else {
            return (["Markov([Int: [Int]](), slots: \(slots))",
                     "// nothing was learned — the chain is empty"] + notes).joined(separator: "\n")
        }

        let numeric = rows.allSatisfy { Markov.isPlainInteger($0.key)
            && $0.successors.allSatisfy(Markov.isPlainInteger) }
        func literal(_ token: String) -> String {
            numeric ? token : "\"\(token.replacingOccurrences(of: "\"", with: "\\\""))\""
        }

        let openings = starts.compactMap(\.first)
        let opening: String?
        if openings.reduced().count == 1 {
            opening = "start: " + literal(openings[0])
        } else if openings.count > 1 {
            opening = "starts: [" + openings.map(literal).joined(separator: ", ") + "]"
        } else {
            opening = nil
        }

        let width = rows.map { literal($0.key).count }.max() ?? 0
        let indent = String(repeating: " ", count: "Markov([".count)
        let body = rows.enumerated().map { index, row in
            let key = literal(row.key)
            let pad = String(repeating: " ", count: width - key.count)
            let list = "[" + row.successors.map(literal).joined(separator: ", ") + "]"
            return (index == 0 ? "" : indent) + key + ":" + pad + " " + list
        }.joined(separator: ",\n")

        var tail = ""
        if let opening { tail += ", \(opening)" }
        tail += ", slots: \(slots)"
        return (["Markov([" + body + "]" + tail + ")"] + notes).joined(separator: "\n")
    }

    private func orderedKeys() -> [String] {
        let keys = table.keys.filter { $0.count == 1 }.compactMap(\.first)
        if keys.allSatisfy(Markov.isPlainInteger) {
            return keys.sorted { (Int($0) ?? 0, $0) < (Int($1) ?? 0, $1) }
        }
        return keys.sorted()
    }

    static func isPlainInteger(_ token: String) -> Bool {
        !token.isEmpty && Int(token) != nil
    }

    // MARK: The walk

    private func successors(after walked: [String], remembering: Int? = nil) -> [String] {
        var length = min(remembering ?? order, walked.count)
        while length > 0 {
            let context = Array(walked.suffix(length))
            if let next = table[context], !next.isEmpty { return next }
            length -= 1
        }
        return alphabet
    }

    private func openSet(from candidates: [String], including chosen: String) -> String? {
        guard settable.contains(chosen) else { return nil }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for token in candidates where settable.contains(token) && token != chosen {
            if counts[token] == nil { order.append(token) }
            counts[token, default: 0] += 1
        }
        guard !order.isEmpty else { return nil }
        let ranked = order.sorted { left, right in
            let (l, r) = (counts[left] ?? 0, counts[right] ?? 0)
            if l != r { return l > r }
            return (order.firstIndex(of: left) ?? 0) < (order.firstIndex(of: right) ?? 0)
        }
        return "?(" + ([chosen] + ranked.prefix(2)).joined(separator: " ") + ")"
    }

    // MARK: Reading notation

    static func bars(of notation: String) -> [[String]] {
        notation.split(separator: "|", omittingEmptySubsequences: false).map {
            SectionBuilder.barTokens(String($0))
        }
    }

    static func settable(in alphabet: [String]) -> Set<String> {
        Set(alphabet).filter(NotationToken.canJoinSet)
    }

    static func commonest(_ values: [Int]) -> Int? {
        var counts: [Int: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        var best: Int? = nil
        for value in counts.keys.sorted() {
            if best == nil || (counts[value] ?? 0) > (counts[best!] ?? 0) { best = value }
        }
        return best
    }
}

// MARK: - Wave: breakpoints shaped like an oscillator

/// Automation breakpoints shaped like an oscillator: sine, triangle, sawtooth, square or random steps.
///
/// A wave is the `[time: value]` dictionary you would otherwise type, so it goes wherever
/// `automate` takes breakpoints, with any of its unit labels:
///
/// ```swift
/// "| 1 3 5 5 |".automate(.volume, over: Wave.sine(cycles: 8, between: 0.6...1.0))
/// Section { "| 1 3 5 8 |" }.automate(.cutoff, bars: Wave.triangle(cycles: 2, span: 8, between: 400...6000))
/// ```
///
/// Every wave starts at the top of its band, unless a phase moves it.
/// See <doc:Automation>.
///
/// ## Topics
///
/// ### Shapes
///
/// - ``sine(cycles:span:between:depth:phase:resolution:)``
/// - ``triangle(cycles:span:between:depth:phase:)``
/// - ``sawtooth(cycles:span:between:depth:rising:)``
/// - ``square(cycles:span:between:depth:duty:)``
/// - ``random(steps:span:between:depth:seed:)``
public enum Wave {

    /// A smooth wobble: a tremolo on `.volume`, a filter LFO on `.cutoff`.
    ///
    /// - Parameters:
    ///   - cycles: How many times the wave goes round in the span. `0.5` is half a cycle.
    ///   - span: The length the wave is written across, in the unit of the `automate` label it is
    ///     passed to: `1` for `over:`, a number of bars for `bars:`, of beats for `beats:`.
    ///   - band: The values the wave moves between, such as `0.6...1.0` for a tremolo or
    ///     `400...6000` for a filter sweep in hertz.
    ///   - depth: How far below the top of the band the wave reaches: `0` stays at the top,
    ///     `1` reaches the bottom. A range changes it across the span, so `0...1` fades the wave in.
    ///   - phase: Where in the cycle to start, in cycles. `0` starts at the top of the band,
    ///     `0.5` at the bottom.
    ///   - resolution: Breakpoints per cycle. The curve is straight between them.
    /// - Returns: Breakpoints, as `automate` takes them.
    public static func sine(cycles: Double = 1, span: Double = 1,
                            between band: ClosedRange<Double>,
                            depth: ClosedRange<Double> = 1...1,
                            phase: Double = 0, resolution: Int = 16) -> [Double: Double] {
        samples(count: max(2, Int((Double(resolution) * cycles).rounded())) + 1,
                cycles: cycles, span: span, band: band, depth: depth, phase: phase) { x in
            0.5 + 0.5 * cos(2 * Double.pi * x)
        }
    }

    /// Up and down in straight lines.
    ///
    /// - Parameters:
    ///   - cycles: How many times the wave goes round in the span. `0.5` is half a cycle.
    ///   - span: The length the wave is written across, in the unit of the `automate` label it is
    ///     passed to: `1` for `over:`, a number of bars for `bars:`, of beats for `beats:`.
    ///   - band: The values the wave moves between, such as `0.6...1.0` for a tremolo or
    ///     `400...6000` for a filter sweep in hertz.
    ///   - depth: How far below the top of the band the wave reaches: `0` stays at the top,
    ///     `1` reaches the bottom. A range changes it across the span, so `0...1` fades the wave in.
    ///   - phase: Where in the cycle to start, in cycles. `0` starts at the top of the band,
    ///     `0.5` at the bottom.
    /// - Returns: Breakpoints, as `automate` takes them.
    public static func triangle(cycles: Double = 1, span: Double = 1,
                                between band: ClosedRange<Double>,
                                depth: ClosedRange<Double> = 1...1,
                                phase: Double = 0) -> [Double: Double] {
        samples(count: max(2, Int((2 * cycles).rounded())) + 1,
                cycles: cycles, span: span, band: band, depth: depth, phase: phase) { x in
            let t = x.truncatingRemainder(dividingBy: 1)
            return t < 0.5 ? 1 - 2 * t : 2 * t - 1
        }
    }

    /// A ramp that snaps back at the end of each cycle.
    ///
    /// - Parameters:
    ///   - cycles: How many times the wave goes round in the span. `0.5` is half a cycle.
    ///   - span: The length the wave is written across, in the unit of the `automate` label it is
    ///     passed to: `1` for `over:`, a number of bars for `bars:`, of beats for `beats:`.
    ///   - band: The values the wave moves between, such as `0.6...1.0` for a tremolo or
    ///     `400...6000` for a filter sweep in hertz.
    ///   - depth: How far below the top of the band the wave reaches: `0` stays at the top,
    ///     `1` reaches the bottom. A range changes it across the span, so `0...1` fades the wave in.
    ///   - rising: `false` falls from the top and snaps back up, like a filter that opens on each
    ///     beat and closes. `true` climbs from the bottom and drops.
    /// - Returns: Breakpoints, as `automate` takes them.
    public static func sawtooth(cycles: Double = 1, span: Double = 1,
                           between band: ClosedRange<Double>,
                           depth: ClosedRange<Double> = 1...1,
                           rising: Bool = false) -> [Double: Double] {
        edges(cycles: cycles, span: span, band: band, depth: depth) { cycle in
            rising ? [(0.0, 0.0), (1.0, 1.0)] : [(0.0, 1.0), (1.0, 0.0)]
        }
    }

    /// On, off, on: a gate rather than a sweep.
    ///
    /// - Parameters:
    ///   - cycles: How many times the wave goes round in the span. `0.5` is half a cycle.
    ///   - span: The length the wave is written across, in the unit of the `automate` label it is
    ///     passed to: `1` for `over:`, a number of bars for `bars:`, of beats for `beats:`.
    ///   - band: The values the wave moves between, such as `0.6...1.0` for a tremolo or
    ///     `400...6000` for a filter sweep in hertz.
    ///   - depth: How far below the top of the band the wave reaches: `0` stays at the top,
    ///     `1` reaches the bottom. A range changes it across the span, so `0...1` fades the wave in.
    ///   - duty: The part of each cycle spent at the top, 0.01…0.99. `0.5` is even, `0.25` a short stab.
    /// - Returns: Breakpoints, as `automate` takes them.
    public static func square(cycles: Double = 1, span: Double = 1,
                              between band: ClosedRange<Double>,
                              depth: ClosedRange<Double> = 1...1,
                              duty: Double = 0.5) -> [Double: Double] {
        let d = min(max(duty, 0.01), 0.99)
        return edges(cycles: cycles, span: span, band: band, depth: depth) { _ in
            [(0.0, 1.0), (d, 1.0), (d, 0.0), (1.0, 0.0)]
        }
    }

    /// Sample and hold: a new level on every step, held until the next.
    ///
    /// The same seed always draws the same levels.
    ///
    /// - Parameters:
    ///   - steps: How many levels across the span.
    ///   - span: The length the wave is written across, in the unit of the `automate` label it is
    ///     passed to: `1` for `over:`, a number of bars for `bars:`, of beats for `beats:`.
    ///   - band: The values the wave moves between, such as `0.6...1.0` for a tremolo or
    ///     `400...6000` for a filter sweep in hertz.
    ///   - depth: How far below the top of the band the wave reaches: `0` stays at the top,
    ///     `1` reaches the bottom. A range changes it across the span, so `0...1` fades the wave in.
    ///   - seed: Which set of levels to draw. Change it to hear another.
    /// - Returns: Breakpoints, as `automate` takes them.
    public static func random(steps: Int, span: Double = 1,
                              between band: ClosedRange<Double>,
                              depth: ClosedRange<Double> = 1...1,
                              seed: Int = 1) -> [Double: Double] {
        guard steps > 0 else { return [:] }
        let dice = Dice(seed: seed)
        var result: [Double: Double] = [:]
        let step = span / Double(steps)
        for i in 0..<steps {
            let start = Double(i) * step
            let level = dice(0, i)
            result[start] = place(level, at: start / span, band: band, depth: depth)
            let end = start + step * (1 - 1e-6)
            result[end] = result[start]
        }
        return result
    }

    // MARK: shared shaping

    private static func samples(count: Int, cycles: Double, span: Double,
                                band: ClosedRange<Double>, depth: ClosedRange<Double>,
                                phase: Double,
                                _ unit: (Double) -> Double) -> [Double: Double] {
        guard count > 1, span > 0 else { return [:] }
        var result: [Double: Double] = [:]
        for i in 0..<count {
            let fraction = Double(i) / Double(count - 1)
            let level = unit(fraction * cycles + phase)
            result[fraction * span] = place(level, at: fraction, band: band, depth: depth)
        }
        return result
    }

    private static func edges(cycles: Double, span: Double,
                              band: ClosedRange<Double>, depth: ClosedRange<Double>,
                              _ corners: (Int) -> [(Double, Double)]) -> [Double: Double] {
        guard cycles > 0, span > 0 else { return [:] }
        let whole = max(1, Int(cycles.rounded(.up)))
        let cycleSpan = span / cycles
        var result: [Double: Double] = [:]
        var nudge = 0.0
        for cycle in 0..<whole {
            for (fraction, level) in corners(cycle) {
                var time = (Double(cycle) + fraction) * cycleSpan
                guard time <= span + 1e-12 else { continue }
                if result[time] != nil { nudge += 1; time += cycleSpan * 1e-6 * nudge }
                result[min(time, span)] = place(level, at: min(time, span) / span,
                                                band: band, depth: depth)
            }
        }
        return result
    }

    private static func place(_ level: Double, at fraction: Double,
                              band: ClosedRange<Double>, depth: ClosedRange<Double>) -> Double {
        let d = depth.lowerBound + (depth.upperBound - depth.lowerBound) * min(max(fraction, 0), 1)
        let excursion = (1 - min(max(level, 0), 1)) * min(max(d, 0), 1)
        return band.upperBound - (band.upperBound - band.lowerBound) * excursion
    }
}
