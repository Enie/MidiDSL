# Drums

Step-grid lanes on General MIDI drum keys.

## Overview

A groove is written as lanes, one per kit piece and one character per step, like a drum machine. The lanes in a section are layers over the same bars. Put them on a track whose instrument is ``Instrument/drums(_:)``: it is written on channel 10, where every General MIDI player keeps its kit, and the kit is chosen by program.

```swift
Track("drums", instrument: .drums()) {
    Section {
        Kick( "x... .... x.x. ....")
        Snare(".... x..o .... x...")
        Hat(  "x.x. x.x. x.x. X.x.")
    }
}
```

## Reading a grid

| Character | Plays |
|---|---|
| `x` | a hit, velocity 100 |
| `X` | an accent, velocity 120 |
| `o` | a ghost note, velocity 55 |
| `?` | a hit on about half the passes |
| `1`…`9` | a hit on about that many passes in ten |
| `.` or `-` | a rest |

`|` separates bars, and spaces only group steps for the eye. Each bar divides evenly by its own number of steps, so 16 steps are sixteenths and 8 are eighths, in the session's meter. A grid without `|` is one bar.

The `?` and digit steps are rolled by ``Dice`` on every pass. Each step rolls its own die, so two lanes never start agreeing, and the rolls are the same on every build. See <doc:DiceAndChance>.

## Lanes

``Kick(_:)``, ``Snare(_:)``, ``Hat(_:)``, ``OpenHat(_:)``, ``Clap(_:)``, ``Crash(_:)`` and ``Ride(_:)`` name the everyday pieces. ``Lane(_:_:)`` plays any other ``DrumPiece``: `.cowbell`, `.rideBell`, `.tambourine`, `.highTom`, `.claves` and the rest of the General MIDI percussion keys. ``DrumPiece/init(key:)`` reaches a key without a name.

```swift
Lane(.cowbell, "..x. .... ..x. ....")
```

## Balancing lanes

All the lanes of a groove play on one track, so there is no fader per lane. ``DrumLane/volume(_:)`` scales the velocities a lane plays at instead. Hits, accents and ghosts keep their ratio, and a kit may answer a softer velocity with a different sample, so treat it as an accent balance rather than a calibrated fader.

```swift
Section {
    Kick( "x... x...").volume(0.9)
    Snare(".... x...")
    Hat(  "x.x. x.x.").volume(0.45)   // under everything
}
```

``DrumLane/mute(_:)`` silences a lane and keeps its bars, so muting the longest lane does not shorten the section.

``DrumLane/automate(_:over:curve:)`` moves a parameter over one lane. A `.volume` curve is the lane's own, so one piece of the kit swells while the others hold, and it multiplies with `.volume(_:)`. Every other target moves something the whole track shares, so a `.cutoff` curve written on the hats sweeps the kick too.

```swift
Hat("x.x. x.x. x.x. x.x.").automate(.volume, over: [0: 0.3, 1: 1.0])
```

In a MIDI file a lane's volume curve travels as expression, which is one value per channel. On a drum track the most recently shaped hit sets it for every piece of the kit.

## Grids written by code

A grid is a string, so code can write it. ``Grid(bars:beats:subdivisions:_:)`` calls a closure once for every step and joins the answers:

```swift
Lane(.ride, Grid(bars: 8, subdivisions: 3) { step in step.isOnBeat ? "x" : "." })
```

See <doc:GeneratingParts>.

## A piece in a notation string

Where a drum has to be a note, in a Markov chain's training or a ``Phrase(bars:beats:subdivisions:_:)`` closure, interpolate the piece. It is written as a note name, the kick as C3, so no key moves it; a bare number in notation would be a scale degree.

```swift
let line = Phrase(bars: 2) { _ in "[\(.kick) \(.closedHat)]" }
```

``DrumPiece/spelling`` is the same name as a string:

```swift
DrumPiece.slot(3).spelling   // "D#3"
```

An interpolated string loses the link between its notes and the characters you typed, so in a hand-written part prefer a lane.

## Kits

``DrumKit`` names the General MIDI kits: `.standard`, `.room`, `.power`, `.electronic`, `.tr808`, `.jazz`, `.brush` and `.orchestra`. The kit is the track's program, and each lane's piece is the key it strikes. Plain notes on the drum keys play through the same kit.

```swift
Track("drums", instrument: .drums(.tr808)) { … }
```

## Topics

- ``DrumLane``
- ``DrumPiece``
- ``DrumKit``
- ``Lane(_:_:)``
- ``Kick(_:)``
- ``Snare(_:)``
- ``Hat(_:)``
- ``OpenHat(_:)``
- ``Clap(_:)``
- ``Crash(_:)``
- ``Ride(_:)``
