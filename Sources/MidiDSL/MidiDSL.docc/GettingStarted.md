# Getting Started

Add the package, write the smallest score, and hear it.

## Overview

### Add the package

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Enie/MidiDSL.git", from: "0.2.0"),
],
targets: [
    .executableTarget(name: "MyScore", dependencies: [
        .product(name: "MidiDSL", package: "MidiDSL"),
    ]),
]
```

In Xcode, choose File ▸ Add Package Dependencies… and enter the same URL. The package needs Swift 6 tools and macOS 13 or later, and builds in the Swift 5 language mode. Until 1.0, a minor version may change the API.

### Write a score

A score is a Swift program. It imports the DSL and declares an `@main` type that conforms to ``Score``. That type's `session` is the music (see <doc:WhatAScoreIs>).

```swift
import MidiDSL

@main
struct Sketch: Score {
    var session = Session {
        Track("melody") {
            Section {
                "C E G C6"
            }
        }
    }
    .tempo(120)
}
```

A string literal inside a `Section` is parsed as notation (see <doc:StringNotation>).

### Hear it

```bash
swift run MyScore --midi sketch.mid
```

This writes a Standard MIDI File that any DAW or notation program opens (see <doc:MIDIFiles>). Open the same file in [Componium](https://eniestudio.de/componium) to hear it played, recompiled as you type.

### A typical structure

Give each track its own sound with a ``Synth`` preset or builder, and bring tracks in and out across passes with `.active(...)`:

```swift
Session {
    Track("drums", instrument: Synth.drums()) {
        Section {
            Kick("x... x... x... x...")
            Hat("x.x. x.x. x.x. x.x.")
        }
    }
    Track("keys", instrument: Synth.pad()) {
        Section { "Cm7 | Fm7 | Bbmaj7 | Ebmaj7" }
    }
    .active(loops: 1...)   // joins on the second pass
}
.tempo(96)
.loopBars(4)
```

Statements inside a section are parallel layers: they all start together, and the longest one sets the section's length. Sequence comes one level up, where a track's sections play one after another.
