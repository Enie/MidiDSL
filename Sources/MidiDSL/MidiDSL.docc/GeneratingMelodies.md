# Generating Melodies

Markov chains over notation tokens.

## Overview

Grid writes a drum lane one character at a time. Phrase and Markov do the same for notes, one level up: they write a *notation string*, one token per slot.

That is the whole design. What comes back is the same thing you would have typed between the quotes, so nothing downstream knows it was generated — .key(…) still moves it, the parser still warns about it, a MIDI file still holds it, and it sounds identical whether you generated it or wrote it out. You can print one, read it, and paste it back into the score as a literal.

Everything here draws from Dice, never from the clock. The same seed writes the same melody on every recompile, on every machine, and in the file you export — which matters more than it sounds when a host recompiles the score as you type. A melody that rerolled itself would change under your hands and export a take you never heard.

## Phrase: the numbers

### Phrase()

```swift
Phrase(bars: Int, beats: Int = 4, subdivisions: Int = 1, _ fill: (GridStep) -> String) -> String
```

- term `bars`: How many bars to lay out. Match it to .loopBars(…), as with Grid.
- term `beats`: Beats per bar — match your time signature, or the generated bars aren't the song's bars.
- term `subdivisions`: Slots per beat, which is the note value you get: 1 quarters, 2 eighths, 3 triplet eighths, 4 sixteenths. It defaults to 1 rather than Grid's 4 because that is where a melody usually starts.
- term `fill`: Called once per slot, in order; answers the notation token that slot holds. "" is a rest, and several tokens become a run group sharing the slot.

Calls fill once per slot, in order, and lays the answers out in bars with | between them and at both ends.

The three numbers multiply, and the closure is called exactly once per slot. bars: 0 gives an empty string; beats or subdivisions below 1 are treated as 1.

```swift
slots in a bar = beats × subdivisions
slots in all   = bars × beats × subdivisions

Phrase(bars: 2, beats: 4, subdivisions: 2) { … }
// 4 × 2 = 8 slots per bar, 16 calls in all
// → "| a a a a a a a a | a a a a a a a a |"
```

### What one slot is worth

A bar of notation divides evenly by however many tokens it holds, so beats × subdivisions is the note value you get — and nothing else decides it. The bar's own length comes from the session's .timeSignature(…); these numbers only say how finely to cut it.

subdivisions defaults to 1 rather than Grid's 4, because one note per beat is where a melody usually starts and sixteenths are where a hi-hat usually starts.

```swift
beats × subdivisions   one slot is
4 × 1  =  4            a quarter
4 × 2  =  8            an eighth
4 × 3  = 12            a triplet eighth
4 × 4  = 16            a sixteenth
3 × 2  =  6            an eighth in 3/4

// A bar of 4/4, eight slots: every slot is an eighth note.
Phrase(bars: 1, beats: 4, subdivisions: 2) { s in
    s.sub == 0 ? "1" : "-"
}
// → "| 1 - 1 - 1 - 1 - |"  — four quarters, written as ties
```

### Match beats to the meter

beats is beats per bar, so it has to agree with the session's time signature or the bars you generate will not be the bars the song counts. In 3/4 use beats: 3. Nothing enforces this — the string is just tokens, and the parser divides each bar by however many it finds — so a 4-beat phrase in a 3/4 session plays four notes in the time of three.

```swift
Session { … }.timeSignature(.threeFour)
Phrase(bars: 4, beats: 3, subdivisions: 2) { … }
```

### Match bars to the loop

Phrase lays out exactly the bars you ask for. If the session loops fewer bars than the phrase holds, the tail never plays; if it loops more, the part goes silent for the rest of the pass. Pass the same number to both.

```swift
let bars = 8
let lead = Phrase(bars: bars, subdivisions: 2) { … }
// …
.loopBars(bars)
```

## Phrase: the coordinates

### GridStep

```swift
s.bar, s.beat, s.sub, s.step, s.index, s.isDownbeat
```

The same value Grid hands out, so a melody and a drum lane can be written by the same reasoning. Every field is 0-based.

