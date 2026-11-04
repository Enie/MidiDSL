# Getting Started

Add the package, write the smallest score, and hear it.

## Overview

### Add the package

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Enie/MidiDSL.git", .upToNextMinor(from: "0.3.0")),
],
targets: [
    .executableTarget(name: "MyScore", dependencies: [
        .product(name: "MidiDSL", package: "MidiDSL"),
    ]),
]
```

In Xcode, choose File ▸ Add Package Dependencies… and enter the same URL. The package needs Swift 6 tools and macOS 13 or later, and builds in the Swift 5 language mode. Until 1.0, a minor version may change the API, which is why the requirement above stops at the next one.

### Write a score

A score is a Swift program. It imports the DSL and declares an `@main` type that conforms to ``Score``. That type's `session` is the music (see <doc:WhatAScoreIs>).

```swift
import MidiDSL

@main
struct Sketch: Score {
    var session = Session {
        Track("melody") {
            Section {
                "| C E G C6 |"
            }
        }
    }
    .tempo(120)
}
```

A string literal inside a `Section` is parsed as notation (see <doc:StringNotation>): here one bar of four quarter notes.

### Hear it

```bash
swift run MyScore --midi sketch.mid
```

This writes a Standard MIDI File that any DAW or notation program opens (see <doc:MIDIFiles>).

### A typical structure

Give each track its own ``Instrument``, the General MIDI sound a MIDI file opens it with, and bring tracks in and out across passes with `.active(...)`:

```swift
Session {
    Track("drums", instrument: .drums()) {
        Loop(bars: 1) { _ in            // one bar, repeated for the whole piece
            Section {
                Kick("x... x... x... x...")
                Hat("x.x. x.x. x.x. x.x.")
            }
        }
    }
    Track("keys", instrument: .generalMIDI(89)) {
        Section { "Cm7 | Fm7 | Bbmaj7 | Ebmaj7" }
    }
    .active(loops: 1...)   // joins on the second pass
}
.tempo(96)
.loopBars(4)
```

Statements inside a section are parallel layers: they all start together, and the longest one sets the section's length. Sequence comes one level up, where a track's sections play one after another.
