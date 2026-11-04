# Tracks and Arrangement

One instrument's part, and when it plays across the passes.

## Overview

One track = one instrument, on one MIDI channel. Sections inside a track play back to back. The .active() family controls on which loop passes a track (or a single section) actually sounds — passes are 0-based, and an inactive pass leaves silence, so the rest of the timing is unchanged.

## Creating

### Track

```swift
Track(_ name: String) { Section... }
```

- term `name`: What the track is called. It names the track in an exported MIDI file, so keep it distinct. `name:` may be written out; every other constructor here takes its first argument unlabelled, so this one does too.

A track with no instrument named: a player picks its default sound, and a MIDI file sends no program change.

```swift
Track("melody") { … }
Track(name: "melody") { … }   // the same thing
```

### Track

```swift
Track(_ name: String, instrument: Instrument) { Section... }
```

- term `name`: What the track is called — see above.
- term `instrument`: What plays it: a General MIDI program, or a drum kit on channel 10. Left out, a MIDI file sends no program and the player keeps its default. See <doc:Instruments>.

A track with a sound of its own.

```swift
Track("bass", instrument: .generalMIDI(33)) { … }
Track("drums", instrument: .drums(.tr808)) { … }

// an instrument named once and shared reads the same way
let keys = Instrument.generalMIDI(4)
Track("keys", instrument: keys) { … }
```

## Modifiers

### .instrument()

```swift
instrument(_ instrument: Instrument) -> Track
```

- term `instrument`: The same value the instrument: parameter takes, applied after the fact.

Gives a track its sound after the block rather than in the header — the modifier twin of the instrument: parameter.

```swift
Track("lead") { … }.instrument(.generalMIDI(81))
```

### .volume()

```swift
volume(_ level: Double) -> Track
```

- term `level`: This track against the others, 0.0–1.0. Multiplies into every note's velocity along with the session's master volume.

Track volume, 0.0–1.0.

### .tempo()

```swift
tempo(_ bpm: Double) -> Track
```

- term `bpm`: This track's own beats per minute. Its sections are time-warped by the ratio to the session tempo, so the track drifts against the rest rather than the whole score changing speed.

Time-warps this track's sections relative to the session tempo.

### .automate(over:)

