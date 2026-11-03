# Samples

Audio files, slices of them, and kits made of slices.

## Overview

A Sample is an audio file on disk. Slice it, shape it, and play it from drum lanes or as a statement of its own — the slices then sound through the notation, lanes, dice and arrangement that already exist. Each slice claims a key on the track, which is what a MIDI file carries; playing the audio is the host's part, and Componium does it with the same voice its synthesizer uses, so the track's envelope, filter, reverb and volume all apply.

A slice of a sample is still a sample, so every modifier works at either level. Files are found beside the score first and in a "<Score> samples" folder next to it second; an absolute or ~ path is taken as written.

## The file

### Sample()

```swift
Sample(_ file: String)
```

- term `file`: The audio file. A bare name is looked for beside the score, then in the score's own "<Score> samples" folder; an absolute or ~ path is taken as written. Anything AVFoundation reads — WAV, AIFF, CAF, MP3, M4A — and it is decoded to mono at the engine's rate.

The whole file, ready to be sliced. Nothing is read at compile time — a score that names an audio file it cannot find still builds, and the host that plays it reports the missing file rather than going silent for an unstated reason.

```swift
let amen = Sample("amen.wav")
let room = Sample("~/Recordings/room tone.aif")
```

## Slicing

### .slice()

```swift
slice(from: Double, to: Double) / slice(fraction: Double, to: Double) / slice(beats: Double, count: Double) / slice(bars: Double, count: Double)
```

- term `from`: Where the slice starts, in seconds — the file's own unit, and what a waveform ruler reads in.
- term `to`: Where it ends, in the same unit as the label beside it.
- term `fraction`: Where it starts as a share of the whole file, 0…1. Survives the file being replaced by a longer take.
- term `beats`: Where it starts, in beats off the session tempo and meter.
- term `bars`: Where it starts, in bars off the session tempo and meter.
- term `count`: How long the slice is, in the same musical unit — beats or bars. A length rather than an end, because that is how a bar of a break is described.

A window on the file. The label names the unit — seconds, a fraction of the file, beats or bars — and there is one implementation underneath, the rule .automate() already sets.

Both edges are measured from the start of the file, and slicing again replaces the window rather than nesting inside it: a window relative to an enclosing one would need a duration to compose, and a mapping that is nearly right is worse than a plain one.

```swift
let snare = amen.slice(from: 0.51, to: 0.74)
let half  = amen.slice(fraction: 0.0, to: 0.5)
let bar2  = amen.slice(bars: 1, count: 1)
```

### .slices()

```swift
slices(_ count: Int)
```

- term `count`: How many even pieces to cut. 16 sixteenths of a one-bar break is the usual chop.

Chop into even pieces — how a break is played. The division happens inside the sample's current window, so slicing a bar out first and chopping that works.

Every piece names the same file, so sixteen slices are one decode and one copy of the audio in memory.

```swift
let chops = amen.slices(16)

Track("break") {
    Section {
        Lane(chops[0], "x... .... x... ....")
        Lane(chops[4], ".... x... .... x...")
    }
}
```

## Shaping

### .fade()

```swift
fade(in: Double, out: Double)
```

- term `in`: The attack, in seconds. A couple of milliseconds is what keeps a chop from clicking.
- term `out`: The release, in seconds. This is how a slice is shortened — a one-shot plays to its end and ignores its note-off, so the fade is the shape rather than the gate.

The amp envelope's two edges. A sample voice is a one-shot: it plays to the end of its slice whatever the note's length, which is what lets a sixteenth-note step trigger a longer chop. The fade out is how you make it end instead of stop.

```swift
let snare = amen.slice(from: 0.51, to: 0.74)
                .fade(in: 0.002, out: 0.03)
```

### .gain()

```swift
gain(_ level: Double)
```

- term `level`: 1.0 as recorded. Multiplies with velocity, Track.volume, Session.volume and any .automate(.volume, …) curve.

Sit one slice under or over the others.

```swift
let ghost = chops[7].gain(0.45)
```

### .tune()

```swift
tune(_ semitones: Double)
```

- term `semitones`: Transposition on top of whatever key plays the slice. Fractional values work — 0.2 is a fifth of a semitone.

Transpose the slice. On a kit this offsets that one chop; on a sample played across the keyboard it offsets all of it.

```swift
let sub = kick.tune(-5)
```

### .speed()

```swift
speed(_ rate: Double)
```

- term `rate`: Playback rate. 2.0 is twice as fast and an octave up; 0.5 is half speed and an octave down.

Pitch and length move together — the honest one-knob version. Time-stretch independent of pitch is a different feature and this is not it.

```swift
let slowed = amen.speed(0.75)
```

### .reverse()

```swift
reverse(_ on: Bool = true)
```

- term `on`: false puts it back, so the modifier can be written under a condition.

Play the slice back to front.

```swift
let swell = crash.reverse().fade(out: 0.01)
```

## The insert chain

### .bitCrush()

```swift
bitCrush(bits: Int, rate: Double?)
```

- term `bits`: Word length, 1–24. 8 is an old sampler, 6 is dirty, 1 is sign alone.
- term `rate`: Optional sample-and-hold rate in Hz. This is the half that puts the aliasing in, and the aliasing is what an old sampler actually sounds like. Omitted, only the depth is reduced.

Bit-depth reduction, and optionally sample-rate decimation. Inserts belong to the slice, not the track, so two chops of one break can crush differently — and they run in the order they are written, because that order is the signal path.

