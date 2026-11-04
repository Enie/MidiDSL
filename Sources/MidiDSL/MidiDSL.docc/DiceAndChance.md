# Dice and Chance

Deterministic chance: rolls that are the same on every run.

## Overview

Chance comes into a piece two ways here. You can roll while *writing* it — Dice(seed:) and Grid() generate a part from a seed instead of you typing every hit — and you can leave a choice open for the *machine* to make on each pass: which note of a set, how hard, how long, whether a step sounds at all, which of several layers plays.

The rolls are not noise. Each one is a pure function of where the choice is written and which pass is playing, so the same source always produces the same performance: what a player sounds and what the MIDI file contains are the same music. Nothing is drawn from the clock, so a piece keeps its shape across runs, machines and exports — it varies, but it is never lost. Two choices written in different places roll independently, and a note's loudness and its length roll separately, so the loud passes aren't also the long ones.

## Rolling a number

### Dice(seed:)

```swift
Dice(seed: Int)
```

- term `seed`: The take. Any Int; it is the only thing that decides what the dice answer, and neighbouring seeds are unrelated draws rather than nearby ones. Keep it and the part never changes; change it for another.

Dice you roll while writing the piece, so a part can be generated instead of typed out. d(stream, bar, step) answers a number in 0..<1 — the same number for the same coordinates, every time. The seed is the take: change it to hear another one, leave it and the piece never changes.

On top of the call itself: .chance(…) for a yes-or-no, .pick([…], …) to choose between options, .int(in: 60...72, …) for a whole number, .value([…]) when the coordinates are already an array. All four are the one roll below, shaped.

Never use Double.random(in:) in a score: a score is meant to be a pure function of its source. A host like Componium recompiles it about 0.8 s after every keystroke, so a random groove would change under your hands, and the file you export would be one you never heard.

```swift
let d = Dice(seed: 7)
d(1, bar, step)              // 0..<1, always the same here
d.chance(0.3, 2, bar, step)  // true 30% of the time
```

### d( … )

```swift
d(_ coordinates: Int...) -> Double
```

- term `coordinates`: Which choice this is: any numbers that identify it, conventionally a stream number first and then the position — d(1, bar, step). The answer is a pure function of them, so the same coordinates give the same number on every recompile, in the exported file and a year from now, and a different order gives a different number. The leading stream number is the part that is easy to forget: give each part its own, or the ride and the snare consult one die and start moving together. Leaving the coordinates out altogether (d(), d.int(in: 1...6)) is legal and answers one fixed number for the whole score — there is no counter here, so the coordinates are the only thing that makes a roll vary.

A number in 0..<1 for a set of coordinates — the roll everything else here is built on. .chance, .pick and .int all read this one number and shape it, which is why they all take the same coordinates in the same place.

Read the call as a question with an address: not "give me a number" but "what number lives at 1, bar, step". Nothing is consumed by asking, so you can ask again anywhere and get the same answer — which is exactly what makes a generated part a fixed part.

```swift
let d = Dice(seed: 7)
d()                 // legal, but one fixed number: no coordinates, no variation
d(1, bar)           // stream 1, per bar
d(2, bar, step)     // stream 2, per step — independent of stream 1
```

### .chance()

```swift
chance(_ probability: Double, _ coordinates: Int...) -> Bool
```

- term `probability`: How often it comes up true, 0…1. 0.3 is three times in ten across the coordinates you sweep — not a coin flipped now: this step either passes or it does not, and does the same on every run.
- term `coordinates`: Which choice this is: any numbers that identify it, conventionally a stream number first and then the position — d(1, bar, step). The answer is a pure function of them, so the same coordinates give the same number on every recompile, in the exported file and a year from now, and a different order gives a different number. The leading stream number is the part that is easy to forget: give each part its own, or the ride and the snare consult one die and start moving together. Leaving the coordinates out altogether (d(), d.int(in: 1...6)) is legal and answers one fixed number for the whole score — there is no counter here, so the coordinates are the only thing that makes a roll vary.

A yes-or-no, decided while you write. This is the one that fills a grid: sweep it over a lane's steps and the density is the number you typed.

It decides at compile time, so what it writes is settled material. For a maybe the machine re-decides on every pass, write a ? or a digit into the grid instead — see Whether it sounds. The two compose: d.chance(…) ? "?" : "." lets the dice place the maybes and the machine sound them.

```swift
let d = Dice(seed: 7)
Lane(.ride, Grid(bars: 4) { s in
    d.chance(0.3, 1, s.bar, s.step) ? "x" : "."
})
```

### .int(in:)

