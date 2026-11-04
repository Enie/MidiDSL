# Automation

Curves over volume, filter, reverb and MIDI controllers.

## Overview

A score can set a level. This is how it moves one.

`.automate(target, <unit>: [time: value])`, on a notation string, a drum lane, a Section or a Track: a handful of breakpoints, held before the first and after the last, interpolated between. One breakpoint is a constant. An empty dictionary changes nothing. A value outside the target's range is clamped to it. Each time may appear once — a repeated key is a Swift error at the literal, not a later value quietly winning.

The targets split in two, and the split decides what a curve can be. `.volume` rides each voice, so a held note genuinely fades while it rings, two layers of one section can fade differently, and two volume curves multiply — the way every other gain in this DSL does. Everything else moves something the whole *track* shares: one MIDI channel, and in a player one filter and one reverb. Those cannot be per-layer, so an inner curve wins over an outer one, and two statements sounding in the same window contest it rather than stacking.

Nothing here is sampled while the music plays. A shape, a wave and a hand-written dictionary all become the same list of breakpoints when the score compiles, and that one list is what a MIDI file, a player and an audio render each read. They agree because there is only one of it.

## Writing a curve

### The four units

```swift
over: / at: / bars: / beats:
```

The second label names the unit the times are written in, and all four count from that statement's own start — not from the top of the piece. over: is a fraction of the statement's own span, so the curve survives a tempo change or an edit that makes the phrase longer. at: is the DSL's musical time in whole notes, so .n4 and .n2 work as keys. bars: and beats: are read under the session's meter — the same meter bar notation is parsed under, so a bars: curve and a | … | phrase cannot disagree.

```swift
"| 1 3 5 5 | 5 3 2 1 |".automate(.volume, over:  [0: 0.2, 1: 1.0])
Section { … }.automate(.volume, at:    [0: 0.2, .n1: 1.0])
Section { … }.automate(.cutoff, bars:  [0: 400, 3: 6000])
Section { … }.automate(.volume, beats: [0: 0.2, 4: 1.0])
```

### Held at both ends

Before the first breakpoint the value holds at the first; after the last it holds at the last. That is the same contract slides and falls keep, and it is why a single breakpoint is simply a constant — a cheap way to set a level that the arrangement can then leave alone. It also means a curve does not need to reach the end of what it is written over.

### Where to write it in a chain

On a notation string the order does not matter: everything a string carries is applied in one fixed pass, and the curve is sliced against the notes' final positions whatever order you wrote the modifiers in. On a Section it does matter, because Section modifiers act immediately — .durations() after .automate() stretches each note's slice of the curve rather than moving the note along it. Write .automate last on a Section and you never have to think about it.

## What can move

### .volume

```swift
gain, 0…1
```

Rides each voice. A note held across the whole curve fades while it rings, and two statements in one section can fade differently because each note carries its own stretch of the curve. Volume curves multiply — with each other, and with the track's and session's volume. A MIDI file carries it as CC 11 (expression), stepped as finely as the value changes.

```swift
Section { … }.automate(.volume, over: [0: 1.0, 1: 0.0], curve: .exponential)
```

### .cutoff / .resonance

```swift
cutoff in hertz, 20…20000 / resonance 0…2.5
```

One filter per track, so this is not per-layer: an inner curve wins over an outer one, and two statements sounding at the same time contest it — but two *serial* parts, whether two sections or two halves of a + join, are two sweeps in two windows and both keep theirs. A MIDI file carries them as CC 74 (brightness) and CC 71 (timbre); the cutoff is mapped logarithmically across 20 Hz…20 kHz, because a sweep is heard in octaves, and the resonance linearly across 0…2.5.

### .reverb

```swift
wet/dry, 0…1
```

How much of the track goes to reverb. Track-wide, like the filter; a MIDI file carries it as CC 91 (reverb send).

### .cc(n)

```swift
controller number, value 0…1 → 0–127
```

A raw controller, for whatever receives the file to learn: the value 0…1 is written across 0–127.

```swift
Section { … }.automate(.cc(74), bars: [0: 0.2, 4: 1.0])
```

## Shapes

### curve:

```swift
curve: .linear / .exponential / .smooth / .hold
```