```swift
let dirt = chops[3].bitCrush(bits: 6, rate: 8000)
```

### .drive()

```swift
drive(_ amount: Double)
```

- term `amount`: 1.0 is unity; 4.0 is well into the knee. The curve caps at ±1 however hard it is driven.

Saturation, through the same soft-clip curve the synthesizer's own output stage uses.

```swift
let fat = kick.drive(3.0)
```

### .ringMod()

```swift
ringMod(_ hz: Double)
```

- term `hz`: The modulator's frequency. Low values wobble; audio rates turn the slice metallic.

Ring modulation: the slice multiplied by a sine. The phase is per voice and reset at every note-on, so a repeated chop is the same sound every time.

```swift
let metal = snare.ringMod(220)
```

## Playing them

### A kit in Componium

Componium also plays a list of slices as a kit of its own, one slice per key from the GM kick up, so `DrumPiece.slot(n)` lanes play slice n; and one sample chromatically, repitched across the keyboard. Those are its `Synth.kit(_:from:)` and `Synth.sample(_:root:)`, in a score that imports `Componium`.

### Lane() with a slice

```swift
Lane(_ sample: Sample, _ grid: String)
```

- term `sample`: The slice this lane plays. It claims a key as it is written and the track builds its kit from what its lanes claimed, so no instrument: is needed.
- term `grid`: The step string, read exactly as a drum lane's is: x hit, X accent, o ghost, . rest, ? a maybe, 1–9 odds in tenths, | between bars.

A lane that plays a slice instead of a kit piece — the same Lane, overloaded on its first argument, so Grid(...), the dice steps, .volume() and .mute() all work here unchanged.

Keys are claimed in written order, and the same slice on two lanes is one voice playing two rhythms rather than two copies of it.

The lanes' keys sit clear of the General MIDI percussion range, so a real kit and a chopped break can play on one track — Kick("x...") and Lane(chop, "..x.") side by side.

```swift
let amen  = Sample("amen.wav")
let kick  = amen.slice(from: 0.00, to: 0.21)
let snare = amen.slice(from: 0.51, to: 0.74)

Track("break") {            // no instrument: written
    Section {
        Lane(kick,  "x... .... x... ....")
        Lane(snare, ".... x... .... x...")
    }
}
```

### A sample as a statement

```swift
Section { sample } / Section { a + b }
```

A sample written on a line of its own is a layer like any other statement, sounding at the section's start. So two of them play together, because that is what a Section's statements mean — and + lays them end to end, because that is what + already means between two pieces of notation.

Sequence has to live inside one statement, which is why the run is written with an operator rather than as two lines. An array of samples is the same thing spelled with commas, so a chopped break plays back in order without a single key being named.

No instrument: is needed: each sample claims a key as it is written and the track builds its kit out of what its sections claimed — the same collector Lane(slice, "…") uses, so a reel and a lane share one track without colliding.

```swift
let amen = Sample("amen.wav")

Section {
    trumpets                       // both start
    bass                           // at bar 1
}
Section { trumpets + bass }        // one, then the other
Section { amen.slices(8) }         // the break, in order
```

### .hold()

```swift
hold(bars: Double) / hold(beats: Double) / hold(_ whole: Double)
```

- term `bars`: How many bars of the session meter the sample's slot occupies.
- term `beats`: The same slot counted in beats.
- term `whole`: The same slot in whole notes — the DSL's own unit, the one .automate(at:) counts in.

How much of the score's time this sample takes up. A sample written plainly occupies one bar, which is the length Lane(sample, "x") already has; this is how to say otherwise.

It is a different question from .slice(), and that is why it is a different word: a slice says which part of the file to play, a hold says how long the piece waits before the next thing.

The slot is layout, not length. A sample voice is a one-shot — it plays to the end of its slice and the score's note-off does not cut it — so a slot shorter than the audio overlaps what follows rather than truncating it, and a longer one leaves a gap. How long the file actually runs is not knowable here: the DSL never opens it, so that a score still compiles when the audio is missing. Cutting in musical units (.slice(bars: 0, count: 2)) is the way to have a written length and a real one agree.

```swift
Section {
    trumpets.hold(bars: 2) + bass  // bass enters at bar 3
    pad.hold(bars: 3)              // under both
}
```

### DrumPiece.slot()

```swift
DrumPiece.slot(_ n: Int)
```

- term `n`: Which slice of the kit, counting from 0 at the kit's base key.

Slot n of a sample kit. The same key space the named pieces use, read two ways: .slot(0) is where a kit's first slice lands and .kick is where a GM kit's bass drum does.

```swift
Lane(.slot(3), "..x. ..x.")
```

## What a sample track obeys

### Automation and MIDI

A slice is notes on a key, so every .automate(...) curve applies to a sample track as to any other, and a host that plays the audio plays the curves with it.

What a slice's own insert chain does is not automatable: the curve targets are track-wide or per-voice volume, and a per-slice lane would be a fourth kind of curve. .gain() multiplies with a .volume curve, so fades already move.

A MIDI export carries the notes on the kit's keys, because a MIDI file cannot carry audio.

```swift
Track("break") {
    Section {
        Lane(amen.slice(from: 0, to: 0.21), "x... x... x... x...")
    }
    .automate(.cutoff, over: [0: 400, 1: 12000], curve: .exponential)
}
```
