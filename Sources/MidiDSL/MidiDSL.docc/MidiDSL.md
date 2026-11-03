# ``MidiDSL``

Music written as Swift.

## Overview

A score is a value built with result builders: a ``Session`` holds tracks, a ``Track`` holds sections, and a ``Section`` holds notation. A score is also a program. Run it, and it hands over the piece it describes, either as JSON for a host to play or as a Standard MIDI File.

```swift
import MidiDSL

@main
struct HelloScore: Score {
    var session = Session {
        Track("Keys") {
            Section { "Cmaj | Gmaj | Am | Fmaj" }
        }
        Track("Lead") {
            Section { "1 2 3 5 | 5 3 2 1 | 6, 1 3 5 | 4 3 2 -".key(.C4, .major) }
        }
        Track("Drums", instrument: .drums(.standard)) {
            Loop(bars: 1, times: 4) { _ in
                Section {
                    Kick("x... x... x... x...")
                    Snare(".... x... .... x...")
                    Hat("x.x. x.x. x.x. x.?.")
                }
            }
        }
    }
    .tempo(120)
}
```

One composition rule holds at each level:

- **A track's sections play one after another.**
- **A section's statements are parallel layers.** Two notation strings in one `Section {}` sound together, and the longest sets the section's length.
- **Notes sequence inside a statement.** That covers the tokens of a notation string and the chords of a progression.

Time is measured in whole notes: a duration of `1.0` is one whole note, four beats in 4/4.

### Describing, not playing

MidiDSL describes music and makes no sound. Its output is a `Session`: plain data that is `Codable` and `Equatable`, for a host to play, export or draw, plus ``MIDIFile`` when a file is all you need. [Componium](https://eniestudio.de/componium), the macOS app this language was written for, is one such host. A track's ``Instrument`` says what a MIDI file can: a General MIDI program, and whether the track is drums. Sound beyond that, a synthesizer, a plugin, an effect chain, belongs to the host that makes it, and Componium adds its own for scores that import it.

### Pure functions of their source

Nothing in a score is random in the sense of `Double.random`. Everything left to chance goes through ``Dice``, which rolls from *where the choice is written* and *which pass is playing*. The same source therefore gives the same piece on every run and on every machine, and ``Session/seed(_:)`` picks the take.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:WhatAScoreIs>
- <doc:MIDIFiles>

### The Structure of a Piece

- <doc:Sessions>
- <doc:TracksAndArrangement>
- <doc:Sections>
- <doc:TimeSignatures>

### Writing Notes

- <doc:StringNotation>
- <doc:NotesRestsAndNoteSets>
- <doc:PitchesAndDurations>
- <doc:ChordsAndVoicings>
- <doc:ProgressionsAndScales>
- <doc:Drums>
- <doc:Samples>
- <doc:NotInTheGrammar>

### Sound and Movement

- <doc:Instruments>
- <doc:Automation>

### Chance and Generation

- <doc:DiceAndChance>
- <doc:GeneratingParts>
- <doc:GeneratingMelodies>