```swift
int(in range: ClosedRange<Int>, _ coordinates: Int...) -> Int
```

- term `in`: The range to answer inside, both ends included. int(in: 1...6) is a die, int(in: -24...24) an interval in semitones.
- term `coordinates`: Which choice this is: any numbers that identify it, conventionally a stream number first and then the position — d(1, bar, step). The answer is a pure function of them, so the same coordinates give the same number on every recompile, in the exported file and a year from now, and a different order gives a different number. The leading stream number is the part that is easy to forget: give each part its own, or the ride and the snare consult one die and start moving together. Leaving the coordinates out altogether (d(), d.int(in: 1...6)) is legal and answers one fixed number for the whole score — there is no counter here, so the coordinates are the only thing that makes a roll vary.

A whole number in a range — a transposition, an octave, a number of repeats, a velocity.

Watch the parentheses: the range is labelled and the coordinates are the variadic tail, so they go inside this call, not after it. .transpose(d.int(in: -24...24), pass) is an extra argument to .transpose, which takes one; the pass belongs to the roll.

```swift
let d = Dice(seed: 7)
Session { pass in
    Track("keys") {
        Section {
            "| C4 E4 G4 C5 |".transpose(d.int(in: -24...24, 1, pass))
        }
    }
}.loops(8)
```

### .pick()

```swift
pick(_ options: [T], _ coordinates: Int...) -> T?
```

- term `options`: What there is to choose between, each as likely as the next. Write a value twice to weight it. An empty array answers nil, so a filtered list needs no second guard.
- term `coordinates`: Which choice this is: any numbers that identify it, conventionally a stream number first and then the position — d(1, bar, step). The answer is a pure function of them, so the same coordinates give the same number on every recompile, in the exported file and a year from now, and a different order gives a different number. The leading stream number is the part that is easy to forget: give each part its own, or the ride and the snare consult one die and start moving together. Leaving the coordinates out altogether (d(), d.int(in: 1...6)) is legal and answers one fixed number for the whole score — there is no counter here, so the coordinates are the only thing that makes a roll vary.

One of the options, evenly. Anything can go in the array — a notation token, a drum piece, a degree, a whole phrase — because the choice is made while you write and what comes back is an ordinary value.

It answers an Optional only because the array might be empty; ?? a fallback and it reads as one value.

```swift
let d = Dice(seed: 7)
let fills = ["1 2 3 5", "5 3 2 1", "1 - 5 -"]
Phrase(bars: 4, beats: 1) { s in d.pick(fills, 3, s.bar) ?? "1" }   // one fill per bar
```

### .value()

```swift
value(_ coordinates: [Int]) -> Double
```

- term `coordinates`: Which choice this is: any numbers that identify it, conventionally a stream number first and then the position — d(1, bar, step). The answer is a pure function of them, so the same coordinates give the same number on every recompile, in the exported file and a year from now, and a different order gives a different number. The leading stream number is the part that is easy to forget: give each part its own, or the ride and the snare consult one die and start moving together. Leaving the coordinates out altogether (d(), d.int(in: 1...6)) is legal and answers one fixed number for the whole score — there is no counter here, so the coordinates are the only thing that makes a roll vary.

d( … ) for coordinates you already hold in an array — built up in a loop, or passed along from somewhere else. Same function, same number; the call form is the only difference.

```swift
let d = Dice(seed: 7)
let address = [1, bar, step]
d.value(address)    //  ==  d(1, bar, step)
```

## Generating a part

### Grid()

```swift
Grid(bars: Int, beats: Int = 4, subdivisions: Int = 4, _ fill: (GridStep) -> Character) -> String
```

- term `bars`: How many bars to lay out. When the session sets .loopBars(…), match it: a longer grid is cut off at the end of the pass, and a shorter one leaves the lane silent for the rest of it.
- term `beats`: Beats per bar — match your time signature. 4 unless you pass another; it does not read the session's meter.
- term `subdivisions`: Steps per beat, and so the resolution: 4 gives sixteenths, 3 the triplet eighths a swung ride actually lands on. Each bar gets beats × subdivisions characters.
- term `fill`: Called once per step, in order, with that step's coordinates; answers the one character the step holds.

Writes a lane's grid step by step and joins the bars with |, so a part can be described by its rules instead of typed out. The closure gets bar, beat, sub, step and index, and returns the one character that step should hold — including ? or a digit, which makes it a maybe the machine re-decides every pass.

See the Generating Parts topic for the coordinates in full, how to choose a resolution, recipes and the trade-offs.