How the value gets from one breakpoint to the next. .linear is a straight line and the default. .exponential is the shape a decay has — usually what a volume fade wants, because gain is linear and hearing is not, so a straight line drops fast and then lingers. .smooth eases in and out, leaving no corner where segments meet. .hold does not ramp at all: it keeps each value until the next breakpoint's time and then jumps, which is a stepped filter or a gate rather than a smoother sweep.

```swift
Section { … }.automate(.volume, over: [0: 1.0, 1: 0.0], curve: .exponential)
```

### Why there is no spline

Every shape here is monotone between two breakpoints, and that is load-bearing rather than a matter of taste. A spline through the points would overshoot between them, so the curve would pass values you never wrote — a gain above 1.0, a cutoff beyond the band you chose.

## Waves

### Wave

```swift
Wave.sine / .triangle / .sawtooth / .square / .random
```

Ready-made breakpoints for .automate(...) — a tremolo, a filter wobble, a sample-and-hold. A wave *is* the [time: value] dictionary you would otherwise have typed, so it needs no special .automate overload and every unit label works: over: wants times in 0…1, bars: in bars, beats: in beats, which is what span is for.

```swift
"| 1 3 5 5 |".automate(.volume, over: Wave.sine(cycles: 8, between: 0.6...1.0))
Section { … }.automate(.cutoff, bars: Wave.triangle(cycles: 2, span: 8, between: 400...6000))
Section { … }.automate(.cutoff, over: Wave.random(steps: 16, between: 400...8000, seed: 7))
```

### Wave.sine()

```swift
Wave.sine(cycles: Double = 1, span: Double = 1, between band: ClosedRange<Double>, depth: ClosedRange<Double> = 1...1, phase: Double = 0, resolution: Int = 16) -> [Double: Double]
```

- term `cycles`: How many times round in the span. Fractional is fine — 0.5 is half a cycle.
- term `span`: The length the wave is written across, in whatever unit the .automate label names: 1 for over:, a bar count for bars:, a beat count for beats:. Defaults to 1, which is what over: wants.
- term `between`: The band the wave moves in — its bottom and its top. For a volume tremolo that is something like 0.6...1.0; for a filter LFO, 400...6000 in Hz.
- term `depth`: The tremolo pedal's depth knob. 0 pins the parameter at the band's *top* and the wave disappears entirely; 1 is the full excursion down to the band's bottom. Written as a range it moves across the span, which is how a wobble fades in (0...1) or dies away (1...0). For .volume there is often a better way to say this: two volume curves multiply, so a tremolo riding a fade is just both written down.
- term `phase`: Where in the cycle to start, in cycles. 0 starts at the band's top, so an unphased sine reads as "unmodulated, then ducking"; 0.5 starts at the bottom.
- term `resolution`: Breakpoints per cycle. A sine read as straight lines between its own peaks would be a triangle, so it is sampled; 16 is well under anything audible.

A smooth wobble — tremolo on .volume, an LFO on .cutoff.

### Wave.triangle()

```swift
Wave.triangle(cycles: Double = 1, span: Double = 1, between band: ClosedRange<Double>, depth: ClosedRange<Double> = 1...1, phase: Double = 0) -> [Double: Double]
```

- term `cycles`: How many times round in the span. Fractional is fine — 0.5 is half a cycle.
- term `span`: The length the wave is written across, in whatever unit the .automate label names: 1 for over:, a bar count for bars:, a beat count for beats:. Defaults to 1, which is what over: wants.
- term `between`: The band the wave moves in — its bottom and its top. For a volume tremolo that is something like 0.6...1.0; for a filter LFO, 400...6000 in Hz.
- term `depth`: The tremolo pedal's depth knob. 0 pins the parameter at the band's *top* and the wave disappears entirely; 1 is the full excursion down to the band's bottom. Written as a range it moves across the span, which is how a wobble fades in (0...1) or dies away (1...0). For .volume there is often a better way to say this: two volume curves multiply, so a tremolo riding a fade is just both written down.
- term `phase`: Where in the cycle to start, in cycles.

Up and down in straight lines. Exact with two breakpoints per cycle — there is nothing between a peak and a trough that a line gets wrong.

