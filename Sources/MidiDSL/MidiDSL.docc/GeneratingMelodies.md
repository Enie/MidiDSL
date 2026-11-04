# Generating Melodies

Phrases computed slot by slot, and Markov chains over notation tokens.

## Overview

``Grid(bars:beats:subdivisions:_:)`` writes a drum lane one character at a time. ``Phrase(bars:beats:subdivisions:_:)`` and ``Markov`` do the same for notes: they write a *notation string*, one token per slot.

What comes back is the same text you would have typed between the quotes, so nothing downstream knows it was generated. ``Section/key(_:_:)`` still moves it, the parser still warns about it, and a MIDI file holds it like any other line. You can print one, read it, and paste it back into the score as a literal.

Everything here draws from ``Dice``. The same seed writes the same melody on every build and on every machine, which matters because a score is built again after every change: a melody that rerolled itself would change under your hands.

## Phrase

``Phrase(bars:beats:subdivisions:_:)`` calls your closure once per slot and writes the answers as bar notation. The closure is handed a ``GridStep``, the same value ``Grid(bars:beats:subdivisions:_:)`` hands out, so a melody and a drum lane can follow the same reasoning.

```swift
let line = Phrase(bars: 1, subdivisions: 2) { step in step.isOnBeat ? "1" : "-" }
// "| 1 - 1 - 1 - 1 - |": four quarters, written as eighths and ties
```

A bar has `beats × subdivisions` slots and divides evenly between them. Without `beats:` the session's time signature decides, so a phrase in 3/4 has three beats a bar. `subdivisions:` defaults to 1, one note per beat, because that is where a melody usually starts:

| `beats × subdivisions` in 4/4 | One slot is |
|---|---|
| 4 × 1 | a quarter |
| 4 × 2 | an eighth |
| 4 × 3 | a triplet eighth |
| 4 × 4 | a sixteenth |

Match `bars:` to the loop: if a session sets ``Session/loopBars(_:)`` to fewer bars, the tail never plays, and to more, the part is silent for the rest of the pass.

### What a slot may hold

The closure answers a string, so a slot can hold anything a bar can: a degree (`"3"`, `"1'"`), a note name (`"Eb4"`), a chord on a degree (`"6m"`), a stack (`"[1 3 5]"`), a note set (`"?(1 3 5)"`), a slide (`">5"`), `"-"` to hold the note before, or `"R"` to rest.

```swift
let comp = Phrase(bars: 2) { step in
    switch step.beat {
    case 0: return "[1 3 5]"
    case 2: return "?(1 3 5)"
    default: return "-"
    }
}
// "| [1 3 5] - ?(1 3 5) - | [1 3 5] - ?(1 3 5) - |"
```

An empty answer is a rest: `"| 1 R R R |"` is a quarter and three beats of silence, where `"-"` instead would make `"| 1 - - - |"`, one note a bar long. The slot is never dropped, so the part keeps its length.

An answer with several tokens is a group that shares the slot, which is how a tuplet fits in one beat:

```swift
let turn = Phrase(bars: 1) { step in step.beat == 1 ? "1 2 3" : "5" }
// "| 5 {1 2 3} 5 5 |": the second beat is a triplet
```

Give each generated part its own ``Dice/stream(_:)``, so two parts never move together:

```swift
let dice = Dice(seed: 3)
let lead    = dice.stream("lead")
let counter = dice.stream("counter")
let a = Phrase(bars: 4, subdivisions: 2) { step in lead.chance(0.5, at: step) ? "3" : "-" }
let b = Phrase(bars: 4, subdivisions: 2) { step in counter.chance(0.5, at: step) ? "5" : "-" }
```

## Markov chains

A ``Markov`` chain learns which token follows which in a phrase you like, then walks that table to write more of it.

```swift
let m = Markov(from: "1 2 3 5 | 5 3 2 1 | 1 3 5 3 - -", order: 2)
Section { m.melody(bars: 8, seed: 7) }.key(.D5, .dorian)
```

