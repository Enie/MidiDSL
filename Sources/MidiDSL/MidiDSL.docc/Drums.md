# Drums

Step-grid lanes on General MIDI drum keys.

## Overview

Drum grooves are written as step-sequencer lanes: one lane per kit piece, one character per step. The lanes in a Section are parallel layers over the same bar grid. Put them on a track whose patch is Synth.drums(...) — the General MIDI percussion bank, where every key is a kit piece and the kit itself is chosen per patch.

## Lanes

### Kick / Snare / Hat / OpenHat / Clap / Crash / Ride

```swift
Kick(_ grid: String) …
```

- term `grid`: The step string: x hit, X accent, o ghost, . or - rest, ? a maybe, 1–9 odds in tenths. | separates bars and spaces only group for the eye. Each bar divides evenly by its own step count, so 16 characters are sixteenths and 8 are eighths.

One rhythm layer on the everyday kit piece the name says. The grid reads like a drum machine: x hit, X accent, o ghost note, . (or -) rest. Spaces just group steps; | separates bars. Each bar's step characters divide it evenly — 16 characters are sixteenths, 8 are eighths; a grid with no | is one bar.

```swift
Track(name: "drums", instrument: Synth.drums().build()) {
    Section {
        Kick( "x... .... x.x. ....")
        Snare(".... x..o .... x...")
        Hat(  "x.x. x.x. x.x. X.x.")
    }
}
```

### Lane

```swift
Lane(_ piece: DrumPiece, _ grid: String)
```

- term `piece`: Which GM percussion key the lane strikes — .cowbell, .rideBell, .tambourine, .highTom and the rest of the map. DrumPiece(key:) reaches one the list doesn't name.
- term `grid`: The step string, read exactly as for Kick and the other named lanes.

A lane for any General MIDI kit piece: .cowbell, .rideBell, .clap, .tambourine, .highTom … .lowFloorTom, .highBongo, .claves, and the rest of the GM percussion map. DrumPiece(key:) reaches unnamed keys.

```swift
Lane(.cowbell, "..x. .... ..x. ....")
```

### .volume()

```swift
volume(_ level: Double) -> DrumLane
```

- term `level`: This lane against the others in the same groove. 1.0 is as written; below sits it back, above pushes it towards the velocity ceiling. It scales the lane's velocities at expansion time, so hit, accent and ghost keep their ratio, and it multiplies with Section .velocity(scale:) and Track .volume().

Sits one lane under or over the others. 1.0 is the lane as written; above 1.0 pushes it, up to the velocity ceiling. Every lane of a groove is a voice on the same sampler track, so this scales the velocities that lane's steps play at — the hit/accent/ghost ratio inside the lane stays as written, and the kit's own velocity layers still apply, which makes it an accent balance rather than a calibrated fader. Multiplies with Section .velocity(scale:) and Track .volume().

```swift
Section {
    Kick( "x... x...").volume(0.9)
    Snare(".... x...")
    Hat(  "x.x. x.x.").volume(0.45)   // ride under everything
}
```

### .mute()

```swift
mute(_ on: Bool = true) -> DrumLane
```

- term `on`: true drops the lane's hits, false brings them back. The bars still hold their time either way, so muting the longest lane can't shorten the section under the others.

Takes one lane out of the groove without deleting it — the counterpart to .volume(): where that scales the lane's hits, this drops them altogether. The lane's bars still hold their time, so muting the longest lane doesn't shorten the section under the others, and the written grid stays as the record of what comes back when the modifier goes.

```swift
Hat("x.x. x.x.").mute()
```

### .automate()

```swift
automate(_ target: AutomationTarget, over breakpoints: [Double: Double], curve: AutomationShape = .linear) -> DrumLane
```

