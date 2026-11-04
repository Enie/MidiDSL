# Sessions

The whole piece: its tracks, tempo, meter, form, key and seed.

## Overview

A ``Session`` holds the tracks, which all play at once, and the settings that belong to the whole piece. Its modifiers return a changed copy, so they chain after the closing brace:

```swift
Session {
    Track("drums", instrument: .drums()) { … }
    Track("bass", instrument: .generalMIDI(33)) { … }
}
.tempo(96)
.timeSignature(.sixEight)
.key(.E3, .minor)
.volume(0.9)
```

| Modifier | Sets |
|---|---|
| ``Session/tempo(_:)`` | quarter notes per minute, 120 if the score says nothing |
| ``Session/timeSignature(_:)`` | the meter bars are measured in, 4/4 if the score says nothing; see <doc:TimeSignatures> |
| ``Session/key(_:_:)`` | the key degrees are read in; see <doc:ProgressionsAndScales> |
| ``Session/volume(_:)`` | the master level, multiplied into every track's |
| ``Session/loops(_:)`` | how many passes the form has; see <doc:TracksAndArrangement> |
| ``Session/loopBars(_:)`` | how many bars one pass lasts, if not the longest track's length |
| ``Session/seed(_:)`` | which performance the dice give; see <doc:DiceAndChance> |

The tempo counts quarter notes in every meter: at 120, a bar of 6/8 lasts 1.5 seconds. It sets how fast the music goes and never what a bar holds, so a MIDI file carries it in its conductor track and no note changes with it.

Written as `Session { pass in … }`, the body is read once per pass, so a track can change from one time through the piece to the next. See <doc:TracksAndArrangement>.

## Meter and tempo while the score is built

A session states its meter and tempo after its body, but some of the body needs them while it is built: bar notation and `Loop(bars:)` need the bar's length, a ``Grid(bars:beats:subdivisions:_:)`` without `beats:` needs the beats, and ``Section/tempo(_:)`` needs the tempo it is measured against.

``Session/build(_:)`` takes care of it: it builds the session once to learn what it declares, and once more if that is not what it was built in. A score is a pure function of its source, so the second build is the same score read with the right bar. A ``Score`` builds its session this way; call it yourself when you build a session in your own code.

```swift
let waltz = Session.build {
    Session { Track("melody") { Section { "| 1 2 3 | 5 - - |" } } }
        .timeSignature(.threeFour)
}
```

A session built without it is read in 4/4 at 120, whatever it declares.

## Topics

- ``Session``
- ``TimeSignature``
