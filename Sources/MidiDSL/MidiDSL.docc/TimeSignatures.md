# Time Signatures

The meter of a piece, and what follows it.

## Overview

```swift
Session { … }
    .tempo(120)
    .timeSignature(3, 4)      // or .timeSignature(.sevenEight), .timeSignature(13, 16), …
```

The presets are `.fourFour`, `.threeFour`, `.sixEight`, `.fiveFour`, `.sevenEight`, `.twoFour` and `.twelveEight`. The default is 4/4.

- **Bar notation follows the meter.** Each `|` bar spans one bar of the signature, and its tokens divide it equally.
- **Drum grids follow the meter** in the same way.
- **Inline notation doesn't.** Its tokens stay whole-note slots, so shape them with `.duration(...)`.
- **Note durations are fractions of a whole note**, whatever the meter. 3/4 and 6/8 are both bars of 0.75; 5/4 is 1.25.
- **A `Loop`'s bars follow the meter** too, so `Loop(bars: 2)` in 3/4 repeats every 1.5 whole notes.
- **Tempo counts quarter notes per minute** in every meter. At 120 a bar of 6/8 lasts 1.5 seconds. 6/8 is usually felt in two pulses of a dotted quarter (`.n4d`), each 0.75 seconds at that tempo.

## Topics

- ``TimeSignature``