### Wave.sawtooth()

```swift
Wave.sawtooth(cycles: Double = 1, span: Double = 1, between band: ClosedRange<Double>, depth: ClosedRange<Double> = 1...1, rising: Bool = false) -> [Double: Double]
```

- term `cycles`: How many times round in the span. Fractional is fine — 0.5 is half a cycle.
- term `span`: The length the wave is written across, in whatever unit the .automate label names: 1 for over:, a bar count for bars:, a beat count for beats:. Defaults to 1, which is what over: wants.
- term `between`: The band the wave moves in — its bottom and its top. For a volume tremolo that is something like 0.6...1.0; for a filter LFO, 400...6000 in Hz.
- term `depth`: The tremolo pedal's depth knob. 0 pins the parameter at the band's *top* and the wave disappears entirely; 1 is the full excursion down to the band's bottom. Written as a range it moves across the span, which is how a wobble fades in (0...1) or dies away (1...0). For .volume there is often a better way to say this: two volume curves multiply, so a tremolo riding a fade is just both written down.
- term `rising`: False (the default) falls and snaps back — a filter that opens on each beat and decays. True climbs and drops instead.

A ramp that snaps back. The snap is written as two breakpoints a hair apart, since one instant cannot hold two values.

### Wave.square()

```swift
Wave.square(cycles: Double = 1, span: Double = 1, between band: ClosedRange<Double>, depth: ClosedRange<Double> = 1...1, duty: Double = 0.5) -> [Double: Double]
```

- term `cycles`: How many times round in the span. Fractional is fine — 0.5 is half a cycle.
- term `span`: The length the wave is written across, in whatever unit the .automate label names: 1 for over:, a bar count for bars:, a beat count for beats:. Defaults to 1, which is what over: wants.
- term `between`: The band the wave moves in — its bottom and its top. For a volume tremolo that is something like 0.6...1.0; for a filter LFO, 400...6000 in Hz.
- term `depth`: The tremolo pedal's depth knob. 0 pins the parameter at the band's *top* and the wave disappears entirely; 1 is the full excursion down to the band's bottom. Written as a range it moves across the span, which is how a wobble fades in (0...1) or dies away (1...0). For .volume there is often a better way to say this: two volume curves multiply, so a tremolo riding a fade is just both written down.
- term `duty`: The fraction of each cycle spent at the top, 0.01…0.99. 0.5 is even; 0.25 is a short stab.

On, off, on — a gate rather than a sweep.

### Wave.random()

```swift
Wave.random(steps: Int, span: Double = 1, between band: ClosedRange<Double>, depth: ClosedRange<Double> = 1...1, seed: Int = 1) -> [Double: Double]
```

- term `steps`: How many levels across the span. Each is held until the next.
- term `span`: The length the wave is written across, in whatever unit the .automate label names: 1 for over:, a bar count for bars:, a beat count for beats:. Defaults to 1, which is what over: wants.
- term `between`: The band the wave moves in — its bottom and its top. For a volume tremolo that is something like 0.6...1.0; for a filter LFO, 400...6000 in Hz.
- term `depth`: The tremolo pedal's depth knob. 0 pins the parameter at the band's *top* and the wave disappears entirely; 1 is the full excursion down to the band's bottom. Written as a range it moves across the span, which is how a wobble fades in (0...1) or dies away (1...0). For .volume there is often a better way to say this: two volume curves multiply, so a tremolo riding a fade is just both written down.
- term `seed`: The take. Rolled from Dice, so the same seed writes the same wobble on every recompile, on every machine, and in the file you export — a level that rerolled under your hands would export a take you never heard.

Sample and hold: a new level every step, held until the next.

## In a MIDI file

### Everything agrees

A fade is written as expression (CC 11) beside the notes it shapes, and a track-wide curve as its controller on the track's channel. A player that reads the same session reads the same list of breakpoints, which is why the file and what you hear cannot drift apart.

### Per-channel limits

MIDI expression is per channel, exactly as pitch bend is. Overlapping notes carrying different fades share the most recent one's curve. A section-wide fade is the same curve for every note in it, so this bites far less often than the bend equivalent — but two statements in one section fading differently will hear it.
