# Notes, Rests and Note Sets

The values a section is made of, written as Swift instead of notation.

## Overview

Most scores write notes as notation strings. Build a ``Note`` instead when you need an exact velocity, duration or start time, or when the notes come from code.

```swift
Section {
    Note(pitch: .C5, velocity: 90, duration: 0.25)
    Note(pitch: nil, duration: 0.25)                           // a quarter of silence
}
```

Durations and start times are in whole notes: `1` is a whole note, `0.25` a quarter, whatever the meter. A pitch is a MIDI number or a ``Pitch`` constant such as `.C4` or `.ASharp5`; C5 is 60. A `nil` pitch is a rest that still takes its time.

A note's duration is how long it rings. It does not push back what comes after it: inside one statement, the notes are placed by their start times. Give several notes the same `startTime` to write a chord by hand:

```swift
Section {
    Note(pitch: .C5, velocity: 80, startTime: 0, duration: 1)
    Note(pitch: .E5, velocity: 80, startTime: 0, duration: 1)
    Note(pitch: .G5, velocity: 80, startTime: 0, duration: 1)
}
```

A note's velocity, 0…127, is multiplied by the track's and the session's volume on the way out.

## Rests

``Rest`` is a ``Note`` without a pitch. `Rest()` is a whole note of silence, and ``Note/init(startTime:duration:)`` places one exactly. A rest at the end of a statement makes the statement longer, which is how a line ends in silence.

## Note sets

A ``NoteSet`` is one note slot that plays a different member on each pass. ``NoteSetMode`` says in what order: up, down, up and back, or chosen by the dice.

```swift
Loop(bars: 1, times: 4) { _ in
    Section {
        NoteSet(.C4, .DSharp4, .G4)              // C4, D#4, G4, C4 on the four rounds
        NoteSet(.random, .C5, .D5, .E5)          // the dice choose, the same way every time
    }
}
```

In notation the same thing is `"(C4 D#4 G4)"`. See <doc:StringNotation> and <doc:DiceAndChance>.

## Topics

- ``Note``
- ``Rest``
- ``NoteSet``
- ``NoteSetMode``
- ``Pitch``
