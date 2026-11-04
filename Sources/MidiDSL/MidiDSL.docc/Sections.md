# Sections

Layers that sound together, and the transforms that shape them.

## Overview

A group of notes. Every statement in the block — a notation string, drum lane, Note, Chord, Progression, NoteSet or Rest — is a parallel layer: all layers start together at the section's start, and the longest one sets the section's length. Sequence lives one level up (a track's sections play one after another) or inside a statement (bar notation, progressions). Notes that share a start time (a chord) sound together. Modifiers that talk about "beats" treat a chord as one beat position.

## Creating

### Section

```swift
Section { statements }
```

Parallel container: each statement is a layer over the same bars — a melody over a held chord, drum lanes over each other. To play material one piece after another, chain Sections (they follow with no gap) or use one notation string with bars.

```swift
Section {
    "CDEFGABC6".duration(.n8)  // eighth-note run…
    "[C3 G3]".duration(.n1)    // …over a held fifth
}
Section {                      // then chords back to back,
    "Am~0.15 | Fmaj7~0.15"     // one bar each
}
```

### Section.random()

```swift
random(from pitches: [UInt32] | [String], count: Int, duration: Double = .n8, velocity: UInt32 = 80) -> Section
```

- term `from`: The pool to draw from — pitches or note names. A Scale's own pitches keep the result in key.
- term `count`: How many notes to generate. They follow one another back to back, so count × duration is the section's length.
- term `duration`: How long each note is, in whole notes (.n8 is an eighth). Also the spacing, since the notes are laid end to end.
- term `velocity`: How hard every note is struck, 0–127. One value for all of them; use .velocity(random:) afterwards if they should breathe.

Generates random notes drawn from a pitch pool — combine with Scale to stay in key.

```swift
Section.random(from: Scale.majorScale(for: "C"), count: 8)
```

## Dynamics & durations

### .velocity()

```swift
velocity(_ velocity: UInt32) -> Section
```

- term `velocity`: 0–127, the same for every note in the section. Flattens whatever the notes were written with, so drum accents and ghosts lose their ratios — .velocity(scale:) is what keeps those.

Sets every note to the same velocity (0–127).

### .velocity(scale:)

```swift
velocity(scale: Double) -> Section
```

- term `scale`: A multiplier on every note's written velocity, so their ratios survive. 0.5 halves the section; above 1.0 pushes towards the 127 ceiling.

Scales every note's velocity by a factor, keeping their ratios — drum accents (X) and ghosts (o) stay accents and ghosts, just softer or louder. Use it to balance per-pass variant sections inside one track (a section has no volume of its own). To move one drum lane against the others, give that lane its own .volume() — the two multiply.

```swift
Section { Kick("x...") }.velocity(scale: 0.8)
```

### .automate(over:)

```swift
automate(_ target: AutomationTarget, over breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Section
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `over`: time: value, with the time as a fraction of this section's own span — 0 is its start, 1 its end. The curve is linear between breakpoints and holds outside them, so one breakpoint is a constant and an empty dictionary changes nothing. Each time may appear only once: a repeated key is a Swift error at the literal, not a later value quietly winning.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

Move a parameter over time — a fade, a swell, a filter sweep. Four spellings, one per unit of time; this one measures the curve against the section's own length, so it survives a tempo change or an edit that makes the section longer. Write .automate last in a chain: .durations() after it stretches each note's slice of the curve rather than moving the note along it.

```swift
"| 1 3 5 5 | 5 3 2 1 |".automate(.volume, over: [0: 0.2, 1: 1.0])
Section { … }.automate(.volume, over: [0: 1, 0.75: 1, 1: 0])
```

### .automate(at:)

```swift
automate(_ target: AutomationTarget, at breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Section
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `at`: time: value, with the time in whole notes from this section's start — the DSL's own unit, so .n4 and .n2 work as keys. Otherwise exactly as over:.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times in musical whole notes from this section's start.

```swift
Section { … }.automate(.volume, at: [0: 0.2, .n1: 1.0])
```

### .automate(bars:)

```swift
automate(_ target: AutomationTarget, bars breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Section
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `bars`: time: value, with the time as a bar number counted from this section's start — not from the top of the piece. Read under the session's meter, the same meter bar notation is parsed under, so a bars: curve and a | … | phrase cannot disagree.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times as bar numbers off the session's time signature, counted from this section's start.

```swift
Section { … }.automate(.cutoff, bars: [0: 400, 3: 6000])
```

### .automate(beats:)

```swift
automate(_ target: AutomationTarget, beats breakpoints: [Double: Double], curve: AutomationShape = .linear) -> Section
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares — one MIDI channel — and a MIDI file carries them as CC 74, CC 71, CC 91 and CC n.
- term `beats`: time: value, with the time as a beat counted from this section's start. Agrees with bars: by construction — four beats of 4/4 are one bar.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

The same curve, with times as beats off the session's time signature. Note the limit a shared parameter brings: two statements moving the same .cutoff, .resonance, .reverb or .cc in one window cannot each have it, so the later-written one wins. Only .volume is per-voice, and volume curves multiply.

```swift
Section { … }.automate(.volume, beats: [0: 0.2, 4: 1.0])
```

### .velocities()

```swift
velocities(_ velocities: UInt32...) -> Section
```

- term `velocities`: One value per beat position, 0–127, in order. The notes of a chord share the value at their position; positions past the end of the list keep what they were written with.

One velocity per beat position; the notes of a chord share one value.

```swift
Section { "CCGG" }.velocities(110, 70, 90, 70)
```

### .durations()

```swift
durations(_ durations: Double...) -> Section
```

- term `durations`: One length per beat position, in whole notes. Only the ringing changes — start times stay where they are, unlike "…".durations() on a notation string, which re-spaces them.

One duration per beat position; chords share one value. Does not re-space start times — unlike the string modifier "…".durations(), which does (see String Notation).

### .noteDuration()

```swift
noteDuration(_ duration: Double) -> Section
```

- term `duration`: One length in whole notes for every note, and the spacing too: the notes are re-laid back to back, so this changes the section's length.

Sets a uniform duration and re-spaces the notes back to back.

```swift
Section { "CDEFGAB" }.noteDuration(.n8)
```

## Timing & feel

### .tempo()

```swift
tempo(_ tempo: Double) -> Section
```

- term `tempo`: Beats per minute for this section alone. Its notes are time-warped by the ratio to the session tempo, which scales their start times and durations — including the choices .durations(random:) may roll.

Time-warps just this section to the given BPM.

### .syncopate()

```swift
syncopate(by amount: MusicTimeStamp = .n16) -> Section
```

- term `by`: How far earlier to pull the notes that land squarely on a beat, in whole notes. .n16 is a sixteenth. Beat 1 and anything already off the beat are left alone.

Pulls notes that fall exactly on quarter-note beats (except beat 1) earlier by the given amount — an anticipation feel. Off-beat notes are untouched.

### .swing()

```swift
swing(_ ratio: Double = 0.67) -> Section
```

- term `ratio`: Where the off-beat eighth falls inside its beat. 0.5 is straight, 0.67 the usual jazz triplet feel, 0.75 heavy. Only off-beat eighths move.

Pushes off-beat eighth notes later. 0.5 = straight, 0.67 = jazz swing, 0.75 = heavy swing.

```swift
Section { "C C6 A B C6 G A F" }.noteDuration(.n8).swing()
```

### .active()

Same loop-arrangement modifiers as Track — see <doc:TracksAndArrangement>. The section's time slot stays reserved on inactive passes.

### .mute()

```swift
mute(_ on: Bool = true) -> Section
```

- term `on`: true silences the section, false un-silences it — the argument is there so the switch can be written either way. The slot stays reserved whichever it is.

Silences this section — playback, MIDI out and both exporters skip its notes — while its slot stays reserved, so the sections after it keep their timing. The written notes stay as the record of what comes back when the modifier goes. On a nested Section {} layer it takes that one variant out and leaves the others.

```swift
Section { "C E G" }.mute()
```