```swift
let d = Dice(seed: 7)
Lane(.ride, Grid(bars: 8, subdivisions: 3) { s in
    if s.isDownbeat { return s.beat % 2 == 0 ? "X" : "x" }
    if s.sub == 2 && s.beat % 2 == 1 { return "x" }
    return d.chance(0.3, 1, s.bar, s.step) ? "x" : "."
})
```

### Phrase()

```swift
Phrase(bars: Int, beats: Int = 4, subdivisions: Int = 1, _ fill: (GridStep) -> String) -> String
```

- term `bars`: How many bars to lay out. Match it to .loopBars(…), as with Grid.
- term `beats`: Beats per bar — match your time signature, or the generated bars aren't the song's bars.
- term `subdivisions`: Slots per beat, which is the note value you get: 1 quarters, 2 eighths, 3 triplet eighths, 4 sixteenths. It defaults to 1 rather than Grid's 4 because that is where a melody usually starts.
- term `fill`: Called once per slot, in order; answers the notation token that slot holds. "" is a rest, and several tokens become a run group sharing the slot.

Grid for notes. Same coordinates, but the closure answers one notation token per slot rather than one character — a degree, a note name, a chord, a stack, a slide, "-" to tie or "R" to rest. What comes back is an ordinary notation string, so the key still arrives from .key(…) and everything downstream reads it as written notation.

An empty answer is a rest, so the slot keeps its time. An answer holding several tokens is wrapped in a run group, { }, which is how you write a triplet in one slot.

```swift
let d = Dice(seed: 3)
Section {
    Phrase(bars: 4, subdivisions: 2) { s in
        if s.isDownbeat { return s.beat == 0 ? "1" : "5" }
        return d.chance(0.6, 1, s.bar, s.step) ? "3" : "-"
    }
}.key(.D5, .dorian)
```

### Markov()

```swift
Markov(from: String, order: Int = 1) / Markov([Int: [Int]], start: Int? = nil, slots: Int = 4)
```

- term `from`: The phrase to learn from, written as ordinary notation. Its tokens are the only ones the chain can write, its counts are the weights, and its | set the bar length and the openings.
- term `order`: How many tokens of history a choice looks at, 1–4. 1 wanders, 2 keeps the source's turns of phrase, 3 nearly quotes it.
- term `start`: Chart form only: the state every melody opens on. Left out, the seed picks among all the states you named.
- term `slots`: Chart form only: notes per bar, since a chart has no bars in it — 4 unless given. The phrase form reads this off the | instead.

A melody generator you hand a phrase you already like. It is a chain over notation tokens, not over pitches — a tie after a 3 is a transition like any other, so what it learns is the source's rhythm and articulation as much as its shape.

Either learn the chain from notation, or state the table outright: each degree and the degrees that may follow it, where a repeat is a weight. order is how much history a choice looks at — 1 wanders, 3 nearly quotes the source.

```swift
let m = Markov(from: "1 2 3 5 | 5 3 2 1 | 1 3 5 3 - -", order: 2)
Section { m.melody(bars: 8, seed: 7) }.key(.D5, .dorian)

Markov([1: [2, 3, 3, 5], 2: [1, 3], 3: [2, 5, 1]], start: 1)
```

### .melody()

```swift
melody(bars: Int, slots: Int? = nil, seed: Int = 0, open: Double = 0) -> String
```

- term `bars`: How many bars to write. bars × slots is the number of tokens, and the only relationship between the two.
- term `slots`: Notes per bar. Left nil it is the chain's own — the commonest bar length in what it learned. Changing it re-bars the same token stream rather than changing the notes.
- term `seed`: The take. Any Int, and neighbouring seeds are unrelated draws. It decides the opening and every choice along the way, and nothing else.
- term `open`: How much of the melody to leave for the machine, 0 to 1. An open slot is written as a ?( … ) set the passes re-roll instead of one chosen note. It is a probability offered, not a share delivered: a slot can only open where the chain has an alternative to offer.

Walks the chain and answers notation. Same seed, same melody — on every recompile, on every machine, in the file you export; change the seed for another take. slots is notes per bar, defaulting to what the chain learned.

open, 0 to 1, is how much of the melody to leave for the machine: at an open slot the chain writes the plausible continuations as a ?( … ) set instead of choosing between them, so that note is re-rolled every pass and the tune keeps moving while it runs.

```swift
m.melody(bars: 8, seed: 7)             // a fixed melody
m.melody(bars: 8, seed: 7, open: 0.3)  // …that keeps moving
m.melody(bars: 4, slots: 8, seed: 7)   // in eighths
```

## Which note

### .chart