The states are notation *tokens*, not pitches. A hold `-` after a `3` is a transition like any other, so the chain learns the phrase's rhythm and articulation as much as its shape. A stack, a chord, a note set or a group counts as the one token it is written as.

### What it learns from a phrase

Learning is counting. Walk the phrase's tokens in order and, for each, note what came next:

```
Markov(from: "1 2 3 | 3 2 1")

tokens in order:    1  2  3  3  2  1
what followed:      1 → 2,  2 → 3,  3 → 3,  3 → 2,  2 → 1
at the end:         1 → 1,  1 → 3     (the phrase opens again)

collected:          1: [2, 1, 3]
                    2: [3, 1]
                    3: [3, 2]
```

A token that appears twice counts twice, once for each thing that followed it, so the phrase already holds the weights. `3 → 3` is there because the phrase has two 3s in a row across the barline: the chain reads straight through barlines.

The phrase's last token is followed by each way the phrase opens a bar, once each, so the walk never reaches a dead end. Here bars open on 1 and on 3. The seam is a transition like any other, so a melody can pass through it; if the ending should not lead back into an opening, do not end the phrase there.

The barlines do two other things. They set ``Markov/slots``, the commonest number of tokens in a bar, which ``Markov/melody(bars:slots:seed:open:ending:)`` writes per bar unless told otherwise. And they set the openings: a melody starts where some bar of the phrase started. A phrase without `|` is one bar, so its whole length becomes the bar length; write the bars in.

```swift
Markov(from: "1 2 | 3 5 | 1 2").slots     // 2
Markov(from: "1 2 3 5 6 7").slots         // 6: one bar of six
```

The chain can only write the tokens it read. One that never saw a 6 never writes one, and one learned from quarters never holds a note. If the melody feels narrow, widen the phrase: two more bars of material do more than any parameter.

### Order

`order:` is how many tokens of history a choice looks at. At 1 the chain asks "what followed this note?"; at 2, "what followed this pair?", which keeps the phrase's characteristic turns. More history means fewer choices, so the melody quotes the source for longer:

| | Longest stretch quoted from the source | Different melodies from 100 seeds |
|---|---|---|
| `order: 1` | about 6 slots | 100 |
| `order: 2` | about 9 slots | 89 |
| `order: 3` | about 10 slots | 78 |

Measured on the theme `"1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 2 | 3 3 2 1 | 2 1 - -"`, sixteen slots per melody. Start at 2; go to 1 when it sounds too much like the source, and to 3 when it sounds like nothing in particular.

The order is 1…4. Outside that range the chain uses the nearest order and the score warns.

When the walk reaches a context it has never seen, it drops one token of history and asks again, down to a single token and finally to every token it knows. So a high order is a preference, not a requirement, and the walk never stops in the middle of a bar. A melody opens on a context some bar of the phrase opened on, so its first `order` tokens are quoted.

On a short phrase a high order may leave nothing to choose:

```swift
let m = Markov(from: "1 2 3 | 3 2 1", order: 2)
m.melody(bars: 3, seed: 0)   // "| 1 2 3 | 3 2 1 | 3 3 2 |"
m.melody(bars: 3, seed: 4)   // "| 3 2 1 | 3 2 1 | 1 2 3 |"
```

### Stating the table

When you are designing the chain rather than sampling one, write the table: each degree, and the degrees that may follow it. A repeat is a weight, so below `1 → 2` comes up three times in four.

```swift
Markov([1: [2, 2, 2, 3],
        2: [1, 3],
        3: [2, 5, 1],
        5: [3, 6, 1]], start: 1)
```

A table has no bars, so it says the bar length with `slots:` (4 unless given) and where a melody begins with `start:`. With ``Markov/init(_:starts:slots:)-(_,[Int],_)``, `starts:` lists several openings, a repeat making one likelier. Left out, the seed picks among the degrees you listed.