s.step and s.sub restart on every barline. s.index does not — which is what you key to when something should develop across the whole passage rather than repeat each bar. s.isDownbeat is just s.sub == 0.

```swift
s.bar    which bar, 0 ..< bars
s.beat   which beat of that bar, 0 ..< beats
s.sub    which subdivision of that beat, 0 ..< subdivisions
s.step   which slot of that bar, 0 ..< beats × subdivisions
s.index  which slot of the whole phrase, counting through bars

// bars: 2, beats: 2, subdivisions: 3 — twelve slots
// bar   0 0 0 0 0 0  1 1 1 1 1 1
// beat  0 0 0 1 1 1  0 0 0 1 1 1
// sub   0 1 2 0 1 2  0 1 2 0 1 2
// step  0 1 2 3 4 5  0 1 2 3 4 5
// index 0 1 2 3 4 5  6 7 8 9 10 11
```

### One stream per part

When two parts consult the dice with the same coordinates they get the same answers and move together, which sounds like one part doubled rather than two players. Give each its own leading number — the "stream" — exactly as drum lanes do.

```swift
let lead    = Phrase(…) { s in d.chance(0.5, 1, s.bar, s.step) ? "3" : "-" }
let counter = Phrase(…) { s in d.chance(0.5, 2, s.bar, s.step) ? "5" : "-" }
//                                          ↑ different stream
```

## Phrase: what a slot may hold

### Any token a bar can hold

The closure answers a String, not a Character, so a slot can hold anything notation can write there: a degree ("3", "1'", "5b"), a note name ("Eb4"), a chord on a degree ("6m", "5dom7"), a stack ("[1 3 5]"), a note set ("?(1 3 5)"), a slide (">5", "1>3"), "-" to tie into the slot, "R" to rest through it.

Mixing degrees and names in one phrase is fine — the degrees move when the key changes and the names do not, which is exactly what each is for.

```swift
Phrase(bars: 2) { s in
    switch s.beat {
    case 0: return "[1 3 5]"
    case 2: return "?(1 3 5)"
    default: return "-"
    }
}
// → "| [1 3 5] - ?(1 3 5) - | [1 3 5] - ?(1 3 5) - |"
```

### An empty answer is a rest

Return "" and the slot is written as R. It is not dropped: a slot that left nothing behind would make the section shorter, and the next section would start early — the same reason a rest is a real note everywhere else in notation.

"R" and "" mean the same thing here. "-" is different: it ties the slot onto the note before it, lengthening that note instead of leaving a gap.

```swift
Phrase(bars: 1) { s in s.beat == 0 ? "1" : "" }   // → "| 1 R R R |"
Phrase(bars: 1) { s in s.beat == 0 ? "1" : "-" }  // → "| 1 - - - |"
// the first is one quarter and three beats of silence,
// the second is one note a bar long
```

### Several tokens make a tuplet

Answer with more than one token and they are wrapped in a run group, { }, which shares the one slot between them. The slot divides by what is inside, so the count is the tuplet: two tokens halve it, three make a triplet, four make sixteenths of that beat.

This is the only way to change the rhythm *inside* a slot — raising subdivisions re-grids the whole phrase, a group re-grids one beat. Anything a bar can hold works inside the group, including rests and further groups.

```swift
Phrase(bars: 1) { s in s.beat == 1 ? "1 2 3" : "5" }
// → "| 5 {1 2 3} 5 5 |"
//   the second beat is a triplet, the rest are quarters
```

## Markov: from a phrase to a chart

### The two forms are the same thing

If the chart form makes sense to you, you already understand Markov(from:) — it writes that same chart for you, by counting.

Take the phrase apart into its tokens, walk them in order, and for each one write down what came next. That list of "what followed what" *is* the chart. Nothing else happens: there is no analysis of the music, no notion of key or interval. It counts pairs.

A token that appears twice contributes twice, once for each thing that followed it — which is where the weights come from. You never write the weights; the phrase already contains them.

