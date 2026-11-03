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
- **Tempo counts quarter notes per minute** in every meter. At 120 a bar of 6/8 lasts 1.5 seconds, and a 6/8 felt in two pulses on the dotted quarter, `.n4d`.

## Topics

- ``TimeSignature``