The string form, ``Markov/init(_:start:slots:)-(_,String?,_)``, takes a table over any tokens: note names, chords, stacks, holds.

```swift
Markov(["[1 3 5]": ["2m7", "4maj7"],
        "2m7":     ["5dom7"],
        "5dom7":   ["[1 3 5]"],
        "4maj7":   ["5dom7"]], start: "[1 3 5]")
```

A stated table is always order 1. A token with no successors is left out, and a token named only as a successor is reachable but has no moves of its own: the walk backs off to every token it knows.

### From a phrase to a chart and back

``Markov/chart`` prints a chain as a table you can paste and edit. A chain also prints as its chart, so `print(m)` does the same.

```swift
print(Markov(from: "1 2 1 2 | 1 2 1 3").chart)
// Markov([1: [2, 2, 2, 3],
//         2: [1, 1, 1],
//         3: [1]], start: 1, slots: 4)
```

That is the move to make when you want one transition likelier. A phrase can only gain whole paths: writing another `1 2` into it also adds whatever follows that 2. A chart sets each move directly. Sketch with a phrase, print its chart, paste it over the `Markov(from:)` line and tune the weights.

The chart keeps every opening the phrase had, as `starts: [...]`, and the successors in the order they were counted, so the pasted chart writes the same melodies as the phrase. A chain of a higher order prints as its order-1 table, with a comment saying so, because a table of pairs cannot hold longer contexts.

```swift
print(Markov(from: "1 2 3 | 3 2 1").chart)
// Markov([1: [2, 1, 3],
//         2: [3, 1],
//         3: [3, 2]], starts: [1, 3], slots: 3)
```

### Keep decoration out of the tokens

A token's whole text is its state. A token that carries a rolled number, such as a strum time, is a state that occurs once: `"~0.137Cm"` and `"~0.088Cm"` are two unrelated states, and a chain learned from them can only replay the phrase.

Learn the clean harmony, and decorate the melody afterwards. It is an ordinary string, so a map over its tokens can add the voicing:

```swift
let harmony = Markov(from: "Cm - - R | Cm7 Fm7 - - | Bbdom7 - - -", order: 2)
let voicing = Dice(seed: 7).stream("voicing")

func voiced(_ notation: String) -> String {
    var slot = 0
    return notation.split(separator: " ").map { token -> String in
        guard token != "|" else { return "|" }
        defer { slot += 1 }
        guard let first = token.first, ("A"..."G").contains(String(first)) else { return String(token) }
        return "~\(String(format: "%.3f", 0.02 + voicing(slot) * 0.18))\(token)"
    }.joined(separator: " ")
}

let part = voiced(harmony.melody(bars: 4, seed: 3))
// "| ~0.020Cm7 ~0.033Fm7 - - | ~0.074Bbdom7 - - ~0.102Bbdom7 | …"
```

## Writing a melody

``Markov/melody(bars:slots:seed:open:ending:)`` walks the chain and writes `bars × slots` tokens of bar notation.

```swift
let theme = "1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 2 | 3 3 2 1 | 2 1 - -"
let m = Markov(from: theme, order: 2)
m.melody(bars: 4, seed: 7)               // "| 6 5 3 2 | 1 2 1 - | - 3 5 6 | 5 3 2 1 |"
m.melody(bars: 4, slots: 8, seed: 7)     // the same tokens, two bars of eighths
```

- term seed: The take. The same seed always writes the same melody; neighbouring seeds are unrelated draws. Two seeds can land on the same melody when the chain has few choices to make.
- term slots: Tokens per bar, the chain's own unless given. It cuts the same token stream into different bars: `bars: 4, slots: 4` and `bars: 2, slots: 8` write the same sixteen tokens, as quarters and as eighths.
- term ending: The tokens the melody may end on, such as `["1"]`. Only the last slot changes: it is chosen from what the chain would play there if any of those fit, and otherwise is the ending itself.
- term open: How much of the melody to leave to each pass, from 0 to 1. See below.