```swift
chart: String
```

The chain printed back as a paste-ready chart. A phrase is a closed walk, so you can only add whole paths to it; a chart sets edges directly. Sketch with a phrase, print the chart, paste it over the Markov(from:) line, tune the weights.

See Generating Melodies for what a chart cannot carry.

```swift
print(Markov(from: "1 2 1 2 | 1 2 1 3").chart)
// Markov([1: [2, 2, 2, 3],
//         2: [1, 1, 1],
//         3: [1]], start: 1, slots: 4)
```

### ?( … )

```swift
"| C ?(E G B) C |"
```

A note set in notation: one of the listed members sounds each pass, drawn by dice. ~ walks the set up instead, ~~ down, ~* back and forth — the dice are the unpredictable member of that family.

A member can be a **chord** as well as a single note — a chord on a degree ("6m", "5dom7"), a named chord ("Cmaj7") or a stack ("[1 3 5]") — so a set is how you write a harmony that changes from pass to pass. Every mode works the same on chords as on pitches, so an unprefixed set walks the chords in order and "?" draws one. Ties, rests and slides are not members: a set is a choice between things that sound.

```swift
Section { "| C ?(E G B) C |" }              // one note, three readings
Section { "| ?(1maj 6m) - ?(4maj 2m) - |" } // one bar, two chords, each drawn per pass
Section { "| ([1 3 5] [4 6 1']) |" }        // the two stacks take turns, pass by pass
```

## How hard

### .velocity(random:)

```swift
velocity(random: ClosedRange<UInt32>) -> Section
```

- term `random`: The range each note draws its velocity from, 0–127, re-rolled every pass. The written velocity becomes the middle of the range — the one value a reader that does not roll (a drawing of the part, say) sees.

Every note draws its velocity from the range again on every pass, so a part breathes instead of repeating. The written velocity becomes the middle of the range — the one value a reader that does not roll (a drawing of the part, say) sees.

```swift
Section { "| C E G C |" }.velocity(random: 70...110)
```

## How long

### .durations(random:)

```swift
durations(random: [MusicTimeStamp]) -> Section
```

- term `random`: The lengths each note may ring for, one drawn per pass. Start times never move, so the section keeps its shape however the roll goes.

Each note picks a length from the list per pass. Start times never move — like durations(_:), this changes how long a note rings, not when the next one begins, so the section keeps its shape and the track behind it keeps its timing.

```swift
Section { "| C E G C |" }.durations(random: [.n8, .n4])
```

## Whether it sounds

### ? and 1–9 steps

```swift
Kick("x..? x..3")
```

A drum step the machine decides. ? is an even coin; a digit is the odds in tenths, so 3 sounds on about three passes in ten and 9 on nine. They sound at hit velocity, and each one rolls its own die from its own position, so two lanes never start agreeing. 0 is a rest like . — nothing that never sounds.

This is how a song keeps moving while it runs: write the parts you decided as x and X, leave the rest as odds, and every pass is a different performance of the same written music. Pair it with Grid() to have the dice place the maybes for you.

```swift
Section {
    Kick( "x... x..3")   // that last kick, 3 passes in 10
    Snare(".... x...")   // always
    Hat(  "x.x? x.x7").volume(0.45)
}
```

## The take

### .seed()

```swift
seed(_ seed: Int) -> Session
```

- term `seed`: The performance, not the piece: it twists every roll the machine makes while playing — set members, maybe-steps, .pickOne() layers, rolled velocities and lengths. One written score has as many performances as you have seeds, each identical every time it runs.

The score's own seed: every roll the machine makes while playing — which member of a ?() set, whether a maybe-step sounds, which .pickOne() layer, rolled velocities and lengths — is twisted by it. One written piece therefore has as many performances as you have seeds, and each of them is the same every time you play it or export it. A score without .seed(…) keeps the rolls it always had.

```swift
Session { … }.tempo(150).loopBars(8).seed(11)
```

## Which layer

### .pickOne()

```swift
pickOne() -> Section
```

Exactly one of the section's layers sounds per pass — a slot with several possible fillings. Every statement in the block is a candidate. This is the sibling of .active(loops:) on a nested Section: that names the passes by hand, this lets the machine choose.

```swift
Section {
    "| C5 E5 G5 - |"
    "| C5 F5 A5 - |"
    "| B4 D5 G5 - |"
}.pickOne()
```

### .shuffleSections()

```swift
shuffleSections() -> Track
```

The track-level relative: the order of a track's sections is permuted per pass rather than one of them being chosen. Pass 0 plays as written, so the piece introduces itself before it starts varying.