```swift
automate(_ target: AutomationTarget, over breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Track
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `over`: time: value, with the time as a fraction of the whole track — 0 is the top of the pass, 1 where its last section ends. So the curve spans the sections instead of restarting inside each one, which is the difference between this level and the same modifier on a Section.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

Move a parameter across the whole track — the level of a part over the piece, a filter opening from the first bar to the last. It is spent where it is written: .volume is sliced onto every note, and a track parameter is cut into the sections' own windows, so a section that moves that same target keeps its own reading (innermost wins, the rule .key() follows). Two volume curves multiply, so a section that fades inside a track that fades does both. Write it after .tempo(): a curve written before it is scaled with the warp, one written after is measured against the warped clock.

```swift
Track("pad") { … }.automate(.volume, over: [0: 0, 0.25: 1, 1: 0])
```

### .automate(at:)

```swift
automate(_ target: AutomationTarget, at breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Track
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `at`: time: value, with the time in whole notes from the top of the track — the DSL's own unit, so .n4 and .n2 work as keys. Otherwise exactly as over:.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times in musical whole notes from the track's start.

```swift
Track("bass") { … }.automate(.volume, at: [0: 0.2, .n1: 1.0])
```

### .automate(bars:)

```swift
automate(_ target: AutomationTarget, bars breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Track
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `bars`: time: value, with the time as a bar number counted from the top of the track — which at this level is the top of the piece, so a bar number here is the bar number you count. Read under the session's meter.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times as bar numbers off the session's time signature — the spelling an eight-bar filter sweep wants.

```swift
Track("bass") { … }.automate(.cutoff, bars: [0: 300, 8: 5000])
```

### .automate(beats:)

```swift
automate(_ target: AutomationTarget, beats breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Track
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `beats`: time: value, with the time as a beat counted from the top of the track. Agrees with bars: by construction — four beats of 4/4 are one bar.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times as beats off the session's time signature. Note where a track curve does not reach: a shuffled track (.shuffleSections()) carries its slices with the sections, so a reordered pass plays the curve reordered too — the curve is spent onto the sections, and the sections move.

```swift
Track("pad") { … }.automate(.reverb, beats: [0: 0.1, 16: 0.6])
```

### .mute()

```swift
mute(_ on: Bool = true) -> Track
```

- term `on`: true silences the track, false un-silences it. The argument exists so the switch can be written either way; .mute() alone means true.

Silences the track — its notes are left out of playback and out of the MIDI file. The track keeps its place in the session, so MIDI channels and the section shuffle stay aligned.

```swift
Track(name: "pad") { … }.mute()
```

## Repetition — Loop

### Loop

```swift
Loop(bars: Int, times: Int? = nil, body: (Int) -> [Section])
```

- term `bars`: How long one time round is. It is held exactly, whatever the body builds: a round that builds nothing still occupies its bars, and a body longer than the grid is cropped rather than allowed to push the rounds after it out of alignment.
- term `times`: How many times round. Leave it out and the loop runs as long as the piece — measured against whatever is written out, so adding a phrase to the melody lengthens the groove under it with nothing to re-count.
- term `body`: The sections for one time round, handed the 0-based round number. It is an ordinary Swift closure, so `if loop == 0`, `if loop % 4 == 3` and `for v in 0..<loop` all work — written as a trailing closure: Loop(bars: 2) { loop in … }. Name it `loop` rather than `pass`: a pass is the whole piece going round, which is a different number and has a variable of its own — see The form.

Repetition, written where it happens. A Loop holds sections and lays them down again and again on a grid of its own, so a groove can repeat under a voice that does not — the thing a Session's one loop could never say. Each loop in a piece can have its own length. Anything written outside a Loop plays once, straight through. The dice keep rolling: every time round is salted separately, so a ?() set, a ? step and a rolled velocity all vary from round to round, the way they vary from pass to pass.

```swift
Track(name: "drums") {
    Loop(bars: 2) { loop in            // as long as the piece
        Section { Kick("x..x"); Snare("..x.") }
        if loop % 4 == 3 { Section { Crash("x...") } }
    }
}
Track(name: "bass") {
    Loop(bars: 4, times: 8) { _ in Section { "| 1 1 5 5 |" } }
}
Track(name: "voice") {           // no Loop: written once, straight through
    Section { "| 1 2 3 4 | 5 - - - |" }
    Section { "| 5 6 7 1' | 1' - - - |" }
}
```

### Reacting to the time round

The body is a plain Swift closure, so `if loop == 0`, `if loop % 4 == 3` and `for v in 0..<loop` choose what each round plays. A round that builds nothing is silent and still keeps its bars, which is how a part drops out for eight bars without anything under it moving. The number is the loop's own round — for the pass the whole piece is on, see The form.

```swift
Loop(bars: 1, times: 8) { loop in
    Section { "| 1 1 1 1 |" }
    if loop >= 4 { Section { "| [1 3 5] - - - |" } }   // harmony joins halfway
}
```

## The form — Session { pass in … }

### Session { pass in … }

```swift
Session { pass in … }.loops(_ count: Int)
```

- term `count`: How many times through the piece — the form's length. It is also how many times a pass body is read. Leave .loops(…) off and the form is whatever the arrangement itself declares, which is one pass for a score that arranges nothing.

The session body can be handed the pass — which time through the whole piece is playing, 0-based — so `if pass >= 2` can change what plays from the third time through. A Loop's number counts rounds inside one track; this one counts times through everything. The piece cycles through the passes it was built for: the player takes the pass modulo the form's length, so a four-pass body plays round and round rather than running out. Every pass is built at once and gated to its own, which is what a nested variant Section {} does by hand — so a track's sound (its instrument, its volume, its section order) belongs to the track and not to the pass, and sections are aligned position by position. Vary the material between passes and write the sound once; where two passes disagree about either, the score reports it when it runs.

```swift
return Session { pass in
    Track(name: "drums") {
        Loop(bars: 1) { _ in Section { Kick("x..x"); Snare("..x.") } }
    }
    Track(name: "bass") {
        Section { pass < 2 ? "| 1 1 5 5 |" : "| 1 b3 4 5 |" }
    }
}
.loops(4)
```

### Writing the choice

```swift
pass < 2 ? "…" : "…"   ·   if pass < 2 { "…" } else { "…" }
```

Both spellings play the same. Each note records which string literal it was read from, so a host that maps notes back to the source, to light the token that is sounding, can tell the branches of a ternary apart by their text, and the branches of an if by their position. Two branches written identically can't be told apart that way; write those as if / else.

```swift
Section { pass < 2 ? "| 1 1 5 5 |" : "| 1 b3 4 5 |" }

Section {                       // the same thing, spelled out
    if pass < 2 { "| 1 1 5 5 |" }
    else        { "| 1 b3 4 5 |" }
}
```

### Loop or the session's pass?

Two different repetitions, and the difference is what they repeat. A Loop lays its rounds down one after another inside one track, on a grid of its own — a two-bar groove under a sixteen-bar melody. The session's pass has no length of its own: it is the whole piece going round, and every track goes round with it. So a loop's number counts bars within a track and the session's counts times through the form. Name them apart — `loop` in a Loop body, `pass` in the session's — and a piece can read both at once.

```swift
return Session { pass in
    Track(name: "drums") {
        Loop(bars: 1) { loop in
            Section { Kick("x..x") }
            if pass == 3 && loop % 2 == 1 { Section { Crash("x...") } }
        }
    }
}
.loops(4)
```

## Arrangement — .active()

### .active(loops: range)

```swift
active(loops: 2...) / active(loops: 0...1) / active(loops: ..<4)
```

- term `loops`: Which passes this sounds on, 0-based. Closed (0...1), half-open (..<4) and one-sided (2...) ranges all work.

Play only on these loop passes (0-based). Accepts closed, half-open and one-sided ranges. Works on Track and Section.

```swift
Track(name: "lead") { … }.active(loops: 2...)
```

### .active(loops: [Int])

```swift
active(loops: [Int])
```

- term `loops`: Exactly the passes listed, 0-based — [0, 1, 4] plays the first two and the fifth and is silent on the rest.

Play on exactly the listed passes, e.g. [0, 1, 4].

### .active(every:offset:)

```swift
active(every n: Int, offset: Int = 0)
```

- term `every`: The period: sounds when the pass number divides by this. 2 is every other pass.
- term `offset`: Which pass of each period, 0-based — the phase. every: 2 is the even passes, every: 2, offset: 1 the odd ones.

Play every nth pass; offset shifts the phase. active(every: 2, offset: 1) = odd passes.

```swift
Section { "| Cm7~= - - - |" }.active(every: 4)
```

### .shuffleSections()

```swift
shuffleSections()   shuffleSections(loops: [1, 2])   shuffleSections(every: 2)
```

- term `loops`: Shuffle only these passes and play the rest as written — same range and array shapes .active takes. Useful when a fixed opener and closer bracket the passes that may move.
- term `every`: Shuffle every nth pass instead of naming them, with the same meaning as in .active(every:offset:).

The first pass plays the sections as written, every later pass reshuffles their order. Deterministic — exports match playback, and tracks with the same section count shuffle alike, staying aligned. A loops: argument (same shapes as .active) shuffles only those passes and plays the rest as written — so a track whose sections hold per-pass variants can reshuffle its verse passes while its chorus keeps a fixed opener and closer.

```swift
Track(name: "melody") { … }.shuffleSections()
Track(name: "drums") { … }.shuffleSections(loops: [1, 2, 4, 5])
```

### Variant sections

```swift
Section { Section { … }.active(…) … }
```

A Section nested inside a Section {} block is a layer like any other — and with .active(…) it becomes a per-pass alternative. Gated variants share one time window (the longest sets the section's length), so a single track can play different material on different passes — verse riff early, chorus strums later — without one track per variant. All gates compose: the note sounds only if its variant, its section and its track are active on the pass.

```swift
Track(name: "guitar") {
    Section {
        Section { "| D3 A3 E4 F#4 | C#5 - A4 - |" }.active(loops: [0, 1])
        Section { "| [Dmaj7 9]~0.05 - - - |" }.active(loops: 2...)
    }
}
```
