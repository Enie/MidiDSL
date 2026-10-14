# MidiDSL

Music written as Swift. A score is a value built with result builders — tracks
hold sections, sections hold notation — and a score is also a program: run it
and it prints the piece it describes.

```swift
import MidiDSL

@main
struct HelloScore: Score {
    var session = Session {
        Track("Keys") {
            Section {
                "Cmaj | Gmaj | Am | Fmaj"
            }
        }

        Track("Lead") {
            Section {
                "1 2 3 5 | 5 3 2 1 | 6, 1 3 5 | 4 3 2 -".key(.C4, .major)
            }
        }

        Track("Drums", instrument: Synth.drums(.standard)) {
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
    .timeSignature(.fourFour)
}
```

That file is `Examples/HelloScore`. Run it:

```bash
swift run HelloScore
```

and the `Session` comes out as JSON on stdout — every note with its pitch,
start, duration and velocity, and the line and column it was written at. Pass
`--session-json <path>` to have it written to a file instead, which leaves
stdout free for the score's own `print(...)`.

## What it is and is not

MidiDSL **describes** music. It does not make sound: there is no synthesizer,
no MIDI output and no file writer in this package. What you get is a `Session`
— `Codable`, `Equatable`, plain data — for a host to play, export or draw.
Componium, the macOS app this was written for, is one such host; the JSON
above is the whole interface between them.

It depends on Foundation and nothing else.

## How a score is put together

One composition rule per level:

- **A track's sections play one after another.**
- **A section's statements are parallel layers** — two notation strings in one
  `Section {}` sound together, and the longest sets the section's length.
- **Notes sequence inside a statement** — the tokens of a notation string, the
  chords of a progression.

Notation is a string. `|` separates bars and spaces split a bar into equal
slots, so four tokens in 4/4 are quarter notes. A token can be a note name
(`C4`, `F#3`), a chord (`Am`, `Gdom7`), a stack (`[C4 E4 G4]`), a rest (`R`),
a hold (`-`) or a scale degree (`1`, `b3`, `5'`) that takes its pitch from the
nearest `.key(...)`. Drum lanes are step grids: `x` a hit, `X` an accent, `o` a
ghost, `.` a rest, `?` a coin tossed again on every pass.

## A score is a pure function of its source

Nothing here is random in the sense of `Double.random`. Everything left to
chance goes through `Dice`, which rolls from *where the choice is written* and
*which pass is playing*, so the same source gives the same piece on every run
and on every machine — and a host that recompiles on each keystroke does not
reroll the groove under your hands. `Session.seed(_:)` picks the take.

## Using it

Add the package as a dependency and depend on its `MidiDSL` library product.
It builds in Swift 5 language mode.

## Tests

```bash
swift test
```
