# Time Signatures

The meter of a piece, and what follows it.

## Overview

```swift
Session { … }
    .tempo(120)
    .timeSignature(3, 4)      // or .timeSignature(.sevenEight), .timeSignature(13, 16), …
```

A ``TimeSignature`` is beats per bar over the note that gets the beat. The common ones have names: `.fourFour`, `.threeFour`, `.twoFour`, `.fiveFour`, `.sixEight`, `.sevenEight` and `.twelveEight`. A session without one is in 4/4.

A bar lasts `beatsPerBar / noteValue` whole notes: 3/4 and 6/8 are both 0.75, 5/4 is 1.25. Note durations are fractions of a whole note in every meter.

What follows the meter:

- **Bar notation.** Each `|` bar spans one bar of the signature, and its tokens divide it equally. Inline notation does not: its tokens stay whole-note slots, so shape them with `.duration(...)`.
- **Drum grids**, in the same way as bar notation.
- **`Loop(bars:)`.** `Loop(bars: 2)` in 3/4 repeats every 1.5 whole notes.
- **`bars:` and `beats:` curves.** A beat is the signature's note value: a quarter in 3/4, an eighth in 6/8.
- **``Grid(bars:beats:subdivisions:_:)`` and ``Phrase(bars:beats:subdivisions:_:)``** without `beats:` write as many beats a bar as the signature has.

All of these read the meter while the score is built, so build the session in a ``Score`` or with ``Session/build(_:)``; see <doc:Sessions>.

The tempo counts quarter notes per minute in every meter. At 120 a bar of 6/8 lasts 1.5 seconds; 6/8 is usually felt as two beats of a dotted quarter (`.n4d`), each 0.75 seconds at that tempo.

A meter is set for the whole piece; it cannot change partway through yet.

## Topics

- ``TimeSignature``
