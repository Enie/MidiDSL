import Foundation

// MARK: - Phrase

public func Phrase(bars: Int, beats: Int = 4, subdivisions: Int = 1,
                   _ fill: (GridStep) -> String) -> String {
    let bars = max(0, bars), beats = max(1, beats), subdivisions = max(1, subdivisions)
    let perBar = beats * subdivisions
    let slots = (0..<(bars * perBar)).map { index in
        NotationToken.slot(fill(GridStep(bar: index / perBar,
                                         beat: (index % perBar) / subdivisions,
                                         sub: index % subdivisions,
                                         step: index % perBar,
                                         index: index)))
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

public struct Markov {

    public let order: Int

    public let slots: Int

    private let table: [[String]: [String]]

    private let starts: [[String]]

    private let settable: Set<String>

    private let alphabet: [String]

    // MARK: Learning from notation

    public init(from notation: String, order: Int = 1) {
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

    public init(_ transitions: [Int: [Int]], start: Int? = nil, slots: Int = 4) {
        var tokens: [String: [String]] = [:]
        for (from, to) in transitions {
            tokens[String(from)] = to.map(String.init)
        }
        self.init(tokens, start: start.map(String.init), slots: slots)
    }

    public init(_ transitions: [String: [String]], start: String? = nil, slots: Int = 4) {
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
        self.starts = start.map { [[$0]] } ?? stated
        self.alphabet = alphabet
        self.settable = Markov.settable(in: alphabet)
        self.slots = max(1, slots)
    }

    // MARK: Writing a melody

    public func melody(bars: Int, slots: Int? = nil, seed: Int = 0, open: Double = 0) -> String {
        let bars = max(0, bars)
        let perBar = max(1, slots ?? self.slots)
        let total = bars * perBar
        guard total > 0 else { return "" }
        guard !alphabet.isEmpty else {
            return NotationToken.barred(Array(repeating: "R", count: total), perBar: perBar)
        }

        let dice = Dice(seed: seed)
        var written: [String] = []
        var walked: [String] = []

        let start = dice.pick(starts, 1, 0) ?? [alphabet[0]]
        for token in start.prefix(total) {
            written.append(token)
            walked.append(token)
        }

        while written.count < total {
            let index = written.count
            let chosen = dice.pick(successors(after: walked), 2, index) ?? alphabet[0]
            if open > 0, dice.value([3, index]) < open,
               let set = openSet(from: successors(after: walked, remembering: 1), including: chosen) {
                written.append(set)
            } else {
                written.append(chosen)
            }
            walked.append(chosen)
        }

        return NotationToken.barred(written, perBar: perBar)
    }

    // MARK: Reading the chain back

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

        let openings = starts.compactMap(\.first).reduced()
        let opening: String?
        if openings.count == 1 {
            opening = literal(openings[0])
        } else if openings.count > 1 {
            opening = literal(openings[0])
            notes.append("// the phrase also opened on "
                         + openings.dropFirst().map(literal).joined(separator: ", ")
                         + " — a chart takes one start:")
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
        if let opening { tail += ", start: \(opening)" }
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

public enum Wave {

    public static func sine(cycles: Double = 1, span: Double = 1,
                            between band: ClosedRange<Double>,
                            depth: ClosedRange<Double> = 1...1,
                            phase: Double = 0, resolution: Int = 16) -> [Double: Double] {
        samples(count: max(2, Int((Double(resolution) * cycles).rounded())) + 1,
                cycles: cycles, span: span, band: band, depth: depth, phase: phase) { x in
            0.5 + 0.5 * cos(2 * Double.pi * x)
        }
    }

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

    public static func sawtooth(cycles: Double = 1, span: Double = 1,
                           between band: ClosedRange<Double>,
                           depth: ClosedRange<Double> = 1...1,
                           rising: Bool = false) -> [Double: Double] {
        edges(cycles: cycles, span: span, band: band, depth: depth) { cycle in
            rising ? [(0.0, 0.0), (1.0, 1.0)] : [(0.0, 1.0), (1.0, 0.0)]
        }
    }

    public static func square(cycles: Double = 1, span: Double = 1,
                              between band: ClosedRange<Double>,
                              depth: ClosedRange<Double> = 1...1,
                              duty: Double = 0.5) -> [Double: Double] {
        let d = min(max(duty, 0.01), 0.99)
        return edges(cycles: cycles, span: span, band: band, depth: depth) { _ in
            [(0.0, 1.0), (d, 1.0), (d, 0.0), (1.0, 0.0)]
        }
    }

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