- term `target`: What moves. .volume is a gain, 0…1, and rides each voice — so a held note fades while it rings and two layers of one section can fade differently. .cutoff (Hz), .resonance, .reverb (0…1) and .cc(n) move something the whole track shares: one filter, one reverb node, one MIDI channel. Sampled and hosted tracks have no filter of ours, so .cutoff and .resonance reach them as CC 74 and CC 71; .cc(n) makes no sound in Componium at all and exists for the DAW to learn. .effect("Name", parameter: "Mix") moves a parameter of a plugin in the track's effect chain, 0…1 across its range.
- term `over`: time: value, with the time as a fraction of this lane's own written grid — 0 its first step, 1 the end of its last bar, trailing rests included. at:, bars: and beats: are the other three spellings, exactly as on a section.
- term `curve`: How the value gets from one breakpoint to the next. .linear (the default) is a straight line; .exponential is the shape a decay has and is usually what a volume fade wants, since gain is linear but hearing is not — a straight line drops fast and then lingers; .smooth eases in and out so there is no corner where segments meet; .hold does not ramp at all, holding each value until the next breakpoint and then jumping. The shape is spent when it is written: it becomes breakpoints, so everything downstream reads one piecewise-linear curve.

Moves a parameter over this lane — a hat that swells across the                     bar, a filter opening under the groove. .volume is the one that                     is genuinely this lane's: it is sliced onto this lane's own hits,                     so one voice of a groove swells while the others hold. It is the                     moving twin of .volume(level) — that one scales the lane's                     velocities once, this one draws them over time — and where both                     are written they multiply. Every other target moves something the                     whole track shares (one filter, one reverb node, one MIDI                     channel), so .cutoff written on the hats sweeps the kick with it,                     and two lanes moving the same target is a contest the                     later-written one wins. One caveat that is not this modifier's                     own: a per-voice curve reaches a sampled track — which                     Synth.drums() is — as CC 11, and CC is per-channel, so on a GM                     kit the most recently faded hit owns the expression for all of                     them. On sample lanes (Lane(chop, "x...")), which play our own                     voices, the curve is per-hit as written.

```swift
Hat("x.x. x.x. x.x. x.x.").automate(.volume, over: [0: 0.3, 1: 1.0])
Kick("x... x...").automate(.cutoff, bars: [0: 400, 2: 6000])
```

### Generated grids

```swift
Lane(.ride, Grid(bars: 8) { … })
```

A grid is just a string, so it can be built by code instead of typed: Grid() fills one step by step from a closure, which is how a part gets generated rather than written out. See Generating Parts.

## A piece in a notation string

### \(.kick)

```swift
"\(.kick) \(.closedHat) [\(.snare) \(.closedHat)]"
```

A kit piece written into notation by name, for the parts that are notes rather than a step grid — a Markov chain's training, a Phrase closure, anywhere a drum has to be a token. It arrives as a pitch name (the kick is C3), never a number: a bare number in notation is a degree, while a name is read absolutely, so no .key(...) at any level moves it. The bare leading dot resolves because this overload is what gives it a type. In a literal you would otherwise type out, Lane(.kick, "x... x...") names the same piece.

```swift
Phrase(bars: 2) { _ in "[\(.kick) \(.closedHat)]" }
```

### .spelling

```swift
DrumPiece.spelling: NoteNotation
```

The piece as notation spells its pitch — .kick is C3, .closedHat is F#3. What the interpolation above writes, for when the string is being assembled rather than interpolated into.

```swift
DrumPiece.slot(3).spelling   // "D#3"
```

## Kits

### Synth.drums()

```swift
drums(_ kit: DrumKit = .standard, soundFont: String? = nil)
```

- term `kit`: Which GM percussion program the whole track plays — .standard, .room, .power, .electronic, .tr808, .jazz, .brush, .orchestra. The kit is the program; each lane's piece is the key.
- term `soundFont`: Path to a SoundFont whose percussion bank to load instead of the system GM one. Left nil, the system bank is used.

Sampled drum kit from the General MIDI percussion bank. Kits: .standard, .room, .power, .electronic, .tr808, .jazz, .brush, .orchestra. Pass a SoundFont path to use its percussion bank instead. Oscillator, envelope and filter settings don't apply; reverb and volume do. Plain notes on GM keys (36 kick, 38 snare, 42 closed hat…) play through the same kit.

```swift
Synth.drums(.tr808).build()
```