```swift
Markov(from: "1 2 3 | 3 2 1", order: 1)

the tokens, in order:      1  2  3  3  2  1
                            ↘  ↘  ↘  ↘  ↘
what followed what:        1 → 2      (then the phrase ran
                           2 → 3       out, and a source that
                           3 → 3       has run out opens
                           3 → 2       another: this one opens
                           2 → 1       bars on 1 and on 3)
                           1 → 1
                           1 → 3

collected, that is:        1: [2, 1, 3]
                           2: [3, 1]
                           3: [3, 2]

which is exactly what you would have typed:

Markov([1: [2, 1, 3],
        2: [3, 1],
        3: [3, 2]], start: 1, slots: 3)

// Both write the same melodies for the same seeds:
// seed 1 → "| 1 2 1 | 2 3 2 |"
// seed 3 → "| 1 1 2 | 3 3 3 |"
```

### Reading the counts back

Three of the seven pairs above deserve a second look, because they are the things people expect to be cleverer than they are.

3 → 3 is there because the phrase really does have two 3s in a row, at the barline. The chain has no idea that is a barline; it saw a 3 followed by a 3 and wrote it down.

1 → 1 and 1 → 3 are the seam. The phrase has to end somewhere, and a source that has run out opens another one — so its last token is followed by each way the source opens a bar, once each. This phrase opens on 1 and on 3, so its ending has a choice; a source whose bars all open alike has exactly one.

### What a phrase gives you that a chart can't

Three things, which is why the chart form takes two extra arguments and the phrase form takes none.

The bar length: the | in the phrase say how many notes a bar holds, so melody(bars:) already knows. A chart has no bars in it, so you pass slots:.

The openings: a melody starts where a bar of the phrase started — here on 1 or on 3, never mid-figure. A chart has no notion of "the beginning", so you pass start:, or leave it out and let any named state open.

And the vocabulary: whatever tokens are in the phrase are the tokens it can write. That is the real reason the phrase form is usually the one to reach for — you get the material, the weights, the phrasing and the bar length from one line you can hear in your head.

The way back exists too: .chart prints the table a phrase derived, so you can sketch with a phrase and then tune it as a chart. That is the move to reach for when you want one transition likelier — a phrase can only add whole paths.

```swift
Markov(from: "1 2 3 | 3 2 1")     // bars, openings and weights, all from the phrase
Markov([1: [2, 1], …], start: 1, slots: 3)   // the same chart, said by hand
```

### What order does to the chart

order 1 keys the chart on a single token: "after a 3, what?" order 2 keys it on the *pair* that just happened: "after a 2 then a 3, what?" — and that is the whole difference.

Because there are more pairs than tokens, each key has fewer answers, so the melody follows the phrase further before it can branch. On the six-token phrase above, every pair has exactly one continuation, so order 2 has no choices left to make at all: it replays the phrase, every seed, forever. That is the extreme of the same effect a longer phrase shows as "sounds more like the source".

```swift
Markov(from: "1 2 3 | 3 2 1", order: 2)

keyed on pairs:   (1,2) → 3      every pair inside the
                  (2,3) → 3      phrase has one answer,
                  (3,3) → 2      so nothing is chosen
                  (3,2) → 1      until the ending, where
                  (2,1) → 1      the phrase opens again
                  (2,1) → 3      — on 1 or on 3

m.melody(bars: 3, seed: 0)  // "| 1 2 3 | 3 2 1 | 3 3 2 |"
m.melody(bars: 3, seed: 4)  // "| 3 2 1 | 3 2 1 | 1 2 3 |"
```

### .chart

```swift
chart: String
```

The chain printed back as a chart you can paste and edit — the bridge between the two forms, and the answer to the one thing a phrase cannot do.

A phrase is a closed walk, so you can only add whole *paths* to it: writing another "1 2" in to make that transition likelier also drags in whatever follows that 2. A chart sets edges directly. So sketch with a phrase, print its chart, paste it over the Markov(from:) line, and tune the weights by hand from there.

The successors come back in the order they were counted, so the pasted chart writes the same melodies. Sorting a list yourself is safe for the distribution — a successor is drawn evenly from the list — but it changes which melody a given seed writes.

Two things a chart cannot hold, and the print says so in comments after the expression (after, so that `let m = ` plus the paste is still Swift): a chart is order 1 by construction, so a higher-order chain prints as its order-1 projection; and it takes one start:, where a phrase knows every place a bar of it began.

