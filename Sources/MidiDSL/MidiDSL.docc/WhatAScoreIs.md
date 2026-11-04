# What a Score Is

A score is an ordinary Swift program whose entry point is the music.

## Overview

A score needs the two things any Swift program needs: an import, and somewhere to start. `@main` is Swift's own attribute for the second. It wants a type with a `main()`, which conforming to ``Score`` supplies, the same way `@main struct MyApp: App` works in SwiftUI. The type's name is yours.

```swift
import MidiDSL

@main
struct Ballad: Score {
    var session = Session {
        Track("keys", instrument: .generalMIDI(0)) {
            Section { "C4 E4 G4 | F3 A3 C4" }
        }
    }
    .tempo(96)
}
```

`var session` is a stored property here, which is the flattest spelling when the piece is one expression.

### When there is something to work out first

Make the property computed instead. Anything you would have written above the `Session` goes inside, and the last expression is returned, as in any Swift property.

```swift
@main
struct Generated: Score {
    var session: Session {
        let d = Dice(seed: 7)
        let hats = Grid(bars: 2, subdivisions: 4) { step in
            d.chance(0.4, 1, step.index) ? "x" : "."
        }
        return Session {
            Track("drums", instrument: .drums()) {
                Section { Hat(hats) }
            }
        }
    }
}
```

### Instruments as properties

A computed session can name the type's own properties. That is often where a sound belongs, because it is part of the score rather than part of one section.

```swift
@main
struct Combo: Score {
    let rhodes = Instrument.generalMIDI(4)
    let upright = Instrument.generalMIDI(32)

    var session: Session {
        Session {
            Track("keys", instrument: rhodes) { … }
            Track("bass", instrument: upright) { … }
        }
    }
}
```

## Running a score

`Score` supplies `main()`, and the program it makes understands a few arguments:

| Argument | Result |
|---|---|
| *(none)* | The `Session` is written to standard output as JSON. |
| `--session-json <path>` | The JSON goes to a file instead, which leaves standard output free for the score's own `print(...)`. |
| `--midi <path>` | Writes a Standard MIDI File of the whole form. Given without `--session-json`, nothing else is printed. |
| `--time-signature <n>/<d>` | The meter that bar notation is read in before the session states its own. |

The JSON holds every note with its pitch, start, duration and velocity, plus the line and column it was written at. That is the whole interface between a score and a host: a host can compile the file as written, run it, and read the `Session` back, with nothing added to the score.

## Topics

- ``Score``
- ``Session``