To roll from dice the rest of the score also uses, pass them instead of a seed: ``Markov/melody(bars:slots:dice:open:ending:)``.

```swift
let theme = "1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 2 | 3 3 2 1 | 2 1 - -"
let dice = Dice(seed: 7)
let lead = Markov(from: theme, order: 2).melody(bars: 8, dice: dice.stream("lead"))
```

A chain is a value, so one chain can write a tune, an answer and a bass line from the same material:

```swift
let m = Markov(from: "1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 2 | 3 3 2 1 | 2 1 - -", order: 2)
let tune   = m.melody(bars: 4, seed: 7)
let answer = m.melody(bars: 4, slots: 8, seed: 23, open: 0.4)
let bass   = m.melody(bars: 4, slots: 2, seed: 5)
```

## Leaving notes open

With `open:`, some slots are written as a note set of the chain's likeliest choices instead of one note. The set is fixed when the score is built; which member sounds is decided on each pass, so the tune keeps moving while it plays.

```swift
let m = Markov(from: "1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 2 | 3 3 2 1 | 2 1 - -", order: 2)
m.melody(bars: 4, seed: 7, open: 0.25)
// "| 6 5 ?(3 6) 2 | 1 2 1 - | - 3 5 6 | 5 3 2 1 |"
```

`open:` is a chance offered, not a share delivered: a slot can only open where the chain has at least two notes it would accept. Around 0.25 a tune stays recognisable and never repeats exactly; above 0.5 its shape starts to dissolve.

| `open:` | `order: 1` | `order: 2` | `order: 3` |
|---|---|---|---|
| 0 | 0% | 0% | 0% |
| 0.25 | 14% | 12% | 11% |
| 0.5 | 24% | 21% | 19% |
| 1 | 35% | 34% | 31% |

The share of slots that became sets, on the theme above.

A set holds the chain's own choice first, then up to two more candidates, commonest first. The walk continues from the first member, so the rest of the melody is the one the chain would have written anyway. The candidates are what could follow the last token alone, even at a higher order, because a long context usually has only one successor.

Only things that sound can be members: degrees, note names, chords and stacks, so a generated chord progression opens the same way a melody does. A hold, a rest or a slide is written as itself. The quoted opening never opens, and neither does the last slot of a melody with an `ending:`.

```swift
let changes = Markov(from: "1maj - 6m - | 4maj - 5dom7 -", order: 2)
changes.melody(bars: 4, seed: 3, open: 0.5)
// "| 1maj - 6m - | ?(4maj 6m 5dom7) - ?(5dom7 4maj 6m) - | …"
```

Each set rolls its own die, so two sets in one bar do not move together, and ``Session/seed(_:)`` changes all of those rolls at once.

## Fitting it into the song

Write the source in degrees and the melody is in degrees too, so a key at any level still moves it:

```swift
let m = Markov(from: "1 2 3 5 | 5 3 2 1", order: 2)
Track("lead") {
    Section { m.melody(bars: 4, seed: 7) }
    Section { m.melody(bars: 4, seed: 7) }.key(.A4, .minor)   // the same melody in another key
}
```

``Section/velocity(random:)`` and ``Section/durations(random:)`` add how hard and how long, and all three roll independently on every pass:

```swift
let m = Markov(from: "1 2 3 5 | 5 3 2 1", order: 2)
Section { m.melody(bars: 8, seed: 7, open: 0.25) }
    .velocity(random: 70...100)
    .durations(random: [.n8, .n4])
```

`print(m.melody(bars: 4, seed: 7))` shows a take, and pasting it into the score as a literal keeps it. Generate while you search; paste when you have found it.

A written melody shows you the tune; a generated one shows you the rules that made it. That is usually the better trade for eight bars of accompaniment, and the wrong one for a hook you want to see.

## Topics

- ``Markov``
- ``Phrase(bars:beats:subdivisions:_:)``
- ``GridStep``
- ``Dice``