```swift
print(Markov(from: "1 2 1 2 | 1 2 1 3").chart)

Markov([1: [2, 2, 2, 3],
        2: [1, 1, 1],
        3: [1]], start: 1, slots: 4)

// …then paste it and move a weight:
let m = Markov([1: [2, 2, 3],   // 1 → 2 twice in three now
                2: [1, 1, 1],
                3: [1]], start: 1, slots: 4)
```

## Markov: what it learns

### Markov()

```swift
Markov(from: String, order: Int = 1)
```

- term `from`: The phrase to learn from, as ordinary notation. Its tokens are the only ones the chain can write, how often each pair occurs is the weighting, and its | set both the bar length and where a melody may open.
- term `order`: How many tokens of history a choice looks at, clamped to 1–4. 1 wanders freely, 2 keeps the source's turns of phrase, 3 nearly quotes it. A context the chain has never seen backs off to a shorter one, so a high order costs variety rather than correctness.

Write a phrase you like and the chain writes more of it. It counts, for every token in the source, which tokens followed it — then walks that table.

The states are notation *tokens*, not pitches. A tie "-" after a "3" is a transition like any other, so what it learns is the source's rhythm and phrasing as much as its shape, and it needs to know nothing about music to do it. A stack, a chord, a note set or a run group each count as the single token they sound as.

```swift
let m = Markov(from: "1 2 3 5 | 5 3 2 1 | 1 3 5 3 - -", order: 2)
Section { m.melody(bars: 8, seed: 7) }.key(.D5, .dorian)
```

### It can only write what it read

The alphabet is exactly the set of tokens in the source. A chain that never saw a 6 will never write one; a chain whose source is all quarters will never write a tie. If the melody feels too narrow, widen the source rather than the numbers — two more bars of material does more than any parameter here.

How often a token appears in the source is how often it comes up, and the same goes for each transition. The source is the weighting.

### Keep decoration out of the state

The chain's states are the literal token *texts*. So anything you write into a token becomes part of what the chain is matching on — and a token that carries a rolled number is a state that occurs exactly once.

This is the trap: "~0.137Cm" and "~0.088Cm" are two unrelated states, not one chord voiced two ways. A chain built from them has nowhere to return to, every state has one successor, and it can only replay the phrase. Worse, with Double.random the token texts change on every recompile, so it is a different chain every time the score is compiled.

Chain the harmony; decorate afterwards. The melody comes back as an ordinary String, so a map over its tokens can add the voicing — rolled from Dice, keyed to the slot, so it is the same on every recompile and in the file you export.

```swift
// The chain sees clean chords, and can return to Cm.
let harmony = Markov(from: "Cm - - r | Cm7 Fm7 - - | Bbdom7 - - -", order: 2)

let d = Dice(seed: 7)
func voiced(_ notation: String) -> String {
    var slot = 0
    return notation.split(separator: " ").map { token -> String in
        guard token != "|" else { return "|" }
        defer { slot += 1 }
        guard let f = token.first, ("A"..."G").contains(String(f)) else {
            return String(token)
        }
        return "~\(String(format: "%.3f", 0.02 + d(1, slot) * 0.18))\(token)"
    }.joined(separator: " ")
}

Section { voiced(harmony.melody(bars: 4, seed: 3)) }
// | ~0.054Cm7 ~0.066Fm7 - - | ~0.166Bbdom7 - - ~0.150Bbdom7 | …
```

### The end of the source opens a new phrase

The source is read straight through, and its last token is followed by each way the source opens a bar — once each, since it ended once and what it knows is how to open, not how often. Something has to follow it: a final token with nowhere to go is a dead end, which is how a chain learned from a phrase ending in two ties came out as eight bars of tie.

One consequence worth knowing: the seam is a transition like any other, so a melody may pass through it. If the ending should not lead back into an opening, don't end the source there.

### Barlines set the bar length, not the phrasing

The chain reads straight through the barlines — a melody's phrasing crosses them, and a chain that reset each bar would only ever learn how a bar begins. The | do two other things instead.

