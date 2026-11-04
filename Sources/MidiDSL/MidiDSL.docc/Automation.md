# Automation

Curves over volume, filter, reverb and MIDI controllers.

## Overview

A modifier like `.volume(0.8)` sets a level. `.automate` moves one: a fade, a swell, a filter sweep. It is written on a notation string, a drum lane, a section or a track, as a handful of breakpoints:

```swift
"| 1 3 5 5 | 5 3 2 1 |".automate(.volume, over: [0: 0.2, 1: 1.0])
```

The dictionary maps a time to a value. Between breakpoints the value travels along the curve; before the first and after the last it holds. So one breakpoint is a constant, an empty dictionary changes nothing, and a curve does not have to reach the end of what it is written on. A value outside the target's range is clamped.

## Units of time

The label after the target names the unit the times are written in. Every unit counts from the start of the thing the curve is written on, not from the top of the piece.

| Label | Time is |
|---|---|
| `over:` | a fraction of the thing's length: `0` its start, `1` its end |
| `at:` | whole notes, so `.n4` and `.n2` work as keys |
| `bars:` | bars of the session's meter |
| `beats:` | beats of the session's meter |

```swift
Section { … }.automate(.volume, over:  [0: 1, 0.75: 1, 1: 0])
Section { … }.automate(.volume, at:    [0: 0.2, .n1: 1.0])
Section { … }.automate(.cutoff, bars:  [0: 400, 3: 6000])
Section { … }.automate(.volume, beats: [0: 0.2, 4: 1.0])
```

`over:` keeps its shape when the thing gets longer. `bars:` and `beats:` are read in the same meter as bar notation, so a `bars:` curve and a `| … |` phrase always agree.

## What can move

``AutomationTarget`` names what a curve moves:

| Target | Range | In a MIDI file |
|---|---|---|
| `.volume` | gain, 0…1 | controller 11, expression |
| `.cutoff` | filter cutoff, 20…20 000 Hz | controller 74 |
| `.resonance` | filter resonance, 0…2.5 | controller 71 |
| `.reverb` | reverb send, 0…1 | controller 91 |
| `.cc(n)` | 0…1 | controller `n`, 0…127 |

The targets split in two. `.volume` belongs to each note: a held note fades while it rings, two layers of one section can fade differently, and two volume curves multiply, with each other and with the track's and session's volume.

The other targets move something the whole track shares, one filter or one MIDI channel. They cannot differ from layer to layer, so a curve written further in wins over one written further out, and of two statements moving the same target at the same time the later-written one wins. Two sections one after another each keep their own curve.

A MIDI file writes the cutoff on a logarithmic scale across 20 Hz…20 kHz, as the ear hears a sweep, and the others straight across their range.

## Shapes

``AutomationShape`` says how the value travels from one breakpoint to the next:

- term `.linear`: A straight line. The default.
- term `.exponential`: Fast at first, then easing in. It is usually what a fade wants: gain is linear and hearing is not, so a straight fade seems to drop and then linger.
- term `.smooth`: Eases out of one breakpoint and into the next, with no corner where segments meet.
- term `.hold`: Keeps each value until the next breakpoint, then jumps: a stepped filter or a gate.

```swift
Section { … }.automate(.volume, over: [0: 1.0, 1: 0.0], curve: .exponential)
```

Every shape stays between the two values it joins, so a curve never passes a value you did not write.

## Where to write it in a chain

On a notation string the order of the modifiers does not matter. On a section it does, because section modifiers act at once: `.durations(...)` written after `.automate(...)` stretches each note's slice of the curve instead of moving the note along it. Write `.automate` last.

On a track, a curve is laid onto the sections, so a section that moves the same target keeps its own reading.

## Waves

``Wave`` writes the breakpoints of an oscillator: a sine or triangle for a tremolo or filter wobble, a sawtooth, a square for a gate, or random steps for sample-and-hold. A wave is the same `[time: value]` dictionary you would type, so it works with every unit label:

```swift
"| 1 3 5 5 |".automate(.volume, over: Wave.sine(cycles: 8, between: 0.6...1.0))
Section { … }.automate(.cutoff, bars: Wave.triangle(cycles: 2, span: 8, between: 400...6000))
Section { … }.automate(.cutoff, over: Wave.random(steps: 16, between: 400...8000, seed: 7))
```

`span` is the length the wave is written across, in the label's unit: leave it at `1` for `over:`, give it the number of bars for `bars:`. `depth` says how far below the top of the band the wave reaches; a range such as `0...1` fades the wave in across the span. Two volume curves multiply, so a tremolo over a fade is just both written down.

## In a MIDI file

A volume curve is written as expression beside the notes it shapes; a track-wide curve as its controller on the track's channel. Expression is one value per channel, so overlapping notes with different fades share the most recent one's curve. A fade written on a whole section is the same curve for all its notes, so this only matters when two statements in one section fade differently.

## Topics

- ``AutomationTarget``
- ``AutomationShape``
- ``Wave``