They set .slots: the number of tokens in the commonest bar of the source, which is what melody(bars:) lays out per bar unless you say otherwise. A source with no | at all counts as one bar, so its whole length becomes the bar length — usually not what you want, so write the bars in.

And they set the openings: a melody starts on a context some bar of the source started on, so it begins where a bar begins rather than in the middle of a turn of phrase.

```swift
Markov(from: "1 2 | 3 5 | 1 2").slots      // 2
Markov(from: "1 2 3 5 6 7").slots          // 6 — one bar of six
```

## Markov: order

### order:

```swift
order: Int = 1  (clamped to 1…4)
```

How many tokens of history a choice looks at. It is the one knob that decides how much the output is *the source* and how much it is *like* the source.

order 1 asks "what followed this note?" — the most freedom, and the least memory of the source's turns of phrase. order 2 asks "what followed this pair?", which is enough to keep the source's characteristic moves. order 3 usually has one answer for each context and reproduces long stretches verbatim.

Start at 2. Go to 1 when it sounds too much like the source, to 3 when it sounds like nothing in particular.

```swift
let theme = "1 2 3 5 | 6 5 3 2 | 3 5 6 5 | 3 2 1 2 | 3 3 2 1 | 2 1 - -"

// Measured on that six-bar theme, sixteen slots per melody, seeds 0–99:
//
//          longest run quoted    different melodies
//          from the source       over 100 seeds
// order 1  about 6 slots         100
// order 2  about 9 slots          89
// order 3  about 10 slots         78
```

### Longer memories back off

When a context of the full length has never been seen — which happens as soon as the walk leaves the source's own paths — the chain drops one token and asks again, down to a single token, and finally to the whole alphabet. So a high order is a *preference* for a long memory, not a requirement, and the walk can never stop in the middle of a bar.

This is also why an order larger than the source can support costs nothing but variety: it simply backs off more often.

### The first notes come from the source

A melody opens on a context that some bar of the source opened on, chosen by the seed — so the first `order` tokens are quoted, and the walk starts after them. With order 3 that is three written notes before the chain has said anything of its own, which is another reason a high order sounds close to home.

## Markov: stating the table

### Markov()

```swift
Markov([Int: [Int]], start: Int? = nil, slots: Int = 4)
```

- term `start`: The degree every melody opens on. Left out, the seed picks among all the degrees you named — useful when several parts share one table.
- term `slots`: Notes per bar, which a chart has no way to imply. It is only the default for melody(bars:), which can override it.

When you are designing the chain rather than sampling one, write it out: each degree, and the degrees that may follow it. This form is always order 1 — a table of pairs is what order 1 means.

A repeat is a weight. The successors are drawn evenly from the list as written, so a token listed three times out of four comes up three quarters of the time — measured, exactly 0.75. There is no separate probability type; the list is the distribution.

```swift
Markov([1: [2, 2, 2, 3],   // 1 → 2 three quarters, 1 → 3 one quarter
        2: [1, 3],         // evenly
        3: [2, 5, 1],
        5: [3, 6, 1]], start: 1)
```

### start: and slots:

start is the degree every melody opens on. Leave it out and the seed picks among all the degrees you named — useful when several parts share a table and should not all begin the same way.

slots is the bar length, which a stated table has no way to infer; it defaults to 4. It is only the default for melody(bars:), which can override it.

A degree with an empty successor list is dropped, and a degree named only as a successor is reachable but has no transitions of its own — the walk backs off to the alphabet when it lands there.

### Any token, not just degrees

```swift
Markov([String: [String]], start: String? = nil, slots: Int = 4)
```

- term `start`: The token every melody opens on. Left out, the seed picks among all the tokens you named.
- term `slots`: Notes per bar — the default melody(bars:) uses when it isn't told otherwise.

The String form takes the same table over any tokens — note names, chords, stacks, ties, rests — for when the states are not plain degrees. Everything else behaves identically.

```swift
Markov(["[1 3 5]": ["2m7", "4maj7"],
        "2m7":     ["5dom7"],
        "5dom7":   ["[1 3 5]"],
        "4maj7":   ["5dom7"]], start: "[1 3 5]")
```

## melody(): the numbers

### .melody()

```swift
melody(bars: Int, slots: Int? = nil, seed: Int = 0, open: Double = 0) -> String
```

- term `bars`: How many bars to write. bars × slots is the number of tokens, and the only relationship between the two.
- term `slots`: Notes per bar. Left nil it is the chain's own — the commonest bar length in what it learned. Changing it re-bars the same token stream rather than changing the notes.
- term `seed`: The take. Any Int, and neighbouring seeds are unrelated draws. It decides the opening and every choice along the way, and nothing else.
- term `open`: How much of the melody to leave for the machine, 0 to 1. An open slot is written as a ?( … ) set the passes re-roll instead of one chosen note. It is a probability offered, not a share delivered: a slot can only open where the chain has an alternative to offer.

Walks the chain and answers notation, barlines and all. The two layout numbers multiply, and that is the only relationship between them: bars: 4, slots: 4 and bars: 2, slots: 8 both write sixteen tokens, but the first is four bars of quarters and the second two bars of eighths.

```swift
tokens written = bars × slots

m.melody(bars: 4, seed: 7)             // 4 bars at the learned bar length
m.melody(bars: 4, slots: 8, seed: 7)   // the same chain, in eighths
m.melody(bars: 8, seed: 7, open: 0.25) // …and a quarter of it left open
```

### slots:

Notes per bar. Left out, it is the chain's own .slots — the commonest bar length in what it learned from — so a melody sampled from eighth-note bars comes out in eighths without your saying so.

Setting it does not change *what* the chain writes, only how the tokens are cut into bars. The walk is driven by the slot number, so for a given seed the token stream is the same sequence whatever slots you ask for — only how many of them get written (bars × slots) and where the barlines fall.

So bars: 4, slots: 4 and bars: 2, slots: 8 write the identical sixteen tokens: the first as four bars of quarters (each note 0.25), the second as two bars of eighths (each 0.125) — the same melody at twice the speed. Raising slots alone keeps the tempo of the notes you had and adds more after them.

### seed:

The take. Any Int; there is nothing special about small ones and nothing sequential about neighbours — seed 7 and seed 8 are two unrelated draws, not two nearby ones.

It decides the opening and every choice along the way, and nothing else: the same chain and the same numbers always write the same melody for the same seed. Two seeds can still land on the same melody when the chain has few choices to make — the higher the order, the more often (see the table under order:).

Change the number to hear another take.

```swift
let lead   = m.melody(bars: 4, seed: 7)
let answer = m.melody(bars: 4, seed: 23)   // a different part, one chain
```

### open:

How much of the melody to leave for the machine, 0 to 1. At an open slot the chain writes the plausible continuations as a ?( … ) set instead of choosing between them, so that note is re-rolled on every pass and the tune keeps moving while it runs.

It is a probability *offered*, not a proportion delivered: a slot can only open when there are at least two different pitches the chain would accept there, so the ceiling is the source's own branchiness and open: 1.0 does not mean every note.

Around 0.25 is a tune that stays recognisable and never repeats exactly; above 0.5 the shape starts to dissolve.

```swift
// Share of slots that actually became sets, on the theme above:
//
// open   order 1   order 2   order 3
// 0.00     0%        0%        0%
// 0.25    14%       12%       11%
// 0.50    24%       21%       19%
// 1.00    35%       34%       31%

let m = Markov(from: theme, order: 2)
m.melody(bars: 4, seed: 7, open: 0.25)
// → "| 6 5 ?(3 6) 2 | 1 2 1 - | - 3 5 6 | 5 3 2 1 |"
```

## open: how the sets behave

### Written once, decided every pass

The set is fixed when the score compiles; which member sounds is decided on each pass through the loop. That split is the whole point, and it is the same one a "?" step gives a drum lane: the candidates are placed once so every reader of the session agrees on them, and the choice among them is re-rolled per pass so no two passes are identical.

Each set rolls its own die, from where it is written, so two sets in the same bar do not move together. .seed(…) on the Session twists all of those rolls at once — one written melody, as many performances as you have seeds, each identical every time it runs.

```swift
Session { … }.seed(11)   // the performance, not the melody
```

### Two or three members

A set holds the chain's own choice first, then up to two more candidates, commonest first — so sets are always 2 or 3 members wide. Wider sets stop sounding like a melody with alternatives and start sounding like a scale.

The first member is what the walk continues from, so the rest of the melody is the one the chain would have written anyway.

### Candidates come from the widest memory

An open slot asks what could follow the *last token alone*, even when the walk is running at order 2 or 3. At a high order a context usually has exactly one successor, so drawing the set from the full-order candidates would leave nothing to be undecided about and open: would quietly do nothing.

The walk itself still moves at the order you asked for. Only the question "what else would have fitted here" is asked of a shorter memory — which is why the table above falls off so gently with order instead of collapsing.

### What never opens

A set is a choice between things that *sound*, so a member has to be one. Degrees, note names, chords on degrees, named chords and stacks all qualify — which means a generated chord progression opens exactly as a melody does. A tie or a rest is the absence of a note, so "?(- 3)" would mean nothing; a slide spans two slots. Those are written as themselves whatever open says, and a slot whose alternatives are all of those stays closed.

The first `order` tokens never open either: they are the quoted opening, and the walk has not started making choices yet.

```swift
let chart = Markov(from: "1maj - 6m - | 4maj - 5dom7 -", order: 2)
chart.melody(bars: 4, seed: 3, open: 0.5)
// | 1maj - 6m - | ?(4maj 6m 5dom7) - ?(5dom7 4maj 6m) - | …
```

## Fitting it into the song

### Degrees, so the key still moves it

Write the source in degrees and the generated melody is in degrees too, which means .key(…) at any level still moves the whole thing — the string's, the Section's, the Track's, the Session's, innermost first. Nothing about generation happens before the key is read; the chain writes numbers and the key turns them into pitches, exactly as with a written line.

```swift
let m = Markov(from: "1 2 3 5 | 5 3 2 1", order: 2)
Track(name: "Lead") {
    Section { m.melody(bars: 4, seed: 7) }
    Section { m.melody(bars: 4, seed: 7) }.key(.A4, .minor)
}
// the same melody twice, the second one in another key
```

### The other per-pass knobs stack on top

open decides which note; .velocity(random:) decides how hard and .durations(random:) how long, and all three roll independently on every pass. A section that generates its notes and then breathes is three lines.

They compose because each answers a different question about the same note. Adding them does not make the melody less reproducible: every one of those rolls is a function of where the note is written and which pass is playing.

```swift
Section { m.melody(bars: 8, seed: 7, open: 0.25) }
    .velocity(random: 70...100)
    .durations(random: [.n8, .n4])
```

### One chain, several parts

A chain is a value, so the same one can write a tune, an answer to it and a bass line — different seeds, different bar lengths, the same idiom. That is usually more coherent than three chains, because everything is drawn from the same material.

```swift
let m = Markov(from: theme, order: 2)
let lead   = m.melody(bars: 4, seed: 7)
let answer = m.melody(bars: 4, slots: 8, seed: 23, open: 0.4)
let bass   = m.melody(bars: 4, slots: 2, seed: 5)
```

### Print it and keep it

The result is an ordinary String. print(m.melody(…)) shows it, and pasting it back into the score as a literal freezes that take. Generate while you are searching; paste when you have found it.

```swift
print(m.melody(bars: 4, seed: 7))   // m = Markov(from: theme, order: 2)
// | 6 5 3 2 | 1 2 1 - | - 3 5 6 | 5 3 2 1 |
```

## Worth knowing

### You trade the notes for the intent

A written melody shows you the tune; a generated one shows you the rules that made it. That is usually the better trade for eight bars of accompaniment and the wrong one for a hook you want to see. Mix freely — generate the parts that should feel played, write out the parts that should feel decided.

### Never use Double.random(in:)

Not in a score, and not to feed one of these. A host that recompiles as you type would run it again on every keystroke, so a melody drawn from the system generator would change under your hands, and the file you exported would be a take you never heard. Dice, the seed parameter and open: are all deterministic for exactly this reason — the whole point is that a generated part is as fixed as a written one.
